import Foundation
import Combine

struct City: Hashable {
    let id: String
    let ru: String
    let en: String
    let lat: Double
    let lon: Double
    var name: String { tr(ru, en) }
}

/// Города России, где зимой обычно лежит снег.
enum Cities {
    static let all: [City] = [
        City(id: "msk", ru: "Москва", en: "Moscow", lat: 55.7558, lon: 37.6173),
        City(id: "spb", ru: "Санкт-Петербург", en: "Saint Petersburg", lat: 59.9343, lon: 30.3351),
        City(id: "nn", ru: "Нижний Новгород", en: "Nizhny Novgorod", lat: 56.2965, lon: 43.9361),
        City(id: "kzn", ru: "Казань", en: "Kazan", lat: 55.7961, lon: 49.1064),
        City(id: "ufa", ru: "Уфа", en: "Ufa", lat: 54.7388, lon: 55.9721),
        City(id: "perm", ru: "Пермь", en: "Perm", lat: 58.0105, lon: 56.2502),
        City(id: "ekb", ru: "Екатеринбург", en: "Yekaterinburg", lat: 56.8389, lon: 60.6057),
        City(id: "chel", ru: "Челябинск", en: "Chelyabinsk", lat: 55.1644, lon: 61.4368),
        City(id: "tmn", ru: "Тюмень", en: "Tyumen", lat: 57.1530, lon: 65.5343),
        City(id: "omsk", ru: "Омск", en: "Omsk", lat: 54.9885, lon: 73.3242),
        City(id: "nsk", ru: "Новосибирск", en: "Novosibirsk", lat: 55.0084, lon: 82.9357),
        City(id: "krsk", ru: "Красноярск", en: "Krasnoyarsk", lat: 56.0153, lon: 92.8932),
        City(id: "irk", ru: "Иркутск", en: "Irkutsk", lat: 52.2870, lon: 104.3050),
        City(id: "arh", ru: "Архангельск", en: "Arkhangelsk", lat: 64.5393, lon: 40.5187),
        City(id: "mur", ru: "Мурманск", en: "Murmansk", lat: 68.9585, lon: 33.0827),
        City(id: "slh", ru: "Салехард", en: "Salekhard", lat: 66.5300, lon: 66.6019),
        City(id: "nrl", ru: "Норильск", en: "Norilsk", lat: 69.3558, lon: 88.1893),
        City(id: "yak", ru: "Якутск", en: "Yakutsk", lat: 62.0355, lon: 129.6755),
    ]

    static func byId(_ id: String) -> City? { all.first { $0.id == id } }
}

struct WeatherNow {
    let city: City
    let temp: Double
    let code: Int
    /// Сила снегопада, nil — снега нет.
    let snow: Intensity?
    /// -2...2, как ручной ветер.
    let wind: Int

    var summary: String {
        let t = Int(temp.rounded())
        return "\(city.name): \(t > 0 ? "+" : "")\(t)°, \(WeatherNow.describe(code))"
    }

    static func describe(_ code: Int) -> String {
        switch code {
        case 0: return tr("ясно", "clear")
        case 1, 2, 3: return tr("облачно", "cloudy")
        case 45, 48: return tr("туман", "fog")
        case 51...57: return tr("морось", "drizzle")
        case 61...67, 80...82: return tr("дождь", "rain")
        case 71, 77, 85: return tr("снег", "snow")
        case 73: return tr("снегопад", "snowfall")
        case 75, 86: return tr("метель", "blizzard")
        case 95...99: return tr("гроза", "thunderstorm")
        default: return "—"
        }
    }
}

/// Текущая погода в выбранном городе (Open-Meteo, без ключа). Обновляется раз в 15 минут.
final class WeatherService {
    static let shared = WeatherService()
    private var timer: Timer?
    private var sub: AnyCancellable?

    func start() {
        sub = Settings.shared.$weatherCity.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let s = Settings.shared
        guard let city = Cities.byId(s.weatherCity) else { s.weather = nil; return }
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.lat)),
            URLQueryItem(name: "longitude", value: String(city.lon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,snowfall,wind_speed_10m,wind_direction_10m"),
        ]
        URLSession.shared.dataTask(with: c.url!) { data, _, error in
            guard let data, error == nil,
                  let resp = try? JSONDecoder().decode(Response.self, from: data) else {
                NSLog("Für Elise: погода не загрузилась: \(String(describing: error))")
                return
            }
            let now = WeatherService.interpret(resp.current, city: city)
            DispatchQueue.main.async {
                guard Settings.shared.weatherCity == city.id else { return }
                Settings.shared.weather = now
            }
        }.resume()
    }

    private struct Response: Decodable { let current: Current }
    private struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let snowfall: Double?
        let wind_speed_10m: Double
        let wind_direction_10m: Double
    }

    private static func interpret(_ c: Current, city: City) -> WeatherNow {
        let snow: Intensity?
        switch c.weather_code {
        case 75, 86: snow = .blizzard
        case 73: snow = .steady
        case 71, 77, 85: snow = .light
        default: snow = (c.snowfall ?? 0) > 0 ? .light : nil
        }
        // Направление — откуда дует (метео-градусы). Горизонтальная составляющая «куда»:
        // западный ветер (270°) дует вправо.
        let h = -sin(c.wind_direction_10m * .pi / 180) * c.wind_speed_10m   // км/ч
        let level: Int
        switch abs(h) {
        case ..<8: level = 0
        case ..<20: level = 1
        default: level = 2
        }
        return WeatherNow(city: city, temp: c.temperature_2m, code: c.weather_code, snow: snow,
                          wind: h < 0 ? -level : level)
    }
}
