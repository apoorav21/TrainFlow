import SwiftUI

// MARK: - ViewModel
@MainActor
final class DynamicTrainingViewModel: ObservableObject {
    @Published var plan: RemotePlan?
    @Published var workoutDays: [RemoteWorkoutDay] = []
    @Published var selectedWeekIndex = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPlanChat = false
    @Published var showAdaptChat = false
    @Published var selectedDay: RemoteWorkoutDay?
    @Published var logDay: RemoteWorkoutDay?
    @Published var adaptReply: String?
    @Published var recentActivity: [WorkoutActivity] = []
    @Published var showAllActivity = false
    @Published var selectedActivity: WorkoutActivity?

    // Calendar weeks: each entry is 7 slots Mon(0)…Sun(6), nil = no workout that day
    var calendarWeeks: [[RemoteWorkoutDay?]] {
        guard !workoutDays.isEmpty else { return [] }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current

        func monday(of date: Date) -> Date {
            let wd = cal.component(.weekday, from: date) // 1=Sun…7=Sat
            let sub = wd == 1 ? 6 : wd - 2
            return cal.startOfDay(for: cal.date(byAdding: .day, value: -sub, to: date)!)
        }

        // Collect unique Monday dates across all workout days
        var mondaySet = Set<Date>()
        for day in workoutDays {
            if let d = f.date(from: day.scheduledDate) { mondaySet.insert(monday(of: d)) }
        }

        // Build lookup: dateStr → workout day
        let lookup = Dictionary(uniqueKeysWithValues: workoutDays.compactMap { d -> (String, RemoteWorkoutDay)? in
            (d.scheduledDate, d)
        })

        return mondaySet.sorted().map { mon in
            (0..<7).map { offset -> RemoteWorkoutDay? in
                guard let slotDate = cal.date(byAdding: .day, value: offset, to: mon) else { return nil }
                return lookup[f.string(from: slotDate)]
            }
        }
    }

    // Kept for compatibility — used only by todayWorkout / other non-grid code
    var weeks: [[RemoteWorkoutDay]] {
        guard !workoutDays.isEmpty else { return [] }
        let sorted = workoutDays.sorted { $0.scheduledDate < $1.scheduledDate }
        var result: [[RemoteWorkoutDay]] = []; var current: [RemoteWorkoutDay] = []
        var currentWeek = sorted.first?.weekNumber ?? 1
        for day in sorted {
            if day.weekNumber != currentWeek { result.append(current); current = []; currentWeek = day.weekNumber }
            current.append(day)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    var currentCalendarWeek: [RemoteWorkoutDay?] {
        calendarWeeks.indices.contains(selectedWeekIndex) ? calendarWeeks[selectedWeekIndex] : []
    }
    var currentWeekDays: [RemoteWorkoutDay] { currentCalendarWeek.compactMap { $0 } }
    var todayWorkout: RemoteWorkoutDay? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let todayStr = f.string(from: Date())
        return workoutDays.first { $0.scheduledDate == todayStr }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            plan = try await TrainingService.shared.fetchActivePlan()
            if let p = plan {
                workoutDays = try await TrainingService.shared.fetchWorkoutDays(planId: p.id)
                setCurrentWeek()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        if let today = todayWorkout {
            PhoneSessionManager.shared.sendTodayWorkout(today)
        }
        await loadActivity()
    }

    func loadActivity() async {
        do {
            let raw = try await TrainingService.shared.fetchRecentActivity()
            recentActivity = deduplicateActivity(raw)
        } catch {
            // Non-critical — silently fail so plan view still works
        }
    }

    private func deduplicateActivity(_ activities: [WorkoutActivity]) -> [WorkoutActivity] {
        let hk = activities.filter { $0.isHealthKit }
        let tf = activities.filter { !$0.isHealthKit }
        let cal = Calendar.current
        var remove = Set<String>()
        for t in tf {
            guard let tDate = t.displayDate else { continue }
            let tType = (t.workoutType ?? "").lowercased().filter { !$0.isWhitespace }
            for h in hk {
                guard let hDate = h.displayDate else { continue }
                let hType = (h.workoutType ?? "").lowercased().filter { !$0.isWhitespace }
                guard cal.isDate(tDate, inSameDayAs: hDate) else { continue }
                if tType == hType || hType.contains(tType) || tType.contains(hType) {
                    // Prefer TrainFlow record when it has effort rating; otherwise use HealthKit
                    if t.effortRating != nil {
                        remove.insert(h.id)
                    } else {
                        remove.insert(t.id)
                    }
                    break
                }
            }
        }
        return activities.filter { !remove.contains($0.id) }
    }

    func deleteActivity(_ activity: WorkoutActivity) {
        guard let ts = activity.timestamp else { return }
        recentActivity.removeAll { $0.id == activity.id }
        Task {
            try? await TrainingService.shared.deleteActivity(timestamp: ts)
        }
        // kept for API compatibility but no longer exposed in UI
    }

    func markComplete(_ day: RemoteWorkoutDay) {
        guard let idx = workoutDays.firstIndex(where: { $0.id == day.id }) else { return }
        workoutDays[idx].isCompleted = true
        workoutDays[idx].completedAt = ISO8601DateFormatter().string(from: Date())
        let planId = plan?.id ?? ""
        Task { try? await TrainingService.shared.markDayComplete(planId: planId, daySK: day.planWeekDay) }
    }

    func getAdaptAdvice(message: String) async {
        guard let planId = plan?.id else { return }
        do {
            adaptReply = try await TrainingService.shared.adaptPlan(planId: planId, message: message)
            // Reload plan data so changes appear immediately
            await load()
        } catch {
            adaptReply = error.localizedDescription
        }
    }

    private func setCurrentWeek() {
        let today = Calendar.current.startOfDay(for: Date())
        for (i, week) in calendarWeeks.enumerated() {
            if week.compactMap({ $0 }).contains(where: { dayDate($0) >= today }) {
                selectedWeekIndex = i; return
            }
        }
        selectedWeekIndex = max(0, calendarWeeks.count - 1)
    }

    func dayDate(_ day: RemoteWorkoutDay) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: day.scheduledDate) ?? Date()
    }

    // Pass "\(day.type) \(day.title)" so canonical DB type is checked before title keywords.
    // e.g. "cross_training Cycling Rest Day" → blue (not textTertiary), because "cross" appears first.
    func dayTypeColor(_ combined: String) -> Color {
        let t = combined.lowercased()
        if t.contains("interval") || t.contains("speed") { return TFTheme.accentRed }
        if t.contains("tempo") { return TFTheme.accentYellow }
        if t.contains("long") { return TFTheme.accentOrange }
        if t.contains("strength") { return TFTheme.accentPurple }
        if t.contains("cross") || t.contains("cycl") { return TFTheme.accentBlue }
        if t.contains("swim") { return TFTheme.accentCyan }
        if t.contains("recover") || t.contains("rest") { return TFTheme.accentCyan }
        if t.contains("easy") { return TFTheme.accentGreen }
        if t.contains("race") { return TFTheme.accentOrange }
        if t.contains("run") { return TFTheme.accentGreen }
        return TFTheme.accentGreen
    }

    func dayTypeIcon(_ combined: String) -> String {
        let t = combined.lowercased()
        if t.contains("strength") { return "dumbbell.fill" }
        if t.contains("cross") || t.contains("cycling") { return "figure.outdoor.cycle" }
        if t.contains("rest") { return "moon.zzz.fill" }
        if t.contains("swim") { return "figure.pool.swim" }
        if t.contains("interval") || t.contains("speed") { return "bolt.fill" }
        if t.contains("tempo") { return "gauge.with.needle.fill" }
        if t.contains("recover") { return "leaf.fill" }
        if t.contains("race") { return "flag.checkered" }
        return "figure.run"
    }

    func activityIcon(_ a: WorkoutActivity) -> String {
        let t = (a.workoutType ?? "").lowercased()
        if t.contains("cycling") || t.contains("bike") { return "figure.outdoor.cycle" }
        if t.contains("swim") { return "figure.pool.swim" }
        if t.contains("walk") { return "figure.walk" }
        if t.contains("hik") { return "figure.hiking" }
        if t.contains("strength") || t.contains("hiit") || t.contains("functional") { return "dumbbell.fill" }
        if t.contains("yoga") || t.contains("pilates") { return "figure.yoga" }
        if t.contains("row") { return "figure.rowing" }
        if t.contains("elliptical") || t.contains("stair") { return "figure.stair.stepper" }
        return "figure.run"
    }

    func activityColor(_ a: WorkoutActivity) -> Color {
        let t = (a.workoutType ?? "").lowercased()
        if t.contains("run") || t.contains("walk") || t.contains("hik") { return TFTheme.accentOrange }
        if t.contains("cycl") || t.contains("bike") || t.contains("row") || t.contains("elliptical") { return TFTheme.accentBlue }
        if t.contains("swim") { return TFTheme.accentCyan }
        if t.contains("strength") || t.contains("hiit") || t.contains("functional") || t.contains("cross") { return TFTheme.accentPurple }
        if t.contains("yoga") || t.contains("pilates") || t.contains("recov") { return TFTheme.accentGreen }
        return TFTheme.accentOrange
    }

    func goalTypeDisplay(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var completedCount: Int { workoutDays.filter(\.isCompleted).count }
    var totalCount: Int { workoutDays.count }
    var progressFraction: Double { totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0 }
}

// MARK: - Main View
struct DynamicTrainingView: View {
    @ObservedObject var vm: DynamicTrainingViewModel
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                Group {
                    if vm.isLoading && vm.plan == nil {
                        loadingView
                    } else if vm.plan == nil {
                        emptyState
                    } else {
                        planContent
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            // Loading is now driven by MainTabView.task — no re-load on tab switch
            .fullScreenCover(isPresented: $vm.showPlanChat) {
                PlanChatView(isPresented: $vm.showPlanChat) { Task { await vm.load() } }
            }
            .sheet(item: $vm.selectedDay) { day in
                WorkoutDayRemoteDetailView(day: day, vm: vm)
            }
            .sheet(item: $vm.logDay) { day in
                WorkoutLogView(day: day, planId: vm.plan?.id ?? "") { feedback in
                    vm.markComplete(day)
                }
            }
            .sheet(isPresented: $vm.showAdaptChat) {
                AdaptPlanSheet(vm: vm)
            }
            .sheet(item: $vm.selectedActivity) { activity in
                WorkoutDetailSheet(activity: activity, vm: vm)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Training").font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
        }
        if vm.plan != nil {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { vm.showAdaptChat = true }) {
                        Image(systemName: "brain.head.profile.fill").foregroundStyle(TFTheme.accentOrange)
                    }
                    Button(action: { vm.showPlanChat = true }) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(TFTheme.accentOrange)
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5).tint(TFTheme.accentOrange)
            Text("Loading your plan...").font(.system(.body, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(TFTheme.accentOrange.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "figure.run")
                    .font(.system(size: 52, weight: .semibold)).foregroundStyle(TFTheme.accentOrange)
            }
            VStack(spacing: 12) {
                Text("No Training Plan Yet")
                    .font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                Text("Chat with Coach Goggins to create a personalised plan tailored to your goals and fitness level.")
                    .font(.system(.body, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Button(action: { vm.showPlanChat = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Chat with Coach Goggins")
                }
                .font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(.white)
                .frame(maxWidth: 280, minHeight: 54)
                .background(TFTheme.accentOrange)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Spacer()
        }.padding(24)
    }

    private var planContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let plan = vm.plan { planHero(plan) }
                todayCard
                weekSelector
                if !vm.currentWeekDays.isEmpty { weekGrid }
                if !vm.recentActivity.isEmpty { pastActivitySection }
                Spacer(minLength: 32)
            }.padding(.top, 8)
        }
        .refreshable {
            await HealthSyncService.shared.syncNow()
            await vm.loadActivity()
        }
    }

    // MARK: - Plan Hero
    private func planHero(_ plan: RemotePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.planName)
                        .font(.system(.title2, design: .rounded, weight: .black)).foregroundStyle(TFTheme.textPrimary)
                    Text(vm.goalTypeDisplay(plan.goalType))
                        .font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(daysUntil(plan.goalDate)).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(TFTheme.accentOrange)
                    Text("days to go").font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                }
            }
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Plan Progress").font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                    Spacer()
                    Text("\(vm.completedCount)/\(vm.totalCount) workouts")
                        .font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(TFTheme.accentOrange)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(TFTheme.bgCard).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(TFTheme.accentOrange)
                            .frame(width: geo.size.width * vm.progressFraction, height: 8)
                    }
                }.frame(height: 8)
            }
            HStack(spacing: 16) {
                planStat(label: "Level", value: plan.fitnessLevel.isEmpty ? "—" : plan.fitnessLevel.capitalized, color: TFTheme.accentBlue)
                planStat(label: "Days/Week", value: "\(plan.daysPerWeek)", color: TFTheme.accentPurple)
                planStat(label: "Goal Date", value: shortDate(plan.goalDate), color: TFTheme.accentGreen)
            }
        }
        .padding(18).glassCard().padding(.horizontal, 20)
    }

    @ViewBuilder
    private var todayCard: some View {
        if let today = vm.todayWorkout {
            Button(action: { vm.selectedDay = today }) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(vm.dayTypeColor("\(today.type) \(today.dayType)").opacity(0.2)).frame(width: 56, height: 56)
                        Image(systemName: vm.dayTypeIcon("\(today.type) \(today.dayType)"))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(vm.dayTypeColor("\(today.type) \(today.dayType)"))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TODAY").font(.system(.caption2, design: .rounded, weight: .black)).foregroundStyle(vm.dayTypeColor("\(today.type) \(today.dayType)"))
                        Text(today.title).font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                        HStack(spacing: 6) {
                            Text(today.targetDuration).font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                            if let d = today.targetDistance {
                                Text("·").foregroundStyle(TFTheme.textTertiary)
                                Text(d).font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(TFTheme.textTertiary)
                }
                .padding(16).glassCard()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    private var weekSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.calendarWeeks.indices, id: \.self) { i in
                    let slots = vm.calendarWeeks[i]
                    let isSelected = i == vm.selectedWeekIndex
                    let phase = slots.compactMap { $0 }.first?.phase ?? "Base"
                    let pColor = phaseColor(phase)
                    Button(action: { withAnimation(.spring(response: 0.3)) { vm.selectedWeekIndex = i } }) {
                        VStack(spacing: 4) {
                            Text("Wk \(i + 1)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(isSelected ? .white : TFTheme.textSecondary)
                            Circle().fill(isSelected ? Color.white : pColor).frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(isSelected ? pColor : TFTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }.padding(.horizontal, 20)
        }
    }

    private let calendarDayHeaders = ["M","T","W","T","F","S","S"]

    private var weekGrid: some View {
        VStack(spacing: 12) {
            let slots = vm.currentCalendarWeek
            let phase = slots.compactMap { $0 }.first?.phase ?? "Base"
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(phaseColor(phase)).frame(width: 8, height: 8)
                    Text("\(phase) Phase").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(phaseColor(phase))
                }
                Spacer()
            }.padding(.horizontal, 20)

            // Fixed Mon–Sun header
            HStack(spacing: 6) {
                ForEach(calendarDayHeaders.indices, id: \.self) { i in
                    Text(calendarDayHeaders[i])
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(TFTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }.padding(.horizontal, 20)

            // 7 slots — real workout day or empty placeholder
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    if let day = (slots.indices.contains(i) ? slots[i] : nil) {
                        RemoteDayCell(day: day, vm: vm)
                            .onTapGesture { if !day.isRestDay { vm.selectedDay = day } }
                    } else {
                        EmptyDayCell()
                    }
                }
            }.padding(.horizontal, 20)
        }
    }

    // MARK: - Past Activity Section

    private var pastActivitySection: some View {
        let displayed = vm.showAllActivity
            ? vm.recentActivity
            : Array(vm.recentActivity.prefix(8))
        let remaining = vm.recentActivity.count - 8

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Past Activity")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(TFTheme.textSecondary)
                Spacer()
                Text("\(vm.recentActivity.count) workouts")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(TFTheme.textTertiary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(displayed) { activity in
                    Button { vm.selectedActivity = activity } label: {
                        ActivityFeedRow(activity: activity, vm: vm)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }

            if remaining > 0 && !vm.showAllActivity {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { vm.showAllActivity = true }
                } label: {
                    Text("Show \(remaining) more")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(TFTheme.accentOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TFTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    private func daysUntil(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
        return "\(max(0, days))"
    }

    private func shortDate(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return dateStr }
        let out = DateFormatter(); out.dateFormat = "MMM d"; return out.string(from: d)
    }

    private func phaseColor(_ phase: String) -> Color {
        switch phase {
        case "Base": return TFTheme.accentBlue
        case "Build": return TFTheme.accentOrange
        case "Peak": return TFTheme.accentRed
        case "Taper": return TFTheme.accentGreen
        default: return TFTheme.accentBlue
        }
    }

    private func planStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Remote Day Cell
// MARK: - Empty Day Cell (no workout scheduled)
struct EmptyDayCell: View {
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 52)
                Text("—")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.15))
            }
            Text(" ").font(.system(.caption2, design: .rounded))
        }
        .frame(maxWidth: .infinity)
    }
}

struct RemoteDayCell: View {
    let day: RemoteWorkoutDay
    let vm: DynamicTrainingViewModel
    private var isToday: Bool {
        Calendar.current.isDate(vm.dayDate(day), inSameDayAs: Date())
    }
    private var color: Color { vm.dayTypeColor("\(day.type) \(day.dayType)") }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isToday ? color : (day.isCompleted ? color.opacity(0.3) : TFTheme.bgCard))
                    .frame(height: 52)
                if day.isRestDay {
                    Image(systemName: "moon.zzz.fill").font(.system(size: 14)).foregroundStyle(isToday ? .white : color)
                } else {
                    VStack(spacing: 3) {
                        Image(systemName: vm.dayTypeIcon("\(day.type) \(day.dayType)"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isToday ? .white : color)
                        if day.isCompleted {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 8)).foregroundStyle(TFTheme.accentGreen)
                        }
                    }
                }
            }
            let dateNum = String(day.scheduledDate.suffix(2).prefix(while: { !$0.isWhitespace }))
            Text(dateNum.hasPrefix("0") ? String(dateNum.dropFirst()) : dateNum)
                .font(.system(.caption2, design: .rounded, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? color : TFTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Workout Day Detail (Remote)
struct WorkoutDayRemoteDetailView: View {
    let day: RemoteWorkoutDay
    let vm: DynamicTrainingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLogView = false
    @State private var aiReport: String?
    @State private var isGeneratingReport = false

    private var accentColor: Color { vm.dayTypeColor("\(day.type) \(day.dayType)") }

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        heroCard
                        if day.warmup != nil || day.mainSet != nil || day.cooldown != nil || day.exercises != nil {
                            structuredWorkoutSection
                        } else if day.coachMessage == nil {
                            // Only show fallback when there is no coach message (avoids duplicate text)
                            instructionsFallbackCard
                        }
                        if let msg = day.coachMessage {
                            coachMessageCard(msg)
                        }
                        if !day.isCompleted {
                            logButton
                        } else {
                            completedBadge
                            if isGeneratingReport {
                                reportLoadingCard
                            } else if let report = aiReport ?? day.aiReport {
                                aiReportCard(report)
                            }
                        }
                        Spacer(minLength: 40)
                    }.padding(.horizontal, 20).padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(day.title).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(TFTheme.accentOrange)
                }
            }
            .onAppear {
                aiReport = day.aiReport
                if day.isCompleted && day.aiReport == nil {
                    isGeneratingReport = PhoneSessionManager.shared.lastWorkoutReport == nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .workoutReportReady)) { note in
                guard let report = note.userInfo?["report"] as? WorkoutReport,
                      report.planWeekDay == day.planWeekDay else { return }
                withAnimation { isGeneratingReport = false; aiReport = report.aiReport }
                Task { await vm.load() }
            }
        }
    }

    // MARK: - Hero
    private var heroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accentColor.opacity(0.15)).frame(width: 60, height: 60)
                Image(systemName: vm.dayTypeIcon("\(day.type) \(day.dayType)"))
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(day.dayType).font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(accentColor)
                HStack(spacing: 10) {
                    Label(day.targetDuration, systemImage: "timer")
                    if let d = day.targetDistance { Label(d, systemImage: "figure.run") }
                    if let p = day.targetPace { Label(p, systemImage: "speedometer") }
                }
                .font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                if let z = day.targetHRZone {
                    hrZoneBadge(z)
                }
            }
            Spacer()
        }
        .padding(18).glassCard()
    }

    private func hrZoneBadge(_ zone: Int) -> some View {
        let colors: [Int: Color] = [1: .cyan, 2: .green, 3: .yellow, 4: .orange, 5: .red]
        let color = colors[zone] ?? .orange
        return HStack(spacing: 4) {
            Image(systemName: "heart.fill").font(.system(size: 10))
            Text("Zone \(zone) Target").font(.system(.caption2, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Structured Workout
    @ViewBuilder
    private var structuredWorkoutSection: some View {
        if let warmup = day.warmup {
            workoutSectionCard(
                icon: "sunrise.fill", title: "Warm Up", color: .cyan,
                detail: sectionDetail(warmup),
                pace: warmup.targetPace, hrZone: warmup.hrZone,
                intervals: nil
            )
        }

        if let ms = day.mainSet {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(icon: "bolt.fill", title: "Main Set", color: accentColor, pace: ms.targetPace, hrZone: ms.hrZone)
                if let detail = ms.description {
                    Text(detail)
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                        .padding(.horizontal, 18).padding(.bottom, 12)
                }
                if let intervals = ms.intervals, !intervals.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(intervals.enumerated()), id: \.offset) { i, iv in
                            intervalRow(iv, index: i)
                            if i < intervals.count - 1 {
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 18)
                            }
                        }
                    }
                }
            }
            .glassCard()
        }

        if let exs = day.exercises, !exs.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader(icon: "dumbbell.fill", title: "Exercises", color: TFTheme.accentPurple, pace: nil, hrZone: nil)
                VStack(spacing: 0) {
                    ForEach(Array(exs.enumerated()), id: \.offset) { i, ex in
                        exerciseRow(ex)
                        if i < exs.count - 1 {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 18)
                        }
                    }
                }
            }
            .glassCard()
        }

        if let cooldown = day.cooldown {
            workoutSectionCard(
                icon: "sunset.fill", title: "Cool Down", color: TFTheme.accentBlue,
                detail: sectionDetail(cooldown),
                pace: cooldown.targetPace, hrZone: cooldown.hrZone,
                intervals: nil
            )
        }
    }

    private func sectionDetail(_ s: WorkoutSection) -> String {
        var parts: [String] = []
        if let d = s.durationMin { parts.append("\(Int(d)) min") }
        if let desc = s.description { parts.append(desc) }
        return parts.joined(separator: " — ")
    }

    private func sectionHeader(icon: String, title: String, color: Color, pace: String?, hrZone: Int?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color).frame(width: 22)
            Text(title).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(color)
            Spacer()
            if let p = pace {
                Text(p).font(.system(.caption, design: .monospaced, weight: .medium)).foregroundStyle(TFTheme.textSecondary)
            }
            if let z = hrZone {
                let zColors: [Int: Color] = [1: .cyan, 2: .green, 3: .yellow, 4: .orange, 5: .red]
                Text("Z\(z)").font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(zColors[z] ?? .orange)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    private func workoutSectionCard(icon: String, title: String, color: Color, detail: String, pace: String?, hrZone: Int?, intervals: [WorkoutInterval]?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: icon, title: title, color: color, pace: pace, hrZone: hrZone)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(.subheadline, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                    .padding(.horizontal, 18).padding(.bottom, 12)
            }
        }
        .glassCard()
    }

    private func intervalRow(_ iv: WorkoutInterval, index: Int) -> some View {
        let isRest = iv.type == "rest" || iv.type == "recovery"
        let color: Color = isRest ? .green : accentColor
        return HStack(spacing: 12) {
            Rectangle().fill(color).frame(width: 3).padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(isRest ? "Recovery" : "Interval \(index / 2 + 1)")
                        .font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(color)
                    Spacer()
                    if let p = iv.targetPace {
                        Text(p).font(.system(.caption, design: .monospaced)).foregroundStyle(TFTheme.textSecondary)
                    }
                    if let z = iv.hrZone {
                        let zc: [Int: Color] = [1: .cyan, 2: .green, 3: .yellow, 4: .orange, 5: .red]
                        Text("Z\(z)").font(.system(.caption2, design: .rounded, weight: .bold)).foregroundStyle(zc[z] ?? .orange)
                    }
                }
                HStack(spacing: 8) {
                    if let d = iv.durationMin { Text("\(d < 1 ? String(format: "%.0f sec", d * 60) : String(format: "%.0f min", d))").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textSecondary) }
                    if let km = iv.distanceKm { Text("\(String(format: "%.1f", km)) km").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textSecondary) }
                    if let n = iv.notes { Text(n).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary).lineLimit(1) }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(color.opacity(0.04))
    }

    private func exerciseRow(_ ex: WorkoutExercise) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(TFTheme.accentPurple.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: "dumbbell.fill").font(.system(size: 13)).foregroundStyle(TFTheme.accentPurple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(ex.name).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                HStack(spacing: 8) {
                    let sets = ex.sets ?? 3
                    let repsStr = ex.reps.map { "\(sets) × \($0)" } ?? "\(sets) sets"
                    Text(repsStr).font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                    if let rest = ex.restSec { Text("· \(rest)s rest").font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textTertiary) }
                }
                if let notes = ex.notes { Text(notes).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary).lineLimit(2) }
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    // MARK: - Fallback / Coach
    private var instructionsFallbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout Instructions", systemImage: "list.bullet.clipboard.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textSecondary)
            Text(day.instructions).font(.system(.body, design: .rounded)).foregroundStyle(TFTheme.textPrimary).lineSpacing(4)
        }
        .padding(18).glassCard()
    }

    private func coachMessageCard(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(icon: "brain.head.profile.fill", title: "Coach Goggins",
                          color: TFTheme.accentOrange, pace: nil, hrZone: nil)
            Text(msg)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
                .padding(.horizontal, 18).padding(.bottom, 12)
        }
        .glassCard()
    }

    // MARK: - Buttons
    private var logButton: some View {
        Button(action: { showLogView = true }) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                Text("Mark Complete & Log")
            }
            .font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(TFTheme.accentOrange)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .sheet(isPresented: $showLogView) {
            WorkoutLogView(day: day, planId: vm.plan?.id ?? "") { _ in
                vm.markComplete(day)
                dismiss()
            }
        }
    }

    private var completedBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 22)).foregroundStyle(TFTheme.accentGreen)
            Text("Workout Completed!").font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.accentGreen)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(TFTheme.accentGreen.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var reportLoadingCard: some View {
        HStack(spacing: 14) {
            ProgressView().tint(TFTheme.accentOrange).scaleEffect(0.9)
            VStack(alignment: .leading, spacing: 2) {
                Text("Generating AI Report").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                Text("Your coach is analysing your workout…").font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
            }
        }
        .padding(18).glassCard()
    }

    private func aiReportCard(_ report: String) -> some View {
        let suggestion = day.nextWorkoutSuggestion
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(TFTheme.accentOrange.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "brain.head.profile.fill").font(.system(size: 16)).foregroundStyle(TFTheme.accentOrange)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Post-Workout Report").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                    Text("Coach Goggins").font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.accentOrange)
                }
                Spacer()
                Image(systemName: "sparkles").foregroundStyle(TFTheme.accentOrange).font(.system(size: 14))
            }
            Divider().background(Color.white.opacity(0.08))
            Text(report)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
                .lineSpacing(5)

            if let suggestion = suggestion {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    Label("Next Workout Suggestion", systemImage: "arrow.forward.circle.fill")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(TFTheme.accentBlue)
                    Text(suggestion)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                        .lineSpacing(3)
                    Button(action: {
                        let msg = "Based on my last workout, you suggested: \"\(suggestion)\" — can you implement this change to my next session?"
                        NotificationCenter.default.post(
                            name: .openAICoachWithMessage,
                            object: nil,
                            userInfo: ["message": msg]
                        )
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "brain.head.profile.fill").font(.system(size: 13))
                            Text("Discuss & Apply with Coach")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(TFTheme.accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding(18).glassCard()
    }
}

// MARK: - Activity Feed Row

struct ActivityFeedRow: View {
    let activity: WorkoutActivity
    let vm: DynamicTrainingViewModel

    private var color: Color { vm.activityColor(activity) }
    private var icon: String { vm.activityIcon(activity) }

    var body: some View {
        HStack(spacing: 14) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(color)
            }

            // Name + stats
            VStack(alignment: .leading, spacing: 5) {
                Text(activity.workoutType ?? "Workout")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(TFTheme.textPrimary)
                    .lineLimit(1)
                // Row 1: distance · duration · pace
                HStack(spacing: 10) {
                    if let dist = activity.displayDistanceKm {
                        Label(String(format: "%.2f km", dist), systemImage: "figure.run")
                    }
                    if let dur = activity.displayDurationMin {
                        let durStr = dur >= 60 ? "\(dur / 60)h \(dur % 60)m" : "\(dur)m"
                        Label(durStr, systemImage: "timer")
                    }
                    if let pace = activity.displayPace {
                        Label(pace, systemImage: "speedometer")
                    }
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                // Row 2: avg HR · peak HR · calories (only if data present)
                let hasHR = activity.avgHeartRate != nil || activity.displayPeakHR != nil
                let hasCal = activity.calories != nil
                if hasHR || hasCal {
                    HStack(spacing: 8) {
                        if let hr = activity.avgHeartRate {
                            Label("\(hr)", systemImage: "heart.fill")
                                .foregroundStyle(TFTheme.accentRed)
                        }
                        if let peak = activity.displayPeakHR {
                            Label("\(peak)pk", systemImage: "heart.fill")
                                .foregroundStyle(TFTheme.accentRed.opacity(0.7))
                        }
                        if let cal = activity.calories {
                            Label("\(Int(cal)) kcal", systemImage: "flame.fill")
                                .foregroundStyle(TFTheme.accentOrange)
                        }
                    }
                    .font(.system(.caption, design: .rounded))
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            // Date + source — fixed width so it never squeezes the stats column
            VStack(alignment: .trailing, spacing: 4) {
                if let date = activity.displayDate {
                    Text(relativeDate(date))
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(TFTheme.textSecondary)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(activity.isHealthKit ? TFTheme.accentBlue : TFTheme.accentOrange)
                        .frame(width: 5, height: 5)
                    Text(activity.displaySource)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(TFTheme.textTertiary)
                        .lineLimit(1)
                }
                if let effort = activity.effortRating {
                    effortDots(effort)
                }
            }
            .frame(width: 82, alignment: .trailing)
        }
        .padding(14)
        .glassCard()
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 { return "\(days)d ago" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func effortDots(_ effort: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= effort ? TFTheme.accentOrange : TFTheme.bgCard)
                    .frame(width: 5, height: 5)
            }
        }
    }
}

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
    let activity: WorkoutActivity
    let vm: DynamicTrainingViewModel
    @Environment(\.dismiss) private var dismiss

    private var color: Color { vm.activityColor(activity) }
    private var icon: String { vm.activityIcon(activity) }

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        statsGrid
                        if activity.avgHeartRate != nil || activity.displayPeakHR != nil {
                            heartRateCard
                        }
                        if activity.calories != nil || activity.effortRating != nil || activity.notes != nil {
                            extraCard
                        }
                        analyzeButton
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(activity.workoutType ?? "Workout")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(TFTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(TFTheme.accentOrange)
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(0.15)).frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(activity.workoutType ?? "Workout")
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .foregroundStyle(TFTheme.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(activity.isHealthKit ? TFTheme.accentBlue : TFTheme.accentOrange)
                        .frame(width: 6, height: 6)
                    Text(activity.displaySource)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                }
                if let date = activity.displayDate {
                    Text(fullDate(date))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(TFTheme.textTertiary)
                }
            }
            Spacer()
        }
        .padding(18).glassCard()
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let hasDistance = activity.displayDistanceKm != nil
        let hasDuration = activity.displayDurationMin != nil
        let hasPace = activity.displayPace != nil

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if hasDistance {
                statCell(
                    value: String(format: "%.2f", activity.displayDistanceKm!),
                    unit: "km",
                    label: "Distance",
                    icon: "figure.run",
                    color: color
                )
            }
            if hasDuration {
                let d = activity.displayDurationMin!
                statCell(
                    value: d >= 60 ? "\(d / 60):\(String(format: "%02d", d % 60))" : "\(d)",
                    unit: d >= 60 ? "h:m" : "min",
                    label: "Duration",
                    icon: "timer",
                    color: TFTheme.accentBlue
                )
            }
            if hasPace {
                statCell(
                    value: activity.displayPace!.replacingOccurrences(of: " /km", with: ""),
                    unit: "/km",
                    label: "Avg Pace",
                    icon: "speedometer",
                    color: TFTheme.accentPurple
                )
            }
        }
    }

    private func statCell(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                Text(unit).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
            }
            Text(label).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Heart Rate

    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Heart Rate", systemImage: "heart.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.accentRed)

            HStack(spacing: 16) {
                if let avg = activity.avgHeartRate {
                    hrStat(value: "\(avg)", label: "Avg BPM", color: TFTheme.accentOrange)
                }
                if let peak = activity.displayPeakHR {
                    hrStat(value: "\(peak)", label: "Peak BPM", color: TFTheme.accentRed)
                }
            }
        }
        .padding(18).glassCard()
    }

    private func hrStat(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill").font(.system(size: 14)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                Text(label).font(.system(.caption2, design: .rounded)).foregroundStyle(TFTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Extra Details

    private var extraCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let cal = activity.calories {
                detailRow(icon: "flame.fill", label: "Calories", value: String(format: "%.0f kcal", cal), color: TFTheme.accentOrange)
            }
            if let effort = activity.effortRating {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "dial.medium.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(effortColor(effort))
                            .frame(width: 22)
                        Text("Perceived Effort")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(TFTheme.textSecondary)
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(effort)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(effortColor(effort))
                            Text("/ 10")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(TFTheme.textTertiary)
                        }
                    }
                    HStack(spacing: 3) {
                        ForEach(1...10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i <= effort ? effortColor(i) : TFTheme.bgCard)
                                .frame(height: 10)
                        }
                    }
                    Text(effortLabel(effort))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(effortColor(effort))
                }
            }
            if let notes = activity.notes, !notes.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 6) {
                    Label("Notes", systemImage: "note.text")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(TFTheme.textTertiary)
                    Text(notes)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(TFTheme.textPrimary)
                        .lineSpacing(3)
                }
            }
        }
        .padding(18).glassCard()
    }

    private func detailRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color).frame(width: 22)
            Text(label).font(.system(.subheadline, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
            Spacer()
            Text(value).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
        }
    }

    private func effortColor(_ v: Int) -> Color {
        switch v {
        case 1...3: return TFTheme.accentGreen
        case 4...5: return TFTheme.accentCyan
        case 6...7: return TFTheme.accentYellow
        case 8...9: return TFTheme.accentOrange
        default:    return TFTheme.accentRed
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

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        Button(action: analyzeWithAI) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile.fill")
                Text("Analyze with Coach Goggins")
            }
            .font(.system(.body, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(TFTheme.accentOrange)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func analyzeWithAI() {
        var parts: [String] = []

        let type = activity.workoutType ?? "Workout"
        if let date = activity.displayDate {
            parts.append("I completed a \(type) on \(fullDate(date)).")
        } else {
            parts.append("I completed a \(type).")
        }

        if let dist = activity.displayDistanceKm {
            parts.append("Distance: \(String(format: "%.2f", dist)) km.")
        }
        if let dur = activity.displayDurationMin {
            let h = dur / 60; let m = dur % 60
            parts.append("Duration: \(h > 0 ? "\(h)h \(m)min" : "\(m) min").")
        }
        if let pace = activity.displayPace {
            parts.append("Average pace: \(pace).")
        }
        if let avg = activity.avgHeartRate {
            parts.append("Average HR: \(avg) bpm.")
        }
        if let peak = activity.displayPeakHR {
            parts.append("Peak HR: \(peak) bpm.")
        }
        if let cal = activity.calories {
            parts.append("Calories burned: \(Int(cal)) kcal.")
        }
        if let effort = activity.effortRating {
            parts.append("Perceived effort: \(effort)/10.")
        }
        if let notes = activity.notes, !notes.isEmpty {
            parts.append("Notes: \(notes)")
        }
        parts.append("Source: \(activity.displaySource).")
        parts.append("Please analyze this workout — how did I perform, was the intensity appropriate, and what should I focus on next?")

        let message = parts.joined(separator: " ")
        NotificationCenter.default.post(name: .openAICoachWithMessage, object: nil, userInfo: ["message": message])
        dismiss()
    }

    // MARK: - Helpers

    private func fullDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// MARK: - Adapt Plan Sheet
struct AdaptPlanSheet: View {
    @ObservedObject var vm: DynamicTrainingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    if let reply = vm.adaptReply {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Coach Goggins", systemImage: "brain.head.profile.fill")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(TFTheme.accentOrange)
                            ScrollView { Text(reply).font(.system(.body, design: .rounded)).foregroundStyle(TFTheme.textPrimary) }
                        }
                        .padding(20).glassCard()
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ask your coach anything about your plan")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(TFTheme.textSecondary)
                        TextField("e.g. I've been feeling fatigued, should I reduce load?", text: $message, axis: .vertical)
                            .font(.system(.body, design: .rounded)).foregroundStyle(TFTheme.textPrimary)
                            .lineLimit(3...5).padding(14)
                            .background(TFTheme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Button(action: send) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TFTheme.accentOrange)
                            if isLoading { ProgressView().tint(.white) }
                            else { Text("Get Coach Feedback").font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(.white) }
                        }.frame(height: 54)
                    }.disabled(isLoading || message.trimmingCharacters(in: .whitespaces).isEmpty)
                    Spacer()
                }.padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Adapt My Plan").font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { vm.adaptReply = nil; dismiss() }.foregroundStyle(TFTheme.accentOrange)
                }
            }
        }
    }

    private func send() {
        isLoading = true
        let msg = message
        message = ""
        Task {
            await vm.getAdaptAdvice(message: msg)
            isLoading = false
        }
    }
}

