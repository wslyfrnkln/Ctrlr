import SwiftUI
import CoreMIDI

// =========================================================================
// MARK: - Main View (Redesigned from launchpad-v4-iphone17.jsx)
// =========================================================================
// This is the root view that contains all UI sections stacked vertically.
// Uses dark theme with modern gradients, glows, and professional styling.
// =========================================================================

struct ContentView: View {
    @StateObject var midi = MIDIManager()
    @StateObject var model = AppModel()

    @State private var activeTab: Tab = .mixer
    @State private var armOn = false
    @State private var loopOn = true
    @State private var showDevicePicker = false

    enum Tab {
        case mixer, macros
    }

    var body: some View {
        ZStack {
            // Deep black background for pro studio look
            Color(hex: "#0c0c0c")
                .ignoresSafeArea()

            // Subtle white gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // ═══════════════════════════════════════════════════
                // HEADER: Connection status + DEVICES button
                // ═══════════════════════════════════════════════════
                HeaderView(midi: midi, showDevicePicker: $showDevicePicker)
                    .padding(.top, 50)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                // ═══════════════════════════════════════════════════
                // TAB SELECTOR: Switch between MIXER and MACROS views
                // ═══════════════════════════════════════════════════
                TabSelector(activeTab: $activeTab)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)

                // ═══════════════════════════════════════════════════
                // MAIN CONTENT AREA: Fader + Macros (switchable via tabs)
                // ═══════════════════════════════════════════════════
                MainContentArea(
                    activeTab: activeTab,
                    model: model,
                    midi: midi
                )
                .padding(.horizontal, 10)
                .frame(height: 280) // Increased from 200 for better visibility

                // ═══════════════════════════════════════════════════
                // ARM / LOOP SECTION: Track arming and loop toggle
                // ═══════════════════════════════════════════════════
                ArmLoopSection(
                    armOn: $armOn,
                    loopOn: $loopOn,
                    midi: midi
                )
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 10)

                // ═══════════════════════════════════════════════════
                // TRANSPORT CONTROLS: STOP, PLAY, RECORD buttons
                // ═══════════════════════════════════════════════════
                TransportSection(model: model, midi: midi)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)

                // Minimal spacer to push content up and fill screen
                Spacer(minLength: 8)

                // ═══════════════════════════════════════════════════
                // HOME INDICATOR: iPhone-style gesture bar
                // ═══════════════════════════════════════════════════
                HomeIndicator()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDevicePicker) {
            DevicePickerView(midi: midi, isPresented: $showDevicePicker)
        }
    }
}

// =========================================================================
// MARK: - Header: Connection Status + DEVICES Button
// =========================================================================
// Shows connection LED (green/yellow/red) and button to refresh MIDI destinations
// Green = Connected, Yellow = Error, Red = Disconnected
// =========================================================================

struct HeaderView: View {
    @ObservedObject var midi: MIDIManager
    @Binding var showDevicePicker: Bool

    // Computed properties for status display
    private var statusColor: Color {
        switch midi.connectionState {
        case .connected:
            return Color(hex: "#00ff88")  // Green
        case .error:
            return Color(hex: "#ffcc00")  // Yellow
        case .disconnected:
            return Color(hex: "#ff3b30")  // Red
        }
    }

    private var statusText: String {
        switch midi.connectionState {
        case .connected:
            return "CONNECTED"
        case .error:
            return "ERROR"
        case .disconnected:
            return "DISCONNECTED"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // Connection status: LED + label
                HStack(spacing: 8) {
                    // LED indicator with glow effect
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: statusColor, radius: 8)

                    Text(statusText)
                        .font(.system(size: 8, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#555555"))
                }

                Spacer()

                // DEVICES button to show device picker sheet
                Button(action: {
                    midi.refreshDestinations()
                    showDevicePicker = true
                }) {
                    Text("DEVICES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Color(hex: "#ff6b35"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#ff6b35").opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(hex: "#ff6b35").opacity(0.25), lineWidth: 1)
                        )
                        .cornerRadius(5)
                }
            }

            // Error message banner (shown when there's an error)
            if let error = midi.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#ffcc00"))

                    Text(error.localizedDescription)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(hex: "#ffcc00"))

                    Spacer()

                    // Dismiss button
                    Button(action: {
                        midi.clearError()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#ffcc00").opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
}

// =========================================================================
// MARK: - Tab Selector: Switch Between MIXER and MACROS
// =========================================================================
// Two-button segmented control to toggle between main view modes
// =========================================================================

struct TabSelector: View {
    @Binding var activeTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 2) {
            TabButton(title: "MIXER", isActive: activeTab == .mixer) {
                activeTab = .mixer
            }
            TabButton(title: "MACROS", isActive: activeTab == .macros) {
                activeTab = .macros
            }
        }
        .padding(2)
        .background(Color(hex: "#131313"))
        .cornerRadius(6)
    }
}

// Individual tab button with active state styling
struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundColor(isActive ? .white : Color(hex: "#444444"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isActive ?
                    LinearGradient(
                        colors: [Color(hex: "#282828"), Color(hex: "#1e1e1e")],
                        startPoint: .top,
                        endPoint: .bottom
                    ) :
                    LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(5)
        }
    }
}

// =========================================================================
// MARK: - Main Content Area: Fader + Macros (Tab-Dependent)
// =========================================================================
// Shows either: (1) SSL Fader + Quick Access Macros, or (2) Full Macro Grid
// Dark gradient background with subtle border
// =========================================================================

struct MainContentArea: View {
    let activeTab: ContentView.Tab
    @ObservedObject var model: AppModel
    @ObservedObject var midi: MIDIManager

    var body: some View {
        HStack(spacing: 0) {
            if activeTab == .mixer {
                // MIXER VIEW: Vertical fader + 6 quick access macro buttons
                HStack(spacing: 10) {
                    // SSL-style professional vertical fader with VU meters
                    SSLFaderView(value: $model.faderValue, midi: midi, model: model)
                        .frame(width: 58)

                    // 6 quick access macro buttons (3x2 grid)
                    QuickAccessView(midi: midi)
                }
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#161616"), Color(hex: "#101010")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#222222"), lineWidth: 1)
                )
                .cornerRadius(10)
            } else {
                // MACROS VIEW: Full 12-button grid (4x3)
                FullMacrosView(midi: midi)
                    .padding(10)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#161616"), Color(hex: "#101010")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#222222"), lineWidth: 1)
                    )
                    .cornerRadius(10)
            }
        }
    }
}

// =========================================================================
// MARK: - SSL Fader: Professional Vertical Fader with VU Meters
// =========================================================================
// Studio-quality fader with: value display, dual VU meters, draggable knob
// Sends MIDI CC7 (channel volume) in real-time during drag
// =========================================================================

struct SSLFaderView: View {
    @Binding var value: Double
    @ObservedObject var midi: MIDIManager
    @ObservedObject var model: AppModel
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            // Numeric value display (0-100) with green glow
            Text("\(Int(value * 100))")
                .font(.system(size: 18, weight: .regular, design: .monospaced))
                .foregroundColor(Color(hex: "#00ff88"))
                .shadow(color: Color(hex: "#00ff88").opacity(0.4), radius: 10)

            // Dual VU meters: green → yellow → red level indicators
            HStack(spacing: 2) {
                VUMeterChannel(level: value, variance: 0)      // Left channel
                VUMeterChannel(level: value, variance: 0.05)   // Right channel (slight variance)
            }
            .frame(height: 100) // Increased from 80

            // Draggable fader track with knob
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // Dark track background with center line
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "#050505"))
                        .shadow(color: .black.opacity(0.6), radius: 2, y: 2)
                        .overlay(
                            Rectangle()
                                .fill(Color(hex: "#222222"))
                                .frame(width: 2)
                        )

                    // Fader knob (moves vertically)
                    FaderKnob(isDragging: isDragging)
                        .offset(y: CGFloat((1.0 - value)) * geometry.size.height - 11)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let newValue = 1.0 - (gesture.location.y / geometry.size.height)
                            value = min(max(newValue, 0), 1)
                            // Send MIDI CC in real-time
                            midi.sendCC(cc: model.ccFader, value: model.ccScaledValue())
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: 32)

            // "MASTER" label
            Text("MASTER")
                .font(.system(size: 6, weight: .semibold))
                .tracking(1)
                .foregroundColor(Color(hex: "#444444"))
        }
        .padding(8)
        .background(Color(hex: "#0a0a0a"))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: "#1a1a1a"), lineWidth: 1)
        )
        .cornerRadius(6)
    }
}

// VU Meter: Single channel with 12 segments (green → yellow → red)
struct VUMeterChannel: View {
    let level: Double
    let variance: Double // Slight randomization for realistic meter

    var body: some View {
        VStack(spacing: 1) {
            ForEach((0..<12).reversed(), id: \.self) { i in
                let threshold = Double(i) / 12.0
                let isActive = (level + variance) >= threshold
                let isRed = i >= 10        // Top 2 segments: red
                let isYellow = i >= 8 && i < 10  // Next 2: yellow
                let color = isRed ? Color(hex: "#ff3b30") : (isYellow ? Color(hex: "#ffcc00") : Color(hex: "#00ff88"))

                Rectangle()
                    .fill(isActive ? color : Color(hex: "#1a1a1a"))
                    .cornerRadius(1)
                    .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: 2)
            }
        }
    }
}

// Fader Knob: 3D-styled draggable element with grip lines
struct FaderKnob: View {
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 2) {
            // Three horizontal grip lines
            ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 16, height: 1)
            }
        }
        .frame(width: 28, height: 22)
        .background(
            LinearGradient(
                colors: isDragging ?
                    [Color(hex: "#5a5a5a"), Color(hex: "#3a3a3a"), Color(hex: "#4a4a4a")] :
                    [Color(hex: "#4a4a4a"), Color(hex: "#2a2a2a"), Color(hex: "#3a3a3a")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: "#555555"), lineWidth: 1)
                .shadow(color: .white.opacity(isDragging ? 0.2 : 0.15), radius: 0, y: 1)
        )
        .cornerRadius(2)
        .shadow(color: isDragging ? Color(hex: "#00ff88").opacity(0.2) : .black.opacity(0.5), radius: isDragging ? 6 : 3, y: 2)
    }
}

// =========================================================================
// MARK: - Quick Access Macros: 6-Button Grid (MIXER Tab)
// =========================================================================
// 2x3 grid of macro buttons shown alongside fader in MIXER view
// =========================================================================

struct QuickAccessView: View {
    @ObservedObject var midi: MIDIManager

    // Macro definitions: icon, color, MIDI note (6 buttons in 2x3 grid)
    let macros: [(icon: String, color: String, note: UInt8, name: String)] = [
        ("↶", "#ff6b35", 68, "UNDO"),      // U+21B6 anticlockwise top semicircle arrow
        ("↷", "#ff6b35", 69, "REDO"),      // U+21B7 clockwise top semicircle arrow
        ("⊕", "#00d4ff", 70, "DUPLICATE"),
        ("◆", "#ff3b30", 73, "DELETE"),
        ("⚑", "#ffcc00", 72, "MARKER"),
        ("≡", "#9b59b6", 74, "MENU")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACCESS")
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(Color(hex: "#444444"))

            // 2x3 grid (2 columns, 3 rows)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    MacroButton(
                        icon: macros[i].icon,
                        color: macros[i].color,
                        action: {
                            midi.sendNoteOn(note: macros[i].note)
                            midi.sendNoteOff(note: macros[i].note)
                        }
                    )
                }
            }
        }
    }
}

// =========================================================================
// MARK: - Full Macros Grid: 12-Button Grid (MACROS Tab)
// =========================================================================
// 4x3 grid of all available macro buttons (shown when MACROS tab active)
// =========================================================================

struct FullMacrosView: View {
    @ObservedObject var midi: MIDIManager

    // All 12 macro definitions
    let macros: [(icon: String, color: String, note: UInt8, name: String)] = [
        ("↶", "#ff6b35", 68, "UNDO"), ("↷", "#ff6b35", 69, "REDO"),
        ("+", "#00d4ff", 70, "ADD"), ("⚑", "#ffcc00", 72, "MARKER"),
        ("◆", "#ff3b30", 73, "DELETE"), ("●", "#00ff88", 74, "RECORD"),
        ("■", "#9b59b6", 75, "STOP"), ("▲", "#3498db", 76, "UP"),
        ("◀", "#e74c3c", 77, "LEFT"), ("▶", "#2ecc71", 78, "RIGHT"),
        ("⬟", "#f39c12", 79, "OPTIONS"), ("✦", "#1abc9c", 80, "FAVORITE")
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 5) {
            ForEach(0..<12, id: \.self) { i in
                MacroButton(
                    icon: macros[i].icon,
                    color: macros[i].color,
                    action: {
                        midi.sendNoteOn(note: macros[i].note)
                        midi.sendNoteOff(note: macros[i].note)
                    }
                )
            }
        }
    }
}

// Individual macro button with icon and colored indicator dot
struct MacroButton: View {
    let icon: String
    let color: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Icon symbol - increased size for better visibility
                Text(icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: "#777777"))

                // Colored indicator dot (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 6, height: 6)  // Larger dot for visibility
                            .opacity(0.7)
                            .shadow(color: Color(hex: color).opacity(0.6), radius: 5)
                    }
                    Spacer()
                }
                .padding(5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 65)  // Increased minimum height to fill space better
            .background(
                LinearGradient(
                    colors: [Color(hex: "#252525"), Color(hex: "#1a1a1a")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// =========================================================================
// MARK: - ARM / LOOP Section: Track Recording + Loop Controls
// =========================================================================
// Two toggle buttons: ARM (track recording) and LOOP (loop mode)
// Glow effects when active
// =========================================================================

struct ArmLoopSection: View {
    @Binding var armOn: Bool
    @Binding var loopOn: Bool
    @ObservedObject var midi: MIDIManager

    var body: some View {
        HStack(spacing: 8) {
            // ARM button: Enables track recording
            ArmLoopButton(
                label: "ARM",
                isActive: armOn,
                color: "#ff3b30",
                action: {
                    armOn.toggle()
                    midi.sendCC(cc: 65, value: armOn ? 127 : 0)
                }
            )

            // LOOP button: Enables loop mode
            ArmLoopButton(
                label: "LOOP",
                isActive: loopOn,
                color: "#ff9500",
                action: {
                    loopOn.toggle()
                    midi.sendCC(cc: 66, value: loopOn ? 127 : 0)
                }
            )
        }
    }
}

// ARM/LOOP button with LED indicator and glow when active
struct ArmLoopButton: View {
    let label: String
    let isActive: Bool
    let color: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Button label
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(3)
                    .foregroundColor(isActive ? .white : Color(hex: "#555555"))

                // LED indicator (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(isActive ? .white : Color(hex: color))
                            .frame(width: 6, height: 6)
                            .opacity(isActive ? 1 : 0.4)
                            .shadow(color: isActive ? Color(hex: color) : .clear, radius: 8)
                    }
                    Spacer()
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60) // Increased from 52
            .background(
                isActive ?
                LinearGradient(
                    colors: [Color(hex: color), Color(hex: color).opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color(hex: "#252525"), Color(hex: "#1a1a1a")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(8)
            .shadow(color: isActive ? Color(hex: color).opacity(0.5) : .black.opacity(0.4), radius: isActive ? 12 : 5, y: 4)
        }
    }
}

// =========================================================================
// MARK: - Transport Section: STOP, PLAY, RECORD Buttons
// =========================================================================
// Main playback controls: wide STOP on top, PLAY/REC side-by-side below
// Glowing effects when active, MIDI notes sent on press
// =========================================================================

struct TransportSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var midi: MIDIManager
    @State private var stopPressed = false

    var body: some View {
        VStack(spacing: 8) {
            // STOP button: Wide button spanning full width
            // Only glows yellow while being pressed
            TransportStopButton(
                isStopped: stopPressed,
                onPressChanged: { isPressed in
                    stopPressed = isPressed
                    if isPressed {
                        model.isPlaying = false
                        model.isRecording = false
                        midi.sendNoteOn(note: model.noteStop)
                        midi.sendNoteOff(note: model.noteStop)
                    }
                }
            )
            .frame(height: 64) // Increased from 56

            // PLAY and RECORD buttons: Side by side below STOP
            HStack(spacing: 8) {
                TransportPlayButton(
                    isPlaying: model.isPlaying,
                    action: {
                        model.isPlaying = true
                        midi.sendNoteOn(note: model.notePlay)
                        midi.sendNoteOff(note: model.notePlay)
                    }
                )

                TransportRecordButton(
                    isRecording: model.isRecording,
                    action: {
                        model.isRecording.toggle()
                        if model.isRecording {
                            model.isPlaying = true
                        }
                        midi.sendNoteOn(note: model.noteRecord)
                        midi.sendNoteOff(note: model.noteRecord)
                    }
                )
            }
            .frame(height: 120) // Increased from 100
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [Color(hex: "#141414"), Color(hex: "#0a0a0a")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#222222"), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

// STOP button: Yellow when pressed (momentary)
struct TransportStopButton: View {
    let isStopped: Bool
    let onPressChanged: (Bool) -> Void

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 10) {
                Text("■")
                    .font(.system(size: 22))
                    .foregroundColor(isStopped ? .black : Color(hex: "#ffcc00").opacity(0.4))

                Text("STOP")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(4)
                    .foregroundColor(isStopped ? .black : Color(hex: "#ffcc00").opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                isStopped ?
                LinearGradient(
                    colors: [Color(hex: "#ffcc00"), Color(hex: "#e6b800")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color(hex: "#2a2a2a"), Color(hex: "#1e1e1e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isStopped ? Color.clear : Color(hex: "#ffcc00").opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(10)
            .shadow(color: isStopped ? Color(hex: "#ffcc00").opacity(0.4) : .black.opacity(0.4), radius: isStopped ? 15 : 6, y: 4)
        }
        .buttonStyle(PressableButtonStyle(onPressChanged: onPressChanged))
    }
}

// Custom button style to detect press/release
struct PressableButtonStyle: ButtonStyle {
    let onPressChanged: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed in
                onPressChanged(isPressed)
            }
    }
}

// PLAY button: Green when active (playing state)
struct TransportPlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("▶")
                    .font(.system(size: 36))
                    .foregroundColor(isPlaying ? .black : Color(hex: "#00ff88").opacity(0.35))
                    .padding(.leading, 4)

                Text("PLAY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundColor(isPlaying ? .black : Color(hex: "#00ff88").opacity(0.35))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                isPlaying ?
                LinearGradient(
                    colors: [Color(hex: "#00ff88"), Color(hex: "#00dd77")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color(hex: "#2a2a2a"), Color(hex: "#1e1e1e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPlaying ? Color.clear : Color(hex: "#00ff88").opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(10)
            .shadow(color: isPlaying ? Color(hex: "#00ff88").opacity(0.5) : .black.opacity(0.4), radius: isPlaying ? 17 : 8, y: 6)
        }
    }
}

// RECORD button: Red when active (recording state)
struct TransportRecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("●")
                    .font(.system(size: 32))
                    .foregroundColor(isRecording ? .white : Color(hex: "#ff3b30").opacity(0.35))

                Text("REC")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundColor(isRecording ? .white : Color(hex: "#ff3b30").opacity(0.35))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                isRecording ?
                LinearGradient(
                    colors: [Color(hex: "#ff3b30"), Color(hex: "#dd3328")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [Color(hex: "#2a2a2a"), Color(hex: "#1e1e1e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isRecording ? Color.clear : Color(hex: "#ff3b30").opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(10)
            .shadow(color: isRecording ? Color(hex: "#ff3b30").opacity(0.5) : .black.opacity(0.4), radius: isRecording ? 17 : 8, y: 6)
        }
    }
}

// =========================================================================
// MARK: - Home Indicator: iPhone Gesture Bar
// =========================================================================
// Small rounded bar at bottom matching iOS home indicator
// =========================================================================

struct HomeIndicator: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(hex: "#333333"))
            .frame(width: 100, height: 4)
            .padding(.bottom, 8)
    }
}

// =========================================================================
// MARK: - Device Picker Sheet: Select MIDI Destination
// =========================================================================
// Modal sheet that displays all available MIDI destinations
// User can tap to select and connect to a specific device
// =========================================================================

struct DevicePickerView: View {
    @ObservedObject var midi: MIDIManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color(hex: "#0c0c0c")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if midi.destinations.isEmpty {
                        SetupGuideView(midi: midi)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Device list
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

                    // Debug footer
                    VStack(spacing: 10) {
                        Divider()

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(midi.destinations.count) DESTINATIONS FOUND")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundColor(Color(hex: "#444444"))
                                if let name = midi.selectedDestination.map({ midi.name(for: $0) }) {
                                    Text("→ \(name)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color(hex: "#00ff88"))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                Text("TCP: \(midi.listenerDebug)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "#666666"))
                                Text("MAC: \(midi.companionDebug)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "#666666"))
                                Text("incoming: \(midi.incomingCount)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "#666666"))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        Button(action: { midi.reconnect() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("RECONNECT")
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(2)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#00d4ff").opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#00d4ff").opacity(0.4), lineWidth: 1)
                            )
                            .cornerRadius(10)
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
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#ff6b35"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Individual device row with selection indicator
struct DeviceRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                // Device icon
                Image(systemName: "cable.connector")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color(hex: "#00ff88") : Color(hex: "#666666"))
                    .frame(width: 32)

                // Device name
                Text(name)
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                Spacer()

                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#00ff88"))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                isSelected ?
                Color(hex: "#00ff88").opacity(0.08) :
                Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// =========================================================================
// MARK: - Setup Guide: Step-by-step WiFi MIDI connection instructions
// =========================================================================
// Shown in DevicePickerView when no MIDI destinations are found.
// Guides the user through the one-time Audio MIDI Setup step on Mac.
// =========================================================================

struct SetupGuideView: View {
    @ObservedObject var midi: MIDIManager

    private struct Step {
        let number: Int
        let title: String
        let detail: String
        let color: String
    }

    private let steps: [Step] = [
        Step(number: 1, title: "Same WiFi",        detail: "Connect your iPhone and Mac to the same WiFi network.",                                      color: "#00d4ff"),
        Step(number: 2, title: "Audio MIDI Setup", detail: "On your Mac, open:\nApplications → Utilities → Audio MIDI Setup",                            color: "#ff6b35"),
        Step(number: 3, title: "MIDI Studio",      detail: "Go to Window → Show MIDI Studio.\nClick the Network icon in the toolbar.",                   color: "#ffcc00"),
        Step(number: 4, title: "Connect",          detail: "Find \"Ctrlr\" in the Directory list on the left.\nClick Connect — you're done.",             color: "#00ff88"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Header
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

                // Steps
                VStack(spacing: 0) {
                    ForEach(steps, id: \.number) { step in
                        HStack(alignment: .top, spacing: 14) {
                            // Numbered circle
                            ZStack {
                                Circle()
                                    .fill(Color(hex: step.color).opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Text("\(step.number)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: step.color))
                            }

                            // Step content
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

                // Advertising status
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

                // Refresh button
                Button(action: { midi.refreshDestinations() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("REFRESH DEVICES")
                            .tracking(1)
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

// =========================================================================
// MARK: - Color Extension: Hex String to SwiftUI Color
// =========================================================================
// Utility to create Color from hex strings like "#ff0000"
// =========================================================================

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
