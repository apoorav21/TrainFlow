import SwiftUI

struct WorkoutDayDetailView: View {
    let day: TrainingDay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            TFTheme.bgPrimary.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    VStack(spacing: 16) {
                        statsRow
                        instructionsCard
                        warmupCard
                        mainSetCard
                        cooldownCard
                        effortCard
                        aiNoteCard
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: Hero
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [day.dayType.color.opacity(0.7), TFTheme.bgPrimary],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 220)
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.7))
                            .background(Color.black.opacity(0.3).clipShape(Circle()))
                    }
                    Spacer()
                    PhasePill(phase: day.phase)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().fill(day.dayType.color.opacity(0.25)).frame(width: 36, height: 36)
                                Image(systemName: day.dayType.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(day.dayType.color)
                            }
                            Text(day.dayType.rawValue.uppercased())
                                .font(.system(.caption, design: .rounded, weight: .black))
                                .foregroundStyle(day.dayType.color)
                        }
                        Text(day.title)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(TFTheme.textPrimary)
                        Text(day.date, style: .date)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            if let dist = day.targetDistance {
                DetailStatBox(label: "Distance", value: dist, icon: "arrow.trianglehead.2.clockwise", color: day.dayType.color)
            }
            DetailStatBox(label: "Duration", value: day.targetDuration, icon: "clock.fill", color: TFTheme.accentBlue)
            DetailStatBox(label: "Effort", value: effortShort, icon: "flame.fill", color: effortColor)
        }
    }

    private var effortShort: String {
        switch day.dayType {
        case .rest: return "None"
        case .recovery: return "Very Easy"
        case .easyRun, .crossTrain: return "Easy"
        case .longRun, .strength: return "Moderate"
        case .tempo: return "Hard"
        case .intervals, .race: return "Max"
        }
    }

    private var effortColor: Color {
        switch day.dayType {
        case .rest, .recovery: return TFTheme.accentGreen
        case .easyRun, .crossTrain: return TFTheme.zone2
        case .longRun, .strength: return TFTheme.zone3
        case .tempo: return TFTheme.zone4
        case .intervals, .race: return TFTheme.zone5
        }
    }

    // MARK: Instructions
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workout Overview", systemImage: "doc.text.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
            Text(day.instructions)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: Workout Sections
    private var warmupCard: some View {
        WorkoutPhaseCard(
            title: "Warm-Up",
            icon: "sunrise.fill",
            color: TFTheme.accentYellow,
            items: warmupItems
        )
    }

    private var mainSetCard: some View {
        WorkoutPhaseCard(
            title: "Main Set",
            icon: "bolt.fill",
            color: day.dayType.color,
            items: mainSetItems
        )
    }

    private var cooldownCard: some View {
        WorkoutPhaseCard(
            title: "Cool-Down",
            icon: "sunset.fill",
            color: TFTheme.accentCyan,
            items: cooldownItems
        )
    }

    private var warmupItems: [String] {
        switch day.dayType {
        case .easyRun, .longRun: return ["5–10 min easy walk/jog", "Dynamic leg swings × 10 each", "Hip circles × 10 each direction"]
        case .tempo: return ["10 min easy jog", "4× 20s strides at race pace", "Leg swings and hip openers"]
        case .intervals: return ["15 min easy jog", "4× 100m accelerations", "High knees and butt kicks"]
        case .strength: return ["5 min light cardio", "Bodyweight squats × 15", "Hip mobility drill × 10"]
        case .crossTrain: return ["5 min very easy pace", "Joint mobility — ankles, knees, hips"]
        default: return ["5 min gentle movement", "Deep breathing × 5"]
        }
    }

    private var mainSetItems: [String] {
        switch day.dayType {
        case .easyRun: return ["Run at comfortable conversational pace", "Target HR Zone 2 (60–70% max)", "Focus on smooth, relaxed stride"]
        case .longRun: return ["First 2/3 in Zone 2", "Final 1/3 in Zone 3", "Fuel every 45 min", "Stay relaxed, steady effort"]
        case .tempo: return ["3–4 × 10 min at comfortably hard pace", "90s–2 min easy jog recovery", "Target HR Zone 3–4", "Should feel 'pleasantly uncomfortable'"]
        case .intervals: return ["6 × 800m at 5K race pace", "90s standing recovery between reps", "Focus on consistent splits", "HR Zone 4–5 on efforts"]
        case .strength: return ["Squats 3×10", "Romanian Deadlifts 3×10", "Walking Lunges 2×12 each", "Push-ups 3×12", "Plank 3×45 sec"]
        case .crossTrain: return ["30–35 min steady-state cycling or swimming", "HR Zone 1–2 only", "Focus on recovery, not performance"]
        case .recovery: return ["20 min gentle yoga or foam rolling", "Target mobility areas: hips, calves, IT band", "10 min mindful breathing"]
        default: return ["Rest fully — no structured activity", "Hydrate well and eat nutritious food", "Light walking OK if desired"]
        }
    }

    private var cooldownItems: [String] {
        switch day.dayType {
        case .rest, .recovery: return ["Enjoy your rest!", "Light stretching if desired"]
        case .strength: return ["5 min light walking", "Static stretching: quads, hamstrings, chest × 30s each"]
        default: return ["5–10 min easy walk", "Static stretching × 30s each major muscle group", "Foam roll calves and IT band"]
        }
    }

    // MARK: Effort Card
    private var effortCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Effort & HR Target", systemImage: "heart.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
            Text(day.dayType.effortLabel)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(TFTheme.textPrimary)
            HRZoneBar(dayType: day.dayType)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: AI Note
    private var aiNoteCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(TFTheme.accentPurple.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(TFTheme.accentPurple)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Coach Goggins Note")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(TFTheme.accentPurple)
                Text("Connect Coach Goggins to get personalized insights, pacing strategy, and real-time adjustments for this workout.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Supporting Views
struct DetailStatBox: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(TFTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard()
    }
}

struct WorkoutPhaseCard: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(color).frame(width: 5, height: 5).padding(.top, 6)
                        Text(item)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(TFTheme.textPrimary)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }
}

struct PhasePill: View {
    let phase: TrainingPhase
    var body: some View {
        Text(phase.rawValue + " Phase")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(phase.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(phase.color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(phase.color.opacity(0.3), lineWidth: 1))
    }
}

struct HRZoneBar: View {
    let dayType: TrainingDayType

    private var zones: [(Color, CGFloat)] {
        switch dayType {
        case .easyRun, .crossTrain:
            return [(TFTheme.zone1, 0.2), (TFTheme.zone2, 0.65), (TFTheme.zone3, 0.15), (TFTheme.zone4, 0), (TFTheme.zone5, 0)]
        case .longRun:
            return [(TFTheme.zone1, 0.1), (TFTheme.zone2, 0.55), (TFTheme.zone3, 0.3), (TFTheme.zone4, 0.05), (TFTheme.zone5, 0)]
        case .tempo:
            return [(TFTheme.zone1, 0.1), (TFTheme.zone2, 0.15), (TFTheme.zone3, 0.45), (TFTheme.zone4, 0.3), (TFTheme.zone5, 0)]
        case .intervals:
            return [(TFTheme.zone1, 0.05), (TFTheme.zone2, 0.2), (TFTheme.zone3, 0.15), (TFTheme.zone4, 0.35), (TFTheme.zone5, 0.25)]
        default:
            return [(TFTheme.zone1, 0.6), (TFTheme.zone2, 0.3), (TFTheme.zone3, 0.1), (TFTheme.zone4, 0), (TFTheme.zone5, 0)]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(zones.indices, id: \.self) { i in
                        let (color, fraction) = zones[i]
                        if fraction > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                }
            }
            .frame(height: 10)
            HStack {
                ForEach(1...5, id: \.self) { z in
                    Text("Z\(z)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(TFTheme.textTertiary)
                    Spacer()
                }
            }
        }
    }
}
