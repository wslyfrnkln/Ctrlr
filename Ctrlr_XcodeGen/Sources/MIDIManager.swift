import Foundation
import CoreMIDI
import Network

// MARK: - MIDI Error Types

enum MIDIConnectionError: Error, LocalizedError {
    case clientCreationFailed(OSStatus)
    case portCreationFailed(OSStatus)
    case noDestinationSelected
    case sendFailed(OSStatus)
    case deviceDisconnected

    var errorDescription: String? {
        switch self {
        case .clientCreationFailed(let status): return "Failed to create MIDI client (error: \(status))"
        case .portCreationFailed(let status):   return "Failed to create MIDI output port (error: \(status))"
        case .noDestinationSelected:            return "No MIDI device selected"
        case .sendFailed(let status):           return "Failed to send MIDI message (error: \(status))"
        case .deviceDisconnected:               return "MIDI device disconnected"
        }
    }
}

// MARK: - MIDI Manager

final class MIDIManager: ObservableObject {
    private var client = MIDIClientRef()
    private var outPort = MIDIPortRef()

    @Published var destinations: [MIDIEndpointRef] = []
    @Published var selectedDestination: MIDIEndpointRef?
    @Published var lastError: MIDIConnectionError?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var companionConnected = false

    private var lastSelectedDeviceName: String?

    // TCP server — Mac companion connects to us
    private var midiListener: NWListener?
    private var macConnection: NWConnection?

    enum ConnectionState {
        case disconnected, connected, error
    }

    init() {
        setupMIDI()
        startMIDIServer()
    }

    // MARK: - CoreMIDI Setup

    private func setupMIDI() {
        let r = MIDIClientCreateWithBlock("CtrlrClient" as CFString, &client) { [weak self] n in
            self?.handleMIDINotification(n)
        }
        guard r == noErr else { lastError = .clientCreationFailed(r); connectionState = .error; return }

        let p = MIDIOutputPortCreate(client, "CtrlrOut" as CFString, &outPort)
        guard p == noErr else { lastError = .portCreationFailed(p); connectionState = .error; return }

        refreshDestinations()
    }

    // MARK: - TCP Server (iPhone listens, Mac connects)

    @Published var listenerDebug: String = "not started"
    @Published var companionDebug: String = "no mac conn"
    @Published var incomingCount: Int = 0

    private func startMIDIServer() {
        guard let listener = try? NWListener(using: .tcp, on: .any) else {
            listenerDebug = "init failed"; return
        }
        listener.service = NWListener.Service(name: "Ctrlr", type: "_ctrlr._tcp")
        listener.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.listenerDebug = "ready port:\(listener.port?.rawValue ?? 0)"
                case .failed(let e):
                    self?.listenerDebug = "failed:\(e)"
                case .waiting(let e):
                    self?.listenerDebug = "waiting:\(e)"
                case .cancelled:
                    self?.listenerDebug = "cancelled"
                default: break
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            DispatchQueue.main.async { self?.incomingCount += 1 }
            self?.acceptMacConnection(connection)
        }
        listener.start(queue: .main)
        midiListener = listener
    }

    private func acceptMacConnection(_ connection: NWConnection) {
        macConnection?.cancel()
        macConnection = connection
        companionDebug = "mac connecting…"
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.companionConnected = true
                    self?.connectionState = .connected
                    self?.lastError = nil
                    self?.companionDebug = "mac: ready ✓"
                case .failed(let e):
                    self?.companionConnected = false
                    self?.macConnection = nil
                    self?.companionDebug = "mac: failed \(e)"
                    if self?.selectedDestination == nil { self?.connectionState = .disconnected }
                case .cancelled:
                    self?.companionConnected = false
                    self?.macConnection = nil
                    self?.companionDebug = "mac: cancelled"
                    if self?.selectedDestination == nil { self?.connectionState = .disconnected }
                case .waiting(let e):
                    self?.companionDebug = "mac: waiting \(e)"
                default: break
                }
            }
        }
        connection.start(queue: .main)
    }

    // MARK: - MIDI Notifications

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch notification.pointee.messageID {
            case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
                self.refreshDestinations(); self.attemptReconnect()
            default:
                self.refreshDestinations()
            }
        }
    }

    // MARK: - Helpers

    func name(for endpoint: MIDIEndpointRef) -> String {
        var param: Unmanaged<CFString>?
        var name = "MIDI Dest"
        if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &param) == noErr,
           let s = param?.takeRetainedValue() { name = s as String }
        return name
    }

    var selectedDestinationName: String { selectedDestination.map { name(for: $0) } ?? "None" }

    var isConnected: Bool { companionConnected || (selectedDestination != nil && connectionState == .connected) }

    // MARK: - Auto-Reconnect

    private func attemptReconnect() {
        if let last = lastSelectedDeviceName,
           let match = destinations.first(where: { name(for: $0) == last }) {
            selectedDestination = match; connectionState = .connected; lastError = nil; return
        }
        if selectedDestination == nil && !destinations.isEmpty {
            selectedDestination = destinations.first
            lastSelectedDeviceName = selectedDestinationName
            connectionState = .connected; lastError = nil
        } else if destinations.isEmpty {
            selectedDestination = nil; connectionState = .disconnected
        }
    }

    func reconnect() { refreshDestinations(); attemptReconnect() }

    // MARK: - Destinations

    func refreshDestinations() {
        destinations = (0..<MIDIGetNumberOfDestinations()).map { MIDIGetDestination($0) }
        if let sel = selectedDestination {
            if !destinations.contains(sel) {
                lastError = .deviceDisconnected; connectionState = .disconnected; selectedDestination = nil
            }
        } else if !destinations.isEmpty {
            selectedDestination = destinations.first
            lastSelectedDeviceName = selectedDestinationName
            connectionState = .connected; lastError = nil
        }
    }

    func selectDestination(_ destination: MIDIEndpointRef) {
        selectedDestination = destination
        lastSelectedDeviceName = name(for: destination)
        connectionState = .connected; lastError = nil
    }

    // MARK: - Send MIDI

    private func sendPacket(_ data: [UInt8]) {
        guard !data.isEmpty else { return }

        // Send to Mac companion via TCP (length-prefixed)
        if let conn = macConnection {
            conn.send(content: Data([UInt8(data.count)] + data), completion: .idempotent)
        }

        // Also send via CoreMIDI if a destination is selected
        guard let dest = selectedDestination else {
            if !companionConnected { lastError = .noDestinationSelected; connectionState = .disconnected }
            return
        }

        var packetList = MIDIPacketList(numPackets: 1, packet: MIDIPacket())
        withUnsafeMutablePointer(to: &packetList) { ptr in
            let pkt = MIDIPacketListInit(ptr)
            if MIDIPacketListAdd(ptr, 1024, pkt, 0, data.count, data) != nil {
                let r = MIDISend(outPort, dest, ptr)
                if r != noErr { DispatchQueue.main.async { self.lastError = .sendFailed(r); self.connectionState = .error } }
            }
        }
    }

    func sendNoteOn(note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) { sendPacket([0x90 | channel, note, velocity]) }
    func sendNoteOff(note: UInt8, channel: UInt8 = 0)                       { sendPacket([0x80 | channel, note, 0]) }
    func sendCC(cc: UInt8, value: UInt8, channel: UInt8 = 0)                { sendPacket([0xB0 | channel, cc, value]) }

    /// Universal Real-Time MMC: F0 7F 7F 06 <cmd> F7
    /// Stop=0x01, Play=0x02, Record=0x06
    func sendMMC(command: UInt8)                                             { sendPacket([0xF0, 0x7F, 0x7F, 0x06, command, 0xF7]) }

    func clearError() { lastError = nil; if selectedDestination != nil { connectionState = .connected } }
}
