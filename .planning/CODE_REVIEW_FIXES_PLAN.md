# Implementation Plan: Ctrlr Code Review Fixes

## Overview

13 fixes from code review across MIDIManager.swift (iOS), ConnectionManager.swift (Mac Helper), ContentView.swift, and AppModel.swift. Grouped into 4 phases by risk: critical memory safety and concurrency, high-priority UX and error handling, medium cleanup, and low dead-code removal. One commit per phase. Branch: `feature/code-review-fixes` from `main`.

## Requirements

- Fix use-after-free on MIDI notification pointer
- Migrate MIDIPacketList construction to Builder API (iOS + Mac)
- Add @MainActor to ObservableObject classes with @Published GCD mutations
- Remove false-confidence ARM/LOOP state latching
- Make PLAY/RECORD transport buttons honest (no persistent highlight without DAW feedback)
- Add TCP send error handling (`.contentProcessed`)
- Guard against zero-length recursion in receiveMIDI
- Check OSStatus returns in Mac Helper setupVirtualMIDI
- Consolidate duplicate macro arrays
- Add `[weak self]` in sendPacket closure
- Clamp MIDI channel parameter
- Remove dead code (DiagRow, HomeIndicator, InstallError.copyFailed)
- Fix font name inconsistency

## Architecture Changes

- `MIDIManager.swift`: Add `@MainActor`, fix notification callback, migrate packet builder, TCP error handling, weak self, channel clamping
- `ConnectionManager.swift`: Add `@MainActor`, migrate packet builder, add recursion guard, check OSStatus
- `ContentView.swift`: Remove armOn/loopOn @State, make transport momentary, consolidate macros into AppModel, remove dead views, fix font name
- `AppModel.swift`: Add macro definitions array, mark `@MainActor`
- `ScriptInstaller.swift`: Remove unused `copyFailed` case

## Implementation Steps

---

### Phase 1: Critical — Memory Safety + Concurrency (1 commit)

**Dependency note:** @MainActor annotation (task 3) must land first because tasks 1 and 2 modify the same files and need to compile against the new actor context.

#### Task 3: Add @MainActor to ObservableObject classes

**File:** `Ctrlr_XcodeGen/Sources/MIDIManager.swift`

- Add `@MainActor` to class declaration: `@MainActor final class MIDIManager: ObservableObject`
- Mark `init()` as `@MainActor` (implicit from class annotation)
- Mark CoreMIDI callback in `setupMIDI()` as `nonisolated`: The `MIDIClientCreateWithBlock` closure cannot be `@MainActor`. It already dispatches to main via `handleMIDINotification` — after task 1 fix, the closure body is synchronous pointer read + `Task { @MainActor in ... }`, which is correct
- Mark `NWConnection.stateUpdateHandler` closures: These already dispatch to `DispatchQueue.main.async` — replace with `Task { @MainActor in ... }` or keep GCD dispatch (both valid under @MainActor class). Prefer `Task { @MainActor in }` for consistency
- Mark `NWListener` handler closures similarly
- `startMIDIServer()`, `acceptMacConnection()`, `restartServer()` — all called from main, implicitly @MainActor from class. No change needed
- The `sendPacket()` method is called from UI actions (main actor). CoreMIDI send functions are thread-safe — no issue

**File:** `Ctrlr_MacHelper/Sources/ConnectionManager.swift`

- Add `@MainActor` to class declaration: `@MainActor final class ConnectionManager: NSObject, ObservableObject`
- NSObject inheritance: `@MainActor` on the class is fine with NSObject
- `NWBrowser` and `NWConnection` handler closures already use `DispatchQueue.main.async` — replace with `Task { @MainActor in }` for consistency
- `dns-sd` pipe readability handler runs on arbitrary thread — wrap main-dispatch calls in `Task { @MainActor in }`
- `receiveMIDI(from:)` — the NWConnection receive callback is not main-isolated. The body dispatches UI updates to main already. The `self?.route(msg)` call touches CoreMIDI only (thread-safe). Wrap the `DispatchQueue.main.async` calls in `Task { @MainActor in }` or leave GCD (both work)
- `route(_ data:)` only calls `MIDIReceived` (thread-safe C API) — mark `nonisolated` so it can be called from non-main contexts without compiler complaints
- `setupVirtualMIDI()` calls CoreMIDI setup functions — called from `init()` which is @MainActor. Fine as-is (CoreMIDI setup is main-thread safe)

**File:** `Ctrlr_XcodeGen/Sources/AppModel.swift`

- Add `@MainActor` to class declaration: `@MainActor final class AppModel: ObservableObject`
- This is trivial — all properties are already only mutated from SwiftUI views (main actor)

**Risk:** Medium. Compiler may surface new isolation warnings in closures. Each closure needs individual attention.

---

#### Task 1: Fix use-after-free on MIDI notification pointer

**File:** `Ctrlr_XcodeGen/Sources/MIDIManager.swift` (line 206-215)

Current code captures `UnsafePointer<MIDINotification>` across async boundary (`DispatchQueue.main.async`). The pointer is only valid for the duration of the callback.

**Change `handleMIDINotification` to:**
```swift
private nonisolated func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
    let messageID = notification.pointee.messageID
    Task { @MainActor [weak self] in
        guard let self else { return }
        switch messageID {
        case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
            self.refreshDestinations()
            self.attemptReconnect()
        default:
            self.refreshDestinations()
        }
    }
}
```

Key changes:
1. Read `notification.pointee.messageID` synchronously (before any async hop)
2. Capture the value type `messageID` into the async block
3. Mark `nonisolated` since it is called from CoreMIDI's callback thread
4. Use `Task { @MainActor in }` instead of `DispatchQueue.main.async` (consistent with @MainActor class)

**Risk:** Low. Value type capture is safe. `Task { @MainActor in }` schedules on next main run loop tick (same semantics as DispatchQueue.main.async).

---

#### Task 2a: Migrate MIDIPacketList to Builder — iOS

**File:** `Ctrlr_XcodeGen/Sources/MIDIManager.swift` (line 303-311)

Current code:
```swift
var packetList = MIDIPacketList(numPackets: 1, packet: MIDIPacket())
withUnsafeMutablePointer(to: &packetList) { ptr in
    let pkt = MIDIPacketListInit(ptr)
    if MIDIPacketListAdd(ptr, 1024, pkt, 0, data.count, data) != nil {
        let r = MIDISend(outPort, dest, ptr)
        ...
    }
}
```

**Replace with MIDIPacketList.Builder (iOS 14+):**
```swift
let builder = MIDIPacketList.Builder(byteSize: 256)
builder.append(timestamp: 0, data: data)
let r = builder.withUnsafePointer { ptr in
    MIDISend(outPort, dest, ptr)
}
if r != noErr {
    lastError = .sendFailed(r)
    connectionState = .error
}
```

Notes:
- 256 bytes is generous for single MIDI messages (max 6 bytes for SysEx in this app)
- No more hardcoded 1024 byte claim on a stack-allocated struct
- Error handling is now synchronous (we are on @MainActor), no need for DispatchQueue.main.async
- `builder.withUnsafePointer` manages the buffer lifetime correctly

**Risk:** Low. Builder API available since iOS 14, deployment target is iOS 16.

---

#### Task 2b: Migrate MIDIPacketList to Builder — Mac Helper

**File:** `Ctrlr_MacHelper/Sources/ConnectionManager.swift` (line 258-267)

Current `route(_ data:)` method:
```swift
private func route(_ data: Data) {
    let bytes = [UInt8](data)
    var packetList = MIDIPacketList(numPackets: 1, packet: MIDIPacket())
    withUnsafeMutablePointer(to: &packetList) { ptr in
        let pkt = MIDIPacketListInit(ptr)
        _ = MIDIPacketListAdd(ptr, 1024, pkt, 0, bytes.count, bytes)
        MIDIReceived(virtualSource, ptr)
        MIDIReceived(mapSource, ptr)
    }
}
```

**Replace with:**
```swift
private nonisolated func route(_ data: Data) {
    let bytes = [UInt8](data)
    let builder = MIDIPacketList.Builder(byteSize: 256)
    builder.append(timestamp: 0, data: bytes)
    builder.withUnsafePointer { ptr in
        MIDIReceived(virtualSource, ptr)
        MIDIReceived(mapSource, ptr)
    }
}
```

Notes:
- Mark `nonisolated` because `route` is called from NWConnection receive callback (not main actor). `MIDIReceived` is thread-safe
- `virtualSource` and `mapSource` are `MIDIEndpointRef` (UInt32 value types set once in init) — accessing from nonisolated context is safe. If compiler complains about actor isolation, capture them as local lets at call site

**Risk:** Low. Same Builder API, macOS 11+ (Mac Helper target is current macOS).

---

### Phase 2: High — UX Honesty + Error Handling (1 commit)

#### Task 4: Make ARM/LOOP momentary (remove false state)

**File:** `Ctrlr_XcodeGen/Sources/ContentView.swift`

Step 1 — Remove @State vars from ContentView (lines 17-18):
- Delete `@State private var armOn = false`
- Delete `@State private var loopOn = true`

Step 2 — Update ArmLoopSection call site (line 73-77):
- Remove `armOn: $armOn` and `loopOn: $loopOn` bindings
- ArmLoopSection no longer takes bindings

Step 3 — Rewrite `ArmLoopSection` (line 597-629):
```swift
struct ArmLoopSection: View {
    @ObservedObject var midi: MIDIManager

    var body: some View {
        HStack(spacing: 8) {
            MomentaryButton(
                label: "ARM",
                color: "#ff3b30",
                action: {
                    midi.sendCC(cc: 65, value: 127)
                    midi.sendCC(cc: 65, value: 0)
                }
            )
            MomentaryButton(
                label: "LOOP",
                color: "#ff9500",
                action: {
                    midi.sendCC(cc: 66, value: 127)
                    midi.sendCC(cc: 66, value: 0)
                }
            )
        }
    }
}
```

Step 4 — Convert `ArmLoopButton` to `MomentaryButton`:
- Remove `isActive` parameter
- Button always shows inactive styling (dim LED, dark background)
- On tap: brief visual flash (use `@State private var flashing = false` with 0.15s auto-reset)
- This makes it honest: "I sent the command" not "I think the DAW state is X"

**Risk:** Low. Removes code, no new dependencies.

---

#### Task 5: Make PLAY/RECORD transport honest

**File:** `Ctrlr_XcodeGen/Sources/ContentView.swift` (TransportSection, lines 690-753)

Current: `model.isPlaying = true` persists highlight forever. No DAW feedback to clear it.

**Change approach — "last sent" indicator with auto-dim:**

Step 1 — Add timestamp to AppModel:
```swift
// In AppModel.swift
@Published var lastPlayTime: Date?
@Published var lastRecordTime: Date?
```

Step 2 — In TransportSection, PLAY action:
```swift
model.lastPlayTime = Date()
midi.sendNoteOn(note: model.notePlay)
midi.sendNoteOff(note: model.notePlay)
midi.sendMMC(command: 0x02)
```

Step 3 — In TransportSection, compute isPlaying from recency:
```swift
// In TransportSection body, use a TimelineView or simple approach:
// Pass `isPlaying: false` to TransportPlayButton always (no persistent highlight)
// OR use a 1.5s timer-based dim
```

**Simpler approach (preferred):** Remove `isPlaying`/`isRecording` from AppModel entirely. Make PLAY and RECORD purely momentary like STOP already is. Add `@State private var playPressed = false` and `@State private var recordPressed = false` local to TransportSection, with the same press-and-release pattern STOP uses.

Step-by-step:
1. Remove `isPlaying` and `isRecording` from AppModel.swift
2. In TransportSection, add `@State private var playPressed = false` and `@State private var recordPressed = false`
3. Convert TransportPlayButton to use `onPressChanged` pattern (matching TransportStopButton)
4. Convert TransportRecordButton to use `onPressChanged` pattern
5. PLAY action: `playPressed = isPressed; if isPressed { midi.sendNoteOn(...); midi.sendNoteOff(...); midi.sendMMC(...) }`
6. RECORD action: same pattern

This makes all three transport buttons behave identically — momentary highlight while finger is down, no persistent state.

**Risk:** Low. Removes misleading state, simplifies logic.

---

#### Task 6: TCP send error handling

**File:** `Ctrlr_XcodeGen/Sources/MIDIManager.swift` (line 293-295)

Current:
```swift
conn.send(content: Data([UInt8(data.count)] + data), completion: .idempotent)
```

**Replace with:**
```swift
conn.send(content: Data([UInt8(data.count)] + data), completion: .contentProcessed({ [weak self] error in
    if let error {
        Task { @MainActor in
            self?.companionConnected = false
            self?.companionDebug = "tcp send failed: \(error)"
        }
    }
}))
```

Also fix the handshake ping in `acceptMacConnection` (line 179):
```swift
self.macConnection?.send(content: Data([0x01, 0xFF]), completion: .contentProcessed({ _ in }))
```
(Handshake failure is non-critical — just use empty handler, or log to companionDebug.)

**Risk:** Low. Straightforward API change.

---

#### Task 7: receiveMIDI zero-length recursion guard

**File:** `Ctrlr_MacHelper/Sources/ConnectionManager.swift` (line 235-256)

Current: If the length byte is 0, the inner `connection.receive(minimumIncompleteLength: 0, ...)` fires immediately, causing synchronous recursion until stack overflow.

**Add guard after reading length byte:**
```swift
connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
    guard let length = data?.first, error == nil else { return }
    guard length > 0 else {
        // Invalid frame — skip and continue listening
        self?.receiveMIDI(from: connection)
        return
    }
    connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { ... }
}
```

The outer `receiveMIDI` call with `minimumIncompleteLength: 1` will wait for the next byte from the network, breaking any tight loop. The recursion only happens when there is actual data to process.

**Risk:** Low.

---

#### Task 8: Check OSStatus in Mac Helper setupVirtualMIDI

**File:** `Ctrlr_MacHelper/Sources/ConnectionManager.swift` (line 40-44)

Current:
```swift
MIDIClientCreateWithBlock("CtrlrHelper" as CFString, &midiClient) { _ in }
MIDISourceCreate(midiClient, "Ctrlr" as CFString, &virtualSource)
MIDISourceCreate(midiClient, "Ctrlr Map" as CFString, &mapSource)
```

**Replace with:**
```swift
private func setupVirtualMIDI() {
    let clientStatus = MIDIClientCreateWithBlock("CtrlrHelper" as CFString, &midiClient) { _ in }
    guard clientStatus == noErr else {
        updateDebug("MIDI client failed: \(clientStatus)")
        return
    }

    let srcStatus = MIDISourceCreate(midiClient, "Ctrlr" as CFString, &virtualSource)
    if srcStatus != noErr {
        updateDebug("Ctrlr source failed: \(srcStatus)")
    }

    let mapStatus = MIDISourceCreate(midiClient, "Ctrlr Map" as CFString, &mapSource)
    if mapStatus != noErr {
        updateDebug("Ctrlr Map source failed: \(mapStatus)")
    }

    updateDebug()
}
```

**Risk:** Low. Adds logging, no behavior change on success path.

---

### Phase 3: Medium — Cleanup + Consistency (1 commit)

#### Task 9: Consolidate duplicate macro arrays

**File:** `Ctrlr_XcodeGen/Sources/AppModel.swift`

Add canonical macro definitions:
```swift
struct MacroDef {
    let icon: String
    let color: String
    let note: UInt8
    let name: String
    let mmc: UInt8?
}

// All 12 macros — QuickAccessView slices [0..<6], FullMacrosView uses all 12
static let allMacros: [MacroDef] = [
    MacroDef(icon: "↶", color: "#ff6b35", note: 68, name: "UNDO", mmc: nil),
    MacroDef(icon: "↷", color: "#ff6b35", note: 69, name: "REDO", mmc: nil),
    MacroDef(icon: "⊕", color: "#00d4ff", note: 70, name: "DUPLICATE", mmc: nil),
    MacroDef(icon: "◆", color: "#ff3b30", note: 73, name: "DELETE", mmc: nil),
    MacroDef(icon: "≪", color: "#3498db", note: 81, name: "RWD", mmc: 0x05),
    MacroDef(icon: "≫", color: "#3498db", note: 82, name: "FWD", mmc: 0x04),
    // Full grid extras (indices 6-11)
    MacroDef(icon: "⚑", color: "#ffcc00", note: 72, name: "MARKER", mmc: nil),
    MacroDef(icon: "●", color: "#00ff88", note: 74, name: "RECORD", mmc: nil),
    MacroDef(icon: "■", color: "#9b59b6", note: 75, name: "STOP", mmc: nil),
    MacroDef(icon: "▲", color: "#3498db", note: 76, name: "UP", mmc: nil),
    MacroDef(icon: "⬟", color: "#f39c12", note: 79, name: "OPTIONS", mmc: nil),
    MacroDef(icon: "✦", color: "#1abc9c", note: 80, name: "FAVORITE", mmc: nil),
]

static var quickAccessMacros: [MacroDef] { Array(allMacros.prefix(6)) }
```

**File:** `Ctrlr_XcodeGen/Sources/ContentView.swift`

- In `QuickAccessView`: Replace local `macros` array with `AppModel.quickAccessMacros`, update ForEach to use `AppModel.quickAccessMacros[i]`
- In `FullMacrosView`: Replace local `macros` array with `AppModel.allMacros`, update ForEach to use `AppModel.allMacros[i]`

**Risk:** Low. Data-only refactor, no logic changes.

---

#### Task 10: Weak self in sendPacket TCP closure

**File:** `Ctrlr_XcodeGen/Sources/MIDIManager.swift`

This is already addressed by Task 6 — the `.contentProcessed` replacement uses `[weak self]`. If the CoreMIDI error dispatch on line 308 is still using strong self after Phase 1 changes, also fix:

Current (line 308, after Phase 1 rewrite):
```swift
if r != noErr {
    lastError = .sendFailed(r)
    connectionState = .error
}
```

Under @MainActor, this is fine — `self` is implicitly captured and we are on the main actor already. No closure capture involved. **No change needed** — the strong self concern was about the DispatchQueue.main.async closure that Phase 1 removes.

Mark as resolved by Phase 1 + Phase 2 changes.

---

#### Task 11: MIDI channel clamping

**File:** `Ctrlr_XcodeGen/Sources/MIDIManager.swift` (lines 313-315)

Current:
```swift
func sendNoteOn(note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) { sendPacket([0x90 | channel, note, velocity]) }
func sendNoteOff(note: UInt8, channel: UInt8 = 0)                       { sendPacket([0x80 | channel, note, 0]) }
func sendCC(cc: UInt8, value: UInt8, channel: UInt8 = 0)                { sendPacket([0xB0 | channel, cc, value]) }
```

**Add `& 0x0F` to channel in status byte:**
```swift
func sendNoteOn(note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) { sendPacket([0x90 | (channel & 0x0F), note, velocity]) }
func sendNoteOff(note: UInt8, channel: UInt8 = 0)                       { sendPacket([0x80 | (channel & 0x0F), note, 0]) }
func sendCC(cc: UInt8, value: UInt8, channel: UInt8 = 0)                { sendPacket([0xB0 | (channel & 0x0F), cc, value]) }
```

**Risk:** Low. Defense-in-depth — currently all callers pass channel 0, but this prevents corruption if channel is ever parameterized.

---

### Phase 4: Low — Dead Code + Font Fix (1 commit)

#### Task 12: Remove dead code

**File:** `Ctrlr_XcodeGen/Sources/ContentView.swift`

1. **Delete `DiagRow` struct** (lines 1096-1117) — unused. The actual diagnostic rows use `DiagnosticRow` (defined at line 1286). Verify with grep: `DiagRow` appears only in its own definition; all call sites use `DiagnosticRow`.

2. **Delete `HomeIndicator` struct** (lines 941-948) — unused. Not referenced anywhere in ContentView or other files.

**File:** `Ctrlr_MacHelper/Sources/ScriptInstaller.swift`

3. **Remove `case copyFailed(String)`** from `InstallError` enum (line 37) and its switch case (line 42). Never thrown anywhere — `install()` lets `FileManager.copyItem` throw its own error directly.

**Risk:** Low. Pure deletion of unreferenced code.

---

#### Task 13: Fix font name inconsistency

**Files affected:**
- `ContentView.swift` line 909: `.font(.custom("DigitalDismay", size: 25))` — NO SPACE
- `LaunchScreenView.swift` line 40: `.font(.custom("Digital Dismay", size: 13))` — WITH SPACE

The font file is `Digital Dismay.otf`. The PostScript name (what `.custom()` uses) needs verification:

**Verification step:** Run `fc-scan` or `otfinfo` on the font file to get PostScript name. Alternatively: the name registered in Info.plist (line 23) is `Digital Dismay.otf` (filename, not PS name). The `.custom()` initializer uses the **PostScript name**, not the filename.

**Likely fix:** The PostScript name for "Digital Dismay" fonts is typically `"DigitalDismay"` (no space). The LaunchScreenView usage with space is likely wrong (would fall back to system font silently).

**Action:**
1. Determine correct PostScript name from font file metadata
2. Use that name consistently in both files
3. If uncertain, keep `"DigitalDismay"` (no space) since ContentView.swift uses it and the branding renders correctly there

**Risk:** Low. Worst case: one view was already silently falling back to system font, fix makes it render correctly.

---

## Verification Strategy

No test suite exists. Verification for each phase:

| Phase | Verification |
|-------|-------------|
| Phase 1 (Critical) | Clean build with zero warnings. No new compiler errors from @MainActor isolation. |
| Phase 2 (High) | Clean build. Visual inspection: ARM/LOOP/PLAY/RECORD no longer latch. |
| Phase 3 (Medium) | Clean build. Macro grids render same content (same notes, icons, colors). |
| Phase 4 (Low) | Clean build. No "unused" warnings. Font renders in both views. |

For each phase: `cd Ctrlr_XcodeGen && ./build.sh` must pass.

If XcodeBuildMCP is available, also: `build_run_sim` + `screenshot` to verify UI renders correctly after Phase 2 (transport buttons) and Phase 4 (font).

## Commit Plan

```
git checkout -b feature/code-review-fixes

# Phase 1
git add -A && git commit  # "fix: memory safety + @MainActor on ObservableObject classes"

# Phase 2
git add -A && git commit  # "fix: honest transport/arm/loop state, TCP error handling, Mac MIDI checks"

# Phase 3
git add -A && git commit  # "refactor: consolidate macro arrays, clamp MIDI channel"

# Phase 4
git add -A && git commit  # "chore: remove dead code, fix font name"
```

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| @MainActor causes cascade of isolation errors | Medium | High | Fix isolation errors one closure at a time. Mark CoreMIDI/NWConnection callbacks as `nonisolated` or wrap in `Task { @MainActor in }`. |
| MIDIPacketList.Builder API slightly different than expected | Low | Low | Builder is well-documented. Fallback: use `MIDIEventList` (MIDI 2.0 API, iOS 14+) if Builder has issues. |
| Font PostScript name guess is wrong | Low | Low | Test both names in a debug build. The one that renders correctly wins. |
| Removing isPlaying/isRecording breaks other code | Low | Medium | Grep for all references before deleting. Currently only used in TransportSection. |
| nonisolated `route()` accessing actor-isolated stored properties | Medium | Medium | `virtualSource` and `mapSource` are set once in init and never mutated. Capture as local lets if compiler rejects direct access. |

## Success Criteria

- [ ] All 13 review items addressed
- [ ] Clean build (zero warnings) for iOS target
- [ ] Clean build (zero warnings) for Mac Helper target
- [ ] No @Published mutations from non-main-actor contexts
- [ ] No UnsafePointer captured across async boundaries
- [ ] No hardcoded MIDIPacketList buffer sizes
- [ ] Transport/ARM/LOOP buttons are visually honest (no false state)
- [ ] TCP send failures surface to user via companionConnected = false
- [ ] Single source of truth for macro definitions
- [ ] No dead code remaining in scope
- [ ] Font name consistent across all views

## Edge Cases (from /brainstorm)

### Critical

1. **`nonisolated route()` accessing actor-isolated stored properties** — After adding `@MainActor` to `ConnectionManager`, marking `route()` as `nonisolated` means it cannot access `virtualSource` or `mapSource` — stored properties on a `@MainActor` class. The caller (`receiveMIDI`) has the same problem. **Mitigation:** Make `virtualSource` and `mapSource` `nonisolated(unsafe) let` properties (set once in `init`, never mutated), or store them as separate non-isolated constants outside the class.

2. **`deinit` on `@MainActor` ConnectionManager** — `deinit` is `nonisolated` by definition in Swift. It cannot access actor-isolated stored properties (`midiClient`, `virtualSource`, `mapSource`, `browser`, `discoveryProcess`, `phoneConnection`). This will be a compiler error. **Mitigation:** Move MIDI refs to `nonisolated(unsafe)` since they're set once in `init`, or move cleanup to a `func cleanup()` called before release.

### Important

3. **`MIDIPacketList.Builder` API exact signatures** — Verify `.append(timestamp:data:)` accepts `[UInt8]` on both iOS and macOS targets. If not, use `MIDIEventList` as fallback. **Mitigation:** Build-verify Phase 1 before moving on.

4. **Removing `isRecording` breaks toggle logic** — `model.isRecording.toggle()` currently controls whether pressing RECORD sends "start" or "stop" semantically. With momentary behavior, every press sends identical NOTE ON+OFF. This is correct IF Ableton handles the toggle internally (it does for the remote script). **Mitigation:** Verify Ableton remote script toggles record on CC regardless of current state.

5. **TCP `.contentProcessed` on hot path** — Fader CC sends 30+ per second during drag. `.contentProcessed` adds closure allocation + callback per send vs `.idempotent` fire-and-forget. **Mitigation:** Set `companionConnected = false` on first error only, skip subsequent callbacks while already disconnected. Or use `.contentProcessed` only for non-fader messages.

6. **`@MainActor` + `deinit` on `ConnectionManager`** — See Critical #2. Also applies to `MIDIManager` if it adds a `deinit` in the future.

### Awareness

7. **Handshake ping still `.idempotent`** — If handshake silently drops, Mac rejects after 5s timeout. Use `.contentProcessed` with log, not empty handler.

8. **Font verification** — `fc-scan`/`otfinfo` not standard on macOS. Use `mdls -name com_apple_ait_postscriptName "Digital Dismay.otf"` instead.

9. **`MacroDef` expands AppModel** — 17-line file → ~50 lines. Still under limits, just noting role change.

10. **Branch name generic** — `feature/code-review-fixes` may collide with future reviews. Consider `fix/code-review-2026-03`.
