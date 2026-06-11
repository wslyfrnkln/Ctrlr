#!/usr/bin/env python3
"""Generate Ctrlr app icon concepts via Gemini."""

import os
import base64

os.environ["GEMINI_API_KEY"] = "AIzaSyBl8ic22USqx7LP1rSNZScmhE4q0X2hTGg"

from google import genai

client = genai.Client()

prompts = [
    # 1 - Dark minimal fader
    (
        "concept_1_dark_fader",
        "Design an iOS app icon for a MIDI controller app called 'Ctrlr'. "
        "Dark background (#1C1C1E). A single stylized vertical fader/slider in the center, "
        "glowing with a subtle cyan (#00FFD1) accent line. Minimal, geometric, professional. "
        "No text. Square format, 1024x1024. Flat design with subtle depth. "
        "Apple iOS app icon style with rounded corners built in."
    ),
    # 2 - Bold geometric knob
    (
        "concept_2_bold_knob",
        "Design an iOS app icon for a music production MIDI controller app. "
        "A single large rotary knob viewed from above, centered on a dark charcoal background. "
        "The knob has a bright red (#FF3B30) position indicator mark. Subtle concentric rings "
        "around it suggesting precision. Modern, bold, clean. No text. 1024x1024 square. "
        "Apple iOS app icon style."
    ),
    # 3 - Signal/wireless motif
    (
        "concept_3_wireless_signal",
        "Design an iOS app icon for a wireless MIDI controller app. "
        "Abstract wireless signal arcs emanating from a stylized play button triangle, "
        "on a deep black background. Signal arcs in gradient from green (#34C759) to cyan. "
        "Futuristic, sleek, minimal. No text. 1024x1024 square. "
        "Apple iOS app icon style with clean vector aesthetics."
    ),
    # 4 - Letterform C
    (
        "concept_4_letterform_c",
        "Design an iOS app icon featuring a bold geometric letter 'C' that subtly "
        "incorporates a fader notch or MIDI connector shape in its negative space. "
        "Dark background with the C in a warm gold/amber (#FFD60A) color. "
        "Sophisticated, memorable, brandable. No other text. 1024x1024 square. "
        "Apple iOS app icon style, modern and premium."
    ),
]

for name, prompt in prompts:
    print(f"Generating {name}...")
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash-image",
            contents=prompt,
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
            print(f"  No image in response. Text: {response.text[:200] if response.text else 'none'}")
    except Exception as e:
        print(f"  Error: {e}")

print("\nDone.")
