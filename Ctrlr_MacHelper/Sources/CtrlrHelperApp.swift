import SwiftUI
import ServiceManagement

@main
struct CtrlrHelperApp: App {
    @StateObject private var manager = ConnectionManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(manager: manager)
        } label: {
            Image(systemName: manager.isConnected ? "waveform" : "waveform")
                .foregroundColor(manager.isConnected ? .green : .primary)
                .opacity(manager.isConnected ? 1.0 : 0.4)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Popover

struct MenuBarContent: View {
    @ObservedObject var manager: ConnectionManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("selectedDAW") private var selectedDAW = "ableton"
    @State private var scriptInstalled = ScriptInstaller.isInstalled
    @State private var installError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("CTRLR HELPER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("v1.0")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Connection status
            HStack(spacing: 10) {
                Circle()
                    .fill(manager.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: manager.isConnected ? .green : .clear, radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.isConnected ? "Connected" : "Searching…")
                        .font(.system(size: 13, weight: .semibold))
                    if let name = manager.connectedName {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Open Ctrlr on your iPhone")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("\(manager.sourceCount) src")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Reconnect button
            Button(action: { manager.reconnect() }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Reconnect")
                        .font(.system(size: 12))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // Launch at Login
            HStack {
                Text("Launch at Login")
                    .font(.system(size: 12))
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !enabled
                        }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // DAW Picker
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DAW")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $selectedDAW) {
                        Text("Ableton Live").tag("ableton")
                        Text("Logic Pro").tag("logic")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120)
                }

                if selectedDAW == "ableton" {
                    if scriptInstalled {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("Script installed")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: {
                            installError = nil
                            do {
                                try ScriptInstaller.install()
                                scriptInstalled = true
                            } catch {
                                installError = error.localizedDescription
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12))
                                Text("Install Script")
                                    .font(.system(size: 12))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                } else if selectedDAW == "logic" {
                    Text("Enable MMC: Logic → Synchronization → MIDI → Listen to MMC")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("MIDI signals available for manual mapping")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                if let err = installError {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Debug
            VStack(alignment: .leading, spacing: 3) {
                ForEach(manager.debugLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(manager.diagnosticText, forType: .string)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Copy")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // Quit
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Text("Quit CtrlrHelper")
                        .font(.system(size: 12))
                    Spacer()
                    Text("⌘Q")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 260)
    }
}
