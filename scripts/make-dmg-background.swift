// Рисует фон окна установщика (.dmg) и собирает Resources/dmg/background.tiff (1x + 2x для Retina).
// Запуск: swift scripts/make-dmg-background.swift
//
// Окно 660×420: приложение слева (центр 165, 205), «Программы» справа (495, 205) — координаты
// от верхнего левого угла, как их задаёт Finder. Фон светлый: Finder подписывает иконки тёмным текстом.
import AppKit

let W: CGFloat = 660, H: CGFloat = 420

/// Детерминированный генератор — чтобы фон не менялся от запуска к запуску.
struct LCG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(s >> 33) / CGFloat(UInt32.max >> 1)
    }
}

func render(scale: CGFloat) -> Data {
    let px = Int(W * scale), py = Int(H * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: py, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)   // точки, а не пиксели — для Retina
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let full = NSRect(x: 0, y: 0, width: W, height: H)

    // Зимнее небо.
    NSGradient(colors: [NSColor(calibratedRed: 0.80, green: 0.88, blue: 0.98, alpha: 1),
                        NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.00, alpha: 1)])!
        .draw(in: full, angle: -90)

    // Снежинки: мелкие точки и несколько шестилучевых звёздочек.
    var rnd = LCG(s: 42)
    for _ in 0..<140 {
        let p = NSPoint(x: rnd.next() * W, y: 80 + rnd.next() * (H - 80))
        let r = 0.8 + rnd.next() * 2.2
        NSColor(calibratedWhite: 1, alpha: 0.55 + rnd.next() * 0.4).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
    }
    for _ in 0..<14 {
        let p = NSPoint(x: rnd.next() * W, y: 90 + rnd.next() * (H - 100))
        let r = 4 + rnd.next() * 7
        let path = NSBezierPath()
        for k in 0..<3 {
            let a = CGFloat(k) * .pi / 3 + rnd.next()
            path.move(to: NSPoint(x: p.x - cos(a) * r, y: p.y - sin(a) * r))
            path.line(to: NSPoint(x: p.x + cos(a) * r, y: p.y + sin(a) * r))
        }
        path.lineWidth = 1.2
        path.lineCapStyle = .round
        NSColor(calibratedRed: 0.62, green: 0.75, blue: 0.95, alpha: 0.6).setStroke()
        path.stroke()
    }

    // Сугробы внизу.
    func drift(_ base: CGFloat, _ amp: CGFloat, _ phase: CGFloat, _ color: NSColor) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 0, y: 0))
        var x: CGFloat = 0
        while x <= W {
            p.line(to: NSPoint(x: x, y: base + sin(x / 95 + phase) * amp + sin(x / 41 + phase * 2) * amp * 0.35))
            x += 4
        }
        p.line(to: NSPoint(x: W, y: 0))
        p.close()
        color.setFill()
        p.fill()
    }
    drift(62, 10, 0.7, NSColor(calibratedRed: 0.82, green: 0.89, blue: 0.99, alpha: 1))
    drift(46, 8, 2.1, NSColor(calibratedWhite: 1, alpha: 1))

    // Название — как на автографе Бетховена.
    let navy = NSColor(calibratedRed: 0.13, green: 0.22, blue: 0.42, alpha: 1)
    let title = NSAttributedString(string: "Für Elise", attributes: [
        .font: NSFont(name: "SnellRoundhand-Bold", size: 46) ?? NSFont.systemFont(ofSize: 34, weight: .semibold),
        .foregroundColor: navy,
    ])
    let ts = title.size()
    title.draw(at: NSPoint(x: (W - ts.width) / 2, y: H - 30 - ts.height))

    // Стрелка от приложения к «Программам»: пунктирная дуга.
    let yArrow = H - 205
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 250, y: yArrow + 4))
    arrow.curve(to: NSPoint(x: 408, y: yArrow + 4),
                controlPoint1: NSPoint(x: 290, y: yArrow + 38), controlPoint2: NSPoint(x: 368, y: yArrow + 38))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    arrow.setLineDash([9, 7], count: 2, phase: 0)
    navy.withAlphaComponent(0.75).setStroke()
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 396, y: yArrow + 16))
    head.line(to: NSPoint(x: 410, y: yArrow + 3))
    head.line(to: NSPoint(x: 392, y: yArrow - 2))
    head.lineWidth = 3
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Подсказка под иконками.
    func centered(_ s: String, _ size: CGFloat, _ y: CGFloat, _ alpha: CGFloat) {
        let a = NSAttributedString(string: s, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: navy.withAlphaComponent(alpha),
        ])
        a.draw(at: NSPoint(x: (W - a.size().width) / 2, y: y))
    }
    centered("Перетащите Für Elise в «Программы»", 14, 104, 0.85)
    centered("Drag Für Elise to Applications", 11, 86, 0.55)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let out = root.appendingPathComponent("Resources/dmg")
try! fm.createDirectory(at: out, withIntermediateDirectories: true)
let tmp = root.appendingPathComponent("build/dmgbg")
try? fm.removeItem(at: tmp)
try! fm.createDirectory(at: tmp, withIntermediateDirectories: true)
try! render(scale: 1).write(to: tmp.appendingPathComponent("background.png"))
try! render(scale: 2).write(to: tmp.appendingPathComponent("background@2x.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
p.arguments = ["-cathidpicheck", tmp.appendingPathComponent("background.png").path,
               tmp.appendingPathComponent("background@2x.png").path,
               "-out", out.appendingPathComponent("background.tiff").path]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Resources/dmg/background.tiff готов" : "tiffutil упал")
