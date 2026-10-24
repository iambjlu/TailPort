# TailPort 架構

macOS 選單列 App(SwiftUI)。內建一個小型 HTTP 伺服器,提供網頁入口:掃描自己 tailnet 上所有上線裝置,
列出開著指定埠的裝置,點卡片展開後可直接開新分頁前往 `http://<裝置 Tailscale IP>:<埠>`。

## 檔案

- `Sources/TailPort/App.swift`:App 進入點、選單列、設定視窗、`AppState`(伺服器啟停、連接埠、開機自動啟動)。
- `Sources/TailPort/Config.swift`:`Config`(網頁服務埠 `port`,預設 8899;要掃描的 `ports` 與名稱)。
  存於 `~/Library/Application Support/TailPort/config.json`。`ConfigStore.shared` 以鎖保護,網頁與 App 共用。
- `Sources/TailPort/HTTPServer.swift`:Network.framework 極簡 HTTP/1.1 伺服器。無密碼,
  只接受區網、Tailscale(100.64.0.0/10、fd7a:)與本機來源。
- `Sources/TailPort/Router.swift`:
  - `GET /` 網頁
  - `GET /api/ports` / `POST /api/ports`(需 `application/json`)讀寫要掃描的埠,驗證 1–65535、不得重複、名稱空白時用 `Port N`
  - `GET /api/scan` 執行一次掃描,只回傳至少有一個符合埠開啟的裝置
- `Sources/TailPort/Scanner.swift`:呼叫 tailscale CLI(`status --json`)取得本機與上線的 peer,
  每台裝置的每個埠以 NWConnection 做 TCP 連線探測(逾時 1.5 秒,全部並行)。使用 Tailscale 的 IPv4。
  裝置名稱取 `HostName`(濾掉 U+F8FF),沒有則用 DNSName 第一段。
- `Sources/TailPort/Web.swift`:單頁網頁(卡片可展開、設定對話框編輯埠與名稱、30 秒自動重新整理)。
- `scripts/make_app.sh`:編譯並包成 `build/TailPort.app`(ad-hoc 簽章);`scripts/make_icon.swift` 繪製 App 圖示。

## 注意

- Tailscale CLI 路徑依序找 `/Applications/Tailscale.app/Contents/MacOS/Tailscale`、`/opt/homebrew/bin/tailscale`、`/usr/local/bin/tailscale`。
- 目標裝置的 ACL 若不允許本機連入,該埠會被視為未開啟。
