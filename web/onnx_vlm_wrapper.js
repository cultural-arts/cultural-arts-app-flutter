import { 
  AutoTokenizer,
  load_image,
  AutoConfig
} from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.7.1';

// source to check for updates https://www.jsdelivr.com/package/npm/@huggingface/transformers

class NanoVLMInference {
  constructor(config) {
    // Model configuration
    this.config = {
      lm_config: {
        lm_dim: config.lm_config.lm_dim,
        num_hidden_layers: config.lm_config.num_hidden_layers,
      },
      vit_config: {
        vit_dim: config.vit_config.vit_dim,
      }
    };
    
    // Initialize sessions and processor
    this.visionTower = null;
    this.mp = null;
    this.tokenEmbedding = null;
    this.decoderHead = null;
    this.decoder = null;
    
    // Model parameters from config
    this.lmDim = this.config.lm_config.lm_dim;
    this.vitDim = this.config.vit_config.vit_dim;
    this.numHiddenLayers = this.config.lm_config.num_hidden_layers;
    this.numKeyValueHeads = 1;
    this.headDim = 36;
  }

  // Initialize ONNX sessions
  async loadModels() {
    try {
      console.log("Loading ONNX models...");
      
      // Load all three models in parallel
      [this.visionTower, this.mp, this.tokenEmbedding, this.decoderHead, this.decoder] = await Promise.all([
        ort.InferenceSession.create('./nanoVLM_vision_tower.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_mp.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_decoder_token_embedding.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_decoder_head.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_decoder.onnx', { executionProviders: ['webgpu'] })
      ]);
      
      console.log("Models loaded successfully!");
      return true;
    } catch (error) {
      console.error("Error loading models:", error);
      return false;
    }
  }

  async officialPreproc(imageURL, question){

    let inputs = {};
    const tokenizer = await AutoTokenizer.from_pretrained('HuggingFaceTB/cosmo2-tokenizer');

    let input_img = await load_image(imageURL);
    input_img = input_img.rgb();
    input_img = await input_img.resize(224, 224);

    // img to [1, 3, 224, 224]
    inputs["img"] = new ort.Tensor("float32", new Float32Array(input_img.data), [1, 3, 224, 224]);
    
    let input_ids = await tokenizer(question);
    input_ids = input_ids.input_ids.ort_tensor;

    // input_ids to [1, 12]
    inputs["token_ids"] = input_ids;

    return inputs;
  }

  // Main inference function
  async generateText(imageURL, question, maxNewTokens = 50) {
    try {

      const officialInputProcessing = await this.officialPreproc(imageURL, question);
      
      // prepare decoder inputs for prefill phase
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
      let tokenIds = officialInputProcessing.token_ids;
      // let attentionMask = officialInputProcessing.attention_mask;
      
      // Calculate position IDs
      // let positionIds = this.calculatePositionIds(attentionMask);
      let positionIds = new ort.Tensor("int64", new BigInt64Array([BigInt(0)]), [1]);
      
      // Generation loop
      let generatedTokens = [];
      let outputText = "";

      console.log("Prefill phase.");

      const visionTowerFeeds = {
        "vision_tower_input": officialInputProcessing.img,
      }

      console.log("[1/X] vision tower done.");

      // [1, 3, 224, 224] -> vision_tower_output
      let imgEmbed = await this.visionTower.run(visionTowerFeeds);

      const mpFeeds = {
        "modality_projection_input": imgEmbed.vision_tower_output,
      }
      
      // [1, 196, 768] -> [1, 49, 144] .modality_projection_output
      let imgProjection = await this.mp.run(mpFeeds);

      console.log("[2/X] modality projection done.");

      const tokenEmbedFeeds = {
        "tokens": officialInputProcessing.token_ids
      };

      // [1, 12] -> [1, 12, 216] embedding
      let promptEmbeds = await this.tokenEmbedding.run(tokenEmbedFeeds);

      if (imgProjection.modality_projection_output.dims[2] != promptEmbeds.embedding.dims[2]) {
        throw "Different MP and TokenEmbeddding dimensions";
      }

      // concat imgProjection and tokenIds over dim 1
      // let # [B, T_img + T_prompt_text, D_lm]

      

      const decoderFeeds = {
        "decoder_input": null,
        "decoder_start_pos": positionIds,
        ...pastKeyValues
      };

      let prefillOutput = await this.decoderSession.run(decoderFeeds);
      
      console.log("DECODING...");
      
      for (let i = 0; i < maxNewTokens; i++) {

        // Get token embeddings (from LLM)
        const tokenIdsArray = Array.from(this.getTensorData(tokenIds));
        const embedFeed = { 'input_ids': tokenIds };
        const embedResult = await this.tokenEmbeddingSession.run(embedFeed);

        // [, , ]
        let inputsEmbeds = embedResult.inputs_embeds;
        
        // Process image if needed
        if (imageFeatures === null) {

          const imageTokenCount = tokenIdsArray.filter(num => num === BigInt(this.imageTokenId)).length;

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
          for (let i = 0; i < tokenIdsArray.length; i++){
            if (tokenIdsArray[i] == BigInt(this.imageTokenId)) {
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
          // 'attention_mask': attentionMask,
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
        tokenIds = new ort.Tensor('int64', new BigInt64Array([BigInt(nextToken)]), [1, 1]);
        // attentionMask = new ort.Tensor('int64', new BigInt64Array([1n]), [1, 1]);
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
    6
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

const config = {
  lm_config: {
    lm_dim: 216,
    num_hidden_layers: 1,
  },
  vit_config: {
    vit_dim: 768
  }
}


console.log("Loading NanoVLM model configs...");
const inferenceEngine = new NanoVLMInference(config);

globalThis.loadNanoVLM = async function () {
  // Step 1: Load models
  const modelsLoaded = await inferenceEngine.loadModels();
  if (!modelsLoaded) {
    console.error("Failed to load models");
    return false;
  }

  return true;
}

  // Usage example
globalThis.runNanoVLM = async function (imageURL) {
  
  // Step 2: Run inference
  const question = "Question: What art is there in the photo? Answer:";

  console.log("Running inference on image:", imageURL);
  console.log("Question:", question);
  
  const result = await inferenceEngine.generateText(imageURL, question);
  
  // Step 3: Show results
  console.log("Generated text:");
  console.log(result);

  return result;

}