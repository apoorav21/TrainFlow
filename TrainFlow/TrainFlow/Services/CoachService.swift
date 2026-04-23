import Foundation

// MARK: - Coach Service

@MainActor
final class CoachService: ObservableObject {
    static let shared = CoachService()
    private init() {}

    // MARK: - Models

    struct ChatResponse: Decodable {
        let reply: String
        let onboardingComplete: Bool?
        let metadata: ChatMetadata?
    }

    struct ChatMetadata: Decodable {
        let toolsUsed: [String]?
    }

    struct HistoryResponse: Decodable {
        let messages: [ChatMessage]
        let summary: String?
    }

    struct ChatMessage: Decodable, Identifiable {
        var id: String { msgId }
        let msgId: String
        let role: String    // "user" | "assistant"
        let content: String
        let timestamp: String?
    }

    // MARK: - Send Message

    /// Sends a message to the AI coach and returns (reply, onboardingComplete, toolsUsed).
    func send(message: String) async throws -> (reply: String, onboardingComplete: Bool, toolsUsed: [String]) {
        struct Body: Encodable { let message: String }
        let response: ChatResponse = try await APIClient.shared.chat(
            "/chat/message",
            body: Body(message: message)
        )
        return (
            response.reply,
            response.onboardingComplete ?? false,
            response.metadata?.toolsUsed ?? []
        )
    }

    // MARK: - Chat History

    /// Loads recent chat history from the server.
    func loadHistory(limit: Int = 50) async throws -> [ChatMessage] {
        let response: HistoryResponse = try await APIClient.shared.get(
            "/chat/history",
            queryItems: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
        return response.messages
    }

    // MARK: - Clear Chat

    func clearChat() async throws {
        try await APIClient.shared.delete("/chat")
    }
}

// MARK: - Coach Errors

enum CoachError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Couldn't reach the coaching server."
        case .httpError(let code): return "Server returned error \(code)."
        case .serverError(let msg): return msg
        }
    }
}
