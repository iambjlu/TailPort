import SwiftUI
import AppKit
import Network
import ServiceManagement

extension Notification.Name {
    static let openMainWindow = Notification.Name("TailPort.openMainWindow")
}

let mainWindowTitle = "TailPort"

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var port = ConfigStore.shared.config.port
    @Published var serverStatus = "啟動中…"
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var notice = ""

    private var server: HTTPServer?

    /// 各網路介面的連線網址
    var urls: [(name: String, url: String)] {
        Self.localIPv4().map { ($0.0, "http://\($0.1):\(port)/") }
    }

    func startServer() {
        server?.stop()
        server = nil
        let router = Router()
        do {
            let s = try HTTPServer(port: port) { await router.handle($0) }
            s.start { state in
                Task { @MainActor in AppState.shared.serverStatus = Self.describe(state) }
            }
            server = s
        } catch {
            serverStatus = "啟動失敗:\(error)"
        }
    }

    private static func describe(_ s: NWListener.State) -> String {
        switch s {
        case .ready: return "執行中"
        case .failed(let e): return "失敗:\(e)"
        case .cancelled: return "已停止"
        default: return "啟動中…"
        }
    }

    func applyPort(_ text: String) {
        guard let p = UInt16(text.trimmingCharacters(in: .whitespaces)), p >= 1024 else {
            notice = "連接埠必須是 1024 到 65535 之間的數字"
            return
        }
        guard p != port else { return }
        port = p
        ConfigStore.shared.update { $0.port = p }
        notice = "已改用連接埠 \(p),請改用新的網址"
        startServer()
    }

    func setLaunchAtLogin(_ on: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            notice = "開機自動啟動需要把程式包成 .app(執行 build_app.sh)"
            launchAtLogin = false
            return
        }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            notice = on ? "已設定開機自動啟動" : "已取消開機自動啟動"
        } catch { notice = "開機啟動設定失敗:\(error.localizedDescription)" }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        notice = "已拷貝 \(text)"
    }

    /// 各網路介面的 IPv4:回傳 (顯示名稱, IP)。排除 loopback、link-local 與虛擬機內部網路。
    static func localIPv4() -> [(String, String)] {
        var out: [(String, String)] = []
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return out }
        defer { freeifaddrs(ifap) }
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(p.pointee.ifa_flags)
            guard flags & (IFF_UP | IFF_RUNNING) == (IFF_UP | IFF_RUNNING), flags & IFF_LOOPBACK == 0,
                  let sa = p.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let bsd = String(cString: p.pointee.ifa_name)
            if bsd.hasPrefix("gif") || bsd.hasPrefix("vmnet") || bsd.hasPrefix("bridge") { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: host)
            if ip.hasPrefix("127.") || ip.hasPrefix("169.254.") { continue }
            out.append((isTailscale(ip) ? "Tailscale" : bsd, ip))
        }
        return out
    }

    /// Tailscale 使用 CGNAT 位址範圍 100.64.0.0/10
    private static func isTailscale(_ ip: String) -> Bool {
        let p = ip.split(separator: ".").compactMap { Int($0) }
        return p.count == 4 && p[0] == 100 && (64...127).contains(p[1])
    }
}

/// 主視窗開著時 Dock 要有圖示(.regular),關掉後只剩選單列(.accessory)。
@MainActor
func showMainWindow(_ open: OpenWindowAction) {
    NSApp.setActivationPolicy(.regular)
    open(id: "main")
    NSApp.activate(ignoringOtherApps: true)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in AppState.shared.startServer() }

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let w = note.object as? NSWindow, w.title == mainWindowTitle else { return }
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { NotificationCenter.default.post(name: .openMainWindow, object: nil) }
        return true
    }
}

@main
struct TailPortApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Window(mainWindowTitle, id: "main") { SettingsView() }
            .defaultSize(width: 480, height: 420)
            .defaultLaunchBehavior(.suppressed)
    }
}

struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "dot.radiowaves.left.and.right")
            .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                showMainWindow(openWindow)
            }
    }
}

struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var state = AppState.shared
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow { Text("服務").foregroundStyle(.secondary); Text(state.serverStatus) }
                GridRow { Text("連接埠").foregroundStyle(.secondary); Text(String(state.port)) }
            }

            Divider()

            Text("連線網址(點一下拷貝)").font(.caption).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(state.urls, id: \.url) { item in
                    GridRow {
                        Text(item.name).foregroundStyle(.secondary)
                        Button {
                            state.copy(item.url)
                            copied = item.url
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if copied == item.url { copied = nil } }
                        } label: {
                            HStack(spacing: 6) {
                                Text(item.url.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "/", with: ""))
                                if copied == item.url { Image(systemName: "checkmark").foregroundStyle(.green) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            HStack {
                Button("開啟網頁") {
                    if let u = URL(string: "http://127.0.0.1:\(state.port)/") { NSWorkspace.shared.open(u) }
                }
                Button("設定…") { showMainWindow(openWindow) }
                Spacer()
                Button("結束") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

struct SettingsView: View {
    @ObservedObject private var state = AppState.shared
    @State private var portText = ""

    private var launchBinding: Binding<Bool> {
        Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) })
    }

    var body: some View {
        Form {
            Section("連線") {
                LabeledContent("服務狀態", value: state.serverStatus)
                LabeledContent("連接埠") {
                    HStack {
                        TextField("", text: $portText).multilineTextAlignment(.trailing).frame(width: 80)
                            .onSubmit { state.applyPort(portText) }
                        Button("套用") { state.applyPort(portText) }
                    }
                }
                ForEach(state.urls, id: \.url) { item in
                    LabeledContent(item.name) {
                        HStack {
                            Text(item.url).font(.caption).textSelection(.enabled)
                            Button("拷貝") { state.copy(item.url) }
                        }
                    }
                }
            }

            Section {
                Toggle("登入時自動啟動", isOn: launchBinding)
            } header: {
                Text("一般")
            } footer: {
                Text("要掃描的埠與名稱請在網頁右上角的設定按鈕裡編輯。網頁沒有密碼,僅接受區網與 Tailscale 來源的連線。")
            }

            if !state.notice.isEmpty {
                Section { Text(state.notice).font(.callout).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            portText = String(state.port)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
