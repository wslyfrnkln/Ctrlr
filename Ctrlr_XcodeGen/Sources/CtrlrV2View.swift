import SwiftUI

// MARK: - Design tokens

private let cream    = Color(hex: "#e8e4dc")
private let ink      = Color(hex: "#1a1a1a")
private let sub      = Color(hex: "#1a1a1a").opacity(0.55)
private let hair     = Color(hex: "#1a1a1a").opacity(0.18)
private let accent   = Color(hex: "#ff5b14")
private let mono     = Font.system(.body, design: .monospaced)

// MARK: - Root

struct CtrlrV2View: View {
    @ObservedObject var midi: MIDIManager
    @ObservedObject var model: AppModel
    @Binding var showDevicePicker: Bool

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    V2Header(midi: midi, showDevicePicker: $showDevicePicker)
                        .padding(.top, 20)

                    TrackCardView()

                    MasterZoneView(model: model, midi: midi)

                    V2MacroPadView(midi: midi)

                    V2LoopArmRow(model: model, midi: midi)

                    V2RecStopRow(model: model, midi: midi)

                    V2PlayButton(model: model, midi: midi)

                    Text("SinAudio")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(sub)
                        .padding(.bottom, 96)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Header

private struct V2Header: View {
    @ObservedObject var midi: MIDIManager
    @Binding var showDevicePicker: Bool

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(accent)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("C")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("ctrlr")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(ink)
                    Text("MIDI · v2.0")
                        .font(.system(size: 7, weight: .regular, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(sub)
                        .textCase(.uppercase)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#2cb67d"))
                    .frame(width: 5, height: 5)
                Text("USB · OP-Z")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(sub)
                    .textCase(.uppercase)
            }
            .onTapGesture {
                midi.refreshDestinations()
                showDevicePicker = true
            }
        }
    }
}

// MARK: - Track Card

private struct TrackCardView: View {
    // In a future version this will be driven by MIDI feedback
    let trackName = "BIRDS / take 04"
    let bpm = "128.0 BPM"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TRACK")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(sub)
                Spacer()
                Text("CH 01 / 16")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(sub)
            }

            Text(trackName)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundColor(ink)
                .lineLimit(1)

            TimelineRuler()

            HStack {
                Text("001.1.00")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(sub)
                Spacer()
                Text(bpm)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(sub)
            }
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ink, lineWidth: 1.5)
        )
        .cornerRadius(10)
    }
}

private struct TimelineRuler: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Ruler ticks
                Canvas { ctx, size in
                    let count = 41
                    for i in 0..<count {
                        let x = (Double(i) / Double(count - 1)) * size.width
                        let big = i % 4 == 0
                        let top: Double = big ? 4 : 8
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: top))
                        path.addLine(to: CGPoint(x: x, y: 14))
                        ctx.stroke(path, with: .color(ink.opacity(big ? 0.4 : 0.22)),
                                   lineWidth: big ? 1 : 0.6)
                    }
                    // Base line
                    var base = Path()
                    base.move(to: CGPoint(x: 0, y: 14))
                    base.addLine(to: CGPoint(x: size.width, y: 14))
                    ctx.stroke(base, with: .color(ink.opacity(0.22)), lineWidth: 0.7)
                }

                // Playhead at 0
                Rectangle()
                    .fill(accent)
                    .frame(width: 2)
                    .shadow(color: accent.opacity(0.8), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Master Zone (meter · jog · fader)

private struct MasterZoneView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var midi: MIDIManager

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            MicroMeterView(level: model.faderValue)
                .frame(width: 56)

            Spacer()

            RotaryJogView(value: $model.faderValue)
                .frame(width: 180, height: 180)
                .onChange(of: model.faderValue) { _ in
                    midi.sendCC(cc: model.ccFader, value: model.ccScaledValue())
                }

            Spacer()

            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    Text("MASTER")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(sub)
                    Text("CC")
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(sub)
                    Text("07")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(ink)
                }
                MiniFaderView(value: $model.faderValue)
                    .frame(width: 18, height: 88)
            }
            .frame(width: 56)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Micro Meter

private struct MicroMeterView: View {
    let level: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("L · R")
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .tracking(4)
                .foregroundColor(sub)

            HStack(alignment: .bottom, spacing: 4) {
                MeterChannel(level: level, offset: 0)
                MeterChannel(level: level, offset: 0.05)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MeterChannel: View {
    let level: Double
    let offset: Double
    private let segs = 14

    var body: some View {
        VStack(spacing: 1.5) {
            ForEach((0..<segs).reversed(), id: \.self) { i in
                let threshold = Double(i) / Double(segs)
                let isOn = (level + offset) >= threshold
                let color: Color = i >= 12 ? Color(hex: "#e63946") :
                                   i >= 9  ? Color(hex: "#f5b800") : accent
                Rectangle()
                    .fill(isOn ? color : ink.opacity(0.18))
                    .frame(width: 3, height: 6)
            }
        }
    }
}

// MARK: - Rotary Jog

private struct RotaryJogView: View {
    @Binding var value: Double
    @State private var dragStartY: CGFloat? = nil
    @State private var dragStartValue: Double = 0

    private let startAngle: Double = -135
    private let endAngle: Double   =  135
    private let size: CGFloat      =  180
    private let ticks              =  41
    // Points of drag travel to go from 0 → 1
    private let dragSensitivity: CGFloat = 200

    private var currentAngle: Double {
        startAngle + value * (endAngle - startAngle)
    }

    private var dBString: String {
        value == 0 ? "-∞" : String(format: "%.1f", 20 * log10(max(0.001, value)) - 6) + " dB"
    }

    var body: some View {
        ZStack {
            Canvas { ctx, sz in
                let cx = sz.width / 2
                let cy = sz.height / 2
                let r1: Double = Double(sz.width) / 2 - 4
                let activeT = Int(round(value * Double(ticks - 1)))

                for i in 0..<ticks {
                    let t = Double(i) / Double(ticks - 1)
                    let a = (startAngle + t * (endAngle - startAngle)) * .pi / 180
                    let r2: Double = i % 5 == 0 ? r1 - 12 : r1 - 6
                    let x1 = cx + sin(a) * r1
                    let y1 = cy - cos(a) * r1
                    let x2 = cx + sin(a) * r2
                    let y2 = cy - cos(a) * r2
                    let isOn = i <= activeT
                    var path = Path()
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.stroke(path,
                               with: .color(isOn ? accent : ink.opacity(0.28)),
                               style: StrokeStyle(lineWidth: i % 5 == 0 ? 1.5 : 1,
                                                  lineCap: .round))
                }
            }

            // Disc
            Circle()
                .fill(Color(hex: "#0e0e0d"))
                .frame(width: size * 0.69, height: size * 0.69)

            // Indicator dot
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
                .offset(y: -(size * 0.69 / 2 - 10))
                .rotationEffect(.degrees(currentAngle))

            // Labels
            VStack(spacing: 2) {
                Text("VOL")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(Color(hex: "#ece4d2").opacity(0.6))
                Text("\(Int(value * 100))")
                    .font(.system(size: 40, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#ece4d2"))
                Text(dBString)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#ece4d2").opacity(0.55))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { g in
                    if dragStartY == nil {
                        dragStartY = g.startLocation.y
                        dragStartValue = value
                    }
                    let delta = dragStartY! - g.location.y
                    value = max(0, min(1, dragStartValue + Double(delta / dragSensitivity)))
                }
                .onEnded { _ in
                    dragStartY = nil
                }
        )
    }
}

// MARK: - Mini Fader (vertical)

private struct MiniFaderView: View {
    @Binding var value: Double
    @State private var isDragging = false
    private let capH: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Track line
                Rectangle()
                    .fill(hair)
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity)

                // Cap
                RoundedRectangle(cornerRadius: 3)
                    .fill(ink)
                    .frame(width: 18, height: capH)
                    .overlay(
                        Rectangle()
                            .fill(accent)
                            .frame(width: 10, height: 1.5)
                    )
                    .offset(y: CGFloat(1.0 - value) * (geo.size.height - capH))
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { g in
                        let v = 1.0 - Double(g.location.y / geo.size.height)
                        value = max(0, min(1, v))
                    }
            )
        }
    }
}

// MARK: - Macro Pad (4×2 grid)

private struct V2MacroPadView: View {
    @ObservedObject var midi: MIDIManager
    @State private var activeMacros: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MACROS")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(sub)
                Spacer()
                Text("\(AppModel.v2Macros.count) × CC")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(sub)
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(AppModel.v2Macros, id: \.id) { m in
                    V2MacroButton(
                        macro: m,
                        isActive: activeMacros.contains(m.id),
                        onTap: {
                            let wasActive = activeMacros.contains(m.id)
                            if wasActive {
                                activeMacros.remove(m.id)
                                midi.sendCC(cc: m.cc, value: 0)
                            } else {
                                activeMacros.insert(m.id)
                                midi.sendCC(cc: m.cc, value: 127)
                            }
                        }
                    )
                }
            }
        }
    }
}

private struct V2MacroButton: View {
    let macro: AppModel.V2Macro
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(macro.id)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(isActive ? accent : ink)
                    Spacer()
                    Text("CC\(macro.cc)")
                        .font(.system(size: 7, weight: .regular, design: .monospaced))
                        .foregroundColor(sub)
                }
                Text(macro.label)
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(sub)
                    .textCase(.uppercase)
            }
            .padding(8)
            .frame(height: 50)
            .background(isActive ? accent.opacity(0.08) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? accent : hair, lineWidth: 1)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.1), value: isActive)
    }
}

// MARK: - Transport rows

private struct V2RecStopRow: View {
    @ObservedObject var model: AppModel
    @ObservedObject var midi: MIDIManager
    @State private var recording = false
    @State private var playing   = false

    var body: some View {
        HStack(spacing: 6) {
            transportBtn(label: "REC", sfSymbol: "circle.fill",
                         active: recording, color: Color(hex: "#e63946")) {
                recording.toggle()
                midi.sendNoteOn(note: model.noteRecord)
                midi.sendNoteOff(note: model.noteRecord)
                midi.sendMMC(command: 0x06)
            }
            transportBtn(label: "STOP", sfSymbol: "stop.fill",
                         active: false, color: ink) {
                playing = false; recording = false
                midi.sendNoteOn(note: model.noteStop)
                midi.sendNoteOff(note: model.noteStop)
                midi.sendMMC(command: 0x01)
            }
        }
    }
}

private struct V2LoopArmRow: View {
    @ObservedObject var model: AppModel
    @ObservedObject var midi: MIDIManager
    @State private var looping = false
    @State private var armed   = false

    var body: some View {
        HStack(spacing: 6) {
            transportBtn(label: "LOOP", sfSymbol: "repeat",
                         active: looping, color: Color(hex: "#f59e0b")) {
                looping.toggle()
                midi.sendCC(cc: 66, value: looping ? 127 : 0)
            }
            transportBtn(label: "ARM", sfSymbol: "record.circle",
                         active: armed, color: Color(hex: "#e63946")) {
                armed.toggle()
                midi.sendCC(cc: 65, value: armed ? 127 : 0)
            }
        }
    }
}

private func transportBtn(label: String, sfSymbol: String,
                           active: Bool, color: Color,
                           action: @escaping () -> Void) -> some View {
    Button(action: action) {
        VStack(spacing: 5) {
            Image(systemName: sfSymbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(active ? color : sub)
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundColor(active ? color : sub)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(active ? color.opacity(0.08) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(active ? color : hair, lineWidth: 1)
        )
        .cornerRadius(8)
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.1), value: active)
}


private struct V2PlayButton: View {
    @ObservedObject var model: AppModel
    @ObservedObject var midi: MIDIManager
    @State private var playing = false

    var body: some View {
        Button(action: {
            playing.toggle()
            midi.sendNoteOn(note: model.notePlay)
            midi.sendNoteOff(note: model.notePlay)
            midi.sendMMC(command: playing ? 0x02 : 0x03)
        }) {
            HStack(spacing: 14) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(playing ? "Pause" : "Play")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .textCase(.uppercase)
            }
            .foregroundColor(playing ? .white : ink)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(playing ? accent : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ink, lineWidth: 1.5)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.14), value: playing)
    }
}
