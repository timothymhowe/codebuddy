import AppKit
import AVFoundation

/// Plays persona voices — custom wav files if available, animalese synth fallback
class BuddyVoice {
    private var synth = NSSpeechSynthesizer()
    private var player: AVAudioPlayer?

    /// Map activity states to sound file keywords
    private static let activityToSound: [BuddyActivity: [String]] = [
        .idle:     ["happy"],
        .thinking: ["confused", "question"],
        .coding:   ["happy"],
        .running:  ["happy", "question"],
        .error:    ["error"],
        .success:  ["happy"],
    ]

    /// Try to find a custom wav/mp3 for this persona + activity
    private func customSoundPath(persona: String, activity: BuddyActivity) -> String? {
        let dir = FileManager.default.currentDirectoryPath + "/sounds/" + persona + "/"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return nil }
        let soundFiles = files.filter { $0.hasSuffix(".wav") || $0.hasSuffix(".mp3") }
        guard !soundFiles.isEmpty else { return nil }

        // Match by activity keyword
        let keywords = BuddyVoice.activityToSound[activity] ?? ["happy"]
        for keyword in keywords {
            if let match = soundFiles.first(where: { $0.lowercased().contains(keyword) }) {
                return dir + match
            }
        }
        // Fallback: random sound file
        return dir + soundFiles.randomElement()!
    }

    func speak(_ text: String, persona personaId: String, activity: BuddyActivity = .idle) {
        // Stop anything playing
        player?.stop()
        if synth.isSpeaking { synth.stopSpeaking() }

        // Try custom sound first
        if let path = customSoundPath(persona: personaId, activity: activity) {
            let url = URL(fileURLWithPath: path)
            if let p = try? AVAudioPlayer(contentsOf: url) {
                p.volume = 0.4
                p.play()
                player = p
                return
            }
        }

        // Fallback: animalese synth
        let vid = BuddyVoice.voiceId(for: personaId)
        synth.setVoice(NSSpeechSynthesizer.VoiceName(rawValue: vid))
        synth.rate = 340
        synth.volume = 0.25
        synth.startSpeaking(text)
    }

    func stop() {
        player?.stop()
        if synth.isSpeaking { synth.stopSpeaking() }
    }

    /// Synth voice ID per persona
    static func voiceId(for personaId: String) -> String {
        switch personaId {
        case "mochi":     return "com.apple.speech.synthesis.voice.Bubbles"
        case "pixel":     return "com.apple.speech.synthesis.voice.Trinoids"
        case "tanuki":    return "com.apple.speech.synthesis.voice.Bahh"
        case "kumo":      return "com.apple.speech.synthesis.voice.Whisper"
        case "yuki":      return "com.apple.speech.synthesis.voice.Bells"
        case "kitsune":   return "com.apple.speech.synthesis.voice.Zarvox"
        case "chubby":    return "com.apple.speech.synthesis.voice.Bahh"
        case "frenchie":  return "com.apple.speech.synthesis.voice.Bahh"
        case "oni":       return "com.apple.speech.synthesis.voice.Cellos"
        case "sakura":    return "com.apple.speech.synthesis.voice.Bubbles"
        case "tsukuyomi": return "com.apple.speech.synthesis.voice.Whisper"
        case "raijin":    return "com.apple.speech.synthesis.voice.Cellos"
        default:          return "com.apple.speech.synthesis.voice.Bells"
        }
    }
}
