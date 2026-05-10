import SwiftUI
import CoreMIDI

// MARK: - Root

struct ContentView: View {
    @StateObject var midi = MIDIManager()
    @StateObject var model = AppModel()
    @State private var showDevicePicker = false

    var body: some View {
        CtrlrV2View(midi: midi, model: model, showDevicePicker: $showDevicePicker)
            .sheet(isPresented: $showDevicePicker) {
                DevicePickerView(midi: midi, isPresented: $showDevicePicker)
            }
    }
}

// MARK: - Device Picker Sheet

struct DevicePickerView: View {
    @ObservedObject var midi: MIDIManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0c0c0c").ignoresSafeArea()

                VStack(spacing: 0) {
                    if midi.destinations.isEmpty {
                        SetupGuideView(midi: midi)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(midi.destinations, id: \.self) { destination in
                                DeviceRow(
                                    name: midi.name(for: destination),
                                    isSelected: midi.selectedDestination == destination,
                                    action: {
                                        midi.selectDestination(destination)
                                        isPresented = false
                                    }
                                )
                            }
                            .listRowBackground(Color(hex: "#161616"))
                        }
                        .scrollContentBackground(.hidden)
                    }

                    VStack(spacing: 0) {
                        Divider()

                        VStack(alignment: .leading, spacing: 0) {
                            Text("NETWORK")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "#555555"))
                                .padding(.top, 10)
                                .padding(.bottom, 4)

                            DiagnosticRow(label: "TCP", value: midi.listenerDebug,
                                          isOK: midi.listenerDebug.contains("listening"))
                            DiagnosticRow(label: "SVC", value: midi.serviceDebug,
                                          isOK: midi.serviceDebug != "not registered" && midi.serviceDebug != "removed")
                            DiagnosticRow(label: "MAC", value: midi.companionDebug,
                                          isOK: midi.companionConnected)
                            DiagnosticRow(label: "IP", value: midi.localIP,
                                          isOK: midi.localIP != "—")
                            DiagnosticRow(label: "IN", value: "\(midi.incomingCount)", isOK: nil)
                        }
                        .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("MIDI")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: "#555555"))
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            DiagnosticRow(label: "DST", value: "\(midi.destinations.count)",
                                          isOK: !midi.destinations.isEmpty)
                            DiagnosticRow(label: "SEL", value: midi.selectedDestinationName,
                                          isOK: midi.selectedDestination != nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        HStack(spacing: 12) {
                            Button(action: { midi.reconnect() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("RESTART ALL")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#00d4ff").opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#00d4ff").opacity(0.4), lineWidth: 1)
                                )
                                .cornerRadius(10)
                            }

                            Button(action: { UIPasteboard.general.string = midi.diagnosticText }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("COPY")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1)
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 20)
                                .background(Color(hex: "#333333").opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#444444"), lineWidth: 1)
                                )
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(Color(hex: "#0c0c0c"))
                }
            }
            .navigationTitle("MIDI Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(Color(hex: "#ff6b35"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "cable.connector")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color(hex: "#00ff88") : Color(hex: "#666666"))
                    .frame(width: 32)
                Text(name)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#00ff88"))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? Color(hex: "#00ff88").opacity(0.08) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setup Guide

struct SetupGuideView: View {
    @ObservedObject var midi: MIDIManager

    private struct Step {
        let number: Int
        let title: String
        let detail: String
        let color: String
    }

    private let steps: [Step] = [
        Step(number: 1, title: "Same WiFi",        detail: "Connect your iPhone and Mac to the same WiFi network.",                         color: "#00d4ff"),
        Step(number: 2, title: "Audio MIDI Setup", detail: "On your Mac, open:\nApplications → Utilities → Audio MIDI Setup",              color: "#ff6b35"),
        Step(number: 3, title: "MIDI Studio",      detail: "Go to Window → Show MIDI Studio.\nClick the Network icon in the toolbar.",     color: "#ffcc00"),
        Step(number: 4, title: "Connect",          detail: "Find \"Ctrlr\" in the Directory list.\nClick Connect — you're done.",          color: "#00ff88"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#00d4ff"))
                        Text("WIFI MIDI")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "#00d4ff"))
                        Text("RECOMMENDED")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Color(hex: "#00d4ff").opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#00d4ff").opacity(0.1))
                            .cornerRadius(3)
                    }
                    Text("One-time setup on your Mac. Reconnects automatically.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                VStack(spacing: 0) {
                    ForEach(steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: step.color).opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Text("\(step.number)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: step.color))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(step.detail)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#888888"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 20)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "#00ff88"))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color(hex: "#00ff88"), radius: 6)
                    Text("Advertising as \"Ctrlr\" on your network")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#555555"))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                Button(action: { midi.refreshDestinations() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("REFRESH DEVICES").tracking(1)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#ff6b35"))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Diagnostic Row

struct DiagnosticRow: View {
    let label: String
    let value: String
    let isOK: Bool?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .shadow(color: isOK == true ? dotColor.opacity(0.6) : .clear, radius: 3)
            Text(label).foregroundColor(Color(hex: "#555555"))
            Text(value).foregroundColor(Color(hex: "#999999"))
            Spacer()
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(.vertical, 1.5)
    }

    private var dotColor: Color {
        switch isOK {
        case .some(true):  return Color(hex: "#00ff88")
        case .some(false): return Color(hex: "#ff4444")
        case .none:        return Color(hex: "#444444")
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Full App") { ContentView() }
#Preview("V2 View") {
    CtrlrV2View(midi: MIDIManager(), model: AppModel(), showDevicePicker: .constant(false))
}
#endif

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
