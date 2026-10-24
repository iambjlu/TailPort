# TailPort 架構

macOS 選單列 App(SwiftUI)。內建一個小型 HTTP 伺服器,提供網頁入口:掃描自己 tailnet 上所有上線裝置,
列出開著指定埠的裝置,點卡片展開後可直接開新分頁前往 `http://<裝置 Tailscale IP>:<埠>`。

## 檔案

- `Sources/TailPort/App.swift`:App 進入點、選單列、設定視窗、`AppState`(伺服器啟停、連接埠、開機自動啟動)。
- `Sources/TailPort/Config.swift`:`Config`(網頁服務埠 `port`,預設 8899;要掃描的 `ports`:埠、名稱、連結協定 `scheme`(http/https/vnc/ssh/smb,缺少時視為 http),例如 5900 的連結是 `vnc://<IP>:5900`、22 是 `ssh://<IP>:22`)。
  存於 `~/Library/Application Support/TailPort/config.json`。`ConfigStore.shared` 以鎖保護,網頁與 App 共用。
- `Sources/TailPort/HTTPServer.swift`:Network.framework 極簡 HTTP/1.1 伺服器。無密碼,
  只接受區網、Tailscale(100.64.0.0/10、fd7a:)與本機來源。
- `Sources/TailPort/Router.swift`:
  - `GET /` 網頁
  - `GET /api/ports` / `POST /api/ports`(需 `application/json`)讀寫要掃描的埠,驗證 1–65535、不得重複、名稱空白時用 `Port N`
  - `GET /api/scan` 執行一次掃描,只回傳至少有一個符合埠開啟的裝置
- `Sources/TailPort/Scanner.swift`:呼叫 tailscale CLI(`status --json`)取得本機與上線的 peer,
  每台裝置的每個埠以 NWConnection 做 TCP 連線探測(逾時 1.5 秒,全部並行)。使用 Tailscale 的 IPv4;本機這台改用 127.0.0.1 探測(連自己的 Tailscale IP 會經過 utun,可能被防火牆擋下而逾時),網頁連結仍是 Tailscale IP。
  裝置名稱取 `HostName`(保留 U+F8FF 蘋果標誌,只整理空白;非 Apple 系統的瀏覽器會顯示成方框),沒有則用 DNSName 第一段。
- `Sources/TailPort/Web.swift`:單頁網頁(卡片可展開、設定對話框編輯埠與名稱、30 秒自動重新整理;設定對話框每個埠有「只顯示」核取方塊,純前端篩選:伺服器永遠回傳全部結果,勾選的埠存在瀏覽器 localStorage(`tailport.filter`);全不勾或全勾顯示全部,只勾部分時只顯示勾選的埠(裝置沒有任何勾選的埠就不顯示卡片);卡片上有拷貝 Tailscale IP 的按鈕;「這台 Mac」那張卡片的連結主機取自瀏覽器網址列的主機名稱(location.hostname),其他裝置用各自的 Tailscale IP;禁止選取文字與雙擊/雙指縮放,輸入框除外)。
- `build_app.sh`:編譯並包成 `build/TailPort.app`(ad-hoc 簽章);`scripts/make_icon.swift` 繪製 App 圖示。

## 注意

- Tailscale CLI 路徑依序找 `/usr/local/bin/tailscale`(官方包裝腳本,會設好環境)、`/opt/homebrew/bin/tailscale`,最後才是 App 內的執行檔(直接執行它而沒有 shell 環境時會嘗試啟動 GUI 而失敗)。
- 目標裝置的 ACL 若不允許本機連入,該埠會被視為未開啟。
