import Foundation
import SwiftUI

// MARK: - Goal Types
enum GoalType: String, CaseIterable, Identifiable {
    case marathon = "Marathon"
    case halfMarathon = "Half Marathon"
    case tenK = "10K"
    case fiveK = "5K"
    case triathlon = "Triathlon"
    case cyclingEvent = "Cycling Event"
    case weightLoss = "Weight Loss"
    case buildStrength = "Build Strength"
    case improveCardio = "Improve Cardio"
    case custom = "Custom Goal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .marathon, .halfMarathon, .tenK, .fiveK: return "figure.run"
        case .triathlon: return "figure.open.water.swim"
        case .cyclingEvent: return "figure.outdoor.cycle"
        case .weightLoss: return "scalemass.fill"
        case .buildStrength: return "dumbbell.fill"
        case .improveCardio: return "heart.fill"
        case .custom: return "star.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .marathon, .halfMarathon, .tenK, .fiveK: return TFTheme.accentOrange
        case .triathlon: return TFTheme.accentCyan
        case .cyclingEvent: return TFTheme.accentBlue
        case .weightLoss: return TFTheme.accentYellow
        case .buildStrength: return TFTheme.accentPurple
        case .improveCardio: return TFTheme.accentRed
        case .custom: return TFTheme.accentGreen
        }
    }

    var category: String {
        switch self {
        case .marathon, .halfMarathon, .tenK, .fiveK: return "Race"
        case .triathlon: return "Race"
        case .cyclingEvent: return "Race"
        case .weightLoss, .buildStrength, .improveCardio: return "Fitness"
        case .custom: return "Custom"
        }
    }
}

enum FitnessLevel: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }
    var description: String {
        switch self {
        case .beginner: return "New to structured training"
        case .intermediate: return "1–2 years of consistent training"
        case .advanced: return "3+ years, competing regularly"
        }
    }
}

// MARK: - Planned Workout Day
enum TrainingDayType: String, CaseIterable {
    case easyRun = "Easy Run"
    case longRun = "Long Run"
    case tempo = "Tempo"
    case intervals = "Intervals"
    case strength = "Strength"
    case crossTrain = "Cross-Train"
    case rest = "Rest"
    case recovery = "Recovery"
    case race = "Race"

    var workoutType: WorkoutType? {
        switch self {
        case .easyRun, .longRun, .tempo, .intervals: return .running
        case .strength: return .strength
        case .crossTrain: return .cycling
        case .race: return .running
        case .rest, .recovery: return nil
        }
    }

    var color: Color {
        switch self {
        case .easyRun: return TFTheme.accentGreen
        case .longRun: return TFTheme.accentOrange
        case .tempo: return TFTheme.accentYellow
        case .intervals: return TFTheme.accentRed
        case .strength: return TFTheme.accentPurple
        case .crossTrain: return TFTheme.accentBlue
        case .rest: return TFTheme.textTertiary
        case .recovery: return TFTheme.accentCyan
        case .race: return TFTheme.accentOrange
        }
    }

    var icon: String {
        switch self {
        case .easyRun: return "figure.run"
        case .longRun: return "figure.run.circle.fill"
        case .tempo: return "gauge.with.needle.fill"
        case .intervals: return "bolt.fill"
        case .strength: return "dumbbell.fill"
        case .crossTrain: return "figure.outdoor.cycle"
        case .rest: return "moon.zzz.fill"
        case .recovery: return "leaf.fill"
        case .race: return "flag.checkered"
        }
    }

    var effortLabel: String {
        switch self {
        case .easyRun: return "Easy • Zone 2"
        case .longRun: return "Moderate • Zone 2–3"
        case .tempo: return "Hard • Zone 3–4"
        case .intervals: return "Very Hard • Zone 4–5"
        case .strength: return "Moderate effort"
        case .crossTrain: return "Easy • Zone 1–2"
        case .rest: return "No activity"
        case .recovery: return "Very Easy • Zone 1"
        case .race: return "Max effort"
        }
    }
}

struct TrainingDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayType: TrainingDayType
    let title: String
    let targetDistance: String?
    let targetDuration: String
    let instructions: String
    var isCompleted: Bool = false
    var phase: TrainingPhase
}

enum TrainingPhase: String {
    case base = "Base"
    case build = "Build"
    case peak = "Peak"
    case taper = "Taper"

    var color: Color {
        switch self {
        case .base: return TFTheme.accentBlue
        case .build: return TFTheme.accentOrange
        case .peak: return TFTheme.accentRed
        case .taper: return TFTheme.accentGreen
        }
    }
}

struct TrainingWeek: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let phase: TrainingPhase
    let days: [TrainingDay]
    let totalDistance: Double
    let totalDuration: String
    var isDeload: Bool = false
}

struct TrainingGoal {
    let type: GoalType
    let goalDate: Date
    let fitnessLevel: FitnessLevel
    let daysPerWeek: Int
    let maxHoursPerWeek: Double
    let restDays: Set<Int> // 0 = Sunday, 1 = Monday...
}

// MARK: - Plan Generator
enum PlanGenerator {
    static func generate(for goal: TrainingGoal) -> [TrainingWeek] {
        let calendar = Calendar.current
        let today = Date()
        let weeksUntilGoal = max(4, calendar.dateComponents([.weekOfYear], from: today, to: goal.goalDate).weekOfYear ?? 12)
        let totalWeeks = min(weeksUntilGoal, 16)

        let baseWeeks = Int(Double(totalWeeks) * 0.35)
        let buildWeeks = Int(Double(totalWeeks) * 0.35)
        let peakWeeks = Int(Double(totalWeeks) * 0.20)
        let taperWeeks = totalWeeks - baseWeeks - buildWeeks - peakWeeks

        var weeks: [TrainingWeek] = []
        var weekStart = today

        let phases: [(TrainingPhase, Int)] = [
            (.base, baseWeeks), (.build, buildWeeks),
            (.peak, peakWeeks), (.taper, taperWeeks)
        ]

        var weekNumber = 1
        for (phase, count) in phases {
            for i in 0..<count {
                let isDeload = (i + 1) % 4 == 0
                let days = generateDays(
                    weekStart: weekStart,
                    weekNumber: weekNumber,
                    phase: phase,
                    goal: goal,
                    isDeload: isDeload
                )
                let dist = days.compactMap { distanceValue($0.targetDistance) }.reduce(0, +)
                weeks.append(TrainingWeek(
                    weekNumber: weekNumber,
                    phase: phase,
                    days: days,
                    totalDistance: dist,
                    totalDuration: totalDurationString(days),
                    isDeload: isDeload
                ))
                weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
                weekNumber += 1
            }
        }
        return weeks
    }

    private static func generateDays(
        weekStart: Date,
        weekNumber: Int,
        phase: TrainingPhase,
        goal: TrainingGoal,
        isDeload: Bool
    ) -> [TrainingDay] {
        let calendar = Calendar.current
        let schedule = weekSchedule(phase: phase, goal: goal, isDeload: isDeload)
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            let weekday = calendar.component(.weekday, from: date) - 1 // 0=Sun
            let dayType: TrainingDayType = goal.restDays.contains(weekday) ? .rest : schedule[dayOffset % schedule.count]
            return makeDay(date: date, type: dayType, phase: phase, weekNumber: weekNumber, isDeload: isDeload)
        }
    }

    private static func weekSchedule(phase: TrainingPhase, goal: TrainingGoal, isDeload: Bool) -> [TrainingDayType] {
        if isDeload {
            return [.easyRun, .rest, .crossTrain, .rest, .easyRun, .rest, .recovery]
        }
        switch phase {
        case .base:
            return [.easyRun, .strength, .easyRun, .rest, .easyRun, .longRun, .recovery]
        case .build:
            return [.easyRun, .tempo, .easyRun, .strength, .rest, .longRun, .recovery]
        case .peak:
            return [.easyRun, .intervals, .tempo, .rest, .easyRun, .longRun, .recovery]
        case .taper:
            return [.easyRun, .tempo, .rest, .easyRun, .rest, .easyRun, .recovery]
        }
    }

    private static func makeDay(date: Date, type: TrainingDayType, phase: TrainingPhase, weekNumber: Int, isDeload: Bool) -> TrainingDay {
        let factor = isDeload ? 0.6 : 1.0
        let weekFactor = min(1.0 + Double(weekNumber) * 0.05, 1.5)

        switch type {
        case .easyRun:
            let dist = (5.0 * factor * weekFactor).rounded(toPlaces: 1)
            return TrainingDay(date: date, dayType: type, title: "Easy Run",
                               targetDistance: "\(dist) km", targetDuration: "\(Int(dist * 6.5)) min",
                               instructions: "Run at a comfortable conversational pace. HR Zone 2 throughout. Focus on form and breathing rhythm.", phase: phase)
        case .longRun:
            let dist = (10.0 * factor * weekFactor).rounded(toPlaces: 1)
            return TrainingDay(date: date, dayType: type, title: "Long Run",
                               targetDistance: "\(dist) km", targetDuration: "\(Int(dist * 7)) min",
                               instructions: "Start easy, finish strong. First 2/3 in Zone 2, last 1/3 in Zone 3. Fuel every 45 minutes.", phase: phase)
        case .tempo:
            let dist = (7.0 * factor * weekFactor).rounded(toPlaces: 1)
            return TrainingDay(date: date, dayType: type, title: "Tempo Run",
                               targetDistance: "\(dist) km", targetDuration: "\(Int(dist * 5.5)) min",
                               instructions: "Warm up 10 min easy. Main set: comfortably hard pace (Zone 3–4). Cool down 10 min easy.", phase: phase)
        case .intervals:
            return TrainingDay(date: date, dayType: type, title: "Interval Session",
                               targetDistance: "6–8 km", targetDuration: "50 min",
                               instructions: "Warm up 15 min. 6×800m at Zone 4–5 with 90s recovery jog. Cool down 10 min.", phase: phase)
        case .strength:
            return TrainingDay(date: date, dayType: type, title: "Strength Training",
                               targetDistance: nil, targetDuration: "45 min",
                               instructions: "Full-body strength. Squats, deadlifts, lunges, core work. Focus on stability and running-specific movements.", phase: phase)
        case .crossTrain:
            return TrainingDay(date: date, dayType: type, title: "Cross-Training",
                               targetDistance: nil, targetDuration: "40 min",
                               instructions: "Low-impact cardio — cycling, swimming, or elliptical. Zone 1–2 only. Active recovery.", phase: phase)
        case .recovery:
            return TrainingDay(date: date, dayType: type, title: "Recovery",
                               targetDistance: nil, targetDuration: "20–30 min",
                               instructions: "Gentle yoga, foam rolling, or walking. Focus on mobility and relaxation. No elevated HR.", phase: phase)
        case .rest:
            return TrainingDay(date: date, dayType: type, title: "Rest Day",
                               targetDistance: nil, targetDuration: "—",
                               instructions: "Full rest. Sleep well, hydrate, and prepare for tomorrow's session.", phase: phase)
        case .race:
            return TrainingDay(date: date, dayType: type, title: "Race Day 🏁",
                               targetDistance: nil, targetDuration: "Goal time",
                               instructions: "Race day! Trust your training. Start conservative, negative split if possible.", phase: phase)
        }
    }

    private static func distanceValue(_ str: String?) -> Double? {
        guard let str else { return nil }
        let nums = str.components(separatedBy: .whitespaces)
        return nums.compactMap { Double($0.replacingOccurrences(of: "km", with: "")) }.first
    }

    private static func totalDurationString(_ days: [TrainingDay]) -> String {
        let total = days.filter { $0.dayType != .rest }.count
        return "\(total * 45) min est."
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
