import Foundation

// MARK: - Macro Definition

struct MacroDef {
    let icon: String
    let color: String
    let note: UInt8
    let name: String
    let mmc: UInt8?
}

// MARK: - App Model

@MainActor final class AppModel: ObservableObject {
    @Published var faderValue: Double = 0.7 // 0.0 ... 1.0

    // MIDI mapping (match Ableton UserConfiguration.txt)
    let notePlay: UInt8 = 60   // C4
    let noteStop: UInt8 = 62   // D4
    let noteRecord: UInt8 = 64 // E4
    let ccFader: UInt8 = 7     // Channel Volume (selected track)

    func ccScaledValue() -> UInt8 {
        UInt8(max(0, min(127, Int(faderValue * 127))))
    }

    // MARK: - Canonical Macro Definitions

    // Single source of truth — QuickAccessView uses quickAccessMacros, FullMacrosView uses allMacros
    static let quickAccessMacros: [MacroDef] = [
        MacroDef(icon: "↶", color: "#ff6b35", note: 68, name: "UNDO",      mmc: nil),
        MacroDef(icon: "↷", color: "#ff6b35", note: 69, name: "REDO",      mmc: nil),
        MacroDef(icon: "⊕", color: "#00d4ff", note: 70, name: "DUPLICATE", mmc: nil),
        MacroDef(icon: "◆", color: "#ff3b30", note: 73, name: "DELETE",    mmc: nil),
        MacroDef(icon: "≪", color: "#3498db", note: 81, name: "RWD",       mmc: 0x05),
        MacroDef(icon: "≫", color: "#3498db", note: 82, name: "FWD",       mmc: 0x04),
    ]

    static let allMacros: [MacroDef] = [
        MacroDef(icon: "↶", color: "#ff6b35", note: 68, name: "UNDO",     mmc: nil),
        MacroDef(icon: "↷", color: "#ff6b35", note: 69, name: "REDO",     mmc: nil),
        MacroDef(icon: "+",  color: "#00d4ff", note: 70, name: "ADD",      mmc: nil),
        MacroDef(icon: "⚑", color: "#ffcc00", note: 72, name: "MARKER",   mmc: nil),
        MacroDef(icon: "◆", color: "#ff3b30", note: 73, name: "DELETE",   mmc: nil),
        MacroDef(icon: "●", color: "#00ff88", note: 74, name: "RECORD",   mmc: nil),
        MacroDef(icon: "■", color: "#9b59b6", note: 75, name: "STOP",     mmc: nil),
        MacroDef(icon: "▲", color: "#3498db", note: 76, name: "UP",       mmc: nil),
        MacroDef(icon: "≪", color: "#3498db", note: 81, name: "RWD",      mmc: 0x05),
        MacroDef(icon: "≫", color: "#3498db", note: 82, name: "FWD",      mmc: 0x04),
        MacroDef(icon: "⬟", color: "#f39c12", note: 79, name: "OPTIONS",  mmc: nil),
        MacroDef(icon: "✦", color: "#1abc9c", note: 80, name: "FAVORITE", mmc: nil),
    ]
}
