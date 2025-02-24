import { 
    AutoProcessor,
    AutoModelForVision2Seq,
    load_image,
} from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3';

console.log("vlm.js");

const DEBUG_MODE = true;

globalThis.whatsInTheImage = async function (imagePath) {
    console.log(imagePath);

    const adapter = await navigator.gpu.requestAdapter();

    /** [Android Available Features (via navigator.gpu)]
        float32-blendable
        depth32float-stencil8
        rg11b10ufloat-renderable
        texture-compression-astc
        texture-compression-etc2
        depth-clip-control
        chromium-experimental-multi-draw-indirect
        dual-source-blending
        clip-distances
        timestamp-query
        chromium-experimental-snorm16-texture-formats
        chromium-experimental-unorm16-texture-formats
        chromium-experimental-timestamp-query-inside-passes
        indirect-first-instance
     */

    if (DEBUG_MODE){
        console.log("******");
        adapter.features.forEach(element => {
            console.log(element);
        });
        console.log("******");
    }

    if (!adapter.features.has("shader-f16")) {
        console.log("16-bit floating-point value support is not available");
    }

    // https://github.com/huggingface/transformers.js/pull/1059

    const timings = {};

    function logTime(label) {
        if (DEBUG_MODE){
            const now = performance.now();
            if (!timings[label]) {
                timings[label] = now;
            } else {
                console.log(`${label} took ${(now - timings[label]).toFixed(2)}ms`);
                delete timings[label];
            }
        }
    }

    // Load images
    logTime("Image Loading");
    const image1 = await load_image(imagePath);
    logTime("Image Loading");

    // Initialize processor and model
    const model_id = "HuggingFaceTB/SmolVLM-256M-Instruct";

    logTime("Processor Loading");
    const processor = await AutoProcessor.from_pretrained(model_id);
    logTime("Processor Loading");

    logTime("Model Loading");
    const model = await AutoModelForVision2Seq.from_pretrained(model_id, {
        dtype: {
            embed_tokens: "fp32", 
            vision_encoder: "q4", 
            decoder_model_merged: "q4", 
        },
        device: "webgpu",
    });
    logTime("Model Loading");

    /**
        -- CPU WASM --
        Step,Time (ms)
        Image Loading,498.10
        Processor Loading,2281.60
        Model Loading,13780.50
        Text Processing,3.40
        Processor Apply,1083.20
        Model Generation,59057.00
        Batch Decoding,0.80

        -- WEBGPU --
        Step,Time (ms)
        Image Loading,176.50
        Processor Loading,991.80
        Model Loading,13262.60
        Text Processing,3.10
        Processor Apply,1016.60
        Model Generation,6788.70
        Batch Decoding,0.80
     */

    // Create input messages
    const messages = [
        {
            role: "user",
            content: [
                { type: "image" },
                { type: "text", text: "Can you describe this artistic image?" },
            ],
        },
    ];

    // Prepare inputs
    logTime("Text Processing");
    const text = processor.apply_chat_template(messages, { add_generation_prompt: true });
    logTime("Text Processing");

    logTime("Processor Apply");
    const inputs = await processor(text, [image1], {
        do_image_splitting: false,
    });
    logTime("Processor Apply");

    // Generate outputs
    logTime("Model Generation");
    const generated_ids = await model.generate({
        ...inputs,
        max_new_tokens: 500,
    });
    logTime("Model Generation");

    logTime("Batch Decoding");
    const generated_texts = processor.batch_decode(
        generated_ids.slice(null, [inputs.input_ids.dims.at(-1), null]), 
        { skip_special_tokens: true },
    );
    logTime("Batch Decoding");

    /**
     * The image is a photograph of the statue of the Lady in the Park in New York City.
     * The statue is located in the center of the image and is surrounded by the sky.
     * The statue is green and has a statue of the Lady in the center.
     * The statue is made of granite and is surrounded by a blue and white backdrop.
     * The statue is surrounded by trees and there is a blue and white backdrop.
     */

    return generated_texts[0];

};
