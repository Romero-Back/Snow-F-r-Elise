import AppKit
import CoreImage
import SpriteKit

enum DecorStyle: String, CaseIterable, Codable {
    case classic, cartoon, vintage, pixel, paper
    var title: String {
        switch self {
        case .classic: return tr("Классика", "Classic")
        case .cartoon: return tr("Мульт", "Cartoon")
        case .vintage: return tr("Винтаж", "Vintage")
        case .pixel: return tr("Пиксель", "Pixel")
        case .paper: return tr("Бумага", "Paper")
        }
    }
}

/// Each frame is drawn once and shared by the palette and every display.
enum DecorArtwork {
    struct Key: Hashable {
        let kind: DecorKind
        let style: DecorStyle
        let frame: Int
        var pictureID: UUID? = nil
    }
    private static var images = [Key: NSImage]()
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static let renderer = SKView(frame: CGRect(x: 0, y: 0, width: 256, height: 256))
    private static let tree = ChristmasTree(height: 175, lights: .multicolor, gifts: true)
    private static let fire = Fireplace()
    private static let lights = Garland(width: 240, topY: 0, style: .multicolor)
    private static let waves = Garland(width: 240, topY: 0, style: .warm, depth: 14, wave: true)
    private static let curtain = Garland(width: 240, topY: 0, style: .warm, curtain: true)
    private static let rows = Garland(width: 240, topY: 0, style: .multicolor, double: true)

    static func image(_ kind: DecorKind, _ style: DecorStyle, frame: Int = 0, pictureID: UUID? = nil) -> NSImage {
        let key = Key(kind: kind, style: style, frame: frame, pictureID: pictureID)
        if let cached = images[key] { return cached }
        let result: NSImage
        if style == .classic {
            if kind.isAnimated {
                let node: SKNode
                let crop: CGRect
                switch kind {
                case .tree:
                    tree.update(dt: 0.16, mode: .twinkle)
                    node = tree.node
                    crop = CGRect(x: -100, y: -10, width: 200, height: 200)
                case .fireplace:
                    fire.update(dt: 0.16)
                    node = fire.node
                    crop = CGRect(x: -105, y: -20, width: 210, height: 167)
                default:
                    let garland = kind == .wave ? waves : (kind == .doubleLights ? rows : (kind == .curtain ? curtain : lights))
                    garland.update(t: CGFloat(frame) * 0.32, mode: .twinkle)
                    node = garland.node
                    crop = CGRect(x: 0, y: -64, width: 240, height: 72)
                }
                if let texture = renderer.texture(from: node, crop: crop) {
                    result = NSImage(cgImage: texture.cgImage(), size: crop.size)
                } else { return NSImage(size: crop.size) }
            } else if let pictureID, let source = DecorLibrary.shared.load(pictureID) {
                let side = max(source.size.width, source.size.height)
                result = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
                    source.draw(at: CGPoint(x: (side - source.size.width) / 2, y: (side - source.size.height) / 2),
                                from: .zero, operation: .sourceOver, fraction: 1)
                    return true
                }
            } else { result = kind.artwork }
        } else {
            let original = image(kind, .classic, frame: frame, pictureID: pictureID)
            guard let cg = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return original }
            let source = CIImage(cgImage: cg)
            let filtered: CIImage
            switch style {
            case .cartoon:
                filtered = source.applyingFilter("CIMedianFilter")
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.8])
                    .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.24,
                                                                   kCIInputContrastKey: 1.06])
                    .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 7])
            case .vintage:
                filtered = source.applyingFilter("CIPhotoEffectTransfer")
                    .applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.45])
            case .pixel:
                filtered = source.applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(4, source.extent.width / 32)])
                    .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 6])
            case .paper:
                filtered = source.applyingFilter("CICrystallize", parameters: ["inputRadius": max(4, source.extent.width / 24)])
                    .applyingFilter("CIColorPosterize", parameters: ["inputLevels": 5])
                    .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.74])
            case .classic: return original
            }
            let masked = filtered.applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: source])
            guard let output = context.createCGImage(masked, from: source.extent) else { return original }
            result = NSImage(cgImage: output, size: original.size)
        }
        images[key] = result
        return result
    }
}
