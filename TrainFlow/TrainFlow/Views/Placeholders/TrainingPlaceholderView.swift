import SwiftUI

struct TrainingPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 20) {
                    PlaceholderEmptyState(
                        icon: "calendar.badge.clock",
                        color: TFTheme.accentOrange,
                        title: "Your Training Plan",
                        subtitle: "Set a goal and get a personalized, adaptive training plan built around your fitness level and schedule.",
                        buttonTitle: "Create Plan"
                    )
                }
            }
            .navigationTitle("Training")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
