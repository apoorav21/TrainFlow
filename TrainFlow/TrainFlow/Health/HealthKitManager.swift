import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var heart = HeartMetrics()
    @Published var body = BodyMetrics()
    @Published var activity = ActivityMetrics()
    @Published var respiratory = RespiratoryMetrics()
    @Published var sleepNights: [NightSleep] = []
    @Published var authorizationDenied = false

    private init() {}

    // MARK: - Read types
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
            .walkingHeartRateAverage, .vo2Max,
            .stepCount, .distanceWalkingRunning, .activeEnergyBurned,
            .basalEnergyBurned, .flightsClimbed, .appleExerciseTime,
            .appleStandTime, .walkingSpeed,
            .bodyMass, .bodyMassIndex, .bodyFatPercentage, .leanBodyMass,
            .respiratoryRate, .oxygenSaturation
        ]
        quantityIDs.forEach { if let t = HKQuantityType.quantityType(forIdentifier: $0) { types.insert(t) } }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        types.insert(HKWorkoutType.workoutType())
        return types
    }

    // MARK: - Authorization
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            loadFallbackData(); return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await fetchAll()
        } catch {
            NSLog("[HealthKit] Auth error: \(error)")
            loadFallbackData()
        }
    }

    func fetchAll() async {
        async let h: () = fetchHeartMetrics()
        async let b: () = fetchBodyMetrics()
        async let a: () = fetchActivityMetrics()
        async let r: () = fetchRespiratoryMetrics()
        async let s: () = fetchSleep()
        _ = await (h, b, a, r, s)
    }

    // MARK: - Heart
    private func fetchHeartMetrics() async {
        heart.restingHR = await fetchLatestQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute())).map { Int($0) } ?? 0
        heart.hrv = await fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) ?? 0
        heart.walkingAvgHR = await fetchLatestQuantity(.walkingHeartRateAverage, unit: .count().unitDivided(by: .minute())).map { Int($0) } ?? 0
        heart.vo2Max = await fetchLatestQuantity(.vo2Max, unit: HKUnit(from: "ml/kg·min")) ?? 0
        heart.hrvHistory = await fetchDailyHistory(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 14)
        heart.restingHRHistory = await fetchDailyHistory(.restingHeartRate, unit: .count().unitDivided(by: .minute()), days: 14)
        if heart.restingHRHistory.count >= 2 {
            heart.restingHRTrend = heart.restingHRHistory.last!.value - heart.restingHRHistory[heart.restingHRHistory.count - 8].value
        }
        if heart.hrvHistory.count >= 2 {
            heart.hrvTrend = heart.hrvHistory.last!.value - heart.hrvHistory[heart.hrvHistory.count - 8].value
        }
        if heart.restingHR == 0 { heart = HealthSampleData.heart }
    }

    // MARK: - Body
    private func fetchBodyMetrics() async {
        body.weight = await fetchLatestQuantity(.bodyMass, unit: .gramUnit(with: .kilo)) ?? 0
        body.bmi = await fetchLatestQuantity(.bodyMassIndex, unit: .count()) ?? 0
        body.bodyFat = (await fetchLatestQuantity(.bodyFatPercentage, unit: .percent()) ?? 0) * 100
        body.leanMass = await fetchLatestQuantity(.leanBodyMass, unit: .gramUnit(with: .kilo)) ?? 0
        body.weightHistory = await fetchDailyHistory(.bodyMass, unit: .gramUnit(with: .kilo), days: 14)
        if body.weight == 0 { body = HealthSampleData.body }
    }

    // MARK: - Activity
    private func fetchActivityMetrics() async {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let pred = HKQuery.predicateForSamples(withStart: today, end: tomorrow)
        activity.steps = await fetchSum(.stepCount, unit: .count(), predicate: pred).map { Int($0) } ?? 0
        activity.distance = (await fetchSum(.distanceWalkingRunning, unit: .meter(), predicate: pred) ?? 0) / 1000
        activity.activeCalories = await fetchSum(.activeEnergyBurned, unit: .kilocalorie(), predicate: pred).map { Int($0) } ?? 0
        activity.basalCalories = await fetchSum(.basalEnergyBurned, unit: .kilocalorie(), predicate: pred).map { Int($0) } ?? 0
        activity.exerciseMinutes = await fetchSum(.appleExerciseTime, unit: .minute(), predicate: pred).map { Int($0) } ?? 0
        activity.flightsClimbed = await fetchSum(.flightsClimbed, unit: .count(), predicate: pred).map { Int($0) } ?? 0
        activity.walkingSpeed = await fetchLatestQuantity(.walkingSpeed, unit: .meter().unitDivided(by: .second())).map { $0 * 3.6 } ?? 0
        activity.weeklySteps = await fetchDailySumHistory(.stepCount, unit: .count(), days: 7)
        if activity.steps == 0 { activity = HealthSampleData.activity }
    }

    // MARK: - Respiratory
    private func fetchRespiratoryMetrics() async {
        respiratory.respiratoryRate = await fetchLatestQuantity(.respiratoryRate, unit: .count().unitDivided(by: .minute())) ?? 0
        respiratory.bloodOxygen = (await fetchLatestQuantity(.oxygenSaturation, unit: .percent()) ?? 0) * 100
        if respiratory.respiratoryRate == 0 { respiratory = HealthSampleData.respiratory }
    }

    // MARK: - Sleep
    private func fetchSleep() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let nights = await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            store.execute(q)
        }
        sleepNights = processSleepSamples(nights)
        if sleepNights.isEmpty { sleepNights = HealthSampleData.makeSleepNights() }
    }

    private func processSleepSamples(_ samples: [HKCategorySample]) -> [NightSleep] {
        let grouped = Dictionary(grouping: samples) { s -> Date in
            let cal = Calendar.current
            let bedDate = s.startDate < cal.startOfDay(for: s.startDate).addingTimeInterval(12*3600)
                ? cal.date(byAdding: .day, value: -1, to: s.startDate)!
                : s.startDate
            return cal.startOfDay(for: bedDate)
        }
        return grouped.keys.sorted().suffix(7).compactMap { day in
            let daySamples = grouped[day] ?? []
            var stageMins: [SleepStage: Double] = [:]
            for s in daySamples {
                let mins = s.endDate.timeIntervalSince(s.startDate) / 60
                switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
                case .asleepDeep: stageMins[.deep, default: 0] += mins
                case .asleepCore: stageMins[.core, default: 0] += mins
                case .asleepREM:  stageMins[.rem, default: 0] += mins
                case .awake:      stageMins[.awake, default: 0] += mins
                default: break
                }
            }
            let segments = stageMins.map { SleepStageSegment(stage: $0.key, minutes: $0.value) }
            let total = segments.reduce(0) { $0 + $1.minutes } / 60.0
            guard total > 2 else { return nil }
            return NightSleep(date: day, totalHours: total, stages: segments, respiratoryRate: 14.0, consistency: 0.85)
        }
    }

    // MARK: - Fallback
    private func loadFallbackData() {
        heart = HealthSampleData.heart
        body = HealthSampleData.body
        activity = HealthSampleData.activity
        respiratory = HealthSampleData.respiratory
        sleepNights = HealthSampleData.makeSleepNights()
    }

    // MARK: - Helpers
    private func fetchLatestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, s, _ in
                let val = (s?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: val)
            }
            store.execute(q)
        }
    }

    private func fetchSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    private func fetchDailySumHistory(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [HRVDataPoint] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let interval = DateComponents(day: 1)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: pred,
                                                options: .cumulativeSum,
                                                anchorDate: Calendar.current.startOfDay(for: start),
                                                intervalComponents: interval)
            q.initialResultsHandler = { _, results, _ in
                var points: [HRVDataPoint] = []
                results?.enumerateStatistics(from: start, to: Date()) { stats, _ in
                    if let val = stats.sumQuantity()?.doubleValue(for: unit) {
                        points.append(HRVDataPoint(date: stats.startDate, value: val))
                    }
                }
                continuation.resume(returning: points)
            }
            store.execute(q)
        }
    }

    private func fetchDailyHistory(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [HRVDataPoint] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let interval = DateComponents(day: 1)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: pred,
                                                options: [.discreteAverage, .separateBySource],
                                                anchorDate: Calendar.current.startOfDay(for: start),
                                                intervalComponents: interval)
            q.initialResultsHandler = { _, results, _ in
                var points: [HRVDataPoint] = []
                results?.enumerateStatistics(from: start, to: Date()) { stats, _ in
                    if let val = stats.averageQuantity()?.doubleValue(for: unit) {
                        points.append(HRVDataPoint(date: stats.startDate, value: val))
                    }
                }
                continuation.resume(returning: points)
            }
            store.execute(q)
        }
    }
}
