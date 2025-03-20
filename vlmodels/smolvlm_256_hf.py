import torch
import os
import time
from PIL import Image
from transformers import AutoProcessor, AutoModelForVision2Seq
from transformers.image_utils import load_image

from loguru import logger

os.environ["HF_HUB_DISABLE_SYMLINKS_WARNING"] = "1"

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

# Load images
# image = load_image("https://cdn.britannica.com/61/93061-050-99147DCE/Statue-of-Liberty-Island-New-York-Bay.jpg")
image = load_image(r"C:\Users\s.brazzo\Desktop\workspace\ca\cultural-arts-app-flutter\web\Statue-of-Liberty-Island-New-York-Bay.jpg")

# Initialize processor and model
processor = AutoProcessor.from_pretrained("HuggingFaceTB/SmolVLM-256M-Instruct")
model = AutoModelForVision2Seq.from_pretrained(
    "HuggingFaceTB/SmolVLM-256M-Instruct",
    torch_dtype=torch.bfloat16,
    _attn_implementation="flash_attention_2" if DEVICE == "cuda" else "eager",
).to(DEVICE)

# Create input messages
messages = [
    {
        "role": "user",
        "content": [
            {"type": "image"},
            {"type": "text", "text": "Can you describe this image?"}
        ]
    },
]

ts1 = time.time()

# Prepare inputs
prompt = processor.apply_chat_template(messages, add_generation_prompt=True)
inputs = processor(text=prompt, images=[image], return_tensors="pt")
inputs = inputs.to(DEVICE)

logger.info(f"Preprocessing inputs {time.time() - ts1}s")

ts2 = time.time()

# Generate outputs
generated_ids = model.generate(**inputs, max_new_tokens=500)
generated_texts = processor.batch_decode(
    generated_ids,
    skip_special_tokens=True,
)

logger.info(f"Preprocessing inputs {time.time() - ts2}s")

"""
GPU

2025-02-18 17:11:02.315 | INFO     | __main__:<module>:44 - Preprocessing inputs 0.46349620819091797s
2025-02-18 17:11:36.394 | INFO     | __main__:<module>:55 - Preprocessing inputs 34.07909536361694s

CPU

2025-02-18 17:13:00.838 | INFO     | __main__:<module>:45 - Preprocessing inputs 0.4088890552520py752s
2025-02-18 17:34:52.065 | INFO     | __main__:<module>:56 - Preprocessing inputs 1311.227169752121s
"""

print(generated_texts[0])