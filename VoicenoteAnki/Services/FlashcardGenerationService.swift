import Foundation

// MARK: - Errors

enum FlashcardGenerationError: LocalizedError {
    case missingAPIKey
    case emptyTranscript
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:        return "Claude API key not configured. Set CLAUDE_API_KEY in the app."
        case .emptyTranscript:      return "Cannot generate flashcards from an empty transcript."
        case .networkError(let e):  return "Network error: \(e.localizedDescription)"
        case .invalidResponse:      return "Unexpected response from the server."
        case .decodingError(let e): return "Failed to parse flashcards: \(e.localizedDescription)"
        case .apiError(let msg):    return "API error: \(msg)"
        }
    }
}

// MARK: - Service

final class FlashcardGenerationService {

    /// Set at app launch or from Settings. In production load from Keychain.
    static var apiKey: String = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? ""

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model    = "claude-haiku-4-5-20251001"

    // MARK: - Public

    /// Generate flashcards from a voice-note transcript.
    func generateFlashcards(from transcript: String, noteID: UUID) async throws -> [Flashcard] {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FlashcardGenerationError.emptyTranscript
        }
        let key = Self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw FlashcardGenerationError.missingAPIKey }

        let prompt = buildPrompt(transcript: transcript)
        let body   = buildRequestBody(prompt: prompt)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json",     forHTTPHeaderField: "Content-Type")
        request.setValue(key,                    forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",           forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FlashcardGenerationError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data))?.error.message
            throw FlashcardGenerationError.apiError(msg ?? "HTTP \(http.statusCode)")
        }

        return try parseResponse(data: data, noteID: noteID)
    }

    // MARK: - Private helpers

    private func buildPrompt(transcript: String) -> String {
        """
        You are an expert educator. Given the following voice-note transcript, \
        generate a set of high-quality Anki-style flashcards that capture the key \
        concepts, facts, definitions, and ideas.

        Rules:
        - Return ONLY a valid JSON array — no markdown, no commentary.
        - Each element must have exactly these fields:
            "front"      : string  (concise question or term, ≤ 120 chars)
            "back"       : string  (clear, complete answer or definition)
            "tags"       : array of strings (topic keywords, lowercase)
            "difficulty" : one of "easy" | "medium" | "hard"
        - Generate between 3 and 12 cards depending on content density.
        - Prefer specific, testable facts over vague summaries.

        Transcript:
        \(transcript)
        """
    }

    private func buildRequestBody(prompt: String) -> [String: Any] {
        [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
    }

    private func parseResponse(data: Data, noteID: UUID) throws -> [Flashcard] {
        struct MessageResponse: Decodable {
            struct Content: Decodable { let type: String; let text: String }
            let content: [Content]
        }

        let decoded: MessageResponse
        do {
            decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
        } catch {
            throw FlashcardGenerationError.decodingError(error)
        }

        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw FlashcardGenerationError.invalidResponse
        }

        // Strip any accidental markdown fences
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw FlashcardGenerationError.invalidResponse
        }

        struct RawCard: Decodable {
            let front: String
            let back: String
            let tags: [String]
            let difficulty: String
        }

        let rawCards: [RawCard]
        do {
            rawCards = try JSONDecoder().decode([RawCard].self, from: jsonData)
        } catch {
            throw FlashcardGenerationError.decodingError(error)
        }

        return rawCards.map { raw in
            Flashcard(
                front:      raw.front,
                back:       raw.back,
                tags:       raw.tags,
                difficulty: Difficulty(rawValue: raw.difficulty) ?? .medium,
                sourceNoteID: noteID
            )
        }
    }
}

// MARK: - Anthropic error envelope

private struct AnthropicErrorResponse: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}
