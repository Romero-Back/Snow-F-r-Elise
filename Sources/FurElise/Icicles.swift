import SpriteKit
import AppKit

/// Край, с которого свисают сосульки: низ строки меню или нижний край окна.
struct IcicleRailSpec {
    let id: Int
    let x0: CGFloat
    let y: CGFloat
    let width: CGFloat
    /// Закрыта ли точка под краем (x — координата сцены) окном спереди.
    let covered: (CGFloat) -> Bool
}

/// Сосульки: растут со временем, тают и капают в тепле, отламываются, когда окно сдвигают.
final class IcicleLayer {
    let node = SKNode()

    private final class Icicle {
        let node = SKNode()
        let body = SKNode()
        let x: CGFloat
        var len: CGFloat
        let maxLen: CGFloat
        var dripAcc = CGFloat.random(in: 0...1)

        init(x: CGFloat, maxLen: CGFloat, width w: CGFloat) {
            self.x = x
            self.maxLen = maxLen
            len = maxLen * .random(in: 0.2...0.45)
            node.position = CGPoint(x: x, y: 0)

            // Контур в единичной высоте: длину задаёт yScale, перестраивать путь не нужно.
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -w / 2, y: 0))
            p.addQuadCurve(to: CGPoint(x: 0, y: -1), control: CGPoint(x: -w * 0.15, y: -0.55))
            p.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: w * 0.15, y: -0.55))
            p.closeSubpath()
            let ice = SKShapeNode(path: p)
            ice.fillColor = NSColor(calibratedRed: 0.80, green: 0.90, blue: 1.0, alpha: 0.85)
            ice.strokeColor = .clear
            ice.zPosition = 0

            let sp = CGMutablePath()
            sp.move(to: CGPoint(x: -w * 0.28, y: -0.04))
            sp.addQuadCurve(to: CGPoint(x: -w * 0.04, y: -0.78), control: CGPoint(x: -w * 0.22, y: -0.45))
            sp.addLine(to: CGPoint(x: -w * 0.1, y: -0.06))
            sp.closeSubpath()
            let shine = SKShapeNode(path: sp)
            shine.fillColor = NSColor(calibratedWhite: 1, alpha: 0.6)
            shine.strokeColor = .clear
            shine.zPosition = 0.01

            body.addChild(ice)
            body.addChild(shine)
            body.yScale = len
            node.addChild(body)
        }
    }

    private final class Rail {
        let id: Int
        let x0: CGFloat
        let y: CGFloat
        let width: CGFloat
        let node = SKNode()
        var icicles: [Icicle] = []
        init(id: Int, x0: CGFloat, y: CGFloat, width: CGFloat) {
            self.id = id; self.x0 = x0; self.y = y; self.width = width
            node.position = CGPoint(x: x0, y: y)
        }
    }

    private struct Falling {
        let node: SKNode
        var vel: CGVector
        let spin: CGFloat
    }

    private var rails: [Int: Rail] = [:]
    private var falling: [Falling] = []
    private var builtSize: IcicleSize?

    var isEmpty: Bool { rails.isEmpty && falling.isEmpty }

    func sync(_ specs: [IcicleRailSpec], size: IcicleSize) {
        if builtSize != size {
            removeAll()
            builtSize = size
        }
        var seen = Set<Int>()
        for sp in specs {
            seen.insert(sp.id)
            if let r = rails[sp.id],
               abs(r.x0 - sp.x0) > 0.5 || abs(r.y - sp.y) > 0.5 || abs(r.width - sp.width) > 0.5 {
                breakOff(r)
            }
            let rail = rails[sp.id] ?? makeRail(sp, size: size)
            for ic in rail.icicles { ic.node.isHidden = sp.covered(rail.x0 + ic.x) }
        }
        for (id, r) in rails where !seen.contains(id) { breakOff(r) }
    }

    func removeAll() {
        for r in rails.values { r.node.removeFromParent() }
        rails = [:]
    }

    /// melt > 0 — тает (pt высоты снега в секунду): сосульки укорачиваются и капают.
    func update(dt: CGFloat, melt: CGFloat, drip: (CGPoint) -> Void) {
        for r in rails.values {
            for ic in r.icicles {
                if melt > 0 {
                    ic.len = max(1.5, ic.len - melt * 3 * dt)
                    ic.dripAcc += dt * (0.25 + melt * 8)
                    if ic.dripAcc > 1 {
                        ic.dripAcc = 0
                        if !ic.node.isHidden { drip(CGPoint(x: r.x0 + ic.x, y: r.y - ic.len)) }
                    }
                } else if ic.len < ic.maxLen {
                    ic.len = min(ic.maxLen, ic.len + ic.maxLen / 150 * dt)
                }
                ic.body.yScale = ic.len
            }
        }
        var alive: [Falling] = []
        for var f in falling {
            f.vel.dy -= 900 * dt
            f.node.position.x += f.vel.dx * dt
            f.node.position.y += f.vel.dy * dt
            f.node.zRotation += f.spin * dt
            if f.node.position.y < -80 { f.node.removeFromParent() } else { alive.append(f) }
        }
        falling = alive
    }

    private func makeRail(_ sp: IcicleRailSpec, size: IcicleSize) -> Rail {
        let r = Rail(id: sp.id, x0: sp.x0, y: sp.y, width: sp.width)
        var x: CGFloat = .random(in: 4...12)
        while x < sp.width - 4, r.icicles.count < 150 {
            if CGFloat.random(in: 0...1) > 0.25 {
                let maxLen: CGFloat = size == .small ? .random(in: 5...16) : .random(in: 10...44)
                let w: CGFloat = size == .small ? .random(in: 3...5) : .random(in: 4...7.5)
                let ic = Icicle(x: x, maxLen: maxLen, width: w)
                r.icicles.append(ic)
                r.node.addChild(ic.node)
            }
            x += size == .small ? .random(in: 8...20) : .random(in: 12...30)
        }
        rails[sp.id] = r
        node.addChild(r.node)
        return r
    }

    /// Край исчез или сдвинулся — сосульки отламываются и падают.
    private func breakOff(_ r: Rail) {
        for ic in r.icicles where !ic.node.isHidden && falling.count < 200 {
            ic.node.removeFromParent()
            ic.node.position = CGPoint(x: r.x0 + ic.x, y: r.y)
            node.addChild(ic.node)
            falling.append(Falling(node: ic.node, vel: CGVector(dx: .random(in: -25...25), dy: .random(in: 0...40)),
                                   spin: .random(in: -3...3)))
        }
        r.node.removeFromParent()
        rails[r.id] = nil
    }
}
