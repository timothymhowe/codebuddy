import Foundation
import Combine

/// Persisted settings at ~/.codebuddy/settings.json
class BuddySettings: ObservableObject {
    @Published var voiceEnabled: Bool { didSet { save() } }
    @Published var draggable: Bool { didSet { save() } }
    @Published var walkEnabled: Bool { didSet { save() } }
    @Published var gravityEnabled: Bool { didSet { save() } }
    @Published var speechBubbleEnabled: Bool { didSet { save() } }
    @Published var volume: Float { didSet { save() } }

    private let path = NSHomeDirectory() + "/.codebuddy/settings.json"

    struct Data: Codable {
        var voiceEnabled: Bool
        var draggable: Bool
        var walkEnabled: Bool
        var gravityEnabled: Bool
        var speechBubbleEnabled: Bool
        var volume: Float?
    }

    init() {
        if let data = try? Foundation.Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory() + "/.codebuddy/settings.json")),
           let s = try? JSONDecoder().decode(Data.self, from: data) {
            voiceEnabled = s.voiceEnabled
            draggable = s.draggable
            walkEnabled = s.walkEnabled
            gravityEnabled = s.gravityEnabled
            speechBubbleEnabled = s.speechBubbleEnabled
            volume = s.volume ?? 0.3
        } else {
            voiceEnabled = true
            draggable = true
            walkEnabled = true
            gravityEnabled = true
            speechBubbleEnabled = true
            volume = 0.3
        }
    }

    private func save() {
        let d = Data(
            voiceEnabled: voiceEnabled,
            draggable: draggable,
            walkEnabled: walkEnabled,
            gravityEnabled: gravityEnabled,
            speechBubbleEnabled: speechBubbleEnabled,
            volume: volume
        )
        if let json = try? JSONEncoder().encode(d) {
            try? json.write(to: URL(fileURLWithPath: path))
        }
    }
}
