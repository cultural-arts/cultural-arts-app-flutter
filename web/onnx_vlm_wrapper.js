import { 
  AutoTokenizer,
  load_image} from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.7.1';
  
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
    this.processor = null;
    
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

      globalThis.updateUILoadingSteps("Initializing AI models...");

      const loadModel = async (path, label) => {
        globalThis.updateUILoadingSteps(`Loading ${label}...`);
        const model = await ort.InferenceSession.create(path, { executionProviders: ['webgpu'] });
        globalThis.updateUILoadingSteps(`${label} loaded.`);
        return model;
      };

      [
        this.visionTower,
        this.mp,
        this.tokenEmbedding,
        this.decoderHead,
        this.decoder,
        this.concat,
        this.lastToken
      ] = await Promise.all([
        loadModel('./nanoVLM_vision_tower.onnx', '[1/7] Vision Tower'),
        loadModel('./nanoVLM_mp.onnx', '[2/7] MP'),
        loadModel('./nanoVLM_decoder_token_embedding.onnx', '[3/7] Token Embedding'),
        loadModel('./nanoVLM_decoder_head.onnx', '[4/7] Decoder Head'),
        loadModel('./nanoVLM_decoder.onnx', '[5/7] Decoder'),
        loadModel('./nanoVLM_dynamicconcat.onnx', '[6/7] Dynamic Concat'),
        loadModel('./nanoVLM_last_token.onnx', '[7/7] Last Token')
      ]);

      globalThis.updateUILoadingSteps("All models loaded successfully.");
      return true;
    } catch (error) {
      console.error("Error loading models:", error);
      return false;
    }
  }

  async officialPreproc(imageURL, question){

    let inputs = {};
    this.processor = await AutoTokenizer.from_pretrained('HuggingFaceTB/cosmo2-tokenizer');

    let input_img = await load_image(imageURL);
    input_img = input_img.rgb();
    input_img = await input_img.resize(224, 224);

    // img to [1, 3, 224, 224]
    inputs["img"] = new ort.Tensor("float32", new Float32Array(input_img.data), [1, 3, 224, 224]);

    // normalize [0-255] to [0-1]
    let imgArray = Array.from(this.getTensorData(inputs["img"]));
    imgArray = imgArray.map(v => v / 255);

    // rewrite tensor
    inputs["img"] = new ort.Tensor("float32", new Float32Array(imgArray), [1, 3, 224, 224]);
    
    let input_ids = await this.processor(question);
    input_ids = input_ids.input_ids.ort_tensor;

    // input_ids to [1, 12]
    inputs["token_ids"] = input_ids;

    return inputs;
  }

  /**
   * Apply softmax with temperature.
   * @param {number[]} logits - 1D array of filtered logits.
   * @param {number} temperature - Temperature for softmax.
   * @returns {number[]} Softmax probabilities.
   */
  softmax(logits, temperature = 1.0) {
      const scaled = logits.map(v => v / temperature);
      const exps = scaled.map(v => math.exp(v));
      const total = math.sum(exps);
      return exps.map(v => v / total);
  }

  /**
   * Sample a token index from a probability distribution.
   * @param {number[]} probs - Probabilities summing to 1.
   * @returns {number} Index of sampled token.
   */
  sampleFromProbs(probs) {
      const r = math.random();
      let acc = 0;
      for (let i = 0; i < probs.length; i++) {
          acc += probs[i];
          if (r < acc) {
              return i;
          }
      }
      // fallback (due to floating point)
      return probs.length - 1;
  }

  // Main inference function
  async generateText(imageURL, question, maxNewTokens = 150) {
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
      
      // let imageFeatures = null;
      // let tokenIds = officialInputProcessing.token_ids;
      // let attentionMask = officialInputProcessing.attention_mask;
      
      // Calculate position IDs
      // let positionIds = this.calculatePositionIds(attentionMask);
      let positionIdCounter = 0;
      let positionId = new ort.Tensor("int64", new BigInt64Array([BigInt(positionIdCounter)]), [1]);
      
      // Generation loop
      // let generatedTokens = [];
      let outputText = "";

      console.log("prefill...");

      const visionTowerFeeds = {
        "vision_tower_input": officialInputProcessing.img,
      }

      console.log("[1/X] vision tower done.");

      // [1, 3, 224, 224] -> [1, 196, 768] vision_tower_output
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

      // embedding -> [1, 49k] tokens
      let logits = await this.decoderHead.run(decoderHeadFeeds);

      console.log("[7/X] decoder head done.");

      positionIdCounter = imgProjection.modality_projection_output.dims[1] + promptEmbeds.embedding.dims[1];
      positionId = new ort.Tensor("int64", new BigInt64Array([BigInt(positionIdCounter)]), [1]);
      
      console.log("decode...");

      let generatedTokenIds = [];
      
      for (let i = 0; i < maxNewTokens; i++) {

        const tokensData = this.getTensorData(logits.tokens);
        const filteredLogits = this.topKTopPFiltering(tokensData, 50, 0.9);
        const probs = this.softmax(filteredLogits, 0.5);
        const nextToken = this.sampleFromProbs(probs);

        generatedTokenIds.push(nextToken);

        const nextTokenOrt = new ort.Tensor("int64", new BigInt64Array([BigInt(nextToken)]), [1, 1])

        const tokenEmbedFeeds = {
          "tokens": nextTokenOrt
        };

        let nextTokenEmbed = await this.tokenEmbedding.run(tokenEmbedFeeds);
        
        // Run decoder model
        const decoderFeeds = {
          'decoder_input': nextTokenEmbed.embedding,
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
        logits = await this.decoderHead.run(decoderHeadFeeds);

        // Update for next iteration
        positionId = new ort.Tensor('int64', new BigInt64Array([BigInt(this.getTensorData(positionId).at(-1) + BigInt(1))]), [1]);
        
        // Optional streaming output
        if (i % 5 === 0) {
          // TODO here call the callback to update the UI
          console.log("Generation progress:", outputText);
        }

        // Decode token and add to output text
        const tokenText = this.processor.decode([nextToken]);
        
        // Check for EOS token
        if (tokenText === this.processor.eos_token) {
          break;
        }

        outputText += tokenText;

        globalThis.tokenToUI(tokenText);

      }
      
      console.log("Generation complete!");
      return outputText;
    } catch (error) {
      console.error("Error in generation:", error);
      return "An error occurred during text generation.";
    }
  }


  /**
   * Apply top-k and/or top-p (nucleus) filtering to logits (1D array).
   * @param {number[]} logits Array of raw logits.
   * @param {number} topK Keep only topK tokens with highest logits.
   * @param {number} topP Keep smallest number of tokens whose cumulative prob ≥ topP.
   * @param {number} filterValue Value to assign to filtered logits.
   * @returns {number[]} Filtered logits array.
   */
  topKTopPFiltering(logits, topK = 0, topP = 1.0, filterValue = -Infinity) {
      const logitsCopy = [...logits];
      const vocabSize = logits.length;

      // --- Top-K filtering ---
      if (topK > 0 && topK < vocabSize) {
          const topKThreshold = [...logitsCopy].sort((a, b) => b - a)[topK - 1];
          for (let i = 0; i < vocabSize; i++) {
              if (logitsCopy[i] < topKThreshold) {
                  logitsCopy[i] = filterValue;
              }
          }
      }

      // --- Top-P (nucleus) filtering ---
      if (topP < 1.0) {
          // 1. Sort logits + keep track of original indices
          const indexed = logitsCopy.map((logit, i) => ({ index: i, logit }));
          indexed.sort((a, b) => b.logit - a.logit);

          // 2. Convert to probabilities
          const exps = indexed.map(obj => math.exp(obj.logit));
          const total = math.sum(exps);
          const probs = exps.map(v => v / total);

          // 3. Cumulative sum of sorted probs
          const cumProbs = math.cumsum(probs);

          // 4. Find indices where cumulative prob exceeds topP
          let cutoff = probs.length;
          for (let i = 0; i < cumProbs.length; i++) {
              if (cumProbs[i] > topP) {
                  cutoff = i + 1; // keep up to and including i
                  break;
              }
          }

          // 5. Zero out logits beyond cutoff
          for (let i = cutoff; i < indexed.length; i++) {
              logitsCopy[indexed[i].index] = filterValue;
          }
      }

      return logitsCopy;
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