import Foundation
import Combine

enum Intensity: String, CaseIterable {
    case light, steady, blizzard

    var title: String {
        switch self {
        case .light: return tr("Лёгкий", "Light")
        case .steady: return tr("Ровный", "Steady")
        case .blizzard: return tr("Метель", "Blizzard")
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
    case none, mitten, shovel

    var title: String {
        switch self {
        case .none: return tr("Ничего", "Nothing")
        case .mitten: return tr("🧤 Варежка", "🧤 Mitten")
        case .shovel: return tr("🪏 Лопата", "🪏 Shovel")
        }
    }

    var hint: String {
        switch self {
        case .none: return tr("Курсор проходит мимо снега", "The cursor passes through the snow")
        case .mitten: return tr("Курсор смахивает снег", "The cursor brushes snow away")
        case .shovel: return tr("Касание убирает весь снег с окна", "A touch clears all snow off a window")
        }
    }
}

enum GarlandStyle: String, CaseIterable {
    case off, multicolor, warm

    var title: String {
        switch self {
        case .off: return tr("Выкл", "Off")
        case .multicolor: return tr("Цветная", "Colorful")
        case .warm: return tr("Тёплая", "Warm")
        }
    }
}

enum GarlandMode: String, CaseIterable {
    case twinkle, chase, steady

    var title: String {
        switch self {
        case .twinkle: return tr("Мерцание", "Twinkle")
        case .chase: return tr("Бегущий огонь", "Chase")
        case .steady: return tr("Ровно", "Steady")
        }
    }
}

enum IcicleWhere: String, CaseIterable {
    case menu, windows, both

    var title: String {
        switch self {
        case .menu: return tr("Строка меню", "Menu bar")
        case .windows: return tr("Окна", "Windows")
        case .both: return tr("Везде", "Both")
        }
    }
}

enum IcicleSize: String, CaseIterable {
    case small, large

    var title: String {
        switch self {
        case .small: return tr("Маленькие", "Small")
        case .large: return tr("Большие", "Large")
        }
    }
}

enum TreeCorner: String, CaseIterable {
    case left, right

    var title: String {
        switch self {
        case .left: return tr("Слева", "Left")
        case .right: return tr("Справа", "Right")
        }
    }
}

enum TreeSize: String, CaseIterable {
    case small, medium, large

    var title: String {
        switch self {
        case .small: return tr("Маленькая", "Small")
        case .medium: return tr("Средняя", "Medium")
        case .large: return tr("Большая", "Large")
        }
    }

    var height: CGFloat {
        switch self {
        case .small: return 120
        case .medium: return 180
        case .large: return 260
        }
    }
}

enum FrostSize: String, CaseIterable {
    case light, heavy

    var title: String {
        switch self {
        case .light: return tr("По краям", "Edges")
        case .heavy: return tr("Сильный", "Heavy")
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
    /// id города из `Cities.all`; пусто — снегопад и ветер задаются вручную.
    @Published var weatherCity: String { didSet { d.set(weatherCity, forKey: "weatherCity") } }
    @Published var icicles: Bool { didSet { d.set(icicles, forKey: "icicles") } }
    @Published var icicleWhere: IcicleWhere { didSet { d.set(icicleWhere.rawValue, forKey: "icicleWhere") } }
    @Published var icicleSize: IcicleSize { didSet { d.set(icicleSize.rawValue, forKey: "icicleSize") } }
    /// Дед Мороз иногда пролетает по верху экрана.
    @Published var santa: Bool { didSet { d.set(santa, forKey: "santa") } }
    /// Отсчёт и салют в полночь 31 декабря.
    @Published var newYear: Bool { didSet { d.set(newYear, forKey: "newYear") } }
    /// Снег тает, когда Mac горячий или за окном плюс.
    @Published var melting: Bool { didSet { d.set(melting, forKey: "melting") } }
    @Published var musicOnSnowman: Bool { didSet { d.set(musicOnSnowman, forKey: "musicOnSnowman") } }
    @Published var tree: Bool { didSet { d.set(tree, forKey: "tree") } }
    @Published var treeCorner: TreeCorner { didSet { d.set(treeCorner.rawValue, forKey: "treeCorner") } }
    @Published var treeSize: TreeSize { didSet { d.set(treeSize.rawValue, forKey: "treeSize") } }
    @Published var treeLights: GarlandStyle { didSet { d.set(treeLights.rawValue, forKey: "treeLights") } }
    @Published var treeGifts: Bool { didSet { d.set(treeGifts, forKey: "treeGifts") } }
    @Published var frost: Bool { didSet { d.set(frost, forKey: "frost") } }
    @Published var frostSize: FrostSize { didSet { d.set(frostSize.rawValue, forKey: "frostSize") } }
    @Published var birds: Bool { didSet { d.set(birds, forKey: "birds") } }
    @Published var sounds: Bool { didSet { d.set(sounds, forKey: "sounds") } }
    /// 0...1, общая громкость всех звуков и шкатулки.
    @Published var soundVolume: Double { didSet { d.set(soundVolume, forKey: "soundVolume") } }
    /// «ru» или «en» — язык интерфейса (см. tr()).
    @Published var language: String { didSet { d.set(language, forKey: "language") } }

    /// Последняя загруженная погода (не сохраняется).
    @Published var weather: WeatherNow?

    /// По умолчанию включены только снег, трактор и снеговики — украшения, звуки и прочее
    /// пользователь включает сам, чтобы при первом запуске экран не был занят всем сразу.
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
        weatherCity = d.string(forKey: "weatherCity") ?? ""
        icicles = d.object(forKey: "icicles") as? Bool ?? false
        icicleWhere = IcicleWhere(rawValue: d.string(forKey: "icicleWhere") ?? "") ?? .menu
        icicleSize = IcicleSize(rawValue: d.string(forKey: "icicleSize") ?? "") ?? .small
        santa = d.object(forKey: "santa") as? Bool ?? false
        newYear = d.object(forKey: "newYear") as? Bool ?? false
        melting = d.object(forKey: "melting") as? Bool ?? false
        musicOnSnowman = d.object(forKey: "musicOnSnowman") as? Bool ?? false
        language = d.string(forKey: "language") ?? "ru"
        tree = d.object(forKey: "tree") as? Bool ?? false
        treeCorner = TreeCorner(rawValue: d.string(forKey: "treeCorner") ?? "") ?? .right
        treeSize = TreeSize(rawValue: d.string(forKey: "treeSize") ?? "") ?? .medium
        treeLights = GarlandStyle(rawValue: d.string(forKey: "treeLights") ?? "") ?? .multicolor
        treeGifts = d.object(forKey: "treeGifts") as? Bool ?? true
        frost = d.object(forKey: "frost") as? Bool ?? false
        frostSize = FrostSize(rawValue: d.string(forKey: "frostSize") ?? "") ?? .light
        birds = d.object(forKey: "birds") as? Bool ?? false
        sounds = d.object(forKey: "sounds") as? Bool ?? false
        soundVolume = d.object(forKey: "soundVolume") as? Double ?? 0.3
    }

    /// Погода выбранного города, если режим «как за окном» включён и она уже загружена.
    var activeWeather: WeatherNow? { weatherCity.isEmpty ? nil : weather }

    /// Сила снегопада с учётом погоды. nil — снег сейчас не идёт.
    var effectiveIntensity: Intensity? {
        if let w = activeWeather { return w.snow }
        return intensity
    }

    var effectiveWind: Int { activeWeather?.wind ?? wind }
}
