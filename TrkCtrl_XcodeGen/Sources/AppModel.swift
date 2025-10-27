import Foundation

final class AppModel: ObservableObject {
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var faderValue: Double = 0.7 // 0.0 ... 1.0

    // MIDI mapping (match Ableton UserConfiguration.txt)
    let notePlay: UInt8 = 60   // C4
    let noteStop: UInt8 = 62   // D4
    let noteRecord: UInt8 = 64 // E4
    let ccFader: UInt8 = 7     // Channel Volume (selected track)

    func ccScaledValue() -> UInt8 {
        UInt8(max(0, min(127, Int(faderValue * 127))))
    }
}
