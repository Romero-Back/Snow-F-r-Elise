import Foundation
import Combine

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
        case .mitten: return "🧤 Варежка"
        case .shovel: return "🪏 Лопата"
        }
    }

    var hint: String {
        switch self {
        case .mitten: return "Курсор смахивает снег"
        case .shovel: return "Касание убирает весь снег с окна"
        }
    }
}

enum GarlandStyle: String, CaseIterable {
    case off, multicolor, warm

    var title: String {
        switch self {
        case .off: return "Выкл"
        case .multicolor: return "Цветная"
        case .warm: return "Тёплая"
        }
    }
}

enum GarlandMode: String, CaseIterable {
    case twinkle, chase, steady

    var title: String {
        switch self {
        case .twinkle: return "Мерцание"
        case .chase: return "Бегущий огонь"
        case .steady: return "Ровно"
        }
    }
}

/// Настройки в UserDefaults. ObservableObject — чтобы панель на SwiftUI обновлялась сама.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var intensity: Intensity { didSet { d.set(intensity.rawValue, forKey: "intensity") } }
    @Published var tool: Tool { didSet { d.set(tool.rawValue, forKey: "tool") } }
    /// -2...2, 0 — штиль. Отрицательный — ветер влево.
    @Published var wind: Int { didSet { d.set(wind, forKey: "wind") } }
    @Published var paused: Bool { didSet { d.set(paused, forKey: "paused") } }
    /// Полностью выключен: окон снега нет, рендеринг и опрос окон остановлены.
    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    /// Трактор сам выезжает, когда внизу экрана наметает сугроб.
    @Published var autoTractor: Bool { didSet { d.set(autoTractor, forKey: "autoTractor") } }
    /// Снег оседает на окнах и Dock. Выключено — просто падает сквозь экран.
    @Published var accumulate: Bool { didSet { d.set(accumulate, forKey: "accumulate") } }
    @Published var garland: GarlandStyle { didSet { d.set(garland.rawValue, forKey: "garland") } }
    @Published var garlandMode: GarlandMode { didSet { d.set(garlandMode.rawValue, forKey: "garlandMode") } }

    private init() {
        intensity = Intensity(rawValue: d.string(forKey: "intensity") ?? "") ?? .steady
        tool = Tool(rawValue: d.string(forKey: "tool") ?? "") ?? .mitten
        wind = d.integer(forKey: "wind")
        paused = d.bool(forKey: "paused")
        enabled = d.object(forKey: "enabled") as? Bool ?? true
        autoTractor = d.object(forKey: "autoTractor") as? Bool ?? true
        accumulate = d.object(forKey: "accumulate") as? Bool ?? true
        garland = GarlandStyle(rawValue: d.string(forKey: "garland") ?? "") ?? .off
        garlandMode = GarlandMode(rawValue: d.string(forKey: "garlandMode") ?? "") ?? .twinkle
    }
}
