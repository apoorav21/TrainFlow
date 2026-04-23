import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager

    var body: some View {
        Group {
            switch manager.phase {
            case .notStarted:
                TodayWorkoutView()
            case .active, .paused:
                ActiveWorkoutView()
            case .effortRating:
                EffortRatingView()
            case .summary:
                WorkoutSummaryView()
            }
        }
        .environmentObject(manager)
    }
}
