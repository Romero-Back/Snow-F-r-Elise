import SpriteKit
import AppKit

/// Салют: ракеты взлетают снизу со следом и разрываются разноцветными искрами.
final class Fireworks {
    let node = SKNode()

    private struct Spark {
        let s: SKSpriteNode
        var vel: CGVector
        var life: CGFloat
        let maxLife: CGFloat
        let gravity: CGFloat
    }
    private struct Rocket {
        let s: SKSpriteNode
        var vel: CGVector
        let burstY: CGFloat
        let colors: [NSColor]
        var trailAcc: CGFloat = 0
    }

    private var sparks: [Spark] = []
    private var rockets: [Rocket] = []
    private var t: CGFloat = 0
    private var until: CGFloat = 0
    private var next: CGFloat = 0
    private let maxSparks = 2500

    private static let palette: [NSColor] = [
        NSColor(calibratedRed: 1.00, green: 0.30, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 0.35, green: 1.00, blue: 0.50, alpha: 1),
        NSColor(calibratedRed: 0.35, green: 0.70, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.90, alpha: 1),
        NSColor(calibratedRed: 0.75, green: 0.55, blue: 1.00, alpha: 1),
        NSColor(calibratedWhite: 1, alpha: 1),
    ]

    var onLaunch: (() -> Void)?
    var onBurst: (() -> Void)?

    var isActive: Bool { t < until || !sparks.isEmpty || !rockets.isEmpty }

    func start(duration: CGFloat) {
        until = max(until, t + duration)
        next = t
    }

    func update(dt: CGFloat, size: CGSize) {
        t += dt
        if t < until, t >= next {
            launch(size)
            if CGFloat.random(in: 0...1) < 0.3 { launch(size) }
            next = t + .random(in: 0.3...0.9)
        }

        var liveRockets: [Rocket] = []
        for var r in rockets {
            r.vel.dy -= 260 * dt
            r.s.position.x += r.vel.dx * dt
            r.s.position.y += r.vel.dy * dt
            r.trailAcc += dt
            if r.trailAcc > 0.02 {
                r.trailAcc = 0
                addSpark(at: r.s.position, vel: CGVector(dx: .random(in: -15...15), dy: .random(in: -40...(-10))),
                         color: NSColor(calibratedRed: 1, green: 0.85, blue: 0.6, alpha: 1),
                         size: 3, life: 0.45, gravity: 40)
            }
            if r.s.position.y >= r.burstY || r.vel.dy < 70 {
                explode(at: r.s.position, colors: r.colors)
                r.s.removeFromParent()
            } else {
                liveRockets.append(r)
            }
        }
        rockets = liveRockets

        var liveSparks: [Spark] = []
        liveSparks.reserveCapacity(sparks.count)
        let drag = max(0, 1 - 1.3 * dt)
        for var sp in sparks {
            sp.vel.dx *= drag
            sp.vel.dy = sp.vel.dy * drag - sp.gravity * dt
            sp.s.position.x += sp.vel.dx * dt
            sp.s.position.y += sp.vel.dy * dt
            sp.life -= dt
            let k = sp.life / sp.maxLife
            // В конце искры мерцают.
            sp.s.alpha = k < 0.3 ? k * 3 * (CGFloat.random(in: 0...1) < 0.7 ? 1 : 0.3) : 1
            if sp.life <= 0 { sp.s.removeFromParent() } else { liveSparks.append(sp) }
        }
        sparks = liveSparks
    }

    private func launch(_ size: CGSize) {
        let s = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: 9, height: 9))
        s.color = NSColor(calibratedRed: 1, green: 0.9, blue: 0.7, alpha: 1)
        s.colorBlendFactor = 1
        s.blendMode = .add
        s.position = CGPoint(x: size.width * .random(in: 0.12...0.88), y: -5)
        node.addChild(s)
        let c1 = Fireworks.palette.randomElement()!
        let colors = CGFloat.random(in: 0...1) < 0.35 ? [c1, Fireworks.palette.randomElement()!] : [c1]
        // Скорость подбираем так, чтобы ракета успела долететь до высоты разрыва.
        let burstY = size.height * .random(in: 0.45...0.8)
        let vy = sqrt(2 * 260 * burstY) * 1.05
        rockets.append(Rocket(s: s, vel: CGVector(dx: .random(in: -40...40), dy: vy), burstY: burstY, colors: colors))
        onLaunch?()
    }

    private func explode(at p: CGPoint, colors: [NSColor]) {
        onBurst?()
        let n = Int.random(in: 80...130)
        let base = CGFloat.random(in: 170...260)
        for _ in 0..<n {
            let a = CGFloat.random(in: 0...(2 * .pi))
            let sp = base * .random(in: 0.55...1)
            addSpark(at: p, vel: CGVector(dx: cos(a) * sp, dy: sin(a) * sp), color: colors.randomElement()!,
                     size: .random(in: 3.5...5.5), life: .random(in: 1.3...2.2), gravity: 90)
        }
    }

    private func addSpark(at p: CGPoint, vel: CGVector, color: NSColor, size: CGFloat, life: CGFloat, gravity: CGFloat) {
        guard sparks.count < maxSparks else { return }
        let s = SKSpriteNode(texture: Garland.glowTexture, size: CGSize(width: size * 2.2, height: size * 2.2))
        s.color = color
        s.colorBlendFactor = 1
        s.blendMode = .add
        s.position = p
        node.addChild(s)
        sparks.append(Spark(s: s, vel: vel, life: life, maxLife: life, gravity: gravity))
    }
}
