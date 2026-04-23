import SwiftUI

struct PlanChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" | "assistant"
    let text: String
    let timestamp = Date()
}

@MainActor
final class PlanChatViewModel: ObservableObject {
    @Published var messages: [PlanChatMessage] = []
    @Published var inputText = ""
    @Published var isTyping = false
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var generationComplete = false
    @Published var generatedPlanId: String?

    private var readyToGenerate = false

    init() {
        let welcome = PlanChatMessage(role: "assistant",
            text: "Hey! 👋 I'm your AI training coach. Let's build a plan tailored just for you.\n\nFirst — what's your goal? (e.g., run a 5K, finish a marathon, get fitter, lose weight)")
        messages = [welcome]
    }

    var chatHistory: [[String: String]] {
        messages.map { ["role": $0.role == "user" ? "user" : "assistant", "content": $0.text] }
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isTyping, !isGenerating else { return }
        inputText = ""
        let userMsg = PlanChatMessage(role: "user", text: text)
        withAnimation { messages.append(userMsg) }
        Task { await fetchReply() }
    }

    private func fetchReply() async {
        isTyping = true
        errorMessage = nil
        defer { isTyping = false }

        do {
            let reply = try await TrainingService.shared.chat(messages: chatHistory)
            let assistantMsg = PlanChatMessage(role: "assistant", text: reply)
            withAnimation { messages.append(assistantMsg) }

            // Check if AI is ready to generate
            if reply.contains("I have everything I need") {
                readyToGenerate = true
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await generatePlan()
            }
        } catch {
            errorMessage = error.localizedDescription
            let desc = error.localizedDescription
            let friendly: String
            if desc.contains("network") || desc.contains("offline") || desc.contains("connect") {
                friendly = "Looks like you're offline. Check your connection and try again."
            } else if desc.contains("502") || desc.contains("503") {
                friendly = "The AI server is temporarily unavailable. Please try again in a moment."
            } else {
                friendly = "Sorry, I hit a snag — please try again."
            }
            let errMsg = PlanChatMessage(role: "assistant", text: friendly)
            withAnimation { messages.append(errMsg) }
        }
    }

    private func generatePlan() async {
        isGenerating = true
        let genMsg = PlanChatMessage(role: "assistant",
            text: "⚙️ Building your personalised training plan now. This may take up to a minute for longer plans — hang tight!")
        withAnimation { messages.append(genMsg) }

        do {
            let (planId, dayCount) = try await TrainingService.shared.generatePlan(chatHistory: chatHistory)
            generatedPlanId = planId
            let doneMsg = PlanChatMessage(role: "assistant",
                text: "✅ Done! I've created your \(dayCount)-day training plan with full day-by-day workouts. Let's get to work! 🏃")
            withAnimation { messages.append(doneMsg) }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            generationComplete = true
        } catch {
            let desc = error.localizedDescription
            let friendly: String
            if desc.contains("timed out") || desc.contains("timeout") {
                friendly = "⚠️ Plan generation is taking longer than expected. Please try again — it usually works on the second attempt!"
            } else {
                friendly = "⚠️ Couldn't create your plan: \(desc). Please try again."
            }
            let failMsg = PlanChatMessage(role: "assistant", text: friendly)
            withAnimation { messages.append(failMsg) }
        }
        isGenerating = false
    }
}

// MARK: - Plan Chat View
struct PlanChatView: View {
    @StateObject private var vm = PlanChatViewModel()
    @Binding var isPresented: Bool
    var onPlanGenerated: () -> Void
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 0) {
                    chatScrollView
                    inputBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(TFTheme.accentOrange.opacity(0.2)).frame(width: 32, height: 32)
                            Image(systemName: "brain.head.profile.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(TFTheme.accentOrange)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("AI Training Coach")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(TFTheme.textPrimary)
                            Text(vm.isGenerating ? "Generating plan..." : "Online")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(vm.isGenerating ? TFTheme.accentOrange : TFTheme.accentGreen)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(TFTheme.textTertiary)
                    }
                }
            }
            .onChange(of: vm.generationComplete) { _, done in
                if done { isPresented = false; onPlanGenerated() }
            }
        }
    }

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(vm.messages) { msg in
                        PlanChatBubble(message: msg)
                            .id(msg.id)
                    }
                    if vm.isTyping || vm.isGenerating {
                        TypingBubble(isGenerating: vm.isGenerating)
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastId = vm.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.isTyping) { _, _ in
                withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(TFTheme.bgCard)
            HStack(spacing: 12) {
                TextField("Type your answer...", text: $vm.inputText, axis: .vertical)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                    .lineLimit(4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(TFTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onSubmit { vm.send() }

                Button(action: { vm.send() }) {
                    ZStack {
                        Circle().fill(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty ?
                                      TFTheme.bgCard : TFTheme.accentOrange)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)
                }
                .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isTyping || vm.isGenerating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TFTheme.bgPrimary)
        }
    }
}

// MARK: - Chat Bubble
struct PlanChatBubble: View {
    let message: PlanChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            if !isUser {
                ZStack {
                    Circle().fill(TFTheme.accentOrange.opacity(0.2)).frame(width: 30, height: 30)
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TFTheme.accentOrange)
                }
            }
            Text(message.text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(isUser ? .white : TFTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? TFTheme.accentOrange : TFTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .clipShape(
                    .rect(
                        topLeadingRadius: isUser ? 18 : 4,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: isUser ? 4 : 18,
                        topTrailingRadius: 18
                    )
                )
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Bubble
struct TypingBubble: View {
    let isGenerating: Bool
    @State private var dotPhase = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(TFTheme.accentOrange.opacity(0.2)).frame(width: 30, height: 30)
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFTheme.accentOrange)
            }
            generatingContent
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(TFTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 60)
        }
        .onAppear { dotPhase = 1 }
    }

    @ViewBuilder
    private var generatingContent: some View {
        if isGenerating {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(TFTheme.accentOrange)
                    .scaleEffect(0.8)
                Text("Building your plan…")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
            }
        } else {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(TFTheme.textTertiary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotPhase == i ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: dotPhase)
                }
            }
        }
    }
}
