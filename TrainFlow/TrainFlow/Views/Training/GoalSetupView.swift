import SwiftUI

struct GoalSetupView: View {
    @Binding var isPresented: Bool
    var onComplete: (TrainingGoal) -> Void

    @State private var step = 0
    @State private var selectedGoal: GoalType = .halfMarathon
    @State private var goalDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    @State private var fitnessLevel: FitnessLevel = .intermediate
    @State private var daysPerWeek = 4
    @State private var maxHours = 6.0
    @State private var restDays: Set<Int> = [0, 3]

    private let totalSteps = 4

    var body: some View {
        ZStack {
            TFTheme.bgPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                setupHeader
                progressBar
                TabView(selection: $step) {
                    GoalTypeStep(selected: $selectedGoal).tag(0)
                    GoalDateStep(goalDate: $goalDate, goalType: selectedGoal).tag(1)
                    FitnessLevelStep(level: $fitnessLevel).tag(2)
                    ScheduleStep(daysPerWeek: $daysPerWeek, maxHours: $maxHours, restDays: $restDays).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: step)
                navButtons
            }
        }
    }

    private var setupHeader: some View {
        HStack {
            Button("Cancel") { isPresented = false }
                .foregroundStyle(TFTheme.textSecondary)
            Spacer()
            Text("Set Your Goal")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textPrimary)
            Spacer()
            Text("Step \(step + 1)/\(totalSteps)")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(TFTheme.bgCard)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(selectedGoal.accentColor)
                    .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 4)
                    .animation(.spring(response: 0.5), value: step)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var navButtons: some View {
        HStack(spacing: 16) {
            if step > 0 {
                Button(action: { step -= 1 }) {
                    Text("Back")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(TFTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(TFTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            Button(action: nextStep) {
                Text(step == totalSteps - 1 ? "Build My Plan 🚀" : "Continue")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(selectedGoal.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private func nextStep() {
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            let goal = TrainingGoal(
                type: selectedGoal,
                goalDate: goalDate,
                fitnessLevel: fitnessLevel,
                daysPerWeek: daysPerWeek,
                maxHoursPerWeek: maxHours,
                restDays: restDays
            )
            onComplete(goal)
            isPresented = false
        }
    }
}

// MARK: - Step 1: Goal Type
struct GoalTypeStep: View {
    @Binding var selected: GoalType

    private let raceGoals: [GoalType] = [.marathon, .halfMarathon, .tenK, .fiveK, .triathlon, .cyclingEvent]
    private let fitnessGoals: [GoalType] = [.weightLoss, .buildStrength, .improveCardio, .custom]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                stepTitle(icon: "trophy.fill", title: "What's your goal?", subtitle: "We'll build a personalized plan around it")
                goalSection(title: "Race Goals", goals: raceGoals)
                goalSection(title: "Fitness Goals", goals: fitnessGoals)
            }
            .padding(20)
        }
    }

    private func goalSection(title: String, goals: [GoalType]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(goals) { goal in
                    GoalTypeCard(goal: goal, isSelected: selected == goal)
                        .onTapGesture { withAnimation(.spring(response: 0.3)) { selected = goal } }
                }
            }
        }
    }
}

struct GoalTypeCard: View {
    let goal: GoalType
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(goal.accentColor.opacity(isSelected ? 0.25 : 0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: goal.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(goal.accentColor)
            }
            Text(goal.rawValue)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(TFTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .padding(14)
        .background(isSelected ? goal.accentColor.opacity(0.15) : TFTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? goal.accentColor : Color.white.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Step 2: Goal Date
struct GoalDateStep: View {
    @Binding var goalDate: Date
    let goalType: GoalType

    private var weeksAway: Int {
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: Date(), to: goalDate).weekOfYear ?? 0
        return max(0, weeks)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                stepTitle(icon: "calendar.badge.clock", title: "When's race day?", subtitle: "Pick your target date and we'll reverse-engineer your plan")
                VStack(spacing: 0) {
                    DatePicker("", selection: $goalDate, in: Date().addingTimeInterval(86400 * 14)..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(goalType.accentColor)
                        .colorScheme(.dark)
                }
                .glassCard()
                HStack(spacing: 16) {
                    weeksAwayBadge
                    phaseBadge
                }
            }
            .padding(20)
        }
    }

    private var weeksAwayBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(weeksAway)")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(goalType.accentColor)
            Text("weeks to train")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private var phaseBadge: some View {
        let phases = weeksAway >= 12 ? "Base → Build → Peak → Taper" : weeksAway >= 8 ? "Build → Peak → Taper" : "Peak → Taper"
        return VStack(alignment: .leading, spacing: 4) {
            Text("Plan Structure")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
            Text(phases)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(TFTheme.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }
}

// MARK: - Step 3: Fitness Level
struct FitnessLevelStep: View {
    @Binding var level: FitnessLevel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                stepTitle(icon: "chart.bar.fill", title: "Current fitness level?", subtitle: "Be honest — this shapes your starting volume and intensity")
                VStack(spacing: 12) {
                    ForEach(FitnessLevel.allCases) { lvl in
                        FitnessLevelRow(level: lvl, isSelected: level == lvl)
                            .onTapGesture { withAnimation(.spring(response: 0.3)) { level = lvl } }
                    }
                }
            }
            .padding(20)
        }
    }
}

struct FitnessLevelRow: View {
    let level: FitnessLevel
    let isSelected: Bool

    private var color: Color {
        switch level {
        case .beginner: return TFTheme.accentGreen
        case .intermediate: return TFTheme.accentOrange
        case .advanced: return TFTheme.accentRed
        }
    }

    private var detail: String {
        switch level {
        case .beginner: return "2–3 days/week • <20 km/week"
        case .intermediate: return "3–5 days/week • 20–50 km/week"
        case .advanced: return "5–7 days/week • 50+ km/week"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(isSelected ? 0.25 : 0.1)).frame(width: 48, height: 48)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(level.rawValue)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(TFTheme.textPrimary)
                Text(level.description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(TFTheme.textTertiary)
            }
            Spacer()
        }
        .padding(16)
        .background(isSelected ? color.opacity(0.12) : TFTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? color : Color.white.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
        )
    }
}

// MARK: - Step 4: Schedule
struct ScheduleStep: View {
    @Binding var daysPerWeek: Int
    @Binding var maxHours: Double
    @Binding var restDays: Set<Int>

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                stepTitle(icon: "clock.fill", title: "Your schedule", subtitle: "Tell us your availability — we'll fit the plan to your life")
                daysPerWeekSection
                hoursSection
                restDaysSection
            }
            .padding(20)
        }
    }

    private var daysPerWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training days per week")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(TFTheme.textSecondary)
                Spacer()
                Text("\(daysPerWeek) days")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(TFTheme.accentOrange)
            }
            HStack(spacing: 10) {
                ForEach(2...7, id: \.self) { d in
                    Button(action: { withAnimation { daysPerWeek = d } }) {
                        Text("\(d)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(daysPerWeek == d ? .white : TFTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(daysPerWeek == d ? TFTheme.accentOrange : TFTheme.bgCard)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Max hours per week")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(TFTheme.textSecondary)
                Spacer()
                Text(String(format: "%.1f hrs", maxHours))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(TFTheme.accentBlue)
            }
            Slider(value: $maxHours, in: 2...20, step: 0.5)
                .tint(TFTheme.accentBlue)
        }
        .padding(16)
        .glassCard()
    }

    private var restDaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferred rest days")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    Button(action: { withAnimation { toggleRestDay(i) } }) {
                        Text(dayNames[i])
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(restDays.contains(i) ? .white : TFTheme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(restDays.contains(i) ? TFTheme.accentGreen : TFTheme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func toggleRestDay(_ day: Int) {
        if restDays.contains(day) { restDays.remove(day) } else { restDays.insert(day) }
    }
}

// MARK: - Shared helper
func stepTitle(icon: String, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 32))
            .foregroundStyle(.white)
            .padding(.bottom, 4)
        Text(title)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(TFTheme.textPrimary)
        Text(subtitle)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(TFTheme.textSecondary)
    }
}
