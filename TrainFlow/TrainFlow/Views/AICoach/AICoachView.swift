import SwiftUI

struct AICoachView: View {
    @StateObject private var vm = AICoachViewModel()
    @StateObject private var hk = HealthKitManager.shared
    @State private var showChat = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            TFTheme.bgPrimary.ignoresSafeArea()
            if showChat {
                chatView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                homeView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showChat)
        .onTapGesture { inputFocused = false }
        .task {
            async let history: () = vm.loadHistory()
            async let health: () = hk.fetchAll()
            _ = await (history, health)
            if !vm.messages.isEmpty { showChat = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAICoachWithMessage)) { note in
            if let msg = note.userInfo?["message"] as? String {
                showChat = true
                vm.inputText = msg
                inputFocused = true
            }
        }
    }

    // MARK: - Home (Briefing)

    private var homeView: some View {
        VStack(spacing: 0) {
            coachHeader(showBack: false)
            Divider().background(Color.white.opacity(0.07))
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    briefingSection
                    quickPromptsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            sharedInputBar
        }
    }

    // MARK: - Chat

    private var chatView: some View {
        VStack(spacing: 0) {
            coachHeader(showBack: true)
            Divider().background(Color.white.opacity(0.07))
            chatScrollArea
            sharedInputBar
        }
    }

    // MARK: - Header

    private func coachHeader(showBack: Bool) -> some View {
        HStack(spacing: showBack ? 4 : 12) {
            if showBack {
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) { showChat = false }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(TFTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
            }
            coachAvatar
            VStack(alignment: .leading, spacing: 2) {
                Text("Coach Goggins")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                HStack(spacing: 5) {
                    Circle().fill(TFTheme.accentGreen).frame(width: 7, height: 7)
                    Text("Online · Stay hard.")
                        .font(.system(size: 12))
                        .foregroundStyle(TFTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, showBack ? 12 : 20)
        .padding(.vertical, 14)
    }

    private var coachAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [TFTheme.accentPurple, TFTheme.accentBlue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Briefing Cards (Real Data)

    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Briefing")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
                .padding(.horizontal, 4)
            ForEach(liveInsights) { insight in
                ProactiveInsightCard(insight: insight) {
                    showChat = true
                    vm.send(insight.action ?? "Tell me more about my \(insight.category.rawValue.lowercased()) data today")
                }
            }
        }
    }

    // Build insight cards from real HealthKit data; falls back to static if no data yet
    private var liveInsights: [CoachInsight] {
        var insights: [CoachInsight] = []

        // HRV / Recovery
        if hk.heart.hrv > 0 {
            let hrv = hk.heart.hrv
            let trend = hk.heart.hrvTrend
            let good = trend >= 0
            insights.append(CoachInsight(
                category: .recovery,
                title: good ? "HRV Rising — Push Today" : "HRV Dipping — Ease Up",
                body: good
                    ? "HRV is up \(String(format: "%.1f", abs(trend)))ms this week, signalling strong adaptation. Your body is primed for a quality session."
                    : "HRV is down \(String(format: "%.1f", abs(trend)))ms. Your nervous system needs recovery — keep today's intensity low.",
                metric: "\(Int(hrv))ms",
                metricLabel: "HRV",
                action: good ? "My HRV is trending up — what's the best workout to do today?" : "My HRV is down this week. Should I take it easy today?",
                color: good ? TFTheme.accentGreen : TFTheme.accentOrange
            ))
        }

        // Sleep
        let recentNights = hk.sleepNights.suffix(7)
        let deepValues = recentNights.compactMap { night -> Double? in
            let d = night.stages.first(where: { $0.stage == SleepStage.deep })?.minutes ?? 0
            return d > 0 ? d : nil
        }
        if !deepValues.isEmpty {
            let avgDeep = deepValues.reduce(0, +) / Double(deepValues.count)
            let target = 90.0
            let low = avgDeep < target
            insights.append(CoachInsight(
                category: .sleep,
                title: low ? "Deep Sleep Below Target" : "Deep Sleep on Track",
                body: low
                    ? "Averaged \(Int(avgDeep)) min deep sleep this week vs. the \(Int(target)) min target. This may slow muscle repair and adaptation."
                    : "Averaging \(Int(avgDeep)) min of deep sleep — solid. Keep the consistent bedtime.",
                metric: "\(Int(avgDeep)) min",
                metricLabel: "Deep Sleep",
                action: low ? "My deep sleep is below 90 minutes average. What can I do to improve it?" : "How is my sleep quality affecting my training?",
                color: low ? TFTheme.accentPurple : TFTheme.accentCyan
            ))
        }

        // Activity / Steps
        if hk.activity.steps > 0 {
            let steps = hk.activity.steps
            let goal = 10_000
            let pct = Double(steps) / Double(goal)
            let stepsStr = steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)"
            insights.append(CoachInsight(
                category: .performance,
                title: pct >= 1.0 ? "Daily Step Goal Crushed" : "Steps Progress Today",
                body: pct >= 1.0
                    ? "You've hit \(stepsStr) steps today. Strong movement habit — consistency compounds over time."
                    : "You're at \(stepsStr) of your 10k step goal. A short walk or active recovery will close the gap.",
                metric: stepsStr,
                metricLabel: "Steps Today",
                action: "How are my daily steps contributing to my overall fitness?",
                color: pct >= 1.0 ? TFTheme.accentGreen : TFTheme.accentBlue
            ))
        }

        return insights.isEmpty ? CoachEngine.proactiveInsights : insights
    }

    // MARK: - Quick Prompts

    private var quickPromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask Your Coach")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
                .padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CoachEngine.quickPrompts) { prompt in
                    QuickPromptButton(prompt: prompt) {
                        showChat = true
                        vm.send(prompt.message)
                    }
                }
            }
        }
    }

    // MARK: - Chat Scroll Area

    private var chatScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if vm.isLoadingHistory {
                        historyLoadingView
                    } else {
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if vm.isTyping {
                            TypingIndicator()
                                .padding(.top, 8)
                                .transition(.opacity)
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }
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
        }
    }

    private var historyLoadingView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ProgressView().tint(TFTheme.accentPurple).scaleEffect(1.3)
            Text("Loading…")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input Bar

    private var sharedInputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.07))
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 15))
                        .foregroundStyle(TFTheme.textTertiary)
                    TextField("No excuses. Talk to Goggins...", text: $vm.inputText, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(TFTheme.textPrimary)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .tint(TFTheme.accentPurple)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(TFTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    inputFocused = false
                    if !showChat { showChat = true }
                    vm.sendCurrentInput()
                } label: {
                    let isEmpty = vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                    ZStack {
                        Circle()
                            .fill(isEmpty ? AnyShapeStyle(TFTheme.bgCard) : AnyShapeStyle(
                                LinearGradient(colors: [TFTheme.accentPurple, TFTheme.accentBlue],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isEmpty ? TFTheme.textTertiary : .white)
                    }
                }
                .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isTyping)
                .animation(.easeInOut(duration: 0.2), value: vm.inputText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(TFTheme.bgPrimary)
        }
    }
}
