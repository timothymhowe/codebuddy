import AppKit
import AVFoundation

/// Animal Crossing-style babble using synthesized tones
class BuddyVoice {
    private var player: AVAudioPlayer?
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isSetup = false

    /// Map activity states to sound file keywords
    private static let activityToSound: [BuddyActivity: [String]] = [
        .idle:     ["happy"],
        .thinking: ["confused", "question"],
        .coding:   ["happy"],
        .running:  ["happy", "question"],
        .error:    ["error"],
        .success:  ["happy"],
    ]

    private func customSoundPath(persona: String, activity: BuddyActivity) -> String? {
        let dir = FileManager.default.currentDirectoryPath + "/sounds/" + persona + "/"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return nil }
        let soundFiles = files.filter { $0.hasSuffix(".wav") || $0.hasSuffix(".mp3") }
        guard !soundFiles.isEmpty else { return nil }
        let keywords = BuddyVoice.activityToSound[activity] ?? ["happy"]
        for keyword in keywords {
            if let match = soundFiles.first(where: { $0.lowercased().contains(keyword) }) {
                return dir + match
            }
        }
        return dir + soundFiles.randomElement()!
    }

    func speak(_ text: String, persona personaId: String, activity: BuddyActivity = .idle) {
        stop()

        // Custom wav for error/success
        if activity == .error || activity == .success {
            if let path = customSoundPath(persona: personaId, activity: activity) {
                if let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) {
                    p.volume = 0.35
                    p.play()
                    player = p
                    return
                }
            }
        }

        // Animalese: generate tone sequence from text
        babble(text: text)
    }

    func stop() {
        player?.stop()
        if engine.isRunning { engine.stop() }
        playerNode.stop()
    }

    // MARK: - Tone-based Animalese

    private func babble(text: String) {
        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // Map each letter to a frequency (vowels = distinct pitches, consonants = noise-ish)
        let baseFreq: Double = 400
        let letterFreqs: [Character: Double] = [
            "a": 440, "e": 520, "i": 600, "o": 380, "u": 340,
        ]

        // Build audio buffer from text
        let syllableDuration: Double = 0.065 // very short per letter
        let pauseDuration: Double = 0.03
        let maxLetters = 15
        let letters = Array(text.lowercased().filter { $0.isLetter }.prefix(maxLetters))
        guard !letters.isEmpty else { return }

        let totalSamples = Int(Double(letters.count) * (syllableDuration + pauseDuration) * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else { return }
        buffer.frameLength = AVAudioFrameCount(totalSamples)
        let data = buffer.floatChannelData![0]

        var sampleIdx = 0
        for letter in letters {
            let freq = letterFreqs[letter] ?? (baseFreq + Double(letter.asciiValue ?? 100) * 2.5)
            // Add slight random pitch variation for natural feel
            let actualFreq = freq * Double.random(in: 0.92...1.08)
            let syllableSamples = Int(syllableDuration * sampleRate)
            let pauseSamples = Int(pauseDuration * sampleRate)

            // Generate sine wave syllable with envelope
            for i in 0..<syllableSamples {
                if sampleIdx >= totalSamples { break }
                let t = Double(i) / sampleRate
                let envelope = sin(Double.pi * Double(i) / Double(syllableSamples)) // smooth fade in/out
                let sample = sin(2.0 * Double.pi * actualFreq * t) * envelope * 0.3
                data[sampleIdx] = Float(sample)
                sampleIdx += 1
            }

            // Silence between syllables
            for _ in 0..<pauseSamples {
                if sampleIdx >= totalSamples { break }
                data[sampleIdx] = 0
                sampleIdx += 1
            }
        }

        // Play through AVAudioEngine
        if !isSetup {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            isSetup = true
        }

        do {
            if !engine.isRunning { try engine.start() }
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
            playerNode.volume = 0.5
            playerNode.play()
        } catch {
            // silently fail
        }
    }
}
