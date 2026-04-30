import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var onboardingComplete: Bool = true  // optimistic default
    @State private var profileLoaded = false
    @EnvironmentObject private var auth: AuthService
    @StateObject private var trainingVM = DynamicTrainingViewModel()

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TodayView()
                    .environmentObject(trainingVM)
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                    .tag(0)
                DynamicTrainingView(vm: trainingVM)
                    .tabItem { Label("Training", systemImage: "calendar.badge.clock") }
                    .tag(1)
                HealthView()
                    .tabItem { Label("Health", systemImage: "heart.text.square.fill") }
                    .tag(2)
                PlanProgressView()
                    .environmentObject(trainingVM)
                    .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(3)
                AICoachView()
                    .tabItem { Label("Coach", systemImage: "brain.head.profile.fill") }
                    .tag(4)
            }
            .tint(TFTheme.accentOrange)

            // Cover all tabs while initial data loads to prevent empty-state flicker
            if trainingVM.isLoading && !profileLoaded {
                ZStack {
                    TFTheme.bgPrimary.ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(TFTheme.accentOrange)
                            .scaleEffect(1.4)
                        Text("Loading your plan…")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(TFTheme.textSecondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: trainingVM.isLoading)
        .task {
            await trainingVM.load()
            await checkOnboardingStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAICoachWithMessage)) { _ in
            selectedTab = 4
        }
        .onReceive(NotificationCenter.default.publisher(for: .planDidUpdate)) { _ in
            Task { await trainingVM.load(preserveWeek: true) }
        }
    }

    // MARK: - Onboarding Check

    private func checkOnboardingStatus() async {
        struct ProfileResponse: Decodable {
            let onboardingComplete: Bool?
        }
        do {
            let profile: ProfileResponse = try await APIClient.shared.get("/profile")
            onboardingComplete = profile.onboardingComplete ?? true
            if !onboardingComplete {
                selectedTab = 4  // Land on AI Coach so the coach greets the new user
            }
        } catch {
            NSLog("[MainTabView] Could not load profile: \(error.localizedDescription)")
        }
        profileLoaded = true
    }
}
