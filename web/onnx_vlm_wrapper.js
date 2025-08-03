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
    this.concat = null;
    this.lastToken = null;
    
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
      [this.visionTower, this.mp, this.tokenEmbedding, this.decoderHead, this.decoder, this.concat, this.lastToken] = await Promise.all([
        ort.InferenceSession.create('./nanoVLM_vision_tower.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_mp.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_decoder_token_embedding.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_decoder_head.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_decoder.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_dynamicconcat.onnx', { executionProviders: ['webgpu'] }),
        ort.InferenceSession.create('./nanoVLM_last_token.onnx', { executionProviders: ['webgpu'] })
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
          pastKeyValues[`past_${kv}_${layer}`] = new ort.Tensor(
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
      let positionIdCounter = 0;
      let positionId = new ort.Tensor("int64", new BigInt64Array([BigInt(positionIdCounter)]), [1]);
      
      // Generation loop
      let generatedTokens = [];
      let outputText = "";

      console.log("prefill...");

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

      console.log("[3/X] token embedding done.");

      if (imgProjection.modality_projection_output.dims[2] != promptEmbeds.embedding.dims[2]) {
        throw "Different MP and TokenEmbeddding dimensions";
      }

      // concat imgProjection and tokenIds over dim 1
      // let # [B, T_img + T_prompt_text, D_lm]

      const concatFeeds = {
        "x": imgProjection.modality_projection_output,
        "y": promptEmbeds.embedding
      };

      let concatText = await this.concat.run(concatFeeds);

      console.log("[4/X] concat done.");

      const decoderFeeds = {
        "decoder_input": concatText.x_y_concat,
        "decoder_start_pos": positionId,
        ...pastKeyValues
      };

      let prefillOutput = await this.decoder.run(decoderFeeds);

      this.updatePastKV(prefillOutput, pastKeyValues);

      console.log("[5/X] decoder done.");

      const lastTokenFeeds = { "x": prefillOutput.decoder_output };
      
      // x -> last_token
      let lastToken = await this.lastToken.run(lastTokenFeeds);

      console.log("[6/X] last token done.");

      const decoderHeadFeeds = { "embedding": lastToken.last_token.reshape([1, 1, this.lmDim]) };

      // embedding -> tokens
      let currentLogits = await this.decoderHead.run(decoderHeadFeeds);

      console.log("[7/X] decoder head done.");

      positionIdCounter = imgProjection.modality_projection_output.dims[1] + promptEmbeds.embedding.dims[1];
      positionId = new ort.Tensor("int64", new BigInt64Array([BigInt(positionIdCounter)]), [1]);
      
      console.log("decode...");

      let generatedTokenIds = [];
      
      for (let i = 0; i < maxNewTokens; i++) {

        /*
        filtered_logits = top_k_top_p_filtering(current_logits, top_k=top_k, top_p=top_p)
        probs = torch.softmax(filtered_logits / temperature, dim=-1)
        next_token_id = torch.multinomial(probs, num_samples=1)
         */

        throw "Implement rows above to get nextToken";

        generatedTokenIds.push(nextToken);

        const tokenEmbedFeeds = {
          "tokens": officialInputProcessing.nextToken
        };

        let nextTokenEmbed = await this.tokenEmbedding.run(tokenEmbedFeeds);
        
        // Run decoder model
        const decoderFeeds = {
          'decoder_input': nextTokenEmbed,
          'decoder_start_pos': positionId,
          ...pastKeyValues
        };
        
        const decoderResults = await this.decoder.run(decoderFeeds);

        // Update past key values
        this.updatePastKV(decoderResults, pastKeyValues);
        
        const lastTokenFeeds = { "x": decoderResults.decoder_output };
      
        // x -> last_token
        let lastToken = await this.lastToken.run(lastTokenFeeds);

        const decoderHeadFeeds = { "embedding": lastToken.last_token.reshape([1, 1, this.lmDim]) };

        // embedding -> tokens
        let currentLogits = await this.decoderHead.run(decoderHeadFeeds);

        // Update for next iteration
        positionId = new ort.Tensor('int64', new BigInt64Array([BigInt(this.getTensorData(positionId).at(-1) + BigInt(1))]), [1, 1]);
        
        // Decode token and add to output text
        const tokenText = this.processor.decode([nextToken]);
        outputText += tokenText;
        
        // Optional streaming output
        if (i % 5 === 0) {
          // TODO here call the callback to update the UI
          console.log("Generation progress:", outputText);
        }
        
        // Check for EOS token
        // if (nextToken === this.eosTokenId) {
        //   break;
        // }
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
        pastKV[`past_${kv}_${layer}`] = presentKV[`present_${kv}_${layer}`];
      }
    }
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