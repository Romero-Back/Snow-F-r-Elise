import AppKit
import CoreGraphics

struct WinInfo {
    let id: Int
    /// Рамка окна в глобальных координатах Cocoa (начало — левый нижний угол основного экрана).
    let frame: CGRect
}

enum WindowTracker {
    /// Обычные окна на текущем Space, от переднего к заднему.
    /// Читаются только границы окон: разрешение на запись экрана не нужно.
    static func fetch() -> [WinInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]],
              let primary = NSScreen.screens.first else { return [] }
        let primaryH = primary.frame.height
        let myPid = Int(getpid())
        var result: [WinInfo] = []
        for d in list {
            guard (d[kCGWindowLayer as String] as? Int ?? -1) == 0,
                  (d[kCGWindowOwnerPID as String] as? Int ?? -1) != myPid,
                  (d[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let num = d[kCGWindowNumber as String] as? Int,
                  let bd = d[kCGWindowBounds as String] as? NSDictionary,
                  let b = CGRect(dictionaryRepresentation: bd as CFDictionary),
                  b.width >= 60, b.height >= 30 else { continue }
            let cocoa = CGRect(x: b.minX, y: primaryH - b.maxY, width: b.width, height: b.height)
            result.append(WinInfo(id: num, frame: cocoa))
        }
        return result
    }
}
