// 以程式繪製 macOS App 圖示 AppIcon.icns:深灰圓角底 + 琥珀金同心圓與中心點。
// 用法:swift scripts/make_icon.swift <輸出 .icns 路徑>
import AppKit
import Foundation

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let box = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let bg = NSBezierPath(roundedRect: box, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(red: 0.43, green: 0.44, blue: 0.45, alpha: 1), ending: NSColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1))!
        .draw(in: bg, angle: -60)
    let gold = NSColor(red: 1, green: 0.84, blue: 0, alpha: 1)
    gold.setStroke(); gold.setFill()
    let c = NSPoint(x: s / 2, y: s / 2)
    for (i, r) in [0.12, 0.2, 0.28].enumerated() {
        let ring = NSBezierPath(ovalIn: NSRect(x: c.x - s * r, y: c.y - s * r, width: s * r * 2, height: s * r * 2))
        ring.lineWidth = s * 0.028
        gold.withAlphaComponent(1.0 - Double(i) * 0.3).setStroke()
        ring.stroke()
    }
    NSBezierPath(ovalIn: NSRect(x: c.x - s * 0.045, y: c.y - s * 0.045, width: s * 0.09, height: s * 0.09)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let set = out.deletingPathExtension().appendingPathExtension("iconset")
try? FileManager.default.removeItem(at: set)
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
    try png(s).write(to: set.appendingPathComponent("icon_\(s)x\(s).png"))
    try png(s * 2).write(to: set.appendingPathComponent("icon_\(s)x\(s)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", out.path]
try p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: set)
exit(p.terminationStatus)
