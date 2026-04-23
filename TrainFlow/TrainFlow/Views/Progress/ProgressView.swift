import SwiftUI
import Charts

struct TrainingProgressView: View {
    @State private var selectedTab = 0
    private let tabs = ["Load", "Records", "Streaks"]
    @EnvironmentObject private var trainingVM: DynamicTrainingViewModel
    @StateObject private var hk = HealthKitManager.shared
    @State private var workoutLogs: [TFWorkoutLog] = []

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerBar
                    summaryStrip
                    segmentPicker
                    TabView(selection: $selectedTab) {
                        ProgressLoadView(loads: weeklyLoadData).tag(0)
                        ProgressRecordsView(records: personalRecords).tag(1)
                        ProgressStreakView(
                            days: activityHeatmap,
                            currentStreak: currentStreak,
                            longestStreak: longestStreak,
                            totalWorkouts: completedCount,
                            totalDistance: totalDistanceKm
                        ).tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: selectedTab)
                }
            }
            .navigationBarHidden(true)
            .task {
                workoutLogs = (try? await TrainingService.shared.fetchWorkouts(days: 365)) ?? []
            }
        }
    }

    // MARK: - Computed real data

    private var completedDays: [TFWorkoutDay] {
        trainingVM.workoutDays.filter { $0.isCompleted && !$0.isRestDay }
    }

    private var completedCount: Int { completedDays.count }

    private var totalDistanceKm: Double {
        completedDays.compactMap { parseKm($0.distance) }.reduce(0, +)
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        let sorted = trainingVM.workoutDays
            .filter { $0.isCompleted }
            .compactMap { day -> Date? in
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                return f.date(from: day.scheduledDate)
            }
            .sorted(by: >)
        guard let first = sorted.first else { return 0 }
        var streak = 0
        var check = cal.startOfDay(for: Date())
        if !cal.isDate(first, inSameDayAs: check) &&
           !cal.isDate(first, inSameDayAs: cal.date(byAdding: .day, value: -1, to: check)!) {
            return 0
        }
        for d in sorted {
            if cal.isDate(d, inSameDayAs: check) || cal.isDate(d, inSameDayAs: cal.date(byAdding: .day, value: -1, to: check)!) {
                streak += 1
                check = cal.startOfDay(for: d)
            } else { break }
        }
        return streak
    }

    private var longestStreak: Int {
        let cal = Calendar.current
        let dates = trainingVM.workoutDays
            .filter { $0.isCompleted }
            .compactMap { day -> Date? in
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                return f.date(from: day.scheduledDate)
            }
            .map { cal.startOfDay(for: $0) }
        let sorted = Array(Set(dates)).sorted()
        guard !sorted.isEmpty else { return 0 }
        var best = 1; var current = 1
        for i in 1..<sorted.count {
            let diff = cal.dateComponents([.day], from: sorted[i-1], to: sorted[i]).day ?? 0
            if diff == 1 { current += 1; best = max(best, current) } else { current = 1 }
        }
        return best
    }

    private var thisWeekKm: Double {
        trainingVM.currentWeekDays
            .filter { $0.isCompleted }
            .compactMap { parseKm($0.distance) }
            .reduce(0, +)
    }

    private var weeklyLoadData: [WeeklyLoad] {
        guard !trainingVM.workoutDays.isEmpty else { return [] }
        let cal = Calendar.current
        let grouped = Dictionary(grouping: completedDays) { day -> Date in
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let d = f.date(from: day.scheduledDate) ?? Date()
            return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d))!
        }
        let labelFmt = DateFormatter(); labelFmt.dateFormat = "MMM d"
        return grouped.keys.sorted().suffix(12).map { weekStart in
            let days = grouped[weekStart] ?? []
            let km = days.compactMap { parseKm($0.distance) }.reduce(0, +)
            let mins = days.compactMap { parseMins($0.duration) }.reduce(0, +)
            return WeeklyLoad(
                weekOffset: cal.dateComponents([.weekOfYear], from: weekStart, to: Date()).weekOfYear ?? 0,
                label: labelFmt.string(from: weekStart),
                acuteLoad: km, chronicLoad: km * 0.85,
                tsb: -km * 0.15,
                distanceKm: km, durationMin: mins, sessionCount: days.count
            )
        }
    }

    private var activityHeatmap: [ActivityDay] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let completedSet = Set(trainingVM.workoutDays.filter { $0.isCompleted }.map { $0.scheduledDate })
        let cal = Calendar.current
        return (0..<112).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: Date())!
            let key = f.string(from: d)
            return ActivityDay(date: d, load: completedSet.contains(key) ? 6.0 : 0.0)
        }
    }

    private var personalRecords: [PersonalRecord] {
        var records: [PersonalRecord] = []
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"

        // Longest completed run
        if let best = completedDays.filter({ $0.type == "run" })
            .compactMap({ d -> (TFWorkoutDay, Double)? in
                guard let km = parseKm(d.distance) else { return nil }
                return (d, km)
            }).max(by: { $0.1 < $1.1 }) {
            records.append(PersonalRecord(
                event: "Longest Run",
                icon: "map.fill",
                value: String(format: "%.1f km", best.1),
                detail: best.0.title + " · " + best.0.scheduledDate,
                date: f.date(from: best.0.scheduledDate) ?? Date(),
                color: TFTheme.accentPurple,
                prevValue: nil, improvement: nil
            ))
        }

        // Most weekly distance
        let weeklyBest = weeklyLoadData.max(by: { $0.distanceKm < $1.distanceKm })
        if let wb = weeklyBest, wb.distanceKm > 0 {
            records.append(PersonalRecord(
                event: "Best Week",
                icon: "calendar.badge.checkmark",
                value: String(format: "%.0f km", wb.distanceKm),
                detail: "Week of \(wb.label)",
                date: Date(),
                color: TFTheme.accentBlue,
                prevValue: nil, improvement: nil
            ))
        }

        // Total workouts completed
        if completedCount > 0 {
            records.append(PersonalRecord(
                event: "Workouts Done",
                icon: "checkmark.seal.fill",
                value: "\(completedCount)",
                detail: "Total completed sessions",
                date: Date(),
                color: TFTheme.accentGreen,
                prevValue: nil, improvement: nil
            ))
        }

        // Total distance
        if totalDistanceKm > 0 {
            records.append(PersonalRecord(
                event: "Total Distance",
                icon: "figure.run",
                value: String(format: "%.0f km", totalDistanceKm),
                detail: "Across all training",
                date: Date(),
                color: TFTheme.accentOrange,
                prevValue: nil, improvement: nil
            ))
        }

        return records
    }

    // MARK: - Helpers

    private func parseKm(_ s: String?) -> Double? {
        guard let s else { return nil }
        let clean = s.lowercased().replacingOccurrences(of: "km", with: "").trimmingCharacters(in: .whitespaces)
        return Double(clean)
    }

    private func parseMins(_ s: String?) -> Int {
        guard let s else { return 0 }
        let clean = s.lowercased()
        if let m = clean.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init).first {
            return m
        }
        return 0
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Progress")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text("Based on your training")
                    .font(.caption)
                    .foregroundStyle(TFTheme.textSecondary)
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
                summaryChip(value: hk.heart.vo2Max > 0 ? String(format: "%.0f", hk.heart.vo2Max) : "—",
                            label: "VO₂ Max", color: TFTheme.accentBlue, icon: "bolt.heart.fill")
                summaryChip(value: thisWeekKm > 0 ? String(format: "%.0f km", thisWeekKm) : "0 km",
                            label: "This Week", color: TFTheme.accentOrange, icon: "figure.run")
                summaryChip(value: "\(currentStreak)d",
                            label: "Streak", color: TFTheme.accentYellow, icon: "flame.fill")
                summaryChip(value: "\(personalRecords.count)",
                            label: "All-Time PRs", color: TFTheme.accentGreen, icon: "trophy.fill")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func summaryChip(value: String, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(TFTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.08))
        }
    }
}
