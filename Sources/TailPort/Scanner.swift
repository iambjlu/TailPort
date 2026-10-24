import Foundation
import Network

struct OpenPort: Sendable {
    var port: Int
    var name: String
}

struct ScannedDevice: Sendable {
    var name: String
    var ip: String
    var os: String
    var isSelf: Bool
    var open: [OpenPort]
}

struct ScanResult: Sendable {
    var devices: [ScannedDevice] = []
    var scanned = 0
    var error: String?
}

/// 透過 tailscale CLI 取得 tailnet 裝置,再對每台上線的裝置逐一探測指定的埠。
enum Scanner {
    private static let cliCandidates = [
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
        "/opt/homebrew/bin/tailscale",
        "/usr/local/bin/tailscale",
    ]

    private struct Peer {
        var name: String
        var ip: String
        var os: String
        var isSelf: Bool
    }

    static func scan(_ entries: [PortEntry]) async -> ScanResult {
        let peers: [Peer]
        do { peers = try await loadPeers() }
        catch { return ScanResult(error: "\(error)") }

        var devices: [ScannedDevice] = []
        await withTaskGroup(of: ScannedDevice.self) { group in
            for peer in peers {
                group.addTask {
                    let open = await withTaskGroup(of: OpenPort?.self) { g -> [OpenPort] in
                        for e in entries {
                            g.addTask { await probe(host: peer.ip, port: e.port) ? OpenPort(port: e.port, name: e.name) : nil }
                        }
                        var r: [OpenPort] = []
                        for await p in g { if let p { r.append(p) } }
                        return r.sorted { $0.port < $1.port }
                    }
                    return ScannedDevice(name: peer.name, ip: peer.ip, os: peer.os, isSelf: peer.isSelf, open: open)
                }
            }
            for await d in group { devices.append(d) }
        }
        devices.sort { ($0.isSelf ? 0 : 1, $0.name.lowercased()) < ($1.isSelf ? 0 : 1, $1.name.lowercased()) }
        return ScanResult(devices: devices, scanned: peers.count)
    }

    // MARK: Tailscale

    private static func loadPeers() async throws -> [Peer] {
        guard let cli = cliCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ScanError("找不到 tailscale 指令列工具,請確認已安裝 Tailscale")
        }
        let data: Data = try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: cli)
            p.arguments = ["status", "--json"]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            try p.run()
            let d = out.fileHandleForReading.readDataToEndOfFile()   // 先讀完再等結束,避免輸出太大塞住管線
            p.waitUntilExit()
            return d
        }.value
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ScanError("無法讀取 Tailscale 狀態,請確認 Tailscale 已登入並連線")
        }
        if let state = root["BackendState"] as? String, state != "Running" {
            throw ScanError("Tailscale 目前未連線(狀態:\(state))")
        }
        var peers: [Peer] = []
        if let me = root["Self"] as? [String: Any], let p = peer(me, isSelf: true) { peers.append(p) }
        for (_, v) in (root["Peer"] as? [String: Any]) ?? [:] {
            if let d = v as? [String: Any], d["Online"] as? Bool == true, let p = peer(d, isSelf: false) { peers.append(p) }
        }
        return peers
    }

    private static func peer(_ d: [String: Any], isSelf: Bool) -> Peer? {
        guard let ips = d["TailscaleIPs"] as? [String], let ip = ips.first(where: { !$0.contains(":") }) else { return nil }
        // 裝置名稱可能帶有 Apple 標誌的私有字元(U+F8FF),其他系統會顯示成方框,先濾掉並整理空白
        let host = (d["HostName"] as? String ?? "").replacingOccurrences(of: "\u{F8FF}", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let dnsLabel = (d["DNSName"] as? String ?? "").split(separator: ".").first.map(String.init) ?? ""
        let name = (host.isEmpty || host == "localhost") ? (dnsLabel.isEmpty ? ip : dnsLabel) : host
        return Peer(name: name, ip: ip, os: d["OS"] as? String ?? "", isSelf: isSelf)
    }

    // MARK: 探測

    /// TCP 連線成功就視為埠已開啟;逾時或被拒絕則視為未開啟。
    private static func probe(host: String, port: Int, timeout: Double = 1.5) async -> Bool {
        guard let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return false }
        return await withCheckedContinuation { cont in
            let conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
            let once = Once()
            let finish: @Sendable (Bool) -> Void = { ok in
                guard once.first() else { return }
                conn.cancel()
                cont.resume(returning: ok)
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }
}

/// 確保結果只回報一次(連線成功與逾時可能同時發生)
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func first() -> Bool { lock.withLock { defer { done = true }; return !done } }
}

struct ScanError: Error, CustomStringConvertible {
    var description: String
    init(_ d: String) { description = d }
}
