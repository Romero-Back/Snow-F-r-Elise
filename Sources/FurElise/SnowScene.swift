import SpriteKit
import AppKit

/// Сцена снега для одного экрана. Координаты сцены — точки относительно левого нижнего угла экрана.
final class SnowScene: SKScene {
    let screenFrame: CGRect
    /// Высота строки меню сверху экрана — под ней висит гирлянда.
    let menuBarInset: CGFloat

    private var ledges: [Int: Ledge] = [:]
    private var particles: [Particle] = []
    private var pool: [SKSpriteNode] = []
    private var balls: [Snowball] = []
    private var heldBall: Snowball?
    private var tractor: Tractor?
    private var garland: Garland?
    private var garlandBuilt: GarlandStyle = .off
    private var accumulating = true
    private var autoTractorCheckAt: TimeInterval = 0

    private let flakeTexture = SnowScene.makeFlakeTexture()
    private let ledgeLayer = SKNode()
    private let ballLayer = SKNode()
    private let flakeLayer = SKNode()
    private let tractorLayer = SKNode()
    private let garlandLayer = SKNode()
    private let icicles = IcicleLayer()
    private let fireworks = Fireworks()
    private var sleigh: Sleigh?
    private var birds: [Bird] = []
    private var birdSpawnAt: TimeInterval = 8
    private let birdLayer = SKNode()
    private var splats: [Splat] = []
    private let splatLayer = SKNode()
    private var lastWins: [WinInfo] = []
    private var frost: Frost?
    private var cursorMovedNow = false
    private var meltAcc: CGFloat = 0
    private var countdownEnd: TimeInterval?
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    /// Слепили снеговика (три снежка друг на друге).
    var onSnowman: (() -> Void)?

    private var lastTime: TimeInterval = 0
    private var spawnAcc: CGFloat = 0
    private var lastMouse: CGPoint?
    private var mouseVel = CGVector.zero
    private var cursorNearSnow = false
    private var busyUntil: TimeInterval = 0
    private let maxParticles = 3000
    private let maxBalls = 30

    init(screenFrame: CGRect, menuBarInset: CGFloat) {
        self.screenFrame = screenFrame
        self.menuBarInset = menuBarInset
        super.init(size: screenFrame.size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        ledgeLayer.zPosition = 0
        ballLayer.zPosition = 1
        flakeLayer.zPosition = 2
        tractorLayer.zPosition = 1.5
        garlandLayer.zPosition = 1.8
        splatLayer.zPosition = 0.9
        birdLayer.zPosition = 1.2
        addChild(splatLayer)
        addChild(birdLayer)
        fireworks.onLaunch = { Sound.shared.play(.whoosh, gain: 0.6) }
        fireworks.onBurst = { Sound.shared.play(.pop) }
        icicles.onBreak = { Sound.shared.play(.tinkle) }
        icicles.node.zPosition = 1.7
        fireworks.node.zPosition = 0.5
        countdownLabel.zPosition = 3
        countdownLabel.fontSize = 200
        countdownLabel.fontColor = .white
        countdownLabel.verticalAlignmentMode = .center
        countdownLabel.isHidden = true
        addChild(fireworks.node)
        addChild(icicles.node)
        addChild(countdownLabel)
        addChild(tractorLayer)
        addChild(garlandLayer)
        addChild(ledgeLayer)
        addChild(ballLayer)
        addChild(flakeLayer)
        addLedge(Ledge(id: -1, x0: 0, y: 0, width: screenFrame.width, cap: 26, isGround: true))
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override func didMove(to view: SKView) {
        // Чтобы снег шёл сразу по всему экрану, а не начинался сверху.
        let count = Int(currentRate() * size.height / 60)
        for _ in 0..<min(count, 1500) { spawnFlake(y: .random(in: 0...size.height)) }
    }

    // MARK: - Публичное API

    func clearAll() {
        for l in ledges.values {
            for i in 0..<l.n { l.h[i] = 0 }
            l.dirty = true; l.urgent = true
        }
        for b in balls { removeBall(b, puff: true) }
        heldBall = nil
        for sp in splats { sp.node.removeFromParent() }
        splats = []
    }

    /// Вызвать трактор: выезжает из-за случайного края экрана и чистит низ экрана.
    func callTractor() {
        guard tractor == nil else { return }
        let dir: CGFloat = Bool.random() ? 1 : -1
        let tr = Tractor(dir: dir, x: dir > 0 ? -Tractor.length : size.width + Tractor.length)
        tractor = tr
        tractorLayer.addChild(tr.node)
    }

    /// Салют на `seconds` секунд.
    func launchFireworks(seconds: CGFloat) { fireworks.start(duration: seconds) }

    /// Новогодний отсчёт: через `seconds` секунд — поздравление и салют.
    func startCountdown(seconds: Int) {
        countdownEnd = lastTime + TimeInterval(seconds)
    }

    /// Дед Мороз пролетает по верху экрана.
    func launchSleigh() {
        guard sleigh == nil else { return }
        let dir: CGFloat = Bool.random() ? 1 : -1
        let y = size.height - menuBarInset - .random(in: 90...170)
        let sl = Sleigh(dir: dir, x: dir > 0 ? -Sleigh.length : size.width + Sleigh.length, y: y)
        sl.node.zPosition = 1.9
        addChild(sl.node)
        sleigh = sl
    }

    func updateWindows(_ wins: [WinInfo]) {
        lastWins = wins
        syncIcicles(wins)
        syncSplats(wins)
        var seen: Set<Int> = [-1]
        for (idx, w) in wins.enumerated() {
            let top = w.frame.maxY
            guard top > screenFrame.minY + 30, top <= screenFrame.maxY + 1,
                  w.frame.maxX > screenFrame.minX, w.frame.minX < screenFrame.maxX else { continue }
            let x0 = w.frame.minX - screenFrame.minX
            let y = top - screenFrame.minY
            let n = max(2, Int(w.frame.width / colW))

            var ledge = ledges[w.id]
            if let l = ledge, abs(l.x0 - x0) > 0.5 || abs(l.y - y) > 0.5 || l.n != n {
                // Окно сдвинули или изменили — снег с него осыпается.
                shakeOff(l, vel: CGVector(dx: (x0 - l.x0) * 8, dy: (y - l.y) * 8))
                removeLedge(l)
                ledge = nil
            }
            let l: Ledge
            if let existing = ledge {
                l = existing
            } else {
                l = Ledge(id: w.id, x0: x0, y: y, width: w.frame.width, cap: 16, isGround: false)
                addLedge(l)
            }
            let vis = visibility(n: l.n, startX: w.frame.minX, y: top + 1, front: wins[0..<idx])
            if vis != l.visible { l.visible = vis; l.dirty = true; l.urgent = true }
            seen.insert(w.id)
        }
        if let g = ledges[-1] {
            let vis = visibility(n: g.n, startX: screenFrame.minX, y: screenFrame.minY + 1, front: wins[...])
            if vis != g.visible { g.visible = vis; g.dirty = true; g.urgent = true }
        }
        for (id, l) in ledges where !seen.contains(id) {
            shakeOff(l, vel: .zero)
            removeLedge(l)
        }
    }

    // MARK: - Кадр

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(lastTime == 0 ? 1.0 / 60 : min(1.0 / 20, max(0.001, currentTime - lastTime)))
        lastTime = currentTime
        spawn(dt)
        handleCursor(dt)
        stepParticles(dt)
        stepBalls(dt)
        stepTractor(dt, currentTime)
        syncAccumulation()
        syncGarland(currentTime)
        stepDecorations(dt)
        stepBirds(dt, currentTime)
        stepSplats(dt)
        stepFrost(dt)
        stepCountdown(currentTime)
        refreshLedges(currentTime)
        adaptFrameRate(currentTime)
    }

    /// Пока снег просто падает, хватает 30 fps (полноэкранный прозрачный слой дорого композитить).
    /// Когда снег трогают, катают снежки или он осыпается, — 60 fps для плавности.
    private func adaptFrameRate(_ t: TimeInterval) {
        let active = cursorNearSnow || heldBall != nil || tractor != nil || sleigh != nil
            || fireworks.isActive || countdownEnd != nil
            || balls.contains { $0.state == .falling || $0.state == .thrown }
            || birds.contains { $0.state != .sitting }
            || particles.contains { $0.ballistic && $0.volume > 0 }
        if active { busyUntil = t + 0.8 }
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let fps = (t < busyUntil && !lowPower) ? 60 : 30
        if let v = view, v.preferredFramesPerSecond != fps { v.preferredFramesPerSecond = fps }
    }

    private func currentRate() -> CGFloat {
        guard let intensity = Settings.shared.effectiveIntensity else { return 0 }
        var rate = intensity.rate * size.width / 1000
        let pi = ProcessInfo.processInfo
        if pi.isLowPowerModeEnabled || pi.thermalState == .serious || pi.thermalState == .critical {
            rate *= 0.4
        }
        return rate
    }

    private func spawn(_ dt: CGFloat) {
        spawnAcc += currentRate() * dt
        while spawnAcc >= 1 {
            spawnAcc -= 1
            guard particles.count < maxParticles else { spawnAcc = 0; break }
            spawnFlake(y: size.height + 6)
        }
    }

    private func spawnFlake(y: CGFloat) {
        let s = Settings.shared
        let pad = abs(CGFloat(s.effectiveWind)) * 250
        spawnFlake(at: CGPoint(x: .random(in: -pad...(size.width + pad)), y: y))
    }

    private func spawnFlake(at p: CGPoint) {
        let sz = 1.6 + pow(CGFloat.random(in: 0...1), 2) * 3.8
        let speed = (22 + sz * 11) * (Settings.shared.effectiveIntensity == .blizzard ? 1.5 : 1)
        addParticle(pos: p, vel: CGVector(dx: 0, dy: -speed), size: sz, volume: sz * sz * 0.22, ballistic: false)
    }

    @discardableResult
    private func addParticle(pos: CGPoint, vel: CGVector, size: CGFloat, volume: CGFloat,
                             ballistic: Bool, life: CGFloat = -1, tint: NSColor? = nil) -> Particle? {
        guard particles.count < maxParticles else { return nil }
        let node = pool.popLast() ?? SKSpriteNode(texture: flakeTexture)
        if let tint {
            node.color = tint
            node.colorBlendFactor = 1
        } else {
            node.colorBlendFactor = 0
        }
        node.size = CGSize(width: size, height: size)
        node.position = pos
        node.alpha = life > 0 ? 0.95 : .random(in: 0.7...1)
        flakeLayer.addChild(node)
        let p = Particle(node: node, pos: pos, vel: vel, size: size, volume: volume, ballistic: ballistic, life: life)
        particles.append(p)
        return p
    }

    private func stepParticles(_ dt: CGFloat) {
        let wind = CGFloat(Settings.shared.effectiveWind) * 40
        var alive: [Particle] = []
        alive.reserveCapacity(particles.count)
        for p in particles {
            let oldY = p.pos.y
            if p.ballistic {
                p.vel.dy -= 650 * dt
                p.vel.dx += (wind - p.vel.dx) * 0.8 * dt
            } else {
                p.phase += p.freq * dt
                let target = wind * (0.55 + p.size * 0.15) + sin(p.phase * 2 * .pi) * 14
                p.vel.dx += (target - p.vel.dx) * 1.5 * dt
            }
            p.pos.x += p.vel.dx * dt
            p.pos.y += p.vel.dy * dt

            var dead = false
            if p.life >= 0 {
                p.life -= dt
                p.node.alpha = max(0, min(1, p.life * 1.5))
                dead = p.life <= 0
            } else if p.vel.dy < 0, accumulating {
                if let hit = landing(x: p.pos.x, from: oldY, to: p.pos.y) {
                    hit.0.h[hit.1] += p.volume / colW
                    hit.0.dirty = true
                    dead = true
                } else if hitsBall(p.pos) {
                    dead = true
                }
            }
            if p.pos.y < -20 || p.pos.x < -400 || p.pos.x > size.width + 400 { dead = true }

            if dead {
                p.node.removeFromParent()
                pool.append(p.node)
            } else {
                p.node.position = p.pos
                alive.append(p)
            }
        }
        particles = alive
    }

    private func landing(x: CGFloat, from y0: CGFloat, to y1: CGFloat) -> (Ledge, Int)? {
        var best: (Ledge, Int)?
        var bestY = -CGFloat.infinity
        for l in ledges.values {
            guard let c = l.col(at: x), l.visible[c] else { continue }
            let surf = l.y + l.h[c]
            if y0 >= surf, y1 < surf, surf > bestY { best = (l, c); bestY = surf }
        }
        return best
    }

    private func hitsBall(_ p: CGPoint) -> Bool {
        for b in balls where b.state == .resting {
            if hypot(p.x - b.pos.x, p.y - b.pos.y) < b.r { return true }
        }
        return false
    }

    private func refreshLedges(_ t: TimeInterval) {
        for l in ledges.values where l.dirty {
            guard l.urgent || t - l.builtAt > 0.2 else { continue }
            let (sl, sr, moved) = l.relax()
            l.spillL += sl * colW
            l.spillR += sr * colW
            while l.spillL >= 2 {
                l.spillL -= 2
                addParticle(pos: CGPoint(x: l.x0 - 2, y: l.y + 1.5),
                            vel: CGVector(dx: -.random(in: 10...35), dy: -.random(in: 35...55)),
                            size: 3, volume: 2, ballistic: false)
            }
            while l.spillR >= 2 {
                l.spillR -= 2
                addParticle(pos: CGPoint(x: l.maxX + 2, y: l.y + 1.5),
                            vel: CGVector(dx: .random(in: 10...35), dy: -.random(in: 35...55)),
                            size: 3, volume: 2, ballistic: false)
            }
            l.rebuildPath()
            l.builtAt = t
            l.urgent = false
            l.dirty = moved
        }
    }

    // MARK: - Курсор

    private func handleCursor(_ dt: CGFloat) {
        let g = NSEvent.mouseLocation
        let m = CGPoint(x: g.x - screenFrame.minX, y: g.y - screenFrame.minY)
        defer { lastMouse = m }
        guard let last = lastMouse else { return }
        let dx = m.x - last.x, dy = m.y - last.y
        mouseVel = CGVector(dx: mouseVel.dx * 0.6 + dx / dt * 0.4, dy: mouseVel.dy * 0.6 + dy / dt * 0.4)
        let moved = dx * dx + dy * dy > 0.25
        let onScreen = CGRect(origin: .zero, size: size).insetBy(dx: -40, dy: -40).contains(m)
        let option = NSEvent.modifierFlags.contains(.option)
        // С инструментом «Ничего» курсор снег не трогает — и 60 fps ради него не нужны.
        cursorMovedNow = moved && onScreen
        cursorNearSnow = onScreen && (Settings.shared.tool != .none || option) && ledges.values.contains {
            m.x > $0.x0 - 30 && m.x < $0.maxX + 30 && m.y > $0.y - 30 && m.y < $0.y + $0.cap + 30
        }

        // ⌥ + движение по снегу — катаем снежок.
        if let ball = heldBall {
            if option && onScreen {
                if moved { ball.area += sweep(from: last, to: m, radius: ball.r * 0.9, dry: false).0 }
                ball.pos = m
                ball.node.position = m
                ball.syncShape()
            } else {
                heldBall = nil
                // Отпустили ⌥ на быстром движении — бросок: снежок летит и бьётся о окно.
                if hypot(mouseVel.dx, mouseVel.dy) > 700 {
                    ball.throwIt(vel: clamp(CGVector(dx: mouseVel.dx * 0.9, dy: mouseVel.dy * 0.9), 1600))
                    Sound.shared.play(.whoosh)
                } else {
                    ball.fall(vel: clamp(CGVector(dx: mouseVel.dx * 0.35, dy: mouseVel.dy * 0.35), 600))
                }
            }
            return
        }
        guard onScreen, moved else { return }

        if option {
            let a = sweep(from: last, to: m, radius: 9, dry: false).0
            if a > 0.5, balls.count < maxBalls {
                let b = Snowball(pos: m, area: .pi * 36 + a)
                balls.append(b)
                ballLayer.addChild(b.node)
                heldBall = b
            }
            return
        }

        switch Settings.shared.tool {
        case .none:
            break
        case .mitten:
            let a = sweep(from: last, to: m, radius: 12, dry: false).0
            if a > 0.3 { toss(area: a, at: m) }
            if a > 1.5 { Sound.shared.play(.crunch) }
            for b in balls where b.state == .resting && hypot(m.x - b.pos.x, m.y - b.pos.y) < b.r + 6 {
                b.fall(vel: clamp(CGVector(dx: mouseVel.dx * 0.5, dy: max(60, mouseVel.dy * 0.3) + 60), 700))
            }
        case .shovel:
            for l in sweep(from: last, to: m, radius: 18, dry: true).1 {
                clearLedge(l)
                Sound.shared.play(.crunch, gain: 1.6)
            }
            for b in balls where b.state != .gone && hypot(m.x - b.pos.x, m.y - b.pos.y) < b.r + 10 {
                removeBall(b, puff: true)
            }
        }
    }

    private func clamp(_ v: CGVector, _ maxLen: CGFloat) -> CGVector {
        let len = hypot(v.dx, v.dy)
        guard len > maxLen else { return v }
        return CGVector(dx: v.dx / len * maxLen, dy: v.dy / len * maxLen)
    }

    private func sweep(from a: CGPoint, to b: CGPoint, radius r: CGFloat, dry: Bool) -> (CGFloat, [Ledge]) {
        let len = hypot(b.x - a.x, b.y - a.y)
        let steps = min(40, max(1, Int(len / max(2, r * 0.5))))
        var total: CGFloat = 0
        var touched: [ObjectIdentifier: Ledge] = [:]
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let (area, ls) = carve(center: p, radius: r, dry: dry)
            total += area
            for l in ls { touched[ObjectIdentifier(l)] = l }
        }
        return (total, Array(touched.values))
    }

    /// Вырезает снег, попавший в круг. Возвращает убранную площадь и задетые поверхности.
    private func carve(center: CGPoint, radius r: CGFloat, dry: Bool) -> (CGFloat, [Ledge]) {
        var area: CGFloat = 0
        var touched: [Ledge] = []
        for l in ledges.values {
            guard center.y + r > l.y - 1, center.y - r < l.y + l.cap + 1,
                  center.x + r > l.x0, center.x - r < l.maxX else { continue }
            let c0 = max(0, Int((center.x - r - l.x0) / colW))
            let c1 = min(l.n - 1, Int((center.x + r - l.x0) / colW))
            guard c0 <= c1 else { continue }
            var got: CGFloat = 0
            for c in c0...c1 where l.visible[c] {
                let dx = l.colX(c) - center.x
                guard abs(dx) < r else { continue }
                let limit = max(0, center.y - sqrt(r * r - dx * dx) - l.y)
                if l.h[c] > limit + 0.05 {
                    got += (l.h[c] - limit) * colW
                    if !dry { l.h[c] = limit }
                }
            }
            if got > 0 {
                area += got
                touched.append(l)
                if !dry { l.dirty = true; l.urgent = true }
            }
        }
        return (area, touched)
    }

    /// Варежка подбрасывает снег, он разлетается и ложится в другом месте.
    private func toss(area a: CGFloat, at m: CGPoint) {
        let count = min(14, max(1, Int(a / 2.5)))
        for _ in 0..<count {
            let v = clamp(CGVector(dx: mouseVel.dx * 0.45 + .random(in: -40...40),
                                   dy: abs(mouseVel.dx) * 0.12 + .random(in: 40...150)), 900)
            addParticle(pos: CGPoint(x: m.x + .random(in: -6...6), y: m.y + .random(in: -3...3)),
                        vel: v, size: .random(in: 2.2...4.2), volume: a / CGFloat(count), ballistic: true)
        }
    }

    private func puff(at p: CGPoint, spread: CGFloat) {
        addParticle(pos: CGPoint(x: p.x + .random(in: -spread...spread), y: p.y + .random(in: 0...spread)),
                    vel: CGVector(dx: .random(in: -50...50) + mouseVel.dx * 0.2, dy: .random(in: 30...170)),
                    size: .random(in: 2...4), volume: 0, ballistic: true, life: .random(in: 0.5...1.1))
    }

    private func clearLedge(_ l: Ledge) {
        var budget = 250
        for c in stride(from: 0, to: l.n, by: 2) where l.visible[c] && l.h[c] > 0.5 && budget > 0 {
            budget -= 1
            puff(at: CGPoint(x: l.colX(c), y: l.y + .random(in: 0...l.h[c])), spread: 2)
        }
        for i in 0..<l.n { l.h[i] = 0 }
        l.dirty = true
        l.urgent = true
    }

    private func shakeOff(_ l: Ledge, vel: CGVector) {
        var total: CGFloat = 0
        for c in 0..<l.n where l.visible[c] { total += l.h[c] * colW }
        guard total > 1 else { return }
        let vp = max(2, total / 500)
        var acc: CGFloat = 0
        for c in 0..<l.n where l.visible[c] && l.h[c] > 0 {
            acc += l.h[c] * colW
            while acc >= vp {
                acc -= vp
                addParticle(pos: CGPoint(x: l.colX(c) + .random(in: -1.5...1.5), y: l.y + .random(in: 0...l.h[c])),
                            vel: clamp(CGVector(dx: vel.dx * 0.5 + .random(in: -25...25),
                                                dy: vel.dy * 0.3 + .random(in: -10...50)), 800),
                            size: min(5, max(2, sqrt(vp / 0.22))), volume: vp, ballistic: true)
            }
        }
    }

    private func addLedge(_ l: Ledge) {
        ledges[l.id] = l
        ledgeLayer.addChild(l.node)
    }

    private func removeLedge(_ l: Ledge) {
        l.node.removeFromParent()
        ledges[l.id] = nil
    }

    private func visibility(n: Int, startX: CGFloat, y: CGFloat, front: ArraySlice<WinInfo>) -> [Bool] {
        var vis = [Bool](repeating: true, count: n)
        func hide(from x0: CGFloat, to x1: CGFloat) {
            let a = max(0, Int(floor((x0 - startX) / colW)))
            let b = min(n - 1, Int(ceil((x1 - startX) / colW)) - 1)
            if a <= b { for c in a...b { vis[c] = false } }
        }
        for f in front where f.frame.minY <= y && f.frame.maxY > y {
            hide(from: f.frame.minX, to: f.frame.maxX)
        }
        hide(from: startX - 10_000, to: screenFrame.minX)
        hide(from: screenFrame.maxX, to: screenFrame.maxX + 10_000)
        return vis
    }

    // MARK: - Сугробы вкл/выкл и гирлянда

    /// Выключили накопление — весь лежащий снег осыпается, снежки рассыпаются.
    private func syncAccumulation() {
        let want = Settings.shared.accumulate
        guard want != accumulating else { return }
        accumulating = want
        guard !want else { return }
        for l in ledges.values {
            shakeOff(l, vel: .zero)
            for i in 0..<l.n { l.h[i] = 0 }
            l.dirty = true
            l.urgent = true
        }
        for b in balls { removeBall(b, puff: true) }
        heldBall = nil
    }

    private func syncGarland(_ t: TimeInterval) {
        let style = Settings.shared.garland
        if style != garlandBuilt {
            garland?.node.removeFromParent()
            garland = nil
            if style != .off {
                let g = Garland(width: size.width, topY: size.height - menuBarInset, style: style)
                garlandLayer.addChild(g.node)
                garland = g
            }
            garlandBuilt = style
        }
        garland?.update(t: CGFloat(t), mode: Settings.shared.garlandMode)
    }

    // MARK: - Украшения, таяние, Новый год

    private func syncIcicles(_ wins: [WinInfo]) {
        let s = Settings.shared
        guard s.icicles else {
            if !icicles.isEmpty { icicles.removeAll() }
            return
        }
        var specs: [IcicleRailSpec] = []
        if s.icicleWhere != .windows, menuBarInset > 0 {
            specs.append(IcicleRailSpec(id: -10, x0: 0, y: size.height - menuBarInset, width: size.width,
                                        covered: { _ in false }))
        }
        if s.icicleWhere != .menu {
            let sf = screenFrame
            for (idx, w) in wins.enumerated() where w.id >= 0 {
                let bottom = w.frame.minY
                guard bottom > sf.minY + 50, bottom < sf.maxY - menuBarInset - 10,
                      w.frame.maxX > sf.minX, w.frame.minX < sf.maxX else { continue }
                let front = wins[0..<idx]
                let gy = bottom - 3
                specs.append(IcicleRailSpec(id: w.id, x0: w.frame.minX - sf.minX, y: bottom - sf.minY,
                                            width: w.frame.width, covered: { lx in
                    let gx = lx + sf.minX
                    if gx < sf.minX || gx > sf.maxX { return true }
                    return front.contains { $0.frame.contains(CGPoint(x: gx, y: gy)) }
                }))
            }
        }
        icicles.sync(specs, size: s.icicleSize)
    }

    /// Скорость таяния, pt высоты в секунду. 0 — не тает.
    private func meltRate() -> CGFloat {
        let s = Settings.shared
        guard s.melting else { return 0 }
        var rate: CGFloat
        switch ProcessInfo.processInfo.thermalState {
        case .fair: rate = 0.015
        case .serious: rate = 0.05
        case .critical: rate = 0.1
        default: rate = 0
        }
        if let w = s.activeWeather, w.temp > 0.5 {
            rate = max(rate, CGFloat(min(w.temp, 10)) * 0.006)
        }
        return rate
    }

    private func drip(at p: CGPoint) {
        addParticle(pos: p, vel: CGVector(dx: 0, dy: -.random(in: 20...60)), size: .random(in: 2...3),
                    volume: 0, ballistic: true, life: .random(in: 1.0...1.6),
                    tint: NSColor(calibratedRed: 0.55, green: 0.78, blue: 1, alpha: 1))
    }

    private func stepDecorations(_ dt: CGFloat) {
        let melt = meltRate()
        icicles.update(dt: dt, melt: melt) { drip(at: $0) }

        // Таяние сугробов — раз в полсекунды, с капелью с краёв.
        if melt > 0 {
            meltAcc += dt
            if meltAcc >= 0.5 {
                for l in ledges.values {
                    var any = false
                    for i in 0..<l.n where l.h[i] > 0 {
                        l.h[i] = max(0, l.h[i] - melt * meltAcc)
                        any = true
                    }
                    guard any else { continue }
                    l.dirty = true
                    if !l.isGround, CGFloat.random(in: 0...1) < melt * 20 {
                        let c = Int.random(in: 0..<l.n)
                        if l.visible[c], l.h[c] > 0.5 { drip(at: CGPoint(x: l.colX(c), y: l.y - 1)) }
                    }
                }
                meltAcc = 0
            }
        }

        fireworks.update(dt: dt, size: size)

        if let sl = sleigh {
            sl.step(dt)
            sl.trailAcc += dt
            if sl.trailAcc > 0.035 {
                sl.trailAcc = 0
                addParticle(pos: sl.trailPoint, vel: CGVector(dx: -sl.dir * .random(in: 10...40), dy: -.random(in: 5...25)),
                            size: .random(in: 2.5...4.5), volume: 0, ballistic: false, life: .random(in: 0.6...1.1),
                            tint: NSColor(calibratedRed: 1, green: 0.85, blue: 0.35, alpha: 1))
            }
            sl.bellAcc += dt
            if sl.bellAcc > 0.9 {
                sl.bellAcc = 0
                Sound.shared.play(.bells)
            }
            sl.snowAcc += dt
            if sl.snowAcc > 0.12 {
                sl.snowAcc = 0
                spawnFlake(at: CGPoint(x: sl.bellyPoint.x + .random(in: -40...40), y: sl.bellyPoint.y))
            }
            if (sl.dir > 0 && sl.x > size.width + Sleigh.length) || (sl.dir < 0 && sl.x < -Sleigh.length) {
                sl.node.removeFromParent()
                sleigh = nil
            }
        }
    }

    private func stepCountdown(_ t: TimeInterval) {
        guard let end = countdownEnd else { return }
        let left = end - t
        if left > 0 {
            let n = Int(ceil(left))
            let frac = CGFloat(left - floor(left))   // 1 → 0 за каждую секунду
            countdownLabel.isHidden = false
            countdownLabel.text = "\(n)"
            countdownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            countdownLabel.setScale(1 + 0.35 * frac)
            countdownLabel.alpha = 0.25 + 0.75 * frac
        } else {
            countdownEnd = nil
            countdownLabel.isHidden = true
            showGreeting()
            fireworks.start(duration: 90)
        }
    }

    private func showGreeting() {
        let label = SKLabelNode(fontNamed: "SnellRoundhand-Bold")
        label.text = tr("С Новым годом!", "Happy New Year!")
        label.fontSize = min(120, size.width / 9)
        label.fontColor = NSColor(calibratedRed: 1, green: 0.85, blue: 0.35, alpha: 1)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        label.zPosition = 3
        label.alpha = 0
        label.setScale(0.8)
        addChild(label)
        label.run(.sequence([
            .group([.fadeIn(withDuration: 1.2), .scale(to: 1, duration: 1.2)]),
            .wait(forDuration: 10),
            .fadeOut(withDuration: 2),
            .removeFromParent(),
        ]))
    }

    // MARK: - Иней

    private func stepFrost(_ dt: CGFloat) {
        let s = Settings.shared
        guard s.frost else {
            if let f = frost { f.node.removeFromParent(); frost = nil }
            return
        }
        if frost == nil {
            let f = Frost(size: size, topInset: menuBarInset, heavy: s.frostSize == .heavy)
            f.node.zPosition = 2.6
            addChild(f.node)
            frost = f
        }
        frost?.setHeavy(s.frostSize == .heavy)
        frost?.update(dt: dt, cursor: cursorMovedNow ? lastMouse : nil)
    }

    // MARK: - Снегири

    private func stepBirds(_ dt: CGFloat, _ t: TimeInterval) {
        let s = Settings.shared
        if s.birds, accumulating, birds.count < 2, t > birdSpawnAt {
            birdSpawnAt = t + .random(in: 15...40)
            if let (l, c) = findPerch() {
                let target = CGPoint(x: l.colX(c), y: l.y + l.h[c])
                let fromLeft = Bool.random()
                let start = CGPoint(x: fromLeft ? -30 : size.width + 30,
                                    y: min(size.height - menuBarInset - 20, target.y + .random(in: 80...220)))
                let b = Bird(pos: start, ledgeId: l.id, col: c)
                b.face(fromLeft ? 1 : -1)
                birdLayer.addChild(b.node)
                birds.append(b)
            }
        }
        for b in birds {
            switch b.state {
            case .flyingIn:
                guard s.birds, let l = ledges[b.ledgeId], b.col < l.n, l.visible[b.col] else { scare(b, from: nil); break }
                let target = CGPoint(x: l.colX(b.col), y: l.y + l.h[b.col])
                let dx = target.x - b.pos.x, dy = target.y - b.pos.y
                let d = hypot(dx, dy)
                if d < 4 {
                    b.pos = target
                    b.state = .sitting
                } else {
                    let k = min(1, (180 + d * 0.6) * dt / d)
                    b.pos.x += dx * k
                    b.pos.y += dy * k + sin(b.t * 7) * 0.5
                    b.face(dx)
                }
            case .sitting:
                guard s.birds, let l = ledges[b.ledgeId], b.col < l.n, l.visible[b.col], l.h[b.col] > 0.3 else {
                    scare(b, from: nil); break
                }
                b.pos.y = l.y + l.h[b.col]
                if cursorMovedNow, let m = lastMouse, hypot(m.x - b.pos.x, m.y - b.pos.y) < 90 { scare(b, from: m); break }
                if let tr = tractor, b.ledgeId == -1, abs(tr.x - b.pos.x) < 150 { scare(b, from: CGPoint(x: tr.x, y: 0)); break }
                b.nextPeck -= dt
                if b.nextPeck <= 0 { b.peck = 0.35; b.nextPeck = .random(in: 1.2...4) }
                b.nextChirp -= dt
                if b.nextChirp <= 0 { b.nextChirp = .random(in: 12...35); Sound.shared.play(.chirp, gain: 0.5) }
            case .flyingAway:
                b.vel.dy += 120 * dt
                b.pos.x += b.vel.dx * dt
                b.pos.y += b.vel.dy * dt
            }
            b.animate(dt)
        }
        birds.removeAll { b in
            let gone = b.state == .flyingAway
                && (b.pos.x < -60 || b.pos.x > size.width + 60 || b.pos.y > size.height + 40)
            if gone { b.node.removeFromParent() }
            return gone
        }
    }

    private func scare(_ b: Bird, from p: CGPoint?) {
        guard b.state != .flyingAway else { return }
        b.state = .flyingAway
        let dir: CGFloat = p.map { b.pos.x >= $0.x ? 1 : -1 } ?? (Bool.random() ? 1 : -1)
        b.vel = CGVector(dx: dir * .random(in: 180...260), dy: .random(in: 120...200))
        b.face(dir)
        if p != nil { Sound.shared.play(.chirp) }
    }

    /// Место на сугробе, где снег не меньше 2 pt и рядом нет другого снегиря.
    private func findPerch() -> (Ledge, Int)? {
        var cands: [(Ledge, Int)] = []
        for l in ledges.values where l.n > 8 {
            let step = max(1, l.n / 12)
            for c in stride(from: 3, to: l.n - 3, by: step) where l.visible[c] && l.h[c] > 2 {
                let x = l.colX(c)
                if !birds.contains(where: { $0.ledgeId == l.id && abs($0.pos.x - x) < 30 }) { cands.append((l, c)) }
            }
        }
        return cands.randomElement()
    }

    // MARK: - Кляксы от снежков

    private final class Splat {
        let node: SKNode
        let winId: Int
        let winOrigin: CGPoint
        var age: CGFloat = 0
        init(node: SKNode, winId: Int, winOrigin: CGPoint) {
            self.node = node; self.winId = winId; self.winOrigin = winOrigin
        }
    }

    /// Самое переднее обычное окно в точке сцены.
    private func windowAt(_ p: CGPoint) -> WinInfo? {
        let g = CGPoint(x: p.x + screenFrame.minX, y: p.y + screenFrame.minY)
        guard let w = lastWins.first(where: { $0.frame.contains(g) }), w.id >= 0 else { return nil }
        return w
    }

    private func splat(on w: WinInfo, at p: CGPoint, r: CGFloat) {
        let n = SKNode()
        let k = 14
        let pts: [CGPoint] = (0..<k).map { i in
            let a = CGFloat(i) / CGFloat(k) * 2 * .pi
            let rr = r * 1.15 * .random(in: 0.7...1.15)
            return CGPoint(x: cos(a) * rr, y: sin(a) * rr)
        }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        let path = CGMutablePath()
        path.move(to: mid(pts[k - 1], pts[0]))
        for i in 0..<k { path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % k]), control: pts[i]) }
        path.closeSubpath()
        let fill = NSColor(calibratedWhite: 0.97, alpha: 0.96)
        let blob = SKShapeNode(path: path)
        blob.fillColor = fill
        blob.strokeColor = NSColor(calibratedRed: 0.7, green: 0.8, blue: 0.95, alpha: 0.8)
        blob.lineWidth = 1
        n.addChild(blob)
        for _ in 0..<Int.random(in: 4...7) {
            let a = CGFloat.random(in: 0...(2 * .pi)), d = r * .random(in: 1.3...1.9), dr = r * .random(in: 0.08...0.2)
            let drop = SKShapeNode(circleOfRadius: dr)
            drop.fillColor = fill
            drop.strokeColor = .clear
            drop.position = CGPoint(x: cos(a) * d, y: sin(a) * d)
            n.addChild(drop)
        }
        n.position = p
        splatLayer.addChild(n)
        splats.append(Splat(node: n, winId: w.id, winOrigin: w.frame.origin))
        if splats.count > 20 { splats.removeFirst().node.removeFromParent() }
        for _ in 0..<min(30, Int(r * 1.5)) { puff(at: p, spread: r * 0.6) }
        Sound.shared.play(.splat)
    }

    /// Окно сдвинули или закрыли — клякса отваливается; закрыто другим окном — прячется.
    private func syncSplats(_ wins: [WinInfo]) {
        splats.removeAll { sp in
            guard let idx = wins.firstIndex(where: { $0.id == sp.winId }),
                  abs(wins[idx].frame.minX - sp.winOrigin.x) < 0.5, abs(wins[idx].frame.minY - sp.winOrigin.y) < 0.5,
                  sp.node.position.y + screenFrame.minY > wins[idx].frame.minY else {
                for _ in 0..<12 { puff(at: sp.node.position, spread: 12) }
                sp.node.removeFromParent()
                return true
            }
            let g = CGPoint(x: sp.node.position.x + screenFrame.minX, y: sp.node.position.y + screenFrame.minY)
            sp.node.isHidden = wins[..<idx].contains { $0.frame.contains(g) }
            return false
        }
    }

    /// Клякса понемногу сползает вниз, вытягивается и тает.
    private func stepSplats(_ dt: CGFloat) {
        splats.removeAll { sp in
            sp.age += dt
            if sp.age > 1.5 {
                sp.node.position.y -= 4 * dt
                sp.node.yScale = 1 + min(0.3, (sp.age - 1.5) * 0.02)
            }
            if sp.age > 18 { sp.node.alpha = max(0, 1 - (sp.age - 18) / 6) }
            if sp.age > 24 { sp.node.removeFromParent(); return true }
            return false
        }
    }

    // MARK: - Трактор

    private func stepTractor(_ dt: CGFloat, _ t: TimeInterval) {
        if tractor == nil, Settings.shared.autoTractor, t > autoTractorCheckAt {
            autoTractorCheckAt = t + 3
            if let g = ledges[-1] {
                var sum: CGFloat = 0, n = 0
                for c in 0..<g.n where g.visible[c] { sum += g.h[c]; n += 1 }
                if n > 0, sum / CGFloat(n) > 14 { callTractor() }
            }
        }
        guard let tr = tractor else { return }

        let oldBlade = tr.bladeFrontX
        var removed: CGFloat = 0
        if let g = ledges[-1] {
            // Чистим под отвалом и под всем трактором, чтобы осыпь из сугроба впереди
            // не оставляла за ним дорожку.
            let newBlade = oldBlade + tr.dir * tr.speed * dt
            let tail = newBlade - tr.dir * 45
            let c0 = max(0, Int((min(newBlade, tail) - g.x0) / colW))
            let c1 = min(g.n - 1, Int((max(newBlade, tail) - g.x0) / colW))
            if c0 <= c1 {
                for c in c0...c1 where g.h[c] > 0 { removed += g.h[c] * colW; g.h[c] = 0 }
                if removed > 0 { g.dirty = true; g.urgent = true }
            }
        }
        tr.step(dt, onSnow: removed > 0.5)

        // Снег из-под отвала летит вверх и в сторону.
        if removed > 0.5 {
            Sound.shared.play(.crunch, gain: 0.5)
            let count = min(8, Int(removed / 4) + 1)
            for _ in 0..<count {
                addParticle(pos: CGPoint(x: tr.bladeFrontX, y: .random(in: 8...22)),
                            vel: CGVector(dx: tr.dir * .random(in: 30...150), dy: .random(in: 150...300)),
                            size: .random(in: 2.5...4.5), volume: 0, ballistic: true, life: .random(in: 0.7...1.3))
            }
        }
        // Дым из трубы.
        tr.smokeAcc += dt
        if tr.smokeAcc > 0.12 {
            tr.smokeAcc = 0
            addParticle(pos: tr.exhaustPoint, vel: CGVector(dx: -tr.dir * .random(in: 10...30), dy: .random(in: 25...55)),
                        size: .random(in: 4...7), volume: 0, ballistic: false, life: .random(in: 0.6...1.0),
                        tint: NSColor(calibratedWhite: 0.55, alpha: 1))
        }
        // Снежки на земле отлетают от отвала.
        for b in balls where b.state == .resting && b.supportLedge == -1 && abs(b.pos.x - tr.bladeFrontX) < b.r {
            b.fall(vel: CGVector(dx: tr.dir * 260, dy: 220))
        }

        if (tr.dir > 0 && tr.x > size.width + Tractor.length) || (tr.dir < 0 && tr.x < -Tractor.length) {
            tr.node.removeFromParent()
            tractor = nil
            autoTractorCheckAt = t + 20
        }
    }

    // MARK: - Снежки

    private func stepBalls(_ dt: CGFloat) {
        for b in balls {
            switch b.state {
            case .held, .gone:
                break
            case .thrown:
                b.flightTime += dt
                b.vel.dy -= 500 * dt
                b.pos.x += b.vel.dx * dt
                b.pos.y += b.vel.dy * dt
                b.node.position = b.pos
                if b.pos.y < -b.r * 2 || b.pos.x < -200 || b.pos.x > size.width + 200 {
                    removeBall(b, puff: false)
                } else if b.flightTime > 0.12, let w = windowAt(b.pos) {
                    splat(on: w, at: b.pos, r: b.r)
                    removeBall(b, puff: false)
                } else if b.flightTime > 1.6 {
                    b.fall(vel: b.vel)
                }
            case .resting:
                if !supportValid(b) { b.fall() }
            case .falling:
                b.vel.dy -= 900 * dt
                b.vel.dx *= (1 - 0.5 * dt)
                let oldY = b.pos.y
                b.pos.x += b.vel.dx * dt
                b.pos.y += b.vel.dy * dt
                land(b, oldY: oldY)
                if b.pos.y < -b.r * 2 || b.pos.x < -200 || b.pos.x > size.width + 200 {
                    removeBall(b, puff: false)
                }
                b.node.position = b.pos
            }
        }
        balls.removeAll { $0.state == .gone }
        for b in balls {
            let want = b.state == .resting
                && b.supportBall?.state == .resting
                && b.supportBall?.supportBall?.state == .resting
                && !balls.contains { $0.state == .resting && $0.supportBall === b }
            let had = b.hasFace
            b.setFace(want)
            if want && !had { onSnowman?() }
        }
        // Средний шар снеговика — руки-веточки и пуговицы.
        for b in balls {
            b.setBody(b.state == .resting && balls.contains { $0.hasFace && $0.supportBall === b })
        }
    }

    private func supportValid(_ b: Snowball) -> Bool {
        if let sb = b.supportBall { return sb.state == .resting }
        if let id = b.supportLedge, let l = ledges[id] {
            return abs(l.y - b.supportY) < 0.5 && b.pos.x >= l.x0 && b.pos.x < l.maxX
        }
        return false
    }

    private func land(_ b: Snowball, oldY: CGFloat) {
        let r = b.r
        var bestY = -CGFloat.infinity
        var onBall: Snowball?
        var onLedge: Ledge?
        for o in balls where o !== b && o.state == .resting {
            guard abs(b.pos.x - o.pos.x) < (o.r + r) * 0.55 else { continue }
            let target = o.pos.y + o.r + r * 0.8
            if oldY >= target, b.pos.y < target, target > bestY { bestY = target; onBall = o; onLedge = nil }
        }
        for l in ledges.values {
            guard let c = l.col(at: b.pos.x), l.visible[c] else { continue }
            let target = l.y + l.h[c] + r * 0.85
            if oldY >= target, b.pos.y < target, target > bestY { bestY = target; onLedge = l; onBall = nil }
        }
        guard bestY > -.infinity else { return }
        b.state = .resting
        b.vel = .zero
        b.pos.y = bestY
        if let o = onBall {
            b.pos.x = o.pos.x + (b.pos.x - o.pos.x) * 0.3
            b.supportBall = o
            b.node.zPosition = o.node.zPosition + 0.1   // верхний шар рисуется поверх нижнего
        } else if let l = onLedge {
            b.supportLedge = l.id
            b.supportY = l.y
        }
    }

    private func removeBall(_ b: Snowball, puff doPuff: Bool) {
        guard b.state != .gone else { return }
        if doPuff {
            for _ in 0..<min(60, Int(b.r * 2)) { puff(at: b.pos, spread: b.r * 0.7) }
        }
        b.state = .gone
        b.node.removeFromParent()
        if heldBall === b { heldBall = nil }
    }

    // MARK: - Текстура

    private static func makeFlakeTexture() -> SKTexture {
        let img = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
            let g = NSGradient(colors: [
                NSColor(calibratedWhite: 1, alpha: 1),
                NSColor(calibratedWhite: 1, alpha: 0.9),
                NSColor(calibratedRed: 0.72, green: 0.80, blue: 0.95, alpha: 0.55),
                NSColor(calibratedRed: 0.72, green: 0.80, blue: 0.95, alpha: 0),
            ], atLocations: [0, 0.45, 0.7, 1], colorSpace: .deviceRGB)
            g?.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
            return true
        }
        return SKTexture(image: img)
    }
}
