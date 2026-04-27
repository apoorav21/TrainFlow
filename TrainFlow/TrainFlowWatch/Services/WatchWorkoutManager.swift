import Foundation
import HealthKit
import Combine
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif

// MARK: - Watch Workout Manager
@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    // MARK: - Published state
    @Published var phase: WorkoutPhase = .notStarted
    @Published var session: WatchWorkoutSession = WatchWorkoutSession(startTime: Date())
    @Published var todayWorkout: WatchWorkoutDay?
    @Published var isLoadingPlan: Bool = false
    @Published var authToken: String? = nil
    @Published var currentDay: WatchWorkoutDay? = nil
    @Published var workoutPhases: [WorkoutPhaseItem] = []
    @Published var currentPhaseIndex: Int = 0
    @Published var phaseElapsedSeconds: Int = 0
    @Published var effortRating: Int = 5
    @Published var workoutNotes: String = ""
    var phaseHRSamples: [[Double]] = []
    private var phaseTimer: Timer?

    var currentPhase: WorkoutPhaseItem? {
        workoutPhases.indices.contains(currentPhaseIndex) ? workoutPhases[currentPhaseIndex] : nil
    }

    // MARK: - Private
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var elapsedTimer: Timer?
    private var hrQuery: HKQuery?
    private var savedWorkout: HKWorkout?

    // MARK: - Init
    private override init() {
        super.init()
        requestHealthKitPermissions()
        setupWatchConnectivity()
        loadTodayWorkout()
    }

    // MARK: - WatchConnectivity Setup
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - HealthKit Permissions
    private func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKObjectType.workoutType()
        ]
        let readTypes: Set<HKObjectType> = types
        healthStore.requestAuthorization(toShare: types, read: readTypes) { _, _ in }
    }

    // MARK: - Load Today's Workout from UserDefaults (synced from phone)
    func loadTodayWorkout() {
        isLoadingPlan = true
        let todayStr = DateFormatter.yyyyMMdd.string(from: Date())

        // Only use UserDefaults cache if it is for today — stale data from previous days is ignored
        if let data = UserDefaults.standard.data(forKey: "watch_today_workout"),
           let day = try? JSONDecoder().decode(WatchWorkoutDay.self, from: data),
           day.scheduledDate == todayStr {
            todayWorkout = day
        }

        // Always prefer the latest context pushed from the phone (overrides any cache)
        if WCSession.isSupported() {
            let context = WCSession.default.receivedApplicationContext
            if !context.isEmpty { applyWorkoutData(context) }
        }
        isLoadingPlan = false
    }

    // MARK: - Request today's workout from phone
    func requestTodayWorkoutFromPhone() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = ["request_today_workout": true]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        }
    }

    // MARK: - Apply incoming workout data from phone
    func applyWorkoutData(_ context: [String: Any]) {
        guard let data = context["today_workout"] as? Data,
              let day = try? JSONDecoder().decode(WatchWorkoutDay.self, from: data) else { return }
        // Reject stale contexts pushed on a previous day
        let todayStr = DateFormatter.yyyyMMdd.string(from: Date())
        guard day.scheduledDate == todayStr else { return }
        UserDefaults.standard.set(data, forKey: "watch_today_workout")
        todayWorkout = day
    }

    // MARK: - Start Workout
    func startWorkout(type: HKWorkoutActivityType = .running, day: WatchWorkoutDay? = nil) {
        currentDay = day
        if let day = day {
            workoutPhases = day.workoutPhases
        }
        currentPhaseIndex = 0
        phaseElapsedSeconds = 0
        phaseHRSamples = Array(repeating: [], count: max(1, workoutPhases.count))

        let startDate = Date()
        session = WatchWorkoutSession(startTime: startDate)
        phase = .active
        startElapsedTimer()

        let config = HKWorkoutConfiguration()
        config.activityType = type
        config.locationType = .outdoor

        do {
            let ws = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = ws.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            ws.delegate = self
            builder.delegate = self
            self.workoutSession = ws
            self.workoutBuilder = builder

            ws.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { _, _ in }
        } catch {
            NSLog("[WatchWorkoutManager] HK session unavailable, running in mock mode: \(error)")
            startMockHRUpdates()
        }
    }

    // MARK: - Pause / Resume
    func pauseWorkout() {
        workoutSession?.pause()
        elapsedTimer?.invalidate()
        session.isPaused = true
        phase = .paused
    }

    func resumeWorkout() {
        workoutSession?.resume()
        startElapsedTimer()
        session.isPaused = false
        phase = .active
    }

    // MARK: - End Workout
    func endWorkout() {
        elapsedTimer?.invalidate()
        session.isFinished = true
        // Go to effort rating screen before summary — send to phone after rating is submitted
        phase = .effortRating

        guard let ws = workoutSession, let builder = workoutBuilder else { return }
        ws.end()
        builder.endCollection(withEnd: Date()) { [weak self] _, _ in
            builder.finishWorkout { [weak self] workout, _ in
                Task { @MainActor [weak self] in
                    self?.savedWorkout = workout
                }
            }
        }
    }

    // MARK: - Submit Effort Rating → move to notes screen
    func submitEffortRating(_ rating: Int) {
        effortRating = rating
        if let day = todayWorkout, !day.isCompleted {
            markTodayComplete()
        }
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
        phase = .notes
    }

    // MARK: - Submit workout notes (from dictation) → summary
    func submitWorkoutNotes(_ notes: String) {
        workoutNotes = notes
        sendWorkoutCompleteToPhone()
        phase = .summary
    }

    // MARK: - Skip notes → summary
    func skipWorkoutNotes() {
        sendWorkoutCompleteToPhone()
        phase = .summary
    }

    // MARK: - Send workout summary to phone
    private func sendWorkoutCompleteToPhone() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let day = todayWorkout else { return }

        var payload: [String: Any] = [
            "planWeekDay": day.planWeekDay,
            "planId": day.planId,
            "workoutType": day.type,
            "scheduledDate": day.scheduledDate,
            "elapsedSeconds": session.elapsedSeconds,
            "avgHeartRate": session.avgHeartRate,
            "peakHeartRate": session.heartRateSamples.max() ?? 0.0,
            "calories": session.calories,
            "distance": session.distance,
            "completedAt": ISO8601DateFormatter().string(from: Date()),
        ]
        if session.currentPace > 0 { payload["avgPace"] = session.currentPace }
        payload["effortRating"] = effortRating
        if !workoutNotes.isEmpty { payload["notes"] = workoutNotes }
        let sectionHRs: [[String: Any]] = workoutPhases.enumerated().compactMap { i, phase in
            let samples = phaseHRSamples.indices.contains(i) ? phaseHRSamples[i] : []
            guard !samples.isEmpty else { return nil }
            return ["phase": phase.label, "avgHR": Int((samples.reduce(0, +) / Double(samples.count)).rounded())]
        }
        if !sectionHRs.isEmpty { payload["sectionHeartRates"] = sectionHRs }

        let message: [String: Any] = ["workout_complete": payload]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }

    // MARK: - Discard / Reset
    func discardWorkout() {
        workoutSession?.end()
        elapsedTimer?.invalidate()
        resetSession()
    }

    func resetSession() {
        phase = .notStarted
        session = WatchWorkoutSession(startTime: Date())
        workoutSession = nil
        workoutBuilder = nil
        savedWorkout = nil
        workoutPhases = []
        currentPhaseIndex = 0
        phaseElapsedSeconds = 0
        effortRating = 5
        workoutNotes = ""
        phaseHRSamples = []
        phaseTimer?.invalidate()
        phaseTimer = nil
    }

    // MARK: - Mark today complete
    private func markTodayComplete() {
        guard var day = todayWorkout else { return }
        day.isCompleted = true
        day.completedAt = ISO8601DateFormatter().string(from: Date())
        todayWorkout = day
        if let data = try? JSONEncoder().encode(day) {
            UserDefaults.standard.set(data, forKey: "watch_today_workout")
        }
    }

    // MARK: - Phase Navigation
    func nextPhase() {
        phaseTimer?.invalidate()
        phaseElapsedSeconds = 0
        if currentPhaseIndex < workoutPhases.count - 1 {
            currentPhaseIndex += 1
            startPhaseTimer()
        }
    }

    func previousPhase() {
        phaseTimer?.invalidate()
        phaseElapsedSeconds = 0
        if currentPhaseIndex > 0 {
            currentPhaseIndex -= 1
            startPhaseTimer()
        }
    }

    private func startPhaseTimer() {
        guard currentPhase != nil else { return }
        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.phaseElapsedSeconds += 1
                // Auto-advance only for phases that have a fixed duration
                if let dur = self.currentPhase?.durationSec, self.phaseElapsedSeconds >= dur {
                    self.phaseTimer?.invalidate()
                    if self.currentPhaseIndex < self.workoutPhases.count - 1 {
                        self.currentPhaseIndex += 1
                        self.phaseElapsedSeconds = 0
                        self.startPhaseTimer()
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.notification)
                        #endif
                    }
                }
            }
        }
    }

    // MARK: - Elapsed Timer
    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .active else { return }
                self.session.elapsedSeconds += 1
            }
        }
        startPhaseTimer()
    }

    // MARK: - Mock HR (simulator fallback)
    private var mockHRTimer: Timer?
    private func startMockHRUpdates() {
        mockHRTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .active else { return }
                let base = 135.0
                let hr = base + Double.random(in: -15...25)
                self.session.heartRate = hr
                self.session.heartRateSamples.append(hr)
                let total = self.session.heartRateSamples.reduce(0, +)
                self.session.avgHeartRate = total / Double(self.session.heartRateSamples.count)
                let idx = self.currentPhaseIndex
                if self.phaseHRSamples.indices.contains(idx) {
                    self.phaseHRSamples[idx].append(hr)
                }
                self.session.calories += Double.random(in: 4...8)
                let distIncrement = (hr / 140.0) * 0.003
                self.session.distance += distIncrement
                if self.session.elapsedSeconds > 0 && self.session.distance > 0 {
                    let paceMinPerKm = (Double(self.session.elapsedSeconds) / 60.0) / self.session.distance
                    self.session.currentPace = paceMinPerKm
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                         didChangeTo toState: HKWorkoutSessionState,
                         from fromState: HKWorkoutSessionState,
                         date: Date) {
        NSLog("[WatchWorkoutManager] Session state: \(toState.rawValue)")
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                         didFailWithError error: Error) {
        NSLog("[WatchWorkoutManager] Session error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                         didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)

            Task { @MainActor [weak self] in
                guard let self else { return }
                switch quantityType {
                case HKQuantityType(.heartRate):
                    let hr = stats?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    if hr > 0 {
                        self.session.heartRate = hr
                        self.session.heartRateSamples.append(hr)
                        let total = self.session.heartRateSamples.reduce(0, +)
                        self.session.avgHeartRate = total / Double(self.session.heartRateSamples.count)
                        let idx = self.currentPhaseIndex
                        if self.phaseHRSamples.indices.contains(idx) {
                            self.phaseHRSamples[idx].append(hr)
                        }
                    }
                case HKQuantityType(.activeEnergyBurned):
                    self.session.calories = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                case HKQuantityType(.distanceWalkingRunning):
                    let km = (stats?.sumQuantity()?.doubleValue(for: .meter()) ?? 0) / 1000.0
                    self.session.distance = km
                    if self.session.elapsedSeconds > 0 && km > 0 {
                        self.session.currentPace = (Double(self.session.elapsedSeconds) / 60.0) / km
                    }
                default: break
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard activationState == .activated else { return }
        // Apply any cached context (date-guarded inside applyWorkoutData)
        let context = session.receivedApplicationContext
        if !context.isEmpty {
            Task { @MainActor in
                WatchWorkoutManager.shared.applyWorkoutData(context)
            }
        }
        // Always ask the phone for today's data on activation — covers the case where the
        // cached context is stale (from a previous day) and the phone hasn't pushed yet
        Task { @MainActor in
            WatchWorkoutManager.shared.requestTodayWorkoutFromPhone()
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        let captured = message
        Task { @MainActor in
            WatchWorkoutManager.shared.applyWorkoutData(captured)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        let captured = applicationContext
        Task { @MainActor in
            WatchWorkoutManager.shared.applyWorkoutData(captured)
        }
    }
}
