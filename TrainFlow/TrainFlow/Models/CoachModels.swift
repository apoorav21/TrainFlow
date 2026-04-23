import Foundation
import SwiftUI

// MARK: - Chat Message
struct CoachMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String
    let timestamp: Date
    var insightCard: CoachInsight? = nil
}

enum MessageRole {
    case user, coach
}

// MARK: - Proactive Insight Card
struct CoachInsight: Identifiable {
    let id = UUID()
    let category: InsightCategory
    let title: String
    let body: String
    let metric: String?
    let metricLabel: String?
    let action: String?
    let color: Color
}

enum InsightCategory: String {
    case recovery = "Recovery"
    case load = "Load"
    case sleep = "Sleep"
    case performance = "Performance"
    case nutrition = "Nutrition"

    var icon: String {
        switch self {
        case .recovery: return "heart.circle.fill"
        case .load: return "bolt.circle.fill"
        case .sleep: return "moon.circle.fill"
        case .performance: return "chart.line.uptrend.xyaxis.circle.fill"
        case .nutrition: return "fork.knife.circle.fill"
        }
    }
}

// MARK: - Quick Prompt Suggestions
struct QuickPrompt: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let color: Color
    let message: String
}

// MARK: - Canned Responses (smart rules engine)
enum CoachEngine {
    static let quickPrompts: [QuickPrompt] = [
        QuickPrompt(label: "Am I overtraining?", icon: "exclamationmark.triangle.fill", color: TFTheme.accentOrange,
                    message: "Am I overtraining right now?"),
        QuickPrompt(label: "Today's plan", icon: "calendar.badge.checkmark", color: TFTheme.accentBlue,
                    message: "What should I do today based on my recovery?"),
        QuickPrompt(label: "Sleep quality", icon: "moon.zzz.fill", color: TFTheme.accentPurple,
                    message: "How is my sleep affecting my performance?"),
        QuickPrompt(label: "Race readiness", icon: "flag.checkered.2.crossed", color: TFTheme.accentYellow,
                    message: "How ready am I for my next race?"),
        QuickPrompt(label: "HRV explained", icon: "waveform.path.ecg", color: TFTheme.accentCyan,
                    message: "What does my HRV data tell you about my fitness?"),
        QuickPrompt(label: "Next PR tips", icon: "trophy.fill", color: TFTheme.accentGreen,
                    message: "What can I improve to break my 5K record?"),
    ]

    static let proactiveInsights: [CoachInsight] = [
        CoachInsight(
            category: .recovery,
            title: "HRV Rising — Push Today",
            body: "Your HRV is up 4.3ms this week, signaling strong adaptation. Your body is ready for a quality session. Consider a tempo run or threshold intervals.",
            metric: "48ms", metricLabel: "HRV",
            action: "View training plan",
            color: TFTheme.accentGreen
        ),
        CoachInsight(
            category: .load,
            title: "Training Load Peak Week",
            body: "You hit 50km last week — your highest ever. ATL (62) is above CTL (55), meaning accumulated fatigue. This week, aim for 35–40km to absorb the gains.",
            metric: "−7 TSB", metricLabel: "Form",
            action: "See load chart",
            color: TFTheme.accentOrange
        ),
        CoachInsight(
            category: .sleep,
            title: "Deep Sleep Below Target",
            body: "You averaged 68 min of deep sleep this week vs. the 90-min target. This may slow muscle repair. Try a consistent 10pm bedtime and avoid screens 1hr before sleep.",
            metric: "68 min", metricLabel: "Deep Sleep",
            action: "See sleep details",
            color: TFTheme.accentPurple
        ),
    ]

    // Rule-based response matching
    static func response(for input: String) -> CoachMessage {
        let lower = input.lowercased()

        if lower.contains("overtrain") {
            return CoachMessage(role: .coach, text: overtrain, timestamp: Date())
        } else if lower.contains("today") || lower.contains("recovery") {
            return CoachMessage(role: .coach, text: todayPlan, timestamp: Date())
        } else if lower.contains("sleep") {
            return CoachMessage(role: .coach, text: sleepResponse, timestamp: Date())
        } else if lower.contains("race") || lower.contains("ready") {
            return CoachMessage(role: .coach, text: raceReadiness, timestamp: Date())
        } else if lower.contains("hrv") {
            return CoachMessage(role: .coach, text: hrvExplained, timestamp: Date())
        } else if lower.contains("5k") || lower.contains("pr") || lower.contains("record") || lower.contains("improve") {
            return CoachMessage(role: .coach, text: prTips, timestamp: Date())
        } else if lower.contains("hi") || lower.contains("hello") || lower.contains("hey") {
            return CoachMessage(role: .coach, text: greeting, timestamp: Date())
        } else {
            return CoachMessage(role: .coach, text: generic, timestamp: Date())
        }
    }

    // MARK: - Response Templates
    private static let overtrain = """
    Based on your current metrics, you're walking the line but not overtrained — yet. ⚠️

    Here's the picture:
    • **ATL (62) > CTL (55)** — fatigue is outpacing fitness
    • **TSB = −7** — you're in the "tired but productive" zone
    • **HRV trending up** — your nervous system is adapting well

    My recommendation: take tomorrow easy (Z1 jog or rest), then reassess. If HRV drops below 44ms in the next 48hrs, take a full rest day.
    """

    private static let todayPlan = """
    Based on your recovery state, here's what I'd suggest for today:

    ✅ **Go for it: Moderate run (8–10km)**
    • HRV at 48ms — above your 7-day avg
    • Resting HR is 54bpm — nominal
    • Last hard session was 2 days ago

    **Suggested workout:** 2km warm-up, 5km at marathon pace (5:20/km), 2km cool-down. Aim for Z2–Z3, keep HR under 155bpm.

    If you feel flat in the first 10 min, drop back to an easy Z1 recovery jog instead.
    """

    private static let sleepResponse = """
    Your sleep this week is decent but there's room to optimize for better recovery. 🌙

    **Last 7 nights avg:**
    • Total: 6h 28min (target: 7h 30min+)
    • Deep sleep: 68 min (want 80–90 min)
    • REM: 93 min ✅ — great for memory consolidation

    **What this means for training:**
    Deep sleep is when growth hormone peaks and muscle repair happens. You're missing ~22 min per night. Over a training block, this compounds into slower adaptation.

    **Quick wins:** Consistent wake time (even weekends), keep the bedroom cool (18°C), and push your hardest sessions to morning so evening cortisol drops sooner.
    """

    private static let raceReadiness = """
    Race readiness check — here's my honest assessment: 🏁

    **Fitness (CTL): 55** — solid endurance base for 5K–10K
    **Form (TSB): −7** — slightly fatigued; you'd benefit from a 10-day taper

    **Prediction for 5K:** ~22:15–22:45 in peak condition
    **Current PR:** 22:34 — so you're close to another breakthrough!

    **For your next race:**
    1. Reduce volume by 30–40% in the final 10 days
    2. Keep 2 short intensity sessions (strides, short intervals)
    3. Sleep 8hrs the last 3 nights before race day

    What's your target race date? I can map out a precise taper plan.
    """

    private static let hrvExplained = """
    Great question — HRV is one of the best windows into your body's readiness. 📊

    **Your HRV: 48ms** (up 4.3ms this week — trending positive 📈)

    HRV measures the variation in time between heartbeats. Higher = more adaptable nervous system = better recovered.

    **Your personal range:** 43–53ms based on your 14-day history
    • Above 50ms → Push hard, your body is ready
    • 45–50ms → Moderate training is ideal
    • Below 44ms → Take it easy, prioritize recovery

    **This week's pattern:** Your HRV dipped mid-week (hard interval session) then rebounded. This "stress and recovery" curve is exactly what you want to see — it means the training is working.
    """

    private static let prTips = """
    To break your 5K PR of 22:34 (4:31/km), here are the highest-leverage changes: 🏆

    **1. Add one weekly VO₂ max session**
    → 6×800m at 4:10–4:20/km, 90s recovery
    → This is where your biggest gains come from at your current fitness level

    **2. Your easy runs might be too fast**
    → If HR on easy days is above 140bpm, you're bleeding recovery
    → Truly easy = conversational pace, ~5:45–6:00/km for you

    **3. Strength work (2×/week)**
    → Single-leg deadlifts, calf raises, hip bridges
    → Running economy improvements can shave 30–60s off 5K without extra mileage

    Based on your VO₂ max of 48.1, your theoretical 5K best is ~21:20. You have significant headroom! 🚀
    """

    private static let greeting = """
    Hey! 👋 I'm your AI Coach — I've been analyzing your training data and I'm ready to help.

    Here's your snapshot right now:
    • **HRV: 48ms** (↑ trending positive this week)
    • **Weekly volume: 38km** (on track for your goals)
    • **Sleep: 6h 28min avg** (a bit low — let's talk about that)
    • **Streak: 6 days** 🔥

    What would you like to dig into? You can ask me anything — from today's workout recommendation to race strategy, overtraining risk, or how to interpret your health metrics.
    """

    private static let generic = """
    That's a great question. Based on your current data here's what I can tell you:

    Your fitness (CTL: 55) is at its highest point in the last 3 months, and your HRV trend is positive — meaning your body is adapting well to the training load.

    The most important thing right now is managing the balance between pushing hard enough to improve and recovering enough to absorb those gains. Your current TSB of −7 suggests you're doing that reasonably well.

    Is there a specific aspect of your training or recovery you'd like me to analyze in more detail? I can look at sleep, load, race readiness, or specific workouts.
    """
}
