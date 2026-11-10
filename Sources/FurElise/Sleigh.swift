import SpriteKit
import AppKit

/// Дед Мороз на санях с двумя оленями. Нарисован «лицом вправо», при полёте влево отражается.
final class Sleigh {
    let node = SKNode()
    let dir: CGFloat
    private(set) var x: CGFloat
    private let baseY: CGFloat
    private var t: CGFloat = 0
    var trailAcc: CGFloat = 0
    var snowAcc: CGFloat = 0
    var bellAcc: CGFloat = 1
    let speed: CGFloat = 170
    static let length: CGFloat = 240

    private var legs: [(SKNode, CGFloat)] = []   // нога и фаза

    private static let red = NSColor(calibratedRed: 0.82, green: 0.10, blue: 0.13, alpha: 1)
    private static let redDark = NSColor(calibratedRed: 0.55, green: 0.05, blue: 0.08, alpha: 1)
    private static let gold = NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.25, alpha: 1)
    private static let fur = NSColor(calibratedWhite: 0.97, alpha: 1)
    private static let skin = NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.74, alpha: 1)
    private static let deer = NSColor(calibratedRed: 0.55, green: 0.36, blue: 0.20, alpha: 1)
    private static let deerDark = NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.12, alpha: 1)

    init(dir: CGFloat, x: CGFloat, y: CGFloat) {
        self.dir = dir
        self.x = x
        baseY = y
        node.xScale = dir
        node.position = CGPoint(x: x, y: y)
        build()
    }

    /// Точка за санями — оттуда сыплются искры.
    var trailPoint: CGPoint { CGPoint(x: node.position.x - dir * 50, y: node.position.y + 10) }
    var bellyPoint: CGPoint { CGPoint(x: node.position.x, y: node.position.y) }

    func step(_ dt: CGFloat) {
        t += dt
        x += dir * speed * dt
        node.position = CGPoint(x: x, y: baseY + sin(t * 1.6) * 10)
        node.zRotation = cos(t * 1.6) * 0.03
        for (leg, phase) in legs { leg.zRotation = sin(t * 13 + phase) * 0.55 }
    }

    // MARK: - Рисунок

    private func shape(_ path: CGPath, fill: NSColor?, stroke: NSColor? = nil, width: CGFloat = 1, z: CGFloat) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.fillColor = fill ?? .clear
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : width
        n.lineCap = .round
        n.zPosition = z
        node.addChild(n)
        return n
    }

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), transform: nil)
    }

    private func line(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts)
        return p
    }

    private func build() {
        // Полозья.
        let runner = CGMutablePath()
        runner.move(to: CGPoint(x: -52, y: 0))
        runner.addLine(to: CGPoint(x: 28, y: 0))
        runner.addQuadCurve(to: CGPoint(x: 36, y: 12), control: CGPoint(x: 42, y: 0))
        shape(runner, fill: nil, stroke: Sleigh.gold, width: 2.5, z: 0)
        shape(line([CGPoint(x: -36, y: 0), CGPoint(x: -36, y: 8)]), fill: nil, stroke: Sleigh.gold, width: 2, z: 0)
        shape(line([CGPoint(x: 12, y: 0), CGPoint(x: 12, y: 8)]), fill: nil, stroke: Sleigh.gold, width: 2, z: 0)

        // Мешок с подарками.
        shape(ellipse(-36, 32, 26, 28), fill: NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.20, alpha: 1), z: 1)
        shape(ellipse(-36, 47, 8, 5), fill: NSColor(calibratedRed: 0.45, green: 0.28, blue: 0.15, alpha: 1), z: 1.1)

        // Дед Мороз: шуба, борода, лицо, шапка.
        shape(ellipse(-8, 34, 26, 32), fill: Sleigh.red, z: 2)
        shape(CGPath(roundedRect: CGRect(x: -21, y: 21, width: 26, height: 5), cornerWidth: 2, cornerHeight: 2, transform: nil),
              fill: Sleigh.fur, z: 2.1)
        shape(ellipse(-5, 55, 16, 16), fill: Sleigh.skin, z: 2.2)
        let beard = CGMutablePath()
        beard.move(to: CGPoint(x: -12, y: 54))
        beard.addQuadCurve(to: CGPoint(x: -2, y: 36), control: CGPoint(x: -14, y: 40))
        beard.addQuadCurve(to: CGPoint(x: 4, y: 54), control: CGPoint(x: 8, y: 42))
        beard.closeSubpath()
        shape(beard, fill: Sleigh.fur, z: 2.3)
        shape(ellipse(1, 54, 4, 3.5), fill: NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.5, alpha: 1), z: 2.4)
        shape(ellipse(-2, 58, 2.2, 2.2), fill: NSColor(calibratedWhite: 0.1, alpha: 1), z: 2.4)
        let hat = CGMutablePath()
        hat.move(to: CGPoint(x: -14, y: 60))
        hat.addQuadCurve(to: CGPoint(x: -20, y: 72), control: CGPoint(x: -8, y: 76))
        hat.addLine(to: CGPoint(x: 4, y: 60))
        hat.closeSubpath()
        shape(hat, fill: Sleigh.red, z: 2.5)
        shape(CGPath(roundedRect: CGRect(x: -15, y: 58, width: 20, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil),
              fill: Sleigh.fur, z: 2.6)
        shape(ellipse(-20, 72, 6, 6), fill: Sleigh.fur, z: 2.6)
        // Рука с вожжами.
        shape(line([CGPoint(x: 0, y: 40), CGPoint(x: 10, y: 38)]), fill: nil, stroke: Sleigh.redDark, width: 4, z: 2.7)

        // Сани (кузов) — поверх ног Деда Мороза.
        let body = CGMutablePath()
        body.move(to: CGPoint(x: -50, y: 8))
        body.addLine(to: CGPoint(x: 22, y: 8))
        body.addQuadCurve(to: CGPoint(x: 34, y: 26), control: CGPoint(x: 36, y: 10))
        body.addQuadCurve(to: CGPoint(x: 24, y: 28), control: CGPoint(x: 30, y: 32))
        body.addLine(to: CGPoint(x: -46, y: 28))
        body.addQuadCurve(to: CGPoint(x: -50, y: 8), control: CGPoint(x: -54, y: 20))
        shape(body, fill: Sleigh.red, stroke: Sleigh.redDark, width: 1, z: 3)
        shape(line([CGPoint(x: -46, y: 26), CGPoint(x: 24, y: 26)]), fill: nil, stroke: Sleigh.gold, width: 2.5, z: 3.1)
        shape(line([CGPoint(x: -40, y: 12), CGPoint(x: 18, y: 12)]), fill: nil, stroke: Sleigh.gold, width: 1.5, z: 3.1)

        // Олени и упряжь.
        for (i, dx) in [CGFloat(84), 150].enumerated() {
            reindeer(at: dx, z: 4 + CGFloat(i))
        }
        shape(line([CGPoint(x: 10, y: 38), CGPoint(x: 70, y: 34), CGPoint(x: 136, y: 34)]), fill: nil,
              stroke: Sleigh.gold, width: 1.2, z: 3.5)
    }

    private func reindeer(at cx: CGFloat, z: CGFloat) {
        // Ноги — отдельные узлы, качаются вокруг верхней точки.
        let legSpots: [(CGFloat, CGFloat)] = [(-12, 0), (-6, .pi), (10, .pi / 2), (16, .pi * 1.5)]
        for (lx, phase) in legSpots {
            let leg = SKNode()
            leg.position = CGPoint(x: cx + lx, y: 26)
            leg.zPosition = z
            let l = SKShapeNode(rect: CGRect(x: -1.6, y: -17, width: 3.2, height: 17), cornerRadius: 1.5)
            l.fillColor = Sleigh.deerDark
            l.strokeColor = .clear
            leg.addChild(l)
            node.addChild(leg)
            legs.append((leg, phase))
        }
        shape(ellipse(cx + 2, 30, 42, 18), fill: Sleigh.deer, z: z + 0.1)
        shape(ellipse(cx - 18, 34, 7, 5), fill: Sleigh.fur, z: z + 0.11)   // хвост
        // Шея и голова.
        let neck = CGMutablePath()
        neck.move(to: CGPoint(x: cx + 14, y: 34))
        neck.addLine(to: CGPoint(x: cx + 24, y: 46))
        neck.addLine(to: CGPoint(x: cx + 30, y: 44))
        neck.addLine(to: CGPoint(x: cx + 22, y: 30))
        neck.closeSubpath()
        shape(neck, fill: Sleigh.deer, z: z + 0.12)
        shape(ellipse(cx + 29, 48, 14, 10), fill: Sleigh.deer, z: z + 0.13)
        shape(ellipse(cx + 36, 46, 7, 5.5), fill: NSColor(calibratedRed: 0.70, green: 0.50, blue: 0.32, alpha: 1), z: z + 0.14)
        shape(ellipse(cx + 30, 50, 2, 2), fill: NSColor(calibratedWhite: 0.1, alpha: 1), z: z + 0.15)
        // Рога.
        let antler = CGMutablePath()
        antler.move(to: CGPoint(x: cx + 26, y: 52))
        antler.addLine(to: CGPoint(x: cx + 22, y: 64))
        antler.move(to: CGPoint(x: cx + 23.5, y: 59))
        antler.addLine(to: CGPoint(x: cx + 17, y: 62))
        antler.move(to: CGPoint(x: cx + 22, y: 64))
        antler.addLine(to: CGPoint(x: cx + 26, y: 68))
        antler.move(to: CGPoint(x: cx + 29, y: 52))
        antler.addLine(to: CGPoint(x: cx + 31, y: 63))
        antler.move(to: CGPoint(x: cx + 30, y: 58))
        antler.addLine(to: CGPoint(x: cx + 36, y: 61))
        shape(antler, fill: nil, stroke: Sleigh.deerDark, width: 1.8, z: z + 0.16)
        // Ошейник с бубенцом.
        shape(line([CGPoint(x: cx + 17, y: 38), CGPoint(x: cx + 25, y: 33)]), fill: nil, stroke: Sleigh.red, width: 3, z: z + 0.17)
        shape(ellipse(cx + 22, 32, 4.5, 4.5), fill: Sleigh.gold, z: z + 0.18)
    }
}
