import Foundation
import CoreMIDI
import Network

// Uses dns-sd subprocess for discovery (bypasses NWBrowser/NetServiceBrowser
// entitlement restrictions on macOS). Connects via NWConnection as TCP client.
// Routes received MIDI bytes to the "Ctrlr" virtual source visible in all DAWs.

final class ConnectionManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectedName: String?
    @Published var sourceCount = 0
    @Published var debugLines: [String] = []

    private var midiClient = MIDIClientRef()
    private var virtualSource = MIDIEndpointRef()
    private var discoveryProcess: Process?
    private var phoneConnection: NWConnection?

    override init() {
        super.init()
        setupVirtualMIDI()
        startBrowsing()
    }

    // MARK: - Virtual MIDI Port

    private func setupVirtualMIDI() {
        MIDIClientCreateWithBlock("CtrlrHelper" as CFString, &midiClient) { _ in }
        MIDISourceCreate(midiClient, "Ctrlr" as CFString, &virtualSource)
        updateDebug()
    }

    // MARK: - Discovery via dns-sd

    func startBrowsing() {
        discoveryProcess?.terminate()
        discoveryProcess = nil

        guard phoneConnection == nil else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
        // -L looks up a named service and prints host:port immediately
        proc.arguments = ["-L", "Ctrlr", "_ctrlr._tcp", "local."]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe() // silence stderr

        var buffer = ""
        pipe.fileHandleForReading.readabilityHandler = { [weak self, weak proc] handle in
            guard let data = try? handle.availableData,
                  !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8) else { return }
            buffer += chunk
            if let (host, port) = Self.parseHostPort(from: buffer) {
                proc?.terminate()
                DispatchQueue.main.async { self?.connectToPhone(host: host, port: port) }
            }
        }

        // If dns-sd exits without a result (service not up yet), retry
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                guard let self, self.phoneConnection == nil else { return }
                self.startBrowsing()
            }
        }

        do {
            try proc.run()
            discoveryProcess = proc
            updateDebug("dns-sd lookup…")
        } catch {
            updateDebug("dns-sd err: \(error)")
        }

        // Kill after 8 s so terminationHandler fires and we retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak proc] in
            proc?.terminate()
        }
    }

    // Parses "can be reached at <host>:<port>" from dns-sd -L output
    private static func parseHostPort(from output: String) -> (String, UInt16)? {
        let pattern = #"can be reached at ([^\s:]+):(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output,
                                           range: NSRange(output.startIndex..., in: output)),
              let hostRange = Range(match.range(at: 1), in: output),
              let portRange = Range(match.range(at: 2), in: output),
              let port = UInt16(output[portRange]) else { return nil }
        return (String(output[hostRange]), port)
    }

    // MARK: - TCP Connection

    private func connectToPhone(host: String, port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        updateDebug("connecting \(host):\(port)")
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.connectedName = "Ctrlr"
                    self.sourceCount = 1
                    self.updateDebug("conn: ready ✓")
                case .failed(let e):
                    self.isConnected = false; self.connectedName = nil
                    self.sourceCount = 0; self.phoneConnection = nil
                    self.updateDebug("conn: failed \(e)")
                    self.startBrowsing()
                case .cancelled:
                    self.isConnected = false; self.connectedName = nil
                    self.sourceCount = 0; self.phoneConnection = nil
                    self.updateDebug("conn: cancelled")
                    self.startBrowsing()
                case .waiting(let e):
                    self.updateDebug("conn: waiting \(e)")
                default: break
                }
            }
        }
        connection.start(queue: .main)
        phoneConnection = connection
        receiveMIDI(from: connection)
    }

    // MARK: - Receive + Route MIDI

    // Each message framed as: [1-byte length][midi bytes...]
    private func receiveMIDI(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
            guard let length = data?.first, error == nil else { return }
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] msg, _, _, err in
                if let msg = msg, !msg.isEmpty { self?.route(msg) }
                if err == nil { self?.receiveMIDI(from: connection) }
            }
        }
    }

    private func route(_ data: Data) {
        let bytes = [UInt8](data)
        var packetList = MIDIPacketList(numPackets: 1, packet: MIDIPacket())
        withUnsafeMutablePointer(to: &packetList) { ptr in
            let pkt = MIDIPacketListInit(ptr)
            _ = MIDIPacketListAdd(ptr, 1024, pkt, 0, bytes.count, bytes)
            MIDIReceived(virtualSource, ptr)
        }
    }

    // MARK: - Reconnect

    func reconnect() {
        phoneConnection?.cancel()
        phoneConnection = nil
        startBrowsing()
    }

    // MARK: - Debug

    private func updateDebug(_ msg: String = "") {
        var lines: [String] = []
        lines.append("virtual src: \(virtualSource)")
        lines.append("phone conn: \(phoneConnection != nil ? "active" : "none")")
        lines.append("discovery: \(discoveryProcess?.isRunning == true ? "running" : "idle")")
        if !msg.isEmpty { lines.append(msg) }
        debugLines = lines
    }

    deinit {
        MIDIEndpointDispose(virtualSource)
        MIDIClientDispose(midiClient)
        discoveryProcess?.terminate()
        phoneConnection?.cancel()
    }
}
