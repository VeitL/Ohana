//
//  HumanLabReportImportCommands.swift
//  Ohana
//
//  Atomic local persistence boundary for reviewed on-device lab report recognition.
//

import Foundation
import SwiftData

nonisolated struct HumanLabMetricImportInput: Equatable, Sendable {
    let logID: UUID
    let measuredAt: Date?
    let metricKey: String
    let unitCode: String
    let value: Double
    let sourceLabel: String
    let referenceLow: Double?
    let referenceHigh: Double?
    let referenceRangeText: String
    let reportedFlag: HumanHealthMetricReportedFlag
    let notes: String

    init(
        logID: UUID = UUID(),
        measuredAt: Date? = nil,
        metricKey: String,
        unitCode: String,
        value: Double,
        sourceLabel: String = "",
        referenceLow: Double? = nil,
        referenceHigh: Double? = nil,
        referenceRangeText: String = "",
        reportedFlag: HumanHealthMetricReportedFlag = .unknown,
        notes: String = ""
    ) {
        self.logID = logID
        self.measuredAt = measuredAt
        self.metricKey = metricKey
        self.unitCode = unitCode
        self.value = value
        self.sourceLabel = sourceLabel
        self.referenceLow = referenceLow
        self.referenceHigh = referenceHigh
        self.referenceRangeText = referenceRangeText
        self.reportedFlag = reportedFlag
        self.notes = notes
    }
}

nonisolated struct HumanLabReportImportInput: Equatable, Sendable {
    let reportID: UUID
    let reportType: HealthReportType
    let conclusion: ReportConclusion
    let hospitalName: String
    let doctorName: String
    let reportDate: Date
    let nextCheckDate: Date?
    let summary: String
    let notes: String
    let recordedByHumanId: String?
    let metrics: [HumanLabMetricImportInput]

    init(
        reportID: UUID = UUID(),
        reportType: HealthReportType = .bloodTest,
        conclusion: ReportConclusion = .normal,
        hospitalName: String = "",
        doctorName: String = "",
        reportDate: Date = Date(),
        nextCheckDate: Date? = nil,
        summary: String = "",
        notes: String = "",
        recordedByHumanId: String? = nil,
        metrics: [HumanLabMetricImportInput]
    ) {
        self.reportID = reportID
        self.reportType = reportType
        self.conclusion = conclusion
        self.hospitalName = hospitalName
        self.doctorName = doctorName
        self.reportDate = reportDate
        self.nextCheckDate = nextCheckDate
        self.summary = summary
        self.notes = notes
        self.recordedByHumanId = recordedByHumanId
        self.metrics = metrics
    }
}

nonisolated struct HumanLabReportImportCommandResult: Equatable, Sendable {
    let humanID: UUID
    let reportID: UUID
    let logIDs: Set<UUID>
    let didChange: Bool
    let didPersist: Bool
    let isIdempotentReplay: Bool
    let persistenceErrorDescription: String?
}

@MainActor
enum HumanLabReportImportCommandService {
    private static let maximumMetricCount = 128

    private enum PreflightResult {
        case ready(HumanLabReportImportInput)
        case completed(HumanLabReportImportCommandResult)
    }

    private struct AuthorizedWrites {
        let report: AuthorizedDomainMemberFactWrite
        let metrics: [AuthorizedDomainMemberFactWrite]
    }

    @discardableResult
    static func importReport(
        human: Human,
        input: HumanLabReportImportInput,
        personalAccessLevel: PersonalAccessLevel,
        context: ModelContext,
        saveChanges: (ModelContext) -> ModelContextSaveResult = {
            $0.safeSaveResult(publishFailureEvent: true)
        }
    ) -> HumanLabReportImportCommandResult {
        let normalizedInput: HumanLabReportImportInput
        switch preflight(
            human: human,
            input: input,
            personalAccessLevel: personalAccessLevel,
            context: context
        ) {
        case let .ready(readyInput):
            normalizedInput = readyInput
        case let .completed(result):
            return result
        }

        guard let writes = authorizedWrites(
            human: human,
            input: normalizedInput,
            context: context
        ) else {
            return failure(human: human, input: normalizedInput)
        }

        let report = DomainMemberFactWriter.createHumanHealthReport(
            plan: writes.report,
            human: human,
            values: DomainHumanHealthReportValues(
                id: normalizedInput.reportID,
                reportType: normalizedInput.reportType,
                conclusion: normalizedInput.conclusion,
                hospitalName: normalizedInput.hospitalName,
                doctorName: normalizedInput.doctorName,
                reportDate: normalizedInput.reportDate,
                nextCheckDate: normalizedInput.nextCheckDate,
                summary: normalizedInput.summary,
                notes: normalizedInput.notes,
                recordedByHumanId: normalizedInput.recordedByHumanId,
                captureSource: .documentScan
            ),
            context: context
        )
        let logs = zip(normalizedInput.metrics, writes.metrics).map { pair in
            let (metric, write) = pair
            return DomainMemberFactWriter.createHumanHealthMetricLog(
                plan: write,
                human: human,
                id: metric.logID,
                metricKey: metric.metricKey,
                unitCode: metric.unitCode,
                value: metric.value,
                notes: metric.notes,
                recordedByHumanId: normalizedInput.recordedByHumanId,
                sourceReportID: report.id,
                sourceLabel: metric.sourceLabel,
                referenceLow: metric.referenceLow,
                referenceHigh: metric.referenceHigh,
                referenceRangeText: metric.referenceRangeText,
                reportedFlag: metric.reportedFlag,
                context: context
            )
        }

        let saveResult = saveChanges(context)
        guard saveResult.didSave else {
            rollbackInsertedBatch(
                human: human,
                logs: logs,
                context: context
            )
            return failure(
                human: human,
                input: normalizedInput,
                errorDescription: saveResult.errorDescription
            )
        }
        return HumanLabReportImportCommandResult(
            humanID: human.id,
            reportID: report.id,
            logIDs: Set(logs.map(\.id)),
            didChange: true,
            didPersist: true,
            isIdempotentReplay: false,
            persistenceErrorDescription: nil
        )
    }

    private static func rollbackInsertedBatch(
        human: Human,
        logs: [HumanHealthMetricLog],
        context: ModelContext
    ) {
        let insertedLogIDs = Set(logs.map(\.id))
        human.healthMetricLogs.removeAll { insertedLogIDs.contains($0.id) }
        logs.forEach { $0.human = nil }
        context.rollback()
    }

    private static func preflight(
        human: Human,
        input: HumanLabReportImportInput,
        personalAccessLevel: PersonalAccessLevel,
        context: ModelContext
    ) -> PreflightResult {
        guard PersonalFeatureAccessPolicy.allows(
            .documentScanning,
            level: personalAccessLevel
        ) else {
            return .completed(failure(
                human: human,
                input: input,
                errorDescription: "personal.documentScanning.required"
            ))
        }
        guard !context.hasChanges else {
            return .completed(failure(
                human: human,
                input: input,
                errorDescription: "Pending local changes must be saved before importing a lab report."
            ))
        }
        let normalizedInput = normalized(input, context: context)
        guard isValid(normalizedInput) else {
            return .completed(failure(human: human, input: normalizedInput))
        }

        do {
            let existingReports = try reports(id: normalizedInput.reportID, context: context)
            guard existingReports.count <= 1 else {
                return .completed(failure(human: human, input: normalizedInput))
            }
            if let report = existingReports.first {
                return .completed(replayResult(
                    report: report,
                    human: human,
                    input: normalizedInput,
                    context: context
                ))
            }
            guard try existingLogs(for: normalizedInput, context: context).isEmpty else {
                return .completed(failure(human: human, input: normalizedInput))
            }
            return .ready(normalizedInput)
        } catch {
            return .completed(failure(
                human: human,
                input: normalizedInput,
                errorDescription: error.localizedDescription
            ))
        }
    }

    private static func authorizedWrites(
        human: Human,
        input: HumanLabReportImportInput,
        context: ModelContext
    ) -> AuthorizedWrites? {
        guard let reportWrite = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
            human: human,
            occurredAt: input.reportDate,
            writeKind: .care,
            context: context,
            logPrefix: "HumanLabReportImportCommandService.importReport"
        ) else { return nil }

        var metricWrites: [AuthorizedDomainMemberFactWrite] = []
        metricWrites.reserveCapacity(input.metrics.count)
        for metric in input.metrics {
            guard let measuredAt = metric.measuredAt,
                  let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
                      human: human,
                      occurredAt: measuredAt,
                      writeKind: .care,
                      context: context,
                      logPrefix: "HumanLabReportImportCommandService.importMetric"
                  ) else { return nil }
            metricWrites.append(write)
        }
        return AuthorizedWrites(report: reportWrite, metrics: metricWrites)
    }

    private static func replayResult(
        report: HumanHealthReport,
        human: Human,
        input: HumanLabReportImportInput,
        context: ModelContext
    ) -> HumanLabReportImportCommandResult {
        guard reportMatches(report, human: human, input: input) else {
            return failure(human: human, input: input)
        }
        do {
            let logs = try logs(sourceReportID: input.reportID, context: context)
            guard logs.count == input.metrics.count,
                  metricsMatch(logs, human: human, input: input)
            else {
                return failure(human: human, input: input)
            }
            return HumanLabReportImportCommandResult(
                humanID: human.id,
                reportID: report.id,
                logIDs: Set(logs.map(\.id)),
                didChange: false,
                didPersist: true,
                isIdempotentReplay: true,
                persistenceErrorDescription: nil
            )
        } catch {
            return failure(
                human: human,
                input: input,
                errorDescription: error.localizedDescription
            )
        }
    }

    private static func reportMatches(
        _ report: HumanHealthReport,
        human: Human,
        input: HumanLabReportImportInput
    ) -> Bool {
        HumanHealthCommandOwnership.owns(report, human: human)
            && report.reportType == input.reportType
            && report.conclusion == input.conclusion
            && report.hospitalName == input.hospitalName
            && report.doctorName == input.doctorName
            && report.reportDate == input.reportDate
            && report.nextCheckDate == input.nextCheckDate
            && report.summary == input.summary
            && report.notes == input.notes
            && report.recordedByHumanId == input.recordedByHumanId
            && report.captureSource == .documentScan
    }

    private static func metricsMatch(
        _ logs: [HumanHealthMetricLog],
        human: Human,
        input: HumanLabReportImportInput
    ) -> Bool {
        let inputsByID = Dictionary(uniqueKeysWithValues: input.metrics.map { ($0.logID, $0) })
        return logs.allSatisfy { log in
            guard let metric = inputsByID[log.id] else { return false }
            return HumanHealthCommandOwnership.owns(log, human: human)
                && log.sourceReportID == input.reportID
                && log.metricKey == metric.metricKey
                && log.unitCode == metric.unitCode
                && log.value == metric.value
                && log.date == (metric.measuredAt ?? input.reportDate)
                && log.notes == metric.notes
                && log.recordedByHumanId == input.recordedByHumanId
                && log.sourceLabel == metric.sourceLabel
                && log.referenceLow == metric.referenceLow
                && log.referenceHigh == metric.referenceHigh
                && log.referenceRangeText == metric.referenceRangeText
                && log.reportedFlag == metric.reportedFlag
        }
    }

    private static func existingLogs(
        for input: HumanLabReportImportInput,
        context: ModelContext
    ) throws -> [HumanHealthMetricLog] {
        let linkedLogs = try logs(sourceReportID: input.reportID, context: context)
        guard linkedLogs.isEmpty else { return linkedLogs }

        var matches: [HumanHealthMetricLog] = []
        matches.reserveCapacity(input.metrics.count)
        for metric in input.metrics {
            let logID = metric.logID
            var descriptor = FetchDescriptor<HumanHealthMetricLog>(
                predicate: #Predicate<HumanHealthMetricLog> { log in
                    log.id == logID
                }
            )
            descriptor.fetchLimit = 1
            if let match = try context.fetch(descriptor).first {
                matches.append(match)
            }
        }
        return matches
    }

    private static func reports(
        id: UUID,
        context: ModelContext
    ) throws -> [HumanHealthReport] {
        var descriptor = FetchDescriptor<HumanHealthReport>(
            predicate: #Predicate<HumanHealthReport> { report in
                report.id == id
            }
        )
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor)
    }

    private static func logs(
        sourceReportID: UUID,
        context: ModelContext
    ) throws -> [HumanHealthMetricLog] {
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { log in
                log.sourceReportID == sourceReportID
            }
        )
        descriptor.fetchLimit = maximumMetricCount + 1
        return try context.fetch(descriptor)
    }

    private static func isValid(_ input: HumanLabReportImportInput) -> Bool {
        guard (1 ... maximumMetricCount).contains(input.metrics.count),
              Set(input.metrics.map(\.logID)).count == input.metrics.count
        else { return false }

        return input.metrics.allSatisfy { metric in
            metric.measuredAt?.timeIntervalSinceReferenceDate.isFinite == true
                && HumanHealthMetricImportValidationPolicy.isValid(
                metricKey: metric.metricKey,
                unitCode: metric.unitCode,
                value: metric.value,
                referenceLow: metric.referenceLow,
                referenceHigh: metric.referenceHigh,
                sourceLabel: metric.sourceLabel,
                referenceRangeText: metric.referenceRangeText
            )
        }
    }

    private static func normalized(
        _ input: HumanLabReportImportInput,
        context: ModelContext
    ) -> HumanLabReportImportInput {
        HumanLabReportImportInput(
            reportID: input.reportID,
            reportType: input.reportType,
            conclusion: input.conclusion,
            hospitalName: clean(input.hospitalName, limit: 256),
            doctorName: clean(input.doctorName, limit: 256),
            reportDate: input.reportDate,
            nextCheckDate: input.nextCheckDate,
            summary: clean(input.summary, limit: 4096),
            notes: clean(input.notes, limit: 4096),
            recordedByHumanId: HumanActionAttributionPolicy.activeHumanID(
                input.recordedByHumanId,
                context: context
            ),
            metrics: input.metrics.map { metric in
                HumanLabMetricImportInput(
                    logID: metric.logID,
                    measuredAt: metric.measuredAt ?? input.reportDate,
                    metricKey: clean(metric.metricKey, limit: 128).lowercased(),
                    unitCode: clean(metric.unitCode, limit: 128),
                    value: metric.value,
                    sourceLabel: clean(metric.sourceLabel, limit: 256),
                    referenceLow: metric.referenceLow,
                    referenceHigh: metric.referenceHigh,
                    referenceRangeText: clean(metric.referenceRangeText, limit: 256),
                    reportedFlag: metric.reportedFlag,
                    notes: clean(metric.notes, limit: 1024)
                )
            }
        )
    }

    private static func failure(
        human: Human,
        input: HumanLabReportImportInput,
        errorDescription: String? = nil
    ) -> HumanLabReportImportCommandResult {
        HumanLabReportImportCommandResult(
            humanID: human.id,
            reportID: input.reportID,
            logIDs: Set(input.metrics.map(\.logID)),
            didChange: false,
            didPersist: false,
            isIdempotentReplay: false,
            persistenceErrorDescription: errorDescription
        )
    }

    private static func clean(_ value: String, limit: Int) -> String {
        String(
            value
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(limit)
        )
    }
}

@MainActor
struct HumanLabReportImportCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let personalAccessLevel: PersonalAccessLevel

    init(
        context: ModelContext,
        revisionCenter: ReadModelRevisionCenter,
        personalAccessLevel: PersonalAccessLevel
    ) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            personalAccessLevel: personalAccessLevel
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            personalAccessLevel: services.commerce.personalAccessLevel
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        personalAccessLevel: PersonalAccessLevel
    ) {
        self.context = context
        self.revisions = revisions
        self.personalAccessLevel = personalAccessLevel
    }

    @discardableResult
    func importReport(
        human: Human,
        input: HumanLabReportImportInput,
        note: String = "",
        saveChanges: (ModelContext) -> ModelContextSaveResult = {
            $0.safeSaveResult(publishFailureEvent: true)
        }
    ) -> HumanLabReportImportCommandResult {
        let result = HumanLabReportImportCommandService.importReport(
            human: human,
            input: input,
            personalAccessLevel: personalAccessLevel,
            context: context,
            saveChanges: saveChanges
        )
        if result.didChange {
            revisions.publishHumanLabReportImport(result, note: note)
        }
        return result
    }
}
