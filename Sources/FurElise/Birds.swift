import SpriteKit
import AppKit

/// Снегирь: прилетает, садится на сугроб, клюёт снег, вспархивает от курсора.
/// Нарисован «лицом вправо» с началом координат у лапок.
final class Bird {
    enum State { case flyingIn, sitting, flyingAway }

    let node = SKNode()
    private let body = SKNode()
    private let wing = SKNode()
    var state = State.flyingIn
    var pos: CGPoint
    var vel = CGVector.zero
    /// Где сидит: поверхность и столбик в ней.
    var ledgeId: Int
    var col: Int
    var t = CGFloat.random(in: 0...10)
    var nextPeck = CGFloat.random(in: 1...3)
    var peck: CGFloat = 0
    var nextChirp = CGFloat.random(in: 6...20)

    private static let grey = NSColor(calibratedRed: 0.46, green: 0.48, blue: 0.54, alpha: 1)
    private static let breast = NSColor(calibratedRed: 0.93, green: 0.33, blue: 0.24, alpha: 1)
    private static let black = NSColor(calibratedWhite: 0.1, alpha: 1)

    init(pos: CGPoint, ledgeId: Int, col: Int) {
        self.pos = pos
        self.ledgeId = ledgeId
        self.col = col
        node.position = pos
        node.setScale(1.3)
        node.addChild(body)
        build()
    }

    func face(_ dir: CGFloat) { body.xScale = dir < 0 ? -1 : 1 }

    func animate(_ dt: CGFloat) {
        t += dt
        switch state {
        case .flyingIn, .flyingAway:
            wing.yScale = sin(t * 30)
            wing.zRotation = 0.3
            body.zRotation = 0
        case .sitting:
            wing.yScale = 1
            wing.zRotation = 0
            if peck > 0 {
                peck -= dt
                body.zRotation = -0.45 * sin(.pi * max(0, peck) / 0.35) * (body.xScale)
            } else {
                body.zRotation = 0
            }
        }
        node.position = pos
    }

    private func add(_ path: CGPath, _ color: NSColor, z: CGFloat, to parent: SKNode? = nil) {
        let n = SKShapeNode(path: path)
        n.fillColor = color
        n.strokeColor = .clear
        n.zPosition = z
        (parent ?? body).addChild(n)
    }

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), transform: nil)
    }

    private func build() {
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -5, y: 6))
        tail.addLine(to: CGPoint(x: -13, y: 8.5))
        tail.addLine(to: CGPoint(x: -12, y: 4))
        tail.closeSubpath()
        add(tail, Bird.black, z: 0)
        add(ellipse(0, 7, 14, 11), Bird.grey, z: 0.1)
        add(ellipse(2.8, 5.5, 9, 8), Bird.breast, z: 0.2)
        // Голова: чёрная шапочка, красная щека, клюв.
        add(ellipse(5.5, 12, 8.5, 8), Bird.black, z: 0.3)
        add(ellipse(6.8, 10.3, 4.2, 3.2), Bird.breast, z: 0.31)
        let beak = CGMutablePath()
        beak.move(to: CGPoint(x: 9, y: 12.5))
        beak.addLine(to: CGPoint(x: 12, y: 11.4))
        beak.addLine(to: CGPoint(x: 9, y: 10.4))
        beak.closeSubpath()
        add(beak, Bird.black, z: 0.32)
        add(ellipse(7.3, 13.2, 1.4, 1.4), NSColor(calibratedWhite: 0.85, alpha: 1), z: 0.33)
        // Лапки.
        let legs = CGMutablePath()
        legs.addRect(CGRect(x: -1.5, y: 0, width: 1, height: 3))
        legs.addRect(CGRect(x: 1.5, y: 0, width: 1, height: 3))
        add(legs, Bird.black, z: 0.05)
        // Крыло с белой полоской — отдельный узел, машет в полёте.
        wing.position = CGPoint(x: -1, y: 9)
        wing.zPosition = 0.4
        body.addChild(wing)
        add(ellipse(-2.5, 0, 10, 5), NSColor(calibratedWhite: 0.18, alpha: 1), z: 0, to: wing)
        add(CGPath(rect: CGRect(x: -6, y: -0.6, width: 7, height: 1.3), transform: nil), .white, z: 0.01, to: wing)
    }
}
