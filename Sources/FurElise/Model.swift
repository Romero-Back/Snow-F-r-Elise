import SpriteKit
import AppKit

/// Ширина одного столбика снежного покрова, pt.
let colW: CGFloat = 3

/// Поверхность, на которую ложится снег: верхний край окна или низ экрана.
final class Ledge {
    let id: Int
    let x0: CGFloat
    let y: CGFloat
    let n: Int
    let cap: CGFloat
    let isGround: Bool
    var h: [CGFloat]
    var visible: [Bool]
    let node = SKNode()
    private let fill = SKShapeNode()
    private let edge = SKShapeNode()
    var dirty = true
    var urgent = true
    var builtAt: TimeInterval = 0
    var spillL: CGFloat = 0
    var spillR: CGFloat = 0
    private var flip = false

    init(id: Int, x0: CGFloat, y: CGFloat, width: CGFloat, cap: CGFloat, isGround: Bool) {
        self.id = id
        self.x0 = x0
        self.y = y
        self.n = max(2, Int(width / colW))
        self.cap = cap
        self.isGround = isGround
        h = Array(repeating: 0, count: n)
        visible = Array(repeating: true, count: n)
        // Без обводки: обводка кривых в SpriteKit дорогая. Голубая кромка — та же фигура, сдвинутая вниз.
        edge.fillColor = NSColor(calibratedRed: 0.70, green: 0.79, blue: 0.95, alpha: 0.9)
        edge.strokeColor = .clear
        edge.lineWidth = 0
        edge.position = CGPoint(x: 0.6, y: -1.2)
        fill.fillColor = NSColor(calibratedWhite: 1, alpha: 0.98)
        fill.strokeColor = .clear
        fill.lineWidth = 0
        edge.zPosition = 0
        fill.zPosition = 0.01
        node.addChild(edge)
        node.addChild(fill)
    }

    var maxX: CGFloat { x0 + CGFloat(n) * colW }
    func colX(_ c: Int) -> CGFloat { x0 + (CGFloat(c) + 0.5) * colW }
    func col(at x: CGFloat) -> Int? {
        guard x >= x0 else { return nil }
        let c = Int((x - x0) / colW)
        return c < n ? c : nil
    }

    /// Осыпание: склон не круче заданного, лишнее с краёв окна ссыпается вниз.
    /// Возвращает (ссыпалось слева, справа, было ли движение).
    func relax() -> (CGFloat, CGFloat, Bool) {
        let slope: CGFloat = 1.6
        var moved: CGFloat = 0
        flip.toggle()
        for pass in 0..<2 {
            let forward = (pass == 0) != flip
            for k in 0..<(n - 1) {
                let i = forward ? k : n - 2 - k
                let d = h[i] - h[i + 1]
                if d > slope {
                    let m = (d - slope) * 0.5
                    h[i] -= m; h[i + 1] += m; moved += m
                } else if d < -slope {
                    let m = (-d - slope) * 0.5
                    h[i] += m; h[i + 1] -= m; moved += m
                }
            }
        }
        var sl: CGFloat = 0, sr: CGFloat = 0
        if !isGround {
            let edge: CGFloat = 1.2
            if h[0] > edge { sl = h[0] - edge; h[0] = edge }
            if h[n - 1] > edge { sr = h[n - 1] - edge; h[n - 1] = edge }
        }
        for i in 0..<n where h[i] > cap { h[i] = cap }
        return (sl, sr, moved > 0.02)
    }

    func rebuildPath() {
        let p = CGMutablePath()
        var i = 0
        while i < n {
            guard visible[i], h[i] > 0.15 else { i += 1; continue }
            let start = i
            while i < n, visible[i], h[i] > 0.15 { i += 1 }
            let end = i
            let xs = x0 + CGFloat(start) * colW
            let xe = x0 + CGFloat(end) * colW
            p.move(to: CGPoint(x: xs, y: y))
            p.addLine(to: CGPoint(x: xs, y: y + h[start] * 0.5))
            var prev = CGPoint(x: colX(start), y: y + h[start])
            p.addLine(to: prev)
            for c in (start + 1)..<end {
                let pt = CGPoint(x: colX(c), y: y + h[c])
                p.addQuadCurve(to: CGPoint(x: (prev.x + pt.x) / 2, y: (prev.y + pt.y) / 2), control: prev)
                prev = pt
            }
            p.addLine(to: prev)
            p.addLine(to: CGPoint(x: xe, y: y + h[end - 1] * 0.5))
            p.addLine(to: CGPoint(x: xe, y: y))
            p.closeSubpath()
        }
        fill.path = p
        edge.path = p
    }
}

final class Particle {
    let node: SKSpriteNode
    var pos: CGPoint
    var vel: CGVector
    let size: CGFloat
    let volume: CGFloat
    let ballistic: Bool
    var life: CGFloat
    var phase = CGFloat.random(in: 0...1)
    /// Вращение снежинки, рад/с (у точек — 0).
    var spin: CGFloat = 0
    let freq = CGFloat.random(in: 0.25...0.8)

    init(node: SKSpriteNode, pos: CGPoint, vel: CGVector, size: CGFloat, volume: CGFloat, ballistic: Bool, life: CGFloat) {
        self.node = node; self.pos = pos; self.vel = vel; self.size = size
        self.volume = volume; self.ballistic = ballistic; self.life = life
    }
}

final class Snowball {
    enum State { case held, falling, resting, thrown, gone }

    let node = SKNode()
    private let base = SKShapeNode()
    private let highlight = SKShapeNode()
    private var face: SKNode?
    private var body: SKNode?
    private var drawnR: CGFloat = 0

    var pos: CGPoint
    var vel = CGVector.zero
    var area: CGFloat
    var state = State.held
    var supportLedge: Int?
    var supportY: CGFloat = 0
    weak var supportBall: Snowball?
    /// Сколько летит после броска.
    var flightTime: CGFloat = 0

    var r: CGFloat { min(70, max(6, sqrt(area / .pi))) }

    init(pos: CGPoint, area: CGFloat) {
        self.pos = pos
        self.area = area
        base.fillColor = NSColor(calibratedRed: 0.80, green: 0.86, blue: 0.96, alpha: 1)
        base.strokeColor = NSColor(calibratedRed: 0.62, green: 0.71, blue: 0.88, alpha: 1)
        base.lineWidth = 1
        highlight.fillColor = .white
        highlight.strokeColor = .clear
        base.zPosition = 0
        highlight.zPosition = 0.01
        node.addChild(base)
        node.addChild(highlight)
        node.position = pos
        syncShape()
    }

    func syncShape() {
        let r = self.r
        guard abs(r - drawnR) > 0.4 else { return }
        drawnR = r
        base.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        let hr = r * 0.82
        highlight.path = CGPath(ellipseIn: CGRect(x: -r * 0.1 - hr, y: r * 0.12 - hr, width: 2 * hr, height: 2 * hr),
                                transform: nil)
    }

    func fall(vel v: CGVector = .zero) {
        state = .falling
        vel = v
        supportLedge = nil
        supportBall = nil
        node.zPosition = 0
    }

    func throwIt(vel v: CGVector) {
        fall(vel: v)
        state = .thrown
        flightTime = 0
    }

    // MARK: - Снеговик

    var hasFace: Bool { face != nil }
    var hasBody: Bool { body != nil }

    private static let scarfColors: [NSColor] = [
        NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.85, alpha: 1),
        NSColor(calibratedRed: 0.15, green: 0.62, blue: 0.32, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.75, blue: 0.15, alpha: 1),
        NSColor(calibratedRed: 0.55, green: 0.30, blue: 0.80, alpha: 1),
    ]

    private func shape(_ path: CGPath, _ fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 1, z: CGFloat, in parent: SKNode) {
        let n = SKShapeNode(path: path)
        n.fillColor = fill
        n.strokeColor = stroke ?? .clear
        n.lineWidth = stroke == nil ? 0 : width
        n.lineCap = .round
        n.zPosition = z
        parent.addChild(n)
    }

    /// Лицо, шапка и шарф — у верхнего шара в стопке из трёх. Шапка и цвет шарфа случайные.
    func setFace(_ want: Bool) {
        if want, face == nil {
            let r = self.r
            let f = SKNode()
            f.zPosition = 0.02
            for sx: CGFloat in [-1, 1] {
                shape(CGPath(ellipseIn: CGRect(x: sx * r * 0.3 - r * 0.09, y: r * 0.16, width: r * 0.18, height: r * 0.18), transform: nil),
                      NSColor(calibratedWhite: 0.1, alpha: 1), z: 0.001, in: f)
            }
            let np = CGMutablePath()
            np.move(to: CGPoint(x: 0, y: r * 0.06))
            np.addLine(to: CGPoint(x: r * 0.6, y: -r * 0.04))
            np.addLine(to: CGPoint(x: 0, y: -r * 0.12))
            np.closeSubpath()
            shape(np, NSColor(calibratedRed: 1, green: 0.5, blue: 0.1, alpha: 1), z: 0.002, in: f)
            for i in 0..<5 {
                let a = -CGFloat.pi / 2 + CGFloat(i - 2) * 0.28
                let c = CGPoint(x: cos(a) * r * 0.45, y: sin(a) * r * 0.45 + r * 0.05)
                let d = max(1, r * 0.05)
                shape(CGPath(ellipseIn: CGRect(x: c.x - d, y: c.y - d, width: 2 * d, height: 2 * d), transform: nil),
                      NSColor(calibratedWhite: 0.15, alpha: 1), z: 0.001, in: f)
            }
            addHat(r: r, to: f)
            addScarf(r: r, to: f)
            node.addChild(f)
            face = f
        } else if !want, let f = face {
            f.removeFromParent()
            face = nil
        }
    }

    private func addHat(r: CGFloat, to f: SKNode) {
        let hat = SKNode()
        hat.zPosition = 0.01
        hat.zRotation = .random(in: -0.18...0.18)
        switch Int.random(in: 0...3) {
        case 0:   // цилиндр
            let black = NSColor(calibratedWhite: 0.08, alpha: 1)
            shape(CGPath(roundedRect: CGRect(x: -0.78 * r, y: 0.72 * r, width: 1.56 * r, height: 0.14 * r),
                         cornerWidth: 0.05 * r, cornerHeight: 0.05 * r, transform: nil), black, z: 0, in: hat)
            shape(CGPath(rect: CGRect(x: -0.5 * r, y: 0.84 * r, width: r, height: 0.85 * r), transform: nil), black, z: 0.001, in: hat)
            shape(CGPath(rect: CGRect(x: -0.5 * r, y: 0.86 * r, width: r, height: 0.16 * r), transform: nil),
                  NSColor(calibratedRed: 0.8, green: 0.1, blue: 0.12, alpha: 1), z: 0.002, in: hat)
        case 1:   // ведро
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -0.62 * r, y: 0.68 * r))
            p.addLine(to: CGPoint(x: 0.62 * r, y: 0.68 * r))
            p.addLine(to: CGPoint(x: 0.46 * r, y: 1.5 * r))
            p.addLine(to: CGPoint(x: -0.46 * r, y: 1.5 * r))
            p.closeSubpath()
            shape(p, NSColor(calibratedRed: 0.58, green: 0.65, blue: 0.72, alpha: 1),
                  stroke: NSColor(calibratedRed: 0.38, green: 0.44, blue: 0.5, alpha: 1), z: 0, in: hat)
            shape(CGPath(rect: CGRect(x: -0.6 * r, y: 0.74 * r, width: 1.2 * r, height: 0.07 * r), transform: nil),
                  NSColor(calibratedRed: 0.38, green: 0.44, blue: 0.5, alpha: 1), z: 0.001, in: hat)
        case 2:   // вязаная шапка с помпоном
            let color = Snowball.scarfColors.randomElement()!
            let dome = CGMutablePath()
            dome.addArc(center: CGPoint(x: 0, y: 0.6 * r), radius: 0.74 * r, startAngle: 0, endAngle: .pi, clockwise: false)
            dome.closeSubpath()
            shape(dome, color, z: 0, in: hat)
            shape(CGPath(roundedRect: CGRect(x: -0.8 * r, y: 0.52 * r, width: 1.6 * r, height: 0.24 * r),
                         cornerWidth: 0.1 * r, cornerHeight: 0.1 * r, transform: nil),
                  color.blended(withFraction: 0.45, of: .white) ?? .white, z: 0.001, in: hat)
            let pr = 0.2 * r
            shape(CGPath(ellipseIn: CGRect(x: -pr, y: 1.34 * r - pr, width: 2 * pr, height: 2 * pr), transform: nil),
                  NSColor(calibratedWhite: 0.97, alpha: 1), z: 0.002, in: hat)
        default:  // без шапки
            return
        }
        f.addChild(hat)
    }

    private func addScarf(r: CGFloat, to f: SKNode) {
        let color = Snowball.scarfColors.randomElement()!
        let stripe = color.blended(withFraction: 0.5, of: .white) ?? .white
        let scarf = SKNode()
        scarf.zPosition = 0.015
        shape(CGPath(roundedRect: CGRect(x: -0.86 * r, y: -0.98 * r, width: 1.72 * r, height: 0.3 * r),
                     cornerWidth: 0.12 * r, cornerHeight: 0.12 * r, transform: nil), color, z: 0, in: scarf)
        let end = SKNode()
        end.position = CGPoint(x: 0.35 * r, y: -0.85 * r)
        end.zRotation = .random(in: 0.05...0.3)
        end.zPosition = 0.001
        shape(CGPath(roundedRect: CGRect(x: -0.14 * r, y: -0.7 * r, width: 0.28 * r, height: 0.72 * r),
                     cornerWidth: 0.06 * r, cornerHeight: 0.06 * r, transform: nil), color, z: 0, in: end)
        shape(CGPath(rect: CGRect(x: -0.14 * r, y: -0.5 * r, width: 0.28 * r, height: 0.07 * r), transform: nil), stripe, z: 0.001, in: end)
        shape(CGPath(rect: CGRect(x: -0.14 * r, y: -0.34 * r, width: 0.28 * r, height: 0.07 * r), transform: nil), stripe, z: 0.001, in: end)
        scarf.addChild(end)
        f.addChild(scarf)
    }

    /// Руки-веточки и пуговицы — у среднего шара снеговика.
    func setBody(_ want: Bool) {
        if want, body == nil {
            let r = self.r
            let b = SKNode()
            b.zPosition = 0.02
            let twig = NSColor(calibratedRed: 0.40, green: 0.26, blue: 0.13, alpha: 1)
            for sx: CGFloat in [-1, 1] {
                let p = CGMutablePath()
                let s0 = CGPoint(x: sx * 0.8 * r, y: 0.2 * r)
                let s1 = CGPoint(x: sx * 1.75 * r, y: (0.7 + .random(in: -0.15...0.2)) * r)
                p.move(to: s0)
                p.addLine(to: s1)
                let fork = CGPoint(x: s0.x + (s1.x - s0.x) * 0.7, y: s0.y + (s1.y - s0.y) * 0.7)
                p.move(to: fork)
                p.addLine(to: CGPoint(x: fork.x + sx * 0.25 * r, y: fork.y + 0.3 * r))
                p.move(to: s1)
                p.addLine(to: CGPoint(x: s1.x + sx * 0.18 * r, y: s1.y + 0.12 * r))
                p.move(to: s1)
                p.addLine(to: CGPoint(x: s1.x + sx * 0.08 * r, y: s1.y + 0.25 * r))
                shape(p, .clear, stroke: twig, width: max(1.5, r * 0.07), z: -0.001, in: b)
            }
            for y in [0.35, 0.0, -0.35] as [CGFloat] {
                let d = max(1.2, r * 0.08)
                shape(CGPath(ellipseIn: CGRect(x: -d, y: y * r - d, width: 2 * d, height: 2 * d), transform: nil),
                      NSColor(calibratedWhite: 0.1, alpha: 1), z: 0.001, in: b)
            }
            node.addChild(b)
            body = b
        } else if !want, let b = body {
            b.removeFromParent()
            body = nil
        }
    }
}
