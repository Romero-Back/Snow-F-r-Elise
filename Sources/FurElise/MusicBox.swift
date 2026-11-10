import AVFoundation

/// Музыкальная шкатулка: начало «К Элизе» (Бетховен, общественное достояние),
/// синтезированное прямо в приложении — без звуковых файлов.
final class MusicBox {
    static let shared = MusicBox()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private var buffer: AVAudioPCMBuffer?
    private var configured = false
    private(set) var isPlaying = false
    private var lastStart = Date.distantPast

    /// (шестнадцатая доля, MIDI-нота, громкость). Правая рука — мелодия, левая — арпеджио.
    private static let score: [(Double, Int, Double)] = {
        let E5 = 76, Ds5 = 75, B4 = 71, D5 = 74, C5 = 72, A4 = 69
        let C4 = 60, E4 = 64, Gs4 = 68, A2 = 45, E3 = 52, A3 = 57, E2 = 40, Gs3 = 56
        var s: [(Double, Int, Double)] = []
        func rh(_ t: Double, _ n: Int) { s.append((t, n, 1.0)) }
        func lh(_ t: Double, _ n: Int) { s.append((t, n, 0.45)) }
        let motif = [E5, Ds5, E5, Ds5, E5, B4, D5, C5]
        for (i, n) in motif.enumerated() { rh(Double(i), n) }
        rh(8, A4); lh(8, A2); lh(9, E3); lh(10, A3)
        rh(11, C4); rh(12, E4); rh(13, A4)
        rh(14, B4); lh(14, E2); lh(15, E3); lh(16, Gs3)
        rh(17, E4); rh(18, Gs4); rh(19, B4)
        rh(20, C5); lh(20, A2); lh(21, E3); lh(22, A3)
        rh(23, E4)
        for (i, n) in motif.enumerated() { rh(24 + Double(i), n) }
        rh(32, A4); lh(32, A2); lh(33, E3); lh(34, A3)
        rh(35, C4); rh(36, E4); rh(37, A4)
        rh(38, B4); lh(38, E2); lh(39, E3); lh(40, Gs3)
        rh(41, E4); rh(42, C5); rh(43, B4)
        rh(44, A4); lh(44, A2); lh(45, E3); lh(46, A3)
        return s
    }()

    func play() {
        // Не перебиваем саму себя и не играем чаще раза в 10 секунд.
        guard !isPlaying, Date().timeIntervalSince(lastStart) > 10 else { return }
        if buffer == nil { buffer = MusicBox.render() }
        guard let buffer else { return }
        if !configured {
            engine.attach(player)
            engine.attach(reverb)
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = 28
            engine.connect(player, to: reverb, format: buffer.format)
            engine.connect(reverb, to: engine.mainMixerNode, format: buffer.format)
            configured = true
        }
        do { try engine.start() } catch { NSLog("Für Elise: звук не запустился: \(error)"); return }
        isPlaying = true
        lastStart = Date()
        player.volume = min(1, Float(Settings.shared.soundVolume) * 1.2)
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            // Даём доиграть хвосту реверберации и выключаем движок — чтобы не держать аудио зря.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard let self else { return }
                self.engine.stop()
                self.isPlaying = false
            }
        }
        player.play()
    }

    private static func render() -> AVAudioPCMBuffer? {
        let rate = 44_100.0
        let step = 0.17        // длительность шестнадцатой, с
        let ring = 2.2         // сколько звенит язычок, с
        let total = (score.map(\.0).max() ?? 0) * step + ring
        let frames = AVAudioFrameCount(total * rate)
        // Стерео: реверберация не принимает моно на выходе в микшер.
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames),
              let out = buf.floatChannelData?[0], let right = buf.floatChannelData?[1] else { return nil }
        buf.frameLength = frames
        for i in 0..<Int(frames) { out[i] = 0 }

        for (beat, midi, vel) in score {
            let f = 440 * pow(2, Double(midi - 69) / 12)
            let start = Int(beat * step * rate)
            let len = min(Int(ring * rate), Int(frames) - start)
            guard len > 0 else { continue }
            for k in 0..<len {
                let t = Double(k) / rate
                let attack = min(1, t / 0.002)
                let w = 2 * Double.pi * f * t
                // Основной тон + обертоны язычка; высокий «дзынь» гаснет быстрее всего.
                var v = sin(w) * exp(-t * 3.0)
                v += 0.35 * sin(2 * w) * exp(-t * 6)
                v += 0.12 * sin(3 * w) * exp(-t * 9)
                v += 0.22 * sin(5.93 * w) * exp(-t * 20)
                out[start + k] += Float(v * attack * vel * 0.22)
            }
        }
        var peak: Float = 0
        for i in 0..<Int(frames) { peak = max(peak, abs(out[i])) }
        if peak > 0 { for i in 0..<Int(frames) { out[i] *= 0.7 / peak } }
        for i in 0..<Int(frames) { right[i] = out[i] }
        return buf
    }
}
