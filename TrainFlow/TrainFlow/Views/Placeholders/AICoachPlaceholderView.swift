import SwiftUI

struct AICoachPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    PlaceholderEmptyState(
                        icon: "brain.head.profile.fill",
                        color: TFTheme.accentPurple,
                        title: "AI Coach",
                        subtitle: "Ask anything about your training, recovery, or performance. Your personal AI coach analyzes every metric to give you tailored advice.",
                        buttonTitle: "Start Chat"
                    )
                    aiInsightPreviewCard
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("AI Coach")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var aiInsightPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(TFTheme.accentYellow)
                Text("Weekly Insight Preview")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(TFTheme.accentYellow)
            }
            Text("\"This week you ran 42 km — your best this month. HRV is trending up — you're adapting well to the increased load.\"")
                .font(.system(size: 14))
                .foregroundColor(TFTheme.textSecondary)
                .lineSpacing(3)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}
