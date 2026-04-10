import AppKit
import AVFoundation

/// Undertale-style voice: plays a sound clip per letter, pauses on spaces
class BuddyVoice {
    private var activePlayers: [AVAudioPlayer] = []
    private var babbleTimer: Timer?
    private var clipData: Data?
    private var masterVolume: Float = 0.3

    init() {
        // Load the voice clip into memory
        let paths = [
            FileManager.default.currentDirectoryPath + "/sounds/buddyvoice.wav",
            NSHomeDirectory() + "/.codebuddy/sounds/buddyvoice.wav",
        ]
        for path in paths {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                clipData = data
                break
            }
        }
    }

    func speak(_ text: String, persona personaId: String, activity: BuddyActivity = .idle, volume: Float = 0.3) {
        stop()
        self.masterVolume = volume
        guard clipData != nil else { return }

        // Cycling cadence: word1 = 1 beep, word2 = every 3rd, word3 = every letter, repeat
        let words = text.split(separator: " ")
        var queue: [(char: Character, shouldBeep: Bool)] = []

        for (wordIdx, word) in words.enumerated() {
            let letters = Array(word).filter { $0.isLetter || $0.isNumber }
            let phase = wordIdx % 3
            let beepEvery: Int
            switch phase {
            case 0:  beepEvery = max(letters.count, 1) // 1 beep for the whole word
            case 1:  beepEvery = 3                      // every 3rd letter
            default: beepEvery = 1                      // every letter
            }
            for (i, letter) in letters.enumerated() {
                queue.append((letter, i % beepEvery == 0))
            }
            queue.append((" ", false))
        }

        var index = 0
        let letterInterval: TimeInterval = 0.09
        let spaceInterval: TimeInterval = 0.14

        babbleTimer = Timer.scheduledTimer(withTimeInterval: letterInterval, repeats: true) { [weak self] timer in
            guard let self = self, index < queue.count else {
                timer.invalidate()
                return
            }

            let item = queue[index]
            index += 1

            if item.char == " " {
                timer.fireDate = timer.fireDate.addingTimeInterval(spaceInterval - letterInterval)
                return
            }

            if item.shouldBeep {
                self.playClip()
            }
        }
    }

    func stop() {
        babbleTimer?.invalidate()
        babbleTimer = nil
        for p in activePlayers { p.stop() }
        activePlayers.removeAll()
    }

    private func playClip() {
        guard let data = clipData else { return }
        // Don't cut previous — let it ring out (undertale style)
        guard let p = try? AVAudioPlayer(data: data) else { return }
        p.enableRate = true
        p.rate = Float.random(in: 1.3...1.6)
        p.volume = masterVolume * 0.5
        p.prepareToPlay()
        p.play()

        // Fade out after ~80ms so the tail is soft, not abrupt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            p.setVolume(0, fadeDuration: 0.05)
        }

        activePlayers.append(p)
        // Clean up finished players
        activePlayers.removeAll { !$0.isPlaying }
    }
}
