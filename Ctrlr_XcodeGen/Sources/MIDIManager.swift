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
    @Published var serviceDebug: String = "not registered"
    @Published var companionDebug: String = "no mac conn"
    @Published var incomingCount: Int = 0
    @Published var localIP: String = "—"

    private func startMIDIServer() {
        updateLocalIP()

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let listener = try? NWListener(using: params, on: 51235) else {
            listenerDebug = "port 51235 busy"; return
        }
        listener.service = NWListener.Service(name: "Ctrlr", type: "_ctrlr._tcp")

        // Guard against stale callbacks from a previously cancelled listener
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            DispatchQueue.main.async {
                guard let self, self.midiListener === listener else { return }
                switch state {
                case .ready:
                    self.listenerDebug = "listening :51235"
                    if !self.companionConnected { self.companionDebug = "waiting for mac" }
                case .failed:   self.listenerDebug = "failed"
                case .waiting:  self.listenerDebug = "waiting (port busy?)"
                case .cancelled: self.listenerDebug = "stopped"
                default: break
                }
            }
        }

        listener.serviceRegistrationUpdateHandler = { [weak self, weak listener] change in
            DispatchQueue.main.async {
                guard let self, self.midiListener === listener else { return }
                switch change {
                case .add(let endpoint): self.serviceDebug = "\(endpoint)"
                case .remove:            self.serviceDebug = "removed"
                @unknown default: break
                }
            }
        }

        listener.newConnectionHandler = { [weak self, weak listener] connection in
            DispatchQueue.main.async {
                guard let self, self.midiListener === listener else { return }
                self.incomingCount += 1
            }
            self?.acceptMacConnection(connection)
        }
        listener.start(queue: .main)
        midiListener = listener
        listenerDebug = "starting…"
    }

    func restartServer() {
        macConnection?.cancel()
        macConnection = nil
        companionConnected = false
        companionDebug = "restarting…"
        serviceDebug = "not registered"
        incomingCount = 0

        if midiListener != nil {
            midiListener?.cancel()
            midiListener = nil
            // Brief delay for port release before rebinding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startMIDIServer()
            }
        } else {
            startMIDIServer()
        }
    }

    private func updateLocalIP() {
        var address = "—"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { localIP = address; return }
        defer { freeifaddrs(first) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = ptr {
            let name = String(cString: ifa.pointee.ifa_name)
            if name == "en0", ifa.pointee.ifa_addr.pointee.sa_family == sa_family_t(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(ifa.pointee.ifa_addr, socklen_t(ifa.pointee.ifa_addr.pointee.sa_len),
                            &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: host)
                break
            }
            ptr = ifa.pointee.ifa_next
        }
        localIP = address
    }

    private func acceptMacConnection(_ connection: NWConnection) {
        macConnection?.cancel()
        macConnection = connection
        companionDebug = "mac connecting…"
        // Capture connection weakly so stale callbacks from a cancelled/replaced
        // connection don't overwrite state belonging to the *new* connection.
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.companionConnected = true
                    self.connectionState = .connected
                    self.lastError = nil
                    self.companionDebug = "mac: ready ✓"
                    // Send handshake ping so Mac can verify this is real
                    self.macConnection?.send(content: Data([0x01, 0xFF]), completion: .idempotent)
                case .failed(let e):
                    // Only clean up if this is still the active connection.
                    if self.macConnection === connection {
                        self.companionConnected = false
                        self.macConnection = nil
                        if self.selectedDestination == nil { self.connectionState = .disconnected }
                    }
                    self.companionDebug = "mac: failed \(e)"
                case .cancelled:
                    if self.macConnection === connection {
                        self.companionConnected = false
                        self.macConnection = nil
                        if self.selectedDestination == nil { self.connectionState = .disconnected }
                    }
                    self.companionDebug = "mac: cancelled"
                case .waiting(let e):
                    self.companionDebug = "mac: waiting \(e)"
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

    var diagnosticText: String {
        """
        TCP: \(listenerDebug)
        SVC: \(serviceDebug)
        MAC: \(companionDebug)
        IP:  \(localIP)
        IN:  \(incomingCount)
        DST: \(destinations.count)
        SEL: \(selectedDestinationName)
        """
    }

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

    func reconnect() {
        refreshDestinations()
        attemptReconnect()
        restartServer()
    }

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
