import SpriteKit
import AppKit

/// Чёрный седан 5-й серии (силуэт G30): чистит снег на скорости или дрифтит.
/// Без логотипов — это рисунок «в духе», а не копия марки.
/// Нарисован в профиль «лицом вправо»; разворот при дрифте — сжатие по X через 0.
final class Sedan {
    enum Mode { case clean, drift }
    enum Phase { case enter, drifting, leave }

    let node = SKNode()
    private let body = SKNode()
    private var wheels: [SKNode] = []
    let mode: Mode
    var phase = Phase.enter
    /// Куда едет: +1 вправо, -1 влево.
    var dir: CGFloat
    var x: CGFloat
    var speed: CGFloat
    /// Куда смотрит морда: плавно меняется при развороте (1 → -1 → 1).
    var facing: CGFloat = 1
    var driftT: CGFloat = 0
    let driftAt: CGFloat
    var smokeAcc: CGFloat = 0
    static let length: CGFloat = 145
    static let halfLength: CGFloat = 70

    private static let paint = NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
    private static let shine = NSColor(calibratedRed: 0.32, green: 0.34, blue: 0.40, alpha: 1)
    private static let glass = NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.33, alpha: 1)
    private static let chrome = NSColor(calibratedRed: 0.75, green: 0.77, blue: 0.80, alpha: 1)

    init(mode: Mode, dir: CGFloat, x: CGFloat, driftAt: CGFloat) {
        self.mode = mode
        self.dir = dir
        self.x = x
        self.driftAt = driftAt
        speed = mode == .clean ? 300 : 360
        facing = dir
        node.addChild(body)
        build()
        node.position = CGPoint(x: x, y: 0)
        body.xScale = facing
    }

    /// Передний край кузова по ходу движения.
    var frontX: CGFloat { x + dir * Sedan.halfLength }
    var rearWheel: CGPoint { CGPoint(x: x - facing * 40, y: 4) }

    func step(_ dt: CGFloat) {
        x += dir * speed * dt
        let roll = phase == .drifting ? sin(driftT * 6) * 0.04 : 0
        node.position = CGPoint(x: x, y: phase == .drifting ? abs(sin(driftT * 9)) * 1.2 : 0)
        body.xScale = facing
        body.zRotation = roll
        let spin = (speed + (phase == .drifting ? 500 : 0)) * dt / 10
        for w in wheels { w.zRotation -= spin }
    }

    // MARK: - Рисунок

    private func shape(_ path: CGPath, fill: NSColor?, stroke: NSColor? = nil, width: CGFloat = 1, z: CGFloat,
                       to parent: SKNode? = nil) {
        let n = SKShapeNode(path: path)
        n.fillColor = fill ?? .clear
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : width
        n.lineJoin = .round
        n.lineCap = .round
        n.zPosition = z
        (parent ?? body).addChild(n)
    }

    private func line(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts)
        return p
    }

    /// Силуэт снят с фото седана 5-й серии (G30) в профиль и отражён «лицом вправо»:
    /// длина ~140 pt, колёса r = 10 с центрами (49, 10) и (-40, 10).
    private func build() {
        // Тень.
        shape(CGPath(ellipseIn: CGRect(x: -72, y: -2.5, width: 144, height: 6), transform: nil),
              fill: NSColor(calibratedWhite: 0, alpha: 0.32), z: -1, to: node)

        // Кузов: длинный капот, покатая крыша, короткий багажник с лип-спойлером, вырезы арок.
        let b = CGMutablePath()
        b.move(to: CGPoint(x: -69.4, y: 7))                                    // низ заднего бампера
        b.addLine(to: CGPoint(x: -70.2, y: 15.5))
        b.addQuadCurve(to: CGPoint(x: -69.4, y: 29.2), control: CGPoint(x: -71, y: 24))
        b.addLine(to: CGPoint(x: -70, y: 30.8))                                // кончик спойлера
        b.addLine(to: CGPoint(x: -53.7, y: 31.6))                              // крышка багажника
        b.addQuadCurve(to: CGPoint(x: -30.3, y: 39.6), control: CGPoint(x: -42, y: 37.5)) // заднее стекло
        b.addQuadCurve(to: CGPoint(x: 8.4, y: 39.4), control: CGPoint(x: -12, y: 41.6))   // крыша
        b.addQuadCurve(to: CGPoint(x: 24.6, y: 29.1), control: CGPoint(x: 17, y: 34))     // лобовое
        b.addQuadCurve(to: CGPoint(x: 65, y: 23.4), control: CGPoint(x: 46, y: 27.4))     // длинный капот
        b.addQuadCurve(to: CGPoint(x: 69.2, y: 15), control: CGPoint(x: 69.5, y: 21))     // морда
        b.addLine(to: CGPoint(x: 70.4, y: 6.2))                                // бампер
        b.addLine(to: CGPoint(x: 66, y: 4.6))                                  // сплиттер
        b.addLine(to: CGPoint(x: 61.2, y: 5))
        b.addArc(center: CGPoint(x: 49, y: 10), radius: 12.8, startAngle: -0.4, endAngle: .pi + 0.4, clockwise: false)
        b.addLine(to: CGPoint(x: 35.4, y: 3.8))
        b.addLine(to: CGPoint(x: -27, y: 3.8))                                 // порог
        b.addLine(to: CGPoint(x: -28.2, y: 5))
        b.addArc(center: CGPoint(x: -40, y: 10), radius: 12.8, startAngle: -0.4, endAngle: .pi + 0.4, clockwise: false)
        b.addLine(to: CGPoint(x: -53, y: 5.5))
        b.closeSubpath()
        shape(b, fill: Sedan.paint, stroke: NSColor(calibratedWhite: 0.2, alpha: 1), width: 0.7, z: 0)

        // Отражения на тёмном металлике: светлая полоса по низу дверей, блик на крыше и капоте.
        let refl = CGMutablePath()
        refl.move(to: CGPoint(x: 30, y: 17))
        refl.addQuadCurve(to: CGPoint(x: -36, y: 18.5), control: CGPoint(x: -3, y: 21))
        refl.addLine(to: CGPoint(x: -36, y: 9))
        refl.addQuadCurve(to: CGPoint(x: 30, y: 8), control: CGPoint(x: -3, y: 6.5))
        refl.closeSubpath()
        shape(refl, fill: NSColor(calibratedWhite: 0.3, alpha: 0.16), z: 0.05)
        shape(line([CGPoint(x: -24, y: 40.2), CGPoint(x: 4, y: 40)]), fill: nil,
              stroke: NSColor(calibratedWhite: 0.55, alpha: 0.5), width: 1.2, z: 0.06)
        shape(line([CGPoint(x: 30, y: 28.2), CGPoint(x: 58, y: 24.6)]), fill: nil,
              stroke: NSColor(calibratedWhite: 0.5, alpha: 0.5), width: 1.1, z: 0.06)
        // Линия плеча до фонарей.
        shape(line([CGPoint(x: 60, y: 24.6), CGPoint(x: 20, y: 26.4), CGPoint(x: -40, y: 27.3), CGPoint(x: -62, y: 27)]),
              fill: nil, stroke: Sedan.shine, width: 1, z: 0.07)
        // Пороги и сплиттер — чёрный глянец.
        shape(line([CGPoint(x: 34, y: 5.2), CGPoint(x: -26, y: 5.2)]), fill: nil,
              stroke: NSColor(calibratedWhite: 0.02, alpha: 1), width: 2.2, z: 0.08)
        shape(line([CGPoint(x: 70, y: 5.4), CGPoint(x: 61, y: 5)]), fill: nil,
              stroke: NSColor(calibratedWhite: 0.02, alpha: 1), width: 1.8, z: 0.08)

        // Три боковых окна: передняя дверь, задняя дверь и «форточка» с изгибом стойки.
        let glassStroke = NSColor(calibratedWhite: 0.05, alpha: 1)
        let w1 = CGMutablePath()
        w1.move(to: CGPoint(x: 18.3, y: 28.4))
        w1.addQuadCurve(to: CGPoint(x: -5.5, y: 38.4), control: CGPoint(x: 9, y: 36))
        w1.addLine(to: CGPoint(x: -8, y: 38.4))
        w1.addLine(to: CGPoint(x: -8, y: 28.4))
        w1.closeSubpath()
        shape(w1, fill: Sedan.glass, stroke: glassStroke, width: 0.8, z: 0.2)
        let w2 = CGMutablePath()
        w2.move(to: CGPoint(x: -10, y: 28.4))
        w2.addLine(to: CGPoint(x: -10, y: 38.3))
        w2.addQuadCurve(to: CGPoint(x: -26.6, y: 37.7), control: CGPoint(x: -19, y: 38.6))
        w2.addLine(to: CGPoint(x: -26.6, y: 28.4))
        w2.closeSubpath()
        shape(w2, fill: Sedan.glass, stroke: glassStroke, width: 0.8, z: 0.2)
        let w3 = CGMutablePath()
        w3.move(to: CGPoint(x: -28, y: 28.4))
        w3.addLine(to: CGPoint(x: -28, y: 37.3))
        w3.addQuadCurve(to: CGPoint(x: -39, y: 31), control: CGPoint(x: -34, y: 35.5))
        w3.addLine(to: CGPoint(x: -38.4, y: 29.4))                            // изгиб задней стойки
        w3.addLine(to: CGPoint(x: -36.6, y: 28.4))
        w3.closeSubpath()
        shape(w3, fill: Sedan.glass, stroke: glassStroke, width: 0.8, z: 0.2)
        // Хром по нижнему краю стёкол и блики на стёклах.
        shape(line([CGPoint(x: 18.3, y: 28.4), CGPoint(x: -36.6, y: 28.4)]), fill: nil, stroke: Sedan.chrome, width: 0.9, z: 0.25)
        shape(line([CGPoint(x: 8, y: 31), CGPoint(x: 1, y: 36)]), fill: nil,
              stroke: NSColor(calibratedWhite: 1, alpha: 0.22), width: 2.2, z: 0.26)
        shape(line([CGPoint(x: -14, y: 30), CGPoint(x: -19, y: 36.5)]), fill: nil,
              stroke: NSColor(calibratedWhite: 1, alpha: 0.18), width: 2.2, z: 0.26)
        shape(line([CGPoint(x: -30, y: 30), CGPoint(x: -33, y: 34.5)]), fill: nil,
              stroke: NSColor(calibratedWhite: 1, alpha: 0.18), width: 1.8, z: 0.26)

        // Двери, ручки, зеркало, «жабры», плавник антенны.
        let seam = NSColor(calibratedWhite: 0.03, alpha: 1)
        shape(line([CGPoint(x: 29, y: 27.6), CGPoint(x: 28.6, y: 15), CGPoint(x: 30.2, y: 6.6)]), fill: nil, stroke: seam, width: 0.8, z: 0.15)
        shape(line([CGPoint(x: -4.4, y: 28.4), CGPoint(x: -4.2, y: 6.2)]), fill: nil, stroke: seam, width: 0.8, z: 0.15)
        shape(line([CGPoint(x: -38, y: 28.4), CGPoint(x: -38.4, y: 22), CGPoint(x: -30.4, y: 16.5), CGPoint(x: -27.4, y: 6)]),
              fill: nil, stroke: seam, width: 0.8, z: 0.15)
        for hx in [CGFloat(0.8), -29.4] {
            shape(CGPath(roundedRect: CGRect(x: hx - 3.2, y: 23.6, width: 6.4, height: 1.6), cornerWidth: 0.8, cornerHeight: 0.8, transform: nil),
                  fill: Sedan.chrome, z: 0.16)
        }
        let mirror = CGMutablePath()
        mirror.move(to: CGPoint(x: 16.8, y: 28))
        mirror.addLine(to: CGPoint(x: 21.2, y: 28.6))
        mirror.addQuadCurve(to: CGPoint(x: 20.4, y: 31.8), control: CGPoint(x: 22, y: 31.6))
        mirror.addLine(to: CGPoint(x: 16.4, y: 31))
        mirror.closeSubpath()
        shape(mirror, fill: NSColor(calibratedWhite: 0.08, alpha: 1), z: 0.3)
        let gill = CGMutablePath()
        gill.move(to: CGPoint(x: 36, y: 13.6))
        gill.addLine(to: CGPoint(x: 33.6, y: 13.6))
        gill.addLine(to: CGPoint(x: 29.8, y: 8.6))
        gill.addLine(to: CGPoint(x: 31.4, y: 8.6))
        gill.closeSubpath()
        shape(gill, fill: NSColor(calibratedWhite: 0.02, alpha: 1), z: 0.17)
        let fin = CGMutablePath()
        fin.move(to: CGPoint(x: -26, y: 40.2))
        fin.addQuadCurve(to: CGPoint(x: -31, y: 41.8), control: CGPoint(x: -30, y: 42))
        fin.addLine(to: CGPoint(x: -31, y: 40))
        fin.closeSubpath()
        shape(fin, fill: NSColor(calibratedWhite: 0.06, alpha: 1), z: 0.05)

        // Фары: узкая LED-фара и L-образный задний фонарь со свечением.
        let head = CGMutablePath()
        head.move(to: CGPoint(x: 67.6, y: 21.4))
        head.addLine(to: CGPoint(x: 59.2, y: 20.2))
        head.addLine(to: CGPoint(x: 59.8, y: 18.4))
        head.addLine(to: CGPoint(x: 68.6, y: 18.6))
        head.closeSubpath()
        shape(head, fill: NSColor(calibratedRed: 0.85, green: 0.93, blue: 1, alpha: 1), z: 0.45)
        let glowWhite = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: 10, height: 10))
        glowWhite.color = NSColor(calibratedRed: 0.8, green: 0.9, blue: 1, alpha: 1)
        glowWhite.colorBlendFactor = 1
        glowWhite.blendMode = .add
        glowWhite.position = CGPoint(x: 66, y: 19.8)
        glowWhite.zPosition = 0.5
        body.addChild(glowWhite)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -59, y: 26.8))
        tail.addLine(to: CGPoint(x: -69.6, y: 27.4))
        tail.addLine(to: CGPoint(x: -70, y: 21.8))
        tail.addLine(to: CGPoint(x: -65, y: 22.2))
        tail.addLine(to: CGPoint(x: -64.5, y: 24.6))
        tail.addLine(to: CGPoint(x: -59.6, y: 24.8))
        tail.closeSubpath()
        shape(tail, fill: NSColor(calibratedRed: 0.86, green: 0.08, blue: 0.08, alpha: 1), z: 0.45)
        let glowRed = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: 11, height: 11))
        glowRed.color = NSColor(calibratedRed: 1, green: 0.15, blue: 0.1, alpha: 1)
        glowRed.colorBlendFactor = 1
        glowRed.blendMode = .add
        glowRed.position = CGPoint(x: -67, y: 25)
        glowRed.zPosition = 0.5
        body.addChild(glowRed)

        // Колёса: большие тёмные диски с пятью сдвоенными спицами, синие суппорты.
        for cx in [CGFloat(-40), 49] {
            shape(CGPath(ellipseIn: CGRect(x: cx - 12.5, y: -2.5, width: 25, height: 25), transform: nil),
                  fill: NSColor(calibratedWhite: 0.03, alpha: 1), z: -0.5)
            let w = SKNode()
            w.position = CGPoint(x: cx, y: 10)
            w.zPosition = 1
            body.addChild(w)
            shape(CGPath(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20), transform: nil),
                  fill: NSColor(calibratedWhite: 0.06, alpha: 1), z: 0, to: w)
            shape(CGPath(ellipseIn: CGRect(x: -7.4, y: -7.4, width: 14.8, height: 14.8), transform: nil),
                  fill: NSColor(calibratedWhite: 0.13, alpha: 1), stroke: NSColor(calibratedWhite: 0.38, alpha: 1),
                  width: 0.9, z: 0.01, to: w)
            let spokes = CGMutablePath()
            for k in 0..<5 {
                let a = CGFloat(k) * 2 * .pi / 5
                for off: CGFloat in [-0.13, 0.13] {
                    spokes.move(to: CGPoint(x: cos(a) * 1.8, y: sin(a) * 1.8))
                    spokes.addLine(to: CGPoint(x: cos(a + off) * 7, y: sin(a + off) * 7))
                }
            }
            shape(spokes, fill: nil, stroke: NSColor(calibratedWhite: 0.4, alpha: 1), width: 1.3, z: 0.02, to: w)
            shape(CGPath(ellipseIn: CGRect(x: -1.7, y: -1.7, width: 3.4, height: 3.4), transform: nil),
                  fill: NSColor(calibratedWhite: 0.35, alpha: 1), z: 0.03, to: w)
            wheels.append(w)
            // Суппорт не крутится — он на кузове, за спицами.
            shape(CGPath(roundedRect: CGRect(x: cx + 2.2, y: 11.5, width: 3.4, height: 5.4), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil),
                  fill: NSColor(calibratedRed: 0.12, green: 0.35, blue: 0.95, alpha: 1), z: 1.1)
        }
    }
}
