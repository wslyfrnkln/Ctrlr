# Roadmap: Ctrlr

## Phase 0 — Setup
- [x] Project scaffold + CLAUDE.md
- [x] XcodeGen project

## Phase 1 — Core MIDI Surface
- [x] CoreMIDI connection
- [x] Dual MIDI port ("Ctrlr" + "Ctrlr Map")
- [x] Transport controls (play/stop/record/arm/loop)
- [x] Fwd/Rwd MMC SysEx
- [x] Launch screen + SinAudio logo
- [x] Mac companion app (CtrlrHelper) — MenuBarExtra, Bonjour auto-discovery
- [x] Ableton remote script auto-installer
- [x] App icon (all 13 sizes)
- [x] Code review fixes (@MainActor, MIDIPacketList.Builder, momentary transport, macro dedup)
- [ ] BLE MIDI support (parked — feature/ble-midi-handshake branch)
- [ ] Custom surface layout editor

## Phase 2 — QA & Device Testing
- [ ] Verify ARM/LOOP single-press works on physical iPhone
- [ ] Test Fwd/Rwd MMC commands in Ableton
- [ ] Test MIDI Learn via "Ctrlr Map" port
- [ ] Unit tests for MIDIManager and AppModel
- [ ] Remove SinAudio logo from ContentView header (layout fix)

## Phase 3 — App Store Submission
- [ ] Apple Developer Program ($99/year)
- [x] Register Bundle ID
- [ ] Create app in App Store Connect
- [ ] Distribution certificate & provisioning profile
- [ ] Screenshots (6.7", 6.5", 5.5", iPad 12.9")
- [ ] Support URL + Quick Start Guide
- [ ] Archive release build + submit

## Phase 4 — Advanced Controls
- [ ] MIDI input port (MIDIInputPortCreate) + Ableton feedback CCs
- [ ] Fader/knob MIDI CC mapping
- [ ] Multi-page surfaces
- [ ] Ableton Live integration (APC-style)
