import AppKit
import SpriteKit

final class HolidayDecor {
    let node = SKNode()
    private let placements = SKNode()
    private var sprites: [UUID: SKSpriteNode] = [:]
    private var houses: [(PlacedDecor, CGRect)] = []
    private var gifts: [CGRect] = []
    private static var textures: [DecorArtwork.Key: SKTexture] = [:]
    private(set) var hearths: [CGRect] = []
    private var trees: [SKSpriteNode] = []
    private var appearances: [UUID: DecorStyle] = [:]
    var layoutDirty = true
    private var renderedRevision = -1
    private var nextHeart: TimeInterval = 0


    init() {
        node.zPosition = 1.75
        node.addChild(placements)
    }

    private func symbol(_ text: String, at point: CGPoint, size: CGFloat, in layer: SKNode) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontSize = size
        label.verticalAlignmentMode = .center
        label.position = point
        layer.addChild(label)
        return label
    }

    func update(t: TimeInterval, screen: CGRect, wins: [WinInfo]) {
        let store = DecorStore.shared
        if renderedRevision != store.revision || layoutDirty {
            renderedRevision = store.revision
            layoutDirty = false
            sync(screen: screen, wins: wins, items: store.items)
        }
        if t >= nextHeart, let gift = gifts.randomElement() {
            nextHeart = t + Double.random(in: 3...7)
            emitHeart(from: gift)
        }
    }

    private static func texture(_ kind: DecorKind, _ style: DecorStyle, _ frame: Int, pictureID: UUID? = nil) -> SKTexture {
        let key = DecorArtwork.Key(kind: kind, style: style, frame: frame, pictureID: pictureID)
        if let texture = textures[key] { return texture }
        let texture = SKTexture(image: DecorArtwork.image(kind, style, frame: frame, pictureID: pictureID))
        texture.filteringMode = style == .pixel ? .nearest : .linear
        textures[key] = texture
        return texture
    }

    private func sync(screen: CGRect, wins: [WinInfo], items: [PlacedDecor]) {
        let ids = Set(items.map(\.id))
        for id in Array(sprites.keys) where !ids.contains(id) {
            sprites.removeValue(forKey: id)?.removeFromParent()
            appearances.removeValue(forKey: id)
        }
        hearths.removeAll(keepingCapacity: true)
        trees.removeAll(keepingCapacity: true)
        houses.removeAll(keepingCapacity: true)
        gifts.removeAll(keepingCapacity: true)
        for item in items {
            guard let point = item.position(in: wins) else {
                sprites[item.id]?.isHidden = true
                continue
            }
            let scale = item.displayScale
            let region = item.kind.isGarland
                ? CGRect(x: min(point.x, point.x + item.vector.x), y: min(point.y, point.y + item.vector.y),
                         width: abs(item.vector.x) + 1, height: abs(item.vector.y) + 1).insetBy(dx: -72 * scale, dy: -72 * scale)
                : CGRect(x: point.x - 110 * scale, y: point.y - 110 * scale, width: 220 * scale, height: 220 * scale)
            guard screen.intersects(region) else {
                sprites[item.id]?.isHidden = true
                continue
            }
            let sprite: SKSpriteNode
            if let existing = sprites[item.id], appearances[item.id] == item.appearance {
                sprite = existing
            } else {
                sprites[item.id]?.removeFromParent()
                let first = Self.texture(item.kind, item.appearance, 0, pictureID: item.pictureID)
                sprite = SKSpriteNode(texture: first)
                if item.kind.isAnimated {
                    let frames = [first] + (1..<6).map { Self.texture(item.kind, item.appearance, $0) }
                    sprite.run(.repeatForever(.animate(with: frames + frames.dropFirst().dropLast().reversed(),
                                                        timePerFrame: 0.14)), withKey: "lights")
                }
                appearances[item.id] = item.appearance
                sprites[item.id] = sprite
                placements.addChild(sprite)
            }
            sprite.isHidden = false
            sprite.position = CGPoint(x: point.x - screen.minX, y: point.y - screen.minY)
            if item.kind.isGarland {
                let vector = item.vector
                let length = hypot(vector.x, vector.y)
                let count = max(1, min(100, Int((length / (item.wavelength ?? 220)).rounded())))
                let width = length / CGFloat(count)
                sprite.anchorPoint = CGPoint(x: 0, y: item.kind == .wave ? 50.0 / 72 : 64.0 / 72)
                if vector.x < 0 {
                    sprite.position.x += vector.x
                    sprite.position.y += vector.y
                    sprite.zRotation = atan2(-vector.y, -vector.x)
                } else { sprite.zRotation = atan2(vector.y, vector.x) }
                sprite.size = CGSize(width: width, height: 72 * scale)
                while sprite.children.count < count - 1 {
                    let segment = SKSpriteNode(texture: sprite.texture)
                    segment.anchorPoint = sprite.anchorPoint
                    if let animation = sprite.action(forKey: "lights") { segment.run(animation, withKey: "lights") }
                    sprite.addChild(segment)
                }
                while sprite.children.count > count - 1 { sprite.children.last?.removeFromParent() }
                for (i, child) in sprite.children.enumerated() {
                    guard let segment = child as? SKSpriteNode else { continue }
                    segment.position.x = CGFloat(i + 1) * width
                    segment.size = sprite.size
                }
            } else {
                sprite.size = item.kind.isAnimated ? DecorArtwork.image(item.kind, item.appearance).size : CGSize(width: 100, height: 100)
                sprite.setScale(scale)
            }
            if item.kind == .pairedHouse {
                houses.append((item, sprite.frame))
                let light = sprite.childNode(withName: "windowLight")
                if item.lit == true && light == nil {
                    let lamp = SKShapeNode(rectOf: CGSize(width: 12, height: 14), cornerRadius: 2)
                    lamp.name = "windowLight"
                    lamp.position = CGPoint(x: 11, y: -6)
                    lamp.fillColor = .systemYellow
                    lamp.strokeColor = .systemOrange
                    lamp.glowWidth = 7
                    sprite.addChild(lamp)
                } else if item.lit != true { light?.removeFromParent() }
            }
            if item.kind.isGift { gifts.append(sprite.frame.insetBy(dx: 6 * scale, dy: 6 * scale)) }
            if item.kind == .fireplace {
                hearths.append(sprite.frame.insetBy(dx: 25 * scale, dy: 20 * scale))
            }
            if item.kind == .tree {
                trees.append(sprite)
                for dx in [-0.33, 0.20, 0.36] {
                    gifts.append(CGRect(x: sprite.position.x + (dx * 175 - 15) * scale,
                                        y: sprite.frame.minY + 9 * scale, width: 30 * scale, height: 25 * scale))
                }
            }
        }
    }

    func nudgeTree(at point: CGPoint, fromRight: Bool) -> Bool {
        guard let tree = trees.first(where: { $0.contains(point) && $0.action(forKey: "sway") == nil }) else { return false }
        let angle: CGFloat = fromRight ? -0.04 : 0.04
        tree.run(.sequence([.rotate(toAngle: angle, duration: 0.12), .rotate(toAngle: -angle/2, duration: 0.17),
                            .rotate(toAngle: 0, duration: 0.22)]), withKey: "sway")
        return true
    }

    private func emitHeart(from gift: CGRect) {
        let heart = symbol("♥", at: CGPoint(x: gift.midX, y: gift.maxY), size: 23, in: node)
        heart.zPosition = 20
        heart.fontColor = NSColor(srgbRed: 0.84, green: 0.37, blue: 0.32, alpha: 1)
        heart.run(.sequence([.moveBy(x: -5, y: 22, duration: 0.45),
                             .group([.moveBy(x: 13, y: 33, duration: 1.1), .fadeOut(withDuration: 1.1)]),
                             .removeFromParent()]))
    }

    func click(at point: CGPoint, screen: CGRect) {
        let local = CGPoint(x: point.x - screen.minX, y: point.y - screen.minY)
        if let (house, _) = houses.last(where: { $0.1.contains(local) }) {
            DecorStore.shared.togglePartner(of: house)
            return
        }
        guard let gift = gifts.last(where: { $0.contains(local) }) else { return }
        emitHeart(from: gift)
        guard Settings.shared.giftUnlocked else { return }
        node.childNode(withName: "compliment")?.removeFromParent()
        let message = symbol(GiftCompliments.next(), at: .zero, size: 16, in: node)
        message.zPosition = 21
        message.name = "compliment"
        message.fontName = "HelveticaNeue-Medium"
        message.fontColor = NSColor(srgbRed: 1, green: 0.96, blue: 0.89, alpha: 1)
        let bounds = message.frame.insetBy(dx: -12, dy: -7)
        message.position = CGPoint(x: min(max(gift.midX, -bounds.minX), screen.width - bounds.maxX),
                                   y: min(max(gift.maxY + 28, -bounds.minY), screen.height - bounds.maxY))
        let plate = SKShapeNode(rect: bounds, cornerRadius: 10)
        plate.fillColor = NSColor(srgbRed: 0.10, green: 0.16, blue: 0.15, alpha: 0.96)
        plate.strokeColor = NSColor(srgbRed: 0.87, green: 0.67, blue: 0.45, alpha: 1)
        plate.zPosition = -1
        message.addChild(plate)
        message.run(.sequence([.wait(forDuration: 3), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }
}
