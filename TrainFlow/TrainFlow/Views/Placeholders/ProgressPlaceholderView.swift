import SwiftUI

struct ProgressPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 20) {
                    PlaceholderEmptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        color: TFTheme.accentGreen,
                        title: "Progress & Records",
                        subtitle: "Track your training load, personal records, streaks, and body composition trends over time.",
                        buttonTitle: "View Progress"
                    )
                }
            }
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
