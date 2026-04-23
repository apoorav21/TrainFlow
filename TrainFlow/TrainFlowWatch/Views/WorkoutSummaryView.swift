import SwiftUI
#if os(watchOS)
import WatchKit
#endif

// MARK: - Workout Summary View
struct WorkoutSummaryView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager

    private var session: WatchWorkoutSession { manager.session }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                completionHeader
                Divider().opacity(0.3)
                statsGrid
                Divider().opacity(0.3)
                hrSummary
                doneButton
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
        }
    }

    // MARK: - Header
    private var completionHeader: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.green)
            Text("Workout Complete!")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            if let day = manager.todayWorkout {
                Text(day.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                SummaryStat(label: "Duration", value: session.formattedElapsed, icon: "timer", color: Color.orange)
                SummaryStat(label: "Distance", value: "\(session.formattedDistance) km", icon: "figure.run", color: Color.green)
            }
            HStack(spacing: 6) {
                SummaryStat(label: "Calories", value: "\(Int(session.calories))", icon: "flame.fill", color: Color.red)
                SummaryStat(label: "Avg Pace", value: session.formattedPace, icon: "gauge.with.needle", color: Color.cyan)
            }
        }
    }

    // MARK: - HR Summary
    private var hrSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AVG HEART RATE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(session.avgHeartRate))")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(session.hrZone.color)
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PEAK HR")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(session.heartRateSamples.max() ?? 0))")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.red)
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Done Button
    private var doneButton: some View {
        Button(action: {
            #if os(watchOS)
            WKInterfaceDevice.current().play(.click)
            #endif
            manager.resetSession()
        }) {
            Text("Done")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Effort Rating View

struct EffortRatingView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    @State private var crownValue: Double = 5.0
    @FocusState private var crownFocused: Bool

    private var rating: Int { max(1, min(10, Int(crownValue.rounded()))) }

    var body: some View {
        VStack(spacing: 6) {
            Text("How hard was it?")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("\(rating)")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(effortColor(rating))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.08), value: rating)

            // 10-pip progress bar
            HStack(spacing: 2) {
                ForEach(1...10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= rating ? effortColor(i) : Color.white.opacity(0.15))
                        .frame(height: 5)
                        .animation(.easeInOut(duration: 0.08), value: rating)
                }
            }

            Text(effortLabel(rating))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(effortColor(rating))
                .animation(.easeInOut(duration: 0.1), value: rating)

            Button(action: { manager.submitEffortRating(rating) }) {
                Text("Save")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(effortColor(rating))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .animation(.easeInOut(duration: 0.15), value: rating)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .navigationTitle("Effort")
        .navigationBarTitleDisplayMode(.inline)
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: 1.0,
            through: 10.0,
            by: 1.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { crownFocused = true }
    }

    private func effortColor(_ v: Int) -> Color {
        switch v {
        case 1...3: return .green
        case 4...5: return .cyan
        case 6...7: return .yellow
        case 8...9: return .orange
        default:    return .red
        }
    }

    private func effortLabel(_ v: Int) -> String {
        switch v {
        case 1:     return "Very Easy"
        case 2...3: return "Easy"
        case 4...5: return "Moderate"
        case 6...7: return "Hard"
        case 8...9: return "Very Hard"
        default:    return "Max Effort"
        }
    }
}

// MARK: - Summary Stat Card
struct SummaryStat: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
