#!/usr/bin/env python3
"""Generate refined Ctrlr icon concepts from the original icon via Gemini."""

import os
import base64

os.environ["GEMINI_API_KEY"] = "AIzaSyBl8ic22USqx7LP1rSNZScmhE4q0X2hTGg"

from google import genai
from google.genai import types

client = genai.Client()

# Read the original icon
og_path = "/Users/wesleyodd/Development/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/Assets.xcassets/AppIcon.appiconset/Ctrlr-AppIcon-1024.png"
with open(og_path, "rb") as f:
    og_bytes = f.read()

prompts = [
    (
        "refined_1_minimal",
        "This is the current app icon for 'Ctrlr', an iOS MIDI controller app. "
        "Redesign it following Apple's Human Interface Guidelines for app icons: "
        "single focal point, simple silhouette recognizable at small sizes, no text, "
        "consistent visual weight. Keep the dark theme and MIDI controller identity "
        "but make it cleaner, more abstract, and more professional. "
        "Reduce to one or two hero elements. 1024x1024 square, iOS app icon style."
    ),
    (
        "refined_2_modern",
        "This is the current app icon for a wireless MIDI controller iOS app called 'Ctrlr'. "
        "It has too many elements and doesn't read well at small sizes. "
        "Redesign following Apple HIG: simplify to ONE focal element inspired by this icon "
        "(fader, knob, or transport button), use the dark background but add a single "
        "vibrant accent color. Make it feel premium, modern, and instantly recognizable "
        "on a home screen. 1024x1024 square, flat/minimal iOS icon style."
    ),
    (
        "refined_3_bold",
        "This is the app icon for 'Ctrlr', an iOS app that wirelessly controls music DAWs. "
        "Redesign it to be bolder and more iconic. Take the essence — the fader, the red "
        "record button, the green status LED — and distill it into one powerful symbol. "
        "Dark background. High contrast. Should look great at 60x60 and 1024x1024. "
        "Apple iOS app icon guidelines: simple, memorable, no text. 1024x1024 square."
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
                        types.Part.from_bytes(data=og_bytes, mime_type="image/png"),
                        types.Part.from_text(text=prompt),
                    ],
                )
            ],
            config={
                "response_modalities": ["IMAGE", "TEXT"],
            },
        )
        for part in response.candidates[0].content.parts:
            if hasattr(part, "inline_data") and part.inline_data:
                img_bytes = part.inline_data.data
                path = f"/Users/wesleyodd/Development/SinAudio/Ctrlr App/icon_concepts/{name}.png"
                with open(path, "wb") as f:
                    f.write(img_bytes)
                print(f"  Saved: {path}")
                break
        else:
            txt = ""
            for part in response.candidates[0].content.parts:
                if hasattr(part, "text") and part.text:
                    txt += part.text
            print(f"  No image. Text: {txt[:300]}")
    except Exception as e:
        print(f"  Error: {e}")

print("\nDone.")
