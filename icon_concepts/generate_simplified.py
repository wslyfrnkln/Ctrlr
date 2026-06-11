#!/usr/bin/env python3
"""Simplify refined_1_minimal — keep the identity, reduce elements."""

import os

os.environ["GEMINI_API_KEY"] = "AIzaSyBl8ic22USqx7LP1rSNZScmhE4q0X2hTGg"

from google import genai
from google.genai import types

client = genai.Client()

# Read the refined_1_minimal icon
with open("/Users/wesleyodd/Development/SinAudio/Ctrlr App/icon_concepts/refined_1_minimal.png", "rb") as f:
    img_bytes = f.read()

prompts = [
    (
        "simplified_1",
        "This iOS app icon has too many elements. Simplify it drastically. "
        "Keep ONLY the fader/slider and the red record button — remove everything else. "
        "Same dark background, same color palette, but just two elements max. "
        "More negative space. Clean, minimal, professional. 1024x1024 square iOS app icon."
    ),
    (
        "simplified_2",
        "This iOS app icon is too busy. Reduce it to just the vertical fader/slider "
        "on the dark background. One single element. Keep the same dark color scheme "
        "but give the fader a subtle glow or accent color to make it pop. "
        "Maximum simplicity. 1024x1024 square iOS app icon following Apple HIG."
    ),
    (
        "simplified_3",
        "This iOS app icon needs simplification. Keep the MIDI controller identity "
        "but reduce to one hero element: the red record button with a subtle green LED dot. "
        "Dark background, lots of breathing room. Should be instantly recognizable "
        "at 60x60 pixels. 1024x1024 square, clean iOS app icon style."
    ),
]

for name, prompt in prompts:
    print(f"Generating {name}...")
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash-image",
            contents=[
                types.Content(
                    role="user",
                    parts=[
                        types.Part.from_bytes(data=img_bytes, mime_type="image/png"),
                        types.Part.from_text(text=prompt),
                    ],
                )
            ],
            config={"response_modalities": ["IMAGE", "TEXT"]},
        )
        for part in response.candidates[0].content.parts:
            if hasattr(part, "inline_data") and part.inline_data:
                path = f"/Users/wesleyodd/Development/SinAudio/Ctrlr App/icon_concepts/{name}.png"
                with open(path, "wb") as f:
                    f.write(part.inline_data.data)
                print(f"  Saved: {path}")
                break
        else:
            print("  No image returned")
    except Exception as e:
        print(f"  Error: {e}")

print("\nDone.")
