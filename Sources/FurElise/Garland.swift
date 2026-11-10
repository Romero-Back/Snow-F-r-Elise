import SpriteKit
import AppKit

/// Новогодняя гирлянда под строкой меню: провод провисает между крючками, на нём лампочки с ореолом.
final class Garland {
    let node = SKNode()
    private struct Bulb {
        let bulb: SKShapeNode
        let glow: SKSpriteNode
        let phase: CGFloat
        let speed: CGFloat
    }
    private var bulbs: [Bulb] = []

    private static let palette: [NSColor] = [
        NSColor(calibratedRed: 1.00, green: 0.22, blue: 0.22, alpha: 1),   // красный
        NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.15, alpha: 1),   // золотой
        NSColor(calibratedRed: 0.20, green: 0.90, blue: 0.40, alpha: 1),   // зелёный
        NSColor(calibratedRed: 0.25, green: 0.60, blue: 1.00, alpha: 1),   // синий
        NSColor(calibratedRed: 1.00, green: 0.35, blue: 0.80, alpha: 1),   // розовый
    ]
    private static let warm = NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.48, alpha: 1)
    static let glowTexture = makeGlowTexture()

    init(width: CGFloat, topY: CGFloat, style: GarlandStyle) {
        let span: CGFloat = 120, sag: CGFloat = 16, perSpan = 4
        let spans = max(1, Int((width / span).rounded()))
        let w = width / CGFloat(spans)

        let wire = CGMutablePath()
        wire.move(to: CGPoint(x: 0, y: topY))
        var points: [CGPoint] = []
        for i in 0..<spans {
            let p0 = CGPoint(x: CGFloat(i) * w, y: topY)
            let p1 = CGPoint(x: p0.x + w, y: topY)
            // Контрольная точка на 2·sag ниже даёт провис ровно sag в середине пролёта.
            let c = CGPoint(x: (p0.x + p1.x) / 2, y: topY - sag * 2)
            wire.addQuadCurve(to: p1, control: c)
            for k in 1...perSpan {
                let t = CGFloat(k) / CGFloat(perSpan + 1)
                let a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, d = t * t
                points.append(CGPoint(x: a * p0.x + b * c.x + d * p1.x, y: a * p0.y + b * c.y + d * p1.y))
            }
        }
        let wireNode = SKShapeNode(path: wire)
        wireNode.strokeColor = NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        wireNode.lineWidth = 1.6
        wireNode.zPosition = 0
        node.addChild(wireNode)

        for (i, p) in points.enumerated() {
            let color = style == .warm ? Garland.warm : Garland.palette[i % Garland.palette.count]

            let glow = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: 30, height: 30))
            glow.color = color
            glow.colorBlendFactor = 1
            glow.blendMode = .add
            glow.position = CGPoint(x: p.x, y: p.y - 9)
            glow.zPosition = 0.5
            node.addChild(glow)

            let cap = SKShapeNode(rect: CGRect(x: -2.2, y: -4, width: 4.4, height: 4.5), cornerRadius: 1)
            cap.fillColor = NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.12, alpha: 1)
            cap.strokeColor = .clear
            cap.position = p
            cap.zPosition = 1
            node.addChild(cap)

            let bulb = SKShapeNode(ellipseOf: CGSize(width: 6, height: 10))
            bulb.fillColor = color
            bulb.strokeColor = .clear
            bulb.position = CGPoint(x: p.x, y: p.y - 9)
            bulb.zPosition = 1.1
            // Блик на стекле.
            let shine = SKShapeNode(ellipseOf: CGSize(width: 1.6, height: 3.4))
            shine.fillColor = NSColor(calibratedWhite: 1, alpha: 0.75)
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -1.2, y: 1.5)
            shine.zPosition = 0.01
            bulb.addChild(shine)
            node.addChild(bulb)

            bulbs.append(Bulb(bulb: bulb, glow: glow, phase: .random(in: 0...(2 * .pi)), speed: .random(in: 1.5...3.5)))
        }
    }

    func update(t: CGFloat, mode: GarlandMode) {
        let step = Int(t * 6)
        for (i, b) in bulbs.enumerated() {
            let v: CGFloat
            switch mode {
            case .steady:
                v = 1
            case .chase:
                v = ((i - step) % 4 + 4) % 4 == 0 ? 1 : 0.15
            case .twinkle:
                v = 0.25 + 0.75 * max(0, sin(t * b.speed + b.phase))
            }
            b.bulb.alpha = 0.35 + 0.65 * v
            b.glow.alpha = 0.9 * v
        }
    }

    private static func makeGlowTexture() -> SKTexture {
        let img = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            let g = NSGradient(colors: [
                NSColor(calibratedWhite: 1, alpha: 0.85),
                NSColor(calibratedWhite: 1, alpha: 0.25),
                NSColor(calibratedWhite: 1, alpha: 0),
            ], atLocations: [0, 0.35, 1], colorSpace: .deviceRGB)
            g?.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
            return true
        }
        return SKTexture(image: img)
    }
}
