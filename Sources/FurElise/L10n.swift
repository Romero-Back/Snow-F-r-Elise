import Foundation

/// Язык интерфейса: «ru» (по умолчанию) или «en». Выбирается в панели → «Ещё».
var isRussian: Bool { (UserDefaults.standard.string(forKey: "language") ?? "ru") == "ru" }

/// Строка интерфейса на выбранном языке.
func tr(_ ru: String, _ en: String) -> String { isRussian ? ru : en }
