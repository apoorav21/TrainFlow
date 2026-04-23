import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct ActiveWorkoutView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    @State private var crownValue: Double = 0
    @FocusState private var crownFocused: Bool

    private var pageCount: Int { manager.workoutPhases.isEmpty ? 3 : 4 }

    var body: some View {
        TabView(selection: Binding(
            get: { Int(crownValue.rounded()).clamped(to: 0...(pageCount - 1)) },
            set: { crownValue = Double($0) }
        )) {
            NowMetricsPage().tag(0)
            if !manager.workoutPhases.isEmpty { PhasePage().tag(1) }
            HeartRatePage().tag(manager.workoutPhases.isEmpty ? 1 : 2)
            ControlsPage().tag(manager.workoutPhases.isEmpty ? 2 : 3)
        }
        .tabViewStyle(.page)
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: Double(pageCount - 1),
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear { crownFocused = true }
        .environmentObject(manager)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Workout category helper

private enum WatchWorkoutCategory {
    case cardio       // running, walking, hiking
    case cycling
    case strength     // strength, HIIT, functional, cross-training
    case other

    init(_ type: String) {
        let t = type.lowercased()
        if t.contains("run") || t.contains("walk") || t.contains("hik") { self = .cardio }
        else if t.contains("cycl") || t.contains("bike") || t.contains("elliptical") { self = .cycling }
        else if t.contains("strength") || t.contains("hiit") || t.contains("functional") || t.contains("cross") { self = .strength }
        else { self = .other }
    }
}

// MARK: - Page 1: Type-adaptive metrics

struct NowMetricsPage: View {
    @EnvironmentObject private var manager: WatchWorkoutManager

    private var category: WatchWorkoutCategory {
        WatchWorkoutCategory(manager.currentDay?.type ?? "")
    }

    var body: some View {
        switch category {
        case .cardio:  CardioMetricsView().environmentObject(manager)
        case .cycling: CyclingMetricsView().environmentObject(manager)
        case .strength: StrengthMetricsView().environmentObject(manager)
        case .other:   GeneralMetricsView().environmentObject(manager)
        }
    }
}

// MARK: - Cardio (run / walk / hike): time · distance · pace · HR

struct CardioMetricsView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    private var session: WatchWorkoutSession { manager.session }
    private var targetPace: String? { manager.currentPhase?.targetPace }
    private var targetZone: HRZone? { manager.currentPhase.flatMap { HRZone(rawValue: $0.hrZone) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                metricBlock(label: "TIME", value: session.formattedElapsed,
                            size: 22, color: .orange, mono: true)
                Spacer()
                metricBlock(label: "DIST", value: session.formattedDistance + " km",
                            size: 22, color: .white, mono: false, trailing: true)
            }
            Divider().opacity(0.25)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("PACE").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    Text(session.formattedPace)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan).contentTransition(.numericText())
                }
                Spacer()
                if let t = targetPace {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("TARGET").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                        Text(t).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.cyan.opacity(0.6))
                    }
                }
            }
            hrRow(targetZone: targetZone)
            Divider().opacity(0.25)
            CalPhaseRow()
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
    }
}

// MARK: - Cycling: time · distance · speed · HR

struct CyclingMetricsView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    private var session: WatchWorkoutSession { manager.session }
    private var targetZone: HRZone? { manager.currentPhase.flatMap { HRZone(rawValue: $0.hrZone) } }

    private var speedKph: String {
        guard session.currentPace > 0 else { return "--" }
        return String(format: "%.1f", 60.0 / session.currentPace)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                metricBlock(label: "TIME", value: session.formattedElapsed,
                            size: 22, color: .orange, mono: true)
                Spacer()
                metricBlock(label: "DIST", value: session.formattedDistance + " km",
                            size: 22, color: .white, mono: false, trailing: true)
            }
            Divider().opacity(0.25)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("SPEED").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(speedKph)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan).contentTransition(.numericText())
                        Text("km/h").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                metricBlock(label: "CAL", value: "\(Int(session.calories))",
                            size: 14, color: .yellow, mono: false, trailing: true)
            }
            hrRow(targetZone: targetZone)
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
    }
}

// MARK: - Strength / HIIT: time · HR · sets guidance · calories

struct StrengthMetricsView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    private var session: WatchWorkoutSession { manager.session }
    private var phase: WorkoutPhaseItem? { manager.currentPhase }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Timer (large, centered)
            HStack {
                metricBlock(label: "TIME", value: session.formattedElapsed,
                            size: 26, color: .purple, mono: true)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("HR").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9)).foregroundStyle(session.hrZone.color)
                        Text(session.heartRate > 0 ? "\(Int(session.heartRate))" : "--")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(session.hrZone.color).contentTransition(.numericText())
                    }
                }
            }
            Divider().opacity(0.25)
            // Current exercise / phase
            if let p = phase {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(p.color).frame(width: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(p.color).lineLimit(1)
                        Text(p.detail)
                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    // Phase timer
                    if let dur = p.durationSec {
                        let rem = max(0, dur - manager.phaseElapsedSeconds)
                        Text(String(format: "%d:%02d", rem / 60, rem % 60))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(rem < 30 ? .red : .orange)
                    }
                }
                .padding(.vertical, 2)
            }
            Divider().opacity(0.25)
            // Calories + set progress
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                    Text("\(Int(session.calories)) kcal")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.yellow)
                }
                Spacer()
                if !manager.workoutPhases.isEmpty {
                    Text("\(manager.currentPhaseIndex + 1)/\(manager.workoutPhases.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
    }
}

// MARK: - General (swim, yoga, etc.): time · HR · calories

struct GeneralMetricsView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    private var session: WatchWorkoutSession { manager.session }
    private var targetZone: HRZone? { manager.currentPhase.flatMap { HRZone(rawValue: $0.hrZone) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                metricBlock(label: "TIME", value: session.formattedElapsed,
                            size: 22, color: .orange, mono: true)
                Spacer()
                metricBlock(label: "CAL", value: "\(Int(session.calories)) kcal",
                            size: 18, color: .yellow, mono: false, trailing: true)
            }
            Divider().opacity(0.25)
            hrRow(targetZone: targetZone)
            Divider().opacity(0.25)
            CalPhaseRow()
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
    }
}

// MARK: - Shared helpers (file-scope so all page structs can use them)

@ViewBuilder
private func metricBlock(label: String, value: String, size: CGFloat, color: Color,
                         mono: Bool, trailing: Bool = false) -> some View {
    VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
        Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
        Text(value)
            .font(mono ? .system(size: size, weight: .heavy, design: .monospaced)
                       : .system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(color).contentTransition(.numericText())
    }
}

@ViewBuilder
private func hrRow(targetZone: HRZone?) -> some View {
    HStack(alignment: .center) {
        // This captures the manager via @EnvironmentObject — views already pass it
        _HRRowContent(targetZone: targetZone)
    }
}

private struct _HRRowContent: View {
    let targetZone: HRZone?
    @EnvironmentObject private var manager: WatchWorkoutManager
    private var session: WatchWorkoutSession { manager.session }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(session.hrZone.color)
            Text(session.heartRate > 0 ? "\(Int(session.heartRate))" : "--")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(session.hrZone.color).contentTransition(.numericText())
            Text("bpm").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        Spacer()
        if let z = targetZone {
            VStack(alignment: .trailing, spacing: 1) {
                Text("TARGET").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                Text(z.label).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(z.color.opacity(0.7))
            }
        }
    }
}

private struct CalPhaseRow: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    private var session: WatchWorkoutSession { manager.session }

    var body: some View {
        HStack {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                Text("\(Int(session.calories)) kcal").font(.system(size: 12, weight: .semibold)).foregroundStyle(.yellow)
            }
            Spacer()
            if let phase = manager.currentPhase {
                Text(phase.label).font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(phase.color).lineLimit(1)
            }
        }
    }
}

// MARK: - Page 2: Phase guidance
struct PhasePage: View {
    @EnvironmentObject private var manager: WatchWorkoutManager

    var body: some View {
        VStack(spacing: 6) {
            if let phase = manager.currentPhase {
                currentPhaseView(phase)
            }
            phaseProgress
            HStack(spacing: 8) {
                Button(action: { manager.previousPhase() }) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .opacity(manager.currentPhaseIndex > 0 ? 1 : 0.3)

                Button(action: { manager.nextPhase() }) {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .opacity(manager.currentPhaseIndex < manager.workoutPhases.count - 1 ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func currentPhaseView(_ phase: WorkoutPhaseItem) -> some View {
        VStack(spacing: 3) {
            Text(phase.label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(phase.color)
                .lineLimit(1)
            if let pace = phase.targetPace {
                HStack(spacing: 4) {
                    Image(systemName: "speedometer").font(.caption2).foregroundStyle(.secondary)
                    Text(pace).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").font(.caption2).foregroundStyle(phase.hrZoneColor)
                Text(phase.hrZoneLabel).font(.system(size: 11)).foregroundStyle(phase.hrZoneColor)
            }
            Text(phase.detail)
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineLimit(2)

            // Timer: countdown if duration set, otherwise stopwatch
            if let dur = phase.durationSec {
                let remaining = max(0, dur - manager.phaseElapsedSeconds)
                let m = remaining / 60; let s = remaining % 60
                Text(String(format: "%d:%02d left", m, s))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(remaining < 30 ? .red : .orange)
            } else {
                let m = manager.phaseElapsedSeconds / 60
                let s = manager.phaseElapsedSeconds % 60
                Text(String(format: "%d:%02d", m, s))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var phaseProgress: some View {
        HStack(spacing: 3) {
            ForEach(manager.workoutPhases.indices, id: \.self) { i in
                let phase = manager.workoutPhases[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(i == manager.currentPhaseIndex ? phase.color : Color.white.opacity(0.2))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.2), value: manager.currentPhaseIndex)
            }
        }
    }
}

// MARK: - Page 3: Heart Rate Zone
struct HeartRatePage: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    private var session: WatchWorkoutSession { manager.session }
    private var zone: HRZone { session.hrZone }
    private var targetZone: HRZone? {
        manager.currentPhase.flatMap { HRZone(rawValue: $0.hrZone) }
    }

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                Text(session.heartRate > 0 ? "\(Int(session.heartRate))" : "--")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(zone.color).contentTransition(.numericText())
                Text("BPM").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(HRZone.allCases, id: \.rawValue) { z in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(z == zone ? z.color : Color.white.opacity(0.15))
                        .frame(height: 6)
                        .overlay(
                            z == targetZone ? RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.white.opacity(0.7), lineWidth: 1.5) : nil
                        )
                        .animation(.easeInOut(duration: 0.3), value: zone)
                }
            }
            .padding(.horizontal, 4)
            VStack(spacing: 2) {
                Text(zone.label).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(zone.color)
                if let target = targetZone, target != zone {
                    Text("Target: \(target.label)").font(.system(size: 10)).foregroundStyle(target.color)
                } else if targetZone != nil {
                    Text("On target ✓").font(.system(size: 10)).foregroundStyle(.green)
                }
            }
            HStack {
                Image(systemName: "heart.text.square.fill").foregroundStyle(.secondary).font(.caption2)
                Text("Avg \(Int(session.avgHeartRate)) BPM").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Page 4: Controls
struct ControlsPage: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    @State private var showEndAlert = false

    private var pauseColor: Color { manager.phase == .paused ? .green : .yellow }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                // Pause / Resume — circle with icon
                Button(action: {
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                    if manager.phase == .paused { manager.resumeWorkout() } else { manager.pauseWorkout() }
                }) {
                    ZStack {
                        Circle()
                            .stroke(pauseColor, lineWidth: 3)
                            .frame(width: 68, height: 68)
                        Image(systemName: manager.phase == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(pauseColor)
                    }
                }
                .buttonStyle(.plain)

                // End — circle with X
                Button(action: { showEndAlert = true }) {
                    ZStack {
                        Circle()
                            .stroke(Color.red, lineWidth: 3)
                            .frame(width: 68, height: 68)
                        Image(systemName: "xmark")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.red)
                    }
                }
                .buttonStyle(.plain)
                .alert("End Workout?", isPresented: $showEndAlert) {
                    Button("End", role: .destructive) {
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.stop)
                        #endif
                        manager.endWorkout()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("Saved to Health.") }
            }

            HStack(spacing: 4) {
                Image(systemName: "timer").font(.caption2).foregroundStyle(.secondary)
                Text(manager.session.formattedElapsed)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
