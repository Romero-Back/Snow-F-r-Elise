import SwiftUI

/// То, что панель показывает, но что не хранится в настройках.
final class PanelState: ObservableObject {
    enum DockAction { case none, grant, relaunch }
    @Published var dockText = ""
    @Published var dockAction: DockAction = .none
    @Published var launchAtLogin = false
}

struct PanelActions {
    var callTractor: () -> Void
    var clearSnow: () -> Void
    var dockAction: () -> Void
    var setLaunchAtLogin: (Bool) -> Void
    var checkForUpdates: () -> Void
    var quit: () -> Void
}

struct PanelView: View {
    @ObservedObject var s = Settings.shared
    @ObservedObject var state: PanelState
    let actions: PanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if s.enabled {
                snowCard
                cursorCard
                garlandCard
                tractorCard
            } else {
                Text("Снег выключен и не нагружает Mac. Включите переключателем сверху.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
            footer
        }
        .padding(14)
        .frame(width: 340)
        .background(
            LinearGradient(colors: [Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.18), .clear],
                           startPoint: .top, endPoint: .center)
        )
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .center) {
            Image(systemName: "snowflake")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.55, green: 0.75, blue: 1)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .blue.opacity(0.4), radius: 4)
            Text("Für Elise")
                .font(.custom("SnellRoundhand-Bold", size: 30))
            Spacer()
            Toggle("", isOn: $s.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(s.enabled ? "Выключить снег полностью" : "Включить снег")
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    // MARK: - Карточки

    private var snowCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            title("Снегопад", "cloud.snow.fill")
            Picker("", selection: $s.intensity) {
                ForEach(Intensity.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Image(systemName: "wind").foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(s.wind) }, set: { s.wind = Int($0.rounded()) }),
                       in: -2...2, step: 1)
                Text(windTitle)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 78, alignment: .trailing)
            }

            HStack {
                Toggle("Копить сугробы", isOn: $s.accumulate)
                Spacer()
                Toggle("Пауза", isOn: $s.paused)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .card()
    }

    private var cursorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            title("Курсор", "cursorarrow.motionlines")
            Picker("", selection: $s.tool) {
                ForEach(Tool.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(!s.accumulate)
            Text(s.accumulate ? "\(s.tool.hint). ⌥ + движение по снегу — снежок, три снежка — снеговик ☃︎"
                              : "Сугробы выключены — трогать нечего")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var garlandCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            title("Гирлянда", "sparkles")
            Picker("", selection: $s.garland) {
                ForEach(GarlandStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            if s.garland != .off {
                Picker("", selection: $s.garlandMode) {
                    ForEach(GarlandMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
        .card()
    }

    private var tractorCard: some View {
        HStack {
            Text("🚜").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("Трактор").font(.subheadline.weight(.semibold))
                Toggle("Сам чистит сугробы", isOn: $s.autoTractor)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            Spacer()
            Button("Вызвать", action: actions.callTractor)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .card()
    }

    // MARK: - Подвал

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "dock.rectangle").foregroundStyle(.secondary)
                Text(state.dockText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                switch state.dockAction {
                case .grant: Button("Дать доступ", action: actions.dockAction).controlSize(.small)
                case .relaunch: Button("Перезапустить", action: actions.dockAction).controlSize(.small)
                case .none: EmptyView()
                }
            }
            HStack {
                Toggle("Запускать при входе", isOn: Binding(get: { state.launchAtLogin },
                                                            set: { actions.setLaunchAtLogin($0) }))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Button(action: actions.checkForUpdates) {
                    Label("Обновления", systemImage: "arrow.triangle.2.circlepath")
                }
                .controlSize(.small)
                .help("Версия \(version). Проверить обновления")
            }
            HStack {
                Button(action: actions.clearSnow) { Label("Очистить снег", systemImage: "trash") }
                    .disabled(!s.enabled)
                Spacer()
                Button(action: actions.quit) { Label("Выйти", systemImage: "power") }
                    .keyboardShortcut("q")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Вспомогательное

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var windTitle: String {
        switch s.wind {
        case -2: return "← сильный"
        case -1: return "← слабый"
        case 1: return "слабый →"
        case 2: return "сильный →"
        default: return "штиль"
        }
    }

    private func title(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
    }
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.background.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08)))
    }
}

private extension View {
    func card() -> some View { modifier(CardModifier()) }
}
