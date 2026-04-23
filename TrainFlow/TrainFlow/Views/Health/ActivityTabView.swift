import SwiftUI
import Charts

struct ActivityTabView: View {
    let activity: ActivityMetrics
    var summary: String? = nil

    @State private var expandedSteps = false
    @State private var expandedActivity = false
    @State private var expandedCalories = false
    @State private var expandedMobility = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let s = summary { AISummaryBanner(text: s) }
                stepsHeroCard
                weeklyStepsChart
                activitySummaryCard
                caloriesBreakdownCard
                if activity.walkingSpeed > 0 { mobilityCard }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Steps Hero (expandable)
    private var stepsHeroCard: some View {
        let steps = activity.steps
        let hasSteps = steps > 0
        let goal = 10000
        let pct = hasSteps ? min(Double(steps) / Double(goal), 1.0) : 0

        return VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedSteps.toggle() } }) {
                ZStack {
                    LinearGradient(
                        colors: [TFTheme.accentOrange.opacity(0.3), TFTheme.accentYellow.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 28)).foregroundStyle(TFTheme.accentOrange)
                        Text(hasSteps ? "\(steps)" : "--")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(hasSteps ? TFTheme.textPrimary : TFTheme.textTertiary)
                        Text("Steps Today")
                            .font(.subheadline).foregroundStyle(TFTheme.textSecondary)

                        if hasSteps {
                            VStack(spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.15)).frame(height: 6)
                                        Capsule().fill(TFTheme.accentOrange)
                                            .frame(width: geo.size.width * CGFloat(pct), height: 6)
                                    }
                                }
                                .frame(height: 6).padding(.horizontal, 40)
                                Text(String(format: "%.0f%% of 10,000 goal", pct * 100))
                                    .font(.caption).foregroundStyle(TFTheme.textSecondary)
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: expandedSteps ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                            Text(expandedSteps ? "Less" : "More insights")
                                .font(.caption2).foregroundStyle(TFTheme.textTertiary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 24)
                }
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

            if expandedSteps {
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentOrange,
                               text: "10,000 steps/day is roughly 7–8 km. Research shows that 7,000–8,000 steps provides most of the longevity benefit — the extra 2,000 adds marginal gains.")
                    insightRow(icon: "figure.run", color: TFTheme.accentGreen,
                               text: "On easy/rest days, aim for 8,000+ steps from non-structured walking to promote active recovery and maintain calorie burn.")
                    if hasSteps && steps < 5000 {
                        insightRow(icon: "exclamationmark.triangle.fill", color: TFTheme.accentYellow,
                                   text: "Low step count today. Consider a 20-min walk — it boosts recovery, lowers cortisol, and improves sleep quality.")
                    }
                }
                .padding(16)
                .background(TFTheme.bgCard.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Weekly Steps Chart (real data)
    private var weeklyStepsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartHeader(icon: "chart.bar.fill", color: TFTheme.accentOrange,
                        title: "7-Day Steps", subtitle: "Daily step count from Apple Health")

            let points = activity.weeklySteps.isEmpty
                ? (activity.steps > 0 ? [DayPoint(date: Calendar.current.startOfDay(for: Date()), value: Double(activity.steps))] : [])
                : activity.weeklySteps.map { DayPoint(date: $0.date, value: $0.value) }

            if !points.isEmpty {
                Chart(points) { pt in
                    BarMark(x: .value("Day", shortDay(pt.date)), y: .value("Steps", pt.value))
                        .foregroundStyle(pt.value >= 10000 ? TFTheme.accentGreen : TFTheme.accentOrange.opacity(0.8))
                        .cornerRadius(5)
                    RuleMark(y: .value("Goal", 10000))
                        .foregroundStyle(TFTheme.accentGreen.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartXAxis {
                    AxisMarks { AxisValueLabel().foregroundStyle(TFTheme.textSecondary) }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 5000, 10000]) {
                        AxisValueLabel().foregroundStyle(TFTheme.textSecondary)
                    }
                }
                .frame(height: 130)
            } else {
                noDataView(message: "Step data not available. Ensure Health access is granted.")
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Activity Summary (expandable)
    private var activitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedActivity.toggle() } }) {
                HStack {
                    Image(systemName: "circle.circle.fill").foregroundStyle(TFTheme.accentRed).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Activity Summary").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Today's metrics").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedActivity ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                activityCell(icon: "flame.fill", color: TFTheme.accentRed,
                             label: "Active Cal",
                             value: activity.activeCalories > 0 ? "\(activity.activeCalories)" : "--",
                             unit: "kcal", goal: "650")
                activityCell(icon: "figure.run", color: TFTheme.accentOrange,
                             label: "Distance",
                             value: activity.distance > 0 ? String(format: "%.1f", activity.distance) : "--",
                             unit: "km", goal: "8.0")
                activityCell(icon: "clock.fill", color: TFTheme.accentBlue,
                             label: "Exercise",
                             value: activity.exerciseMinutes > 0 ? "\(activity.exerciseMinutes)" : "--",
                             unit: "min", goal: "45")
                activityCell(icon: "arrow.up.to.line", color: TFTheme.accentGreen,
                             label: "Flights",
                             value: activity.flightsClimbed > 0 ? "\(activity.flightsClimbed)" : "--",
                             unit: "floors", goal: "10")
            }

            if expandedActivity {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentRed,
                               text: "WHO guidelines: 150–300 min of moderate activity per week, or 75–150 min of vigorous activity. Structured running counts as vigorous.")
                    if activity.exerciseMinutes > 0 {
                        let weeklyTarget = 150
                        let needed = max(0, weeklyTarget - activity.exerciseMinutes * 7)
                        insightRow(icon: "calendar.badge.clock", color: TFTheme.accentBlue,
                                   text: "At today's pace, you need \(needed) more minutes by end of week to hit the weekly target.")
                    }
                    insightRow(icon: "figure.run", color: TFTheme.accentGreen,
                               text: "Flights climbed is a great low-impact supplement on rest days. 10 floors = ~100m of elevation gain.")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func activityCell(icon: String, color: Color, label: String,
                               value: String, unit: String, goal: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Spacer()
                Text("/ \(goal)").font(.caption2).foregroundStyle(TFTheme.textTertiary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(value == "--" ? TFTheme.textTertiary : TFTheme.textPrimary)
            Text("\(unit) · \(label)")
                .font(.caption2).foregroundStyle(TFTheme.textSecondary)
        }
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Calories Breakdown (expandable)
    private var caloriesBreakdownCard: some View {
        let hasBasal  = activity.basalCalories > 0
        let active = Double(activity.activeCalories)
        let basal  = Double(activity.basalCalories)
        let total  = active + basal

        return VStack(alignment: .leading, spacing: 14) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedCalories.toggle() } }) {
                HStack {
                    Image(systemName: "flame.fill").foregroundStyle(TFTheme.accentRed).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calorie Breakdown").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Total vs active vs basal").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedCalories ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if total > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f", total))
                        .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                    Text("kcal total").font(.subheadline).foregroundStyle(TFTheme.textSecondary)
                }
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(TFTheme.accentRed)
                            .frame(width: geo.size.width * CGFloat(active / total) - 2)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(TFTheme.accentOrange.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 14)
                HStack(spacing: 16) {
                    calLegend(color: TFTheme.accentRed, label: "Active", value: String(format: "%.0f kcal", active))
                    calLegend(color: TFTheme.accentOrange.opacity(0.7), label: "Basal", value: String(format: "%.0f kcal", basal))
                }
            } else {
                noDataView(message: "Calorie data not available. Ensure Health access is granted.")
            }

            if expandedCalories {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentRed,
                               text: "Basal calories are what your body burns at rest (breathing, organ function). Active calories come from movement. Total = basal + active.")
                    if hasBasal {
                        insightRow(icon: "chart.pie.fill", color: TFTheme.accentOrange,
                                   text: "Your basal metabolic rate makes up \(Int(basal / max(total, 1) * 100))% of total daily expenditure — typical for a trained athlete.")
                    }
                    insightRow(icon: "fork.knife", color: TFTheme.accentGreen,
                               text: "On heavy training days (>700 active kcal), ensure you're eating enough to fuel recovery — chronic underfuelling suppresses performance and hormones.")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Mobility Card (expandable, only shown if data exists)
    private var mobilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedMobility.toggle() } }) {
                HStack {
                    Image(systemName: "figure.walk.motion").foregroundStyle(TFTheme.accentCyan).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mobility Metrics").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Gait & movement quality").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedMobility ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                mobilityCell(icon: "speedometer", color: TFTheme.accentCyan, label: "Walking Speed",
                             value: String(format: "%.1f", activity.walkingSpeed), unit: "km/h")
                Divider().frame(width: 1).background(Color.white.opacity(0.1)).padding(.vertical, 10)
                mobilityCell(icon: "figure.walk", color: TFTheme.accentPurple, label: "Avg HR Walk",
                             value: "--", unit: "bpm")
            }

            if expandedMobility {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentCyan,
                               text: "Walking speed is a surprisingly powerful health predictor. Studies show it correlates strongly with longevity — faster walkers live longer.")
                    insightRow(icon: "target", color: TFTheme.accentGreen,
                               text: "A walking speed above 4.8 km/h is associated with significantly lower cardiovascular risk. Elite runners typically walk at 5.5–6.5 km/h normally.")
                    if activity.walkingSpeed > 0 {
                        let (label, color) = walkSpeedCategory(activity.walkingSpeed)
                        insightRow(icon: "checkmark.circle.fill", color: color,
                                   text: "\(String(format: "%.1f", activity.walkingSpeed)) km/h — \(label)")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func walkSpeedCategory(_ speed: Double) -> (String, Color) {
        if speed >= 5.5 { return ("excellent — well above average", TFTheme.accentGreen) }
        if speed >= 4.8 { return ("good — within healthy range", TFTheme.accentBlue) }
        return ("below optimal — aim for brisker daily walks", TFTheme.accentYellow)
    }

    private func mobilityCell(icon: String, color: Color, label: String, value: String, unit: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(value == "--" ? TFTheme.textTertiary : TFTheme.textPrimary)
            Text(unit).font(.caption2).foregroundStyle(TFTheme.textSecondary)
            Text(label).font(.system(size: 10)).foregroundStyle(TFTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers
    private func calLegend(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label): \(value)").font(.caption).foregroundStyle(TFTheme.textSecondary)
        }
    }

    private func chartHeader(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                Text(subtitle).font(.caption2).foregroundStyle(TFTheme.textSecondary)
            }
            Spacer()
        }
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18).padding(.top, 1)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func noDataView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(TFTheme.textTertiary)
            Text(message).font(.caption).foregroundStyle(TFTheme.textTertiary)
        }
        .padding(.vertical, 8)
    }

    private func shortDay(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date)
    }
}

struct DayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
