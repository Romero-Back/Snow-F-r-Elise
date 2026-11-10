// Рисует иконку приложения и собирает Resources/AppIcon.icns.
// Запуск: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // Сетка иконок macOS: скруглённый квадрат 824/1024 с отступами.
    let inset = s * 100 / 1024
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.45, alpha: 1),
                        NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.85, alpha: 1)])!
        .draw(in: shape, angle: 90)
    // Сугроб внизу.
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    let drift = NSBezierPath()
    drift.move(to: NSPoint(x: rect.minX, y: rect.minY))
    drift.line(to: NSPoint(x: rect.minX, y: rect.minY + rect.height * 0.16))
    drift.curve(to: NSPoint(x: rect.maxX, y: rect.minY + rect.height * 0.20),
                controlPoint1: NSPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.30),
                controlPoint2: NSPoint(x: rect.minX + rect.width * 0.65, y: rect.minY + rect.height * 0.08))
    drift.line(to: NSPoint(x: rect.maxX, y: rect.minY))
    drift.close()
    NSColor(calibratedRed: 0.86, green: 0.92, blue: 1.0, alpha: 1).setFill()
    drift.fill()
    NSGraphicsContext.restoreGraphicsState()
    // Снежинка.
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "snowflake", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let sz = sym.size
        sym.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2 + s * 0.05, width: sz.width, height: sz.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Resources/AppIcon.icns готов" : "iconutil упал")
