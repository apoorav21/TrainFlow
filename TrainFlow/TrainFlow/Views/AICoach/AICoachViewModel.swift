import Foundation
import SwiftUI

@MainActor
final class AICoachViewModel: ObservableObject {
    @Published var messages: [CoachMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var isLoadingHistory: Bool = true
    @Published var errorMessage: String? = nil

    // MARK: - Send

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let userMsg = CoachMessage(role: .user, text: trimmed, timestamp: Date())
        withAnimation { messages.append(userMsg) }
        inputText = ""
        errorMessage = nil

        Task { await fetchReply(for: trimmed) }
    }

    func sendCurrentInput() {
        send(inputText)
    }

    func clearChat() {
        messages = []
        inputText = ""
        isTyping = false
        errorMessage = nil
        Task {
            try? await CoachService.shared.clearChat()
        }
    }

    // MARK: - Network

    private func fetchReply(for message: String) async {
        isTyping = true
        defer { isTyping = false }

        do {
            let (reply, _, toolsUsed) = try await CoachService.shared.send(message: message)
            let coachMsg = CoachMessage(role: .coach, text: reply, timestamp: Date())
            withAnimation { messages.append(coachMsg) }
            let planTools: Set<String> = ["adapt_training_plan", "create_training_plan"]
            if !planTools.isDisjoint(with: toolsUsed) {
                NotificationCenter.default.post(name: .planDidUpdate, object: nil)
            }
        } catch {
            NSLog("[AICoach] Error: %@", error.localizedDescription)
            errorMessage = error.localizedDescription
            let desc = error.localizedDescription
            let friendlyText: String
            if desc.contains("502") || desc.contains("503") || desc.contains("OpenAI") {
                friendlyText = "The AI server is temporarily unavailable. Please try again in a moment."
            } else if desc.contains("network") || desc.contains("offline") || desc.contains("connect") {
                friendlyText = "Looks like you're offline. Check your connection and try again."
            } else if desc.contains("Please sign in") {
                friendlyText = "You've been signed out. Please sign in again."
            } else {
                friendlyText = "Something went wrong. Please try again."
            }
            let fallback = CoachMessage(role: .coach, text: friendlyText, timestamp: Date())
            withAnimation { messages.append(fallback) }
        }
    }

    // MARK: - Load History

    func loadHistory() async {
        guard messages.isEmpty else {
            isLoadingHistory = false
            return
        }
        defer { isLoadingHistory = false }
        do {
            let history = try await CoachService.shared.loadHistory()
            let mapped: [CoachMessage] = history.compactMap { msg in
                guard msg.role == "user" || msg.role == "assistant" else { return nil }
                let role: MessageRole = msg.role == "user" ? .user : .coach
                var date = Date()
                if let ts = msg.timestamp {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let parsed = f.date(from: ts) { date = parsed }
                }
                return CoachMessage(role: role, text: msg.content, timestamp: date)
            }
            if !mapped.isEmpty {
                withAnimation { messages = mapped }
            }
        } catch {
            NSLog("[AICoach] Could not load history: %@", error.localizedDescription)
        }
    }
}
