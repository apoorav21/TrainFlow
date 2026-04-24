import Foundation
import WatchConnectivity

final class PhoneSessionManager: NSObject, ObservableObject {
    static let shared = PhoneSessionManager()

    @Published var watchReachable = false
    @Published var lastWorkoutReport: WorkoutReport?

    private var pendingData: Data?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send today's workout to watch

    func sendTodayWorkout(_ day: TFWorkoutDay) {
        guard WCSession.isSupported() else { return }
        guard let data = try? JSONEncoder().encode(day) else { return }
        pendingData = data
        if WCSession.default.activationState == .activated {
            transmit(data)
        }
    }

    private func transmit(_ data: Data) {
        let context: [String: Any] = ["today_workout": data]
        try? WCSession.default.updateApplicationContext(context)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil)
        }
    }

    // MARK: - Handle workout completion from watch

    private func handleWorkoutComplete(_ payload: [String: Any]) {
        guard let planWeekDay = payload["planWeekDay"] as? String,
              let planId = payload["planId"] as? String else { return }

        Task {
            let log = TFWorkoutLog(
                planId: planId,
                workoutDayId: planWeekDay,
                workoutType: payload["workoutType"] as? String ?? "Workout",
                scheduledDate: payload["scheduledDate"] as? String,
                actualDistance: payload["distance"] as? Double,
                actualDurationMin: (payload["elapsedSeconds"] as? Int).map { $0 / 60 },
                avgHeartRate: (payload["avgHeartRate"] as? Double).map { Int($0) },
                peakHeartRate: (payload["peakHeartRate"] as? Double).map { Int($0) },
                calories: payload["calories"] as? Double,
                avgPace: payload["avgPace"] as? Double,
                effortRating: payload["effortRating"] as? Int,
                notes: "Completed from Apple Watch",
                hrvPost: nil
            )

            do {
                _ = try await TrainingService.shared.logWorkout(log)
            } catch {
                NSLog("[PhoneSessionManager] Failed to log workout: \(error)")
            }

            do {
                let report = try await TrainingService.shared.generateWorkoutReport(
                    planId: planId,
                    daySK: planWeekDay,
                    sessionData: payload
                )
                await MainActor.run {
                    self.lastWorkoutReport = report
                }
                NotificationCenter.default.post(
                    name: .workoutReportReady,
                    object: nil,
                    userInfo: ["planWeekDay": planWeekDay, "report": report]
                )
            } catch {
                NSLog("[PhoneSessionManager] Failed to generate report: \(error)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.watchReachable = session.isReachable
            if activationState == .activated, let data = self.pendingData {
                self.transmit(data)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.watchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let payload = message["workout_complete"] as? [String: Any] {
            handleWorkoutComplete(payload)
        }
        if message["request_today_workout"] as? Bool == true {
            Task { await self.pushTodayWorkoutToWatch() }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let payload = applicationContext["workout_complete"] as? [String: Any] {
            handleWorkoutComplete(payload)
        }
    }

    // Fetch today's workout from the API and push it to the Watch
    func pushTodayWorkoutToWatch() async {
        guard WCSession.isSupported() else { return }
        do {
            guard let plan = try await TrainingService.shared.fetchActivePlan() else { return }
            let days = try await TrainingService.shared.fetchWorkoutDays(planId: plan.id)
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let todayStr = f.string(from: Date())
            if let today = days.first(where: { $0.scheduledDate == todayStr }) {
                sendTodayWorkout(today)
            }
        } catch {
            NSLog("[PhoneSessionManager] pushTodayWorkoutToWatch failed: %@", error.localizedDescription)
        }
    }
}

// MARK: - Supporting types

struct WorkoutReport: Codable {
    let planWeekDay: String
    let aiReport: String
    let generatedAt: String
    let nextWorkoutSuggestion: String?
}

extension Notification.Name {
    static let workoutReportReady = Notification.Name("workoutReportReady")
    static let openAICoachWithMessage = Notification.Name("openAICoachWithMessage")
    static let planDidUpdate = Notification.Name("planDidUpdate")
}
