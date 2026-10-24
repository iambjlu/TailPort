# TailPort

一個網頁入口,列出你的 Tailscale tailnet 上「有開著指定埠」的裝置,點一下就開啟對應服務。

Mac 端是常駐選單列的 SwiftUI App,內建網頁伺服器;用任何裝置的瀏覽器開啟網址即可,不需要安裝其他東西。

**此專案僅在作者自己內網使用,網頁沒有密碼,請不要在公開外網使用。** 伺服器只接受區網、Tailscale 與本機來源的連線。

## 功能

- 掃描 tailnet 上所有上線的裝置(含這台 Mac),對你指定的每個埠做 TCP 連線探測
- 裝置只要開著任一個指定的埠就會出現一張卡片;點卡片展開,列出該裝置開著的服務名稱,點名稱就前往
- 每個埠可自訂名稱(例如 8888 → Parallels Remote、2283 → Immich)與連結協定:`http`、`https`、`vnc`、`ssh`、`smb`(例如 5900 開 `vnc://<IP>:5900`、22 開 `ssh://<IP>:22`)
- 每張卡片旁有按鈕可拷貝該裝置的 Tailscale IP
- 「這台 Mac」那張卡片的連結使用瀏覽器網址列的主機,例如用 `192.168.1.5` 開網頁,就會用 `192.168.1.5:80` 開它的 Web;其他裝置使用各自的 Tailscale IP
- 設定(齒輪)裡每個埠有「只顯示」核取方塊:全不勾或全勾顯示全部,只勾部分就只顯示那幾個。篩選只存在該瀏覽器
- 每 30 秒自動重新整理,也可手動重新整理
- 選單列常駐;開啟設定視窗期間 Dock 才有圖示

## 需求

- macOS 15 或更新
- 已安裝並登入 Tailscale(App 透過 `tailscale status --json` 取得裝置清單;找不到 CLI 時請在 Tailscale 設定裡安裝)
- Swift 6 工具鏈(Xcode)

## 建置與執行

```bash
swift run                 # 開發用:直接執行
./build_app.sh            # 打包成 build/TailPort.app(ad-hoc 簽章)
./build_app.sh --run      # 打包後結束執行中的 TailPort 並重新開啟
```

啟動後選單列會出現雷達圖示。點圖示可看到連線網址(點一下拷貝)與「開啟網頁」。預設網址為 `http://<這台 Mac 的 IP>:8899/`,可用 Tailscale IP 從其他裝置開啟。

> **登入時自動啟動**需要使用打包後的 `.app`(`SMAppService` 的限制);用 `swift run` 執行時,設定視窗會提示這一點。

## 設定

| 項目 | 位置 | 說明 |
|---|---|---|
| 連接埠 | Mac 設定視窗(選單列 →「設定…」) | 網頁服務的埠,預設 8899,套用後會重啟服務 |
| 登入時自動啟動 | Mac 設定視窗 | 需要 `.app` |
| 要掃描的埠、名稱、協定 | 網頁右上角齒輪 | 預設有 8888、9000、8000、2283、8181、80、5900、22 |

設定存放在 `~/Library/Application Support/TailPort/config.json`。

## 疑難排解

- **「無法讀取 Tailscale 狀態」**:確認 Tailscale 已登入並連線。App 優先使用 `/usr/local/bin/tailscale`,直接執行 `Tailscale.app` 內的執行檔在沒有 shell 環境時會失敗。
- **某台裝置明明有開埠卻沒出現**:該裝置的 Tailscale ACL 可能不允許這台 Mac 連入,會被當成未開啟。
- **連自己的 Tailscale IP 逾時**:macOS 應用程式防火牆可能擋掉經過 Tailscale 通道的連入(常見於重新編譯後簽章改變的 App),到「系統設定 → 網路 → 防火牆」重新允許該 App。掃描這台 Mac 時改走 `127.0.0.1` 以避開此問題。

架構說明請見 [Readme_Architecture.md](Readme_Architecture.md)。
