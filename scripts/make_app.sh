#!/bin/bash
# 把 SwiftPM 編出來的執行檔包成 TailPort.app。
# 「登入時自動啟動」(SMAppService)需要正式的 .app 才能使用。
# 用法:scripts/make_app.sh [輸出資料夾,預設為 build]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-build}"
APP="$OUT/TailPort.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TailPort"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TailPort"
swift scripts/make_icon.swift "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TailPort</string>
    <key>CFBundleDisplayName</key><string>TailPort</string>
    <key>CFBundleIdentifier</key><string>com.iambjlu.TailPort</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleExecutable</key><string>TailPort</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSLocalNetworkUsageDescription</key><string>提供網頁介面,並掃描 Tailscale 裝置上開啟的埠。</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "已建立 $APP"
