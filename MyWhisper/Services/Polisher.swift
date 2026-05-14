import Foundation
import OSLog

private let log = Logger(subsystem: "com.mywhisper.app", category: "Polisher")

struct PolisherConfig {
    var endpoint: URL
    var model: String
    var apiKey: String
    var timeout: TimeInterval = 3.0
}

enum PolisherError: LocalizedError {
    case notConfigured
    case http(Int, String)
    case decode(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Polisher endpoint/model/key not configured"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .decode(let detail): return "Decode failed: \(detail)"
        case .timeout: return "Polish request timed out"
        }
    }
}

/// Sends raw Whisper transcript to an OpenAI-compatible chat completions endpoint
/// (Ollama Cloud by default) and returns the cleaned-up text.
enum Polisher {
    private static let systemPrompt = """
    You are a dictation cleanup assistant. The user dictates text into any app; your job is to return the SAME content rewritten with correct punctuation, capitalization, and natural formatting.

    Rules:
    - Preserve meaning exactly. Do NOT add facts, opinions, commentary, headings, or words the speaker did not say.
    - Fix punctuation, capitalization, and obvious filler ("um", "uh", repeated stutters).

    Formatting heuristics — apply only when the speaker clearly signals structure:
    - Numbered enumeration ("number one… number two… number three…" / "first… second… third… finally…" / "step one… step two…") → numbered markdown list (1. 2. 3.) with the introductory sentence kept as a lead-in ending in a colon. Drop the literal "number one"/"first" tokens.
    - Comma-separated set following a list-introducing phrase ("buy groceries: milk, tea, and bananas" / "the agenda is X, Y, and Z") → bulleted markdown list (- one per line). Drop the trailing "and".
    - "New line" → single line break; "new paragraph" → blank line. Drop the literal phrase.
    - Spoken punctuation ("comma", "period", "question mark", "colon", "exclamation point") → insert that punctuation, drop the word.

    Do NOT format as a list if the speaker only used commas without a list-introducing phrase, or if there are fewer than two items.

    Output ONLY the cleaned text. No preamble, no explanation, no surrounding quotes, no trailing newline.
    """

    static func polish(_ raw: String, config: PolisherConfig) async throws -> String {
        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = config.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": config.model,
            "stream": false,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": raw]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        log.info("polishing via \(config.model, privacy: .public)…")
        let start = Date()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let err as URLError where err.code == .timedOut {
            throw PolisherError.timeout
        }
        let elapsed = Date().timeIntervalSince(start)

        guard let http = response as? HTTPURLResponse else {
            throw PolisherError.decode("response was not HTTPURLResponse")
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw PolisherError.http(http.statusCode, String(snippet))
        }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any],
              let choices = dict["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw PolisherError.decode("unexpected JSON shape")
        }

        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        log.info("polished in \(String(format: "%.2f", elapsed), privacy: .public)s, \(cleaned.count, privacy: .public) chars")
        return cleaned
    }
}
