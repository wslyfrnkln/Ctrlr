import Foundation
import CoreMIDI

final class MIDIManager: ObservableObject {
    private var client = MIDIClientRef()
    private var outPort = MIDIPortRef()
    @Published var destinations: [MIDIEndpointRef] = []
    @Published var selectedDestination: MIDIEndpointRef?

    init() {
        let clientResult = MIDIClientCreate("TrkCtrlClient" as CFString, nil, nil, &client)
        if clientResult != noErr {
            print("Failed to create MIDI client: \(clientResult)")
        }
        
        let portResult = MIDIOutputPortCreate(client, "TrkCtrlOut" as CFString, &outPort)
        if portResult != noErr {
            print("Failed to create MIDI output port: \(portResult)")
        }
        
        refreshDestinations()
    }
    // *********************************************************** BEGIN TESTING
    /*
        TESTING
     */
    // Add this helper inside MIDIManager
    func name(for endpoint: MIDIEndpointRef) -> String {
        var param: Unmanaged<CFString>?
        var name = "MIDI Dest"
        let err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &param)
        if err == noErr, let take = param?.takeRetainedValue() { name = take as String }
        return name
    }

    // Connection helpers
    var selectedDestinationName: String {
        selectedDestination.map { name(for: $0) } ?? "None"
    }

    var isConnected: Bool {
        selectedDestination != nil
    }

    // Optional: prefer specific destination names automatically
    func autoSelectPreferred(names: [String] = ["TrkCtrl"]) {
        refreshDestinations()
        if let match = destinations.first(where: { names.contains(name(for: $0)) }) {
            selectedDestination = match
        } else {
            selectedDestination = destinations.first
        }
    }

    // Basic ping
    func ping() {
        // Middle C Note On/Off
        sendNoteOn(note: 60)
        sendNoteOff(note: 60)
    }
    // *********************************************************** END TESTING

    func refreshDestinations() {
        destinations.removeAll()
        let count = MIDIGetNumberOfDestinations()
        for i in 0..<count {
            destinations.append(MIDIGetDestination(i))
        }
        selectedDestination = destinations.first
    }

    private func sendPacket(_ data: [UInt8]) {
        guard let dest = selectedDestination else { 
            print("No MIDI destination selected")
            return 
        }
        
        guard !data.isEmpty else {
            print("Empty MIDI data")
            return
        }
        
        var packetList = MIDIPacketList(numPackets: 1, packet: MIDIPacket())
        let timestamp: MIDITimeStamp = 0
        
        withUnsafeMutablePointer(to: &packetList) { pktListPtr in
            let pkt = MIDIPacketListInit(pktListPtr)
            let addResult = MIDIPacketListAdd(pktListPtr, 1024, pkt, timestamp, data.count, data)
            
            if addResult != nil {
                let sendResult = MIDISend(outPort, dest, pktListPtr)
                if sendResult != noErr {
                    print("Failed to send MIDI packet: \(sendResult)")
                }
            } else {
                print("Failed to add MIDI packet to list")
            }
        }
    }

    // Note On/Off on channel 1
    func sendNoteOn(note: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) {
        sendPacket([0x90 | channel, note, velocity])
    }
    func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        sendPacket([0x80 | channel, note, 0])
    }

    // Control Change on channel 1
    func sendCC(cc: UInt8, value: UInt8, channel: UInt8 = 0) {
        sendPacket([0xB0 | channel, cc, value])
    }
}
