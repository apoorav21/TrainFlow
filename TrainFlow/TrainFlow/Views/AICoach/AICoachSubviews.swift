import SwiftUI

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: CoachMessage

    var body: some View {
        if message.role == .user {
            userBubble
        } else {
            coachResponse
        }
    }

    // User: right-aligned compact gray bubble
    private var userBubble: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 72)
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(TFTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(TFTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    // Coach: full-width flowing text, no bubble, no per-message avatar
    private var coachResponse: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownText(text: message.text, isUser: false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Markdown-lite Text (bold via **)
struct MarkdownText: View {
    let text: String
    let isUser: Bool

    var body: some View {
        buildText()
            .font(.system(size: isUser ? 15 : 15))
            .foregroundStyle(isUser ? TFTheme.textPrimary : TFTheme.textPrimary)
            .lineSpacing(isUser ? 2 : 5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func buildText() -> Text {
        var result = Text("")
        let parts = text.components(separatedBy: "**")
        for (i, part) in parts.enumerated() {
            if i % 2 == 1 {
                result = result + Text(part).bold()
            } else {
                result = result + Text(part)
            }
        }
        return result
    }
}

// MARK: - Typing Indicator (three dots, no avatar)
struct TypingIndicator: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i == phase ? TFTheme.accentPurple : TFTheme.textTertiary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .scaleEffect(i == phase ? 1.3 : 0.85)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Proactive Insight Card
struct ProactiveInsightCard: View {
    let insight: CoachInsight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(insight.color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: insight.category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(insight.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(insight.category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(insight.color)
                        Spacer()
                        if let metric = insight.metric, let label = insight.metricLabel {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(metric)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(TFTheme.textPrimary)
                                Text(label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(TFTheme.textSecondary)
                            }
                        }
                    }
                    Text(insight.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TFTheme.textPrimary)
                    Text(insight.body)
                        .font(.system(size: 12))
                        .foregroundStyle(TFTheme.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Prompt Button
struct QuickPromptButton: View {
    let prompt: QuickPrompt
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(prompt.color)
                Text(prompt.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TFTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}
