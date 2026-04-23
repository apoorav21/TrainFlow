import Foundation
import SwiftUI

// MARK: - Vitals
struct VitalReading {
    let value: Double
    let unit: String
    let date: Date
}

struct HRVDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct HeartMetrics {
    var restingHR: Int = 0
    var restingHRTrend: Double = 0        // negative = improving
    var hrv: Double = 0
    var hrvTrend: Double = 0
    var walkingAvgHR: Int = 0
    var vo2Max: Double = 0
    var hrvHistory: [HRVDataPoint] = []
    var restingHRHistory: [HRVDataPoint] = []
}

// MARK: - Sleep
struct SleepStageSegment: Identifiable {
    let id = UUID()
    let stage: SleepStage
    let minutes: Double
}

enum SleepStage: String, CaseIterable {
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"

    var color: Color {
        switch self {
        case .awake: return TFTheme.accentRed.opacity(0.8)
        case .rem:   return TFTheme.accentPurple
        case .core:  return TFTheme.accentBlue
        case .deep:  return TFTheme.accentCyan
        }
    }

    var icon: String {
        switch self {
        case .awake: return "eye.fill"
        case .rem:   return "sparkles"
        case .core:  return "moon.fill"
        case .deep:  return "moon.zzz.fill"
        }
    }
}

struct NightSleep: Identifiable {
    let id = UUID()
    let date: Date
    let totalHours: Double
    let stages: [SleepStageSegment]
    let respiratoryRate: Double
    let consistency: Double   // 0–1
}

// MARK: - Body
struct BodyMetrics {
    var weight: Double = 0           // kg
    var bmi: Double = 0
    var bodyFat: Double = 0          // %
    var leanMass: Double = 0         // kg
    var weightHistory: [HRVDataPoint] = []
}

// MARK: - Activity
struct ActivityMetrics {
    var steps: Int = 0
    var distance: Double = 0         // km
    var activeCalories: Int = 0
    var basalCalories: Int = 0
    var exerciseMinutes: Int = 0
    var standHours: Int = 0
    var flightsClimbed: Int = 0
    var walkingSpeed: Double = 0     // km/h
    var weeklySteps: [HRVDataPoint] = []  // 7-day daily step totals
}

// MARK: - Respiratory
struct RespiratoryMetrics {
    var respiratoryRate: Double = 0
    var bloodOxygen: Double = 0      // %
}

// MARK: - Sample fallback data for simulator
enum HealthSampleData {
    static func makeHRVHistory() -> [HRVDataPoint] {
        let values: [Double] = [42, 45, 44, 48, 46, 43, 50, 47, 52, 49, 48, 51, 53, 48]
        return values.enumerated().map { i, v in
            HRVDataPoint(date: Date().addingTimeInterval(Double(i - 13) * 86400), value: v)
        }
    }

    static func makeRHRHistory() -> [HRVDataPoint] {
        let values: [Double] = [57, 56, 55, 54, 56, 55, 54, 53, 54, 52, 54, 53, 52, 54]
        return values.enumerated().map { i, v in
            HRVDataPoint(date: Date().addingTimeInterval(Double(i - 13) * 86400), value: v)
        }
    }

    static func makeWeightHistory() -> [HRVDataPoint] {
        let values: [Double] = [78.2, 78.0, 77.8, 77.5, 77.6, 77.3, 77.1, 76.9, 77.0, 76.7, 76.5, 76.4, 76.6, 76.5]
        return values.enumerated().map { i, v in
            HRVDataPoint(date: Date().addingTimeInterval(Double(i - 13) * 86400), value: v)
        }
    }

    static func makeSleepNights() -> [NightSleep] {
        let stageSets: [[SleepStageSegment]] = [
            [.init(stage: .deep, minutes: 72), .init(stage: .core, minutes: 198), .init(stage: .rem, minutes: 95), .init(stage: .awake, minutes: 15)],
            [.init(stage: .deep, minutes: 58), .init(stage: .core, minutes: 210), .init(stage: .rem, minutes: 88), .init(stage: .awake, minutes: 24)],
            [.init(stage: .deep, minutes: 84), .init(stage: .core, minutes: 205), .init(stage: .rem, minutes: 101), .init(stage: .awake, minutes: 10)],
            [.init(stage: .deep, minutes: 65), .init(stage: .core, minutes: 195), .init(stage: .rem, minutes: 92), .init(stage: .awake, minutes: 28)],
            [.init(stage: .deep, minutes: 78), .init(stage: .core, minutes: 202), .init(stage: .rem, minutes: 98), .init(stage: .awake, minutes: 12)],
            [.init(stage: .deep, minutes: 70), .init(stage: .core, minutes: 208), .init(stage: .rem, minutes: 94), .init(stage: .awake, minutes: 18)],
            [.init(stage: .deep, minutes: 80), .init(stage: .core, minutes: 200), .init(stage: .rem, minutes: 100), .init(stage: .awake, minutes: 14)],
        ]
        return stageSets.enumerated().map { i, stages in
            let total = stages.reduce(0) { $0 + $1.minutes } / 60.0
            return NightSleep(
                date: Date().addingTimeInterval(Double(i - 6) * 86400),
                totalHours: total,
                stages: stages,
                respiratoryRate: Double.random(in: 13.5...15.2),
                consistency: Double.random(in: 0.72...0.95)
            )
        }
    }

    static var heart: HeartMetrics {
        var h = HeartMetrics()
        h.restingHR = 54
        h.restingHRTrend = -2.1
        h.hrv = 48
        h.hrvTrend = 4.3
        h.walkingAvgHR = 82
        h.vo2Max = 46.2
        h.hrvHistory = makeHRVHistory()
        h.restingHRHistory = makeRHRHistory()
        return h
    }

    static var body: BodyMetrics {
        var b = BodyMetrics()
        b.weight = 76.5
        b.bmi = 23.4
        b.bodyFat = 14.8
        b.leanMass = 65.2
        b.weightHistory = makeWeightHistory()
        return b
    }

    static var activity: ActivityMetrics {
        var a = ActivityMetrics()
        a.steps = 8234
        a.distance = 6.2
        a.activeCalories = 487
        a.basalCalories = 1820
        a.exerciseMinutes = 38
        a.standHours = 8
        a.flightsClimbed = 12
        a.walkingSpeed = 5.4
        return a
    }

    static var respiratory: RespiratoryMetrics {
        var r = RespiratoryMetrics()
        r.respiratoryRate = 14.2
        r.bloodOxygen = 98.1
        return r
    }

    static func makeVO2History(base: Double) -> [HRVDataPoint] {
        let deltas: [Double] = [-0.4, 0.2, -0.1, 0.3, 0.1, -0.2, 0.4, 0.0, 0.2, -0.1, 0.3, 0.1, 0.2, 0.0]
        var val = base - 1.0
        return deltas.enumerated().map { i, d in
            val += d
            return HRVDataPoint(date: Date().addingTimeInterval(Double(i - 13) * 86400), value: val)
        }
    }

    static func makeStepsHistory(base: Double) -> [HRVDataPoint] {
        let vals: [Double] = [7200, 9100, 8400, 11200, 6800, 10300, 8900, 7600, 9500, 8100, 10800, 7900, 8600, base]
        return vals.enumerated().map { i, v in
            HRVDataPoint(date: Date().addingTimeInterval(Double(i - 13) * 86400), value: v)
        }
    }

    static func makeCaloriesHistory(base: Double) -> [HRVDataPoint] {
        let vals: [Double] = [380, 520, 460, 610, 320, 580, 440, 390, 540, 420, 630, 410, 490, base]
        return vals.enumerated().map { i, v in
            HRVDataPoint(date: Date().addingTimeInterval(Double(i - 13) * 86400), value: v)
        }
    }

    static func makeBloodOxygenHistory() -> [HRVDataPoint] {
        let vals: [Double] = [98, 97, 98, 99, 98, 98, 97, 98, 99, 98, 97, 98, 98, 98]
        return vals.enumerated().map { i, v in
            HRVDataPoint(date: Date().addingTimeInterval(Double(i - 13) * 86400), value: v)
        }
    }
}
