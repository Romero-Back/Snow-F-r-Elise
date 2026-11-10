import SpriteKit
import AppKit

/// Иней по краям экрана: морозный узор нарастает от краёв и углов, курсор его растапливает,
/// потом он снова зарастает.
///
/// Узор рисуется один раз (ветвистые ледяные «папоротники» + дымка у краёв), а видимость
/// задаёт маленькая карта плотности: ячейка 16 pt, обновляется 4 раза в секунду и
/// растягивается с линейным сглаживанием — края инея получаются мягкими.
final class Frost {
    let node: SKSpriteNode
    private let cell: CGFloat = 16
    private let gw: Int
    private let gh: Int
    private var density: [Float]
    /// Случайный «шум» ячейки — чтобы граница инея была неровной.
    private let jitter: [Float]
    private var reach: CGFloat = 0
    private var maxReach: CGFloat
    private var acc: CGFloat = 0
    private let maskUniform: SKUniform
    private let size: CGSize
    private let topInset: CGFloat

    init(size: CGSize, topInset: CGFloat, heavy: Bool) {
        self.size = size
        self.topInset = topInset
        gw = Int(ceil(size.width / cell))
        gh = Int(ceil(size.height / cell))
        density = Array(repeating: 0, count: gw * gh)
        jitter = (0..<(gw * gh)).map { _ in Float.random(in: 0...1) }
        maxReach = heavy ? 240 : 130

        let pattern = Frost.drawPattern(size: size, topInset: topInset)
        node = SKSpriteNode(texture: SKTexture(cgImage: pattern), size: size)
        node.anchorPoint = .zero
        node.position = .zero

        maskUniform = SKUniform(name: "u_mask", texture: SKTexture())
        let shader = SKShader(source: """
        void main() {
            vec4 c = texture2D(u_texture, v_tex_coord);
            float m = texture2D(u_mask, v_tex_coord).r;
            gl_FragColor = c * m;
        }
        """)
        shader.uniforms = [maskUniform]
        node.shader = shader
        pushMask()
    }

    func setHeavy(_ heavy: Bool) { maxReach = heavy ? 240 : 130 }

    /// cursor — позиция курсора в сцене (если он движется рядом), растапливает иней.
    func update(dt: CGFloat, cursor: CGPoint?) {
        // Фронт инея медленно расползается от краёв: до полной ширины — минут за пять.
        reach = min(maxReach, reach + maxReach / 300 * dt)
        if let c = cursor { thaw(at: c, radius: 48) }
        acc += dt
        guard acc >= 0.25 else { return }
        let step = Float(acc)
        acc = 0

        let top = size.height - topInset
        for gy in 0..<gh {
            let cy = (CGFloat(gy) + 0.5) * cell
            for gx in 0..<gw {
                let i = gy * gw + gx
                let cx = (CGFloat(gx) + 0.5) * cell
                let dx = min(cx, size.width - cx)
                let dy = min(cy, top - cy)
                guard dy > -cell else { density[i] = 0; continue }   // строка меню — без инея
                // В углах иней заходит дальше: расстояние «скругляем».
                let d = min(dx, dy) - (dx < 200 && dy < 200 ? (200 - max(dx, dy)) * 0.35 : 0)
                let r = reach * (0.75 + 0.5 * CGFloat(jitter[i]))
                let target = Float(max(0, min(1, 1 - d / max(r, 1))))
                let t = min(1, target * 1.6)
                if density[i] < t { density[i] = min(t, density[i] + 0.08 * step) }
                else { density[i] = max(t, density[i] - 0.3 * step) }
            }
        }
        pushMask()
    }

    private func thaw(at p: CGPoint, radius: CGFloat) {
        let g0x = max(0, Int((p.x - radius) / cell)), g1x = min(gw - 1, Int((p.x + radius) / cell))
        let g0y = max(0, Int((p.y - radius) / cell)), g1y = min(gh - 1, Int((p.y + radius) / cell))
        guard g0x <= g1x, g0y <= g1y else { return }
        for gy in g0y...g1y {
            for gx in g0x...g1x {
                let cx = (CGFloat(gx) + 0.5) * cell, cy = (CGFloat(gy) + 0.5) * cell
                let d = hypot(cx - p.x, cy - p.y)
                guard d < radius else { continue }
                let i = gy * gw + gx
                density[i] *= Float(d / radius) * 0.5
            }
        }
    }

    private func pushMask() {
        var bytes = [UInt8](repeating: 0, count: gw * gh)
        for gy in 0..<gh {
            let row = gh - 1 - gy   // в CGImage первая строка — верхняя
            for gx in 0..<gw {
                bytes[row * gw + gx] = UInt8(max(0, min(255, density[gy * gw + gx] * 255)))
            }
        }
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData),
              let img = CGImage(width: gw, height: gh, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: gw,
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return }
        let tex = SKTexture(cgImage: img)
        tex.filteringMode = .linear
        maskUniform.textureValue = tex
    }

    // MARK: - Узор

    private static func drawPattern(size: CGSize, topInset: CGFloat) -> CGImage {
        let w = Int(size.width), h = Int(size.height)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let top = CGFloat(h) - topInset
        let W = CGFloat(w)

        // Лёгкая дымка у краёв.
        let haze = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [CGColor(red: 0.93, green: 0.97, blue: 1, alpha: 0.28),
                                       CGColor(red: 0.93, green: 0.97, blue: 1, alpha: 0)] as CFArray,
                              locations: [0, 1])!
        let depth: CGFloat = 200
        ctx.drawLinearGradient(haze, start: CGPoint(x: 0, y: 0), end: CGPoint(x: depth, y: 0), options: [])
        ctx.drawLinearGradient(haze, start: CGPoint(x: W, y: 0), end: CGPoint(x: W - depth, y: 0), options: [])
        ctx.drawLinearGradient(haze, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: depth), options: [])
        ctx.drawLinearGradient(haze, start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: top - depth), options: [])

        ctx.setLineCap(.round)
        func stroke(_ a: CGPoint, _ b: CGPoint, _ width: CGFloat, _ alpha: CGFloat) {
            ctx.setStrokeColor(CGColor(red: 0.96, green: 0.99, blue: 1, alpha: alpha))
            ctx.setLineWidth(width)
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()
        }
        // Морозный «папоротник»: стебель из коротких отрезков, на каждом — отростки
        // в обе стороны под ~60°, к концу стебля всё короче. Отростки тоже ветвятся.
        func fern(_ p: CGPoint, _ angle: CGFloat, _ len: CGFloat, _ width: CGFloat, _ level: Int) {
            var pos = p
            var a = angle
            let seg: CGFloat = level == 0 ? 5 : 3.5
            let steps = max(2, Int(len / seg))
            let alpha = CGFloat.random(in: 0.3...0.55) * (level == 0 ? 1 : 0.85)
            for i in 0..<steps {
                a += .random(in: -0.05...0.05)
                let np = CGPoint(x: pos.x + cos(a) * seg, y: pos.y + sin(a) * seg)
                stroke(pos, np, width, alpha)
                let k = 1 - CGFloat(i) / CGFloat(steps)          // к концу отростки короче
                if level < 2, i > 0, i % (level == 0 ? 2 : 3) == 0 {
                    let side = len * (level == 0 ? 0.32 : 0.4) * k * .random(in: 0.7...1.1)
                    if side > 4 {
                        fern(np, a + .pi / 3 + .random(in: -0.1...0.1), side, width * 0.65, level + 1)
                        fern(np, a - .pi / 3 + .random(in: -0.1...0.1), side, width * 0.65, level + 1)
                    }
                }
                pos = np
            }
        }
        func seedsAlong(from a: CGPoint, to b: CGPoint, inward: CGFloat) {
            let dist = hypot(b.x - a.x, b.y - a.y)
            var t: CGFloat = .random(in: 0...40)
            while t < dist {
                let p = CGPoint(x: a.x + (b.x - a.x) * t / dist, y: a.y + (b.y - a.y) * t / dist)
                fern(p, inward + .random(in: -0.7...0.7), .random(in: 45...150), .random(in: 0.8...1.2), 0)
                t += .random(in: 30...65)
            }
        }
        seedsAlong(from: CGPoint(x: 0, y: 0), to: CGPoint(x: W, y: 0), inward: .pi / 2)
        seedsAlong(from: CGPoint(x: 0, y: top), to: CGPoint(x: W, y: top), inward: -.pi / 2)
        seedsAlong(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: top), inward: 0)
        seedsAlong(from: CGPoint(x: W, y: 0), to: CGPoint(x: W, y: top), inward: .pi)

        // Шестилучевые звёздочки-кристаллики, гуще у краёв.
        for _ in 0..<Int(W * CGFloat(h) / 3500) {
            let edge = CGFloat.random(in: 0...1)
            let off = pow(CGFloat.random(in: 0...1), 2) * 260
            let p: CGPoint
            switch Int(edge * 4) {
            case 0: p = CGPoint(x: .random(in: 0...W), y: off)
            case 1: p = CGPoint(x: .random(in: 0...W), y: top - off)
            case 2: p = CGPoint(x: off, y: .random(in: 0...top))
            default: p = CGPoint(x: W - off, y: .random(in: 0...top))
            }
            let r = CGFloat.random(in: 1.5...4.5)
            let rot = CGFloat.random(in: 0...(.pi / 3))
            let alpha = CGFloat.random(in: 0.35...0.8)
            for k in 0..<3 {
                let a = rot + CGFloat(k) * .pi / 3
                stroke(CGPoint(x: p.x - cos(a) * r, y: p.y - sin(a) * r), CGPoint(x: p.x + cos(a) * r, y: p.y + sin(a) * r), 0.7, alpha)
            }
        }
        return ctx.makeImage()!
    }
}
