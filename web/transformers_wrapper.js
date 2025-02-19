import { pipeline } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3';

let pipe = null;

// Load the model asynchronously and attach to window
(async function () {
    pipe = await pipeline("sentiment-analysis");
    console.log("transformers.js pipeline loaded successfully!");

    // Attach function to window so Dart can access it
    window.analyzeSentiment = async function (text) {
        if (!pipe) {
            throw new Error("Pipeline is not yet loaded!");
        }
        return await pipe(text);
    };
})();