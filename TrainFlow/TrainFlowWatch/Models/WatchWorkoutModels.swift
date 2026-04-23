import Foundation
import SwiftUI

// MARK: - Shared sub-models (must match iOS TFWorkoutDay Codable keys exactly)

struct WorkoutInterval: Codable {
    let type: String
    let durationMin: Double?
    let distanceKm: Double?
    let targetPace: String?
    let hrZone: Int?
    let notes: String?
}

struct WorkoutSection: Codable {
    let durationMin: Double?
    let description: String?
    let targetPace: String?
    let hrZone: Int?
    let intervals: [WorkoutInterval]?
}

struct WorkoutExercise: Codable {
    let name: String
    let sets: Int?
    let reps: String?
    let restSec: Int?
    let notes: String?
}

// MARK: - Watch Workout Day (mirrors TFWorkoutDay — same Codable keys)

struct WatchWorkoutDay: Identifiable, Codable {
    var id: String { planWeekDay }
    let planWeekDay: String
    let planId: String
    let scheduledDate: String
    let weekNumber: Int
    let dayNumber: Int
    let type: String
    let title: String
    var isRestDay: Bool
    let distance: String?
    let duration: String?
    let targetPace: String?
    let targetHRZone: Int?
    let description: String?
    let coachMessage: String?
    let warmup: WorkoutSection?
    let mainSet: WorkoutSection?
    let cooldown: WorkoutSection?
    let exercises: [WorkoutExercise]?
    var isCompleted: Bool
    var completedAt: String?

    var instructions: String { coachMessage ?? description ?? "Follow your training plan for today." }
    var targetDistance: String? { distance }
    var targetDuration: String { duration ?? "—" }

    // Build ordered phase list for watch active workout
    var workoutPhases: [WorkoutPhaseItem] {
        var phases: [WorkoutPhaseItem] = []

        if let w = warmup {
            phases.append(WorkoutPhaseItem(
                label: "Warm Up",
                detail: w.description ?? "Easy effort warm up",
                targetPace: w.targetPace,
                hrZone: w.hrZone ?? 1,
                durationSec: w.durationMin.map { Int($0 * 60) },
                isRest: false,
                color: .cyan
            ))
        }

        if let ms = mainSet {
            if let intervals = ms.intervals, !intervals.isEmpty {
                var workCount = 0
                for (i, iv) in intervals.enumerated() {
                    let isRestType = iv.type == "rest" || iv.type == "recovery"
                    if !isRestType { workCount += 1 }
                    let label: String
                    if isRestType {
                        label = "Rest"
                    } else {
                        label = "Interval \(workCount)"
                    }
                    phases.append(WorkoutPhaseItem(
                        label: label,
                        detail: iv.notes ?? (isRestType ? "Easy recovery" : (iv.targetPace.map { "Target: \($0)" } ?? ms.description ?? "")),
                        targetPace: iv.targetPace,
                        hrZone: iv.hrZone ?? (isRestType ? 1 : (targetHRZone ?? 3)),
                        durationSec: iv.durationMin.map { Int($0 * 60) },
                        isRest: isRestType,
                        color: isRestType ? .green : workoutColor
                    ))
                    _ = i // suppress unused warning
                }
            } else {
                phases.append(WorkoutPhaseItem(
                    label: "Main Set",
                    detail: ms.description ?? "Main workout",
                    targetPace: targetPace,
                    hrZone: targetHRZone ?? 3,
                    durationSec: nil,
                    isRest: false,
                    color: workoutColor
                ))
            }
        }

        if let ex = exercises, !ex.isEmpty {
            for exercise in ex {
                let repsStr = exercise.reps.map { "\(exercise.sets ?? 3)×\($0)" } ?? "\(exercise.sets ?? 3) sets"
                phases.append(WorkoutPhaseItem(
                    label: exercise.name,
                    detail: "\(repsStr)\(exercise.restSec.map { " · \($0)s rest" } ?? "")\(exercise.notes.map { " — \($0)" } ?? "")",
                    targetPace: nil,
                    hrZone: targetHRZone ?? 2,
                    durationSec: exercise.restSec.map { Int(Double(exercise.sets ?? 3) * 45 + Double($0) * Double((exercise.sets ?? 3) - 1)) },
                    isRest: false,
                    color: .purple
                ))
            }
        }

        if let c = cooldown {
            phases.append(WorkoutPhaseItem(
                label: "Cool Down",
                detail: c.description ?? "Easy cool down",
                targetPace: c.targetPace,
                hrZone: c.hrZone ?? 1,
                durationSec: c.durationMin.map { Int($0 * 60) },
                isRest: false,
                color: .blue
            ))
        }

        // Fallback: if no structure, single phase
        if phases.isEmpty && !isRestDay {
            phases.append(WorkoutPhaseItem(
                label: "Workout",
                detail: instructions,
                targetPace: targetPace,
                hrZone: targetHRZone ?? 3,
                durationSec: nil,
                isRest: false,
                color: workoutColor
            ))
        }

        return phases
    }

    var workoutColor: Color {
        let t = type.lowercased()
        if t.contains("strength") { return Color(red: 0.65, green: 0.35, blue: 1.0) }
        if t.contains("cross") || t.contains("cycl") { return Color(red: 0.25, green: 0.60, blue: 1.0) }
        if t.contains("recover") || t.contains("easy") { return Color(red: 0.30, green: 0.85, blue: 0.55) }
        if t.contains("long") { return .orange }
        if t.contains("tempo") { return Color(red: 1.0, green: 0.82, blue: 0.30) }
        if t.contains("interval") || t.contains("speed") { return .red }
        return .orange
    }
}

// MARK: - Workout Phase (for active workout guidance)

struct WorkoutPhaseItem: Identifiable {
    let id = UUID()
    let label: String
    let detail: String
    let targetPace: String?
    let hrZone: Int
    let durationSec: Int?   // nil = open-ended (user advances manually)
    let isRest: Bool
    let color: Color

    var hrZoneColor: Color { HRZone(rawValue: hrZone)?.color ?? .green }
    var hrZoneLabel: String { HRZone(rawValue: hrZone)?.label ?? "Zone \(hrZone)" }
    var formattedDuration: String? {
        guard let s = durationSec else { return nil }
        let m = s / 60; let sec = s % 60
        return sec == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", sec))"
    }
}

// MARK: - Watch Session

struct WatchWorkoutSession: Identifiable {
    let id = UUID()
    var startTime: Date
    var elapsedSeconds: Int = 0
    var heartRate: Double = 0
    var calories: Double = 0
    var distance: Double = 0
    var currentPace: Double = 0
    var avgHeartRate: Double = 0
    var heartRateSamples: [Double] = []
    var isPaused: Bool = false
    var isFinished: Bool = false

    var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    var formattedPace: String {
        guard currentPace > 0 else { return "--'--\"" }
        let m = Int(currentPace); let s = Int((currentPace - Double(m)) * 60)
        return String(format: "%d'%02d\"", m, s)
    }

    var formattedDistance: String { String(format: "%.2f", distance) }
    var hrZone: HRZone { HRZone.zone(for: heartRate) }
}

// MARK: - HR Zone

enum HRZone: Int, CaseIterable {
    case zone1 = 1, zone2, zone3, zone4, zone5

    var color: Color {
        switch self {
        case .zone1: return Color(red: 0.55, green: 0.80, blue: 0.95)
        case .zone2: return Color(red: 0.30, green: 0.85, blue: 0.55)
        case .zone3: return Color(red: 1.0, green: 0.82, blue: 0.30)
        case .zone4: return Color(red: 1.0, green: 0.55, blue: 0.20)
        case .zone5: return Color(red: 1.0, green: 0.35, blue: 0.40)
        }
    }

    var label: String {
        switch self {
        case .zone1: return "Zone 1"; case .zone2: return "Zone 2"
        case .zone3: return "Zone 3"; case .zone4: return "Zone 4"
        case .zone5: return "Zone 5"
        }
    }

    static func zone(for bpm: Double) -> HRZone {
        guard bpm > 0 else { return .zone1 }
        switch bpm {
        case ..<100: return .zone1; case 100..<120: return .zone2
        case 120..<140: return .zone3; case 140..<160: return .zone4
        default: return .zone5
        }
    }
}

// MARK: - Workout Phase enum

enum WorkoutPhase { case notStarted, active, paused, effortRating, summary }

// MARK: - Sample data

extension WatchWorkoutDay {
    static var sampleToday: WatchWorkoutDay {
        WatchWorkoutDay(
            planWeekDay: "sample-1", planId: "sample",
            scheduledDate: DateFormatter.yyyyMMdd.string(from: Date()),
            weekNumber: 1, dayNumber: 1,
            type: "interval", title: "Interval Run", isRestDay: false,
            distance: "8 km", duration: "50 min", targetPace: "5:00/km", targetHRZone: 4,
            description: nil,
            coachMessage: "Hit your paces on the hard intervals. Recovery jogs should feel easy.",
            warmup: WorkoutSection(durationMin: 10, description: "Easy jog, build to Zone 2", targetPace: "6:30/km", hrZone: 2, intervals: nil),
            mainSet: WorkoutSection(durationMin: nil, description: "4×1km at 5:00/km with 90s recovery jog", targetPace: "5:00/km", hrZone: 4, intervals: [
                WorkoutInterval(type: "work", durationMin: 5, distanceKm: 1, targetPace: "5:00/km", hrZone: 4, notes: "Hard effort — Zone 4"),
                WorkoutInterval(type: "rest", durationMin: 1.5, distanceKm: nil, targetPace: nil, hrZone: 1, notes: "Easy recovery jog"),
                WorkoutInterval(type: "work", durationMin: 5, distanceKm: 1, targetPace: "5:00/km", hrZone: 4, notes: "Hard effort — Zone 4"),
                WorkoutInterval(type: "rest", durationMin: 1.5, distanceKm: nil, targetPace: nil, hrZone: 1, notes: "Easy recovery jog"),
                WorkoutInterval(type: "work", durationMin: 5, distanceKm: 1, targetPace: "5:00/km", hrZone: 4, notes: "Hard effort — Zone 4"),
                WorkoutInterval(type: "rest", durationMin: 1.5, distanceKm: nil, targetPace: nil, hrZone: 1, notes: "Easy recovery jog"),
                WorkoutInterval(type: "work", durationMin: 5, distanceKm: 1, targetPace: "5:00/km", hrZone: 4, notes: "Hard effort — Zone 4"),
            ]),
            cooldown: WorkoutSection(durationMin: 10, description: "Easy jog, let HR drop below 130", targetPace: "7:00/km", hrZone: 1, intervals: nil),
            exercises: nil,
            isCompleted: false, completedAt: nil
        )
    }

    static var sampleRest: WatchWorkoutDay {
        WatchWorkoutDay(
            planWeekDay: "sample-rest", planId: "sample",
            scheduledDate: DateFormatter.yyyyMMdd.string(from: Date()),
            weekNumber: 3, dayNumber: 7,
            type: "rest", title: "Rest Day", isRestDay: true,
            distance: nil, duration: "—", targetPace: nil, targetHRZone: nil,
            description: nil,
            coachMessage: "Full rest. Sleep well, hydrate, and prepare for tomorrow's session.",
            warmup: nil, mainSet: nil, cooldown: nil, exercises: nil,
            isCompleted: false, completedAt: nil
        )
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
