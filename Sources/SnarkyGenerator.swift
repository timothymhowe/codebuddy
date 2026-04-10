import Foundation

/// Generates snarky one-liners using Claude API based on what's happening
class SnarkyGenerator {
    private let apiKey: String?
    private var lastRequest: Date = .distantPast
    private let cooldown: TimeInterval = 5 // don't spam API

    init() {
        // Read API key from environment or config
        apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? SnarkyGenerator.readKeyFromConfig()
    }

    private static func readKeyFromConfig() -> String? {
        let paths = [
            NSHomeDirectory() + "/.codebuddy/api_key",
            NSHomeDirectory() + "/.anthropic/api_key",
        ]
        for path in paths {
            if let key = try? String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty {
                return key
            }
        }
        return nil
    }

    var isAvailable: Bool { apiKey != nil }

    /// Generate a snarky response for the given activity + context
    func generate(activity: BuddyActivity, context: String?,
                  completion: @escaping (String?) -> Void) {
        guard let apiKey = apiKey else {
            completion(nil)
            return
        }

        // Rate limit
        let now = Date()
        if now.timeIntervalSince(lastRequest) < cooldown {
            completion(nil)
            return
        }
        lastRequest = now

        let activityDesc: String
        switch activity {
        case .idle:     activityDesc = "is idle, waiting"
        case .thinking: activityDesc = "is thinking/searching"
        case .coding:   activityDesc = "is editing code"
        case .running:  activityDesc = "is running a command"
        case .error:    activityDesc = "just hit an error"
        case .success:  activityDesc = "just succeeded at something"
        }

        let contextStr = context.map { " (specifically: \($0))" } ?? ""

        let prompt = """
        You are a snarky, judgmental shiba inu sitting on someone's desktop watching them code. \
        Their AI assistant \(activityDesc)\(contextStr). \
        Give a single short reaction (under 8 words). Be funny, snarky, and dog-brained. \
        Mix in occasional dog mannerisms (*sniff*, bork, etc). \
        No quotes, no punctuation except ... and !, just the raw line.
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 30,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = jsonData
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                DispatchQueue.main.async {
                    completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            } else {
                completion(nil)
            }
        }.resume()
    }
}
