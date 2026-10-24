import Foundation

struct Router: Sendable {
    func handle(_ req: HTTPRequest) async -> HTTPResponse {
        switch (req.method, req.path) {
        case ("GET", "/"), ("GET", "/index.html"):
            return .html(webPage)

        case ("GET", "/api/ports"):
            return .json(["ports": portsJSON(ConfigStore.shared.config.ports)])

        case ("POST", "/api/ports"):
            // 要求 JSON 內容型別:跨站的一般表單無法送出這種請求
            guard (req.headers["content-type"] ?? "").hasPrefix("application/json") else { return .error(415, "需要 JSON") }
            guard let list = (req.json() as? [String: Any])?["ports"] as? [[String: Any]] else { return .error(400, "格式錯誤") }
            var seen = Set<Int>()
            var entries: [PortEntry] = []
            for item in list {
                guard let port = (item["port"] as? Int) ?? Int("\(item["port"] ?? "")"), (1...65535).contains(port) else {
                    return .error(400, "埠必須是 1 到 65535 之間的數字")
                }
                guard seen.insert(port).inserted else { return .error(400, "埠 \(port) 重複了") }
                let name = (item["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let scheme = (item["scheme"] as? String ?? "http").lowercased()
                guard PortEntry.schemes.contains(scheme) else { return .error(400, "不支援的協定 \(scheme)") }
                entries.append(PortEntry(port: port, name: name.isEmpty ? "Port \(port)" : String(name.prefix(40)), scheme: scheme))
            }
            ConfigStore.shared.update { $0.ports = entries }
            return .json(["ports": portsJSON(entries)])

        case ("GET", "/api/scan"):
            let result = await Scanner.scan(ConfigStore.shared.config.ports)
            var out: [String: Any] = [
                "scanned": result.scanned,
                "devices": result.devices.filter { !$0.open.isEmpty }.map { d in
                    [
                        "name": d.name, "ip": d.ip, "os": d.os, "self": d.isSelf,
                        "open": d.open.map { ["port": $0.port, "name": $0.name, "scheme": $0.scheme, "url": "\($0.scheme)://\(d.ip):\($0.port)"] },
                    ] as [String: Any]
                },
            ]
            if let e = result.error { out["error"] = e }
            return .json(out)

        default:
            return .error(404, "找不到")
        }
    }

    private func portsJSON(_ p: [PortEntry]) -> [[String: Any]] {
        p.map { ["port": $0.port, "name": $0.name, "scheme": $0.scheme ?? "http"] }
    }
}
