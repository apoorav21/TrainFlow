import Foundation
import HealthKit

/// Syncs HealthKit data to the TrainFlow backend on app foreground.
/// Sends the last 30 days of data (backend deduplicates by date).
final class HealthSyncService {
    static let shared = HealthSyncService()
    private init() {}

    private var isSyncing = false

    // MARK: - Models

    struct HKWorkoutSyncRecord: Encodable {
        let hkWorkoutId: String
        let workoutType: String
        let startDate: String
        let endDate: String
        let durationMin: Double
        let distanceKm: Double?
        let calories: Double?
        let sourceName: String
        let avgHeartRate: Int?
        let peakHeartRate: Int?
    }

    struct HealthRecord: Encodable {
        let date: String
        var restingHR: Double?
        var hrv: Double?
        var vo2max: Double?
        var weight: Double?
        var steps: Double?
        var activeCalories: Double?
        var basalCalories: Double?
        var exerciseMinutes: Double?
        var flightsClimbed: Double?
        var distance: Double?
        var walkingHR: Double?
        var sleepData: SleepRecord?
    }

    struct SleepRecord: Encodable {
        var totalMinutes: Double?
        var deepMinutes: Double?
        var remMinutes: Double?
        var coreMinutes: Double?
        var awakeMinutes: Double?
        var respiratoryRate: Double?
        var bloodOxygen: Double?
    }

    // MARK: - Public API

    /// Call on app foreground. No-op if already syncing or HealthKit is unavailable.
    func syncIfNeeded() {
        guard !isSyncing else { return }
        Task { await sync() }
    }

    /// Force a fresh sync even if one just ran (e.g. user-triggered pull-to-refresh).
    /// Waits for any in-progress sync to finish first.
    func syncNow() async {
        // Wait for any running sync to complete before starting a new one
        while isSyncing {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        await sync()
    }

    // MARK: - Sync

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }

        async let healthTask: () = syncHealth()
        async let workoutsTask: () = syncWorkouts()
        _ = await (healthTask, workoutsTask)
    }

    private func syncHealth() async {
        do {
            let records = await buildHealthRecords()
            guard !records.isEmpty else { return }
            struct SyncBody: Encodable { let records: [HealthRecord] }
            struct SyncResponse: Decodable { let synced: Bool?; let recordsWritten: Int? }
            let _: SyncResponse = try await APIClient.shared.post("/health/sync", body: SyncBody(records: records))
            NSLog("[HealthSyncService] Synced \(records.count) health records")
        } catch {
            NSLog("[HealthSyncService] Health sync failed: \(error.localizedDescription)")
        }
    }

    private func syncWorkouts() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()

        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) { readTypes.insert(hrType) }
        guard (try? await store.requestAuthorization(toShare: [], read: readTypes)) != nil else { return }

        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Fetch workouts
        let hkWorkouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                  limit: 200, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            store.execute(q)
        }
        guard !hkWorkouts.isEmpty else { return }

        // Batch-fetch all HR samples for the period — one query for all workouts
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let allHRSamples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                continuation.resume(returning: [])
                return
            }
            let q = HKSampleQuery(sampleType: hrType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            store.execute(q)
        }

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let records: [HKWorkoutSyncRecord] = hkWorkouts.map { w in
            let distKm = w.totalDistance?.doubleValue(for: .meterUnit(with: .kilo))
            let cals: Double?
            if #available(iOS 18, *) {
                cals = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
            } else {
                cals = w.totalEnergyBurned?.doubleValue(for: .kilocalorie())
            }
            // Filter HR samples to this workout's window
            let workoutHR = allHRSamples
                .filter { $0.startDate >= w.startDate && $0.startDate <= w.endDate }
                .map { $0.quantity.doubleValue(for: hrUnit) }
            let avgHR = workoutHR.isEmpty ? nil : Int(workoutHR.reduce(0, +) / Double(workoutHR.count))
            let peakHR = workoutHR.max().map { Int($0) }

            return HKWorkoutSyncRecord(
                hkWorkoutId: w.uuid.uuidString,
                workoutType: w.workoutActivityType.syncName,
                startDate: isoFull.string(from: w.startDate),
                endDate: isoFull.string(from: w.endDate),
                durationMin: w.duration / 60.0,
                distanceKm: distKm,
                calories: cals,
                sourceName: w.sourceRevision.source.name,
                avgHeartRate: avgHR,
                peakHeartRate: peakHR
            )
        }

        do {
            struct SyncBody: Encodable { let workouts: [HKWorkoutSyncRecord] }
            struct SyncResponse: Decodable { let synced: Bool?; let recordsWritten: Int? }
            let _: SyncResponse = try await APIClient.shared.post("/workouts/healthkit-sync", body: SyncBody(workouts: records))
            NSLog("[HealthSyncService] Synced \(records.count) HealthKit workouts")
        } catch {
            NSLog("[HealthSyncService] Workout sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Build Health Records

    private func buildHealthRecords() async -> [HealthRecord] {
        guard HKHealthStore.isHealthDataAvailable() else {
            NSLog("[HealthSyncService] HealthKit not available on this device")
            return []
        }

        let store = HKHealthStore()
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        // Initialise one empty record per day
        var recordsByDate: [String: HealthRecord] = [:]
        var current = startDate
        while current <= endDate {
            let dateStr = formatter.string(from: current)
            recordsByDate[dateStr] = HealthRecord(date: dateStr)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        // Helper: query daily statistics for a given quantity type
        @Sendable func queryDailyStats(
            type: HKQuantityTypeIdentifier,
            unit: HKUnit,
            aggregation: HKStatisticsOptions
        ) async -> [String: Double] {
            await withCheckedContinuation { continuation in
                guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
                    continuation.resume(returning: [:])
                    return
                }
                let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
                let query = HKStatisticsCollectionQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: aggregation,
                    anchorDate: calendar.startOfDay(for: startDate),
                    intervalComponents: DateComponents(day: 1)
                )
                query.initialResultsHandler = { _, results, error in
                    if let error {
                        NSLog("[HealthSyncService] Query error for \(type.rawValue): \(error)")
                        continuation.resume(returning: [:])
                        return
                    }
                    // Create formatter locally to avoid capturing non-Sendable reference
                    let localFormatter = ISO8601DateFormatter()
                    localFormatter.formatOptions = [.withFullDate]
                    var dict: [String: Double] = [:]
                    results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                        let dateStr = localFormatter.string(from: stats.startDate)
                        if aggregation.contains(.discreteAverage) {
                            if let val = stats.averageQuantity()?.doubleValue(for: unit) {
                                dict[dateStr] = val
                            }
                        } else {
                            if let val = stats.sumQuantity()?.doubleValue(for: unit) {
                                dict[dateStr] = val
                            }
                        }
                    }
                    continuation.resume(returning: dict)
                }
                store.execute(query)
            }
        }

        // Query all metrics in parallel
        async let restingHRData = queryDailyStats(
            type: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            aggregation: .discreteAverage
        )
        async let hrvData = queryDailyStats(
            type: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            aggregation: .discreteAverage
        )
        async let vo2Data = queryDailyStats(
            type: .vo2Max,
            unit: HKUnit(from: "ml/kg*min"),
            aggregation: .discreteAverage
        )
        async let weightData = queryDailyStats(
            type: .bodyMass,
            unit: .gramUnit(with: .kilo),
            aggregation: .discreteAverage
        )
        async let stepsData = queryDailyStats(
            type: .stepCount,
            unit: .count(),
            aggregation: .cumulativeSum
        )
        async let activeCalData = queryDailyStats(
            type: .activeEnergyBurned,
            unit: .kilocalorie(),
            aggregation: .cumulativeSum
        )
        async let basalCalData = queryDailyStats(
            type: .basalEnergyBurned,
            unit: .kilocalorie(),
            aggregation: .cumulativeSum
        )
        async let exerciseData = queryDailyStats(
            type: .appleExerciseTime,
            unit: .minute(),
            aggregation: .cumulativeSum
        )
        async let flightsData = queryDailyStats(
            type: .flightsClimbed,
            unit: .count(),
            aggregation: .cumulativeSum
        )
        async let distanceData = queryDailyStats(
            type: .distanceWalkingRunning,
            unit: .meterUnit(with: .kilo),
            aggregation: .cumulativeSum
        )
        async let walkingHRData = queryDailyStats(
            type: .walkingHeartRateAverage,
            unit: HKUnit.count().unitDivided(by: .minute()),
            aggregation: .discreteAverage
        )

        // Sleep data (category samples, fetched separately)
        let sleepByDate: [String: SleepRecord] = await withCheckedContinuation { continuation in
            guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
                continuation.resume(returning: [:])
                return
            }
            let pred = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let q = HKSampleQuery(sampleType: sleepType, predicate: pred,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                let localFormatter = ISO8601DateFormatter()
                localFormatter.formatOptions = [.withFullDate]
                let localCal = Calendar.current
                var byDate: [String: SleepRecord] = [:]
                for sample in (samples as? [HKCategorySample] ?? []) {
                    // Attribute sleep starting before noon to the previous night
                    let noon = localCal.startOfDay(for: sample.startDate).addingTimeInterval(12 * 3600)
                    let nightDate = sample.startDate < noon
                        ? localCal.date(byAdding: .day, value: -1, to: sample.startDate)!
                        : sample.startDate
                    let dateStr = localFormatter.string(from: localCal.startOfDay(for: nightDate))
                    let mins = sample.endDate.timeIntervalSince(sample.startDate) / 60
                    var rec = byDate[dateStr] ?? SleepRecord()
                    switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                    case .asleepDeep:  rec.deepMinutes = (rec.deepMinutes ?? 0) + mins
                    case .asleepCore:  rec.coreMinutes = (rec.coreMinutes ?? 0) + mins
                    case .asleepREM:   rec.remMinutes  = (rec.remMinutes  ?? 0) + mins
                    case .awake:       rec.awakeMinutes = (rec.awakeMinutes ?? 0) + mins
                    default: break
                    }
                    let asleep = (rec.deepMinutes ?? 0) + (rec.coreMinutes ?? 0) + (rec.remMinutes ?? 0)
                    rec.totalMinutes = asleep + (rec.awakeMinutes ?? 0)
                    byDate[dateStr] = rec
                }
                continuation.resume(returning: byDate)
            }
            store.execute(q)
        }

        let (rhr, hrv, vo2, weight, steps, activeCal, basalCal, exercise, flights, distance, walkingHR) =
            await (restingHRData, hrvData, vo2Data, weightData, stepsData,
                   activeCalData, basalCalData, exerciseData, flightsData, distanceData, walkingHRData)

        // Merge all metrics into per-day records
        for dateStr in recordsByDate.keys {
            var record = recordsByDate[dateStr]!
            record.restingHR = rhr[dateStr]
            record.hrv = hrv[dateStr]
            record.vo2max = vo2[dateStr]
            record.weight = weight[dateStr]
            record.steps = steps[dateStr]
            record.activeCalories = activeCal[dateStr]
            record.basalCalories = basalCal[dateStr]
            record.exerciseMinutes = exercise[dateStr]
            record.flightsClimbed = flights[dateStr]
            record.distance = distance[dateStr]
            record.walkingHR = walkingHR[dateStr]
            record.sleepData = sleepByDate[dateStr]
            recordsByDate[dateStr] = record
        }

        // Return only days that have at least one signal (avoid noise from empty days)
        return Array(recordsByDate.values)
            .filter { $0.restingHR != nil || $0.steps != nil || $0.hrv != nil }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - HKWorkoutActivityType display name

private extension HKWorkoutActivityType {
    var syncName: String {
        switch self {
        case .running:                          return "Running"
        case .cycling:                          return "Cycling"
        case .walking:                          return "Walking"
        case .swimming:                         return "Swimming"
        case .hiking:                           return "Hiking"
        case .highIntensityIntervalTraining:    return "HIIT"
        case .yoga:                             return "Yoga"
        case .traditionalStrengthTraining:      return "Strength Training"
        case .functionalStrengthTraining:       return "Functional Strength"
        case .rowing:                           return "Rowing"
        case .elliptical:                       return "Elliptical"
        case .stairClimbing:                    return "Stair Climbing"
        case .crossTraining:                    return "Cross Training"
        case .pilates:                          return "Pilates"
        case .dance:                            return "Dance"
        case .soccer:                           return "Soccer"
        case .tennis:                           return "Tennis"
        case .basketball:                       return "Basketball"
        default:                                return "Workout"
        }
    }
}
