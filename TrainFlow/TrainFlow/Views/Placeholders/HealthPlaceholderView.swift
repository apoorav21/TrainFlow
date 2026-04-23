import SwiftUI

struct HealthPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 20) {
                    PlaceholderEmptyState(
                        icon: "heart.text.square.fill",
                        color: TFTheme.accentRed,
                        title: "Health Metrics",
                        subtitle: "Connect HealthKit to see all your vitals — heart rate, HRV, sleep, body composition, respiratory, and more — in one place.",
                        buttonTitle: "Connect Health"
                    )
                }
            }
            .navigationTitle("Health")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
