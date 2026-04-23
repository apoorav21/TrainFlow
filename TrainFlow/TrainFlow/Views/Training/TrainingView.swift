import SwiftUI

@MainActor
final class TrainingStore: ObservableObject {
    @Published var activeGoal: TrainingGoal? = nil
    @Published var weeks: [TrainingWeek] = []
    @Published var selectedWeekIndex: Int = 0

    var currentWeek: TrainingWeek? {
        weeks.isEmpty ? nil : weeks[min(selectedWeekIndex, weeks.count - 1)]
    }

    func generatePlan(for goal: TrainingGoal) {
        activeGoal = goal
        weeks = PlanGenerator.generate(for: goal)
        selectedWeekIndex = 0
    }
}

struct TrainingView: View {
    @StateObject private var store = TrainingStore()
    @State private var showGoalSetup = false
    @State private var selectedDay: TrainingDay? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                if store.activeGoal == nil {
                    TrainingEmptyState(showGoalSetup: $showGoalSetup)
                } else {
                    trainingContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showGoalSetup) {
                GoalSetupView(isPresented: $showGoalSetup) { goal in
                    store.generatePlan(for: goal)
                }
            }
            .sheet(item: $selectedDay) { day in
                WorkoutDayDetailView(day: day)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Training")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textPrimary)
        }
        if store.activeGoal != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showGoalSetup = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(TFTheme.accentOrange)
                }
            }
        }
    }

    private var trainingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let goal = store.activeGoal {
                    GoalHeroBanner(goal: goal, weekCount: store.weeks.count)
                }
                WeekSelector(
                    weeks: store.weeks,
                    selectedIndex: $store.selectedWeekIndex
                )
                if let week = store.currentWeek {
                    PhaseLabel(week: week)
                    WeeklyCalendarGrid(week: week, onDayTap: { selectedDay = $0 })
                    WeekSummaryCard(week: week)
                }
                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Empty State
struct TrainingEmptyState: View {
    @Binding var showGoalSetup: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(TFTheme.accentOrange.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "figure.run")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(TFTheme.accentOrange)
            }
            VStack(spacing: 12) {
                Text("No Training Plan Yet")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text("Set a goal and we'll build a smart, adaptive training plan tailored to your fitness and schedule.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button(action: { showGoalSetup = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("Set My Goal")
                }
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: 260, minHeight: 54)
                .background(TFTheme.accentOrange)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Goal Hero Banner
struct GoalHeroBanner: View {
    let goal: TrainingGoal
    let weekCount: Int

    private var daysUntil: Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: goal.goalDate).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle().fill(goal.type.accentColor.opacity(0.2)).frame(width: 48, height: 48)
                    Image(systemName: goal.type.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(goal.type.accentColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.type.rawValue)
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(TFTheme.textPrimary)
                    Text(goal.fitnessLevel.rawValue + " • " + goal.type.category)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(daysUntil)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(goal.type.accentColor)
                    Text("days to go")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(0..<weekCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i < weekCount / 4 ? goal.type.accentColor :
                              i < weekCount / 2 ? TFTheme.accentYellow :
                              i < weekCount * 3 / 4 ? TFTheme.accentRed : TFTheme.accentGreen)
                        .frame(height: 6)
                        .opacity(0.6 + (Double(i) / Double(weekCount)) * 0.4)
                }
            }
            HStack {
                ForEach([("Base", TFTheme.accentBlue), ("Build", TFTheme.accentOrange),
                         ("Peak", TFTheme.accentRed), ("Taper", TFTheme.accentGreen)], id: \.0) { label, color in
                    HStack(spacing: 4) {
                        Circle().fill(color).frame(width: 6, height: 6)
                        Text(label)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(TFTheme.textSecondary)
                    }
                }
                Spacer()
                Text(goal.goalDate, style: .date)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(TFTheme.textTertiary)
            }
        }
        .padding(18)
        .glassCard()
        .padding(.horizontal, 20)
    }
}

// MARK: - Week Selector
struct WeekSelector: View {
    let weeks: [TrainingWeek]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(weeks.indices, id: \.self) { i in
                        let week = weeks[i]
                        let isSelected = i == selectedIndex
                        Button(action: { withAnimation(.spring(response: 0.3)) { selectedIndex = i } }) {
                            VStack(spacing: 4) {
                                Text("Wk \(week.weekNumber)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(isSelected ? .white : TFTheme.textSecondary)
                                if week.isDeload {
                                    Text("Deload")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(isSelected ? .white.opacity(0.8) : TFTheme.accentGreen)
                                } else {
                                    Circle()
                                        .fill(week.phase.color)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected ? week.phase.color : TFTheme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .id(i)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear { proxy.scrollTo(selectedIndex, anchor: .center) }
            .onChange(of: selectedIndex) { _, new in
                withAnimation { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }
}

// MARK: - Phase Label
struct PhaseLabel: View {
    let week: TrainingWeek

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(week.phase.color).frame(width: 8, height: 8)
                Text(week.phase.rawValue + " Phase")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(week.phase.color)
                if week.isDeload {
                    Text("• Deload Week")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(TFTheme.accentGreen)
                }
            }
            Spacer()
            Text("Week \(week.weekNumber) of \(week.weekNumber)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(TFTheme.textTertiary)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Weekly Calendar Grid
struct WeeklyCalendarGrid: View {
    let week: TrainingWeek
    var onDayTap: (TrainingDay) -> Void

    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private let today = Calendar.current.startOfDay(for: Date())

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(dayLetters.indices, id: \.self) { i in
                    Text(dayLetters[i])
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(TFTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            HStack(spacing: 6) {
                ForEach(week.days) { day in
                    DayCell(day: day, isToday: Calendar.current.isDate(day.date, inSameDayAs: today))
                        .onTapGesture { if day.dayType != .rest { onDayTap(day) } }
                }
            }
            .padding(.horizontal, 20)
            // Expanded card for today's or next upcoming workout
            if let featured = featuredDay {
                FeaturedWorkoutCard(day: featured, onTap: { onDayTap(featured) })
                    .padding(.horizontal, 20)
            }
        }
    }

    private var featuredDay: TrainingDay? {
        week.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) && $0.dayType != .rest })
        ?? week.days.first(where: { $0.date > today && $0.dayType != .rest })
    }
}

struct DayCell: View {
    let day: TrainingDay
    let isToday: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isToday ? day.dayType.color : (day.isCompleted ? day.dayType.color.opacity(0.3) : TFTheme.bgCard))
                    .frame(height: 52)
                if day.dayType == .rest {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TFTheme.textTertiary)
                } else {
                    VStack(spacing: 3) {
                        Image(systemName: day.dayType.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isToday ? .white : day.dayType.color)
                        if day.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(TFTheme.accentGreen)
                        }
                    }
                }
            }
            Text(day.date, format: .dateTime.day())
                .font(.system(.caption2, design: .rounded, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? day.dayType.color : TFTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Featured Workout Card
struct FeaturedWorkoutCard: View {
    let day: TrainingDay
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(day.dayType.color.opacity(0.2))
                        .frame(width: 54, height: 54)
                    Image(systemName: day.dayType.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(day.dayType.color)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(Calendar.current.isDateInToday(day.date) ? "TODAY" : "NEXT UP")
                            .font(.system(.caption2, design: .rounded, weight: .black))
                            .foregroundStyle(day.dayType.color)
                        Spacer()
                        Text(day.targetDuration)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(TFTheme.textSecondary)
                    }
                    Text(day.title)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(TFTheme.textPrimary)
                    HStack(spacing: 6) {
                        if let dist = day.targetDistance {
                            Label(dist, systemImage: "arrow.trianglehead.2.clockwise")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(TFTheme.textSecondary)
                        }
                        Text("•").foregroundStyle(TFTheme.textTertiary)
                        Text(day.dayType.effortLabel)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(TFTheme.textSecondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFTheme.textTertiary)
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week Summary Card
struct WeekSummaryCard: View {
    let week: TrainingWeek

    private var workoutDays: [TrainingDay] { week.days.filter { $0.dayType != .rest } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week Summary")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
            HStack(spacing: 12) {
                WeekStatPill(label: "Sessions", value: "\(workoutDays.count)", color: TFTheme.accentOrange)
                WeekStatPill(label: "Distance", value: String(format: "%.0f km", week.totalDistance), color: TFTheme.accentBlue)
                WeekStatPill(label: "Est. Time", value: week.totalDuration, color: TFTheme.accentPurple)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(week.days) { day in
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(day.dayType.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: day.dayType.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(day.dayType == .rest ? TFTheme.textTertiary : day.dayType.color)
                            }
                            Text(day.dayType == .rest ? "Rest" : String(day.title.prefix(5)))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(TFTheme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
        .padding(.horizontal, 20)
    }
}

struct WeekStatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(color)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
