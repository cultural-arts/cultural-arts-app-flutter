import { 
    AutoProcessor,
    load_image,
    AutoConfig
  } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3';
  
    class SmolVLMInference {
      constructor(config) {
        // Model configuration
        this.modelId = "HuggingFaceTB/SmolVLM-256M-Instruct";
        this.config = {
          text_config: {
            num_key_value_heads: config.text_config.num_key_value_heads,
            head_dim: config.text_config.head_dim,
            num_hidden_layers: config.text_config.num_hidden_layers,
            eos_token_id: config.text_config.eos_token_id
          },
          image_token_id: config.image_token_id
        };
        
        // Initialize sessions and processor
        this.visionSession = null;
        this.embedSession = null;
        this.decoderSession = null;
        this.processor = null;
        
        // Model parameters from config
        this.numKeyValueHeads = this.config.text_config.num_key_value_heads;
        this.headDim = this.config.text_config.head_dim;
        this.numHiddenLayers = this.config.text_config.num_hidden_layers;
        this.eosTokenId = this.config.text_config.eos_token_id;
        this.imageTokenId = this.config.image_token_id;
      }
    
      // Initialize ONNX sessions
      async loadModels() {
        try {
          console.log("Loading ONNX models...");
          
          // Load all three models in parallel
          [this.visionSession, this.embedSession, this.decoderSession] = await Promise.all([
            ort.InferenceSession.create('./vision_encoder_q4.onnx', { executionProviders: ['webgpu'] }),
            ort.InferenceSession.create('./embed_tokens_q4.onnx', { executionProviders: ['webgpu'] }),
            ort.InferenceSession.create('./decoder_model_merged_q4.onnx', { executionProviders: ['webgpu'] })
          ]);
          
          console.log("Models loaded successfully!");
          return true;
        } catch (error) {
          console.error("Error loading models:", error);
          return false;
        }
      }
    
      // Simplified token decoder
      decodeTokens(tokens) {
        // This is a very simplified decoder
        return tokens.map(t => String.fromCharCode(97 + (Number(t) % 26))).join("");
      }
  
      async officialPreproc(imageUrl, question){
  
        const image1 = await load_image(imageUrl);
  
        // Load processor and model
        const model_id = "HuggingFaceTB/SmolVLM-256M-Instruct";
  
        const processor = await AutoProcessor.from_pretrained(model_id);
  
        const messages = [
            {
                role: "user",
                content: [
                    { type: "image" },
                    { type: "text", text: question },
                ],
            },
        ];
        const text = processor.apply_chat_template(messages, { add_generation_prompt: true });
        const inputs = await processor(text, [image1], {
          do_image_splitting: false,
        });
  
        return inputs;
      }
    
      // Main inference function
      async generateText(imageUrl, question, maxNewTokens = 1024) {
        try {
  
          const officialInputProcessing = await this.officialPreproc(imageUrl, question);
          
          // Prepare decoder inputs
          const batchSize = 1;
          let pastKeyValues = {};
          for (let layer = 0; layer < this.numHiddenLayers; layer++) {
            for (let kv of ['key', 'value']) {
              pastKeyValues[`past_key_values.${layer}.${kv}`] = new ort.Tensor(
                'float32', 
                new Float32Array(0), 
                [batchSize, this.numKeyValueHeads, 0, this.headDim]
              );
            }
          }
          
          let imageFeatures = null;
          let inputIds = officialInputProcessing.input_ids;
          let attentionMask = officialInputProcessing.attention_mask;
          
          // Calculate position IDs
          let positionIds = this.calculatePositionIds(attentionMask);
          
          // Generation loop
          let generatedTokens = [];
          let outputText = "";
          
          console.log("Starting generation...");
          
          for (let i = 0; i < maxNewTokens; i++) {
            // Get token embeddings
            const inputIdsArray = this.getTensorData(inputIds);
            const embedFeed = { 'input_ids': inputIds };
            const embedResult = await this.embedSession.run(embedFeed);
            const inputsEmbeds = embedResult.inputs_embeds; // Assumes output tensor is named 'output'
            
            // Process image if needed
            if (imageFeatures === null) {
              const visionFeed = {
                'pixel_values': officialInputProcessing.pixel_values,
                'pixel_attention_mask': officialInputProcessing.pixel_attention_mask
              };
              
              const visionResult = await this.visionSession.run(visionFeed);
              imageFeatures = visionResult.image_features;
              
              // Replace image token embeddings with image features
              // This would need a more complex implementation to find and replace the correct embeddings
              // For now, just a placeholder showing the concept
            }
            
            // Run decoder model
            const decoderFeeds = {
              'inputs_embeds': inputsEmbeds,
              'attention_mask': attentionMask,
              'position_ids': positionIds,
              ...pastKeyValues
            };
            
            const decoderResults = await this.decoderSession.run(decoderFeeds);
            const logits = decoderResults.logits;
            const presentKeyValues = decoderResults.present_key_values || [];
            
            // Get next token (argmax of last logits)
            const nextToken = this.getNextToken(logits);
            
            // Update for next iteration
            inputIds = new ort.Tensor('int64', new BigInt64Array([BigInt(nextToken)]), [1, 1]);
            attentionMask = new ort.Tensor('int64', new BigInt64Array([1n]), [1, 1]);
            positionIds = new ort.Tensor('int64', new BigInt64Array([BigInt(this.getTensorData(positionIds)[0] + BigInt(1))]), [1, 1]);
            
            // Update past key values
            // This would need proper handling of the present key values structure
            
            // Add token to generated sequence
            generatedTokens.push(nextToken);
            
            // Decode token and add to output text
            const tokenText = this.decodeTokens([nextToken]);
            outputText += tokenText;
            
            // Optional streaming output
            if (i % 5 === 0) {
              console.log("Generation progress:", outputText);
            }
            
            // Check for EOS token
            if (nextToken === this.eosTokenId) {
              break;
            }
          }
          
          console.log("Generation complete!");
          return outputText;
        } catch (error) {
          console.error("Error in generation:", error);
          return "An error occurred during text generation.";
        }
      }
    
      // Helper to calculate position IDs from attention mask
      calculatePositionIds(attentionMask) {
        const attentionArray = this.getTensorData(attentionMask);
        const positionArray = new BigInt64Array(attentionArray.length);
        
        let position = 0n;
        for (let i = 0; i < attentionArray.length; i++) {
          if (attentionArray[i] === 1n) {
            positionArray[i] = BigInt(position);
            position++;
          } else {
            positionArray[i] = 0n;
          }
        }
        
        return new ort.Tensor('int64', positionArray, attentionMask.dims);
      }
    
      // Helper to get next token from logits
      getNextToken(logits) {
        // Get the last token's logits
        const lastLogits = Array.from(this.getTensorData(logits).slice(-logits.dims[2]));
        
        // Find the index of the maximum value (argmax)
        let maxIndex = 0;
        let maxValue = lastLogits[0];
        
        for (let i = 1; i < lastLogits.length; i++) {
          if (lastLogits[i] > maxValue) {
            maxValue = lastLogits[i];
            maxIndex = i;
          }
        }
        
        return maxIndex;
      }
    
      // Helper to get tensor data as array
      getTensorData(tensor) {
        return tensor.data;
      }
    }
    
// Usage example
globalThis.runSmolVLM = async function () {

    let model_id = "HuggingFaceTB/SmolVLM-256M-Instruct";
    const config = await AutoConfig.from_pretrained(model_id);
    const inferenceEngine = new SmolVLMInference(config);

    // Step 1: Load models
    const modelsLoaded = await inferenceEngine.loadModels();
    if (!modelsLoaded) {
        console.error("Failed to load models");
        return;
    }

    // Step 2: Run inference
    const imageUrl = "./Statue-of-Liberty-Island-New-York-Bay.jpg";
    const question = "Can you describe this image?";

    console.log("Running inference on image:", imageUrl);
    console.log("Question:", question);

    const result = await inferenceEngine.generateText(imageUrl, question);

    // Step 3: Show results
    console.log("Generated text:");
    console.log(result);

    return "OK";
}