import AppKit
import ImageIO

enum WinterEvening {
    private static let original: [DecorKind] = [
        .eveningLamp, .eveningCabin, .eveningRobin,
        .eveningLetters, .eveningCocoa, .eveningSkates,
        .eveningFir, .eveningMoon, .eveningBauble
    ]
    private static let hearth: [DecorKind] = [
        .eveningWindow, .eveningSleepingFox, .eveningMittens,
        .eveningStove, .eveningOrangeSprig, .eveningVillageGlobe
    ]

    static let catalog = original + hearth
    static let artwork = loadAtlas("winter-evening", kinds: original)
        .merging(loadAtlas("winter-evening-hearth", kinds: hearth)) { image, _ in image }

    private static func loadAtlas(_ name: String, kinds: [DecorKind]) -> [DecorKind: NSImage] {
        let columns = 3
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
              atlas.width.isMultiple(of: columns) else { return [:] }
        let tileSize = atlas.width / columns
        guard atlas.height == tileSize * (kinds.count / columns) else { return [:] }
        return Dictionary(uniqueKeysWithValues: kinds.enumerated().compactMap { index, kind in
            let rect = CGRect(x: index % columns * tileSize, y: index / columns * tileSize,
                              width: tileSize, height: tileSize)
            guard let tile = atlas.cropping(to: rect) else { return nil }
            return (kind, NSImage(cgImage: tile, size: rect.size))
        })
    }
}

enum WinterPalette {
    static let background = adaptive(light: 0xf0e8da, dark: 0x182524)
    static let gradientEnd = adaptive(light: 0xe5ddd0, dark: 0x111918)
    static let panel = adaptive(light: 0xf8f3e8, dark: 0x202d2a)
    static let card = adaptive(light: 0xfffaf0, dark: 0x293733)
    static let selection = adaptive(light: 0xf3e2c7, dark: 0x403b2b)
    static let line = adaptive(light: 0xd8caba, dark: 0x43534d)
    static let accent = adaptive(light: 0x8a5224, dark: 0xe8b87d)
    static let secondary = adaptive(light: 0x655a4f, dark: 0xb8c7bf)

    static func heading(_ size: CGFloat) -> NSFont {
        NSFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
    }
}
