import SwiftUI
import CoreMIDI

// MARK: - Root

struct ContentView: View {
    @StateObject var midi = MIDIManager()
    @StateObject var model = AppModel()
    @State private var showDevicePicker = false

    var body: some View {
        CtrlrV2View(midi: midi, model: model, showDevicePicker: $showDevicePicker)
            .overlay {
                if !midi.isConnected {
                    SetupGuideView(midi: midi)
                        .background(Color(hex: "#e8e4dc").ignoresSafeArea())
                }
            }
            .sheet(isPresented: $showDevicePicker) {
                DevicePickerView(midi: midi, isPresented: $showDevicePicker)
            }
    }
}

// MARK: - Design tokens (sheet)

private let sheetBg     = Color(hex: "#e8e4dc")
private let sheetInk    = Color(hex: "#1a1a1a")
private let sheetSub    = Color(hex: "#1a1a1a").opacity(0.72)
private let sheetHair   = Color(hex: "#1a1a1a").opacity(0.15)
private let sheetAccent = Color(hex: "#ff5b14")

// MARK: - Device Picker Sheet

struct DevicePickerView: View {
    @ObservedObject var midi: MIDIManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                sheetBg.ignoresSafeArea()

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
                            .listRowBackground(sheetBg)
                        }
                        .scrollContentBackground(.hidden)
                    }

                    VStack(spacing: 0) {
                        Divider().overlay(sheetHair)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("NETWORK")
                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(sheetSub)
                                .padding(.top, 10)
                                .padding(.bottom, 4)

                            DiagnosticRow(label: "TCP", value: midi.listenerDebug,
                                          isOK: midi.listenerDebug.contains("listening"))
                            DiagnosticRow(label: "SVC", value: midi.serviceDebug,
                                          isOK: midi.serviceDebug != "not registered" && midi.serviceDebug != "removed")
                            DiagnosticRow(label: "MAC", value: midi.companionDebug,
                                          isOK: midi.companionConnected)
                            DiagnosticRow(label: "IP",  value: midi.localIP,
                                          isOK: midi.localIP != "—")
                            DiagnosticRow(label: "IN",  value: "\(midi.incomingCount)", isOK: nil)
                        }
                        .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("MIDI")
                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(sheetSub)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            DiagnosticRow(label: "DST", value: "\(midi.destinations.count)",
                                          isOK: !midi.destinations.isEmpty)
                            DiagnosticRow(label: "SEL", value: midi.selectedDestinationName,
                                          isOK: midi.selectedDestination != nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        HStack(spacing: 8) {
                            Button(action: { midi.reconnect() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("RESTART")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .tracking(1.5)
                                }
                                .foregroundColor(sheetInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(sheetInk.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(8)
                            }

                            Button(action: { UIPasteboard.general.string = midi.diagnosticText }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("COPY")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .tracking(1.5)
                                }
                                .foregroundColor(sheetSub)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(sheetHair, lineWidth: 1)
                                )
                                .cornerRadius(8)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(sheetBg)
                }
            }
            .navigationTitle("MIDI Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(sheetAccent)
                }
            }
        }
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
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? sheetAccent : sheetSub)
                    .frame(width: 28)
                Text(name)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(sheetInk)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(sheetAccent)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? sheetAccent.opacity(0.06) : Color.clear)
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
    }

    private let steps: [Step] = [
        Step(number: 1, title: "Same WiFi",          detail: "Connect your iPhone and Mac to the same network."),
        Step(number: 2, title: "Install Helper",      detail: "Download and open Ctrlr Helper on your Mac."),
        Step(number: 3, title: "You're done",         detail: "Helper auto-connects. Open Ctrlr — it appears here."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("SETUP")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(sheetSub)
                    Text("Connect to Mac")
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundColor(sheetInk)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 28)

                VStack(spacing: 0) {
                    ForEach(steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(step.number == 3 ? sheetAccent : sheetHair, lineWidth: 1)
                                    .frame(width: 28, height: 28)
                                Text("\(step.number)")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(step.number == 3 ? sheetAccent : sheetSub)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(sheetInk)
                                Text(step.detail)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(sheetSub)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 24)

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Divider()
                    .overlay(sheetHair)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                Button(action: { midi.refreshDestinations() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("REFRESH")
                            .tracking(2)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(sheetInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(sheetInk, lineWidth: 1.5)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
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
                .frame(width: 4, height: 4)
            Text(label).foregroundColor(sheetSub)
            Text(value).foregroundColor(sheetInk.opacity(0.6))
            Spacer()
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(.vertical, 1.5)
    }

    private var dotColor: Color {
        switch isOK {
        case .some(true):  return sheetAccent
        case .some(false): return Color(hex: "#cc3333")
        case .none:        return sheetHair
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
