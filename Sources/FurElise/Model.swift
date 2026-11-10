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
    let freq = CGFloat.random(in: 0.25...0.8)

    init(node: SKSpriteNode, pos: CGPoint, vel: CGVector, size: CGFloat, volume: CGFloat, ballistic: Bool, life: CGFloat) {
        self.node = node; self.pos = pos; self.vel = vel; self.size = size
        self.volume = volume; self.ballistic = ballistic; self.life = life
    }
}

final class Snowball {
    enum State { case held, falling, resting, gone }

    let node = SKNode()
    private let base = SKShapeNode()
    private let highlight = SKShapeNode()
    private var face: SKNode?
    private var drawnR: CGFloat = 0

    var pos: CGPoint
    var vel = CGVector.zero
    var area: CGFloat
    var state = State.held
    var supportLedge: Int?
    var supportY: CGFloat = 0
    weak var supportBall: Snowball?

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
    }

    /// Лицо снеговика — у верхнего шара в стопке из трёх.
    var hasFace: Bool { face != nil }

    func setFace(_ want: Bool) {
        if want, face == nil {
            let r = self.r
            let f = SKNode()
            for sx: CGFloat in [-1, 1] {
                let e = SKShapeNode(circleOfRadius: max(1.5, r * 0.09))
                e.fillColor = NSColor(calibratedWhite: 0.1, alpha: 1)
                e.strokeColor = .clear
                e.position = CGPoint(x: sx * r * 0.3, y: r * 0.25)
                f.addChild(e)
            }
            let np = CGMutablePath()
            np.move(to: CGPoint(x: 0, y: r * 0.06))
            np.addLine(to: CGPoint(x: r * 0.6, y: -r * 0.04))
            np.addLine(to: CGPoint(x: 0, y: -r * 0.12))
            np.closeSubpath()
            let nose = SKShapeNode(path: np)
            nose.fillColor = NSColor(calibratedRed: 1, green: 0.5, blue: 0.1, alpha: 1)
            nose.strokeColor = .clear
            f.addChild(nose)
            for i in 0..<5 {
                let a = -CGFloat.pi / 2 + CGFloat(i - 2) * 0.28
                let dot = SKShapeNode(circleOfRadius: max(1, r * 0.05))
                dot.fillColor = NSColor(calibratedWhite: 0.15, alpha: 1)
                dot.strokeColor = .clear
                dot.position = CGPoint(x: cos(a) * r * 0.45, y: sin(a) * r * 0.45 + r * 0.05)
                f.addChild(dot)
            }
            f.zPosition = 0.02
            for c in f.children { c.zPosition = 0.001 }
            node.addChild(f)
            face = f
        } else if !want, let f = face {
            f.removeFromParent()
            face = nil
        }
    }
}
