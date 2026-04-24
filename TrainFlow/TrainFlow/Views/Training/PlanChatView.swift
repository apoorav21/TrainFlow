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
            text: "I'm Coach Goggins. No excuses, no hand-holding — just results. Let's build a plan that will push you to your limit.\n\nFirst — what are we training for? (e.g., run a 5K, finish a marathon, get fitter, lose weight)")
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
                            Text("Coach Goggins")
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
                LazyVStack(spacing: 0) {
                    ForEach(vm.messages) { msg in
                        PlanMessageRow(message: msg)
                            .id(msg.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if vm.isTyping || vm.isGenerating {
                        PlanTypingRow(isGenerating: vm.isGenerating)
                            .id("typing")
                    }
                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.top, 8)
                .animation(.easeOut(duration: 0.3), value: vm.messages.count)
                .animation(.easeOut(duration: 0.2), value: vm.isTyping)
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: vm.isTyping) { _, typing in
                if typing { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            .onChange(of: vm.isGenerating) { _, gen in
                if gen { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.07))
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 15))
                        .foregroundStyle(TFTheme.textTertiary)
                    TextField("No excuses. Answer Goggins...", text: $vm.inputText, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(TFTheme.textPrimary)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .tint(TFTheme.accentOrange)
                        .onSubmit { vm.send() }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(TFTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button(action: { vm.send() }) {
                    let isEmpty = vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                    ZStack {
                        Circle()
                            .fill(isEmpty ? AnyShapeStyle(TFTheme.bgCard) : AnyShapeStyle(
                                LinearGradient(colors: [TFTheme.accentOrange, TFTheme.accentRed],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isEmpty ? TFTheme.textTertiary : .white)
                    }
                }
                .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isTyping || vm.isGenerating)
                .animation(.easeInOut(duration: 0.2), value: vm.inputText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(TFTheme.bgPrimary)
        }
    }
}

// MARK: - Message Row (no-bubble style matching AICoachView)
struct PlanMessageRow: View {
    let message: PlanChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        if isUser {
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
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(TFTheme.textPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Typing / Generating Row
struct PlanTypingRow: View {
    let isGenerating: Bool
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            if isGenerating {
                ProgressView().tint(TFTheme.accentOrange).scaleEffect(0.85)
                Text("Building your plan…")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
            } else {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i == phase ? TFTheme.accentOrange : TFTheme.textTertiary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .scaleEffect(i == phase ? 1.3 : 0.85)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onReceive(timer) { _ in if !isGenerating { phase = (phase + 1) % 3 } }
    }
}
