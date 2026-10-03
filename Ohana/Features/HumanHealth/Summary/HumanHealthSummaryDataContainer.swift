//
//  HumanHealthSummaryDataContainer.swift
//  Ohana
//
//  Owner-scoped, bounded SwiftData reads for the high-frequency summary.
//

import Combine
import SwiftData
import SwiftUI

private nonisolated enum HumanHealthSummaryQueryLimit {
    static let medicationPlans = 64
    static let medicationLogs = 256
    static let metricLogs = 256
    static let reports = 64
    static let conditions = 32
    static let observations = 32

    static func ownerCandidateWindow(for presentationLimit: Int) -> Int {
        presentationLimit * 2
    }

    static func ownerFetchLimit(for presentationLimit: Int) -> Int {
        ownerCandidateWindow(for: presentationLimit) + 1
    }
}

struct HumanHealthSummaryDataContainer<Content: View>: View {
    let human: Human
    let bodyIsVisible: Bool
    let medicationIsVisible: Bool
    let workoutIsVisible: Bool
    let content: (HumanHealthSummarySnapshot) -> Content

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppServices.self) private var appServices
    @AppStorage(HumanAppleHealthBindingStore.storageKey) private var appleHealthBoundHumanIDRaw = ""
    @State private var referenceDate = Date()
    @State private var readRevision = 0

    init(
        human: Human,
        bodyIsVisible: Bool,
        medicationIsVisible: Bool,
        workoutIsVisible: Bool,
        @ViewBuilder content: @escaping (HumanHealthSummarySnapshot) -> Content
    ) {
        self.human = human
        self.bodyIsVisible = bodyIsVisible
        self.medicationIsVisible = medicationIsVisible
        self.workoutIsVisible = workoutIsVisible
        self.content = content
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: HumanHealthSummaryRouteData(),
            refreshToken: refreshToken,
            loadDelayMilliseconds: 24,
            reloadDelayMilliseconds: 24,
            shouldLoad: { !$0.hasLoaded },
            load: {
                HumanHealthSummaryRouteData.load(
                    human: human,
                    bodyIsVisible: bodyIsVisible,
                    medicationIsVisible: medicationIsVisible,
                    referenceDate: referenceDate,
                    context: modelContext
                )
            }
        ) { data in
            content(data.snapshot(
                human: human,
                bodyIsVisible: bodyIsVisible,
                medicationIsVisible: medicationIsVisible,
                workoutIsVisible: workoutIsVisible,
                referenceDate: referenceDate,
                sourceState: sourceState
            ))
            .redacted(reason: data.hasLoaded ? [] : .placeholder)
            .allowsHitTesting(data.hasLoaded)
            .accessibilityHidden(!data.hasLoaded)
        }
        .id(HumanHealthSummaryDayIdentity.key(for: referenceDate))
        .onAppear {
            referenceDate = Date()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                referenceDate = Date()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            referenceDate = Date()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates.dropFirst()) { revision in
            guard readRevision != revision.value else { return }
            readRevision = revision.value
        }
    }

    private var refreshToken: String {
        let dayKey = HumanHealthSummaryDayIdentity.key(for: referenceDate)
        return "\(human.id.uuidString)|\(dayKey)|\(readRevision)|\(bodyIsVisible)|\(medicationIsVisible)|\(appleHealthBoundHumanIDRaw)"
    }

    private var sourceState: HumanHealthSummarySourceState {
        guard workoutIsVisible else { return .hidden }
        let boundID = HumanAppleHealthBindingPolicy.normalizedHumanID(from: appleHealthBoundHumanIDRaw)
        switch HumanAppleHealthBindingPolicy.state(
            boundHumanID: boundID,
            viewedHumanID: human.id,
            viewedHumanHasPassedAway: human.hasPassedAway
        ) {
        case .boundToViewedHuman:
            return .appleHealthBound
        case .viewedHumanUnavailable:
            return .unavailable
        case .unbound, .boundToOtherHuman:
            return .localOnly
        }
    }
}

private struct HumanHealthSummaryRouteData {
    var medications: [HumanMedication] = []
    var medicationLogs: [HumanMedicationLog] = []
    var metricLogs: [HumanHealthMetricLog] = []
    var reports: [HumanHealthReport] = []
    var conditions: [HumanHealthCondition] = []
    var observations: [HumanHealthObservation] = []
    var medicationsDidLoad = false
    var medicationLogsDidLoad = false
    var metricLogsDidLoad = false
    var reportsDidLoad = false
    var conditionsDidLoad = false
    var observationsDidLoad = false
    var hasLoaded = false

    @MainActor
    static func load(
        human: Human,
        bodyIsVisible: Bool,
        medicationIsVisible: Bool,
        referenceDate: Date,
        context: ModelContext
    ) -> HumanHealthSummaryRouteData {
        let humanID = human.id
        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        let calendar = Calendar.current
        let logStart = calendar.startOfDay(for: referenceDate)
        let logEnd = calendar.date(byAdding: .day, value: 1, to: logStart) ?? Date.distantFuture
        let observationStart = calendar.date(byAdding: .day, value: -13, to: logStart) ?? logStart
        let resolvedStatus = HumanHealthTrackingStatus.resolved.rawValue
        let noMedicationEndBoundary = Date.distantFuture

        var medicationDescriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                (medication.humanId.contains(humanKey) || medication.humanId.contains(humanKeyLower)) &&
                    medication.isActive &&
                    medication.startDate < logEnd &&
                    (medication.endDate ?? noMedicationEndBoundary) >= logStart
            },
            sortBy: [
                SortDescriptor(\HumanMedication.createdAt, order: .reverse),
                SortDescriptor(\HumanMedication.id, order: .reverse)
            ]
        )
        medicationDescriptor.fetchLimit = HumanHealthSummaryQueryLimit.ownerFetchLimit(
            for: HumanHealthSummaryQueryLimit.medicationPlans
        )

        var medicationLogDescriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                (log.humanId.contains(humanKey) || log.humanId.contains(humanKeyLower)) &&
                    log.scheduledTime >= logStart &&
                    log.scheduledTime < logEnd
            },
            sortBy: [
                SortDescriptor(\HumanMedicationLog.scheduledTime, order: .reverse),
                SortDescriptor(\HumanMedicationLog.createdAt, order: .reverse),
                SortDescriptor(\HumanMedicationLog.id, order: .reverse)
            ]
        )
        medicationLogDescriptor.fetchLimit = HumanHealthSummaryQueryLimit.ownerFetchLimit(
            for: HumanHealthSummaryQueryLimit.medicationLogs
        )

        var metricDescriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { log in
                log.human?.id == humanID
            },
            sortBy: [
                SortDescriptor(\HumanHealthMetricLog.date, order: .reverse),
                SortDescriptor(\HumanHealthMetricLog.createdAt, order: .reverse),
                SortDescriptor(\HumanHealthMetricLog.id, order: .reverse)
            ]
        )
        metricDescriptor.fetchLimit = HumanHealthSummaryQueryLimit.metricLogs + 1

        var reportDescriptor = FetchDescriptor<HumanHealthReport>(
            predicate: #Predicate<HumanHealthReport> { report in
                report.humanId.contains(humanKey) || report.humanId.contains(humanKeyLower)
            },
            sortBy: [
                SortDescriptor(\HumanHealthReport.reportDate, order: .reverse),
                SortDescriptor(\HumanHealthReport.createdAt, order: .reverse),
                SortDescriptor(\HumanHealthReport.id, order: .reverse)
            ]
        )
        reportDescriptor.fetchLimit = HumanHealthSummaryQueryLimit.ownerFetchLimit(
            for: HumanHealthSummaryQueryLimit.reports
        )

        var conditionDescriptor = FetchDescriptor<HumanHealthCondition>(
            predicate: #Predicate<HumanHealthCondition> { condition in
                (condition.humanId.contains(humanKey) || condition.humanId.contains(humanKeyLower)) &&
                    condition.trackingStatusRaw != resolvedStatus
            },
            sortBy: [
                SortDescriptor(\HumanHealthCondition.updatedAt, order: .reverse),
                SortDescriptor(\HumanHealthCondition.createdAt, order: .reverse),
                SortDescriptor(\HumanHealthCondition.id, order: .reverse)
            ]
        )
        conditionDescriptor.fetchLimit = HumanHealthSummaryQueryLimit.ownerFetchLimit(
            for: HumanHealthSummaryQueryLimit.conditions
        )

        var observationDescriptor = FetchDescriptor<HumanHealthObservation>(
            predicate: #Predicate<HumanHealthObservation> { observation in
                (observation.humanId.contains(humanKey) || observation.humanId.contains(humanKeyLower)) &&
                    observation.recordedAt >= observationStart &&
                    observation.recordedAt <= referenceDate
            },
            sortBy: [
                SortDescriptor(\HumanHealthObservation.recordedAt, order: .reverse),
                SortDescriptor(\HumanHealthObservation.createdAt, order: .reverse),
                SortDescriptor(\HumanHealthObservation.id, order: .reverse)
            ]
        )
        observationDescriptor.fetchLimit = HumanHealthSummaryQueryLimit.ownerFetchLimit(
            for: HumanHealthSummaryQueryLimit.observations
        )

        return loadData(
            medicationDescriptor: medicationDescriptor,
            medicationLogDescriptor: medicationLogDescriptor,
            metricDescriptor: metricDescriptor,
            reportDescriptor: reportDescriptor,
            conditionDescriptor: conditionDescriptor,
            observationDescriptor: observationDescriptor,
            medicationIsVisible: medicationIsVisible,
            bodyIsVisible: bodyIsVisible,
            context: context
        )
    }

    @MainActor
    private static func loadData(
        medicationDescriptor: FetchDescriptor<HumanMedication>,
        medicationLogDescriptor: FetchDescriptor<HumanMedicationLog>,
        metricDescriptor: FetchDescriptor<HumanHealthMetricLog>,
        reportDescriptor: FetchDescriptor<HumanHealthReport>,
        conditionDescriptor: FetchDescriptor<HumanHealthCondition>,
        observationDescriptor: FetchDescriptor<HumanHealthObservation>,
        medicationIsVisible: Bool,
        bodyIsVisible: Bool,
        context: ModelContext
    ) -> HumanHealthSummaryRouteData {
        var data = HumanHealthSummaryRouteData()
        if medicationIsVisible {
            let medications = fetch(medicationDescriptor, context: context, name: "medication plans")
            let medicationLogs = fetch(medicationLogDescriptor, context: context, name: "medication logs")
            data.medications = medications.values
            data.medicationLogs = medicationLogs.values
            data.medicationsDidLoad = medications.didLoad
            data.medicationLogsDidLoad = medicationLogs.didLoad
        } else {
            data.medicationsDidLoad = true
            data.medicationLogsDidLoad = true
        }
        if bodyIsVisible {
            let metricLogs = fetch(metricDescriptor, context: context, name: "metric logs")
            let reports = fetch(reportDescriptor, context: context, name: "reports")
            let conditions = fetch(conditionDescriptor, context: context, name: "conditions")
            let observations = fetch(observationDescriptor, context: context, name: "observations")
            data.metricLogs = metricLogs.values
            data.reports = reports.values
            data.conditions = conditions.values
            data.observations = observations.values
            data.metricLogsDidLoad = metricLogs.didLoad
            data.reportsDidLoad = reports.didLoad
            data.conditionsDidLoad = conditions.didLoad
            data.observationsDidLoad = observations.didLoad
        } else {
            data.metricLogsDidLoad = true
            data.reportsDidLoad = true
            data.conditionsDidLoad = true
            data.observationsDidLoad = true
        }
        data.hasLoaded = true
        return data
    }

    @MainActor
    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> (values: [T], didLoad: Bool) {
        do {
            return (try context.fetch(descriptor), true) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Human health summary failed to load \(name): \(error.localizedDescription)",
                category: "HumanHealth"
            )
            return ([], false)
        }
    }

    @MainActor
    func snapshot(
        human: Human,
        bodyIsVisible: Bool,
        medicationIsVisible: Bool,
        workoutIsVisible: Bool,
        referenceDate: Date,
        sourceState: HumanHealthSummarySourceState
    ) -> HumanHealthSummarySnapshot {
        let canonicalMedications = medications.filter { medication in
            HumanHealthSummaryOwnerIdentity.matches(medication.humanId, humanID: human.id) &&
                HumanHealthSummaryMedicationWindow.includes(
                    isActive: medication.isActive,
                    startDate: medication.startDate,
                    endDate: medication.endDate,
                    on: referenceDate
                )
        }
        let canonicalMedicationLogs = medicationLogs.filter {
            HumanHealthSummaryOwnerIdentity.matches($0.humanId, humanID: human.id)
        }
        let canonicalReports = reports.filter {
            HumanHealthSummaryOwnerIdentity.matches($0.humanId, humanID: human.id)
        }
        let canonicalConditions = conditions.filter {
            HumanHealthSummaryOwnerIdentity.matches($0.humanId, humanID: human.id) &&
                $0.trackingStatus != .resolved
        }
        let canonicalObservations = observations.filter {
            HumanHealthSummaryOwnerIdentity.matches($0.humanId, humanID: human.id)
        }
        let medicationPlansAreTruncated = !medicationsDidLoad || ownerCollectionIsTruncated(
            candidateCount: medications.count,
            canonicalCount: canonicalMedications.count,
            presentationLimit: HumanHealthSummaryQueryLimit.medicationPlans
        )
        let medicationLogsAreTruncated = !medicationLogsDidLoad || ownerCollectionIsTruncated(
            candidateCount: medicationLogs.count,
            canonicalCount: canonicalMedicationLogs.count,
            presentationLimit: HumanHealthSummaryQueryLimit.medicationLogs
        )
        let metricLogsAreTruncated = !metricLogsDidLoad || metricLogs.count > HumanHealthSummaryQueryLimit.metricLogs
        let reportsAreTruncated = !reportsDidLoad || ownerCollectionIsTruncated(
            candidateCount: reports.count,
            canonicalCount: canonicalReports.count,
            presentationLimit: HumanHealthSummaryQueryLimit.reports
        )
        let conditionsAreTruncated = !conditionsDidLoad || ownerCollectionIsTruncated(
            candidateCount: conditions.count,
            canonicalCount: canonicalConditions.count,
            presentationLimit: HumanHealthSummaryQueryLimit.conditions
        )
        let observationsAreTruncated = !observationsDidLoad || ownerCollectionIsTruncated(
            candidateCount: observations.count,
            canonicalCount: canonicalObservations.count,
            presentationLimit: HumanHealthSummaryQueryLimit.observations
        )
        let visibleMedications = medicationIsVisible
            ? Array(canonicalMedications.prefix(HumanHealthSummaryQueryLimit.medicationPlans))
            : []
        let visibleMedicationLogs = medicationIsVisible
            ? Array(canonicalMedicationLogs.prefix(HumanHealthSummaryQueryLimit.medicationLogs))
            : []
        let medicationInput = medicationInput(
            medications: visibleMedications,
            logs: visibleMedicationLogs,
            humanID: human.id,
            referenceDate: referenceDate
        )

        let visibleMetricLogs = bodyIsVisible
            ? Array(metricLogs.prefix(HumanHealthSummaryQueryLimit.metricLogs))
            : []
        let metricInputs = metricInputs(from: visibleMetricLogs)
        let visibleReports = bodyIsVisible
            ? Array(canonicalReports.prefix(HumanHealthSummaryQueryLimit.reports))
            : []
        let visibleConditions = bodyIsVisible
            ? Array(canonicalConditions.prefix(HumanHealthSummaryQueryLimit.conditions))
            : []
        let visibleObservations = bodyIsVisible
            ? Array(canonicalObservations.prefix(HumanHealthSummaryQueryLimit.observations))
            : []

        return HumanHealthSummaryBuilder.build(
            input: HumanHealthSummaryInput(
                bodyIsVisible: bodyIsVisible,
                medicationIsVisible: medicationIsVisible,
                workoutIsVisible: workoutIsVisible,
                activeMedicationPlanCount: medicationInput.activePlanCount,
                medicationPlansAreTruncated: medicationIsVisible && medicationPlansAreTruncated,
                medicationLogsAreTruncated: medicationIsVisible && medicationLogsAreTruncated,
                metricLogsAreTruncated: bodyIsVisible && metricLogsAreTruncated,
                reportsAreTruncated: bodyIsVisible && reportsAreTruncated,
                conditionsAreTruncated: bodyIsVisible && conditionsAreTruncated,
                observationsAreTruncated: bodyIsVisible && observationsAreTruncated,
                doses: medicationInput.doses,
                metrics: metricInputs,
                reports: visibleReports.map {
                    HumanHealthSummaryReportInput(
                        id: $0.id,
                        reportTypeRaw: $0.reportTypeRaw,
                        reportDate: $0.reportDate,
                        nextCheckDate: $0.nextCheckDate,
                        createdAt: $0.createdAt
                    )
                },
                conditions: visibleConditions.map {
                    HumanHealthSummaryConditionInput(
                        id: $0.id,
                        name: $0.name,
                        isActive: $0.trackingStatus != .resolved,
                        updatedAt: $0.updatedAt
                    )
                },
                observations: visibleObservations.map {
                    HumanHealthSummaryObservationInput(
                        id: $0.id,
                        conditionID: UUID(
                            uuidString: $0.conditionId.trimmingCharacters(in: .whitespacesAndNewlines)
                        ),
                        recordedAt: $0.recordedAt,
                        severity: $0.severity,
                        moodScore: $0.moodScore
                    )
                },
                sourceState: sourceState
            ),
            now: referenceDate
        )
    }

    private func medicationInput(
        medications: [HumanMedication],
        logs: [HumanMedicationLog],
        humanID: UUID,
        referenceDate: Date
    ) -> (doses: [HumanHealthSummaryDoseInput], activePlanCount: Int) {
        let doses = HumanMedicationSchedulePlan
            .doses(on: referenceDate, medications: medications)
            .map { dose in
                let log = HumanMedicationLogStore.matchingLog(
                    in: logs,
                    humanId: humanID.uuidString,
                    medicationId: dose.medication.id.uuidString,
                    scheduledTime: dose.scheduledTime
                )
                return HumanHealthSummaryDoseInput(
                    medicationID: dose.medication.id,
                    name: dose.medication.name,
                    dosage: dose.medication.dosage,
                    scheduledTime: dose.scheduledTime,
                    state: doseState(log?.status)
                )
            }
        let activePlanCount = medications.count { medication in
            let group = HumanMedicationSchedulePlan.displayGroup(for: medication, now: referenceDate)
            return group == .current || group == .manual
        }
        return (doses, activePlanCount)
    }

    private func metricInputs(
        from logs: [HumanHealthMetricLog]
    ) -> [HumanHealthSummaryMetricInput] {
        logs.compactMap { log in
            guard let metric = HealthMetricCatalog.metric(forKey: log.metricKey),
                  let unit = metric.unit(for: log.unitCode) else { return nil }
            return HumanHealthSummaryMetricInput(
                id: log.id,
                metricKey: log.metricKey,
                unitCode: log.unitCode,
                value: log.value,
                date: log.date,
                createdAt: log.createdAt,
                status: metricStatus(
                    HumanHealthMetricReferenceEvaluator.status(for: log, fallbackUnit: unit)
                )
            )
        }
    }

    private func ownerCollectionIsTruncated(
        candidateCount: Int,
        canonicalCount: Int,
        presentationLimit: Int
    ) -> Bool {
        canonicalCount > presentationLimit ||
            candidateCount > HumanHealthSummaryQueryLimit.ownerCandidateWindow(for: presentationLimit)
    }

    private func doseState(_ status: HumanMedicationStatus?) -> HumanHealthSummaryDoseState {
        switch status {
        case .taken: .taken
        case .skipped: .skipped
        case .pending, nil: .pending
        }
    }

    private func metricStatus(_ status: HealthMetricStatus) -> HumanHealthSummaryMetricStatus {
        switch status {
        case .low: .low
        case .normal: .normal
        case .high: .high
        case .unknown: .unknown
        }
    }
}
