# App Review Notes — Ctrlr

## Overview

Ctrlr is the iPhone half of a two-part system. It **requires the free CtrlrHelper Mac
companion app** running on the same WiFi network. Without the companion, the app
displays a setup guide screen — this is intentional and expected behavior, not a bug.

## How It Works

- Ctrlr (iPhone) acts as a wireless MIDI controller
- CtrlrHelper (Mac) runs as a menu-bar app and bridges Ctrlr to your DAW via MIDI
- Communication is over **local WiFi network via TCP + Bonjour** (not Bluetooth, not cellular)
- Both devices must be on the **same WiFi network**

## Test Setup for Review

1. **Install CtrlrHelper on a Mac** — download from:
   <<CtrlrHelper distribution link — Wes to fill at submission>>

2. **Launch CtrlrHelper** — it appears as a menu-bar icon. No configuration required.

3. **Open Ableton Live** (or any MIDI DAW) on the same Mac.

4. **Open Ctrlr on the iPhone** — the setup guide screen will dismiss automatically
   and the app will show a green connection indicator when CtrlrHelper is detected.

5. **Test controls:**
   - PLAY / STOP / RECORD buttons → transport controls in the DAW
   - Volume fader → master volume (MIDI CC 7)
   - Macro pads → MIDI-learnable via the "Ctrlr Map" port (enable Remote in Ableton
     MIDI preferences to assign macros)

## No Login Required

The app requires no user account, no sign-in, and no internet connection. All
communication is local-network only.

## Expected Behavior Without the Companion

If the reviewer does not have a Mac with CtrlrHelper installed, the app will display
a three-step setup guide screen explaining how to connect. This is the designed
behavior — the app is waiting for the companion to appear on the local network.
