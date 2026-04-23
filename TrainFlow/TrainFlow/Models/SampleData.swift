import Foundation

struct DailySnapshot {
    let activeCalories: Int
    let calorieGoal: Int
    let steps: Int
    let distance: Double // km
    let exerciseMinutes: Int
    let exerciseGoal: Int
    let standHours: Int
    let standGoal: Int
    let restingHR: Int
    let hrv: Int
    let sleepHours: Double
    let vo2Max: Double
    let weight: Double
}

struct RecentWorkout: Identifiable {
    let id = UUID()
    let type: WorkoutType
    let title: String
    let date: Date
    let duration: TimeInterval
    let distance: Double?
    let calories: Int
    let avgHR: Int
    let pace: String?
}

enum WorkoutType: String, CaseIterable {
    case running = "Running"
    case cycling = "Cycling"
    case strength = "Strength"
    case swimming = "Swimming"
    case yoga = "Yoga"
    case hiit = "HIIT"

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .strength: return "dumbbell.fill"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        case .hiit: return "flame.fill"
        }
    }

    var color: SwiftUIColor {
        switch self {
        case .running: return TFTheme.accentOrange
        case .cycling: return TFTheme.accentBlue
        case .strength: return TFTheme.accentPurple
        case .swimming: return TFTheme.accentCyan
        case .yoga: return TFTheme.accentGreen
        case .hiit: return TFTheme.accentRed
        }
    }
}

import SwiftUI
typealias SwiftUIColor = Color

struct PlannedWorkoutItem: Identifiable {
    let id = UUID()
    let type: WorkoutType
    let title: String
    let subtitle: String
    let targetDuration: String
    let effortLevel: String
}

enum SampleData {
    static let snapshot = DailySnapshot(
        activeCalories: 487,
        calorieGoal: 650,
        steps: 8234,
        distance: 6.2,
        exerciseMinutes: 38,
        exerciseGoal: 45,
        standHours: 8,
        standGoal: 12,
        restingHR: 54,
        hrv: 48,
        sleepHours: 7.3,
        vo2Max: 46.2,
        weight: 76.5
    )

    static let todayWorkout = PlannedWorkoutItem(
        type: .running,
        title: "Tempo Run",
        subtitle: "Build phase • Week 3",
        targetDuration: "45 min • 8 km",
        effortLevel: "Moderate"
    )

    static let recentWorkouts: [RecentWorkout] = [
        RecentWorkout(type: .running, title: "Easy Run", date: Date().addingTimeInterval(-86400), duration: 2340, distance: 6.1, calories: 420, avgHR: 138, pace: "6:24"),
        RecentWorkout(type: .strength, title: "Upper Body", date: Date().addingTimeInterval(-172800), duration: 3600, distance: nil, calories: 310, avgHR: 118, pace: nil),
        RecentWorkout(type: .cycling, title: "Zone 2 Ride", date: Date().addingTimeInterval(-259200), duration: 5400, distance: 38.5, calories: 580, avgHR: 132, pace: nil),
        RecentWorkout(type: .running, title: "Interval Session", date: Date().addingTimeInterval(-345600), duration: 2700, distance: 7.2, calories: 510, avgHR: 156, pace: "5:48"),
        RecentWorkout(type: .swimming, title: "Pool Laps", date: Date().addingTimeInterval(-432000), duration: 2400, distance: 1.8, calories: 340, avgHR: 142, pace: nil),
    ]

    static let weeklyCalories: [Double] = [520, 0, 480, 310, 580, 510, 340]
    static let weeklyHR: [Int] = [52, 54, 53, 55, 54, 52, 54]
    static let weeklyHRV: [Int] = [45, 42, 48, 44, 50, 48, 46]
}
