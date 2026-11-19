import AppKit
import ImageIO
import UniformTypeIdentifiers

struct SavedDecorScene: Codable {
    let name: String
    let items: [PlacedDecor]
}

struct DecorPicture: Codable {
    let id: UUID
    let title: String
}

final class DecorLibrary {
    static let shared = DecorLibrary()
    private let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Für Elise/Pictures", isDirectory: true)
    private let key = "decorPictureLibrary"
    private(set) var pictures: [DecorPicture]
    private init() {
        pictures = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([DecorPicture].self, from: $0) } ?? []
    }

    func load(_ id: UUID) -> NSImage? {
        NSImage(contentsOf: folder.appendingPathComponent(id.uuidString + ".png"))
    }

    func add(_ url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source), [UTType.png.identifier, UTType.jpeg.identifier].contains(type as String),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024
              ] as CFDictionary),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileReadCorruptFile) }
        let picture = DecorPicture(id: UUID(), title: url.deletingPathExtension().lastPathComponent)
        let manifest = try JSONEncoder().encode([picture] + pictures)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appendingPathComponent(picture.id.uuidString + ".png"), options: .atomic)
        pictures.insert(picture, at: 0)
        UserDefaults.standard.set(manifest, forKey: key)
    }
}

final class PictureDropView: NSView {
    var onImport: (([URL]) -> Void)?
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else { return false }
        onImport?(urls)
        return true
    }
}
