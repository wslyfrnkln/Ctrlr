import Foundation
import CoreMIDI
import Network

// Discovery: NWBrowser (primary) → dns-sd subprocess (fallback).
// NWBrowser uses live Bonjour state; dns-sd fallback adds a self-host filter
// so stale Simulator records (which resolve to the Mac itself) are rejected.
// Routes received MIDI bytes to the "Ctrlr" virtual source visible in all DAWs.

final class ConnectionManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectedName: String?
    @Published var sourceCount = 0
    @Published var debugLines: [String] = []
    @Published var connectedEndpoint: String?

    private var midiClient = MIDIClientRef()
    private var virtualSource = MIDIEndpointRef()     // "Ctrlr" — claimed by remote script
    private var mapSource = MIDIEndpointRef()          // "Ctrlr Map" — MIDI-learnable
    private var browser: NWBrowser?
    private var discoveryProcess: Process?
    private var phoneConnection: NWConnection?
    private var rejectedEndpoints: Set<String> = []

    // Mac's own hostname stem (e.g. "wslyfrnkln-mac"), used to reject self-connections
    private let selfHost: String = {
        ProcessInfo.processInfo.hostName.lowercased()
            .replacingOccurrences(of: ".local.", with: "")
            .replacingOccurrences(of: ".local", with: "")
    }()

    override init() {
        super.init()
        setupVirtualMIDI()
        startBrowsing()
    }

    // MARK: - Virtual MIDI Port

    private func setupVirtualMIDI() {
        MIDIClientCreateWithBlock("CtrlrHelper" as CFString, &midiClient) { _ in }
        MIDISourceCreate(midiClient, "Ctrlr" as CFString, &virtualSource)
        MIDISourceCreate(midiClient, "Ctrlr Map" as CFString, &mapSource)
        updateDebug()
    }

    // MARK: - Discovery: NWBrowser (primary)

    func startBrowsing() {
        stopDiscovery()
        guard phoneConnection == nil else { return }

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_ctrlr._tcp", domain: "local.")
        let newBrowser = NWBrowser(for: descriptor, using: .tcp)

        newBrowser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    self.updateDebug("NWBrowser: searching…")
                case .failed(let error):
                    self.updateDebug("NWBrowser failed → dns-sd")
                    self.browser?.cancel()
                    self.browser = nil
                    self.startDnsSdFallback()
                case .cancelled:
                    break
                default: break
                }
            }
        }

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                guard let self, self.phoneConnection == nil else { return }
                guard let result = results.first(where: {
                    if case .service(let name, _, _, _) = $0.endpoint {
                        return name == "Ctrlr" && !self.rejectedEndpoints.contains("\($0.endpoint)")
                    }
                    return false
                }) else { return }

                self.stopDiscovery()
                self.connectToEndpoint(result.endpoint)
            }
        }

        newBrowser.start(queue: .main)
        browser = newBrowser
        updateDebug("NWBrowser: starting…")

        // Fallback: if NWBrowser finds nothing after 10s, try dns-sd
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self, self.phoneConnection == nil, self.browser != nil else { return }
            self.updateDebug("NWBrowser timeout → dns-sd")
            self.browser?.cancel()
            self.browser = nil
            self.startDnsSdFallback()
        }
    }

    // MARK: - Discovery: dns-sd fallback (with self-host filter)

    private func startDnsSdFallback() {
        discoveryProcess?.terminate()
        discoveryProcess = nil
        guard phoneConnection == nil else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
        proc.arguments = ["-L", "Ctrlr", "_ctrlr._tcp", "local."]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()

        var buffer = ""
        pipe.fileHandleForReading.readabilityHandler = { [weak self, weak proc] handle in
            guard let data = try? handle.availableData,
                  !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8) else { return }
            buffer += chunk
            guard let self, let (host, port) = Self.parseHostPort(from: buffer) else { return }
            proc?.terminate()

            // Reject self-referential connections (Simulator stale records)
            let resolved = host.lowercased()
                .replacingOccurrences(of: ".local.", with: "")
                .replacingOccurrences(of: ".local", with: "")
            if resolved == self.selfHost {
                DispatchQueue.main.async {
                    self.updateDebug("dns-sd: skipped self (\(host))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        guard self.phoneConnection == nil else { return }
                        self.startDnsSdFallback()
                    }
                }
                return
            }
            DispatchQueue.main.async { self.connectToHost(host, port: port) }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                guard let self, self.phoneConnection == nil else { return }
                self.startDnsSdFallback()
            }
        }

        do {
            try proc.run()
            discoveryProcess = proc
            updateDebug("dns-sd: looking up…")
        } catch {
            updateDebug("dns-sd: error \(error)")
        }

        // Kill after 8s so terminationHandler fires and we retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak proc] in
            proc?.terminate()
        }
    }

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

    private func connectToEndpoint(_ endpoint: NWEndpoint) {
        connectedEndpoint = "\(endpoint)"
        updateDebug("connecting: \(endpoint)")
        setupConnection(NWConnection(to: endpoint, using: .tcp))
    }

    private func connectToHost(_ host: String, port: UInt16) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        connectedEndpoint = "\(host):\(port)"
        updateDebug("connecting: \(host):\(port)")
        setupConnection(NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp))
    }

    private func setupConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    // Don't confirm yet — wait for handshake ping from iPhone
                    self.updateDebug("conn: verifying…")
                    // If no handshake within 5s, this is a stale record — blocklist and retry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                        guard let self, !self.isConnected, self.phoneConnection != nil else { return }
                        if let ep = self.connectedEndpoint {
                            self.rejectedEndpoints.insert(ep)
                            self.updateDebug("conn: rejected stale \(ep)")
                        }
                        self.phoneConnection?.cancel()
                    }
                case .failed(let e):
                    self.isConnected = false; self.connectedName = nil
                    self.sourceCount = 0; self.phoneConnection = nil
                    self.connectedEndpoint = nil
                    self.updateDebug("conn: failed \(e)")
                    self.startBrowsing()
                case .cancelled:
                    self.isConnected = false; self.connectedName = nil
                    self.sourceCount = 0; self.phoneConnection = nil
                    self.connectedEndpoint = nil
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
    // 0xFF = handshake ping from iPhone (not routed to MIDI)
    private func receiveMIDI(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
            guard let length = data?.first, error == nil else { return }
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] msg, _, _, err in
                if let msg = msg, !msg.isEmpty {
                    if msg.first == 0xFF {
                        // Handshake confirmed — this is the real Ctrlr app
                        DispatchQueue.main.async {
                            guard let self else { return }
                            self.isConnected = true
                            self.connectedName = "Ctrlr"
                            self.sourceCount = 1
                            self.updateDebug("conn: verified ✓")
                        }
                    } else {
                        self?.route(msg)
                    }
                }
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
            MIDIReceived(virtualSource, ptr)  // Script port (transport/mixer)
            MIDIReceived(mapSource, ptr)      // Map port (MIDI-learnable)
        }
    }

    // MARK: - Reconnect

    func reconnect() {
        stopDiscovery()
        rejectedEndpoints.removeAll()
        if phoneConnection != nil {
            phoneConnection?.cancel()
            // .cancelled state handler will nil phoneConnection and call startBrowsing()
        } else {
            startBrowsing()
        }
    }

    private func stopDiscovery() {
        browser?.cancel()
        browser = nil
        discoveryProcess?.terminate()
        discoveryProcess = nil
    }

    // MARK: - Debug

    var diagnosticText: String {
        debugLines.joined(separator: "\n")
    }

    private func updateDebug(_ msg: String = "") {
        var lines: [String] = []
        lines.append("virtual src: \(virtualSource)")
        lines.append("phone conn: \(phoneConnection != nil ? "active" : "none")")
        if browser != nil { lines.append("NWBrowser: active") }
        else if discoveryProcess?.isRunning == true { lines.append("dns-sd: running") }
        else { lines.append("discovery: idle") }
        if let ep = connectedEndpoint { lines.append("→ \(ep)") }
        if !msg.isEmpty { lines.append(msg) }
        debugLines = lines
    }

    deinit {
        MIDIEndpointDispose(virtualSource)
        MIDIEndpointDispose(mapSource)
        MIDIClientDispose(midiClient)
        browser?.cancel()
        discoveryProcess?.terminate()
        phoneConnection?.cancel()
    }
}
