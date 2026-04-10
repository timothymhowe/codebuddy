import Foundation

/// Optional LLM-powered snarky responses. Configure in ~/.codebuddy/llm.json:
/// {
///   "provider": "anthropic",        // or "openai", "ollama", "groq"
///   "api_key": "sk-...",            // not needed for ollama
///   "model": "claude-haiku-4-5-20251001",  // or "gpt-4o-mini", "llama3.2:1b", "llama-3.1-8b-instant"
///   "base_url": null                // override for custom endpoints
/// }
class SnarkyGenerator {
    private var config: LLMConfig?
    private var lastRequest: Date = .distantPast
    private let cooldown: TimeInterval = 5

    struct LLMConfig: Codable {
        let provider: String  // anthropic, openai, ollama, groq
        let api_key: String?
        let model: String?
        let base_url: String?
    }

    init() {
        let path = NSHomeDirectory() + "/.codebuddy/llm.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let cfg = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            config = cfg
        }
    }

    var isAvailable: Bool { config != nil }

    func generate(activity: BuddyActivity, context: String?,
                  completion: @escaping (String?) -> Void) {
        guard let config = config else { completion(nil); return }

        let now = Date()
        if now.timeIntervalSince(lastRequest) < cooldown { completion(nil); return }
        lastRequest = now

        let activityDesc: String
        switch activity {
        case .idle:     activityDesc = "is idle"
        case .thinking: activityDesc = "is searching/reading code"
        case .coding:   activityDesc = "is editing code"
        case .running:  activityDesc = "is running a terminal command"
        case .error:    activityDesc = "just hit an error"
        case .success:  activityDesc = "just completed something successfully"
        }

        let contextStr = context.map { " (\($0))" } ?? ""
        let prompt = "You are a snarky shiba inu on someone's desktop watching them code. " +
            "Their AI assistant \(activityDesc)\(contextStr). " +
            "Give ONE short reaction under 8 words. Funny, snarky, dog-brained. " +
            "No quotes. Just the raw line."

        switch config.provider.lowercased() {
        case "anthropic":
            callAnthropic(prompt: prompt, config: config, completion: completion)
        case "openai", "groq":
            callOpenAI(prompt: prompt, config: config, completion: completion)
        case "ollama":
            callOllama(prompt: prompt, config: config, completion: completion)
        default:
            completion(nil)
        }
    }

    // MARK: - Anthropic

    private func callAnthropic(prompt: String, config: LLMConfig,
                               completion: @escaping (String?) -> Void) {
        let url = URL(string: config.base_url ?? "https://api.anthropic.com/v1/messages")!
        let body: [String: Any] = [
            "model": config.model ?? "claude-haiku-4-5-20251001",
            "max_tokens": 30,
            "messages": [["role": "user", "content": prompt]]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue(config.api_key, forHTTPHeaderField: "x-api-key")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 5

        fetch(req) { json in
            if let content = json?["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
            } else { completion(nil) }
        }
    }

    // MARK: - OpenAI-compatible (also works for Groq)

    private func callOpenAI(prompt: String, config: LLMConfig,
                            completion: @escaping (String?) -> Void) {
        let baseURL: String
        switch config.provider.lowercased() {
        case "groq": baseURL = config.base_url ?? "https://api.groq.com/openai/v1/chat/completions"
        default:     baseURL = config.base_url ?? "https://api.openai.com/v1/chat/completions"
        }

        let defaultModel: String
        switch config.provider.lowercased() {
        case "groq": defaultModel = "llama-3.1-8b-instant"
        default:     defaultModel = "gpt-4o-mini"
        }

        let body: [String: Any] = [
            "model": config.model ?? defaultModel,
            "max_tokens": 30,
            "messages": [["role": "user", "content": prompt]]
        ]
        var req = URLRequest(url: URL(string: baseURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(config.api_key ?? "")", forHTTPHeaderField: "authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 5

        fetch(req) { json in
            if let choices = json?["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let text = msg["content"] as? String {
                completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
            } else { completion(nil) }
        }
    }

    // MARK: - Ollama (local)

    private func callOllama(prompt: String, config: LLMConfig,
                            completion: @escaping (String?) -> Void) {
        let url = URL(string: config.base_url ?? "http://localhost:11434/api/generate")!
        let body: [String: Any] = [
            "model": config.model ?? "llama3.2:1b",
            "prompt": prompt,
            "stream": false,
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 10

        fetch(req) { json in
            if let text = json?["response"] as? String {
                completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
            } else { completion(nil) }
        }
    }

    // MARK: - Shared

    private func fetch(_ req: URLRequest,
                       completion: @escaping ([String: Any]?) -> Void) {
        URLSession.shared.dataTask(with: req) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { DispatchQueue.main.async { completion(nil) }; return }
            DispatchQueue.main.async { completion(json) }
        }.resume()
    }
}
