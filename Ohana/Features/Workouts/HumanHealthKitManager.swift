//
//  HumanHealthKitManager.swift
//  Ohana
//
//  Read-only HealthKit bridge for human workout summary surfaces.
//

import Combine
import Foundation
import HealthKit

enum HumanHealthAuthorizationStatus: Equatable, Sendable {
    case notAvailable
    case notDetermined
    case accessRequested
    case unknown
    case failed(String)
}

enum HumanHealthActivitySummaryStatus: Equatable, Sendable {
    case notLoaded
    case available
    case noData
    case failed(String)
}

enum HumanHealthRecentWorkoutsStatus: Equatable, Sendable {
    case notLoaded
    case available
    case noData
    case failed(String)
}

nonisolated enum HumanHealthMoveMode: Equatable, Sendable {
    case activeEnergy
    case moveTime
}

nonisolated enum HumanHealthActivityGoalAvailability: Equatable, Sendable {
    case unavailable
    case partial
    case complete
}

struct HumanHealthHourlyPoint: Equatable, Identifiable, Sendable {
    let hour: Int
    let value: Double

    var id: Int { hour }
}

struct HumanWorkoutHealthSnapshot: Equatable, Sendable {
    var steps: Int
    var activeEnergyKcal: Int
    var moveMode: HumanHealthMoveMode
    var moveMinutes: Int
    var distanceKm: Double
    var exerciseMinutes: Int
    var standHours: Int
    var moveGoalKcal: Int
    var moveGoalMinutes: Int
    var exerciseGoalMinutes: Int
    var standGoalHours: Int
    var hourlySteps: [HumanHealthHourlyPoint]
    var hourlyDistanceKm: [HumanHealthHourlyPoint]

    static let empty = HumanWorkoutHealthSnapshot(
        steps: 0,
        activeEnergyKcal: 0,
        moveMode: .activeEnergy,
        moveMinutes: 0,
        distanceKm: 0,
        exerciseMinutes: 0,
        standHours: 0,
        moveGoalKcal: 0,
        moveGoalMinutes: 0,
        exerciseGoalMinutes: 0,
        standGoalHours: 0,
        hourlySteps: (0 ..< 24).map { HumanHealthHourlyPoint(hour: $0, value: 0) },
        hourlyDistanceKm: (0 ..< 24).map { HumanHealthHourlyPoint(hour: $0, value: 0) }
    )

    var moveValue: Int {
        moveMode == .moveTime ? moveMinutes : activeEnergyKcal
    }

    var moveGoal: Int {
        moveMode == .moveTime ? moveGoalMinutes : moveGoalKcal
    }

    var activityGoalAvailability: HumanHealthActivityGoalAvailability {
        let availableGoalCount = [moveGoal, exerciseGoalMinutes, standGoalHours].count { $0 > 0 }
        return switch availableGoalCount {
        case 0: .unavailable
        case 3: .complete
        default: .partial
        }
    }
}

nonisolated struct HumanHealthActivityValues: Equatable, Sendable {
    let activeEnergyKcal: Double
    let moveMode: HumanHealthMoveMode
    let moveMinutes: Double
    let exerciseMinutes: Double
    let standHours: Double
    let moveGoalKcal: Double
    let moveGoalMinutes: Double
    let exerciseGoalMinutes: Double
    let standGoalHours: Double
}

nonisolated struct HumanHealthResolvedActivity: Equatable, Sendable {
    let activeEnergyKcal: Int
    let moveMode: HumanHealthMoveMode
    let moveMinutes: Int
    let exerciseMinutes: Int
    let standHours: Int
    let moveGoalKcal: Int
    let moveGoalMinutes: Int
    let exerciseGoalMinutes: Int
    let standGoalHours: Int
}

nonisolated enum HumanHealthActivityResolver {
    static func resolve(
        summary: HumanHealthActivityValues?,
        fallbackActiveEnergyKcal: Double,
        fallbackExerciseMinutes: Double,
        fallbackStandHours: Double
    ) -> HumanHealthResolvedActivity {
        HumanHealthResolvedActivity(
            activeEnergyKcal: measured(summary?.activeEnergyKcal, fallback: fallbackActiveEnergyKcal),
            moveMode: summary?.moveMode ?? .activeEnergy,
            moveMinutes: measured(summary?.moveMinutes, fallback: 0),
            exerciseMinutes: measured(summary?.exerciseMinutes, fallback: fallbackExerciseMinutes),
            standHours: measured(summary?.standHours, fallback: fallbackStandHours),
            moveGoalKcal: goal(summary?.moveGoalKcal),
            moveGoalMinutes: goal(summary?.moveGoalMinutes),
            exerciseGoalMinutes: goal(summary?.exerciseGoalMinutes),
            standGoalHours: goal(summary?.standGoalHours)
        )
    }

    private static func measured(_ value: Double?, fallback: Double) -> Int {
        Int(max(finite(value), finite(fallback)).rounded())
    }

    private static func goal(_ value: Double?) -> Int {
        Int(finite(value).rounded())
    }

    private static func finite(_ value: Double?) -> Double {
        guard let value, value.isFinite else { return 0 }
        return max(0, value)
    }
}

struct HumanHealthKitWorkoutSnapshot: Equatable, Identifiable, Sendable {
    let healthKitWorkoutUUID: String
    let type: WorkoutType
    let startDate: Date
    let durationMinutes: Int
    let distanceKm: Double
    let calories: Int
    let steps: Int
    let sourceBundleID: String
    let sourceName: String

    var id: String { healthKitWorkoutUUID }
}

nonisolated enum HumanWorkoutSourceMergePolicy {
    static func shouldShowLocalLog(
        healthKitWorkoutUUID: String,
        sourcePetWalkLogID: String,
        liveHealthKitIDs: Set<String>,
        livePetWalkIDs: Set<String>
    ) -> Bool {
        !liveHealthKitIDs.contains(healthKitWorkoutUUID)
            && !livePetWalkIDs.contains(sourcePetWalkLogID)
    }
}

@MainActor
protocol HumanHealthKitManaging: ObservableObject {
    var authorizationStatus: HumanHealthAuthorizationStatus { get }
    var activitySummaryStatus: HumanHealthActivitySummaryStatus { get }
    var recentWorkoutsStatus: HumanHealthRecentWorkoutsStatus { get }
    var snapshot: HumanWorkoutHealthSnapshot { get }
    var recentWorkouts: [HumanHealthKitWorkoutSnapshot] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func refreshAuthorizationStatus() async
    func requestReadAuthorization() async
    func loadTodaySummary() async
    func loadRecentWorkouts(since: Date, limit: Int) async -> [HumanHealthKitWorkoutSnapshot]
}

private enum HumanHealthKitReadError: LocalizedError {
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case let .timedOut(operationName):
            "\(operationName) timed out. Refresh to try again."
        }
    }
}

private final class HumanHealthKitQueryContinuation<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Value, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        guard let continuation else { return }
        switch result {
        case let .success(value):
            continuation.resume(returning: value)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    func resume(throwing error: Error) {
        resume(with: .failure(error))
    }
}

private final class HumanHealthKitRunningQuery: @unchecked Sendable {
    private let healthStore: HKHealthStore
    private let query: HKQuery

    init(healthStore: HKHealthStore, query: HKQuery) {
        self.healthStore = healthStore
        self.query = query
    }

    func stop() {
        healthStore.stop(query)
    }
}

@MainActor
final class HumanHealthKitManager: ObservableObject, HumanHealthKitManaging {
    @Published private(set) var authorizationStatus: HumanHealthAuthorizationStatus
    @Published private(set) var activitySummaryStatus: HumanHealthActivitySummaryStatus = .notLoaded
    @Published private(set) var recentWorkoutsStatus: HumanHealthRecentWorkoutsStatus = .notLoaded
    @Published private(set) var snapshot: HumanWorkoutHealthSnapshot = .empty
    @Published private(set) var recentWorkouts: [HumanHealthKitWorkoutSnapshot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let healthStore: HKHealthStore?
    private let calendar: Calendar
    private let queryTimeoutSeconds: TimeInterval

    init(
        healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil,
        calendar: Calendar = .current,
        queryTimeoutSeconds: TimeInterval = 6
    ) {
        self.healthStore = healthStore
        self.calendar = calendar
        self.queryTimeoutSeconds = max(1, queryTimeoutSeconds)
        authorizationStatus = healthStore == nil ? .notAvailable : .notDetermined
    }

    func refreshAuthorizationStatus() async {
        guard let healthStore else {
            authorizationStatus = .notAvailable
            activitySummaryStatus = .notLoaded
            recentWorkoutsStatus = .notLoaded
            snapshot = .empty
            recentWorkouts = []
            return
        }

        do {
            let status = try await healthStore.statusForAuthorizationRequest(
                toShare: Set<HKSampleType>(),
                read: readObjectTypes()
            )
            authorizationStatus = switch status {
            case .shouldRequest:
                .notDetermined
            case .unnecessary:
                .accessRequested
            case .unknown:
                .unknown
            @unknown default:
                .unknown
            }
        } catch {
            authorizationStatus = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func requestReadAuthorization() async {
        guard let healthStore else {
            authorizationStatus = .notAvailable
            errorMessage = "HealthKit is not available on this device."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await healthStore.requestAuthorization(
                toShare: Set<HKSampleType>(),
                read: readObjectTypes()
            )
            authorizationStatus = .accessRequested
            errorMessage = nil
            await loadTodaySummary()
            _ = await loadRecentWorkouts()
        } catch {
            authorizationStatus = .failed(error.localizedDescription)
            activitySummaryStatus = .failed(error.localizedDescription)
            recentWorkoutsStatus = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func loadTodaySummary() async {
        guard let healthStore else {
            snapshot = .empty
            activitySummaryStatus = .notLoaded
            authorizationStatus = .notAvailable
            return
        }

        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        async let hourlyStepsResult = loadHealthValue("Apple Health step count") {
            try await hourlyQuantity(
                .stepCount,
                unit: .count(),
                start: startOfDay,
                end: now,
                healthStore: healthStore
            )
        }
        async let hourlyDistanceResult = loadHealthValue("Apple Health walking distance") {
            try await hourlyQuantity(
                .distanceWalkingRunning,
                unit: .meterUnit(with: .kilo),
                start: startOfDay,
                end: now,
                healthStore: healthStore
            )
        }
        async let activeEnergyResult = loadHealthValue("Apple Health active energy") {
            try await totalQuantity(
                .activeEnergyBurned,
                unit: .kilocalorie(),
                start: startOfDay,
                end: now,
                healthStore: healthStore
            )
        }
        async let exerciseResult = loadHealthValue("Apple Health exercise time") {
            try await totalQuantity(
                .appleExerciseTime,
                unit: .minute(),
                start: startOfDay,
                end: now,
                healthStore: healthStore
            )
        }
        async let standHoursResult = loadHealthValue("Apple Health stand hours") {
            try await appleStandHours(
                start: startOfDay,
                end: now,
                healthStore: healthStore
            )
        }
        async let activityResult = loadHealthValue("Apple Health activity summary") {
            try await activitySummary(for: now, healthStore: healthStore)
        }

        let results = await (
            hourlyStepsResult,
            hourlyDistanceResult,
            activeEnergyResult,
            exerciseResult,
            standHoursResult,
            activityResult
        )
        var readErrors: [Error] = []
        let hourlySteps = resolvedHealthValue(
            results.0,
            fallback: HumanWorkoutHealthSnapshot.empty.hourlySteps,
            errors: &readErrors
        )
        let hourlyDistance = resolvedHealthValue(
            results.1,
            fallback: HumanWorkoutHealthSnapshot.empty.hourlyDistanceKm,
            errors: &readErrors
        )
        let activeEnergy = resolvedHealthValue(results.2, fallback: 0, errors: &readErrors)
        let exerciseMinutes = resolvedHealthValue(results.3, fallback: 0, errors: &readErrors)
        let standHours = resolvedHealthValue(results.4, fallback: 0, errors: &readErrors)
        let activitySummaryResult = results.5
        switch activitySummaryResult {
        case let .success(activity):
            activitySummaryStatus = activity == nil ? .noData : .available
        case let .failure(error):
            activitySummaryStatus = .failed(error.localizedDescription)
        }
        let activity = resolvedHealthValue(
            activitySummaryResult,
            fallback: HumanHealthActivityValues?.none,
            errors: &readErrors
        )
        let resolvedActivity = HumanHealthActivityResolver.resolve(
            summary: activity,
            fallbackActiveEnergyKcal: activeEnergy,
            fallbackExerciseMinutes: exerciseMinutes,
            fallbackStandHours: standHours
        )

        snapshot = HumanWorkoutHealthSnapshot(
            steps: Int(hourlySteps.reduce(0) { $0 + $1.value }.rounded()),
            activeEnergyKcal: resolvedActivity.activeEnergyKcal,
            moveMode: resolvedActivity.moveMode,
            moveMinutes: resolvedActivity.moveMinutes,
            distanceKm: hourlyDistance.reduce(0) { $0 + $1.value },
            exerciseMinutes: resolvedActivity.exerciseMinutes,
            standHours: resolvedActivity.standHours,
            moveGoalKcal: resolvedActivity.moveGoalKcal,
            moveGoalMinutes: resolvedActivity.moveGoalMinutes,
            exerciseGoalMinutes: resolvedActivity.exerciseGoalMinutes,
            standGoalHours: resolvedActivity.standGoalHours,
            hourlySteps: hourlySteps,
            hourlyDistanceKm: hourlyDistance
        )

        if let firstError = readErrors.first {
            errorMessage = firstError.localizedDescription
        } else {
            errorMessage = nil
        }
    }

    @discardableResult
    func loadRecentWorkouts(
        since: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        limit: Int = 12
    ) async -> [HumanHealthKitWorkoutSnapshot] {
        guard let healthStore else {
            recentWorkouts = []
            recentWorkoutsStatus = .notLoaded
            authorizationStatus = .notAvailable
            return []
        }

        do {
            let workouts = try await queryRecentWorkouts(since: since, limit: limit, healthStore: healthStore)
            recentWorkouts = workouts
            recentWorkoutsStatus = workouts.isEmpty ? .noData : .available
            errorMessage = nil
            return workouts
        } catch {
            recentWorkouts = []
            recentWorkoutsStatus = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            return []
        }
    }

    private func readObjectTypes() -> Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType()
        ]
        for identifier in [HKQuantityTypeIdentifier.stepCount, .activeEnergyBurned, .distanceWalkingRunning, .appleExerciseTime] {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let standHourType = HKObjectType.categoryType(forIdentifier: .appleStandHour) {
            types.insert(standHourType)
        }
        return types
    }

    private func loadHealthValue<Value>(
        _ operationName: String,
        operation: () async throws -> Value
    ) async -> Result<Value, Error> {
        do {
            let value = try await operation()
            return .success(value)
        } catch {
            OhanaLog.warning("\(operationName) failed: \(error.localizedDescription)", category: "Workouts")
            return .failure(error)
        }
    }

    private func resolvedHealthValue<Value>(
        _ result: Result<Value, Error>,
        fallback: Value,
        errors: inout [Error]
    ) -> Value {
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            errors.append(error)
            return fallback
        }
    }

    private func executeHealthKitQuery<Value>(
        operationName: String,
        healthStore: HKHealthStore,
        makeQuery: (_ finish: @escaping (Result<Value, Error>) -> Void) -> HKQuery
    ) async throws -> Value {
        let timeoutMilliseconds = Int(queryTimeoutSeconds * 1000)
        return try await withCheckedThrowingContinuation { continuation in
            let continuationBox = HumanHealthKitQueryContinuation(continuation)
            let query = makeQuery { result in
                continuationBox.resume(with: result)
            }
            let runningQuery = HumanHealthKitRunningQuery(healthStore: healthStore, query: query)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMilliseconds)) {
                runningQuery.stop()
                continuationBox.resume(throwing: HumanHealthKitReadError.timedOut(operationName))
            }
            healthStore.execute(query)
        }
    }

    private func totalQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        healthStore: HKHealthStore
    ) async throws -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])

        return try await executeHealthKitQuery(operationName: "Apple Health \(identifier.rawValue)", healthStore: healthStore) { finish in
            HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum]
            ) { _, statistics, error in
                if let error {
                    finish(.failure(error))
                    return
                }
                finish(.success(statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0))
            }
        }
    }

    private func hourlyQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        healthStore: HKHealthStore
    ) async throws -> [HumanHealthHourlyPoint] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return HumanWorkoutHealthSnapshot.empty.hourlySteps
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let calendar = calendar
        var interval = DateComponents()
        interval.hour = 1

        return try await executeHealthKitQuery(operationName: "Apple Health hourly \(identifier.rawValue)", healthStore: healthStore) { finish in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: start,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    finish(.failure(error))
                    return
                }

                var values = Array(repeating: 0.0, count: 24)
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let hour = calendar.component(.hour, from: statistics.startDate)
                    guard values.indices.contains(hour) else { return }
                    values[hour] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                }
                finish(.success(values.enumerated().map {
                    HumanHealthHourlyPoint(hour: $0.offset, value: $0.element)
                }))
            }
            return query
        }
    }

    private func appleStandHours(
        start: Date,
        end: Date,
        healthStore: HKHealthStore
    ) async throws -> Double {
        guard let categoryType = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        let calendar = calendar

        return try await executeHealthKitQuery(operationName: "Apple Health stand hours", healthStore: healthStore) { finish in
            HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    finish(.failure(error))
                    return
                }
                let stoodValue = HKCategoryValueAppleStandHour.stood.rawValue
                let stoodHours = Set((samples as? [HKCategorySample] ?? []).compactMap { sample -> Date? in
                    guard sample.value == stoodValue else { return nil }
                    return calendar.dateInterval(of: .hour, for: sample.startDate)?.start
                })
                finish(.success(Double(stoodHours.count)))
            }
        }
    }

    private func activitySummary(for date: Date, healthStore: HKHealthStore) async throws -> HumanHealthActivityValues? {
        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let predicate = HKQuery.predicateForActivitySummary(with: components)

        return try await executeHealthKitQuery(operationName: "Apple Health activity summary", healthStore: healthStore) { finish in
            HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    finish(.failure(error))
                    return
                }
                guard let summary = summaries?.first else {
                    finish(.success(nil))
                    return
                }
                finish(.success(HumanHealthActivityValues(
                    activeEnergyKcal: summary.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                    moveMode: summary.activityMoveMode == .appleMoveTime ? .moveTime : .activeEnergy,
                    moveMinutes: summary.appleMoveTime.doubleValue(for: .minute()),
                    exerciseMinutes: summary.appleExerciseTime.doubleValue(for: .minute()),
                    standHours: summary.appleStandHours.doubleValue(for: .count()),
                    moveGoalKcal: summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()),
                    moveGoalMinutes: summary.appleMoveTimeGoal.doubleValue(for: .minute()),
                    exerciseGoalMinutes: summary.appleExerciseTimeGoal.doubleValue(for: .minute()),
                    standGoalHours: summary.appleStandHoursGoal.doubleValue(for: .count())
                )))
            }
        }
    }

    private func queryRecentWorkouts(
        since: Date,
        limit: Int,
        healthStore: HKHealthStore
    ) async throws -> [HumanHealthKitWorkoutSnapshot] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: [.strictStartDate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await executeHealthKitQuery(operationName: "Apple Health recent workouts", healthStore: healthStore) { finish in
            HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: max(1, limit),
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    finish(.failure(error))
                    return
                }
                let workouts = (samples as? [HKWorkout] ?? []).map(Self.snapshot(from:))
                finish(.success(workouts))
            }
        }
    }

    private nonisolated static func snapshot(from workout: HKWorkout) -> HumanHealthKitWorkoutSnapshot {
        HumanHealthKitWorkoutSnapshot(
            healthKitWorkoutUUID: workout.uuid.uuidString,
            type: workoutType(for: workout.workoutActivityType),
            startDate: workout.startDate,
            durationMinutes: max(1, Int((workout.duration / 60).rounded())),
            distanceKm: max(0, workoutDistanceKm(for: workout)),
            calories: max(0, Int(workoutActiveEnergyKcal(for: workout).rounded())),
            steps: 0,
            sourceBundleID: workout.sourceRevision.source.bundleIdentifier,
            sourceName: workout.sourceRevision.source.name
        )
    }

    private nonisolated static func workoutActiveEnergyKcal(for workout: HKWorkout) -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return workout.statistics(for: quantityType)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    private nonisolated static func workoutDistanceKm(for workout: HKWorkout) -> Double {
        let identifier: HKQuantityTypeIdentifier = switch workout.workoutActivityType {
        case .cycling:
            .distanceCycling
        case .swimming:
            .distanceSwimming
        default:
            .distanceWalkingRunning
        }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        return workout.statistics(for: quantityType)?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0
    }

    private nonisolated static func workoutType(for activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .running:
            .running
        case .walking:
            .walking
        case .cycling:
            .cycling
        case .swimming:
            .swimming
        case .yoga:
            .yoga
        case .hiking:
            .hiking
        case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining:
            .gym
        default:
            .other
        }
    }
}
