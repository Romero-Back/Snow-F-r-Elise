import SpriteKit
import AppKit

/// Камин: каменная кладка, полка с чулками и свечами, дрова и живой огонь со свечением.
final class Fireplace {
    let node = SKNode()
    static let width: CGFloat = 150
    static let height: CGFloat = 130
    var halfWidth: CGFloat { Fireplace.width / 2 }

    private struct Flame { let node: SKShapeNode; let phase: CGFloat; let speed: CGFloat; let baseScale: CGFloat }
    private var flames: [Flame] = []
    private let glow: SKSpriteNode
    private let innerGlow: SKSpriteNode
    private var candleFlames: [SKShapeNode] = []
    private var t: CGFloat = 0
    var sparkAcc: CGFloat = 0
    var crackleAcc: CGFloat = 0

    /// Где вылетают искры (в координатах камина).
    let fireCenter = CGPoint(x: 0, y: 30)

    private static let stone = NSColor(calibratedRed: 0.62, green: 0.58, blue: 0.55, alpha: 1)
    private static let stoneDark = NSColor(calibratedRed: 0.45, green: 0.41, blue: 0.39, alpha: 1)
    private static let wood = NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.12, alpha: 1)

    init() {
        glow = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: 260, height: 200))
        innerGlow = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: 110, height: 80))
        build()
    }

    func update(dt: CGFloat) {
        t += dt
        for f in flames {
            let k = f.baseScale * (0.82 + 0.22 * sin(t * f.speed + f.phase) + 0.08 * sin(t * f.speed * 2.7 + f.phase))
            f.node.yScale = k
            f.node.xScale = f.baseScale * (0.9 + 0.12 * sin(t * f.speed * 1.3 + f.phase * 2))
        }
        let flicker = 0.75 + 0.15 * sin(t * 7) + 0.1 * sin(t * 13.3)
        glow.alpha = 0.33 * flicker
        innerGlow.alpha = 0.9 * flicker
        for (i, c) in candleFlames.enumerated() {
            c.yScale = 0.85 + 0.2 * sin(t * 9 + CGFloat(i) * 2)
        }
    }

    // MARK: - Рисунок

    private func add(_ path: CGPath, _ fill: NSColor, z: CGFloat, stroke: NSColor? = nil) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = fill
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : 1
        n.zPosition = z
        node.addChild(n)
        return n
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat = 0) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
    }

    private func build() {
        let W = Fireplace.width, H = Fireplace.height
        // Свечение на комнату — позади всего.
        glow.color = NSColor(calibratedRed: 1, green: 0.55, blue: 0.2, alpha: 1)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.position = CGPoint(x: 0, y: 40)
        glow.zPosition = -1
        node.addChild(glow)

        // Кладка из камней.
        _ = add(rect(-W / 2, 0, W, H - 18, r: 3), Fireplace.stone, z: 0)
        var rng = SystemRandomNumberGenerator()
        var y: CGFloat = 2
        var row = 0
        while y < H - 22 {
            let h: CGFloat = 13
            var x = -W / 2 + (row % 2 == 0 ? 2 : -10)
            while x < W / 2 - 2 {
                let w = CGFloat.random(in: 18...28, using: &rng)
                let x0 = max(-W / 2 + 2, x), x1 = min(W / 2 - 2, x + w - 2)
                if x1 - x0 > 4 {
                    let shade = CGFloat.random(in: -0.06...0.06, using: &rng)
                    let c = NSColor(calibratedRed: 0.62 + shade, green: 0.58 + shade, blue: 0.55 + shade, alpha: 1)
                    _ = add(rect(x0, y, x1 - x0, h - 2, r: 2.5), c, z: 0.1)
                }
                x += w
            }
            y += h
            row += 1
        }

        // Топка: арка, тёмная внутри.
        let fw: CGFloat = 86, fh: CGFloat = 66
        let box = CGMutablePath()
        box.move(to: CGPoint(x: -fw / 2, y: 8))
        box.addLine(to: CGPoint(x: -fw / 2, y: fh - fw / 2 + 8))
        box.addArc(center: CGPoint(x: 0, y: fh - fw / 2 + 8), radius: fw / 2, startAngle: .pi, endAngle: 0, clockwise: true)
        box.addLine(to: CGPoint(x: fw / 2, y: 8))
        box.closeSubpath()
        _ = add(box, NSColor(calibratedRed: 0.08, green: 0.05, blue: 0.04, alpha: 1), z: 0.5, stroke: Fireplace.stoneDark)
        _ = add(rect(-W / 2 + 6, 0, W - 12, 9, r: 2), Fireplace.stoneDark, z: 0.6)

        innerGlow.color = NSColor(calibratedRed: 1, green: 0.5, blue: 0.15, alpha: 1)
        innerGlow.colorBlendFactor = 1
        innerGlow.blendMode = .add
        innerGlow.position = CGPoint(x: 0, y: 26)
        innerGlow.zPosition = 0.7
        node.addChild(innerGlow)

        // Дрова.
        for (dx, rot) in [(-12.0, 0.18), (12.0, -0.18)] as [(CGFloat, CGFloat)] {
            let log = add(rect(-24, -5, 48, 10, r: 5), Fireplace.wood, z: 0.8)
            log.position = CGPoint(x: dx, y: 15)
            log.zRotation = rot
            let end = add(CGPath(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10), transform: nil),
                          NSColor(calibratedRed: 0.62, green: 0.42, blue: 0.25, alpha: 1), z: 0.81)
            end.position = CGPoint(x: dx + (dx < 0 ? -22 : 22) * cos(rot), y: 15 + (dx < 0 ? -22 : 22) * sin(rot))
        }

        // Огонь: несколько языков пламени, каждый «дышит» сам по себе.
        func flamePath(_ w: CGFloat, _ h: CGFloat) -> CGPath {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: h))
            p.addQuadCurve(to: CGPoint(x: w / 2, y: h * 0.25), control: CGPoint(x: w * 0.55, y: h * 0.6))
            p.addQuadCurve(to: CGPoint(x: -w / 2, y: h * 0.25), control: CGPoint(x: 0, y: -h * 0.15))
            p.addQuadCurve(to: CGPoint(x: 0, y: h), control: CGPoint(x: -w * 0.55, y: h * 0.6))
            p.closeSubpath()
            return p
        }
        let specs: [(CGFloat, CGFloat, CGFloat, NSColor, CGFloat)] = [
            (-18, 22, 34, NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.08, alpha: 0.95), 0.9),
            (16, 20, 30, NSColor(calibratedRed: 0.95, green: 0.38, blue: 0.08, alpha: 0.95), 0.91),
            (0, 30, 46, NSColor(calibratedRed: 1.00, green: 0.50, blue: 0.10, alpha: 0.95), 0.92),
            (-8, 18, 30, NSColor(calibratedRed: 1.00, green: 0.75, blue: 0.20, alpha: 0.95), 0.93),
            (9, 16, 26, NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.25, alpha: 0.95), 0.94),
            (0, 12, 20, NSColor(calibratedRed: 1.00, green: 0.95, blue: 0.70, alpha: 0.95), 0.95),
        ]
        for (dx, w, h, color, z) in specs {
            let f = add(flamePath(w, h), color, z: z)
            f.position = CGPoint(x: dx, y: 14)
            flames.append(Flame(node: f, phase: .random(in: 0...(2 * .pi), using: &rng),
                                speed: .random(in: 5...9, using: &rng), baseScale: 1))
        }

        // Полка.
        _ = add(rect(-W / 2 - 10, H - 20, W + 20, 9, r: 2), Fireplace.wood, z: 1)
        _ = add(rect(-W / 2 - 6, H - 22, W + 12, 3, r: 1), NSColor(calibratedRed: 0.25, green: 0.15, blue: 0.08, alpha: 1), z: 1)

        // Чулки на полке.
        let stockingColors: [NSColor] = [
            NSColor(calibratedRed: 0.85, green: 0.12, blue: 0.15, alpha: 1),
            NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.30, alpha: 1),
            NSColor(calibratedRed: 0.85, green: 0.12, blue: 0.15, alpha: 1),
        ]
        for (i, sx) in [CGFloat(-46), -2, 42].enumerated() {
            let top = H - 22
            let s = CGMutablePath()
            s.move(to: CGPoint(x: sx - 7, y: top))
            s.addLine(to: CGPoint(x: sx + 7, y: top))
            s.addLine(to: CGPoint(x: sx + 7, y: top - 20))
            s.addQuadCurve(to: CGPoint(x: sx + 15, y: top - 26), control: CGPoint(x: sx + 16, y: top - 21))
            s.addQuadCurve(to: CGPoint(x: sx - 4, y: top - 30), control: CGPoint(x: sx + 8, y: top - 33))
            s.addQuadCurve(to: CGPoint(x: sx - 7, y: top - 20), control: CGPoint(x: sx - 9, y: top - 27))
            s.closeSubpath()
            _ = add(s, stockingColors[i], z: 1.1)
            _ = add(rect(sx - 8, top - 6, 16, 6, r: 2), NSColor(calibratedWhite: 0.97, alpha: 1), z: 1.2)
        }

        // Свечи на полке.
        for cx in [CGFloat(-W / 2 + 4), W / 2 - 4] {
            _ = add(rect(cx - 3, H - 11, 6, 14, r: 1), NSColor(calibratedRed: 0.97, green: 0.94, blue: 0.86, alpha: 1), z: 1.3)
            let fl = add(CGPath(ellipseIn: CGRect(x: -2, y: 0, width: 4, height: 7), transform: nil),
                         NSColor(calibratedRed: 1, green: 0.8, blue: 0.3, alpha: 1), z: 1.4)
            fl.position = CGPoint(x: cx, y: H + 3)
            candleFlames.append(fl)
            let g = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: 22, height: 22))
            g.color = NSColor(calibratedRed: 1, green: 0.7, blue: 0.3, alpha: 1)
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.position = CGPoint(x: cx, y: H + 6)
            g.zPosition = 1.35
            node.addChild(g)
        }
    }
}
