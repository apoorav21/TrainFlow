import Foundation
import SwiftUI

// MARK: - Training Load
struct WeeklyLoad: Identifiable {
    let id = UUID()
    let weekOffset: Int      // 0 = this week, -1 = last week…
    let label: String
    let acuteLoad: Double    // ATL – 7-day
    let chronicLoad: Double  // CTL – 42-day
    let tsb: Double          // Training Stress Balance = CTL - ATL
    let distanceKm: Double
    let durationMin: Int
    let sessionCount: Int
}

// MARK: - Personal Record
struct PersonalRecord: Identifiable {
    let id = UUID()
    let event: String
    let icon: String
    let value: String
    let detail: String
    let date: Date
    let color: Color
    let prevValue: String?
    let improvement: String?
}

// MARK: - Streak / Heatmap
struct ActivityDay: Identifiable {
    let id = UUID()
    let date: Date
    let load: Double   // 0 = rest, 1–3 = light, 4–7 = moderate, 8–10 = heavy
    var intensity: HeatmapIntensity {
        switch load {
        case 0: return .none
        case 1...3: return .light
        case 4...6: return .moderate
        case 7...9: return .hard
        default: return .peak
        }
    }
}

enum HeatmapIntensity {
    case none, light, moderate, hard, peak
    var color: Color {
        switch self {
        case .none: return Color.white.opacity(0.06)
        case .light: return TFTheme.accentGreen.opacity(0.30)
        case .moderate: return TFTheme.accentGreen.opacity(0.55)
        case .hard: return TFTheme.accentOrange.opacity(0.70)
        case .peak: return TFTheme.accentRed.opacity(0.85)
        }
    }
}

// MARK: - Sample Progress Data
enum ProgressSampleData {

    // 12 weeks of load data
    static let weeklyLoads: [WeeklyLoad] = {
        let labels = ["Apr 6","Mar 30","Mar 23","Mar 16","Mar 9","Mar 2",
                      "Feb 23","Feb 16","Feb 9","Feb 2","Jan 26","Jan 19"]
        let atl: [Double] = [62, 68, 71, 65, 72, 78, 70, 60, 52, 45, 38, 30]
        let ctl: [Double] = [55, 53, 52, 50, 49, 48, 45, 42, 38, 33, 28, 22]
        let dist: [Double] = [38, 42, 45, 38, 46, 50, 44, 35, 30, 25, 20, 14]
        let dur:  [Int]    = [210,235,250,205,260,280,245,195,170,145,115,85]
        let sess: [Int]    = [5, 5, 6, 4, 5, 6, 5, 4, 4, 3, 3, 2]
        return labels.indices.map { i in
            WeeklyLoad(
                weekOffset: -i,
                label: labels[i],
                acuteLoad: atl[i],
                chronicLoad: ctl[i],
                tsb: ctl[i] - atl[i],
                distanceKm: dist[i],
                durationMin: dur[i],
                sessionCount: sess[i]
            )
        }.reversed()
    }()

    static let personalRecords: [PersonalRecord] = [
        PersonalRecord(event: "5K", icon: "figure.run", value: "22:34",
                       detail: "April 1 • Riverside Park",
                       date: Date().addingTimeInterval(-5 * 86400),
                       color: TFTheme.accentOrange,
                       prevValue: "23:12", improvement: "−38s"),
        PersonalRecord(event: "10K", icon: "figure.run.circle.fill", value: "47:18",
                       detail: "Mar 22 • Sunday Long Run",
                       date: Date().addingTimeInterval(-15 * 86400),
                       color: TFTheme.accentRed,
                       prevValue: "48:50", improvement: "−1:32"),
        PersonalRecord(event: "Longest Run", icon: "map.fill", value: "22.4 km",
                       detail: "Mar 16 • Trail Route",
                       date: Date().addingTimeInterval(-21 * 86400),
                       color: TFTheme.accentPurple,
                       prevValue: "20.1 km", improvement: "+2.3 km"),
        PersonalRecord(event: "Best Pace", icon: "gauge.with.needle.fill", value: "4:48 /km",
                       detail: "Apr 1 • 5K Race",
                       date: Date().addingTimeInterval(-5 * 86400),
                       color: TFTheme.accentYellow,
                       prevValue: "4:58 /km", improvement: "−10s"),
        PersonalRecord(event: "Max VO₂", icon: "lungs.fill", value: "48.1",
                       detail: "Mar 30 • Apple Watch est.",
                       date: Date().addingTimeInterval(-7 * 86400),
                       color: TFTheme.accentCyan,
                       prevValue: "46.2", improvement: "+1.9"),
        PersonalRecord(event: "Weekly Distance", icon: "calendar.badge.checkmark", value: "50 km",
                       detail: "Mar 2 • Peak Build Week",
                       date: Date().addingTimeInterval(-35 * 86400),
                       color: TFTheme.accentBlue,
                       prevValue: "42 km", improvement: "+8 km"),
    ]

    // 16-week heatmap (112 days)
    static let activityDays: [ActivityDay] = {
        let calendar = Calendar.current
        let today = Date()
        let loads: [Double] = [
            0,5,7,0,8,6,0, 0,4,6,0,7,8,0, 0,5,6,0,9,7,0, 0,3,0,0,5,6,0,
            0,6,8,0,9,8,0, 0,5,7,0,10,8,0,0,4,6,0,7,9,0, 0,5,0,0,6,7,0,
            0,6,7,0,8,9,0, 0,4,5,0,7,6,0, 0,5,6,0,8,7,0, 0,3,0,0,4,5,0,
            0,5,7,0,8,6,0, 0,6,8,0,9,7,0, 0,5,6,0,7,8,0, 0,4,0,0,5,6,0
        ]
        return loads.indices.map { i in
            let daysBack = loads.count - 1 - i
            let date = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
            return ActivityDay(date: date, load: loads[i])
        }
    }()

    static var currentStreak: Int { 6 }
    static var longestStreak: Int { 14 }
    static var totalWorkouts: Int { 68 }
    static var totalDistanceKm: Double { 412.5 }
}
