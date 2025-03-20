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

  async officialPreproc(imageURL, question){

    const image1 = await load_image(imageURL);

    // Load processor and model
    const model_id = "HuggingFaceTB/SmolVLM-256M-Instruct";
    this.processor = await AutoProcessor.from_pretrained(model_id);

    const messages = [
        {
            role: "user",
            content: [
                { type: "image" },
                { type: "text", text: question },
            ],
        },
    ];
    const prompt = this.processor.apply_chat_template(messages, { tokenize: false, add_generation_prompt: true });
    const inputs = await this.processor(prompt, [image1]);

    return inputs;
  }

  // Main inference function
  async generateText(imageURL, question, maxNewTokens = 1024) {
    try {

      const officialInputProcessing = await this.officialPreproc(imageURL, question);
      
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
        const inputIdsArray = Array.from(this.getTensorData(inputIds));
        const embedFeed = { 'input_ids': inputIds };
        const embedResult = await this.embedSession.run(embedFeed);

        // [1, 876, 576]
        let inputsEmbeds = embedResult.inputs_embeds;
        
        // Process image if needed
        if (imageFeatures === null) {

          const imageTokenCount = inputIdsArray.filter(num => num === BigInt(this.imageTokenId)).length;

          const visionFeed = {
            'pixel_values': officialInputProcessing.pixel_values,
            'pixel_attention_mask': officialInputProcessing.pixel_attention_mask
          };
          
          const visionResult = await this.visionSession.run(visionFeed);

          // imageFeatures.shape = [13, 64, 576]
          const firstDim = visionResult.image_features.dims[0] * visionResult.image_features.dims[1];
          const secDim = visionResult.image_features.dims[2];
          // [13, 64, 576] -> [479232] contiguous
          imageFeatures = Array.from(this.getTensorData(visionResult.image_features));
          // [13, 64, 576] -> [832, 576]
          imageFeatures = math.reshape(imageFeatures, [firstDim, secDim]);

          // there must be image_token * firstDim tokens in inputsEmbeds, then replace each position (second dim) with the index from imageFeatures

          if (imageTokenCount != firstDim) {
            return "Error, invalid number of image tokens";
          }

          const origDims = inputsEmbeds.dims; // [1, 876, 576]
          const origLocation = inputsEmbeds.location; // cpu
          const origType = inputsEmbeds.type; // float32
          const origSize = inputsEmbeds.size; // 504576

          // [504576] contiguous
          let inputsEmbedsArray = Array.from(this.getTensorData(inputsEmbeds)); 
          // [504576] -> [876, 576]
          inputsEmbedsArray = math.reshape(inputsEmbedsArray, [inputsEmbeds.dims[1], inputsEmbeds.dims[2]]); // first dimension [1] is not effective here

          // replace with imageFeatures
          let imgFeaturesCnt = 0;
          for (let i = 0; i < inputIdsArray.length; i++){
            if (inputIdsArray[i] == BigInt(this.imageTokenId)) {
              inputsEmbedsArray[i] = imageFeatures[imgFeaturesCnt];
              imgFeaturesCnt += 1;
            }
          }

          // [876, 576] -> [504576]
          inputsEmbedsArray = math.reshape(inputsEmbedsArray, [inputsEmbeds.size]);

          // convert the array back to tensor (cpu)
          inputsEmbeds = new ort.Tensor("float32", new Float32Array(inputsEmbedsArray), [inputsEmbeds.size]);
          inputsEmbeds = inputsEmbeds.reshape(origDims);

          if (origDims !== inputsEmbeds.dims || origLocation !== inputsEmbeds.location || origType !== inputsEmbeds.type || origSize !== inputsEmbeds.size) {
            return "Error, convertion of inputsEmbed failed";
          }

        }
        
        // Run decoder model
        const decoderFeeds = {
          'inputs_embeds': inputsEmbeds,
          'attention_mask': attentionMask,
          'position_ids': positionIds,
          ...pastKeyValues  // [1, 3, 0 ,64]
        };
        
        const decoderResults = await this.decoderSession.run(decoderFeeds);
        
        // [1, 876, 49280]
        const logits = decoderResults.logits; 

        // we take the entire object, remove the logits with effect on [decoderResults]
        const presentKeyValues = decoderResults;
        delete presentKeyValues.logits;
        
        // Get next token (argmax of last logits)
        const nextToken = this.getNextToken(logits);
        
        // Update for next iteration
        inputIds = new ort.Tensor('int64', new BigInt64Array([BigInt(nextToken)]), [1, 1]);
        attentionMask = new ort.Tensor('int64', new BigInt64Array([1n]), [1, 1]);
        positionIds = new ort.Tensor('int64', new BigInt64Array([BigInt(this.getTensorData(positionIds).at(-1) + BigInt(1))]), [1, 1]);
        
        // Update past key values
        this.updatePastKV(presentKeyValues, pastKeyValues);
        
        // Add token to generated sequence
        generatedTokens.push(nextToken);
        
        // Decode token and add to output text
        const tokenText = this.processor.decode([nextToken]);
        outputText += tokenText;
        
        // Optional streaming output
        if (i % 5 === 0) {
          // TODO here call the callback to update the UI
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

  // update KVs
  updatePastKV(presentKV, pastKV) {

    for (let layer = 0; layer < this.numHiddenLayers; layer++) {
      for (let kv of ['key', 'value']) {
        pastKV[`past_key_values.${layer}.${kv}`] = presentKV[`present.${layer}.${kv}`];
      }
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
  
console.log("Loading HuggingFaceTB/SmolVLM-256M-Instruct configs...");
let model_id = "HuggingFaceTB/SmolVLM-256M-Instruct";
const config = await AutoConfig.from_pretrained(model_id);
console.log("Init SmolVLMInference object...");
const inferenceEngine = new SmolVLMInference(config);

globalThis.loadSmolVLM = async function () {
  // Step 1: Load models
  const modelsLoaded = await inferenceEngine.loadModels();
  if (!modelsLoaded) {
    console.error("Failed to load models");
    return false;
  }

  return true;
}

  // Usage example
globalThis.runSmolVLM = async function (imageURL) {
  
  // Step 2: Run inference
  const question = "Can you describe this image?";
  
  console.log("Running inference on image:", imageURL);
  console.log("Question:", question);
  
  const result = await inferenceEngine.generateText(imageURL, question);
  
  // Step 3: Show results
  console.log("Generated text:");
  console.log(result);

  return result;

}