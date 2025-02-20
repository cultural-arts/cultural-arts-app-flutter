import { pipeline } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3';


// Load the model asynchronously and attach to window
let pipe = null;

(async function () {
    pipe = await pipeline("sentiment-analysis");
    console.log("transformers.js pipeline loaded successfully!");

    // Attach function to globalThis so Dart can access it
    globalThis.analyzeSentiment = async function (text) {
        if (!pipe) {
            throw new Error("Pipeline is not yet loaded!");
        }
        console.log("return await pipe(...)")
        return await pipe(text);
    };
})();