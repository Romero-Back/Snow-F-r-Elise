import SpriteKit
import AppKit

/// Снегоуборочный трактор: едет по низу экрана, сгребает отвалом снег и выбрасывает его вверх.
/// Нарисован в локальных координатах «лицом вправо»; при езде влево отражается по X.
final class Tractor {
    let node = SKNode()
    let dir: CGFloat
    var x: CGFloat
    var t: CGFloat = 0
    var smokeAcc: CGFloat = 0
    let speed: CGFloat = 120

    private let body = SKNode()
    private let rearWheel: SKNode
    private let frontWheel: SKNode
    private let beacon: SKShapeNode

    /// Передний край отвала относительно центра, pt.
    static let bladeFront: CGFloat = 40
    static let bladeBack: CGFloat = 30
    /// Длина трактора — чтобы выехать из-за края экрана целиком.
    static let length: CGFloat = 75

    private static let orange = NSColor(calibratedRed: 0.98, green: 0.58, blue: 0.10, alpha: 1)
    private static let orangeDark = NSColor(calibratedRed: 0.80, green: 0.40, blue: 0.05, alpha: 1)
    private static let steel = NSColor(calibratedRed: 0.62, green: 0.66, blue: 0.72, alpha: 1)
    private static let steelDark = NSColor(calibratedRed: 0.38, green: 0.42, blue: 0.48, alpha: 1)
    private static let tire = NSColor(calibratedWhite: 0.13, alpha: 1)

    init(dir: CGFloat, x: CGFloat) {
        self.dir = dir
        self.x = x
        rearWheel = Tractor.wheel(radius: 13)
        frontWheel = Tractor.wheel(radius: 8)
        beacon = SKShapeNode(circleOfRadius: 3.2)

        node.xScale = dir
        node.addChild(body)

        // Порядок слоёв задаём явно: в сцене ignoresSiblingOrder = true.
        func add(_ n: SKNode, z: CGFloat, to parent: SKNode? = nil) {
            n.zPosition = z
            (parent ?? body).addChild(n)
        }

        // Выхлопная труба.
        add(rect(x: 19, y: 20, w: 3.5, h: 15, r: 1, fill: Tractor.steelDark), z: 0)
        // Кабина.
        add(rect(x: -27, y: 12, w: 26, h: 33, r: 4, fill: Tractor.orange, stroke: Tractor.orangeDark), z: 1)
        add(rect(x: -23, y: 26, w: 18, h: 14, r: 2,
                 fill: NSColor(calibratedRed: 0.70, green: 0.86, blue: 1, alpha: 0.95)), z: 2)
        add(rect(x: -29, y: 44, w: 30, h: 3.5, r: 1.5, fill: Tractor.steelDark), z: 2)
        // Капот.
        add(rect(x: -4, y: 9, w: 31, h: 15, r: 4, fill: Tractor.orange, stroke: Tractor.orangeDark), z: 1)
        add(rect(x: 2, y: 13, w: 18, h: 2, r: 1, fill: Tractor.orangeDark), z: 2)
        add(rect(x: 2, y: 17, w: 18, h: 2, r: 1, fill: Tractor.orangeDark), z: 2)
        // Рама и рычаг отвала.
        add(rect(x: -24, y: 7, w: 54, h: 4, r: 1, fill: Tractor.steelDark), z: 0.5)
        add(rect(x: 26, y: 8, w: 7, h: 3, r: 1, fill: Tractor.steelDark), z: 0.5)
        // Отвал — изогнутый лист.
        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: Tractor.bladeBack + 1, y: 0))
        blade.addLine(to: CGPoint(x: Tractor.bladeFront, y: 0))
        blade.addQuadCurve(to: CGPoint(x: Tractor.bladeFront + 2, y: 22), control: CGPoint(x: Tractor.bladeFront - 6, y: 10))
        blade.addLine(to: CGPoint(x: Tractor.bladeBack + 3, y: 20))
        blade.addQuadCurve(to: CGPoint(x: Tractor.bladeBack + 1, y: 0), control: CGPoint(x: Tractor.bladeBack - 2, y: 9))
        blade.closeSubpath()
        let bladeNode = SKShapeNode(path: blade)
        bladeNode.fillColor = Tractor.steel
        bladeNode.strokeColor = Tractor.steelDark
        bladeNode.lineWidth = 1
        add(bladeNode, z: 3)
        // Жёлто-чёрная полоска на отвале.
        add(rect(x: Tractor.bladeBack + 3, y: 2, w: 3, h: 16, r: 1,
                 fill: NSColor(calibratedRed: 1, green: 0.85, blue: 0.1, alpha: 1)), z: 3.5)
        // Мигалка.
        add(rect(x: -16, y: 47, w: 4, h: 2.5, r: 1, fill: Tractor.steelDark), z: 2)
        beacon.fillColor = NSColor(calibratedRed: 1, green: 0.75, blue: 0.1, alpha: 1)
        beacon.strokeColor = .clear
        beacon.position = CGPoint(x: -14, y: 52)
        beacon.glowWidth = 2
        add(beacon, z: 3)
        // Колёса.
        rearWheel.position = CGPoint(x: -14, y: 13)
        frontWheel.position = CGPoint(x: 17, y: 8)
        add(rearWheel, z: 4)
        add(frontWheel, z: 4)
    }

    var bladeFrontX: CGFloat { x + dir * Tractor.bladeFront }
    var exhaustPoint: CGPoint { CGPoint(x: x + dir * 20.5, y: 36) }

    func step(_ dt: CGFloat, onSnow: Bool) {
        t += dt
        x += dir * speed * dt
        node.position = CGPoint(x: x, y: 0)
        // Трясёт, когда идёт по снегу.
        body.position.y = onSnow ? sin(t * 38) * 0.7 : 0
        let dist = speed * dt
        rearWheel.zRotation -= dist / 13
        frontWheel.zRotation -= dist / 8
        beacon.alpha = sin(t * 9) > 0 ? 1 : 0.25
    }

    private func rect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat,
                      fill: NSColor, stroke: NSColor? = nil) -> SKShapeNode {
        let n = SKShapeNode(rect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        n.fillColor = fill
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : 1
        return n
    }

    private static func wheel(radius r: CGFloat) -> SKNode {
        let w = SKNode()
        let t = SKShapeNode(circleOfRadius: r)
        t.fillColor = tire
        t.strokeColor = NSColor(calibratedWhite: 0.05, alpha: 1)
        t.lineWidth = 1
        t.zPosition = 0
        w.addChild(t)
        // Грунтозацепы — видно, что колесо крутится.
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * 2 * .pi
            let lug = SKShapeNode(rect: CGRect(x: -1, y: -1.2, width: 2.6, height: 2.4))
            lug.fillColor = NSColor(calibratedWhite: 0.28, alpha: 1)
            lug.strokeColor = .clear
            lug.position = CGPoint(x: cos(a) * (r - 1.2), y: sin(a) * (r - 1.2))
            lug.zRotation = a
            lug.zPosition = 0.1
            w.addChild(lug)
        }
        let hub = SKShapeNode(circleOfRadius: r * 0.48)
        hub.fillColor = NSColor(calibratedRed: 1, green: 0.82, blue: 0.15, alpha: 1)
        hub.strokeColor = orangeDark
        hub.lineWidth = 1
        hub.zPosition = 0.2
        w.addChild(hub)
        for i in 0..<3 {
            let s = SKShapeNode(rect: CGRect(x: -r * 0.4, y: -0.8, width: r * 0.8, height: 1.6))
            s.fillColor = orangeDark
            s.strokeColor = .clear
            s.zRotation = CGFloat(i) * .pi / 3
            s.zPosition = 0.3
            w.addChild(s)
        }
        return w
    }
}
