import SwiftUI
import Charts

struct SleepTabView: View {
    let nights: [NightSleep]
    var summary: String? = nil

    @State private var expandedStages = false
    @State private var expandedWeekly = false
    @State private var expandedStats = false

    private var lastNight: NightSleep? { nights.last }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let s = summary { AISummaryBanner(text: s) }
                if let night = lastNight {
                    sleepHeroCard(night)
                    stageBreakdownCard(night)
                }
                weeklyBarsCard
                sleepStatsGrid
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Hero (expandable)
    private func sleepHeroCard(_ night: NightSleep) -> some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [TFTheme.accentPurple.opacity(0.35), TFTheme.accentBlue.opacity(0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                VStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 32)).foregroundStyle(TFTheme.accentPurple)
                    Text(String(format: "%.1f hrs", night.totalHours))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(TFTheme.textPrimary)
                    Text("Last Night · \(sleepQualityLabel(night))")
                        .font(.subheadline).foregroundStyle(TFTheme.textSecondary)
                    sleepScoreBadge(night)
                }
                .padding(.vertical, 28)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func sleepScoreBadge(_ night: NightSleep) -> some View {
        let score = Int(night.consistency * 100)
        let color = score > 80 ? TFTheme.accentGreen : score > 60 ? TFTheme.accentYellow : TFTheme.accentRed
        return HStack(spacing: 6) {
            Image(systemName: "star.fill").font(.caption)
            Text("Sleep Score \(score)").font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(color.opacity(0.15)).clipShape(Capsule())
    }

    private func sleepQualityLabel(_ night: NightSleep) -> String {
        let deep = night.stages.first(where: { $0.stage == .deep })?.minutes ?? 0
        if deep > 75 { return "Excellent recovery" }
        if deep > 55 { return "Good sleep" }
        return "Light sleep"
    }

    // MARK: - Stage Breakdown (expandable)
    private func stageBreakdownCard(_ night: NightSleep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedStages.toggle() } }) {
                HStack {
                    Image(systemName: "chart.bar.fill").foregroundStyle(TFTheme.accentPurple).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Stages").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Last night's breakdown").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedStages ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            stageBar(night)
            stageLegendRow(night)

            Divider().background(Color.white.opacity(0.08))
            HStack {
                stageStatCell(icon: "wind", color: TFTheme.accentCyan,
                              label: "Resp. Rate",
                              value: String(format: "%.1f br/min", night.respiratoryRate))
                Divider().frame(height: 30).background(Color.white.opacity(0.1))
                stageStatCell(icon: "clock.fill", color: TFTheme.accentBlue,
                              label: "Time in Bed",
                              value: String(format: "%.1f hrs", night.totalHours + 0.3))
            }

            if expandedStages {
                Divider().background(Color.white.opacity(0.08))
                let deep = night.stages.first(where: { $0.stage == .deep })?.minutes ?? 0
                let rem  = night.stages.first(where: { $0.stage == .rem })?.minutes ?? 0
                let light = night.stages.first(where: { $0.stage == .core })?.minutes ?? 0
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentPurple,
                               text: "Sleep cycles through light → deep → REM roughly every 90 min. You need both deep sleep (body repair) and REM (memory, mood) to fully recover.")
                    insightRow(icon: "moon.zzz.fill", color: TFTheme.accentBlue,
                               text: "Deep sleep target: 80–90 min. Yours: \(Int(deep)) min. \(deep < 65 ? "Below target — try a consistent bedtime and cooler room (18°C)." : "On track!")")
                    insightRow(icon: "sparkles", color: TFTheme.accentYellow,
                               text: "REM target: 90+ min. Yours: \(Int(rem)) min. \(rem < 80 ? "Alcohol and late exercise significantly suppress REM — avoid both within 3 hrs of sleep." : "Great REM — supports memory consolidation and performance.")")
                    insightRow(icon: "bed.double.fill", color: TFTheme.accentCyan,
                               text: "Core (light) sleep: \(Int(light)) min. It bridges deep and REM cycles — healthy amounts support memory consolidation and physical restoration.")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func stageBar(_ night: NightSleep) -> some View {
        let total = night.stages.reduce(0) { $0 + $1.minutes }
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(SleepStage.allCases, id: \.self) { stage in
                    let mins = night.stages.first(where: { $0.stage == stage })?.minutes ?? 0
                    let fraction = total > 0 ? CGFloat(mins / total) : 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stage.color)
                        .frame(width: max(fraction * geo.size.width - 2, 0))
                }
            }
        }
        .frame(height: 16)
    }

    private func stageLegendRow(_ night: NightSleep) -> some View {
        HStack(spacing: 12) {
            ForEach(SleepStage.allCases, id: \.self) { stage in
                let mins = night.stages.first(where: { $0.stage == stage })?.minutes ?? 0
                HStack(spacing: 5) {
                    Circle().fill(stage.color).frame(width: 8, height: 8)
                    Text("\(stage.rawValue) \(Int(mins))m")
                        .font(.system(size: 11)).foregroundStyle(TFTheme.textSecondary)
                }
            }
        }
    }

    private func stageStatCell(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                Text(label).font(.caption2).foregroundStyle(TFTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly Bars (expandable)
    private var weeklyBarsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedWeekly.toggle() } }) {
                HStack {
                    Image(systemName: "moon.stars.fill").foregroundStyle(TFTheme.accentBlue).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("7-Day Sleep").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Goal: 8 hrs per night").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedWeekly ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if nights.isEmpty {
                Text("No sleep data available. Wear Apple Watch while sleeping.")
                    .font(.caption).foregroundStyle(TFTheme.textTertiary).padding(.vertical, 8)
            } else {
                Chart(nights) { night in
                    BarMark(x: .value("Day", shortDay(night.date)), y: .value("Hours", night.totalHours))
                        .foregroundStyle(night.totalHours >= 7 ? TFTheme.accentPurple : TFTheme.accentRed.opacity(0.7))
                        .cornerRadius(4)
                    RuleMark(y: .value("Goal", 8))
                        .foregroundStyle(TFTheme.accentGreen.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartXAxis {
                    AxisMarks { AxisValueLabel().foregroundStyle(TFTheme.textSecondary) }
                }
                .chartYAxis {
                    AxisMarks(values: [4, 6, 8]) {
                        AxisValueLabel().foregroundStyle(TFTheme.textSecondary)
                    }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 130)
            }

            if expandedWeekly && !nights.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                let avg = nights.reduce(0) { $0 + $1.totalHours } / Double(nights.count)
                let nightsBelow7 = nights.filter { $0.totalHours < 7 }.count
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "moon.fill", color: TFTheme.accentPurple,
                               text: "7-day average: \(String(format: "%.1f", avg)) hrs. \(avg >= 7.5 ? "Excellent — you're hitting the optimal range for athletic recovery." : "Below the 7.5 hr optimal target for athletes.")")
                    if nightsBelow7 > 2 {
                        insightRow(icon: "exclamationmark.triangle.fill", color: TFTheme.accentYellow,
                                   text: "\(nightsBelow7) nights below 7 hrs this week. Cumulative sleep debt reduces reaction time, power output, and raises injury risk.")
                    }
                    insightRow(icon: "clock.fill", color: TFTheme.accentBlue,
                               text: "The most impactful change: a consistent wake time (including weekends). This anchors your circadian rhythm more powerfully than any other single habit.")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Stats Grid (expandable)
    private var sleepStatsGrid: some View {
        let avg = nights.isEmpty ? 0.0 : nights.reduce(0) { $0 + $1.totalHours } / Double(nights.count)
        let deep = lastNight?.stages.first(where: { $0.stage == .deep })?.minutes ?? 0
        let rem  = lastNight?.stages.first(where: { $0.stage == .rem })?.minutes ?? 0
        let consistency = (lastNight?.consistency ?? 0) * 100

        return VStack(spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedStats.toggle() } }) {
                HStack {
                    Image(systemName: "chart.xyaxis.line").foregroundStyle(TFTheme.accentGreen).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Stats").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Key metrics at a glance").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedStats ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                sleepStatCard(icon: "moon.fill", color: TFTheme.accentPurple,
                              label: "7-Day Avg",
                              value: avg > 0 ? String(format: "%.1f hrs", avg) : "--")
                sleepStatCard(icon: "moon.zzz.fill", color: TFTheme.accentCyan,
                              label: "Deep Sleep",
                              value: lastNight != nil ? "\(Int(deep)) min" : "--")
                sleepStatCard(icon: "sparkles", color: TFTheme.accentYellow,
                              label: "REM Sleep",
                              value: lastNight != nil ? "\(Int(rem)) min" : "--")
                sleepStatCard(icon: "checkmark.circle.fill", color: TFTheme.accentGreen,
                              label: "Consistency",
                              value: lastNight != nil ? String(format: "%.0f%%", consistency) : "--")
            }

            sleepInsightCard(deep: deep, rem: rem)

            if expandedStats {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentPurple,
                               text: "Sleep consistency (going to bed & waking at similar times) is as important as total duration. Irregular sleep disrupts the circadian rhythm and impairs recovery.")
                    insightRow(icon: "moon.zzz.fill", color: TFTheme.accentBlue,
                               text: "Deep sleep targets: 80–90 min. REM targets: 90–120 min. If consistently short, evaluate your caffeine cutoff time (aim for noon) and evening light exposure.")
                    insightRow(icon: "figure.run", color: TFTheme.accentGreen,
                               text: "Performance impact: each hour of sleep below your optimal reduces sprint power by ~3% and slows reaction time. Over a training block, this compounds significantly.")
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func sleepInsightCard(deep: Double, rem: Double) -> some View {
        let isGood = deep > 65 && rem > 85
        let icon = isGood ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        let color = isGood ? TFTheme.accentGreen : TFTheme.accentYellow
        let msg = isGood
            ? "Great recovery last night — deep & REM targets met. You're ready for hard training."
            : "Deep sleep below optimal. Consider earlier bedtime & limiting screens before bed."
        return HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(msg).font(.caption).foregroundStyle(TFTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private func sleepStatCard(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(value == "--" ? TFTheme.textTertiary : TFTheme.textPrimary)
                Text(label).font(.caption).foregroundStyle(TFTheme.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
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

    private func shortDay(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date)
    }
}
