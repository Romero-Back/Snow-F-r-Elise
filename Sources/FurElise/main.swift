import AppKit
import SpriteKit
import ServiceManagement
import SwiftUI
import Combine
import Sparkle

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

        scene = SnowScene(screenFrame: frame, menuBarInset: max(0, frame.maxY - screen.visibleFrame.maxY))
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

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var overlays: [Overlay] = []
    private var timer: Timer?
    private var tick = 0
    private var dockFrame: CGRect?

    private let popover = NSPopover()
    private let panelState = PanelState()
    private var subs: Set<AnyCancellable> = []
    private var outsideClickMonitor: Any?
    /// Sparkle: раз в день сам проверяет ленту обновлений из Info.plist (SUFeedURL).
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil,
                                                       userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        observeSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(pollWindows),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        // Автоматизация: distributed notification «app.snowfall.FurElise.tractor» вызывает трактор.
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

    // MARK: - Строка меню и панель

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Für Elise")
        img?.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
    }

    private func setupPopover() {
        let actions = PanelActions(
            callTractor: { [weak self] in self?.callTractor() },
            clearSnow: { [weak self] in self?.overlays.forEach { $0.scene.clearAll() } },
            dockAction: { [weak self] in self?.dockAction() },
            setLaunchAtLogin: { [weak self] on in self?.setLaunchAtLogin(on) },
            checkForUpdates: { [weak self] in
                self?.popover.performClose(nil)
                NSApp.activate(ignoringOtherApps: true)
                self?.updater.checkForUpdates(nil)
            },
            quit: { NSApp.terminate(nil) })
        let host = NSHostingController(rootView: PanelView(state: panelState, actions: actions))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        refreshPanelState()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Панель должна быть над окнами снега (у них уровень statusBar).
        popover.contentViewController?.view.window?.level = .popUpMenu
        // Приложение без Dock-иконки: клик мимо панели не всегда её закрывает — страхуемся.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
    }

    private func refreshPanelState() {
        switch (DockTracker.hasAccess, DockTracker.status) {
        case (false, _):
            panelState.dockText = "Снег на Dock: нужен доступ"
            panelState.dockAction = .grant
        case (true, .ok):
            panelState.dockText = "Снег на Dock: работает ✓"
            panelState.dockAction = .none
        case (true, .hidden):
            panelState.dockText = "Снег на Dock: Dock скрыт"
            panelState.dockAction = .none
        case (true, _):
            // Доступ выдан, но API Dock ещё не отвечает — обычно помогает перезапуск.
            panelState.dockText = "Снег на Dock: нужен перезапуск"
            panelState.dockAction = .relaunch
        }
        panelState.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Реакция на изменения настроек из панели. @Published шлёт значение до записи — поэтому async.
    private func observeSettings() {
        let s = Settings.shared
        s.$enabled.dropFirst().removeDuplicates().sink { [weak self] on in
            DispatchQueue.main.async {
                if on { self?.start() } else { self?.stop() }
                self?.updateIcon()
            }
        }.store(in: &subs)
        s.$paused.dropFirst().removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.overlays.forEach { $0.syncPaused() }
                self?.updateIcon()
            }
        }.store(in: &subs)
        updateIcon()
    }

    private func updateIcon() {
        statusItem.button?.appearsDisabled = Settings.shared.paused || !Settings.shared.enabled
    }

    @objc private func callTractor() { overlays.forEach { $0.scene.callTractor() } }

    private func dockAction() {
        switch panelState.dockAction {
        case .grant: DockTracker.requestAccess()
        case .relaunch: relaunch()
        case .none: break
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        let svc = SMAppService.mainApp
        do {
            if on { try svc.register() } else { try svc.unregister() }
        } catch {
            NSLog("Für Elise: не удалось изменить автозапуск: \(error)")
        }
        panelState.launchAtLogin = svc.status == .enabled
    }

    private func relaunch() {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
