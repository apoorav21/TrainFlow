import SwiftUI
import Charts

// MARK: - Plan Progress View (connected to real training plan)
struct PlanProgressView: View {
    @EnvironmentObject private var vm: DynamicTrainingViewModel
    @State private var selectedTab = 0
    private let tabs = ["Overview", "Weekly", "Records"]

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                if vm.plan == nil && !vm.isLoading {
                    noPlanState
                } else {
                    VStack(spacing: 0) {
                        headerBar
                        summaryStrip
                        segmentPicker
                        TabView(selection: $selectedTab) {
                            overviewTab.tag(0)
                            weeklyTab.tag(1)
                            recordsTab.tag(2)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.25), value: selectedTab)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - No Plan State
    private var noPlanState: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(TFTheme.accentOrange.opacity(0.12)).frame(width: 100, height: 100)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(TFTheme.accentOrange)
            }
            VStack(spacing: 10) {
                Text("No Plan Yet")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text("Generate a training plan with your AI Coach to track your progress here.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Progress")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                if let plan = vm.plan {
                    Text(plan.planName)
                        .font(.caption)
                        .foregroundStyle(TFTheme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 22))
                .foregroundStyle(TFTheme.accentGreen)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Summary Strip
    private var summaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                progressChip(value: "\(vm.completedCount)", label: "Done", color: TFTheme.accentGreen, icon: "checkmark.circle.fill")
                progressChip(value: "\(vm.totalCount - vm.completedCount)", label: "Remaining", color: TFTheme.accentOrange, icon: "calendar.badge.clock")
                progressChip(value: "\(Int(vm.progressFraction * 100))%", label: "Complete", color: TFTheme.accentBlue, icon: "chart.pie.fill")
                progressChip(value: "\(vm.weeks.count)", label: "Weeks", color: TFTheme.accentPurple, icon: "calendar")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func progressChip(value: String, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                Text(label).font(.system(size: 10)).foregroundStyle(TFTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Segment
    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = i }
                } label: {
                    VStack(spacing: 4) {
                        Text(tabs[i])
                            .font(.system(size: 13, weight: selectedTab == i ? .semibold : .regular))
                            .foregroundStyle(selectedTab == i ? TFTheme.textPrimary : TFTheme.textSecondary)
                        Capsule()
                            .fill(selectedTab == i ? TFTheme.accentGreen : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 4)
        .overlay(alignment: .bottom) { Divider().background(Color.white.opacity(0.08)) }
    }

    // MARK: - Overview Tab
    private var overviewTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                planProgressCard
                phaseBreakdownCard
                completionHeatmap
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private var planProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Plan Progress")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(TFTheme.textSecondary)
                Spacer()
                Text("\(vm.completedCount) / \(vm.totalCount)")
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(TFTheme.accentOrange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(TFTheme.bgCard).frame(height: 12)
                    RoundedRectangle(cornerRadius: 6).fill(
                        LinearGradient(colors: [TFTheme.accentOrange, TFTheme.accentYellow],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(0, geo.size.width * vm.progressFraction), height: 12)
                    .animation(.spring(response: 0.6), value: vm.progressFraction)
                }
            }
            .frame(height: 12)
            HStack(spacing: 20) {
                progressStat("Completed", "\(vm.completedCount)", TFTheme.accentGreen)
                progressStat("Skipped", "\(skippedCount)", TFTheme.accentRed)
                progressStat("Upcoming", "\(upcomingCount)", TFTheme.accentBlue)
            }
        }
        .padding(18).glassCard()
    }

    private func progressStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.title2, design: .rounded, weight: .black)).foregroundStyle(color)
            Text(label).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var phaseBreakdownCard: some View {
        let phases = phaseStats
        return VStack(alignment: .leading, spacing: 14) {
            Text("Phase Breakdown")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
            ForEach(phases, id: \.name) { phase in
                PhaseProgressRow(name: phase.name, done: phase.done, total: phase.total, color: phase.color)
            }
        }
        .padding(18).glassCard()
    }

    private var completionHeatmap: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Workout Activity")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
            let allDays = vm.workoutDays.sorted { $0.scheduledDate < $1.scheduledDate }
            let chunks = stride(from: 0, to: allDays.count, by: 7).map { Array(allDays[$0..<min($0+7, allDays.count)]) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 5) {
                    ForEach(chunks.indices, id: \.self) { wi in
                        VStack(spacing: 5) {
                            ForEach(chunks[wi]) { day in
                                heatCell(day)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(TFTheme.accentOrange).frame(width: 12, height: 12)
                    Text("Done").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(TFTheme.accentOrange.opacity(0.2)).frame(width: 12, height: 12)
                    Text("Missed").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07)).frame(width: 12, height: 12)
                    Text("Rest / Upcoming").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
                }
            }
        }
        .padding(18).glassCard()
    }

    private func heatCell(_ day: RemoteWorkoutDay) -> some View {
        let isPast = vm.dayDate(day) < Date()
        let fillColor: Color
        if day.isRestDay {
            fillColor = Color.white.opacity(0.05)
        } else if day.isCompleted {
            fillColor = TFTheme.accentOrange
        } else if isPast {
            fillColor = TFTheme.accentOrange.opacity(0.2)
        } else {
            fillColor = Color.white.opacity(0.07)
        }
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fillColor)
            .frame(width: 16, height: 16)
    }

    // MARK: - Weekly Tab
    private var weeklyTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                weeklyChartCard
                ForEach(weekSummaries, id: \.weekNum) { summary in
                    WeekSummaryProgressRow(weekNum: summary.weekNum, completed: summary.completed, total: summary.total, phase: summary.phase)
                }
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private var weeklyChartCard: some View {
        let summaries = weekSummaries
        return VStack(alignment: .leading, spacing: 12) {
            Text("Completion per Week")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
            Chart(summaries, id: \.weekNum) { s in
                BarMark(x: .value("Week", "W\(s.weekNum)"), y: .value("Done", s.completed))
                    .foregroundStyle(s.completed == s.total ? TFTheme.accentGreen : (s.completed > 0 ? TFTheme.accentOrange : TFTheme.bgCard))
                    .cornerRadius(4)
                BarMark(x: .value("Week", "W\(s.weekNum)"), y: .value("Remaining", max(0, s.total - s.completed)))
                    .foregroundStyle(Color.white.opacity(0.06))
                    .cornerRadius(4)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(TFTheme.textTertiary) }
            }
            .frame(height: 100)
        }
        .padding(18).glassCard()
    }

    // MARK: - Records Tab
    private var recordsTab: some View {
        let recs = realRecords
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if recs.isEmpty {
                    VStack(spacing: 16) {
                        Spacer(minLength: 60)
                        Image(systemName: "trophy")
                            .font(.system(size: 48)).foregroundStyle(TFTheme.accentYellow.opacity(0.4))
                        Text("No Personal Records Yet")
                            .font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Complete workouts to start\nbuilding your records.")
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                } else {
                    ForEach(recs) { pr in PRCard(record: pr) }
                }
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private var realRecords: [PersonalRecord] {
        let completed = vm.workoutDays.filter { $0.isCompleted && !$0.isRestDay }
        var records: [PersonalRecord] = []

        func parseKm(_ s: String?) -> Double? {
            guard let s else { return nil }
            let clean = s.lowercased().replacingOccurrences(of: "km", with: "").trimmingCharacters(in: .whitespaces)
            return Double(clean)
        }

        // Longest run
        if let best = completed.filter({ $0.type == "run" })
            .compactMap({ d -> (TFWorkoutDay, Double)? in
                guard let km = parseKm(d.distance) else { return nil }
                return (d, km)
            }).max(by: { $0.1 < $1.1 }) {
            records.append(PersonalRecord(
                event: "Longest Run", icon: "map.fill",
                value: String(format: "%.1f km", best.1),
                detail: best.0.title + " · " + best.0.scheduledDate,
                date: DateFormatter().date(from: best.0.scheduledDate) ?? Date(),
                color: TFTheme.accentPurple, prevValue: nil, improvement: nil
            ))
        }

        // Total workouts completed
        if !completed.isEmpty {
            records.append(PersonalRecord(
                event: "Workouts Done", icon: "checkmark.seal.fill",
                value: "\(completed.count)",
                detail: "Total completed sessions",
                date: Date(), color: TFTheme.accentGreen, prevValue: nil, improvement: nil
            ))
        }

        // Total distance
        let totalKm = completed.compactMap { parseKm($0.distance) }.reduce(0, +)
        if totalKm > 0 {
            records.append(PersonalRecord(
                event: "Total Distance", icon: "figure.run",
                value: String(format: "%.0f km", totalKm),
                detail: "Across all training",
                date: Date(), color: TFTheme.accentOrange, prevValue: nil, improvement: nil
            ))
        }

        // Best week
        let byWeek = Dictionary(grouping: completed) { $0.weekNumber }
        if let bestWeek = byWeek.max(by: { lhs, rhs in
            lhs.value.compactMap({ parseKm($0.distance) }).reduce(0,+) <
            rhs.value.compactMap({ parseKm($0.distance) }).reduce(0,+)
        }) {
            let km = bestWeek.value.compactMap { parseKm($0.distance) }.reduce(0,+)
            if km > 0 {
                records.append(PersonalRecord(
                    event: "Best Week", icon: "calendar.badge.checkmark",
                    value: String(format: "%.0f km", km),
                    detail: "Week \(bestWeek.key)",
                    date: Date(), color: TFTheme.accentBlue, prevValue: nil, improvement: nil
                ))
            }
        }

        return records
    }

    // MARK: - Computed helpers
    private var skippedCount: Int {
        vm.workoutDays.filter { !$0.isCompleted && vm.dayDate($0) < Date() && !$0.isRestDay }.count
    }

    private var upcomingCount: Int {
        vm.workoutDays.filter { !$0.isCompleted && vm.dayDate($0) >= Calendar.current.startOfDay(for: Date()) }.count
    }

    private struct PhaseStat { let name: String; let done: Int; let total: Int; let color: Color }
    private var phaseStats: [PhaseStat] {
        let phases = ["Base", "Build", "Peak", "Taper"]
        let colors: [Color] = [TFTheme.accentBlue, TFTheme.accentOrange, TFTheme.accentRed, TFTheme.accentGreen]
        return zip(phases, colors).compactMap { (phase, color) in
            let days = vm.workoutDays.filter { $0.phase == phase && !$0.isRestDay }
            guard !days.isEmpty else { return nil }
            return PhaseStat(name: phase, done: days.filter(\.isCompleted).count, total: days.count, color: color)
        }
    }

    private struct WeekSummaryData { let weekNum: Int; let completed: Int; let total: Int; let phase: String }
    private var weekSummaries: [WeekSummaryData] {
        vm.weeks.map { week in
            let nonRest = week.filter { !$0.isRestDay }
            return WeekSummaryData(
                weekNum: week.first?.weekNumber ?? 0,
                completed: nonRest.filter(\.isCompleted).count,
                total: nonRest.count,
                phase: week.first?.phase ?? "Base"
            )
        }
    }
}

// MARK: - Phase Progress Row
struct PhaseProgressRow: View {
    let name: String; let done: Int; let total: Int; let color: Color
    private var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(name).font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                }
                Spacer()
                Text("\(done)/\(total)").font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(TFTheme.bgCard).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: max(0, geo.size.width * fraction), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Week Summary Row
struct WeekSummaryProgressRow: View {
    let weekNum: Int
    let completed: Int
    let total: Int
    let phase: String
    private var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    private var phaseColor: Color {
        switch phase {
        case "Build": return TFTheme.accentOrange
        case "Peak": return TFTheme.accentRed
        case "Taper": return TFTheme.accentGreen
        default: return TFTheme.accentBlue
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .center, spacing: 2) {
                Text("W\(weekNum)").font(.system(.caption, design: .rounded, weight: .black)).foregroundStyle(phaseColor)
                Text(phase).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
            }
            .frame(width: 44)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(TFTheme.bgCard).frame(height: 10)
                    RoundedRectangle(cornerRadius: 5).fill(fraction == 1 ? TFTheme.accentGreen : phaseColor)
                        .frame(width: max(0, geo.size.width * fraction), height: 10)
                }
            }
            .frame(height: 10)
            Text("\(completed)/\(total)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - PR Card
struct PRCard: View {
    let record: PersonalRecord

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(record.color.opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: record.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(record.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(record.event).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                Text(record.detail).font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(record.value).font(.system(.subheadline, design: .rounded, weight: .black)).foregroundStyle(record.color)
                if let imp = record.improvement {
                    Text(imp).font(.system(.caption2, design: .rounded, weight: .semibold)).foregroundStyle(TFTheme.accentGreen)
                }
            }
        }
        .padding(14).glassCard(cornerRadius: 14)
    }
}
