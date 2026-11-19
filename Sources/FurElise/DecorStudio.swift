import AppKit
import ImageIO
import SpriteKit
import UniformTypeIdentifiers

enum DecorKind: String, CaseIterable, Codable {
    case gift, bear, ruby, gold, tinsel
    case sapphire, emerald, pearl, star, snowflake
    case candy, bell, gingerbread, snowman, wreath
    case candle, mitten, silver, violet, rose
    case pinkGift, blueGift, kraftGift, rabbit, penguin
    case fox, horse, owl, cardinal, deer
    case nutcracker, santa, sleigh, train, house
    case globe, lantern, fir, holly, pinecone
    case stocking, cap, scarf, bow, cookie
    case peppermint, skis, jingle, moon, icicle

    case picture, pairedHouse
    case tree, fireplace, lights, wave, doubleLights, curtain

    var isGarland: Bool { self == .lights || self == .wave || self == .doubleLights || self == .curtain }
    var isAnimated: Bool { isGarland || self == .tree || self == .fireplace }
    private static var atlasKinds: [Self] { allCases.filter { !$0.isAnimated && $0 != .picture && $0 != .pairedHouse } }
    static var catalog: [Self] { [.pairedHouse, .tree, .fireplace, .lights, .wave, .doubleLights, .curtain] + atlasKinds }

    var title: String {
        switch self {
        case .picture: return tr("Своя картинка", "Custom picture")
        case .pairedHouse: return tr("Парные домики", "Paired houses")
        case .curtain: return tr("Световая штора", "Fairy light curtain")
        case .tree: return tr("Праздничная ёлка", "Christmas tree")
        case .fireplace: return tr("Камин", "Fireplace")
        case .lights: return tr("Цветные дуги", "Festoon lights")
        case .wave: return tr("Золотая волна", "Golden wave")
        case .doubleLights: return tr("Двойная гирлянда", "Double garland")
        case .gift: return tr("Бархатный подарок", "Velvet gift")
        case .bear: return tr("Мишка в шарфе", "Teddy with scarf")
        case .ruby: return tr("Рубиновый шар", "Ruby bauble")
        case .gold: return tr("Золотой шар", "Gold bauble")
        case .tinsel: return tr("Хвойная мишура", "Pine tinsel")
        case .sapphire: return tr("Сапфировый шар", "Sapphire bauble")
        case .emerald: return tr("Изумрудный шар", "Emerald bauble")
        case .pearl: return tr("Жемчужный шар", "Pearl bauble")
        case .star: return tr("Золотая звезда", "Gold star")
        case .snowflake: return tr("Хрустальная снежинка", "Crystal snowflake")
        case .candy: return tr("Леденец-трость", "Candy cane")
        case .bell: return tr("Латунный колокол", "Brass bell")
        case .gingerbread: return tr("Имбирный пряник", "Gingerbread man")
        case .snowman: return tr("Цилиндр снеговика", "Snowman hat")
        case .wreath: return tr("Венок с ягодами", "Berry wreath")
        case .candle: return tr("Восковая свеча", "Wax candle")
        case .mitten: return tr("Вязаная варежка", "Knit mitten")
        case .silver: return tr("Серебряный шар", "Silver bauble")
        case .violet: return tr("Фиолетовый шар", "Violet bauble")
        case .rose: return tr("Розовый шар", "Rose bauble")
        case .pinkGift: return tr("Розовый подарок", "Pink gift")
        case .blueGift: return tr("Синий подарок", "Blue gift")
        case .kraftGift: return tr("Подарок с ягодами", "Kraft gift")
        case .rabbit: return tr("Плюшевый кролик", "Plush rabbit")
        case .penguin: return tr("Пингвин в шарфе", "Penguin with scarf")
        case .fox: return tr("Плюшевая лиса", "Plush fox")
        case .horse: return tr("Лошадка-качалка", "Rocking horse")
        case .owl: return tr("Белая сова", "Snowy owl")
        case .cardinal: return tr("Красный кардинал", "Red cardinal")
        case .deer: return tr("Оленёнок", "Fawn")
        case .nutcracker: return tr("Щелкунчик", "Nutcracker")
        case .santa: return tr("Дед Мороз", "Santa")
        case .sleigh: return tr("Красные сани", "Red sleigh")
        case .train: return tr("Игрушечный поезд", "Toy train")
        case .house: return tr("Пряничный домик", "Gingerbread house")
        case .globe: return tr("Снежный шар", "Snow globe")
        case .lantern: return tr("Зимний фонарь", "Winter lantern")
        case .fir: return tr("Заснеженная ёлка", "Snowy fir")
        case .holly: return tr("Ветка падуба", "Holly sprig")
        case .pinecone: return tr("Сосновая шишка", "Pinecone")
        case .stocking: return tr("Новогодний чулок", "Christmas stocking")
        case .cap: return tr("Вязаная шапка", "Knit hat")
        case .scarf: return tr("Зелёный шарф", "Green scarf")
        case .bow: return tr("Красный бант", "Red bow")
        case .cookie: return tr("Печенье-звезда", "Star cookie")
        case .peppermint: return tr("Мятная конфета", "Peppermint candy")
        case .skis: return tr("Зимние лыжи", "Winter skis")
        case .jingle: return tr("Связка бубенчиков", "Jingle bells")
        case .moon: return tr("Серебряный месяц", "Silver crescent")
        case .icicle: return tr("Золотая сосулька", "Gold icicle")
        }
    }

    var isGift: Bool {
        [.gift, .pinkGift, .blueGift, .kraftGift].contains(self)
    }

    var artwork: NSImage { Self.images[self == .pairedHouse ? .house : self] ?? NSImage(size: NSSize(width: 100, height: 100)) }

    private static let images: [DecorKind: NSImage] = {
        guard let url = Bundle.main.url(forResource: "decor-catalog", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [:] }
        // Cell boundaries follow the gaps between the rendered objects.
        let rows = [0, 177, 359, 532, 708, 887]
        let columns = [
            [0, 190, 354, 532, 709, 887, 1064, 1241, 1415, 1596, 1774],
            [0, 177, 355, 532, 709, 887, 1064, 1241, 1419, 1596, 1774],
            [0, 179, 358, 532, 709, 887, 1064, 1241, 1419, 1596, 1774],
            [0, 177, 354, 532, 709, 887, 1064, 1241, 1418, 1596, 1774],
            [0, 177, 354, 532, 709, 887, 1064, 1241, 1419, 1596, 1774],
        ]
        guard atlas.width == 1774, atlas.height == 887 else { return [:] }
        return Dictionary(uniqueKeysWithValues: atlasKinds.enumerated().compactMap { index, kind in
            let column = index % 10
            let row = index / 10
            let x = columns[row][column]
            let y = rows[row]
            let width = columns[row][column + 1] - x
            let height = rows[row + 1] - y
            guard let tile = atlas.cropping(to: CGRect(x: x, y: y, width: width, height: height)) else { return nil }
            let edge = CGFloat(max(width, height))
            let frame = CGRect(x: (edge - CGFloat(width)) / 2, y: (edge - CGFloat(height)) / 2,
                               width: CGFloat(width), height: CGFloat(height))
            let image = NSImage(cgImage: tile, size: frame.size)
            return (kind, NSImage(size: CGSize(width: edge, height: edge), flipped: false) { _ in
                image.draw(in: frame)
                return true
            })
        })
    }()
}

struct PlacedDecor: Codable, Equatable {
    let id: UUID
    let kind: DecorKind
    var x: CGFloat
    var y: CGFloat
    var pictureID: UUID?
    var pairID: UUID?
    var lit: Bool?
    var anchor: DecorAnchor?
    var scale: CGFloat?
    var style: DecorStyle?
    // The first hook is the placement point, the second moves with its window.
    var span: CGPoint?
    var wavelength: CGFloat?
    var vector: CGPoint { span ?? CGPoint(x: 240, y: 0) }
    var appearance: DecorStyle { style ?? .classic }

    func position(in wins: [WinInfo]) -> CGPoint? {
        guard let anchor, anchor.windowID == -2 || anchor.session == DecorStore.shared.session else { return CGPoint(x: x, y: y) }
        guard let index = wins.firstIndex(where: { $0.id == anchor.windowID }) else { return nil }
        let frame = wins[index].frame
        let p = CGPoint(x: frame.minX + min(anchor.xFromLeft, frame.width),
                        y: frame.maxY - min(anchor.yFromTop, frame.height))
        return wins[..<index].contains { $0.frame.contains(p) } ? nil : p
    }
    var displayScale: CGFloat { max(0.35, min(2.5, scale ?? 1)) }
}

struct DecorAnchor: Codable, Equatable {
    let windowID: Int
    let xFromLeft: CGFloat
    let yFromTop: CGFloat
    let session: UUID
}

final class DecorStore {
    static let shared = DecorStore()
    private let key = "placedHolidayDecor"
    private(set) var items: [PlacedDecor] = []
    private(set) var revision = 0
    let session = UUID()

    private(set) var scenes: [SavedDecorScene] = []
    private let sceneKey = "holidayDecorScenes"

    func saveScene(named name: String) {
        let scene = SavedDecorScene(name: name, items: items)
        scenes.removeAll { $0.name == name }
        scenes.append(scene)
        UserDefaults.standard.set(try? JSONEncoder().encode(scenes), forKey: sceneKey)
    }

    func restore(_ scene: SavedDecorScene) {
        items = scene.items
        save()
    }

    func togglePartner(of item: PlacedDecor) {
        guard let pair = item.pairID,
              let i = items.firstIndex(where: { $0.pairID == pair && $0.id != item.id }) else { return }
        items[i].lit = !(items[i].lit ?? false)
        save()
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: sceneKey) {
            scenes = (try? JSONDecoder().decode([SavedDecorScene].self, from: data)) ?? []
        }
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([PlacedDecor].self, from: data) {
            items = saved
        }
    }

    @discardableResult func place(_ kind: DecorKind, style: DecorStyle, id: UUID?, pictureID: UUID? = nil, at point: CGPoint, window: WinInfo?) -> UUID? {
        let anchor = window.map {
            DecorAnchor(windowID: $0.id, xFromLeft: point.x - $0.frame.minX,
                        yFromTop: $0.frame.maxY - point.y, session: session)
        }
        let result = id ?? UUID()
        if let id {
            guard let i = items.firstIndex(where: { $0.id == id }) else { return nil }
            items[i].x = point.x
            items[i].y = point.y
            items[i].anchor = anchor
        } else {
            guard items.count + (kind == .pairedHouse ? 2 : 1) <= 150 else { return nil }
            var initialSpan: CGPoint?
            if kind.isGarland, let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
                initialSpan = CGPoint(x: screen.frame.maxX - point.x > 250 ? 240 : -240, y: 0)
            }
            let pair = kind == .pairedHouse ? UUID() : nil
            if let pair {
                let right = NSScreen.screens.first(where: { $0.frame.contains(point) })?.frame.maxX ?? point.x + 200
                let dx: CGFloat = right - point.x > 165 ? 116 : -116
                let partnerAnchor = window.map { DecorAnchor(windowID: $0.id, xFromLeft: point.x + dx - $0.frame.minX,
                                                              yFromTop: $0.frame.maxY - point.y, session: session) }
                items.append(PlacedDecor(id: UUID(), kind: kind, x: point.x + dx, y: point.y,
                                         pairID: pair, anchor: partnerAnchor, style: style))
            }
            items.append(PlacedDecor(id: result, kind: kind, x: point.x, y: point.y, pictureID: pictureID, pairID: pair, anchor: anchor, style: style, span: initialSpan))
        }
        save()
        return result
    }

    func restyle(_ id: UUID, to style: DecorStyle) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].style = style
        save()
    }

    func moveHook(_ id: UUID, first: Bool, to point: CGPoint, wins: [WinInfo], finished: Bool) {
        guard let i = items.firstIndex(where: { $0.id == id }), let start = items[i].position(in: wins) else { return }
        let old = items[i].vector
        let dx = point.x - start.x, dy = point.y - start.y
        let vector = first ? CGPoint(x: old.x - dx, y: old.y - dy) : CGPoint(x: dx, y: dy)
        if hypot(vector.x, vector.y) >= 12 {
            if first {
                items[i].x = point.x
                items[i].y = point.y
                if let a = items[i].anchor, a.session == session {
                    items[i].anchor = DecorAnchor(windowID: a.windowID, xFromLeft: a.xFromLeft + dx,
                                                  yFromTop: a.yFromTop - dy, session: session)
                }
            }
            items[i].span = vector
            revision += 1
        }
        if finished { save() }
    }

    func changeWavelength(_ id: UUID, to value: CGFloat) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].wavelength = value
        save()
    }

    func resize(_ id: UUID, to scale: CGFloat) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        if let a = items[i].anchor, a.windowID == -2 {
            let offset = (items[i].kind == .tree ? 85.0 : 64.0) * scale
            items[i].anchor = DecorAnchor(windowID: -2, xFromLeft: a.xFromLeft, yFromTop: -offset, session: session)
        }
        items[i].scale = scale
        save()
    }

    func remove(_ id: UUID) {
        let pair = items.first { $0.id == id }?.pairID
        items.removeAll { $0.id == id || (pair != nil && $0.pairID == pair) }
        save()
    }

    private func save() {
        revision += 1
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: key)
    }
}

final class DecorStudio {
    private weak var placedScroll: NSScrollView?
    private weak var catalogScroll: NSScrollView?
    private var selectedKind = DecorKind.tree
    private var selectedPicture: UUID?
    private var selectedID: UUID?
    private var styles: [DecorKind: DecorStyle] = [:]
    private var handles: [NSPanel] = []
    private var windows: [WinInfo] = []
    private var visibleScreens: [CGRect] = []
    private var selectedStyle: DecorStyle {
        DecorStore.shared.items.first { $0.id == selectedID }?.appearance ?? styles[selectedKind] ?? .classic
    }

    private var attachToWindow = false
    private let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 864, height: 613),
                                styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
    private let preview = NSPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)

    init() {
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.center()
        for first in [true, false] {
            let handle = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 22, height: 22),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            handle.isOpaque = false
            handle.backgroundColor = .clear
            handle.level = .popUpMenu
            let grip = HookGrip(frame: handle.frame)
            grip.onMove = { [weak self] point, finished in
                guard let self, let id = self.selectedID else { return }
                DecorStore.shared.moveHook(id, first: first, to: point, wins: self.windows, finished: finished)
                self.refreshHandles()
            }
            handle.contentView = grip
            panel.addChildWindow(handle, ordered: .below)
            handles.append(handle)
            handle.orderOut(nil)
        }
        preview.backgroundColor = .clear
        preview.isOpaque = false
        preview.hasShadow = false
        preview.ignoresMouseEvents = true
        preview.level = .popUpMenu
        preview.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func show() {
        rebuild()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        refreshHandles()
    }

    private func rebuild() {
        panel.title = tr("Мастерская украшений", "Decoration studio")
        let content = PictureDropView()
        content.registerForDraggedTypes([.fileURL])
        content.onImport = { [weak self] in self?.importPictures($0) }
        let add = NSButton(title: tr("Свои картинки…", "Import pictures…"), target: self, action: #selector(choosePictures))
        add.frame = NSRect(x: 330, y: 545, width: 150, height: 28)
        content.addSubview(add)
        let scenes = NSPopUpButton(frame: NSRect(x: 494, y: 575, width: 354, height: 30), pullsDown: true)
        scenes.addItem(withTitle: tr("Сцены", "Scenes"))
        scenes.addItem(withTitle: tr("Сохранить текущую сцену…", "Save current scene…"))
        scenes.lastItem?.target = self
        scenes.lastItem?.action = #selector(saveScene)
        for scene in DecorStore.shared.scenes {
            scenes.menu?.addItem(withTitle: scene.name, action: #selector(loadScene(_:)), keyEquivalent: "").target = self
        }
        content.addSubview(scenes)
        let title = NSTextField(labelWithString: tr("Перетащи украшение на экран", "Drag a decoration onto the screen"))
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.frame = NSRect(x: 16, y: 579, width: 352, height: 23)
        content.addSubview(title)

        let attach = NSButton(checkboxWithTitle: tr("Крепить к окну под курсором", "Attach to window under pointer"),
                              target: self, action: #selector(toggleAttachment(_:)))
        attach.state = attachToWindow ? .on : .off
        attach.toolTip = tr("Отпусти над окном, чтобы украшение двигалось вместе с ним.",
                            "Drop onto a window to move the decoration with it.")
        attach.frame = NSRect(x: 16, y: 547, width: 352, height: 24)
        content.addSubview(attach)

        let catalog = NSScrollView(frame: NSRect(x: 16, y: 88, width: 464, height: 454))
        catalog.hasVerticalScroller = true
        let columns = 4
        let entries: [(DecorKind, UUID?)] = DecorLibrary.shared.pictures.map { (.picture, $0.id) } + DecorKind.catalog.map { ($0, nil) }
        let rows = (entries.count + columns - 1) / columns
        let catalogHeight = CGFloat(rows) * 76
        let grid = NSView(frame: NSRect(x: 0, y: 0, width: 448, height: catalogHeight))
        for (i, entry) in entries.enumerated() {
            let tile = makeTile(entry.0, id: nil, pictureID: entry.1)
            tile.frame = NSRect(x: (i % columns) * 112, y: (rows - 1 - i / columns) * 76, width: 108, height: 71)
            grid.addSubview(tile)
        }
        catalog.documentView = grid
        let catalogY = catalogScroll?.contentView.bounds.minY ?? max(0, catalogHeight - catalog.contentSize.height)
        catalog.contentView.scroll(to: CGPoint(x: 0, y: catalogY))
        catalogScroll = catalog
        content.addSubview(catalog)

        let inspector = NSTextField(labelWithString: selectedKind.title)
        if selectedKind.isGarland, selectedID != nil {
            inspector.stringValue += tr(" · Тяни за концы на экране", " · Drag either hook on screen")
        }
        inspector.font = .systemFont(ofSize: 12, weight: .semibold)
        inspector.frame = NSRect(x: 16, y: 56, width: 464, height: 19)
        content.addSubview(inspector)
        let choices = NSSegmentedControl(labels: DecorStyle.allCases.map(\.title), trackingMode: .selectOne,
                                         target: self, action: #selector(changeStyle(_:)))
        choices.selectedSegment = DecorStyle.allCases.firstIndex(of: selectedStyle) ?? 0
        choices.frame = NSRect(x: 12, y: 20, width: 464, height: 28)
        content.addSubview(choices)

        let heading = NSTextField(labelWithString: tr("Расставленные украшения", "Placed decorations"))
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        heading.frame = NSRect(x: 496, y: 547, width: 352, height: 22)
        content.addSubview(heading)
        let scroll = NSScrollView(frame: NSRect(x: 496, y: 16, width: 352, height: 526))
        scroll.hasVerticalScroller = true
        let items = DecorStore.shared.items
        let documentHeight = max(scroll.contentSize.height, items.reduce(CGFloat(0)) { $0 + ($1.kind.isGarland ? 104 : 70) })
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 335, height: documentHeight))
        var top = documentHeight
        for item in items {
            let y = top - 70
            top = y
            if item.kind.isGarland {
                top -= 34
                let label = NSTextField(labelWithString: tr("Шаг ламп", "Light spacing"))
                label.font = .systemFont(ofSize: 11)
                label.frame = NSRect(x: 6, y: top + 8, width: 90, height: 16)
                document.addSubview(label)
                let spacing = DecorSizeSlider(value: item.wavelength ?? 220, minValue: 72, maxValue: 400,
                                              target: self, action: #selector(changeSpacing(_:)))
                spacing.itemID = item.id
                spacing.isContinuous = false
                spacing.setAccessibilityLabel(label.stringValue)
                spacing.frame = NSRect(x: 101, y: top + 7, width: 220, height: 20)
                document.addSubview(spacing)
            }
            let tile = makeTile(item.kind, id: item.id, pictureID: item.pictureID, compact: true)
            if item.anchor?.windowID == -2 {
                tile.caption += "  ·  Dock"
            } else if item.anchor?.session == DecorStore.shared.session {
                tile.caption += tr("  ·  На окне", "  ·  On window")
            }
            tile.frame = NSRect(x: 0, y: y + 24, width: 290, height: 44)
            document.addSubview(tile)
            let button = DecorRemoveButton(title: "×", target: self, action: #selector(remove(_:)))
            button.id = item.id
            button.toolTip = item.pairID == nil ? tr("Удалить", "Remove") : tr("Удалить пару", "Remove pair")
            button.frame = NSRect(x: 294, y: y + 33, width: 35, height: 28)
            document.addSubview(button)
            let sizeLabel = NSTextField(labelWithString: "\(Int((item.displayScale * 100).rounded()))%")
            sizeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            sizeLabel.alignment = .right
            sizeLabel.frame = NSRect(x: 276, y: y + 3, width: 48, height: 17)
            document.addSubview(sizeLabel)
            let slider = DecorSizeSlider(value: Double(item.displayScale), minValue: 0.35, maxValue: 2.5,
                                         target: self, action: #selector(resize(_:)))
            slider.itemID = item.id
            slider.valueLabel = sizeLabel
            slider.isContinuous = false
            slider.controlSize = .small
            slider.toolTip = item.kind.isGarland ? tr("Глубина провиса", "Sag depth") : tr("Размер украшения", "Decoration size")
            slider.setAccessibilityLabel(slider.toolTip)
            slider.frame = NSRect(x: 62, y: y + 2, width: 209, height: 22)
            document.addSubview(slider)
        }
        if items.isEmpty {
            let empty = NSTextField(labelWithString: tr("Здесь появится всё, что ты расставишь.", "Your placed decorations will appear here."))
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: 8, y: documentHeight - 30, width: 320, height: 22)
            document.addSubview(empty)
        }
        scroll.documentView = document
        let placedY = min(documentHeight - scroll.contentSize.height, placedScroll?.contentView.bounds.minY ?? documentHeight - scroll.contentSize.height)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: placedY))
        placedScroll = scroll
        content.addSubview(scroll)
        panel.contentView = content
    }

    func updateHandles(windows: [WinInfo], visibleScreens: [CGRect]) {
        self.windows = windows
        self.visibleScreens = visibleScreens
        refreshHandles()
    }

    private func refreshHandles() {
        guard panel.isVisible, let item = DecorStore.shared.items.first(where: { $0.id == selectedID }),
              item.kind.isGarland, let start = item.position(in: windows) else {
            for h in handles where h.isVisible { h.orderOut(nil) }
            return
        }
        let end = CGPoint(x: start.x + item.vector.x, y: start.y + item.vector.y)
        for (handle, point) in zip(handles, [start, end]) {
            guard visibleScreens.contains(where: { $0.contains(point) }) else { handle.orderOut(nil); continue }
            let origin = CGPoint(x: point.x - 11, y: point.y - 11)
            if handle.frame.origin != origin { handle.setFrameOrigin(origin) }
            if !handle.isVisible { handle.orderFrontRegardless() }
        }
    }

    @objc private func choosePictures() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.png, .jpeg]
        picker.allowsMultipleSelection = true
        picker.beginSheetModal(for: panel) { [weak self] response in
            if response == .OK { self?.importPictures(picker.urls) }
        }
    }

    private func importPictures(_ urls: [URL]) {
        var failed: [String] = []
        for url in urls {
            do { try DecorLibrary.shared.add(url) }
            catch { failed.append(url.lastPathComponent) }
        }
        catalogScroll = nil
        rebuild()
        if !failed.isEmpty {
            let alert = NSAlert()
            alert.messageText = tr("Не удалось импортировать картинку", "Could not import picture")
            alert.informativeText = failed.joined(separator: ", ") + " (PNG, JPEG)"
            alert.beginSheetModal(for: panel)
        }
    }

    @objc private func saveScene() {
        let alert = NSAlert()
        alert.messageText = tr("Название сцены", "Scene name")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        field.stringValue = tr("Сцена ", "Scene ") + String(DecorStore.shared.scenes.count + 1)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.addButton(withTitle: tr("Сохранить", "Save"))
        alert.addButton(withTitle: tr("Отмена", "Cancel"))
        alert.informativeText = tr("Одинаковое имя обновит сохранённую сцену.", "An existing name updates the saved scene.")
        alert.beginSheetModal(for: panel) { [weak self] response in
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard response == .alertFirstButtonReturn, !name.isEmpty else { return }
            DecorStore.shared.saveScene(named: name)
            self?.rebuild()
        }
    }

    @objc private func loadScene(_ sender: NSMenuItem) {
        guard let scene = DecorStore.shared.scenes.first(where: { $0.name == sender.title }) else { return }
        DecorStore.shared.restore(scene)
        selectedID = nil
        rebuild()
        refreshHandles()
    }

    @objc private func changeStyle(_ sender: NSSegmentedControl) {
        let style = DecorStyle.allCases[sender.selectedSegment]
        if let id = selectedID { DecorStore.shared.restyle(id, to: style) }
        else { styles[selectedKind] = style }
        rebuild()
    }

    @objc private func toggleAttachment(_ sender: NSButton) {
        attachToWindow = sender.state == .on
    }

    @objc private func changeSpacing(_ sender: DecorSizeSlider) {
        DecorStore.shared.changeWavelength(sender.itemID, to: sender.doubleValue)
    }

    @objc private func resize(_ sender: DecorSizeSlider) {
        DecorStore.shared.resize(sender.itemID, to: CGFloat(sender.doubleValue))
        sender.valueLabel?.stringValue = "\(Int((sender.doubleValue * 100).rounded()))%"
    }

    @objc private func remove(_ sender: DecorRemoveButton) {
        DecorStore.shared.remove(sender.id)
        if selectedID == sender.id { selectedID = nil }
        refreshHandles()
        rebuild()
    }

    private func makeTile(_ kind: DecorKind, id: UUID?, pictureID: UUID? = nil, compact: Bool = false) -> DecorTile {
        let tile = DecorTile(kind: kind, compact: compact)
        tile.pictureID = pictureID
        if let pictureID, let picture = DecorLibrary.shared.pictures.first(where: { $0.id == pictureID }) {
            tile.caption = picture.title
            tile.toolTip = picture.title
            tile.setAccessibilityLabel(picture.title)
        } else if kind == .pairedHouse {
            tile.toolTip = tr("Нажми на домик, чтобы переключить свет у второго.", "Click a house to switch the light in its partner.")
        }
        tile.style = DecorStore.shared.items.first { $0.id == id }?.appearance ?? styles[kind] ?? .classic
        tile.selected = selectedKind == kind && selectedID == id && selectedPicture == pictureID
        tile.onSelect = { [weak self] in
            self?.selectedPicture = pictureID
            self?.selectedKind = kind
            self?.selectedID = id
            self?.rebuild()
            self?.refreshHandles()
        }
        tile.onDrag = { [weak self] point in self?.showPreview(kind, id: id, pictureID: pictureID, at: point) }
        tile.onDrop = { [weak self] point in
            guard let self else { return }
            self.preview.orderOut(nil)
            guard !self.panel.frame.contains(point),
                  NSScreen.screens.contains(where: { $0.frame.contains(point) }) else { return }
            var drop = point
            var window: WinInfo?
            let scale = DecorStore.shared.items.first { $0.id == id }?.displayScale ?? 1
            if (kind == .tree || kind == .fireplace),
               let dock = self.windows.first(where: { $0.id == -2 && $0.frame.insetBy(dx: 0, dy: -12).contains(point) }) {
                drop.y = dock.frame.maxY + (kind == .tree ? 85 : 64) * scale
                window = dock
            } else if self.attachToWindow {
                window = WindowTracker.fetch().first(where: { $0.frame.contains(point) })
            }
            self.selectedPicture = pictureID
            self.selectedKind = kind
            self.selectedID = DecorStore.shared.place(kind, style: self.styles[kind] ?? .classic, id: id, pictureID: pictureID, at: drop, window: window)
            self.refreshHandles()
            self.rebuild()
        }
        return tile
    }

    private func showPreview(_ kind: DecorKind, id: UUID?, pictureID: UUID?, at point: CGPoint) {
        if !preview.isVisible {
            let image = NSImageView(image: DecorArtwork.image(kind, DecorStore.shared.items.first { $0.id == id }?.appearance ?? styles[kind] ?? .classic, pictureID: pictureID))
            image.imageScaling = .scaleProportionallyUpOrDown
            preview.contentView = image
        }
        let scale = DecorStore.shared.items.first(where: { $0.id == id })?.displayScale ?? 1
        let size = kind.isAnimated ? DecorArtwork.image(kind, .classic).size : CGSize(width: 100, height: 100)
        let w = size.width * scale, h = size.height * scale
        preview.setFrame(NSRect(x: kind.isGarland ? point.x : point.x - w/2,
                                y: point.y - h * (kind.isGarland ? 64.0/72 : 0.5), width: w, height: h), display: true)
        if !preview.isVisible { preview.orderFrontRegardless() }
    }
}

private final class DecorSizeSlider: NSSlider {
    var itemID = UUID()
    weak var valueLabel: NSTextField?
}

private final class DecorRemoveButton: NSButton {
    var id = UUID()
}

private final class DecorTile: NSView {
    private let kind: DecorKind
    private let compact: Bool
    var selected = false
    var style = DecorStyle.classic
    var onSelect: (() -> Void)?
    var pictureID: UUID?
    var caption: String
    private var dragged = false
    var onDrag: ((CGPoint) -> Void)?
    var onDrop: ((CGPoint) -> Void)?

    init(kind: DecorKind, compact: Bool) {
        self.kind = kind
        self.compact = compact
        self.caption = kind.title
        super.init(frame: .zero)
        toolTip = kind.title
        setAccessibilityLabel(kind.title)
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(selected ? 0.27 : 0.08).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 10, yRadius: 10).fill()
        let imageRect = compact ? NSRect(x: 5, y: 2, width: 53, height: 44)
                                : NSRect(x: (bounds.width - 53) / 2, y: 15, width: 53, height: 53)
        let artwork = DecorArtwork.image(kind, self.style, pictureID: pictureID)
        let scale = min(imageRect.width / artwork.size.width, imageRect.height / artwork.size.height)
        let w = artwork.size.width * scale, h = artwork.size.height * scale
        artwork.draw(in: CGRect(x: imageRect.midX - w/2, y: imageRect.midY - h/2, width: w, height: h))
        let style = NSMutableParagraphStyle()
        style.alignment = compact ? .left : .center
        (caption as NSString).draw(in: compact ? NSRect(x: 65, y: 14, width: 210, height: 18)
                                                   : NSRect(x: 3, y: 4, width: bounds.width - 6, height: 15),
                                     withAttributes: [.font: NSFont.systemFont(ofSize: 11),
                                                      .foregroundColor: NSColor.labelColor, .paragraphStyle: style])
    }

    override func mouseDown(with event: NSEvent) { dragged = false }

    override func mouseDragged(with event: NSEvent) {
        dragged = true
        onDrag?(NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        guard dragged else { onSelect?(); return }
        dragged = false
        onDrop?(NSEvent.mouseLocation)
    }
}

private final class HookGrip: NSView {
    var onMove: ((CGPoint, Bool) -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
        NSColor.controlAccentColor.setFill()
        ring.fill()
        NSColor.white.setStroke()
        ring.lineWidth = 2
        ring.stroke()
    }
    override func mouseDragged(with event: NSEvent) { onMove?(NSEvent.mouseLocation, false) }
    override func mouseUp(with event: NSEvent) { onMove?(NSEvent.mouseLocation, true) }
}
