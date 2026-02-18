# Ctrlr (iOS 16.0+): XcodeGen Project

## Quick Start
1) Open Terminal in this folder and run:
   ```bash
   ./generate.sh
   open Ctrlr.xcodeproj
   ```
2) Select your iPhone and **Run**.

- Bundle ID: com.sinaudio.Ctrlr
- Deployment Target: iOS 16.0
- SwiftUI + CoreMIDI (Transport + Fader)
- Ableton mapping: see `AbletonUserRemoteScript_Ctrlr/UserConfiguration.txt`

## Manual Install (if you already have XcodeGen)
```bash
xcodegen generate --spec project.yml
```
