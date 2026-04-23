import SwiftUI
#if os(watchOS)
import HealthKit
import WatchKit
#endif

struct TodayWorkoutView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if manager.isLoadingPlan {
                        loadingView
                    } else if let day = manager.todayWorkout {
                        if day.isRestDay { RestDayView() }
                        else { WorkoutCardView(day: day) }
                    } else {
                        noPlanView
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView().tint(.orange)
            Text("Loading plan...").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 20)
    }

    private var noPlanView: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run.circle").font(.system(size: 32)).foregroundStyle(.orange)
            Text("No Plan").font(.headline)
            Text("Create a plan on your iPhone").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }
}

// MARK: - Workout Card
struct WorkoutCardView: View {
    let day: WatchWorkoutDay
    @EnvironmentObject private var manager: WatchWorkoutManager
    @State private var showDetail = false

    private var workoutColor: Color { day.workoutColor }
    private var workoutIcon: String { iconForType(day.type) }
    private var activityType: HKWorkoutActivityTypeProxy { activityTypeForDay(day) }

    var body: some View {
        VStack(spacing: 8) {
            headerBadge
            titleSection
            statsRow
            if !day.workoutPhases.isEmpty { phasePreview }
            instructionsButton
            startButton
        }
    }

    private var headerBadge: some View {
        HStack {
            Label(day.type.replacingOccurrences(of: "_", with: " ").uppercased(), systemImage: workoutIcon)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(workoutColor)
            Spacer()
            if day.isCompleted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 14))
            }
        }
    }

    private var titleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Week \(day.weekNumber) · Day \(day.dayNumber)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle().fill(workoutColor.opacity(0.2)).frame(width: 34, height: 34)
                Image(systemName: workoutIcon).font(.system(size: 15, weight: .semibold)).foregroundStyle(workoutColor)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 6) {
            if let dist = day.targetDistance { StatChip(icon: "figure.run", value: dist, color: workoutColor) }
            StatChip(icon: "timer", value: day.targetDuration, color: .secondary)
            if let zone = day.targetHRZone {
                StatChip(icon: "heart.fill", value: "Z\(zone)", color: HRZone(rawValue: zone)?.color ?? .orange)
            }
        }
    }

    private var phasePreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            let phases = day.workoutPhases
            ForEach(phases.prefix(4)) { phase in
                HStack(spacing: 6) {
                    Circle().fill(phase.color).frame(width: 6, height: 6)
                    Text(phase.label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(phase.color)
                    Spacer()
                    if let pace = phase.targetPace {
                        Text(pace).font(.system(size: 10)).foregroundStyle(.secondary)
                    } else if let dur = phase.formattedDuration {
                        Text(dur).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
            if phases.count > 4 {
                Text("+\(phases.count - 4) more").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var instructionsButton: some View {
        Button(action: { showDetail = true }) {
            HStack {
                Image(systemName: "info.circle").font(.caption2)
                Text("Instructions").font(.caption2)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) { WorkoutDetailSheet(day: day) }
    }

    private var startButton: some View {
        Button(action: {
            #if os(watchOS)
            WKInterfaceDevice.current().play(.start)
            #endif
            manager.startWorkout(type: activityType.hkType, day: day)
        }) {
            Label(day.isCompleted ? "Start Again" : "Start Workout", systemImage: "play.fill")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(workoutColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Chip
struct StatChip: View {
    let icon: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
            Text(value).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Color.white.opacity(0.1)).clipShape(Capsule())
    }
}

// MARK: - Workout Detail Sheet
struct WorkoutDetailSheet: View {
    let day: WatchWorkoutDay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(day.title).font(.system(size: 14, weight: .bold, design: .rounded))

                if let warmup = day.warmup {
                    sectionRow(icon: "sunrise.fill", label: "Warm Up",
                               detail: "\(warmup.durationMin.map { "\(Int($0)) min — " } ?? "")\(warmup.description ?? "")",
                               color: .cyan)
                }

                if let ms = day.mainSet {
                    sectionRow(icon: "bolt.fill", label: "Main Set", detail: ms.description ?? "", color: day.workoutColor)
                    if let intervals = ms.intervals {
                        ForEach(Array(intervals.enumerated()), id: \.offset) { i, iv in
                            intervalRow(index: i, interval: iv, day: day)
                        }
                    }
                }

                if let exs = day.exercises, !exs.isEmpty {
                    ForEach(exs, id: \.name) { ex in
                        exerciseRow(ex)
                    }
                }

                if let cooldown = day.cooldown {
                    sectionRow(icon: "sunset.fill", label: "Cool Down",
                               detail: "\(cooldown.durationMin.map { "\(Int($0)) min — " } ?? "")\(cooldown.description ?? "")",
                               color: .blue)
                }

                if let msg = day.coachMessage {
                    Divider()
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "brain.head.profile.fill").foregroundStyle(.orange).font(.caption2)
                        Text(msg).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
        .navigationTitle("Details")
    }

    private func sectionRow(icon: String, label: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.caption2).frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }

    private func intervalRow(index: Int, interval: WorkoutInterval, day: WatchWorkoutDay) -> some View {
        let isRest = interval.type == "rest" || interval.type == "recovery"
        return HStack(spacing: 6) {
            Rectangle().fill(isRest ? Color.green : day.workoutColor).frame(width: 2)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(isRest ? "Rest" : "Work").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isRest ? .green : day.workoutColor)
                    Spacer()
                    if let p = interval.targetPace { Text(p).font(.system(size: 10)).foregroundStyle(.secondary) }
                    if let z = interval.hrZone { Text("Z\(z)").font(.system(size: 10)).foregroundStyle(HRZone(rawValue: z)?.color ?? .orange) }
                }
                if let notes = interval.notes { Text(notes).font(.system(size: 9)).foregroundStyle(.secondary) }
                if let dur = interval.durationMin { Text("\(String(format: "%.0f", dur)) min").font(.system(size: 9)).foregroundStyle(.secondary) }
            }
        }
        .padding(.leading, 4)
    }

    private func exerciseRow(_ ex: WorkoutExercise) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "dumbbell.fill").foregroundStyle(.purple).font(.caption2).frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(ex.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                let repsStr = ex.reps.map { "\(ex.sets ?? 3)×\($0)" } ?? "\(ex.sets ?? 3) sets"
                let restStr = ex.restSec.map { " · \($0)s rest" } ?? ""
                Text("\(repsStr)\(restStr)").font(.system(size: 10)).foregroundStyle(.secondary)
                if let notes = ex.notes { Text(notes).font(.system(size: 9)).foregroundStyle(.secondary) }
            }
        }
    }
}

// MARK: - Rest Day
struct RestDayView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 36)).foregroundStyle(.cyan)
            Text("Rest Day").font(.system(size: 18, weight: .bold, design: .rounded))
            Text("Recover, hydrate, and prepare for tomorrow.").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }
}

// MARK: - Activity Type Proxy
struct HKWorkoutActivityTypeProxy { let hkType: HKWorkoutActivityType }

private func iconForType(_ type: String) -> String {
    let t = type.lowercased()
    if t.contains("strength") { return "dumbbell.fill" }
    if t.contains("cross") || t.contains("cycl") { return "figure.outdoor.cycle" }
    if t.contains("recover") { return "leaf.fill" }
    if t.contains("interval") || t.contains("speed") { return "bolt.fill" }
    if t.contains("tempo") { return "gauge.with.needle.fill" }
    return "figure.run"
}

private func activityTypeForDay(_ day: WatchWorkoutDay) -> HKWorkoutActivityTypeProxy {
    let t = day.type.lowercased()
    if t.contains("strength") { return HKWorkoutActivityTypeProxy(hkType: .traditionalStrengthTraining) }
    if t.contains("cycl") { return HKWorkoutActivityTypeProxy(hkType: .cycling) }
    if t.contains("swim") { return HKWorkoutActivityTypeProxy(hkType: .swimming) }
    return HKWorkoutActivityTypeProxy(hkType: .running)
}
