import AppKit
import ApplicationServices

/// Границы Dock через Accessibility API. Окно Dock в CGWindowList занимает весь экран,
/// поэтому настоящий размер панели можно узнать только так — нужен доступ «Универсальный доступ».
enum DockTracker {
    private static var cachedPid: pid_t = 0
    private static var cachedApp: AXUIElement?

    static var hasAccess: Bool { AXIsProcessTrusted() }

    enum Status: Equatable {
        case noAccess, notFound, hidden, ok(CGRect)
    }
    /// Последнее состояние — для строки в меню и журнала.
    private(set) static var status: Status = .noAccess

    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Рамка панели Dock в глобальных координатах Cocoa. nil — нет доступа,
    /// Dock сбоку (на вертикальный снег не ляжет) или спрятан.
    static func frame() -> CGRect? {
        let (st, f) = query()
        if st != status {
            status = st
            NSLog("Für Elise: Dock — \(st)")
        }
        return f
    }

    private static func query() -> (Status, CGRect?) {
        guard AXIsProcessTrusted() else { return (.noAccess, nil) }
        guard let f = rawFrame() else { return (.notFound, nil) }
        guard let primary = NSScreen.screens.first,
              f.maxY > primary.frame.minY + 5 || NSScreen.screens.contains(where: { $0.frame.intersects(f) })
        else { return (.hidden, nil) }
        return (.ok(f), f)
    }

    private static func rawFrame() -> CGRect? {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let primary = NSScreen.screens.first else { return nil }
        if dock.processIdentifier != cachedPid || cachedApp == nil {
            cachedPid = dock.processIdentifier
            cachedApp = AXUIElementCreateApplication(cachedPid)
        }
        guard let app = cachedApp else { return nil }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success,
              let list = (children as? [AXUIElement])?.first(where: { role(of: $0) == kAXListRole as String })
        else { return nil }

        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(list, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(list, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        // swiftlint:disable force_cast
        AXValueGetValue(posRef as! AXValue, .cgPoint, &p)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &s)
        // swiftlint:enable force_cast
        guard s.width > s.height, s.width > 40, s.height > 10 else { return nil }
        return CGRect(x: p.x, y: primary.frame.height - p.y - s.height, width: s.width, height: s.height)
    }

    private static func role(of e: AXUIElement) -> String? {
        var r: CFTypeRef?
        AXUIElementCopyAttributeValue(e, kAXRoleAttribute as CFString, &r)
        return r as? String
    }
}
