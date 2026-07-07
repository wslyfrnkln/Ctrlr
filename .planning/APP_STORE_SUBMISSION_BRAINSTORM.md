# Brainstorm — Ctrlr App Store Submission (proof-of-concept first publish)

Sources read: `Ctrlr_XcodeGen/Sources/Info.plist`, `ContentView.swift`, `MIDIManager.swift`,
`CtrlrApp.swift`, `AppModel.swift`, `project.yml`, `PROJECT.md`, `.planning/ROADMAP.md`,
`.planning/PLAN.md`, `.planning/CODE_REVIEW_FIXES_PLAN.md`, `Screenshots/AppStore/`,
keychain (`security find-identity`), `sinaudio.co` live site, `decisions` table (no prior
Ctrlr submission-strategy decisions found).

---

## What I found

### Hard blockers (will reject upload or fail App Review)

1. **BLOCKING — False Bluetooth entitlement claims.** `Info.plist:14-15` declares
   `NSBluetoothAlwaysUsageDescription` + `NSBluetoothPeripheralUsageDescription`. `grep` across
   `ContentView.swift` and `MIDIManager.swift` for `Bluetooth|CBCentral|CBPeripheral` returns
   zero matches (verified this session). `MIDIManager.swift:1-3` imports only `Foundation`,
   `CoreMIDI`, `Network` — the transport is TCP via `NWConnection`/`NWBrowser`, not BLE. The
   BLE branch is parked per `CLAUDE.md` ("BLE MIDI branch... parked — do not merge into main").
   Two unused Bluetooth usage strings will trigger Apple's automated privacy-string/permission-usage
   scan (declared-but-unused entitlement is a documented rejection pattern, distinct from the
   mic issue below but same root cause).

2. **BLOCKING — False microphone entitlement claim.** `Info.plist:13`
   `NSMicrophoneUsageDescription` — same problem, zero mic usage anywhere in source (confirmed
   this session, matches the prompt's recon). MIDI over CoreMIDI/Network does not touch
   `AVAudioSession` or microphone APIs.

3. **BLOCKING — Missing `PrivacyInfo.xcprivacy`.** Confirmed absent (`find` returned nothing).
   Required manifest since Xcode 15 / iOS 17 SDKs — binary validation at upload time will
   reject a build compiled against a required-reason API (Network.framework's local network
   usage, UserDefaults, etc.) without a manifest declaring reason codes. This is a build-time
   Transporter/App Store Connect validation failure, not a review-time one — it can block
   upload entirely before a human reviewer ever sees the app.

4. **BLOCKING — Missing `ITSAppUsesNonExemptEncryption`.** Confirmed absent from `Info.plist`.
   Without it, every archive upload triggers the interactive export-compliance prompt in
   Xcode Organizer / Transporter. Not an automatic reject, but it **blocks unattended/scripted
   upload** and is trivial to fix (the app uses only standard HTTPS/TLS-adjacent networking —
   almost certainly qualifies for the standard exemption, `<false/>`).

### Account/infra blockers

5. **NOT a blocker — Apple Developer Program is active.** Keychain has both
   `Apple Development: WESLEY FRANKLIN ODD (25H9286TQC)` and
   `Apple Distribution: WESLEY FRANKLIN ODD (UQH23Q44F9)` valid identities under Team ID
   `UQH23Q44F9`. A Distribution identity is only issued to an enrolled paid-Program account —
   this settles the "$99/yr enrolled?" unknown the prompt flagged. PROJECT.md/ROADMAP.md still
   list "Apple Developer Program ($99/year)" as unchecked — **that checklist is stale**, not
   the actual account state.

6. **MEDIUM — No provisioning profile found locally.** `~/Library/MobileDevice/Provisioning
   Profiles/` doesn't exist on this machine. With Xcode 13+ "Automatically manage signing" this
   is normal/expected (Xcode generates profiles on-demand at archive time) — not itself a
   blocker, but means archive-and-sign has not yet been exercised end-to-end on this project.
   First real signing attempt is untested.

7. **UNKNOWN — App Store Connect app record.** No evidence checked (couldn't reach ASC via
   available tools) whether an app record exists for `com.sinaudio.Ctrlr`. ROADMAP.md marks
   "Create app in App Store Connect" unchecked. Needs a manual/browser check — this is the
   next concrete unknown to resolve, not a redo of settled facts.

### Decisions needed

1. **V1 vs V2 UI — already resolved, not open.** `ContentView.swift:11-16` is a ~17-line
   wrapper that renders `CtrlrV2View` directly (`return CtrlrV2View(midi:model:showDevicePicker:)`).
   `CtrlrApp.swift` loads `ContentView()`, which loads `CtrlrV2View`. **V2 is the live, shipping
   UI today.** The prompt's premise ("ContentView.swift still live, V2 NOT wired in") is stale —
   flag this correction to Wes explicitly since it changes the plan shape (no UI-swap decision
   needed, just verify V2 renders cleanly).

2. **Mac companion app dead-state in App Review — still open.** CtrlrHelper (macOS, not
   submitted) is required for the iOS app to do anything meaningful. A reviewer testing cold
   (no Mac, no Ableton) will see: Bonjour/TCP never finds a peer → `DevicePickerView` falls
   through to `SetupGuideView` (confirmed at `ContentView.swift:39-41`). Options:
   - **A: Rely on the SetupGuideView as review-facing explanation** — cheapest, if its copy
     clearly explains the companion-app requirement and shows expected behavior. Need to read
     `SetupGuideView` (not yet read this session) to judge if it's convincing enough alone.
   - **B: App Review notes field** — explain the Mac companion requirement, provide setup
     video/screenshots, offer a demo path. Zero code cost, always worth doing regardless of A.
   - **C: Provide reviewer test credentials/hardware access** — not really applicable here
     (no login system), likely N/A.
   - Recommendation leans A+B combined (cheap, standard practice for hardware/companion-app
     iOS apps) but Wes should confirm — this is a review-risk vs. effort tradeoff call.

3. **QA completeness threshold for "shipped" — needs explicit lowering, or explicit acceptance
   of current gaps.** ROADMAP.md Phase 2 has 4 unchecked items (ARM/LOOP single-press, Fwd/Rwd
   MMC, MIDI Learn via Ctrlr Map, unit tests). For a proof-of-concept first publish: which of
   these actually block submission vs. are polish that can ship as known-issues / v1.1?
   - Unit tests: near-certainly not an App Review blocker — internal quality bar only, defer.
   - ARM/LOOP + Fwd/Rwd + MIDI Learn: these are core advertised functionality (per PROJECT.md
     "MIDI-learnable macros" is in the app's own description) — if broken, this is a
     "app doesn't work as described" rejection risk, not just polish. Needs a real device pass
     before submission, not deferred.

4. **Screenshot set — technically present but thin, needs a decision on scope.** Found real
   screenshots at native resolution: `Screenshots/AppStore/6.5in/IMG_9531.PNG` (1284×2778) and
   `6.7in/IMG_9531.PNG` (1290×2796) — correct dimensions, confirmed via `sips`, and confirmed
   distinct content (different md5s, not a stretched duplicate). This satisfies Apple's
   *minimum* (1 screenshot per required size class) — the prompt's "no screenshots exist" claim
   is **stale/incorrect**, flag the correction. Open decision: is 1 screenshot per size enough
   for a POC launch, or does Wes want the traditional 3-5 screenshot set (mixer, macros, device
   picker, setup guide) showing more surface? 5.5" and iPad screenshots are absent — 5.5" is
   still technically requestable by Apple for legacy device support unless explicitly opted
   out; iPad is exempt since `TARGETED_DEVICE_FAMILY: "1"` (iPhone-only, confirmed in
   `project.yml:9`).

5. **Support URL — resolved, not open.** `sinaudio.co` is live (HTTP 200, confirmed this
   session) and already has a hosted, dated Privacy Policy section (`#privacy`, "Effective:
   May 15, 2026", confirmed via curl). PROJECT.md's "Privacy Policy: done" checkbox is accurate.
   Remaining open item: does App Store Connect need a *dedicated* support URL/page, or is
   `sinaudio.co` (marketing site) acceptable as both marketing + support URL? Commonly accepted
   as one and the same for small teams — likely fine, but confirm App Store Connect's field
   doesn't require a distinct "support" page vs. marketing page (it doesn't, per Apple's own
   guidelines — support URL can be any reachable page with contact info).

### Risks (App Review rejection vectors specific to this app)

- **HIGH — Guideline 2.1 (App Completeness) / functional dependency on hardware not in the
  reviewer's control.** MIDI/network-controller apps that require a companion device are a
  known rejection category if the dependency isn't explained. Mitigated by decision #2 above
  (SetupGuideView + review notes) but never fully eliminated — reviewers vary in patience.
- **MEDIUM — Guideline 2.3.1 (metadata mismatch)** if the App Store description promises
  MIDI Learn / macro functionality that Phase 2 QA hasn't confirmed works. Ties directly to
  decision #3 — don't ship a description claiming features that are unverified.
  Compounds with the *false entitlement* pattern (blockers #1/#2): reviewers who spot one
  mismatch (unused Bluetooth/mic permission) often scrutinize the rest of the metadata/feature
  claims harder.
- **MEDIUM — Local Network privacy prompt friction.** `NSLocalNetworkUsageDescription` +
  Bonjour services (`_ctrlr._tcp`, `_apple-midi._tcp/_udp`, `Info.plist:16-21`) trigger iOS
  14+'s local-network permission dialog on first launch. If the reviewer denies it (common
  reviewer behavior — they often decline optional-looking permissions), does the app fail
  gracefully or hang/crash? Untested per the recon — worth a real-device pass with Local
  Network permission explicitly denied.
- **LOW-MEDIUM — Export compliance ambiguity.** Once `ITSAppUsesNonExemptEncryption` is added
  as `<false/>`, this should be a non-issue for TCP/Bonjour/CoreMIDI traffic (no proprietary
  crypto). Flag if any TLS/cert-pinning code exists elsewhere that would change this answer —
  not found in the two files read, but MIDIManager/ContentView were the only files grepped for
  crypto-adjacent code.
- **LOW — Custom font bundling.** `Info.plist:22-24` declares `Digital Dismay.otf` via
  `UIAppFonts`. Standard practice, low risk, but confirm the font's license permits
  commercial app-store redistribution (unverified this session — outside file scope given).

### What's already done (don't repeat as tasks)

- CtrlrV2View is the live, wired-in UI (`ContentView.swift` renders it directly) — no UI
  migration decision needed.
- App icon: all sizes present including 1024px (per prompt recon, not re-verified pixel-by-pixel
  this session but no contradicting signal found).
- Apple Developer Program: **enrolled and active** (Distribution cert confirmed in keychain,
  Team ID UQH23Q44F9) — PROJECT.md/ROADMAP.md checkbox is simply unrefreshed.
- Bundle ID registered (`com.sinaudio.Ctrlr`, per ROADMAP.md, consistent with `project.yml:17`).
- Support/marketing site + Privacy Policy: live at `sinaudio.co`, dated May 15 2026, reachable
  now (HTTP 200 confirmed).
- 6.5" and 6.7" screenshots exist at correct native pixel dimensions (1284×2778, 1290×2796),
  confirmed distinct (not a duplicate/stretch).
- `TARGETED_DEVICE_FAMILY: "1"` — iPhone-only confirmed in `project.yml:9`, so no iPad
  screenshot requirement.
- App Store Description + Keywords marked done in PROJECT.md — **file location not found**
  this session (only PROJECT.md's checkbox, no actual copy file located) — treat as
  unconfirmed-artifact, not confirmed-done; note under Decisions/Unknowns for the plan, not
  re-listed as a fresh task from scratch.

---

## Assumptions (flag to confirm)

- Assuming `sinaudio.co` support URL is acceptable to App Store Connect without a
  dedicated `/support` subpage (standard for small dev accounts, but not independently
  verified against current App Store Connect UI requirements).
- Assuming the Bluetooth/mic entitlement removal is a pure Info.plist edit with no
  downstream Swift code depending on those permission prompts having fired (grep found no
  such code, but a full-file read of ContentView.swift beyond line 80 wasn't completed this
  session — only the top ~80 lines were read).
- Assuming "proof-of-concept first publish" means: functional core (transport + mixer CC)
  must work, MIDI Learn/macros can ship as "known limitation" if Phase 2 QA isn't clean by
  submission time — **this is actually decision #3, restated as an assumption Wes should
  confirm or reject explicitly**, since it changes what "done" means for Phase 2.

## Edge cases

- Reviewer denies Local Network permission on first launch — untested behavior.
- Reviewer has no Mac / Ableton available — falls to SetupGuideView, quality of that fallback
  not yet assessed (file not read this session).
- App Store Connect metadata (description/keywords) claims MIDI Learn works but Phase 2 QA
  item for it is unchecked — direct 2.3.1 risk if shipped as-is.
- First real archive+sign attempt is untested end-to-end (no local provisioning profile
  cached) — could surface signing friction that's invisible until attempted.

## Decisions needed

1. **Mac-companion dead-state handling in App Review** — SetupGuideView-only, or
   SetupGuideView + explicit App Review notes/demo materials? (recommend both; low cost)
2. **Phase 2 QA bar for this submission** — does ARM/LOOP, Fwd/Rwd MMC, and MIDI Learn need to
   be verified working on physical hardware before submit, or can any ship as documented
   known-issues? (recommend: verify on-device before submit if the App Store description
   claims these features — ties to 2.3.1 risk above)
3. **Screenshot scope** — ship with the existing 1-per-size-class set, or expand to a
   3-5 shot curated set before first submission? (POC-first bias says ship with what exists,
   but Wes should decide given it's a 5-minute Simulator/device capture either way)
4. **App Store Connect app record + actual description/keyword copy** — needs a direct
   App Store Connect check (browser session) since it's outside filesystem/DB tool reach this
   session — resolve before a submission plan can sequence "create app in ASC" vs. "app
   already exists, just needs build."

## Ready to plan?

**YES** — no blocking unknown prevents writing the plan. The four hard blockers (Bluetooth/mic
false claims, missing PrivacyInfo.xcprivacy, missing export-compliance key) are well-defined,
small, mechanical fixes with clear acceptance criteria. The Developer Program/certificate
unknown is resolved (active). The only two items needing Wes's input before/during planning are
decision #1 (Mac companion dead-state handling — recommend default, confirm) and decision #2
(QA bar — recommend verify-before-ship for advertised features), and the ASC app-record check
(a 2-minute browser look, not a blocker to drafting the plan itself — can be Task 1 of the plan).
