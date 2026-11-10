import AppKit
import SpriteKit
import ServiceManagement

/// SKView, которая рендерит в разрешении 1x даже на Retina: пикселей в 4 раза меньше.
/// Снег мягкий, поэтому на вид разницы почти нет, а GPU и композитору заметно легче.
final class LowResSKView: SKView {
    var renderScale: CGFloat = 1 { didSet { applyScale() } }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        applyScale()
    }

    override func layout() {
        super.layout()
        applyScale()
    }

    private func applyScale() {
        guard let layer = layer else { return }
        if layer.contentsScale != renderScale { layer.contentsScale = renderScale }
        layer.magnificationFilter = .linear
        layer.minificationFilter = .linear
        if let metal = layer as? CAMetalLayer {
            let size = CGSize(width: bounds.width * renderScale, height: bounds.height * renderScale)
            if metal.drawableSize != size { metal.drawableSize = size }
        }
    }
}

final class Overlay {
    let window: NSWindow
    let view: LowResSKView
    let scene: SnowScene
    let displayUUID: String?

    init(screen: NSScreen) {
        let frame = screen.frame
        displayUUID = SpaceTracker.uuid(of: screen)
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true   // клики проходят сквозь снег
        window.level = .statusBar          // выше Dock
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        view = LowResSKView(frame: NSRect(origin: .zero, size: frame.size))
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 30
        window.contentView = view
        window.setFrame(frame, display: false)

        scene = SnowScene(screenFrame: frame)
        view.presentScene(scene)
        view.renderScale = 1.5
        window.orderFrontRegardless()
        syncPaused()
    }

    /// Экран сейчас показывает полноэкранное приложение: окно снега спрятано, сцена на паузе,
    /// накопленный снег ждёт возврата на обычный рабочий стол.
    private(set) var away = false

    func setAway(_ value: Bool) {
        guard value != away else { return }
        away = value
        if value { window.orderOut(nil) } else { window.orderFrontRegardless() }
        syncPaused()
    }

    func syncPaused() {
        view.isPaused = Settings.shared.paused || away
    }

    func close() {
        view.presentScene(nil)
        window.orderOut(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var overlays: [Overlay] = []
    private var timer: Timer?

    private var pauseItem: NSMenuItem!
    private var intensityItems: [Intensity: NSMenuItem] = [:]
    private var toolItems: [Tool: NSMenuItem] = [:]
    private var windItems: [Int: NSMenuItem] = [:]
    private var loginItem: NSMenuItem!
    private var dockAccessItem: NSMenuItem!
    private var tick = 0
    private var dockFrame: CGRect?
    private var enabledItem: NSMenuItem!
    private var autoTractorItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(pollWindows),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        // Автоматизация: `notifyutil`-подобный вызов из скриптов/Shortcuts —
        // distributed notification «app.snowfall.FurElise.tractor» вызывает трактор.
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(callTractor),
                                                            name: .init("app.snowfall.FurElise.tractor"), object: nil)
        if Settings.shared.enabled { start() }
    }

    /// Создать окна снега и запустить опрос окон.
    private func start() {
        buildOverlays()
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(pollWindows),
                                     userInfo: nil, repeats: true)
    }

    /// Полное выключение: окна и сцены уничтожаются, таймер останавливается — ни CPU, ни GPU.
    private func stop() {
        timer?.invalidate()
        timer = nil
        overlays.forEach { $0.close() }
        overlays = []
    }

    private func buildOverlays() {
        overlays.forEach { $0.close() }
        overlays = NSScreen.screens.map { Overlay(screen: $0) }
        pollWindows()
    }

    @objc private func screensChanged() {
        if Settings.shared.enabled { buildOverlays() }
    }

    @objc private func pollWindows() {
        guard Settings.shared.enabled else { return }
        let fullscreen = SpaceTracker.fullscreenDisplays()
        for o in overlays {
            o.setAway(fullscreen.contains("Main") || o.displayUUID.map(fullscreen.contains) == true)
        }
        guard !Settings.shared.paused else { return }
        var wins = WindowTracker.fetch()

        // Границы Dock меняются редко, а запрос через Accessibility дороже — раз в 0.3 с.
        if tick % 3 == 0 { dockFrame = DockTracker.frame() }
        tick += 1
        if let d = dockFrame, let screen = NSScreen.screens.first(where: { $0.frame.intersects(d) }) {
            // Dock выше всех окон. Тянем его рамку до низа экрана, чтобы снег «на земле» не лез на иконки.
            // Рамка из Accessibility включает прозрачный отступ ~6 pt над самой панелью Dock.
            let dockTopInset: CGFloat = 6
            let ext = CGRect(x: d.minX, y: screen.frame.minY, width: d.width,
                             height: d.maxY - dockTopInset - screen.frame.minY)
            wins.insert(WinInfo(id: -2, frame: ext), at: 0)
        }

        // Пока экран в полноэкранном режиме, окна обычного рабочего стола не видны —
        // сцену не обновляем, иначе весь снег с них осыпался бы.
        for o in overlays where !o.away { o.scene.updateWindows(wins) }
    }

    // MARK: - Меню

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Für Elise")
        img?.isTemplate = true
        statusItem.button?.image = img

        let menu = NSMenu()
        menu.delegate = self

        // Название — как на автографе Бетховена.
        let title = NSMenuItem(title: "Für Elise", action: nil, keyEquivalent: "")
        let script = NSFont(name: "SnellRoundhand-Bold", size: 22) ?? NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.attributedTitle = NSAttributedString(string: "Für Elise", attributes: [.font: script])
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        enabledItem = item("Выключить снег", #selector(toggleEnabled), key: "e")
        menu.addItem(enabledItem)
        pauseItem = item("Пауза", #selector(togglePause), key: "p")
        menu.addItem(pauseItem)
        menu.addItem(item("Очистить снег", #selector(clearSnow), key: "k"))
        menu.addItem(.separator())

        menu.addItem(header("Снегопад"))
        for i in Intensity.allCases {
            let it = item(i.title, #selector(setIntensity(_:)))
            it.representedObject = i.rawValue
            intensityItems[i] = it
            menu.addItem(it)
        }
        menu.addItem(.separator())

        menu.addItem(header("Инструмент"))
        for t in Tool.allCases {
            let it = item(t.title, #selector(setTool(_:)))
            it.representedObject = t.rawValue
            toolItems[t] = it
            menu.addItem(it)
        }
        menu.addItem(.separator())

        menu.addItem(header("Трактор"))
        menu.addItem(item("Вызвать трактор", #selector(callTractor), key: "t"))
        autoTractorItem = item("Сам чистит сугробы", #selector(toggleAutoTractor))
        menu.addItem(autoTractorItem)
        menu.addItem(.separator())

        menu.addItem(header("Ветер"))
        let winds: [(Int, String)] = [(-2, "← Сильный"), (-1, "← Слабый"), (0, "Штиль"), (1, "Слабый →"), (2, "Сильный →")]
        for (v, title) in winds {
            let it = item(title, #selector(setWind(_:)))
            it.tag = v
            windItems[v] = it
            menu.addItem(it)
        }
        menu.addItem(.separator())

        let hint = NSMenuItem(title: "Снежок: зажмите ⌥ и ведите курсором по снегу", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        let hint2 = NSMenuItem(title: "Три снежка друг на друге — снеговик ☃︎", action: nil, keyEquivalent: "")
        hint2.isEnabled = false
        menu.addItem(hint2)
        menu.addItem(.separator())

        dockAccessItem = item("Снег на Dock: дать доступ…", #selector(requestDockAccess))
        menu.addItem(dockAccessItem)
        loginItem = item("Запускать при входе", #selector(toggleLogin))
        menu.addItem(loginItem)
        menu.addItem(item("Выйти", #selector(quit), key: "q"))

        statusItem.menu = menu
        refreshMenu()
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        return it
    }

    private func header(_ title: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.isEnabled = false
        return it
    }

    func menuWillOpen(_ menu: NSMenu) { refreshMenu() }

    private func refreshMenu() {
        let s = Settings.shared
        enabledItem.title = s.enabled ? "Выключить снег" : "Включить снег"
        autoTractorItem.state = s.autoTractor ? .on : .off
        pauseItem.state = s.paused ? .on : .off
        intensityItems.forEach { $0.value.state = $0.key == s.intensity ? .on : .off }
        toolItems.forEach { $0.value.state = $0.key == s.tool ? .on : .off }
        windItems.forEach { $0.value.state = $0.key == s.wind ? .on : .off }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        statusItem.button?.appearsDisabled = s.paused || !s.enabled
        switch (DockTracker.hasAccess, DockTracker.status) {
        case (false, _):
            dockAccessItem.title = "Снег на Dock: дать доступ…"
            dockAccessItem.action = #selector(requestDockAccess)
        case (true, .ok):
            dockAccessItem.title = "Снег на Dock: работает ✓"
            dockAccessItem.action = nil
        case (true, .hidden):
            dockAccessItem.title = "Снег на Dock: Dock скрыт"
            dockAccessItem.action = nil
        case (true, _):
            // Доступ выдан, но API Dock ещё не отвечает — обычно помогает перезапуск.
            dockAccessItem.title = "Снег на Dock: перезапустить приложение"
            dockAccessItem.action = #selector(relaunch)
        }
    }

    @objc private func togglePause() {
        Settings.shared.paused.toggle()
        overlays.forEach { $0.syncPaused() }
        refreshMenu()
    }

    @objc private func toggleEnabled() {
        Settings.shared.enabled.toggle()
        if Settings.shared.enabled { start() } else { stop() }
        refreshMenu()
    }

    @objc private func callTractor() { overlays.forEach { $0.scene.callTractor() } }

    @objc private func toggleAutoTractor() {
        Settings.shared.autoTractor.toggle()
        refreshMenu()
    }

    @objc private func clearSnow() { overlays.forEach { $0.scene.clearAll() } }

    @objc private func setIntensity(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let v = Intensity(rawValue: raw) { Settings.shared.intensity = v }
        refreshMenu()
    }

    @objc private func setTool(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let v = Tool(rawValue: raw) { Settings.shared.tool = v }
        refreshMenu()
    }

    @objc private func setWind(_ sender: NSMenuItem) {
        Settings.shared.wind = sender.tag
        refreshMenu()
    }

    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled { try svc.unregister() } else { try svc.register() }
        } catch {
            NSLog("Für Elise: не удалось изменить автозапуск: \(error)")
        }
        refreshMenu()
    }

    @objc private func requestDockAccess() { DockTracker.requestAccess() }

    @objc private func relaunch() {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
