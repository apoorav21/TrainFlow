import SwiftUI

// MARK: - Streak & Heatmap Tab
struct ProgressStreakView: View {
    let days: [ActivityDay]
    let currentStreak: Int
    let longestStreak: Int
    let totalWorkouts: Int
    let totalDistance: Double

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                streakHeroRow
                heatmapCard
                legendCard
                statsGrid
                consistencyInsight
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Streak Hero
    private var streakHeroRow: some View {
        HStack(spacing: 10) {
            streakBadge(
                icon: "flame.fill",
                value: "\(currentStreak)",
                label: "Day Streak",
                color: TFTheme.accentOrange
            )
            streakBadge(
                icon: "crown.fill",
                value: "\(longestStreak)",
                label: "Best Streak",
                color: TFTheme.accentYellow
            )
        }
    }

    private func streakBadge(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(TFTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Heatmap
    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity Heatmap")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TFTheme.textPrimary)
                Text("16-week training history")
                    .font(.caption2)
                    .foregroundStyle(TFTheme.textSecondary)
            }

            weekDayLabels
            heatmapGrid
        }
        .padding(16)
        .glassCard()
    }

    private var weekDayLabels: some View {
        HStack(spacing: 0) {
            ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                Text(d)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(TFTheme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var heatmapGrid: some View {
        // Arrange 112 days into 16 weeks × 7 days
        let weeks = stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0 + 7, days.count)])
        }
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 3)],
            spacing: 3
        ) {
            ForEach(weeks.indices, id: \.self) { wi in
                HStack(spacing: 3) {
                    ForEach(weeks[wi]) { day in
                        heatCell(day: day)
                    }
                    // Pad last incomplete week
                    if weeks[wi].count < 7 {
                        ForEach(0..<(7 - weeks[wi].count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clear)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    private func heatCell(day: ActivityDay) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(day.date)
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(day.intensity.color)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isToday ? TFTheme.accentOrange : Color.clear, lineWidth: 1.5)
            )
    }

    // MARK: - Legend
    private var legendCard: some View {
        HStack(spacing: 0) {
            Text("Less")
                .font(.system(size: 10))
                .foregroundStyle(TFTheme.textTertiary)
            Spacer()
            HStack(spacing: 4) {
                ForEach([HeatmapIntensity.none, .light, .moderate, .hard, .peak], id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i.color)
                        .frame(width: 16, height: 16)
                }
            }
            Spacer()
            Text("More")
                .font(.system(size: 10))
                .foregroundStyle(TFTheme.textTertiary)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statTile(value: "\(totalWorkouts)", label: "Total Workouts",
                     icon: "checkmark.seal.fill", color: TFTheme.accentBlue)
            statTile(value: "\(Int(totalDistance)) km", label: "Total Distance",
                     icon: "map.fill", color: TFTheme.accentOrange)
            statTile(value: "\(activeDays)", label: "Active Days (16w)",
                     icon: "calendar.badge.checkmark", color: TFTheme.accentGreen)
            statTile(value: "\(Int(consistency))%", label: "Consistency",
                     icon: "chart.bar.fill", color: TFTheme.accentPurple)
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(TFTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Insight
    private var consistencyInsight: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20))
                .foregroundStyle(TFTheme.accentYellow)
            VStack(alignment: .leading, spacing: 3) {
                Text("Consistency Insight")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFTheme.textPrimary)
                Text("You've been \(Int(consistency))% consistent over the last 16 weeks. Athletes who hit 80%+ consistency see 2× the fitness gains — you're on track!")
                    .font(.system(size: 12))
                    .foregroundStyle(TFTheme.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Computed
    private var activeDays: Int {
        days.filter { $0.load > 0 }.count
    }
    private var consistency: Double {
        let workDays = days.filter { weekday($0.date) != 0 && weekday($0.date) != 6 }.count
        guard workDays > 0 else { return 0 }
        let active = days.filter { weekday($0.date) != 0 && weekday($0.date) != 6 && $0.load > 0 }.count
        return Double(active) / Double(workDays) * 100
    }
    private func weekday(_ date: Date) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }
}

extension HeatmapIntensity: Hashable {}
