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
    case connected
    case unknown
    case failed(String)
}

struct HumanHealthHourlyPoint: Equatable, Identifiable, Sendable {
    let hour: Int
    let value: Double

    var id: Int { hour }
}

struct HumanWorkoutHealthSnapshot: Equatable, Sendable {
    var steps: Int
    var activeEnergyKcal: Int
    var distanceKm: Double
    var exerciseMinutes: Int
    var standHours: Int
    var moveGoalKcal: Int
    var exerciseGoalMinutes: Int
    var standGoalHours: Int
    var hourlySteps: [HumanHealthHourlyPoint]
    var hourlyDistanceKm: [HumanHealthHourlyPoint]

    static let empty = HumanWorkoutHealthSnapshot(
        steps: 0,
        activeEnergyKcal: 0,
        distanceKm: 0,
        exerciseMinutes: 0,
        standHours: 0,
        moveGoalKcal: 0,
        exerciseGoalMinutes: 0,
        standGoalHours: 0,
        hourlySteps: (0 ..< 24).map { HumanHealthHourlyPoint(hour: $0, value: 0) },
        hourlyDistanceKm: (0 ..< 24).map { HumanHealthHourlyPoint(hour: $0, value: 0) }
    )
}

struct HealthKitWorkoutImportCandidate: Equatable, Identifiable, Sendable {
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

@MainActor
protocol HumanHealthKitManaging: ObservableObject {
    var authorizationStatus: HumanHealthAuthorizationStatus { get }
    var snapshot: HumanWorkoutHealthSnapshot { get }
    var recentWorkoutCandidates: [HealthKitWorkoutImportCandidate] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    func refreshAuthorizationStatus() async
    func requestReadAuthorization() async
    func loadTodaySummary() async
    func loadRecentWorkoutCandidates(since: Date, limit: Int) async -> [HealthKitWorkoutImportCandidate]
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
    @Published private(set) var snapshot: HumanWorkoutHealthSnapshot = .empty
    @Published private(set) var recentWorkoutCandidates: [HealthKitWorkoutImportCandidate] = []
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
            snapshot = .empty
            recentWorkoutCandidates = []
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
                .connected
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
            authorizationStatus = .connected
            errorMessage = nil
            await loadTodaySummary()
            _ = await loadRecentWorkoutCandidates()
        } catch {
            authorizationStatus = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func loadTodaySummary() async {
        guard let healthStore else {
            snapshot = .empty
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
        async let activityResult = loadHealthValue("Apple Health activity summary") {
            try await activitySummary(for: now, healthStore: healthStore)
        }

        let results = await (hourlyStepsResult, hourlyDistanceResult, activeEnergyResult, activityResult)
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
        let activity = resolvedHealthValue(
            results.3,
            fallback: ActivitySummaryValues?.none,
            errors: &readErrors
        )

        snapshot = HumanWorkoutHealthSnapshot(
            steps: Int(hourlySteps.reduce(0) { $0 + $1.value }.rounded()),
            activeEnergyKcal: Int((activity?.activeEnergyKcal ?? activeEnergy).rounded()),
            distanceKm: hourlyDistance.reduce(0) { $0 + $1.value },
            exerciseMinutes: Int((activity?.exerciseMinutes ?? 0).rounded()),
            standHours: Int((activity?.standHours ?? 0).rounded()),
            moveGoalKcal: Int((activity?.moveGoalKcal ?? 0).rounded()),
            exerciseGoalMinutes: Int((activity?.exerciseGoalMinutes ?? 0).rounded()),
            standGoalHours: Int((activity?.standGoalHours ?? 0).rounded()),
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
    func loadRecentWorkoutCandidates(
        since: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
        limit: Int = 12
    ) async -> [HealthKitWorkoutImportCandidate] {
        guard let healthStore else {
            recentWorkoutCandidates = []
            authorizationStatus = .notAvailable
            return []
        }

        do {
            let candidates = try await recentWorkouts(since: since, limit: limit, healthStore: healthStore)
            recentWorkoutCandidates = candidates
            errorMessage = nil
            return candidates
        } catch {
            recentWorkoutCandidates = []
            errorMessage = error.localizedDescription
            return []
        }
    }

    private func readObjectTypes() -> Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType()
        ]
        for identifier in [HKQuantityTypeIdentifier.stepCount, .activeEnergyBurned, .distanceWalkingRunning] {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
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

    private struct ActivitySummaryValues: Sendable {
        let activeEnergyKcal: Double
        let exerciseMinutes: Double
        let standHours: Double
        let moveGoalKcal: Double
        let exerciseGoalMinutes: Double
        let standGoalHours: Double
    }

    private func activitySummary(for date: Date, healthStore: HKHealthStore) async throws -> ActivitySummaryValues? {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
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
                finish(.success(ActivitySummaryValues(
                    activeEnergyKcal: summary.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                    exerciseMinutes: summary.appleExerciseTime.doubleValue(for: .minute()),
                    standHours: summary.appleStandHours.doubleValue(for: .count()),
                    moveGoalKcal: summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()),
                    exerciseGoalMinutes: summary.appleExerciseTimeGoal.doubleValue(for: .minute()),
                    standGoalHours: summary.appleStandHoursGoal.doubleValue(for: .count())
                )))
            }
        }
    }

    private func recentWorkouts(
        since: Date,
        limit: Int,
        healthStore: HKHealthStore
    ) async throws -> [HealthKitWorkoutImportCandidate] {
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
                let candidates = (samples as? [HKWorkout] ?? []).map(Self.candidate(from:))
                finish(.success(candidates))
            }
        }
    }

    private nonisolated static func candidate(from workout: HKWorkout) -> HealthKitWorkoutImportCandidate {
        HealthKitWorkoutImportCandidate(
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
