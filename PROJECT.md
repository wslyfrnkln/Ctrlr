# Ctrlr

**Last Updated:** 2026-03-02
**Status:** active
**Type:** iOS App
**Version:** 1.0 (Build 1)
**Bundle ID:** com.sinaudio.Ctrlr
**Company:** SinAudio
**Repo:** github.com/wslyfrnkln/Ctrlr
**Stack:** SwiftUI, iOS, CoreMIDI, BLE

---

## Brief Description

iOS wireless MIDI controller for Ableton Live. Connects over WiFi via Bonjour auto-discovery and a Mac companion app, sending MIDI transport controls, mixer CC, and MIDI-learnable macros to Ableton via dual virtual ports.

---

## Development Roadmap

### Phase 1 — Core App
**Goal:** Build working iOS MIDI controller with Ableton integration

**Deliverable:** Functional app sending transport, volume, and macro MIDI messages to Ableton over WiFi

- [x] Core iOS app UI (ContentView.swift)
- [x] MIDI communication (MIDIManager.swift)
- [x] App state management (AppModel.swift)
- [x] XcodeGen project setup
- [x] App Icon all 13 sizes
- [x] Launch screen (LaunchScreenView.swift + SinAudio logo)
- [x] Mac companion app (CtrlrHelper) — MenuBarExtra, auto-connect
- [x] Bonjour auto-discovery
- [x] MMC SysEx transport commands
- [x] DAW picker (Ableton/Logic/Other)
- [x] Ableton remote script auto-installer
- [x] Dual MIDI ports ("Ctrlr" + "Ctrlr Map" for MIDI Learn)
- [x] ARM/LOOP momentary pulse fix
- [x] Fwd/Rwd macro buttons with MMC SysEx
- [x] Styled diagnostic panel (green/red status dots)
- [x] Ableton UserConfiguration.txt mapping
- [x] Privacy Policy
- [x] App Store Description + Keywords
- [x] Copyright: © 2026 SinAudio

### Phase 2 — QA & Testing
**Goal:** Validate all MIDI functionality on physical hardware

**Deliverable:** All controls verified working in Ableton on physical iPhone

- [ ] Verify ARM/LOOP single-press works in Ableton after rebuild
- [ ] Test Fwd/Rwd (≪/≫) MMC commands in Ableton
- [ ] Test MIDI Learn via "Ctrlr Map" port with macro buttons
- [ ] Create unit tests for MIDIManager and AppModel

### Phase 3 — App Store Submission
**Goal:** Ship to App Store

**Deliverable:** App live on App Store

- [ ] Apple Developer Program ($99/year)
- [ ] Register Bundle ID
- [ ] Create app in App Store Connect
- [ ] Distribution certificate & provisioning profile
- [ ] iPhone 6.7" screenshot (1290 × 2796)
- [ ] iPhone 6.5" screenshot (1284 × 2778)
- [ ] iPhone 5.5" screenshot (1242 × 2208)
- [ ] iPad Pro 12.9" screenshot (2048 × 2732)
- [ ] App Preview video (optional, 15-30 sec)
- [ ] Support URL/webpage
- [ ] Quick Start Guide + Ableton Setup Instructions
- [ ] Archive release build + submit

---

## Notes

- Testing requires physical iPhone device (MIDI not available in Simulator).
- `Color(hex:)` SourceKit error in LaunchScreenView is a false positive — extension defined in ContentView.swift is module-accessible.
- Reference design: Breathpod app aesthetic.
- TCP: Fixed port 51235 (was random .any).
- ARM/LOOP: Send momentary pulse (127 then 0) every press. Ableton handles toggle internally.
- Macros: "Ctrlr Map" second port — enable Remote in Ableton prefs for MIDI Learn.

---

## App Structure

### iOS Source Files (`Ctrlr_XcodeGen/Sources/`)
| File | Purpose |
|------|---------|
| `CtrlrApp.swift` | App entry point (@main), launch screen |
| `AppModel.swift` | State management (ObservableObject) |
| `MIDIManager.swift` | CoreMIDI communication layer |
| `ContentView.swift` | All UI components (~1000 lines) |
| `ConnectionManager.swift` | Bonjour browser, dual MIDI ports |
| `ScriptInstaller.swift` | Ableton remote script installer |
| `LaunchScreenView.swift` | SwiftUI launch screen (1.2s + 0.4s fade) |

### Mac Helper (`Ctrlr_MacHelper/`)
| Component | Purpose |
|-----------|---------|
| `CtrlrHelperApp.swift` | MenuBarExtra, DAW picker, install button |
| `ConnectionManager.swift` | Bonjour auto-discovery, auto-connect |
| `Resources/AbletonScript/` | `__init__.py` + `Ctrlr.py` (bundled remote script) |

---

## Configuration Locations

| Config | Path |
|--------|------|
| Ableton Script (Local) | `/Ctrlr_XcodeGen/AbletonUserRemoteScript_Ctrlr/UserConfiguration.txt` |
| Ableton Script (Bundle) | `/Ctrlr_MacHelper/Resources/AbletonScript/` |
| Ableton Script (Target) | `~/Music/Ableton/User Library/Remote Scripts/Ctrlr/` |
| App Config | `/Ctrlr_XcodeGen/Sources/Info.plist` |
| XcodeGen Spec | `/Ctrlr_XcodeGen/project.yml` |

---

## MIDI Quick Reference

### Control Mapping
| Control | Type | Value | Description |
|---------|------|-------|-------------|
| Play | Note | 60 (C4) | Transport play |
| Stop | Note | 62 (D4) | Transport stop |
| Record | Note | 64 (E4) | Transport record |
| Volume | CC | 7 | Master fader (0-127) |
| Track Arm | CC | 65 | Toggle track arm |
| Loop | CC | 66 | Toggle loop mode |
| Fwd (≫) | Note + MMC | 68+ | Forward + SysEx 0x04 |
| Rwd (≪) | Note + MMC | 68+ | Rewind + SysEx 0x05 |
| Macros | Notes | 68-82 | MIDI-learnable via "Ctrlr Map" port |

### MMC Commands
| Command | SysEx Byte |
|---------|-----------|
| Stop | `0x01` |
| Play | `0x02` |
| Fast Forward | `0x04` |
| Rewind | `0x05` |
| Record | `0x06` |
| Pause | `0x09` |

---

## Troubleshooting Log

| Date | Issue | Fix |
|------|-------|-----|
| Session 5 | ARM/LOOP require double press | Send momentary pulse (127 then 0) every press. Ableton handles toggle internally. |
| Session 5 | Macro buttons not MIDI-learnable | Added "Ctrlr Map" second port — enable Remote in Ableton prefs for MIDI Learn. |
| Session 5 | UserConfiguration.txt wrong InputName | Renamed from "TrkCtrl Input" to "Ctrlr". |
| Session 4 | TCP race condition — stale .cancelled handler | Used `[weak connection]` capture + identity check in state handler. |
| Session 4 | Double-browse race condition in reconnect | Only `.cancelled` handler calls `startBrowsing()`. `reconnect()` just cancels. |
| Session 4 | NWBrowser discovering stale Simulator records | Added self-host filter, rejected endpoints set, 5-second handshake timeout. |

---

## Change Log

| Date | Change |
|------|--------|
| 2026-03-02 | Standardized to PROJECT.md template |
| 2026-02-26 | Refactored to PROJECT.md |
| 2026-02-20 | Launch screen (LaunchScreenView.swift + CtrlrApp.swift), SinAudio logo |
| 2026-02-19 | Dual MIDI port, ARM/LOOP fix, Fwd/Rwd, diagnostic panel, SinAudio logo |
| 2026-02-18 | TCP debugging + UI fine-tuning, screenshots.sh |
| 2026-02-18 | MMC support, DAW picker, Ableton auto-install |
| 2026-02-18 | Mac companion app (CtrlrHelper), Bonjour auto-discovery |
| 2026-02-18 | WiFi MIDI connection (Network MIDI) |
| 2026-02-17 | All icon sizes generated |
| 2026-02-17 | Rename TrkCtrl → Ctrlr complete |
| 2026-02-17 | App renamed Signal → Ctrlr |
| 2026-01-12 | Error handling, auto-reconnect, company rename Nomaudio → SinAudio |

---

## Model Usage

| Date | Model | Task | Est. Tokens |
|------|-------|------|-------------|
| 2026-03-02 | claude-sonnet-4-6 | PROJECT.md template standardization | ~400 |
| 2026-02-26 | claude-sonnet-4-6 | PROJECT.md refactor | ~300 |
| 2026-02-20 | claude-sonnet-4-6 | Launch screen | ~2,000 |
