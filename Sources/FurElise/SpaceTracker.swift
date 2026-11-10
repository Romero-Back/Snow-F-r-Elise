import AppKit

/// Определяет, на каких экранах сейчас открыт рабочий стол полноэкранного приложения.
///
/// Публичного API для этого нет: окно с уровнем выше обычного macOS показывает и на полноэкранных
/// Space, а рамка полноэкранного окна на MacBook с «чёлкой» не совпадает с экраном.
/// Поэтому используем CGSCopyManagedDisplaySpaces (SkyLight) — закрытую, но много лет стабильную
/// функцию, которой пользуются Hammerspoon, yabai и др. Символы ищем через dlsym: если Apple
/// их уберёт, приложение не упадёт, просто снег будет виден и в полноэкранном режиме.
enum SpaceTracker {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let api: (MainConnection, CopyManagedDisplaySpaces)? = {
        let h = dlopen(nil, RTLD_NOW)
        guard let a = dlsym(h, "CGSMainConnectionID"), let b = dlsym(h, "CGSCopyManagedDisplaySpaces") else { return nil }
        return (unsafeBitCast(a, to: MainConnection.self), unsafeBitCast(b, to: CopyManagedDisplaySpaces.self))
    }()

    /// Тип Space «полноэкранное приложение».
    private static let fullscreenType = 4

    /// UUID дисплеев, на которых сейчас полноэкранный Space. «Main» — когда в настройках
    /// выключено «Мониторы с разными Spaces» и Space общий для всех экранов.
    static func fullscreenDisplays() -> Set<String> {
        guard let (conn, copy) = api,
              let arr = copy(conn())?.takeRetainedValue() as? [[String: Any]] else { return [] }
        var result = Set<String>()
        for d in arr {
            guard let id = d["Display Identifier"] as? String,
                  let cur = d["Current Space"] as? [String: Any],
                  (cur["type"] as? Int) == fullscreenType else { continue }
            result.insert(id)
        }
        return result
    }

    static func uuid(of screen: NSScreen) -> String? {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let u = CGDisplayCreateUUIDFromDisplayID(num)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, u) as String
    }
}
