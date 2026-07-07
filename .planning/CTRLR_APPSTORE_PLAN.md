---
plan: CTRLR_APPSTORE_PLAN
title: Ctrlr — App Store First Publish
created: 2026-07-06
category: plan
track: P
out_of_roadmap: true
---

# Ctrlr — App Store First Publish

## Context

Proof-of-concept first publish of the Ctrlr iOS app (`com.sinaudio.Ctrlr`) to the
App Store. Goal is *shipped*, not perfect: submit what exists, no new features, no
V2 UI rewiring (V2 is already the live UI via `ContentView` → `CtrlrV2View`), no
BLE. Governing fork: **submission-first** — every task minimal, targeted, and
git-reversible where possible.

Source brainstorm: `.planning/APP_STORE_SUBMISSION_BRAINSTORM.md`. Three assumptions
corrected against the actual source:

- Brainstorm assumed `UserDefaults` usage requiring `NSPrivacyAccessedAPICategoryUserDefaults`
  (reason `CA92.1`). Grep of all six source files finds zero `UserDefaults`, `@AppStorage`,
  file-timestamp, disk-space, or active-keyboard API usage. The correct minimal manifest
  is an *empty-declarations* `PrivacyInfo.xcprivacy`. Task 1.3 gates on a re-grep before writing.
- Brainstorm proposed creating a `SetupGuideView`. It already exists (`ContentView.swift:190`)
  but is only rendered inside the device-picker sheet when `midi.destinations.isEmpty`.
  Task 2.1 surfaces the existing view on the main screen when disconnected — no new view authored.
- Brainstorm missed the App Store description, which claims "Bluetooth MIDI" five times
  (`Documentation/APP_STORE_DESCRIPTION.md`). The app has zero Bluetooth — it's WiFi/TCP +
  Bonjour + a Mac companion. This is a direct 2.3.1 metadata-mismatch rejection vector
  and contradicts removing the Bluetooth entitlements. Task 4.0 corrects the copy first.

Distribution is unblocked: Developer Program enrolled, `Apple Distribution: WESLEY
FRANKLIN ODD` (Team ID `UQH23Q44F9`) confirmed in Keychain; `sinaudio.co` hosts the
live privacy policy + support surface; screenshots exist at correct ASC dimensions.

## Codebase Context

**Stack:** Swift 6.2 / SwiftUI, iOS 16.0+, `TARGETED_DEVICE_FAMILY=1` (iPhone only).
Build system is XcodeGen (`Ctrlr_XcodeGen/project.yml`) — `.xcodeproj` is generated,
never hand-edited. Networking: CoreMIDI (output-only) + Network.framework TCP listener
on port `51235` + Bonjour `_ctrlr._tcp`. No mic, no CoreBluetooth, no custom crypto.

**Architecture:** `CtrlrApp.swift` (`@main`) → `ContentView` (thin wrapper; `body` =
`CtrlrV2View(...).sheet(DevicePickerView)`) → `CtrlrV2View` (677 lines, live UI).
State: `MIDIManager` (`ObservableObject`, `@MainActor`) owns connection state
(`connectionState`, `companionConnected: Bool`, computed `isConnected`); `AppModel`
owns fader + macro/note definitions. iPhone is the TCP *server*; CtrlrHelper connects
in. `SetupGuideView` (`ContentView.swift:190`) exists as an in-sheet empty-state.

**Key files:**
- `Ctrlr_XcodeGen/Sources/Info.plist` — edit here, not the generated `.xcodeproj`
- `Ctrlr_XcodeGen/Sources/ContentView.swift` — app entry UI + SetupGuideView definition
- `Ctrlr_XcodeGen/Sources/MIDIManager.swift` — connection state, `isConnected` computed
- `Documentation/APP_STORE_DESCRIPTION.md` — listing copy (has Bluetooth references — Task 4.0)
- Build: `cd Ctrlr_XcodeGen && ./generate.sh && ./build.sh`

**Concerns:**
- `Info.plist:13-15` declares false `NSMicrophoneUsageDescription`, `NSBluetoothAlwaysUsageDescription`,
  `NSBluetoothPeripheralUsageDescription` — no backing code. Binary-validation rejection risk.
- No `PrivacyInfo.xcprivacy` (required since Xcode 15/iOS 17 — binary validation rejects).
- No `ITSAppUsesNonExemptEncryption` (ASC blocks the build for encryption compliance).
- `MIDIManager` is output-only (known gap): arm/loop state can invert when DAW already holds state.
- App is inert without `CtrlrHelper` on a same-WiFi Mac → reviewer hits a "No Device" dead state.
- Working branch: `v2.1-min-ux`.

## Scope

**In scope:**
- Remove three false Info.plist usage strings; add `ITSAppUsesNonExemptEncryption=false`.
- Add an empty-declarations `PrivacyInfo.xcprivacy`.
- Surface the existing `SetupGuideView` on the main screen when disconnected.
- Draft App Review Notes explaining the Mac-companion requirement.
- Correct the App Store description to WiFi/local-network (remove all Bluetooth claims).
- Physical-device QA of ARM/LOOP, Fwd/Rwd MMC, MIDI Learn.
- Create/confirm the ASC app record, configure free listing, upload existing screenshots.
- Archive a release build and submit for review.

**Out of scope:** New features, BLE MIDI (branch stays parked), MIDI input port,
`@Observable` migration, test suite, new screenshot sizes (expand only on reviewer reject),
any edit to `~/Music/Ableton/`.

## Phases

### Phase 1 — Info.plist + Privacy Manifest

**Autonomy:** autonomous — four exact-string changes to a tracked plist + one new
empty-declarations manifest; acceptance is `plutil -lint` + build exit 0; fully
git-reversible; no protected files.
**Commit:** `fix(ctrlr): strip false mic/BT entitlements, add encryption flag + privacy manifest`
**Verify:** `plutil -lint "Ctrlr_XcodeGen/Sources/Info.plist"` and `plutil -lint "Ctrlr_XcodeGen/Sources/PrivacyInfo.xcprivacy"` both print `OK`; `cd Ctrlr_XcodeGen && ./generate.sh && ./build.sh` exits 0.

#### Task 1.1 — Remove false mic + Bluetooth usage strings

**Status:** not_started
**Wave:** 1
**Files:** `Ctrlr_XcodeGen/Sources/Info.plist`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/Info.plist`
**Action:** Delete exactly these three `<key>`/`<string>` pairs from Info.plist:
`NSMicrophoneUsageDescription` (line 13), `NSBluetoothAlwaysUsageDescription` (line 14),
`NSBluetoothPeripheralUsageDescription` (line 15). Leave `NSLocalNetworkUsageDescription`,
`NSBonjourServices` (`_ctrlr._tcp`, `_apple-midi._tcp`, `_apple-midi._udp`), and all
other keys untouched — those are correct and required.
**Verify:** `grep -cE 'NSMicrophoneUsageDescription|NSBluetoothAlwaysUsageDescription|NSBluetoothPeripheralUsageDescription' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/Info.plist"` prints `0`.
**Acceptance:** `grep -cE 'NSMicrophone|NSBluetooth' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/Info.plist"` returns `0` AND `plutil -lint` returns `OK`.
**Done:** Info.plist declares no microphone or Bluetooth usage strings and lints clean.
**Delegate:** sonnet

#### Task 1.2 — Add ITSAppUsesNonExemptEncryption = false

**Status:** not_started
**Wave:** 1
**Files:** `Ctrlr_XcodeGen/Sources/Info.plist`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/Info.plist`
**Dependencies:** Task 1.1
**Action:** Add `<key>ITSAppUsesNonExemptEncryption</key><false/>` inside the top-level
`<dict>`, adjacent to `LSRequiresIPhoneOS`. App uses only HTTPS + OS-provided TLS and
no custom cryptography — encryption-exempt.
**Verify:** `plutil -extract ITSAppUsesNonExemptEncryption raw "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/Info.plist"` prints `false`.
**Acceptance:** Output of the above command is `false`.
**Done:** Encryption-compliance is declared; ASC will not block the build on it.
**Delegate:** sonnet

#### Task 1.3 — Author + add empty-declarations PrivacyInfo.xcprivacy

**Status:** not_started
**Wave:** 1
**Files:** `Ctrlr_XcodeGen/Sources/PrivacyInfo.xcprivacy`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/AppModel.swift`, `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/MIDIManager.swift`
**Action:** First run the gating grep:
`grep -rn 'UserDefaults\|@AppStorage\|attributesOfItem\|modificationDate\|creationDate\|systemFreeSize\|volumeAvailableCapacity\|activeInputModes' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/"`
If no matches (confirmed 2026-07-06): write `PrivacyInfo.xcprivacy` as a standard Apple
privacy manifest plist with `NSPrivacyTracking → false`, `NSPrivacyTrackingDomains →
empty array`, `NSPrivacyCollectedDataTypes → empty array`, `NSPrivacyAccessedAPITypes →
empty array`. If the grep returns any match, STOP and surface it — do not guess a category.
XcodeGen globs `Sources/`, so the file is auto-included; run `./generate.sh` to fold it in.
**Verify:** `plutil -lint "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/PrivacyInfo.xcprivacy"` prints `OK`; after `./generate.sh`, `grep -q PrivacyInfo "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Ctrlr.xcodeproj/project.pbxproj"` succeeds.
**Acceptance:** `plutil -lint` returns `OK` AND `plutil -extract NSPrivacyTracking raw` returns `false`.
**Done:** An empty-declarations privacy manifest ships in the app bundle, satisfying binary validation.
**Delegate:** sonnet

---

### Phase 2 — Mac Companion Onboarding

**Autonomy:** autonomous — surfaces an existing `SetupGuideView` behind a `!midi.isConnected`
conditional in one file + writes one plain-text notes doc; no new SwiftUI pattern; reversible.
**Dependencies:** Phase 1
**Commit:** `feat(ctrlr): show setup guide when disconnected + App Review notes`
**Verify:** `cd Ctrlr_XcodeGen && ./generate.sh && ./build.sh` exits 0; `Documentation/APP_REVIEW_NOTES.md` exists.

#### Task 2.1 — Surface existing SetupGuideView on main screen when disconnected

**Status:** not_started
**Wave:** 1
**Files:** `Ctrlr_XcodeGen/Sources/ContentView.swift`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/ContentView.swift`, `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/CtrlrV2View.swift`
**Action:** In `ContentView.body`, attach an overlay to the existing `CtrlrV2View(...)` call
that shows `SetupGuideView(midi: midi)` whenever `!midi.isConnected`:
```swift
CtrlrV2View(...)
  .overlay {
    if !midi.isConnected {
      SetupGuideView(midi: midi)
        .background(Color(hex: "#e8e4dc").ignoresSafeArea())
    }
  }
```
`midi.isConnected` is the computed `Bool` already on `MIDIManager`. Do not modify
`SetupGuideView` itself, do not create a new view. Keep the existing
`.sheet(isPresented: $showDevicePicker)` modifier intact.
**Verify:** `grep -c 'SetupGuideView(midi: midi)' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Sources/ContentView.swift"` returns `2` (existing sheet path + new overlay); `./build.sh` exits 0.
**Acceptance:** Count is `2` AND build succeeds.
**Done:** Launching the app with no Mac companion shows the setup guide; connecting hides it.
**Delegate:** sonnet

#### Task 2.2 — Draft App Review Notes

**Status:** not_started
**Wave:** 1
**Files:** `Documentation/APP_REVIEW_NOTES.md`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/CLAUDE.md`
**Action:** Write a plain-text notes file (pasted into ASC "App Review Information → Notes"
at submission) covering: (a) Ctrlr is the iPhone half of a two-part system requiring
the free **CtrlrHelper** Mac menu-bar companion on the same WiFi; (b) both devices must
be on the **same WiFi network** (local-network TCP + Bonjour, not Bluetooth); (c) with
no companion the app correctly shows a setup guide (expected, not a bug); (d) test steps:
install CtrlrHelper on a Mac, launch it, open Ableton Live (or any MIDI DAW), confirm
green connection dot, then transport/fader/macros drive the DAW. Include placeholder:
`<<CtrlrHelper distribution link — Wes to fill at submission>>`.
**Verify:** `grep -qi 'CtrlrHelper' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/APP_REVIEW_NOTES.md"` and `grep -qi 'same WiFi'` both succeed.
**Acceptance:** File exists and contains "CtrlrHelper" and "same WiFi".
**Done:** Submission-ready reviewer notes explaining the companion requirement exist on disk.
**Delegate:** sonnet

---

### Phase 3 — Device QA Gate

**Autonomy:** manual — requires physical iPhone + Mac running CtrlrHelper + Ableton Live;
no shell command can verify DAW transport response; Wes executes and records.
**Dependencies:** Phase 2
**Commit:** `docs(ctrlr): record Phase 3 device QA results + connected-state screenshot`
**Verify:** `Documentation/DEVICE_QA_RESULTS.md` records pass/fail for all three controls;
connected-state screenshot exists under `Screenshots/`.

#### Task 3.1 — Verify ARM/LOOP single-press toggle

**Status:** not_started
**Wave:** 1
**Files:** `Documentation/DEVICE_QA_RESULTS.md`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/CLAUDE.md`
**Action:** On physical iPhone with CtrlrHelper + Ableton Live, press ARM then LOOP once
each. Confirm each toggles the corresponding Ableton state (CC 65 arm, CC 66 loop).
Note the known output-only inversion caveat (CLAUDE.md) — record actual behavior verbatim.
Record result (pass / pass-with-caveat / fail) in `DEVICE_QA_RESULTS.md`.
**Verify:** `grep -qi 'ARM/LOOP' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/DEVICE_QA_RESULTS.md"` exits 0.
**Acceptance:** File contains `ARM/LOOP:` line with explicit verdict.
**Done:** ARM/LOOP behavior on device is recorded.
**Delegate:** wes

#### Task 3.2 — Verify Fwd/Rwd MMC commands

**Status:** not_started
**Wave:** 1
**Files:** `Documentation/DEVICE_QA_RESULTS.md`
**Dependencies:** Task 3.1
**Action:** Press ≪ (RWD, MMC `0x05`) and ≫ (FWD, MMC `0x04`). Confirm Ableton
playhead advances/rewinds. Record verdict.
**Verify:** `grep -qi 'MMC' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/DEVICE_QA_RESULTS.md"` exits 0.
**Acceptance:** File contains `Fwd/Rwd MMC:` line with explicit verdict.
**Done:** Fwd/Rwd transport behavior recorded.
**Delegate:** wes

#### Task 3.3 — Verify MIDI Learn via "Ctrlr Map" port

**Status:** not_started
**Wave:** 1
**Files:** `Documentation/DEVICE_QA_RESULTS.md`
**Dependencies:** Task 3.2
**Action:** In Ableton MIDI prefs enable Remote on "Ctrlr Map" input port, enter MIDI
Map mode, tap a macro pad (notes 68–82), assign to an Ableton parameter. Confirm
mapping takes. Record verdict.
**Verify:** `grep -qi 'MIDI Learn' "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/DEVICE_QA_RESULTS.md"` exits 0.
**Acceptance:** File contains `MIDI Learn:` line with explicit verdict.
**Done:** MIDI Learn via Ctrlr Map port recorded.
**Delegate:** wes

#### Task 3.4 — Capture connected-state screenshot

**Status:** not_started
**Wave:** 2
**Files:** `Screenshots/connected-state.png`
**Dependencies:** Task 3.1
**Action:** With app connected (green dot), capture device screenshot showing live
connected UI. Save to `Screenshots/connected-state.png` — evidence and potential
App Store screenshot replacement if reviewer flags current set.
**Verify:** `test -f "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Screenshots/connected-state.png"`.
**Acceptance:** File exists.
**Done:** A connected-state screenshot exists on disk.
**Delegate:** wes

---

### Phase 4 — App Store Connect Setup

**Autonomy:** manual — browser/ASC actions requiring the signed-in Apple Developer
account. Task 4.0 (description correction) is autonomous.
**Dependencies:** Phase 3
**Commit (Task 4.0 only):** `docs(ctrlr): correct App Store description to WiFi/local-network`
**Verify:** ASC record exists for `com.sinaudio.Ctrlr`, Free, Music category, listing
filled with Bluetooth-free copy, both screenshot sizes uploaded, URLs set;
`grep -ci bluetooth Documentation/APP_STORE_DESCRIPTION.md` == 0.

#### Task 4.0 — Correct App Store description: WiFi/local-network, not Bluetooth

**Status:** not_started
**Wave:** 1
**Files:** `Documentation/APP_STORE_DESCRIPTION.md`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/APP_STORE_DESCRIPTION.md`
**Action:** The description claims "Bluetooth" five times. The app uses WiFi/TCP +
Bonjour + Mac companion — zero Bluetooth. Leaving this copy triggers a 2.3.1
metadata-mismatch rejection and contradicts Phase 1's entitlement removal. Rewrite:
- "SEAMLESS BLUETOOTH MIDI" → "SEAMLESS WIRELESS MIDI"
- "via Bluetooth—no cables" → "over your local WiFi network—no cables"
- "Mac with Bluetooth MIDI support" → "Mac on the same WiFi running CtrlrHelper"
- keyword "bluetooth" → "wifi" or "network"
Do not add new feature claims — only correct the transport medium.
**Verify:** `grep -ci bluetooth "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/APP_STORE_DESCRIPTION.md"` returns `0`.
**Acceptance:** Count is `0`.
**Done:** Listing copy describes WiFi/local-network MIDI with zero Bluetooth claims.
**Delegate:** sonnet

#### Task 4.1 — Create/confirm ASC app record

**Status:** not_started
**Wave:** 2
**Files:** (App Store Connect — no local file)
**Dependencies:** Task 4.0
**Action:** In App Store Connect, confirm whether an app record for `com.sinaudio.Ctrlr`
(Team `UQH23Q44F9`) already exists; if not, create one — Platform iOS, Primary Language
English (U.S.), Bundle ID `com.sinaudio.Ctrlr`, SKU `ctrlr-ios`, Primary Category
**Music**, Secondary Category **Utilities**.
**Verify:** App appears in ASC "My Apps" with bundle `com.sinaudio.Ctrlr`.
**Acceptance:** Visual confirm in ASC.
**Done:** ASC app record for the correct bundle ID exists.
**Delegate:** wes

#### Task 4.2 — Configure pricing, availability, age rating

**Status:** not_started
**Wave:** 3
**Files:** (App Store Connect — no local file)
**Dependencies:** Task 4.1
**Action:** Set Price to **Free**, Availability to **all territories**, complete Age
Rating (all "None" → expected 4+; no objectionable content, no UGC, no ads).
**Verify:** ASC Pricing shows Free, all territories, age rating assigned.
**Acceptance:** Visual confirm in ASC.
**Done:** Pricing, availability, and age rating set.
**Delegate:** wes

#### Task 4.3 — Fill store listing (name, subtitle, description, keywords, URLs)

**Status:** not_started
**Wave:** 3
**Files:** (App Store Connect — no local file)
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/APP_STORE_DESCRIPTION.md`
**Dependencies:** Task 4.1, Task 4.0
**Action:** Fill ASC listing from corrected `APP_STORE_DESCRIPTION.md`: App Name **Ctrlr**,
Subtitle "MIDI Controller for Your DAW", corrected long description, corrected keywords,
**Support URL** `https://sinaudio.co`, **Privacy Policy URL** from `sinaudio.co`.
**Verify:** ASC listing fields populated with Bluetooth-free copy; both URLs set.
**Acceptance:** Visual confirm — name Ctrlr, zero "Bluetooth" in description, both URLs present.
**Done:** Store listing fully populated with corrected copy.
**Delegate:** wes

#### Task 4.4 — Upload existing screenshots

**Status:** not_started
**Wave:** 3
**Files:** `Screenshots/AppStore/6.5in/IMG_9531.PNG`, `Screenshots/AppStore/6.7in/IMG_9531.PNG`
**Dependencies:** Task 4.1
**Action:** Upload the existing 6.5" (1284×2778) and 6.7" (1290×2796) screenshots to
their matching ASC slots. Expand only if reviewer rejects for missing sizes — then use
the connected-state capture from Task 3.4.
**Verify:** ASC shows a screenshot in each of the 6.5" and 6.7" slots.
**Acceptance:** Visual confirm — both slots non-empty.
**Done:** Both required screenshot sizes uploaded.
**Delegate:** wes

---

### Phase 5 — Archive + Submit

**Autonomy:** assisted — archive is deterministic `xcodebuild`; upload/submit is
irreversible external; agent runs the archive, Wes confirms and executes the submit.
**Dependencies:** Phase 4
**Commit:** `chore(ctrlr): archive v1.0(1) release build for App Store submission`
**Verify:** Signed `.xcarchive` exists; build appears in ASC as processed; version
submitted for review with App Review Notes pasted.

#### Task 5.1 — Archive release build

**Status:** not_started
**Wave:** 1
**Files:** `build/Ctrlr.xcarchive`
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/project.yml`
**Action:** Regenerate the project (`cd Ctrlr_XcodeGen && ./generate.sh`), then archive:
```bash
xcodebuild archive \
  -project "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Ctrlr_XcodeGen/Ctrlr.xcodeproj" \
  -scheme Ctrlr \
  -destination 'generic/platform=iOS' \
  -archivePath "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/build/Ctrlr.xcarchive" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=UQH23Q44F9
```
If automatic signing fails to resolve a Distribution profile, surface the error to Wes —
do not silently switch signing mode.
**Verify:** `test -d "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/build/Ctrlr.xcarchive"` exits 0.
**Acceptance:** Directory exists AND `xcodebuild` returned exit 0.
**Done:** A signed release `.xcarchive` for Team `UQH23Q44F9` exists.
**Delegate:** sonnet

#### Task 5.2 — Export IPA for App Store distribution

**Status:** not_started
**Wave:** 2
**Files:** `build/export/Ctrlr.ipa`
**Dependencies:** Task 5.1
**Action:** Wes chooses: (a) Xcode Organizer → Distribute App → App Store Connect, or
(b) CLI `xcodebuild -exportArchive -archivePath build/Ctrlr.xcarchive -exportPath build/export
-exportOptionsPlist ExportOptions.plist` (author plist with `method=app-store`,
`teamID=UQH23Q44F9`, `signingStyle=automatic`). Surface the choice rather than assuming.
**Verify:** `test -f "/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/build/export/Ctrlr.ipa"` (CLI) OR Organizer reports success.
**Acceptance:** IPA exists at `build/export/Ctrlr.ipa` OR Organizer confirms export.
**Done:** A distributable App Store build is exported.
**Delegate:** wes

#### Task 5.3 — Upload build + submit for review

**Status:** not_started
**Wave:** 3
**Files:** (App Store Connect — no local file)
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/APP_REVIEW_NOTES.md`
**Dependencies:** Task 5.2
**Action:** Upload via Xcode Organizer (Distribute → Upload) or `xcrun altool --upload-app`.
Wait for ASC processing (~5–15 min), attach build to the version, then click **Submit for
Review**. This is irreversible — confirm with Wes before the final submit.
**Verify:** ASC version status reads "Waiting for Review".
**Acceptance:** Visual confirm in ASC.
**Done:** Ctrlr build uploaded and submitted for App Review.
**Delegate:** wes

#### Task 5.4 — Paste App Review Notes into submission

**Status:** not_started
**Wave:** 3
**Files:** (App Store Connect — no local file)
**Read first:** `/Users/wesleyodd/Judo/projects/SinAudio/Ctrlr App/Documentation/APP_REVIEW_NOTES.md`
**Dependencies:** Task 5.3
**Action:** Before finalizing the submit, paste `APP_REVIEW_NOTES.md` contents into ASC
"App Review Information → Notes". Fill the `<<CtrlrHelper distribution link>>` placeholder
with the actual download URL. Confirm contact phone/email are set. Leave demo-account
fields blank (no login required).
**Verify:** ASC Notes field contains CtrlrHelper + same-WiFi instructions with no `<<...>>` placeholder.
**Acceptance:** Visual confirm — notes present, placeholder filled.
**Done:** Reviewer sees companion-app setup instructions at review time.
**Delegate:** wes

---

## Verification

Plan is complete when:
- **Phase 1:** `plutil -lint` passes on both Info.plist + PrivacyInfo.xcprivacy; zero mic/BT strings; `ITSAppUsesNonExemptEncryption=false`; build succeeds.
- **Phase 2:** App shows `SetupGuideView` over main UI when `!midi.isConnected`; `APP_REVIEW_NOTES.md` explains CtrlrHelper + same-WiFi requirement.
- **Phase 3:** `DEVICE_QA_RESULTS.md` records explicit verdicts for ARM/LOOP, Fwd/Rwd MMC, MIDI Learn; connected-state screenshot exists. No advertised feature confirmed broken without a copy correction.
- **Phase 4:** ASC record for `com.sinaudio.Ctrlr`, Free, Music; `grep -ci bluetooth APP_STORE_DESCRIPTION.md` == 0; both screenshot sizes uploaded; support + privacy URLs set.
- **Phase 5:** Signed `.xcarchive` produced; build uploaded + processed; version status "Waiting for Review"; App Review Notes pasted with CtrlrHelper link filled.

## Risks

- **[HIGH] Reviewer cannot exercise the app without a Mac companion.** Inert without CtrlrHelper on same-WiFi Mac → likely 2.1 rejection. Mitigation: Phase 2 in-app setup guide + Phase 5 App Review Notes with download link and test-rig steps.
- **[HIGH] Metadata mismatch — Bluetooth claims vs. no-Bluetooth app.** Description claims Bluetooth five times while binary has no Bluetooth code/entitlements → 2.3.1 rejection. Mitigation: Task 4.0 corrects all copy.
- **[MED] Output-only MIDI inversion.** ARM/LOOP can invert when DAW holds state (known gap). If QA shows a hard failure, drop/soften the description claim rather than ship broken. Mitigation: Task 3.1 records actual behavior.
- **[MED] Network/MIDI apps draw longer review queues + local-network scrutiny.** `NSLocalNetworkUsageDescription` already present; App Review Notes preempt reviewer confusion.
- **[LOW] Encryption-compliance stall.** Without `ITSAppUsesNonExemptEncryption`, ASC blocks the build. Mitigation: Task 1.2 sets it `false`.
- **[LOW] Screenshot set is one-per-size.** Sufficient; expand only on reject.

## Edge Cases

- **[HIGH] Reviewer WiFi isolation.** Apple's review network may block Bonjour/mDNS. Notes frame the setup guide as expected behavior and explain the same-WiFi requirement.
- **[MED] Device-only MIDI behavior.** CoreMIDI + TCP handshake differ on device vs. simulator. Phase 3 is device-only for this reason — no simulator QA counts.
- **[MED] Bonjour on enterprise/guest WiFi.** Client-isolation APs silently drop `_ctrlr._tcp`; connection never forms. Out of scope to fix; Notes set the expectation.
- **[MED] Distribution cert expiry.** Cert confirmed in Keychain today; if Task 5.1 fails signing, surface the error — do not silently switch modes.
- **[LOW] XcodeGen glob drops new manifest.** `sources: [Sources]` auto-includes `PrivacyInfo.xcprivacy`; Task 1.3 verifies it lands in `project.pbxproj` after `generate.sh`.
- **[LOW] `CFBundleVersion` collision on re-upload.** Bump `CFBundleVersion` if Task 5.3 upload errors with a duplicate-build message (reactive — first publish).

## Rollback Plan

- **Phase 1–2 (code):** all changes on `v2.1-min-ux`, revert-sized — `git revert` restores prior Info.plist / ContentView; deleting `PrivacyInfo.xcprivacy` + `generate.sh` removes it from build.
- **Phase 3 (QA docs):** documentation-only; `git rm` if needed.
- **Phase 4 (ASC):** listing is editable until submission. App record persists Apple-side but causes no harm unversioned.
- **Phase 5:** a submitted review can be withdrawn in ASC before approval; a bad build is superseded by uploading a higher `CFBundleVersion`.

## Lifecycle

**Owner:** N/A — no new persistent local state introduced. Info.plist, `PrivacyInfo.xcprivacy`,
onboarding overlay, and docs are static build inputs versioned in git; ASC state is
Apple-owned, mutated only through ASC by Wes.
**Staleness signal:** App Store description drifting back to Bluetooth claims —
`grep -ci bluetooth Documentation/APP_STORE_DESCRIPTION.md` at any future listing edit.
**Reconciliation:** re-run Phase 1 lints + Bluetooth grep before any resubmission.

## must_haves

```yaml
must_haves:
  behaviors:
    - "Info.plist declares zero mic or Bluetooth usage strings (grep -cE 'NSMicrophone|NSBluetooth' == 0)"
    - "Info.plist sets ITSAppUsesNonExemptEncryption = false"
    - "PrivacyInfo.xcprivacy exists, lints OK, is empty-declarations manifest bundled by XcodeGen"
    - "App shows SetupGuideView over main UI when !midi.isConnected"
    - "App Store description contains zero Bluetooth references (grep -ci bluetooth == 0)"
    - "xcodebuild archive produces a signed .xcarchive under Team UQH23Q44F9"
  artifacts:
    - path: Ctrlr_XcodeGen/Sources/Info.plist
      not_stub: true
    - path: Ctrlr_XcodeGen/Sources/PrivacyInfo.xcprivacy
      not_stub: true
    - path: Ctrlr_XcodeGen/Sources/ContentView.swift
      not_stub: true
    - path: Documentation/APP_REVIEW_NOTES.md
      not_stub: true
    - path: Documentation/APP_STORE_DESCRIPTION.md
      not_stub: true
```
