import AVFoundation

/// Тихие звуковые эффекты, синтезированные в приложении (без файлов).
/// Аудиодвижок запускается по требованию и сам останавливается после нескольких секунд тишины.
final class Sound {
    static let shared = Sound()

    enum Effect: CaseIterable {
        case bells, crunch, pop, whoosh, chirp, tinkle, splat
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var lastPlayed: [Effect: Date] = [:]
    private var stopWork: DispatchWorkItem?
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!

    /// Не чаще, чем раз в столько секунд для каждого эффекта — чтобы не трещало.
    private let minGap: [Effect: TimeInterval] = [
        .bells: 0.5, .crunch: 0.12, .pop: 0.08, .whoosh: 0.25, .chirp: 0.3, .tinkle: 0.2, .splat: 0.1,
    ]
    /// Относительная громкость эффектов — все тихие, хруст тише всего.
    private let level: [Effect: Float] = [
        .bells: 0.35, .crunch: 0.18, .pop: 0.45, .whoosh: 0.15, .chirp: 0.3, .tinkle: 0.3, .splat: 0.4,
    ]

    func play(_ e: Effect, gain: Float = 1) {
        let s = Settings.shared
        guard s.sounds, s.soundVolume > 0.01 else { return }
        let now = Date()
        if let last = lastPlayed[e], now.timeIntervalSince(last) < (minGap[e] ?? 0.1) { return }
        lastPlayed[e] = now

        if players.isEmpty {
            for _ in 0..<6 {
                let p = AVAudioPlayerNode()
                engine.attach(p)
                engine.connect(p, to: engine.mainMixerNode, format: format)
                players.append(p)
            }
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        guard let buf = buffer(e) else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.stop()
        p.volume = Float(s.soundVolume) * (level[e] ?? 0.3) * gain
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        p.play()
        scheduleStop(after: Double(buf.frameLength) / rate + 1.5)
    }

    private func scheduleStop(after seconds: Double) {
        stopWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.players.forEach { $0.stop() }
            self.engine.stop()
        }
        stopWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: w)
    }

    // MARK: - Синтез

    private func buffer(_ e: Effect) -> AVAudioPCMBuffer? {
        if let b = buffers[e] { return b }
        let b: AVAudioPCMBuffer?
        switch e {
        case .bells: b = render(1.2) { t in Sound.bells(t) }
        case .crunch: b = render(0.16) { t in Sound.noise() * exp(-t * 28) * (0.6 + 0.4 * sin(t * 900)) }
        case .pop: b = render(0.9) { t in Sound.pop(t) }
        case .whoosh: b = render(0.7) { t in Sound.noise() * sin(Double.pi * t / 0.7) * 0.5 }
        case .chirp: b = render(0.35) { t in Sound.chirp(t) }
        case .tinkle: b = render(0.8) { t in Sound.tinkle(t) }
        case .splat: b = render(0.25) { t in (Sound.noise() * 0.6 + sin(2 * .pi * 90 * t)) * exp(-t * 22) }
        }
        buffers[e] = b
        return b
    }

    private func render(_ seconds: Double, _ f: (Double) -> Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let l = buf.floatChannelData?[0], let r = buf.floatChannelData?[1] else { return nil }
        buf.frameLength = frames
        var peak: Float = 0
        for i in 0..<Int(frames) {
            let v = Float(f(Double(i) / rate))
            l[i] = v
            peak = max(peak, abs(v))
        }
        let k: Float = peak > 0 ? 0.8 / peak : 0
        for i in 0..<Int(frames) { l[i] *= k; r[i] = l[i] }
        return buf
    }

    private static func noise() -> Double { Double.random(in: -1...1) }

    /// Бубенцы: несколько высоких колокольчиков с дрожанием, вступают вразнобой.
    private static func bells(_ t: Double) -> Double {
        let notes: [(Double, Double)] = [(0, 2093), (0.07, 2637), (0.15, 3136), (0.24, 2349), (0.33, 2793), (0.45, 2093)]
        var v = 0.0
        for (start, f) in notes where t >= start {
            let x = t - start
            let tremolo = 0.75 + 0.25 * sin(2 * .pi * 22 * x)
            v += (sin(2 * .pi * f * x) + 0.4 * sin(2 * .pi * f * 2.76 * x) * exp(-x * 12)) * exp(-x * 5) * tremolo
        }
        return v
    }

    /// Хлопок салюта: глухой удар и потрескивание.
    private static func pop(_ t: Double) -> Double {
        let thump = sin(2 * .pi * (70 - 30 * t) * t) * exp(-t * 14)
        let crackle = (Double.random(in: 0...1) < 0.03 ? noise() : 0) * exp(-t * 3) * 0.8
        return thump + noise() * exp(-t * 30) * 0.5 + crackle
    }

    /// Щебет снегиря: два коротких свиста вверх.
    private static func chirp(_ t: Double) -> Double {
        func tweet(_ x: Double) -> Double {
            guard x >= 0, x < 0.12 else { return 0 }
            let f = 2600 + 1800 * x / 0.12
            return sin(2 * .pi * f * x) * sin(.pi * x / 0.12)
        }
        return tweet(t) + 0.8 * tweet(t - 0.17)
    }

    /// Звон льдинок: россыпь высоких «динь».
    private static func tinkle(_ t: Double) -> Double {
        let hits: [(Double, Double)] = [(0, 3520), (0.05, 4186), (0.11, 3951), (0.18, 4699), (0.26, 3729)]
        var v = 0.0
        for (start, f) in hits where t >= start {
            let x = t - start
            v += sin(2 * .pi * f * x) * exp(-x * 14)
        }
        return v
    }
}
