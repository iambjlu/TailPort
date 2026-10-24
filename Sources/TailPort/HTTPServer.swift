import Foundation
import Network

struct HTTPRequest {
    var method: String
    var path: String
    var headers: [String: String]   // key 皆為小寫
    var body: Data

    func json() -> Any? { try? JSONSerialization.jsonObject(with: body) }
}

struct HTTPResponse {
    var status: Int = 200
    var contentType: String = "application/json; charset=utf-8"
    var body: Data = Data()

    static func json(_ obj: Any, status: Int = 200) -> HTTPResponse {
        let d = (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data("{}".utf8)
        return HTTPResponse(status: status, body: d)
    }
    static func error(_ status: Int, _ msg: String) -> HTTPResponse { .json(["error": msg], status: status) }
    static func html(_ s: String) -> HTTPResponse {
        HTTPResponse(contentType: "text/html; charset=utf-8", body: Data(s.utf8))
    }
}

/// 極簡 HTTP/1.1 伺服器(Network.framework,每個連線只處理一個請求)。
/// 僅接受來自區網、Tailscale 與本機的連線。
final class HTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let handler: @Sendable (HTTPRequest) async -> HTTPResponse
    private let queue = DispatchQueue(label: "http.server")
    private let maxBody = 64 * 1024

    init(port: UInt16, handler: @escaping @Sendable (HTTPRequest) async -> HTTPResponse) throws {
        guard let p = NWEndpoint.Port(rawValue: port) else { throw ScanError("無效的埠") }
        listener = try NWListener(using: .tcp, on: p)
        self.handler = handler
    }

    func start(onState: @escaping @Sendable (NWListener.State) -> Void) {
        listener.stateUpdateHandler = onState
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: queue)
    }

    func stop() { listener.cancel() }

    private func accept(_ conn: NWConnection) {
        guard Self.isAllowed(conn.endpoint) else { conn.cancel(); return }
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, done, err in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if err != nil || (done && data == nil) { conn.cancel(); return }
            if buf.count > self.maxBody + 16 * 1024 { self.send(conn, .error(413, "請求過大")); return }

            switch Self.parse(buf) {
            case .incomplete:
                self.receive(conn, buffer: buf)
            case .bad:
                self.send(conn, .error(400, "無效的請求"))
            case .request(let req, let need):
                if req.body.count < need { self.receive(conn, buffer: buf); return }
                Task {
                    let res = await self.handler(req)
                    self.send(conn, res)
                }
            }
        }
    }

    private func send(_ conn: NWConnection, _ r: HTTPResponse) {
        let reason = [200: "OK", 400: "Bad Request", 404: "Not Found", 413: "Payload Too Large", 415: "Unsupported Media Type"][r.status] ?? "OK"
        var head = "HTTP/1.1 \(r.status) \(reason)\r\n"
        head += "Content-Type: \(r.contentType)\r\nContent-Length: \(r.body.count)\r\n"
        head += "Cache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + r.body, completion: .contentProcessed { _ in conn.cancel() })
    }

    // MARK: 解析

    private enum Parsed { case incomplete, bad, request(HTTPRequest, bodyLength: Int) }

    private static func parse(_ data: Data) -> Parsed {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return .incomplete }
        let head = String(decoding: data[data.startIndex..<sep.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        let first = lines.removeFirst().split(separator: " ")
        guard first.count >= 2 else { return .bad }
        var headers: [String: String] = [:]
        for l in lines {
            guard let i = l.firstIndex(of: ":") else { continue }
            headers[l[..<i].lowercased()] = l[l.index(after: i)...].trimmingCharacters(in: .whitespaces)
        }
        let target = String(first[1])
        let path = String(target.split(separator: "?", maxSplits: 1).first ?? "/").removingPercentEncoding ?? "/"
        let need = Int(headers["content-length"] ?? "0") ?? 0
        let body = Data(data[sep.upperBound...])
        return .request(HTTPRequest(method: String(first[0]), path: path, headers: headers, body: body), bodyLength: need)
    }

    // MARK: 來源限制

    static func isAllowed(_ ep: NWEndpoint) -> Bool {
        guard case .hostPort(let host, _) = ep else { return false }
        switch host {
        case .ipv4(let a): return allowedV4(Array(a.rawValue))
        case .ipv6(let a):
            let b = Array(a.rawValue)
            if b == [UInt8](repeating: 0, count: 15) + [1] { return true }                       // ::1
            if b[0] == 0xfd { return true }                                                      // ULA(含 Tailscale fd7a:)
            if b[0] == 0xfe && (b[1] & 0xc0) == 0x80 { return true }                             // link-local
            if b[0..<10].allSatisfy({ $0 == 0 }) && b[10] == 0xff && b[11] == 0xff { return allowedV4(Array(b[12...])) }
            return false
        default: return false
        }
    }

    private static func allowedV4(_ b: [UInt8]) -> Bool {
        guard b.count == 4 else { return false }
        switch (b[0], b[1]) {
        case (10, _), (127, _), (192, 168): return true
        case (172, 16...31): return true
        case (100, 64...127): return true     // CGNAT,Tailscale 使用
        default: return false
        }
    }
}
