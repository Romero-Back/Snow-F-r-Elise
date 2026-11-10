import SpriteKit
import AppKit

/// Новогодняя ёлка в углу экрана: ярусы с хвоей и снежными шапками, игрушки, огоньки, звезда,
/// подарки. Если провести по ней курсором — качается и стряхивает снег.
final class ChristmasTree {
    let node = SKNode()
    let height: CGFloat
    let halfWidth: CGFloat
    private let sway = SKNode()
    private var lights: [(bulb: SKShapeNode, glow: SKSpriteNode, phase: CGFloat, speed: CGFloat)] = []
    private let starGlow: SKSpriteNode
    private var angle: CGFloat = 0
    private var angVel: CGFloat = 0
    private var t: CGFloat = 0

    private static let needle = NSColor(calibratedRed: 0.10, green: 0.42, blue: 0.22, alpha: 1)
    private static let needleDark = NSColor(calibratedRed: 0.06, green: 0.30, blue: 0.16, alpha: 1)
    private static let snow = NSColor(calibratedWhite: 0.98, alpha: 0.95)
    private static let gold = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.25, alpha: 1)
    private static let ornaments: [NSColor] = [
        NSColor(calibratedRed: 0.90, green: 0.15, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.85, green: 0.88, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.70, green: 0.35, blue: 0.90, alpha: 1),
    ]
    private static let lightPalette: [NSColor] = [
        NSColor(calibratedRed: 1.00, green: 0.25, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.95, blue: 0.45, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.65, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.40, blue: 0.85, alpha: 1),
    ]

    init(height h: CGFloat, lights style: GarlandStyle, gifts: Bool) {
        height = h
        halfWidth = h * 0.36
        starGlow = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: h * 0.17, height: h * 0.17))
        node.addChild(sway)
        var rng = SystemRandomNumberGenerator()
        build(h: h, style: style, gifts: gifts, rng: &rng)
    }

    /// Курсор задел ёлку — она качается.
    func nudge(_ strength: CGFloat) { angVel += strength }

    func update(dt: CGFloat, mode: GarlandMode) {
        t += dt
        // Затухающие колебания вокруг основания.
        angVel += (-angle * 40 - angVel * 4) * dt
        angle += angVel * dt
        sway.zRotation = angle
        starGlow.alpha = 0.65 + 0.25 * sin(t * 2.2)
        let step = Int(t * 5)
        for (i, l) in lights.enumerated() {
            let v: CGFloat
            switch mode {
            case .steady: v = 1
            case .chase: v = ((i - step) % 3 + 3) % 3 == 0 ? 1 : 0.2
            case .twinkle: v = 0.3 + 0.7 * max(0, sin(t * l.speed + l.phase))
            }
            l.bulb.alpha = 0.45 + 0.55 * v
            l.glow.alpha = 0.85 * v
        }
    }

    // MARK: - Рисунок

    private func add(_ path: CGPath, _ fill: NSColor, z: CGFloat, to parent: SKNode? = nil) {
        let n = SKShapeNode(path: path)
        n.fillColor = fill
        n.strokeColor = .clear
        n.zPosition = z
        (parent ?? sway).addChild(n)
    }

    private func build<R: RandomNumberGenerator>(h: CGFloat, style: GarlandStyle, gifts: Bool, rng: inout R) {
        // Ствол.
        add(CGPath(rect: CGRect(x: -h * 0.05, y: 0, width: h * 0.1, height: h * 0.14), transform: nil),
            NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.14, alpha: 1), z: 0)

        // Ярусы снизу вверх, с волнистым нижним краем и снежной шапкой.
        let tiers = 4
        var tierShapes: [(base: CGFloat, top: CGFloat, half: CGFloat)] = []
        for i in 0..<tiers {
            let k = CGFloat(i)
            let base = h * (0.1 + k * 0.19)
            let top = base + h * (0.36 - k * 0.03)
            let half = h * (0.36 - k * 0.075)
            tierShapes.append((base, top, half))
            let z = 1 + k * 0.1

            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: top))
            p.addLine(to: CGPoint(x: -half, y: base))
            let scallops = 5 - i / 2
            let sw = 2 * half / CGFloat(scallops)
            for s in 0..<scallops {
                let x0 = -half + CGFloat(s) * sw
                p.addQuadCurve(to: CGPoint(x: x0 + sw, y: base), control: CGPoint(x: x0 + sw / 2, y: base - h * 0.035))
            }
            p.closeSubpath()
            add(p, ChristmasTree.needle, z: z)

            // Тень справа — объём.
            let shade = CGMutablePath()
            shade.move(to: CGPoint(x: 0, y: top))
            shade.addLine(to: CGPoint(x: half, y: base))
            shade.addLine(to: CGPoint(x: half * 0.25, y: base - h * 0.02))
            shade.closeSubpath()
            add(shade, ChristmasTree.needleDark, z: z + 0.01)

            // Снег по нижнему краю яруса.
            let sn = CGMutablePath()
            sn.move(to: CGPoint(x: -half * 0.98, y: base + h * 0.005))
            var x = -half * 0.98
            while x < half * 0.95 {
                let nx = min(half * 0.95, x + h * 0.05)
                sn.addQuadCurve(to: CGPoint(x: nx, y: base + h * 0.005 + (x - (-half)) / (2 * half) * h * 0.012),
                                control: CGPoint(x: (x + nx) / 2, y: base + h * CGFloat.random(in: 0.025...0.045, using: &rng)))
                x = nx
            }
            sn.addLine(to: CGPoint(x: half * 0.6, y: base - h * 0.012))
            sn.addLine(to: CGPoint(x: -half * 0.7, y: base - h * 0.015))
            sn.closeSubpath()
            add(sn, ChristmasTree.snow, z: z + 0.02)
        }

        // Игрушки — внутри треугольников ярусов.
        let ballR = max(2.5, h * 0.026)
        for (i, tier) in tierShapes.enumerated() {
            let count = 4 - i / 2
            for _ in 0..<count {
                let v = CGFloat.random(in: 0.12...0.62, using: &rng)
                let y = tier.base + (tier.top - tier.base) * v
                let w = tier.half * (1 - v) * 0.8
                let x = CGFloat.random(in: -w...w, using: &rng)
                let c = ChristmasTree.ornaments.randomElement(using: &rng)!
                add(CGPath(ellipseIn: CGRect(x: x - ballR, y: y - ballR, width: 2 * ballR, height: 2 * ballR), transform: nil),
                    c, z: 1.6)
                let hr = ballR * 0.35
                add(CGPath(ellipseIn: CGRect(x: x - ballR * 0.45 - hr / 2, y: y + ballR * 0.2, width: hr, height: hr), transform: nil),
                    NSColor(calibratedWhite: 1, alpha: 0.75), z: 1.61)
            }
        }

        // Огоньки — дугами-гирляндами поперёк ярусов.
        if style != .off {
            let warm = NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.5, alpha: 1)
            var idx = 0
            for tier in tierShapes {
                let y0 = tier.base + (tier.top - tier.base) * 0.28
                let n = 6
                for j in 0..<n {
                    let u = CGFloat(j) / CGFloat(n - 1)
                    let half = tier.half * 0.72 * (1 - 0.28)
                    let x = -half + 2 * half * u
                    let y = y0 + sin(u * .pi) * -h * 0.02 + u * h * 0.04
                    let color = style == .warm ? warm : ChristmasTree.lightPalette[idx % ChristmasTree.lightPalette.count]
                    let glow = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: h * 0.09, height: h * 0.09))
                    glow.color = color
                    glow.colorBlendFactor = 1
                    glow.blendMode = .add
                    glow.position = CGPoint(x: x, y: y)
                    glow.zPosition = 1.7
                    sway.addChild(glow)
                    let br = max(1.5, h * 0.011)
                    let bulb = SKShapeNode(circleOfRadius: br)
                    bulb.fillColor = color
                    bulb.strokeColor = .clear
                    bulb.position = CGPoint(x: x, y: y)
                    bulb.zPosition = 1.71
                    sway.addChild(bulb)
                    lights.append((bulb, glow, .random(in: 0...(2 * .pi), using: &rng), .random(in: 1.5...3.5, using: &rng)))
                    idx += 1
                }
            }
        }

        // Звезда на макушке.
        let top = tierShapes.last!.top
        let sr = h * 0.06
        let star = CGMutablePath()
        for k in 0..<10 {
            let r = k % 2 == 0 ? sr : sr * 0.45
            let a = CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let p = CGPoint(x: cos(a) * r, y: top + sr * 0.6 + sin(a) * r)
            if k == 0 { star.move(to: p) } else { star.addLine(to: p) }
        }
        star.closeSubpath()
        starGlow.color = ChristmasTree.gold
        starGlow.colorBlendFactor = 1
        starGlow.blendMode = .add
        starGlow.position = CGPoint(x: 0, y: top + sr * 0.6)
        starGlow.zPosition = 1.8
        sway.addChild(starGlow)
        add(star, ChristmasTree.gold, z: 1.81)

        // Сугроб у основания и подарки (они не качаются вместе с ёлкой).
        add(CGPath(ellipseIn: CGRect(x: -h * 0.42, y: -h * 0.04, width: h * 0.84, height: h * 0.1), transform: nil),
            ChristmasTree.snow, z: 2, to: node)
        if gifts {
            let boxes: [(CGFloat, CGFloat, CGFloat, NSColor, NSColor)] = [
                (-0.33, 0.15, 0.12, NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.2, alpha: 1), ChristmasTree.gold),
                (0.20, 0.12, 0.10, NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.85, alpha: 1), .white),
                (0.36, 0.10, 0.08, NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.2, alpha: 1), NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.2, alpha: 1)),
            ]
            for (cx, w, bh, body, ribbon) in boxes {
                let bw = h * w, bhh = h * bh, x = h * cx - bw / 2
                add(CGPath(rect: CGRect(x: x, y: 0, width: bw, height: bhh), transform: nil), body, z: 2.1, to: node)
                add(CGPath(rect: CGRect(x: x + bw * 0.42, y: 0, width: bw * 0.16, height: bhh), transform: nil), ribbon, z: 2.11, to: node)
                add(CGPath(rect: CGRect(x: x, y: bhh * 0.55, width: bw, height: bhh * 0.14), transform: nil), ribbon, z: 2.11, to: node)
                let bow = CGMutablePath()
                bow.addEllipse(in: CGRect(x: x + bw * 0.5 - bw * 0.28, y: bhh - bw * 0.04, width: bw * 0.26, height: bw * 0.16))
                bow.addEllipse(in: CGRect(x: x + bw * 0.5 + bw * 0.02, y: bhh - bw * 0.04, width: bw * 0.26, height: bw * 0.16))
                add(bow, ribbon, z: 2.12, to: node)
            }
        }
    }
}
