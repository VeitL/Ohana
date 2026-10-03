//
//  HumanHealthConditionsRouteData.swift
//  Ohana
//
//  Bounded route-loading support for Human health condition screens.
//

import Foundation
import SwiftData

struct HumanHealthConditionsRouteData {
    nonisolated static let conditionPageSize = 12
    nonisolated static let medicationLogAnalysisLimitPerPlan = 128
    private nonisolated static let analysisObservationLimit = 1024

    var conditions: [HumanHealthCondition] = []
    var conditionSnapshots: [UUID: HumanHealthConditionTrendSnapshot] = [:]
    var analysisLimitedConditionIDs: Set<UUID> = []
    var medicationAnalysisIncompleteConditionIDs: Set<UUID> = []
    var includesMedicationDetails = false
    var medications: [HumanMedication] = []
    var medicationLogs: [HumanMedicationLog] = []
    var metricLogs: [HumanHealthMetricLog] = []
    var activeConditionCount = 0
    var sevenDayObservationCount = 0
    var recentObservationCount = 0
    var nextConditionCursor: HumanHealthHistoryPageCursor?
    var hasOlderConditions = false
    var hasLoaded = false

    var medicationAnalysisIsIncomplete: Bool {
        !medicationAnalysisIncompleteConditionIDs.isEmpty
    }

    @MainActor
    static func load(
        humanID: UUID,
        canViewMedication: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        context: ModelContext
    ) throws -> HumanHealthConditionsRouteData {
        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        let historyStart = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let sevenDayStart = calendar.date(
            byAdding: .day,
            value: -6,
            to: calendar.startOfDay(for: now)
        ) ?? now
        let resolvedStatus = HumanHealthTrackingStatus.resolved.rawValue
        let conditionPage = try HumanHealthConditionHistoryQuery.page(
            humanID: humanID,
            limit: conditionPageSize,
            context: context
        )
        let pageData = try loadConditionPageData(
            page: conditionPage,
            humanID: humanID,
            canViewMedication: canViewMedication,
            now: now,
            calendar: calendar,
            context: context
        )
        let activeConditionDescriptor = FetchDescriptor<HumanHealthCondition>(
            predicate: #Predicate<HumanHealthCondition> { condition in
                (condition.humanId.contains(humanKey) || condition.humanId.contains(humanKeyLower))
                    && condition.trackingStatusRaw != resolvedStatus
            }
        )

        return HumanHealthConditionsRouteData(
            conditions: pageData.conditions,
            conditionSnapshots: pageData.conditionSnapshots,
            analysisLimitedConditionIDs: pageData.analysisLimitedConditionIDs,
            medicationAnalysisIncompleteConditionIDs: pageData.medicationAnalysisIncompleteConditionIDs,
            includesMedicationDetails: canViewMedication,
            medications: pageData.medications,
            medicationLogs: pageData.medicationLogs,
            metricLogs: pageData.metricLogs,
            activeConditionCount: try context.fetchCount(activeConditionDescriptor),
            sevenDayObservationCount: try context.fetchCount(FetchDescriptor<HumanHealthObservation>(
                predicate: #Predicate<HumanHealthObservation> { observation in
                    (observation.humanId.contains(humanKey) || observation.humanId.contains(humanKeyLower))
                        && observation.recordedAt >= sevenDayStart
                        && observation.recordedAt <= now
                }
            )),
            recentObservationCount: try context.fetchCount(FetchDescriptor<HumanHealthObservation>(
                predicate: #Predicate<HumanHealthObservation> { observation in
                    (observation.humanId.contains(humanKey) || observation.humanId.contains(humanKeyLower))
                        && observation.recordedAt >= historyStart
                        && observation.recordedAt <= now
                }
            )),
            nextConditionCursor: conditionPage.nextCursor,
            hasOlderConditions: conditionPage.hasOlder,
            hasLoaded: true
        )
    }

    @MainActor
    private static func loadConditionPageData(
        page: HumanHealthConditionPage,
        humanID: UUID,
        canViewMedication: Bool,
        now: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws -> HumanHealthConditionPageRouteData {
        let observationLoad = try loadObservationSnapshots(
            for: page.records,
            humanID: humanID,
            includeMedicationDetails: canViewMedication,
            now: now,
            calendar: calendar,
            context: context
        )
        let linkedMedicationIDs = Set(page.records.flatMap(\.linkedMedicationIDs))
        let linkedMetricKeys = Set(page.records.flatMap(\.linkedMetricKeys))
        let sevenDayStart = calendar.date(
            byAdding: .day,
            value: -6,
            to: calendar.startOfDay(for: now)
        ) ?? now

        let medications: [HumanMedication]
        let medicationLogLoad: HumanHealthLinkedMedicationLogLoad
        if canViewMedication, !linkedMedicationIDs.isEmpty {
            medications = try loadLinkedMedications(
                humanID: humanID,
                medicationIDs: linkedMedicationIDs,
                context: context
            )
            medicationLogLoad = try loadLinkedMedicationLogs(
                humanID: humanID,
                medicationIDs: linkedMedicationIDs,
                from: sevenDayStart,
                through: now,
                context: context
            )
        } else {
            medications = []
            medicationLogLoad = HumanHealthLinkedMedicationLogLoad(logs: [], limitedMedicationIDs: [])
        }

        return HumanHealthConditionPageRouteData(
            conditions: page.records,
            conditionSnapshots: observationLoad.snapshots,
            analysisLimitedConditionIDs: observationLoad.limitedConditionIDs,
            medicationAnalysisIncompleteConditionIDs: Set(page.records.compactMap { condition in
                Set(condition.linkedMedicationIDs).isDisjoint(with: medicationLogLoad.limitedMedicationIDs)
                    ? nil
                    : condition.id
            }),
            medications: medications,
            medicationLogs: medicationLogLoad.logs,
            metricLogs: try loadLatestLinkedMetricLogs(
                humanID: humanID,
                metricKeys: linkedMetricKeys,
                context: context
            ),
            nextConditionCursor: page.nextCursor,
            hasOlderConditions: page.hasOlder
        )
    }

    @MainActor
    private static func loadLinkedMedications(
        humanID: UUID,
        medicationIDs: Set<UUID>,
        context: ModelContext
    ) throws -> [HumanMedication] {
        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        var result: [HumanMedication] = []
        result.reserveCapacity(medicationIDs.count)

        for medicationID in medicationIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            var descriptor = FetchDescriptor<HumanMedication>(
                predicate: #Predicate<HumanMedication> { medication in
                    medication.id == medicationID &&
                        (medication.humanId.contains(humanKey) || medication.humanId.contains(humanKeyLower))
                }
            )
            descriptor.fetchLimit = 4
            if let medication = try fetch(
                descriptor,
                context: context,
                name: "linked HumanMedication"
            ).first(where: { normalizedUUID($0.humanId) == humanID }) {
                result.append(medication)
            }
        }
        return result.sorted {
            if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.createdAt < $1.createdAt
        }
    }

    @MainActor
    private static func loadLinkedMedicationLogs(
        humanID: UUID,
        medicationIDs: Set<UUID>,
        from start: Date,
        through end: Date,
        context: ModelContext
    ) throws -> HumanHealthLinkedMedicationLogLoad {
        let humanKeys = identifierCandidates(for: humanID)
        var logsByID: [UUID: HumanMedicationLog] = [:]
        var limitedMedicationIDs = Set<UUID>()

        for medicationID in medicationIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            let candidates = try fetchLinkedMedicationLogCandidates(
                humanKeys: humanKeys,
                medicationID: medicationID,
                from: start,
                through: end,
                limit: medicationLogAnalysisLimitPerPlan + 1,
                context: context
            )
            let canonical = candidates.filter { log in
                normalizedUUID(log.humanId) == humanID &&
                    normalizedUUID(log.medicationId) == medicationID
            }
            if candidates.count > medicationLogAnalysisLimitPerPlan ||
                canonical.count > medicationLogAnalysisLimitPerPlan {
                limitedMedicationIDs.insert(medicationID)
            }
            for log in canonical.prefix(medicationLogAnalysisLimitPerPlan) {
                logsByID[log.id] = log
            }
        }

        return HumanHealthLinkedMedicationLogLoad(
            logs: logsByID.values.sorted(by: isNewerMedicationLog),
            limitedMedicationIDs: limitedMedicationIDs
        )
    }

    @MainActor
    private static func fetchLinkedMedicationLogCandidates(
        humanKeys: [String],
        medicationID: UUID,
        from start: Date,
        through end: Date,
        limit: Int,
        context: ModelContext
    ) throws -> [HumanMedicationLog] {
        let medicationKey = medicationID.uuidString
        let medicationKeyLower = medicationKey.lowercased()
        var candidatesByID: [UUID: HumanMedicationLog] = [:]
        for humanKey in humanKeys {
            var descriptor = FetchDescriptor<HumanMedicationLog>(
                predicate: #Predicate<HumanMedicationLog> { log in
                    log.humanId.contains(humanKey)
                        && (log.medicationId.contains(medicationKey) || log.medicationId.contains(medicationKeyLower))
                        && log.scheduledTime >= start
                        && log.scheduledTime <= end
                },
                sortBy: [
                    SortDescriptor(\.scheduledTime, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse)
                ]
            )
            descriptor.fetchLimit = limit
            for candidate in try fetch(
                descriptor,
                context: context,
                name: "linked HumanMedicationLog"
            ) {
                candidatesByID[candidate.id] = candidate
            }
        }
        return Array(candidatesByID.values.sorted(by: Self.isNewerMedicationLog).prefix(limit))
    }

    @MainActor
    private static func isNewerMedicationLog(
        _ lhs: HumanMedicationLog,
        _ rhs: HumanMedicationLog
    ) -> Bool {
        if lhs.scheduledTime != rhs.scheduledTime { return lhs.scheduledTime > rhs.scheduledTime }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id > rhs.id
    }

    @MainActor
    private static func loadLatestLinkedMetricLogs(
        humanID: UUID,
        metricKeys: Set<String>,
        context: ModelContext
    ) throws -> [HumanHealthMetricLog] {
        var result: [HumanHealthMetricLog] = []
        result.reserveCapacity(metricKeys.count)

        for metricKey in metricKeys.sorted() where !metricKey.isEmpty {
            var descriptor = FetchDescriptor<HumanHealthMetricLog>(
                predicate: #Predicate<HumanHealthMetricLog> { log in
                    log.human?.id == humanID && log.metricKey == metricKey
                },
                sortBy: [
                    SortDescriptor(\.date, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse)
                ]
            )
            descriptor.fetchLimit = 1
            if let log = try fetch(
                descriptor,
                context: context,
                name: "latest linked HumanHealthMetricLog"
            ).first {
                result.append(log)
            }
        }
        return result
    }

    private nonisolated static func normalizedUUID(_ raw: String) -> UUID? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private nonisolated static func identifierCandidates(for id: UUID) -> [String] {
        let key = id.uuidString
        let lowercasedKey = key.lowercased()
        return key == lowercasedKey ? [key] : [key, lowercasedKey]
    }

    @MainActor
    static func loadRecentObservations(
        humanID: UUID,
        conditionID: UUID,
        now: Date = Date(),
        calendar: Calendar = .current,
        context: ModelContext
    ) throws -> HumanHealthRecentObservationLoad {
        let historyStart = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let candidates = try fetchObservationCandidates(
            humanKeys: identifierCandidates(for: humanID),
            conditionID: conditionID,
            from: historyStart,
            through: now,
            limit: analysisObservationLimit + 1,
            context: context
        )
        let canonical = candidates.filter { observation in
            normalizedUUID(observation.humanId) == humanID &&
                normalizedUUID(observation.conditionId) == conditionID
        }
        let observations = Array(canonical.prefix(analysisObservationLimit))
        return HumanHealthRecentObservationLoad(
            observations: observations,
            totalCount: observations.count,
            isLimited: candidates.count > analysisObservationLimit ||
                canonical.count > analysisObservationLimit
        )
    }

    @MainActor
    private static func fetchObservationCandidates(
        humanKeys: [String],
        conditionID: UUID,
        from start: Date,
        through end: Date,
        limit: Int,
        context: ModelContext
    ) throws -> [HumanHealthObservation] {
        let conditionKey = conditionID.uuidString
        let conditionKeyLower = conditionKey.lowercased()
        var candidatesByID: [UUID: HumanHealthObservation] = [:]
        for humanKey in humanKeys {
            var descriptor = FetchDescriptor<HumanHealthObservation>(
                predicate: #Predicate<HumanHealthObservation> { observation in
                    observation.humanId.contains(humanKey)
                        && (observation.conditionId.contains(conditionKey) || observation.conditionId.contains(conditionKeyLower))
                        && observation.recordedAt >= start
                        && observation.recordedAt <= end
                },
                sortBy: [
                    SortDescriptor(\.recordedAt, order: .reverse),
                    SortDescriptor(\.createdAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse)
                ]
            )
            descriptor.fetchLimit = limit
            for candidate in try fetch(
                descriptor,
                context: context,
                name: "HumanHealthObservation"
            ) {
                candidatesByID[candidate.id] = candidate
            }
        }
        return Array(candidatesByID.values.sorted(by: Self.isNewerObservation).prefix(limit))
    }

    @MainActor
    private static func isNewerObservation(
        _ lhs: HumanHealthObservation,
        _ rhs: HumanHealthObservation
    ) -> Bool {
        if lhs.recordedAt != rhs.recordedAt { return lhs.recordedAt > rhs.recordedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id > rhs.id
    }

    @MainActor
    mutating func replaceConditionPage(
        _ page: HumanHealthConditionPage,
        humanID: UUID,
        now: Date = Date(),
        calendar: Calendar = .current,
        context: ModelContext
    ) throws {
        let pageData = try Self.loadConditionPageData(
            page: page,
            humanID: humanID,
            canViewMedication: includesMedicationDetails,
            now: now,
            calendar: calendar,
            context: context
        )
        conditions = pageData.conditions
        conditionSnapshots = pageData.conditionSnapshots
        analysisLimitedConditionIDs = pageData.analysisLimitedConditionIDs
        medicationAnalysisIncompleteConditionIDs = pageData.medicationAnalysisIncompleteConditionIDs
        medications = pageData.medications
        medicationLogs = pageData.medicationLogs
        metricLogs = pageData.metricLogs
        nextConditionCursor = pageData.nextConditionCursor
        hasOlderConditions = pageData.hasOlderConditions
    }

    @MainActor
    private static func loadObservationSnapshots(
        for conditions: [HumanHealthCondition],
        humanID: UUID,
        includeMedicationDetails: Bool,
        now: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws -> HumanHealthConditionObservationLoad {
        var snapshots: [UUID: HumanHealthConditionTrendSnapshot] = [:]
        var limitedConditionIDs = Set<UUID>()

        for condition in conditions {
            let load = try loadObservationSnapshot(
                humanID: humanID,
                conditionID: condition.id,
                includeMedicationDetails: includeMedicationDetails,
                now: now,
                calendar: calendar,
                context: context
            )
            if load.isLimited { limitedConditionIDs.insert(condition.id) }
            snapshots[condition.id] = load.snapshot
        }

        return HumanHealthConditionObservationLoad(
            snapshots: snapshots,
            limitedConditionIDs: limitedConditionIDs
        )
    }

    @MainActor
    private static func loadObservationSnapshot(
        humanID: UUID,
        conditionID: UUID,
        includeMedicationDetails: Bool,
        now: Date,
        calendar: Calendar,
        context: ModelContext
    ) throws -> HumanHealthConditionObservationSnapshotLoad {
        let recent = try loadRecentObservations(
            humanID: humanID,
            conditionID: conditionID,
            now: now,
            calendar: calendar,
            context: context
        )
        return HumanHealthConditionObservationSnapshotLoad(
            snapshot: HumanHealthConditionAnalysis.trendSnapshot(
                observations: recent.observations,
                includeMedicationDetails: includeMedicationDetails,
                now: now,
                calendar: calendar
            ),
            isLimited: recent.isLimited
        )
    }

    @MainActor
    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) throws -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: bounded deferred fetch
        } catch {
            throw HumanHealthConditionsRouteDataError.fetchFailed(
                name: name,
                message: error.localizedDescription
            )
        }
    }
}

struct HumanHealthRecentObservationLoad {
    let observations: [HumanHealthObservation]
    let totalCount: Int
    let isLimited: Bool
}

private struct HumanHealthConditionPageRouteData {
    let conditions: [HumanHealthCondition]
    let conditionSnapshots: [UUID: HumanHealthConditionTrendSnapshot]
    let analysisLimitedConditionIDs: Set<UUID>
    let medicationAnalysisIncompleteConditionIDs: Set<UUID>
    let medications: [HumanMedication]
    let medicationLogs: [HumanMedicationLog]
    let metricLogs: [HumanHealthMetricLog]
    let nextConditionCursor: HumanHealthHistoryPageCursor?
    let hasOlderConditions: Bool
}

private struct HumanHealthLinkedMedicationLogLoad {
    let logs: [HumanMedicationLog]
    let limitedMedicationIDs: Set<UUID>
}

private struct HumanHealthConditionObservationLoad {
    let snapshots: [UUID: HumanHealthConditionTrendSnapshot]
    let limitedConditionIDs: Set<UUID>
}

private struct HumanHealthConditionObservationSnapshotLoad {
    let snapshot: HumanHealthConditionTrendSnapshot
    let isLimited: Bool
}

private enum HumanHealthConditionsRouteDataError: LocalizedError {
    case fetchFailed(name: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .fetchFailed(name, message): "\(name): \(message)"
        }
    }
}
