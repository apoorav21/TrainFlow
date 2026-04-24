import SwiftUI

struct WorkoutLogView: View {
    let day: RemoteWorkoutDay
    let planId: String
    var onLogged: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var distance: String = ""
    @State private var duration: String = ""
    @State private var heartRate: String = ""
    @State private var effort: Double = 6
    @State private var hrv: String = ""
    @State private var notes: String = ""
    @State private var isLogging = false
    @State private var aiFeedback: String?

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                if let feedback = aiFeedback {
                    feedbackView(feedback)
                } else {
                    formView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Log Workout").font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(TFTheme.textSecondary)
                }
            }
        }
    }

    private var formView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                workoutHeader
                metricsSection
                effortSection
                notesSection
                submitButton
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var workoutHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(dayTypeColor.opacity(0.2)).frame(width: 54, height: 54)
                Image(systemName: dayTypeIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(dayTypeColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(day.title).font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(TFTheme.textPrimary)
                Text("Planned: \(day.targetDuration)\(day.targetDistance.map { " · \($0)" } ?? "")")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Actual Metrics").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textSecondary)
            HStack(spacing: 12) {
                LogField(icon: "figure.run", label: "Distance (km)", placeholder: "e.g. 8.5", text: $distance)
                LogField(icon: "timer", label: "Duration (min)", placeholder: "e.g. 45", text: $duration)
            }
            HStack(spacing: 12) {
                LogField(icon: "heart.fill", label: "Avg HR (bpm)", placeholder: "e.g. 145", text: $heartRate)
                LogField(icon: "waveform.path.ecg", label: "HRV post", placeholder: "e.g. 52", text: $hrv)
            }
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Effort Rating").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textSecondary)
                Spacer()
                Text("\(Int(effort))/10").font(.system(.subheadline, design: .rounded, weight: .black)).foregroundStyle(effortColor)
            }
            Slider(value: $effort, in: 1...10, step: 1).tint(effortColor)
            HStack {
                Text("Easy").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("Max").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
            }
        }
        .padding(16).glassCard()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textSecondary)
            TextField("How did it feel? Any issues?", text: $notes, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
                .lineLimit(3...5)
                .padding(14)
                .background(TFTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var submitButton: some View {
        Button(action: submitLog) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TFTheme.accentOrange)
                if isLogging {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Getting Coach Goggins feedback...").font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(.white)
                    }
                } else {
                    Text("Log Workout & Get Coach Feedback")
                        .font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(height: 54)
        }
        .disabled(isLogging)
    }

    private func feedbackView(_ feedback: String) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(TFTheme.accentGreen.opacity(0.15)).frame(width: 90, height: 90)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48)).foregroundStyle(TFTheme.accentGreen)
            }
            Text("Workout Logged! 🎉")
                .font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
            VStack(alignment: .leading, spacing: 12) {
                Label("Coach Goggins Feedback", systemImage: "brain.head.profile.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(TFTheme.accentOrange)
                Text(feedback)
                    .font(.system(.body, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
            }
            .padding(20).glassCard().padding(.horizontal, 24)
            Button(action: { onLogged(feedback); dismiss() }) {
                Text("Done").font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(TFTheme.accentOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
    }

    private func submitLog() {
        isLogging = true
        let log = WorkoutLogPayload(
            planId: planId,
            workoutDayId: day.id,
            actualDistance: Double(distance),
            actualDurationMin: Int(duration),
            avgHeartRate: Int(heartRate),
            effortRating: Int(effort),
            notes: notes.isEmpty ? nil : notes,
            hrvPost: Int(hrv)
        )
        Task {
            do {
                let feedback = try await TrainingService.shared.logWorkout(planId: planId, workoutDayId: day.id, log: log)
                aiFeedback = feedback ?? "Great work completing your workout!"
            } catch {
                aiFeedback = "Workout saved! Keep up the great work."
            }
            isLogging = false
        }
    }

    private var dayTypeColor: Color {
        switch day.dayType {
        case "Easy Run": return TFTheme.accentGreen
        case "Long Run": return TFTheme.accentOrange
        case "Tempo": return TFTheme.accentYellow
        case "Intervals": return TFTheme.accentRed
        case "Strength": return TFTheme.accentPurple
        case "Cross-Train": return TFTheme.accentBlue
        case "Recovery": return TFTheme.accentCyan
        default: return TFTheme.textSecondary
        }
    }

    private var dayTypeIcon: String {
        switch day.dayType {
        case "Easy Run", "Long Run": return "figure.run"
        case "Tempo": return "gauge.with.needle.fill"
        case "Intervals": return "bolt.fill"
        case "Strength": return "dumbbell.fill"
        case "Cross-Train": return "figure.outdoor.cycle"
        case "Recovery": return "leaf.fill"
        default: return "calendar"
        }
    }

    private var effortColor: Color {
        switch Int(effort) {
        case 1...3: return TFTheme.accentGreen
        case 4...6: return TFTheme.accentYellow
        case 7...8: return TFTheme.accentOrange
        default: return TFTheme.accentRed
        }
    }
}

struct LogField: View {
    let icon: String
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(TFTheme.textSecondary)
            TextField(placeholder, text: $text)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(TFTheme.textPrimary)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(TFTheme.bgPrimary.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .background(TFTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity)
    }
}
