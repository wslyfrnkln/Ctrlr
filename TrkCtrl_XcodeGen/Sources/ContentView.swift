import SwiftUI
import CoreMIDI

struct ContentView: View {
    @StateObject var midi = MIDIManager()
    @StateObject var model = AppModel()

    // UI state
    @State private var armOn = false
    @State private var loopOn = false

    var body: some View {
        VStack(spacing: 16) {

            // ***************************************
            // MIDI Destination (kept simple for now)
            // ***************************************
            /*
            HStack {
                Text("MIDI Out").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Refresh", action: midi.refreshDestinations)
                    ForEach(midi.destinations, id: \.self) { dest in
                        Button(name(for: dest)) { midi.selectedDestination = dest }
                    }
                } label: {
                    Text(name(for: midi.selectedDestination))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 4)
            */

            
            // ***************************************
            // TOP SECTION: Mixer + Macros (panel)\
            // ***************************************
            SectionCard {
                HStack(alignment: .top, spacing: 16) {

                    // MIXER (single fader)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mixer").font(.headline)
                        Slider(value: $model.faderValue, in: 0...1, onEditingChanged: { _ in
                            midi.sendCC(cc: model.ccFader, value: model.ccScaledValue())
                        })
                        Text(String(format: "%.0f%%", model.faderValue * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider().frame(height: 76)

                    // MACROS (labels instead of ASSIGN)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Macros").font(.headline)
                        HStack(spacing: 10) {
                            MacroButton(title: "UNDO", system: "arrow.uturn.backward") {
                                // Map to a free note/CC and handle in Ableton if desired
                                midi.sendNoteOn(note: 68); midi.sendNoteOff(note: 68)
                            }
                            MacroButton(title: "DUPL.", system: "plus.square.on.square") {
                                midi.sendNoteOn(note: 70); midi.sendNoteOff(note: 70)
                            }
                            MacroButton(title: "MARK", system: "flag") {
                                midi.sendNoteOn(note: 72); midi.sendNoteOff(note: 72)
                            }
                        }
                    }
                }
            }

            // ***************************************
            // MIDDLE SECTION: Arrangement / Session
            // ***************************************

            SectionCard {
                HStack(spacing: 12) {
                    // ARM toggle (green when active)
                    PillButton(title: "ARM",
                               active: armOn,
                               activeColor: .green) {
                        armOn.toggle()
                        // Optional: send CC 65 as ARM toggle
                        midi.sendCC(cc: 65, value: armOn ? 127 : 0)
                    }
                    Spacer(minLength: 2)
                    // LOOP toggle (blue when active)
                    PillButton(title: "LOOP",
                               active: loopOn,
                               activeColor: .blue) {
                        loopOn.toggle()
                        // Optional: send CC 66 as LOOP toggle
                        midi.sendCC(cc: 66, value: loopOn ? 127 : 0)
                    }


                }
            }

            // LARGE BLANK SPACE
            Spacer(minLength: 8)

            // Status + controls row
            HStack(spacing: 16) {
                // LED
                Circle()
                    .fill(midi.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text("Destination: \(midi.selectedDestinationName)")
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Button("Refresh") { midi.refreshDestinations() }
                    .font(.caption)

                Button("Ping") { midi.ping() }
                    .font(.caption)
            }
            .padding(.horizontal, 4)

            // ***********************************************
            // LOWER SECTION: Transport Controls (thumb zone)
            // ***********************************************
            SectionCard {
                HStack(spacing: 18) {
                    // PLAY BUTTON
                    TransportIcon(system: "play.fill",
                                  active: model.isPlaying,
                                  color: .green) {
                        model.isPlaying = true
                        midi.sendNoteOn(note: model.notePlay)
                        midi.sendNoteOff(note: model.notePlay)
                    }

                    // STOP BUTTON
                    TransportIcon(system: "stop.fill",
                                  active: true,
                                  color: .gray) {
                        model.isPlaying = false
                        model.isRecording = false
                        midi.sendNoteOn(note: model.noteStop)
                        midi.sendNoteOff(note: model.noteStop)
                    }

                    // REC BUTTON
                    TransportIcon(system: "record.circle.fill",
                                  active: model.isRecording,
                                  color: .red) {
                        model.isRecording.toggle()
                        midi.sendNoteOn(note: model.noteRecord)
                        midi.sendNoteOff(note: model.noteRecord)
                    }
                }
            }
        }
        .padding(16)
    }

    // Helpers
    func name(for endpoint: MIDIEndpointRef?) -> String {
        guard let endpoint else { return "Select…" }
        var param: Unmanaged<CFString>?
        var name: String = "MIDI Dest"
        let err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &param)
        if err == noErr, let take = param?.takeRetainedValue() { name = take as String }
        return name
    }
}

// MARK: - Reusable UI

struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 4, y: 2)
    }
}

struct MacroButton: View {
    let title: String
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PillButton: View {
    let title: String
    let active: Bool
    let activeColor: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 55).padding(.vertical, 10)
                .background(active ? activeColor.opacity(0.18) : Color(.secondarySystemBackground))
                .foregroundStyle(active ? activeColor : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct TransportIcon: View {
    let system: String
    let active: Bool
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(active ? color : .secondary)
                .frame(width: 88, height: 88)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
