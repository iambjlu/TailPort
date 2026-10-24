import Foundation

struct PortEntry: Codable, Equatable {
    var port: Int
    var name: String
    /// 連結使用的協定(http、https、vnc、ssh、smb);舊設定檔沒有這個欄位時視為 http
    var scheme: String?
    /// 勾選「只顯示」:全不勾或全勾顯示全部,只勾部分時只掃描並顯示勾選的埠
    var filter: Bool?

    static let schemes = ["http", "https", "vnc", "ssh", "smb"]
}

struct Config: Codable {
    /// 網頁服務監聽的埠
    var port: UInt16 = 8899
    /// 要掃描的埠與顯示名稱
    var ports: [PortEntry] = [
        PortEntry(port: 8888, name: "Parallels Remote"),
        PortEntry(port: 9000, name: "專題"),
        PortEntry(port: 8000, name: "oMLX"),
        PortEntry(port: 2283, name: "Immich"),
        PortEntry(port: 8181, name: "File Browser"),
        PortEntry(port: 80, name: "Web"),
        PortEntry(port: 5900, name: "VNC/ARD", scheme: "vnc"),
        PortEntry(port: 22, name: "SSH", scheme: "ssh"),
    ]

    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TailPort", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    static func load() -> Config {
        if let d = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(Config.self, from: d) { return c }
        let c = Config()
        c.save()
        return c
    }

    func save() {
        guard let d = try? JSONEncoder().encode(self) else { return }
        try? d.write(to: Self.url, options: .atomic)
    }
}

/// 網頁與 App 共用的設定(多執行緒存取,以鎖保護)
final class ConfigStore: @unchecked Sendable {
    static let shared = ConfigStore()
    private let lock = NSLock()
    private var value = Config.load()

    var config: Config { lock.withLock { value } }

    func update(_ change: (inout Config) -> Void) {
        let c = lock.withLock { () -> Config in change(&value); return value }
        c.save()
    }
}
