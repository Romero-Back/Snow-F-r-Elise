import Foundation

enum Intensity: String, CaseIterable {
    case light, steady, blizzard

    var title: String {
        switch self {
        case .light: return "Лёгкий"
        case .steady: return "Ровный"
        case .blizzard: return "Метель"
        }
    }

    /// Снежинок в секунду на 1000 pt ширины экрана.
    var rate: CGFloat {
        switch self {
        case .light: return 14
        case .steady: return 40
        case .blizzard: return 130
        }
    }
}

enum Tool: String, CaseIterable {
    case mitten, shovel

    var title: String {
        switch self {
        case .mitten: return "Варежка — смахнуть"
        case .shovel: return "Лопата — убрать всё"
        }
    }
}

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var intensity: Intensity { didSet { d.set(intensity.rawValue, forKey: "intensity") } }
    var tool: Tool { didSet { d.set(tool.rawValue, forKey: "tool") } }
    /// -2...2, 0 — штиль. Отрицательный — ветер влево.
    var wind: Int { didSet { d.set(wind, forKey: "wind") } }
    var paused: Bool { didSet { d.set(paused, forKey: "paused") } }
    /// Полностью выключен: окон снега нет, рендеринг и опрос окон остановлены.
    var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    /// Трактор сам выезжает, когда внизу экрана наметает сугроб.
    var autoTractor: Bool { didSet { d.set(autoTractor, forKey: "autoTractor") } }

    private init() {
        intensity = Intensity(rawValue: d.string(forKey: "intensity") ?? "") ?? .steady
        tool = Tool(rawValue: d.string(forKey: "tool") ?? "") ?? .mitten
        wind = d.integer(forKey: "wind")
        paused = d.bool(forKey: "paused")
        enabled = d.object(forKey: "enabled") as? Bool ?? true
        autoTractor = d.object(forKey: "autoTractor") as? Bool ?? true
    }
}
