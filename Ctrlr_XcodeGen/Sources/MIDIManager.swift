import Foundation
import CoreMIDI

// MARK: - MIDI Error Types

enum MIDIConnectionError: Error, LocalizedError {
    case clientCreationFailed(OSStatus)
    case portCreationFailed(OSStatus)
    case noDestinationSelected
    case sendFailed(OSStatus)
    case deviceDisconnected

    var errorDescription: String? {
        switch self {
        case .clientCreationFailed(let status):
            return "Failed to create MIDI client (error: \(status))"
        case .portCreationFailed(let status):
            return "Failed to create MIDI output port (error: \(status))"
        case .noDestinationSelected:
            return "No MIDI device selected"
        case .sendFailed(let status):
            return "Failed to send MIDI message (error: \(status))"
        case .deviceDisconnected:
            return "MIDI device disconnected"
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

    private var lastSelectedDeviceName: String?

    enum ConnectionState {
        case disconnected
        case connected
        case error
    }

    init() {
        setupMIDI()
    }

    // MARK: - Setup

    private func setupMIDI() {
        // Create MIDI client with notification callback
        let clientResult = MIDIClientCreateWithBlock("CtrlrClient" as CFString, &client) { [weak self] notification in
            self?.handleMIDINotification(notification)
        }

        if clientResult != noErr {
            lastError = .clientCreationFailed(clientResult)
            connectionState = .error
            return
        }

        let portResult = MIDIOutputPortCreate(client, "CtrlrOut" as CFString, &outPort)
        if portResult != noErr {
            lastError = .portCreationFailed(portResult)
            connectionState = .error
            return
        }

        refreshDestinations()
    }

    // MARK: - MIDI Notifications (Device Connect/Disconnect)

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let messageID = notification.pointee.messageID

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch messageID {
            case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
                // Device configuration changed - refresh and try to reconnect
                self.refreshDestinations()
                self.attemptReconnect()

            case .msgPropertyChanged, .msgThruConnectionsChanged, .msgSerialPortOwnerChanged:
                // Other changes - just refresh
                self.refreshDestinations()

            default:
                break
            }
        }
    }

    // MARK: - Connection Helpers

    func name(for endpoint: MIDIEndpointRef) -> String {
        var param: Unmanaged<CFString>?
        var name = "MIDI Dest"
        let err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &param)
        if err == noErr, let take = param?.takeRetainedValue() { name = take as String }
        return name
    }

    var selectedDestinationName: String {
        selectedDestination.map { name(for: $0) } ?? "None"
    }

    var isConnected: Bool {
        selectedDestination != nil && connectionState == .connected
    }

    // MARK: - Auto-Reconnect

    private func attemptReconnect() {
        // Try to reconnect to previously selected device
        if let lastName = lastSelectedDeviceName {
            if let match = destinations.first(where: { name(for: $0) == lastName }) {
                selectedDestination = match
                connectionState = .connected
                lastError = nil
                return
            }
        }

        // If previous device not found, select first available
        if selectedDestination == nil && !destinations.isEmpty {
            selectedDestination = destinations.first
            lastSelectedDeviceName = selectedDestinationName
            connectionState = .connected
            lastError = nil
        } else if destinations.isEmpty {
            selectedDestination = nil
            connectionState = .disconnected
        }
    }

    func autoSelectPreferred(names: [String] = ["Ctrlr"]) {
        refreshDestinations()
        if let match = destinations.first(where: { names.contains(name(for: $0)) }) {
            selectedDestination = match
            lastSelectedDeviceName = name(for: match)
            connectionState = .connected
        } else if let first = destinations.first {
            selectedDestination = first
            lastSelectedDeviceName = name(for: first)
            connectionState = .connected
        }
    }

    // MARK: - Destinations

    func refreshDestinations() {
        destinations.removeAll()
        let count = MIDIGetNumberOfDestinations()
        for i in 0..<count {
            destinations.append(MIDIGetDestination(i))
        }

        // Update connection state
        if let selected = selectedDestination {
            // Check if selected device is still available
            if !destinations.contains(selected) {
                lastError = .deviceDisconnected
                connectionState = .disconnected
                selectedDestination = nil
            }
        } else if !destinations.isEmpty {
            selectedDestination = destinations.first
            lastSelectedDeviceName = selectedDestinationName
            connectionState = .connected
            lastError = nil
        }
    }

    func selectDestination(_ destination: MIDIEndpointRef) {
        selectedDestination = destination
        lastSelectedDeviceName = name(for: destination)
        connectionState = .connected
        lastError = nil
    }

    // MARK: - Send MIDI Messages

    private func sendPacket(_ data: [UInt8]) {
        guard let dest = selectedDestination else {
            lastError = .noDestinationSelected
            connectionState = .disconnected
            return
        }

        guard !data.isEmpty else { return }

        var packetList = MIDIPacketList(numPackets: 1, packet: MIDIPacket())
        let timestamp: MIDITimeStamp = 0

        withUnsafeMutablePointer(to: &packetList) { pktListPtr in
            let pkt = MIDIPacketListInit(pktListPtr)
            let addResult = MIDIPacketListAdd(pktListPtr, 1024, pkt, timestamp, data.count, data)

            if addResult != nil {
                let sendResult = MIDISend(outPort, dest, pktListPtr)
                if sendResult != noErr {
                    DispatchQueue.main.async {
                        self.lastError = .sendFailed(sendResult)
                        self.connectionState = .error
                    }
                }
            }
        }
    }

    // MARK: - MIDI Messages

    func sendNoteOn(note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) {
        sendPacket([0x90 | channel, note, velocity])
    }

    func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        sendPacket([0x80 | channel, note, 0])
    }

    func sendCC(cc: UInt8, value: UInt8, channel: UInt8 = 0) {
        sendPacket([0xB0 | channel, cc, value])
    }

    // MARK: - Error Handling

    func clearError() {
        lastError = nil
        if selectedDestination != nil {
            connectionState = .connected
        }
    }
}
