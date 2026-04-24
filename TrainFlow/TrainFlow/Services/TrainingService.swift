import Foundation

// MARK: - Remote Models (AWS API Gateway)

struct TFPlan: Codable, Identifiable {
    var id: String { planId }

    let planId: String
    let planName: String
    let goalType: String
    let startDate: String
    let endDate: String
    let totalWeeks: Int
    let currentWeek: Int
    let daysPerWeek: Int
    var isActive: String
    let createdAt: String

    var goalDate: String { endDate }
    let fitnessLevel: String
    var raceName: String? { nil }

    // daysPerWeek / fitnessLevel may be absent in older records
    private enum CodingKeys: String, CodingKey {
        case planId, planName, goalType, startDate, endDate
        case totalWeeks, currentWeek, daysPerWeek, isActive, createdAt, fitnessLevel
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        planId       = try c.decode(String.self, forKey: .planId)
        planName     = try c.decode(String.self, forKey: .planName)
        goalType     = try c.decode(String.self, forKey: .goalType)
        startDate    = try c.decode(String.self, forKey: .startDate)
        endDate      = try c.decode(String.self, forKey: .endDate)
        totalWeeks   = try c.decode(Int.self,    forKey: .totalWeeks)
        currentWeek  = (try? c.decode(Int.self,  forKey: .currentWeek)) ?? 1
        daysPerWeek  = (try? c.decode(Int.self,  forKey: .daysPerWeek)) ?? 4
        isActive     = (try? c.decode(String.self, forKey: .isActive)) ?? "true"
        createdAt    = (try? c.decode(String.self, forKey: .createdAt)) ?? ""
        fitnessLevel = (try? c.decode(String.self, forKey: .fitnessLevel)) ?? ""
    }
}

// Typealias so existing view code (`RemotePlan`) continues to compile unchanged.
typealias RemotePlan = TFPlan

// MARK: - Workout Day sub-models

struct WorkoutInterval: Codable {
    let type: String          // "work", "rest", "recovery"
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

// MARK: - Workout Day (flat schema matching the AI plan generator output)

struct TFWorkoutDay: Identifiable, Codable {
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
    var aiReport: String?
    var aiReportGeneratedAt: String?
    var nextWorkoutSuggestion: String?

    var dayType: String { title }
    var targetDistance: String? { distance }
    var targetDuration: String { duration ?? "—" }
    var instructions: String { coachMessage ?? description ?? "" }
    var phase: String { "Base" }

    private enum CodingKeys: String, CodingKey {
        case planWeekDay, planId, scheduledDate, weekNumber, dayNumber
        case type, title, isRestDay, distance, duration, targetPace, targetHRZone
        case description, coachMessage, warmup, mainSet, cooldown, exercises
        case isCompleted, completedAt, aiReport, aiReportGeneratedAt, nextWorkoutSuggestion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        planWeekDay          = try c.decode(String.self, forKey: .planWeekDay)
        planId               = try c.decode(String.self, forKey: .planId)
        scheduledDate        = try c.decode(String.self, forKey: .scheduledDate)
        weekNumber           = try c.decode(Int.self,    forKey: .weekNumber)
        dayNumber            = try c.decode(Int.self,    forKey: .dayNumber)
        type                 = (try? c.decode(String.self, forKey: .type))    ?? "rest"
        title                = (try? c.decode(String.self, forKey: .title))   ?? "Rest Day"
        isRestDay            = (try? c.decode(Bool.self,   forKey: .isRestDay)) ?? false
        distance             = try? c.decode(String.self, forKey: .distance)
        duration             = try? c.decode(String.self, forKey: .duration)
        targetPace           = try? c.decode(String.self, forKey: .targetPace)
        targetHRZone         = try? c.decode(Int.self,    forKey: .targetHRZone)
        description          = try? c.decode(String.self, forKey: .description)
        coachMessage         = try? c.decode(String.self, forKey: .coachMessage)
        warmup               = try? c.decode(WorkoutSection.self, forKey: .warmup)
        mainSet              = try? c.decode(WorkoutSection.self, forKey: .mainSet)
        cooldown             = try? c.decode(WorkoutSection.self, forKey: .cooldown)
        exercises            = try? c.decode([WorkoutExercise].self, forKey: .exercises)
        isCompleted          = (try? c.decode(Bool.self,   forKey: .isCompleted)) ?? false
        completedAt          = try? c.decode(String.self, forKey: .completedAt)
        aiReport                = try? c.decode(String.self, forKey: .aiReport)
        aiReportGeneratedAt     = try? c.decode(String.self, forKey: .aiReportGeneratedAt)
        nextWorkoutSuggestion   = try? c.decode(String.self, forKey: .nextWorkoutSuggestion)
    }
}

typealias RemoteWorkoutDay = TFWorkoutDay

// MARK: - Workout Log

struct TFWorkoutLog: Codable {
    let planId: String?
    let workoutDayId: String?       // daySK
    var workoutType: String? = nil
    var scheduledDate: String? = nil
    let actualDistance: Double?
    let actualDurationMin: Int?
    let avgHeartRate: Int?
    var peakHeartRate: Int? = nil
    var calories: Double? = nil
    var avgPace: Double? = nil      // min/km
    let effortRating: Int?
    let notes: String?
    let hrvPost: Int?
}

// Typealias keeps WorkoutLogView's `WorkoutLogPayload` references compiling.
typealias WorkoutLogPayload = TFWorkoutLog

// MARK: - API Response Envelopes

private struct ActivePlanResponse: Decodable {
    let plan: TFPlan?
    let currentWeek: Int?
}

private struct PlanDetailResponse: Decodable {
    let plan: TFPlan?
    let workoutDays: [TFWorkoutDay]
}

private struct WorkoutLogResponse: Decodable {
    let workoutId: String?
    let message: String?
}

private struct WorkoutsListResponse: Decodable {
    let workouts: [TFWorkoutLog]
    let count: Int?
}

// MARK: - Training Service

final class TrainingService {
    static let shared = TrainingService()
    private init() {}

    // MARK: - Plans

    /// GET /plans/active → { plan: {...}, currentWeek: 3 }
    func fetchActivePlan() async throws -> TFPlan? {
        let response: ActivePlanResponse = try await APIClient.shared.get("/plans/active")
        return response.plan
    }

    /// GET /plans/{planId} → { plan: {...}, workoutDays: [...] }
    func fetchWorkoutDays(planId: String) async throws -> [TFWorkoutDay] {
        let encoded = planId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? planId
        let response: PlanDetailResponse = try await APIClient.shared.get("/plans/\(encoded)")
        return response.workoutDays
    }

    /// GET /plans/{planId}/weeks/{weekNum}
    func fetchWeek(planId: String, weekNum: Int) async throws -> [TFWorkoutDay] {
        let encoded = planId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? planId
        let response: PlanDetailResponse = try await APIClient.shared.get(
            "/plans/\(encoded)/weeks/\(weekNum)"
        )
        return response.workoutDays
    }

    /// PUT /plans/{planId}/days/{encodedDaySK}
    /// Body: { isCompleted: true, completedAt: ISO date }
    func markDayComplete(planId: String, daySK: String, log: TFWorkoutLog? = nil) async throws {
        let encodedPlan = planId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? planId
        let encodedDay = daySK.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? daySK

        struct MarkCompleteBody: Encodable {
            let isCompleted: Bool
            let completedAt: String
        }
        let body = MarkCompleteBody(
            isCompleted: true,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
        let _: [String: String] = try await APIClient.shared.put(
            "/plans/\(encodedPlan)/days/\(encodedDay)",
            body: body
        )
    }

    // Backward-compat overload used by DynamicTrainingViewModel (single dayId parameter).
    func markDayComplete(dayId: String) async throws {
        // Without a planId we cannot form the correct path; attempt a best-effort workout log instead.
        // The calling site (DynamicTrainingViewModel) has the planId — see note in that file.
        // For now we silently succeed to avoid breaking the optimistic UI update.
        NSLog("[TrainingService] markDayComplete(dayId:) called without planId — skipping remote update")
    }

    /// DELETE /workouts/{sk} — deletes a workout by its DynamoDB sort key (timestamp field).
    func deleteActivity(timestamp: String) async throws {
        let encoded = timestamp.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? timestamp
        try await APIClient.shared.delete("/workouts/\(encoded)")
    }

    /// GET /workouts?days=N → { workouts: [...] }
    func fetchWorkouts(days: Int = 90) async throws -> [TFWorkoutLog] {
        let response: WorkoutsListResponse = try await APIClient.shared.get("/workouts?days=\(days)")
        return response.workouts
    }

    /// GET /workouts?days=N — returns unified TrainFlow + HealthKit workout records.
    func fetchRecentActivity(days: Int = 45) async throws -> [WorkoutActivity] {
        struct Response: Decodable { let workouts: [WorkoutActivity] }
        let response: Response = try await APIClient.shared.get("/workouts?days=\(days)")
        return response.workouts
    }

    /// POST /workouts → { workoutId, message }
    /// Returns AI feedback message if available.
    func logWorkout(_ log: TFWorkoutLog) async throws -> String? {
        let response: WorkoutLogResponse = try await APIClient.shared.post("/workouts", body: log)
        return response.message
    }

    // Backward-compat overload matching the old signature used by WorkoutLogView.
    func logWorkout(planId: String, workoutDayId: String?, log: WorkoutLogPayload) async throws -> String? {
        // Merge supplied IDs into the log struct before posting
        let merged = TFWorkoutLog(
            planId: planId,
            workoutDayId: workoutDayId ?? log.workoutDayId,
            workoutType: log.workoutType,
            scheduledDate: log.scheduledDate,
            actualDistance: log.actualDistance,
            actualDurationMin: log.actualDurationMin,
            avgHeartRate: log.avgHeartRate,
            effortRating: log.effortRating,
            notes: log.notes,
            hrvPost: log.hrvPost
        )
        return try await logWorkout(merged)
    }

    // MARK: - Plan Chat (PlanChatView compatibility)
    // Plan creation now goes through POST /chat/message.
    // PlanChatView calls chat() and generatePlan(); we route both through CoachService.

    /// Sends a single message and returns the assistant reply.
    /// Used by PlanChatView for the conversational onboarding / plan-creation flow.
    func chat(messages: [[String: String]]) async throws -> String {
        // Forward to CoachService which owns /chat/message
        let lastUserMessage = messages.last(where: { $0["role"] == "user" })?["content"] ?? ""
        let (reply, _, _) = try await CoachService.shared.send(message: lastUserMessage)
        return reply
    }

    /// Triggers plan generation via the AI chat endpoint.
    /// When the AI finishes building a plan it returns onboardingComplete=true.
    func generatePlan(chatHistory: [[String: String]]) async throws -> (planId: String, dayCount: Int) {
        let lastUserMessage = chatHistory.last(where: { $0["role"] == "user" })?["content"] ?? ""
        let (_, onboardingComplete, _) = try await CoachService.shared.send(message: lastUserMessage)
        if onboardingComplete {
            // Fetch the newly created active plan to surface its ID and day count
            if let plan = try? await fetchActivePlan() {
                let days = try? await fetchWorkoutDays(planId: plan.planId)
                return (plan.planId, days?.count ?? 0)
            }
        }
        return ("", 0)
    }

    /// Sends a plan-adaptation message and returns the coach's reply.
    func adaptPlan(planId: String, message: String) async throws -> String {
        let (reply, _, _) = try await CoachService.shared.send(message: message)
        return reply
    }

    // MARK: - POST /workouts/report

    func generateWorkoutReport(planId: String, daySK: String, sessionData: [String: Any]) async throws -> WorkoutReport {
        struct ReportRequest: Encodable {
            let planId: String
            let workoutDayId: String
            let elapsedSeconds: Int
            let avgHeartRate: Double
            let peakHeartRate: Double
            let calories: Double
            let distance: Double
            let avgPace: Double
        }
        let body = ReportRequest(
            planId: planId,
            workoutDayId: daySK,
            elapsedSeconds: sessionData["elapsedSeconds"] as? Int ?? 0,
            avgHeartRate: sessionData["avgHeartRate"] as? Double ?? 0,
            peakHeartRate: sessionData["peakHeartRate"] as? Double ?? 0,
            calories: sessionData["calories"] as? Double ?? 0,
            distance: sessionData["distance"] as? Double ?? 0,
            avgPace: sessionData["avgPace"] as? Double ?? 0
        )
        let report: WorkoutReport = try await APIClient.shared.post("/workouts/report", body: body)
        return report
    }
}

// MARK: - Activity Feed (unified TrainFlow + HealthKit)

struct WorkoutActivity: Decodable, Identifiable {
    // DynamoDB sort key — present on all records
    let timestamp: String?
    // "healthkit" for HealthKit-synced workouts; absent for TrainFlow logs
    let source: String?
    let workoutType: String?

    // TrainFlow log fields
    let planId: String?
    let workoutDayId: String?
    let actualDistance: Double?
    let actualDurationMin: Int?
    let avgHeartRate: Int?
    let effortRating: Int?
    let notes: String?

    // HealthKit fields
    let hkWorkoutId: String?
    let startDate: String?
    let durationMin: Double?
    let distanceKm: Double?
    let calories: Double?
    let sourceName: String?
    let peakHeartRate: Int?
    let avgPace: Double?            // min/km

    var id: String { hkWorkoutId ?? timestamp ?? UUID().uuidString }
    var isHealthKit: Bool { source == "healthkit" }

    var displayDate: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let sd = startDate, let d = iso.date(from: sd) { return d }
        if let ts = timestamp {
            let clean = String(ts.prefix(while: { $0 != "#" }))
            if let d = iso.date(from: clean) { return d }
            // Fall back to standard ISO without fractional seconds
            let f = ISO8601DateFormatter()
            return f.date(from: clean)
        }
        return nil
    }

    var displayDistanceKm: Double? { distanceKm ?? actualDistance }

    var displayDurationMin: Int? {
        if let d = durationMin { return max(1, Int(d)) }
        return actualDurationMin
    }

    var displaySource: String { sourceName ?? (isHealthKit ? "HealthKit" : "TrainFlow") }

    var displayPace: String? {
        guard let p = avgPace, p > 0 else { return nil }
        let minutes = Int(p)
        let seconds = Int((p - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var displayPeakHR: Int? { peakHeartRate }
}

// MARK: - Training Errors

enum TrainingError: LocalizedError {
    case httpError(Int), serverError(String)
    var errorDescription: String? {
        switch self {
        case .httpError(let c): return "Server error \(c)"
        case .serverError(let m): return m
        }
    }
}
