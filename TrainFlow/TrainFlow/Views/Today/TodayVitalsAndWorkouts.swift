import SwiftUI
import Charts

// MARK: - Vital Stats Row (tappable)
extension TodayView {
    var vitalStatsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Health")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(TFTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    TappableVitalCard(
                        icon: "heart.fill", label: "Resting HR",
                        value: hk.heart.restingHR > 0 ? "\(hk.heart.restingHR)" : "—",
                        unit: "bpm", color: TFTheme.accentRed,
                        trend: hrTrend, metric: .heartRate, hk: hk
                    )
                    TappableVitalCard(
                        icon: "waveform.path.ecg", label: "HRV",
                        value: hk.heart.hrv > 0 ? "\(Int(hk.heart.hrv))" : "—",
                        unit: "ms", color: TFTheme.accentPurple,
                        trend: hrvTrend, metric: .hrv, hk: hk
                    )
                    TappableVitalCard(
                        icon: "moon.fill", label: "Sleep",
                        value: sleepValue,
                        unit: "hrs", color: TFTheme.accentBlue,
                        trend: sleepTrend, metric: .sleep, hk: hk
                    )
                    TappableVitalCard(
                        icon: "lungs.fill", label: "VO₂ Max",
                        value: hk.heart.vo2Max > 0 ? String(format: "%.1f", hk.heart.vo2Max) : "—",
                        unit: "mL/kg", color: TFTheme.accentCyan,
                        trend: "Cardio fitness", metric: .vo2Max, hk: hk
                    )
                    TappableVitalCard(
                        icon: "figure.walk", label: "Steps",
                        value: hk.activity.steps > 0 ? stepsFormatted : "—",
                        unit: "steps", color: TFTheme.accentGreen,
                        trend: "Today", metric: .steps, hk: hk
                    )
                    TappableVitalCard(
                        icon: "flame.fill", label: "Active Cal",
                        value: hk.activity.activeCalories > 0 ? "\(hk.activity.activeCalories)" : "—",
                        unit: "kcal", color: TFTheme.accentOrange,
                        trend: "Active energy", metric: .activeCalories, hk: hk
                    )
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var hrTrend: String {
        let t = hk.heart.restingHRTrend
        if t == 0 { return "Stable" }
        return t < 0 ? "↓ \(Int(abs(t))) bpm" : "↑ \(Int(t)) bpm"
    }

    private var hrvTrend: String {
        let t = hk.heart.hrvTrend
        if t == 0 { return "Stable" }
        return t > 0 ? "↑ \(Int(t)) ms" : "↓ \(Int(abs(t))) ms"
    }

    private var sleepValue: String {
        guard let last = hk.sleepNights.last else { return "—" }
        return String(format: "%.1f", last.totalHours)
    }

    private var sleepTrend: String {
        guard let last = hk.sleepNights.last else { return "No data" }
        switch last.totalHours {
        case ..<6: return "Short night"
        case 6..<7: return "Fair"
        case 7..<9: return "Good"
        default: return "Well rested"
        }
    }

    private var stepsFormatted: String {
        let n = hk.activity.steps
        if n >= 1000 {
            let k = Double(n) / 1000.0
            return String(format: "%.1f k", k)
        }
        return "\(n)"
    }
}

// MARK: - Tappable Vital Card
struct TappableVitalCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color
    let trend: String
    let metric: HealthMetricType
    @ObservedObject var hk: HealthKitManager
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(color)
                    Text(label)
                        .font(.system(size: 11, weight: .medium)).foregroundColor(TFTheme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold)).foregroundColor(TFTheme.textTertiary)
                }
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(TFTheme.textPrimary)
                    Text(unit).font(.system(size: 11)).foregroundColor(TFTheme.textTertiary)
                }
                Text(trend).font(.system(size: 11, weight: .medium)).foregroundColor(color.opacity(0.9))
            }
            .frame(width: 130).padding(14)
            .glassCard(cornerRadius: 16)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            HealthDetailSheet(metric: metric, hk: hk)
        }
    }
}

// MARK: - Legacy WorkoutRow (kept for compatibility)
struct WorkoutRow: View {
    let workout: RecentWorkout

    var body: some View {
        HStack(spacing: 14) {
            workoutIcon
            workoutInfo
            Spacer()
            workoutStats
        }
        .padding(14).glassCard(cornerRadius: 14)
    }

    private var workoutIcon: some View {
        ZStack {
            Circle().fill(workout.type.color.opacity(0.15))
            Image(systemName: workout.type.icon)
                .font(.system(size: 16, weight: .semibold)).foregroundColor(workout.type.color)
        }
        .frame(width: 42, height: 42)
    }

    private var workoutInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(workout.title).font(.system(size: 15, weight: .semibold)).foregroundColor(TFTheme.textPrimary)
            Text(relativeDate).font(.system(size: 12)).foregroundColor(TFTheme.textTertiary)
        }
    }

    private var workoutStats: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(durationText).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(TFTheme.textPrimary)
            if let dist = workout.distance {
                Text(String(format: "%.1f km", dist)).font(.system(size: 12)).foregroundColor(TFTheme.textSecondary)
            } else {
                Text("\(workout.calories) cal").font(.system(size: 12)).foregroundColor(TFTheme.textSecondary)
            }
        }
    }

    private var durationText: String { "\(Int(workout.duration) / 60) min" }

    private var relativeDate: String {
        let days = Calendar.current.dateComponents([.day], from: workout.date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }
}
