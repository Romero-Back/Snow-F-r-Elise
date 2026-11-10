import SwiftUI

/// То, что панель показывает, но что не хранится в настройках.
final class PanelState: ObservableObject {
    enum DockAction { case none, grant, relaunch }
    @Published var dockText = ""
    @Published var dockAction: DockAction = .none
    @Published var launchAtLogin = false
    /// Открытая вкладка. Здесь, а не в @State: в Command Line Tools нет плагина макросов SwiftUI.
    @Published var tab: PanelView.Tab = .snow
}

struct PanelActions {
    var callTractor: () -> Void
    var clearSnow: () -> Void
    var dockAction: () -> Void
    var setLaunchAtLogin: (Bool) -> Void
    var checkForUpdates: () -> Void
    var playMusic: () -> Void
    var fireworks: () -> Void
    var santa: () -> Void
    var sedan: () -> Void
    var drift: () -> Void
    var quit: () -> Void
}

struct PanelView: View {
    enum Tab: Hashable { case snow, decor, more }

    @ObservedObject var s = Settings.shared
    @ObservedObject var state: PanelState
    let actions: PanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if s.enabled {
                Picker("", selection: $state.tab) {
                    Text(tr("Снег", "Snow")).tag(Tab.snow)
                    Text(tr("Украшения", "Decor")).tag(Tab.decor)
                    Text(tr("Ещё", "More")).tag(Tab.more)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                switch state.tab {
                case .snow:
                    snowCard
                    cursorCard
                    tractorCard
                case .decor:
                    garlandCard
                    treeCard
                    fireplaceCard
                    iciclesCard
                    frostCard
                    extrasCard
                case .more:
                    soundCard
                    musicCard
                    meltCard
                    systemCard
                }
            } else {
                Text(tr("Снег выключен и не нагружает Mac. Включите переключателем сверху.",
                        "Snow is off and uses no resources. Turn it on with the switch above."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
            footer
        }
        .padding(14)
        .frame(width: 350)
        .background(
            LinearGradient(colors: [Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.18), .clear],
                           startPoint: .top, endPoint: .center)
        )
    }

    // MARK: - Шапка и подвал

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
                .help(s.enabled ? tr("Выключить снег полностью", "Turn snow off completely")
                                : tr("Включить снег", "Turn snow on"))
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private var footer: some View {
        HStack {
            Button(action: actions.clearSnow) { Label(tr("Очистить снег", "Clear snow"), systemImage: "trash") }
                .disabled(!s.enabled)
            Spacer()
            Button(action: actions.quit) { Label(tr("Выйти", "Quit"), systemImage: "power") }
                .keyboardShortcut("q")
        }
        .controlSize(.small)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Вкладка «Снег»

    private var snowCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                title(tr("Снегопад", "Snowfall"), "cloud.snow.fill")
                Spacer()
                Picker("", selection: $s.weatherCity) {
                    Text(tr("Вручную", "Manual")).tag("")
                    Divider()
                    ForEach(Cities.all, id: \.id) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                .help(tr("Снег и ветер как сейчас в выбранном городе", "Snow and wind as they are now in the chosen city"))
            }

            if s.weatherCity.isEmpty {
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
                    Text(windTitle(s.wind))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .trailing)
                }
            } else {
                weatherInfo
            }

            Picker("", selection: $s.flakeStyle) {
                ForEach(FlakeStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .help(tr("Вид снежинок", "Snowflake look"))

            HStack {
                Toggle(tr("Копить сугробы", "Pile up"), isOn: $s.accumulate)
                Spacer()
                Toggle(tr("Пауза", "Pause"), isOn: $s.paused)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .card()
    }

    @ViewBuilder private var weatherInfo: some View {
        if let w = s.weather, w.city.id == s.weatherCity {
            VStack(alignment: .leading, spacing: 3) {
                Label(w.summary, systemImage: w.snow == nil ? "cloud" : "cloud.snow")
                    .font(.callout)
                Text(w.snow.map { tr("Идёт снег: ", "Snowing: ") + $0.title.lowercased() + ", " + tr("ветер ", "wind ") + windTitle(w.wind) }
                     ?? tr("Сейчас там снега нет — ждём", "No snow there right now — waiting"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(tr("Загружаю погоду…", "Loading weather…")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var cursorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(tr("Курсор", "Cursor"), "cursorarrow.motionlines")
            Picker("", selection: $s.tool) {
                ForEach(Tool.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(!s.accumulate)
            Text(s.accumulate
                 ? s.tool.hint + tr(". ⌥ + движение по снегу — снежок, три снежка — снеговик ☃︎. "
                                    + "Отпустите ⌥ на быстром движении — снежок полетит в окно.",
                                    ". ⌥ + move through snow — a snowball; stack three — a snowman ☃︎. "
                                    + "Release ⌥ mid-flick to throw it at a window.")
                 : tr("Сугробы выключены — трогать нечего", "Piling is off — nothing to touch"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    /// Уборка снега: кто выезжает сам и кнопки «вызвать».
    private var tractorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                title(tr("Уборка снега", "Snow clearing"), "car.side")
                Spacer()
                Toggle(tr("Сама", "Auto"), isOn: $s.autoTractor)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .help(tr("Выезжает сама, когда внизу наметёт сугроб", "Comes out by itself when a drift piles up"))
            }
            if s.autoTractor {
                Picker("", selection: $s.autoCleaner) {
                    ForEach(AutoCleaner.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: 6) {
                Button(tr("🚜 Трактор", "🚜 Plow"), action: actions.callTractor)
                Button(tr("🚗 Пятёрка", "🚗 Sedan"), action: actions.sedan)
                Button(tr("💨 Дрифт", "💨 Drift"), action: actions.drift)
                    .buttonStyle(.borderedProminent)
                    .tint(.black)
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    // MARK: - Вкладка «Украшения»

    private var garlandCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            title(tr("Гирлянда", "Garland"), "sparkles")
            Picker("", selection: $s.garland) {
                ForEach(GarlandStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            if s.garland != .off {
                Picker("", selection: $s.garlandDouble) {
                    Text(tr("Один ряд", "One row")).tag(false)
                    Text(tr("Два ряда", "Two rows")).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
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

    private var iciclesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                title(tr("Сосульки", "Icicles"), "drop.fill")
                Spacer()
                Toggle("", isOn: $s.icicles).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            if s.icicles {
                Picker("", selection: $s.icicleWhere) {
                    ForEach(IcicleWhere.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Picker("", selection: $s.icicleSize) {
                    ForEach(IcicleSize.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Text(tr("Растут со временем, отламываются, если сдвинуть окно",
                        "They grow over time and break off when you move a window"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var frostCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                title(tr("Иней", "Frost"), "snowflake.circle")
                Spacer()
                Toggle("", isOn: $s.frost).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            if s.frost {
                Picker("", selection: $s.frostSize) {
                    ForEach(FrostSize.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Text(tr("Нарастает от краёв экрана, курсор его растапливает",
                        "Grows in from the screen edges; the cursor melts it"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var treeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🎄").font(.system(size: 15))
                Text(tr("Ёлка", "Christmas tree")).font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("", isOn: $s.tree).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            if s.tree {
                HStack {
                    Text(tr("Угол", "Corner")).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                    Picker("", selection: $s.treeCorner) {
                        ForEach(TreeCorner.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                Picker("", selection: $s.treeSize) {
                    ForEach(TreeSize.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                HStack {
                    Text(tr("Огоньки", "Lights")).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
                    Picker("", selection: $s.treeLights) {
                        ForEach(GarlandStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                HStack {
                    Toggle(tr("Подарки", "Gifts"), isOn: $s.treeGifts)
                    Spacer()
                    Toggle(tr("Ставить на Dock", "Stand on the Dock"), isOn: $s.treeOnDock)
                        .help(tr("Если Dock виден — ёлка встанет на его край", "If the Dock is visible, the tree stands on its edge"))
                }
                .toggleStyle(.checkbox)
                .font(.caption)
            }
        }
        .card()
    }

    private var fireplaceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🔥").font(.system(size: 15))
                Text(tr("Камин", "Fireplace")).font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("", isOn: $s.fireplace).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            if s.fireplace {
                HStack {
                    Picker("", selection: $s.fireplaceCorner) {
                        ForEach(TreeCorner.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    Toggle(tr("На Dock", "On Dock"), isOn: $s.fireplaceOnDock)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
        }
        .card()
    }

    /// Снегири, Дед Мороз и Новый год — одной карточкой, чтобы панель не росла.
    private var extrasCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🐦")
                Toggle(tr("Снегири", "Bullfinches"), isOn: $s.birds).toggleStyle(.checkbox)
                Spacer()
            }
            HStack {
                Text("🛷")
                Toggle(tr("Дед Мороз иногда пролетает", "Father Frost flies by"), isOn: $s.santa).toggleStyle(.checkbox)
                Spacer()
                Button(tr("Сейчас", "Now"), action: actions.santa).controlSize(.small)
            }
            HStack {
                Text("🎆")
                Toggle(tr("Салют в Новый год", "New Year fireworks"), isOn: $s.newYear).toggleStyle(.checkbox)
                Spacer()
                Button(tr("Салют!", "Fireworks!"), action: actions.fireworks).controlSize(.small)
            }
        }
        .font(.callout)
        .card()
    }




    // MARK: - Вкладка «Ещё»

    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                title(tr("Звуки", "Sounds"), "speaker.wave.2.fill")
                Spacer()
                Toggle("", isOn: $s.sounds).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            if s.sounds {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary).font(.caption)
                    Slider(value: $s.soundVolume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).font(.caption)
                }
                Text(tr("Бубенцы, хруст снега, салют, снегири, сосульки, снежки",
                        "Bells, crunching snow, fireworks, birds, icicles, snowballs"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var musicCard: some View {
        HStack {
            Text("🎼").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("«К Элизе»", "“Für Elise”")).font(.subheadline.weight(.semibold))
                Toggle(tr("Играть, когда слепили снеговика", "Play when a snowman is built"), isOn: $s.musicOnSnowman)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            Spacer()
            Button(action: actions.playMusic) { Label(tr("Сыграть", "Play"), systemImage: "play.fill") }
        }
        .card()
    }

    private var meltCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                title(tr("Таяние", "Melting"), "thermometer.sun")
                Spacer()
                Toggle("", isOn: $s.melting).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            Text(meltStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var systemCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "dock.rectangle").foregroundStyle(.secondary)
                Text(state.dockText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                switch state.dockAction {
                case .grant: Button(tr("Дать доступ", "Grant access"), action: actions.dockAction).controlSize(.small)
                case .relaunch: Button(tr("Перезапустить", "Relaunch"), action: actions.dockAction).controlSize(.small)
                case .none: EmptyView()
                }
            }
            HStack {
                Toggle(tr("Запускать при входе", "Launch at login"),
                       isOn: Binding(get: { state.launchAtLogin }, set: { actions.setLaunchAtLogin($0) }))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Button(action: actions.checkForUpdates) {
                    Label(tr("Обновления", "Updates"), systemImage: "arrow.triangle.2.circlepath")
                }
                .controlSize(.small)
            }
            HStack {
                Picker("", selection: $s.language) {
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .controlSize(.small)
                Spacer()
                Text(tr("Версия ", "Version ") + version)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .card()
    }

    // MARK: - Вспомогательное

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var meltStatus: String {
        let hot: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: hot = tr("Mac холодный — снег не тает", "Your Mac is cool — snow isn't melting")
        case .fair: hot = tr("Mac тёплый — снег понемногу тает", "Your Mac is warm — snow is slowly melting")
        default: hot = tr("Mac горячий — снег быстро тает", "Your Mac is hot — snow is melting fast")
        }
        return hot + tr(". Ещё тает, когда в выбранном городе плюс.", ". It also melts when it's above zero in the chosen city.")
    }

    private func windTitle(_ w: Int) -> String {
        switch w {
        case -2: return tr("← сильный", "← strong")
        case -1: return tr("← слабый", "← light")
        case 1: return tr("слабый →", "light →")
        case 2: return tr("сильный →", "strong →")
        default: return tr("штиль", "calm")
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
