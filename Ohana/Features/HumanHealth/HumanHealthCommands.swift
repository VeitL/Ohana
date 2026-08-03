//
//  HumanHealthCommands.swift
//  Ohana
//
//  Domain write boundaries for human health metrics and reports.
//

import Foundation
import SwiftData

@MainActor
enum HumanHealthCommandOwnership {
    static func owns(_ log: HumanHealthMetricLog, human: Human) -> Bool {
        log.human?.id == human.id
    }

    static func owns(_ report: HumanHealthReport, human: Human) -> Bool {
        UUID(
            uuidString: report.humanId.trimmingCharacters(in: .whitespacesAndNewlines)
        ) == human.id
    }
}

struct HumanHealthMetricCommandResult {
    let log: HumanHealthMetricLog
    let logID: UUID
    let subjectID: UUID
    let metricKey: String
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

nonisolated struct HumanHealthMetricUpdateInput: Equatable, Sendable {
    let unitCode: String
    let value: Double
    let date: Date
    let notes: String
}

nonisolated struct HumanHealthMetricUpdateCommandResult: Equatable, Sendable {
    let humanID: UUID
    let logID: UUID
    let metricKey: String
    let unitCode: String
    let didChange: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
}

struct HumanHealthMetricDeleteCommandResult: Equatable {
    let humanID: UUID
    let metricKey: String
    let logID: UUID
    let didChange: Bool
    let persistenceErrorDescription: String?
}

enum HumanHealthMetricCommandService {
    @discardableResult
    @MainActor
    static func recordMetric(
        human: Human,
        metricKey: String,
        unitCode: String,
        value: Double,
        date: Date,
        notes: String,
        recordedByHumanId: String? = nil,
        context: ModelContext
    ) -> HumanHealthMetricCommandResult? {
        guard value > 0, value.isFinite, !context.hasChanges else { return nil }
        guard let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
            human: human,
            occurredAt: date,
            writeKind: .care,
            context: context,
            logPrefix: "HumanHealthMetricCommandService.recordMetric"
        ) else { return nil }
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let validatedRecorderID = HumanActionAttributionPolicy.activeHumanID(recordedByHumanId, context: context)
        let log = DomainMemberFactWriter.createHumanHealthMetricLog(
            plan: write,
            human: human,
            metricKey: metricKey,
            unitCode: unitCode,
            value: value,
            notes: cleanNotes,
            recordedByHumanId: validatedRecorderID,
            context: context
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return nil
        }
        return HumanHealthMetricCommandResult(
            log: log,
            logID: log.id,
            subjectID: human.id,
            metricKey: metricKey,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func updateMetricLog(
        _ log: HumanHealthMetricLog,
        human: Human,
        input: HumanHealthMetricUpdateInput,
        context: ModelContext
    ) -> HumanHealthMetricUpdateCommandResult {
        let unitCode = input.unitCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.hasChanges else {
            return updateFailure(
                log: log,
                human: human,
                unitCode: unitCode,
                error: "Human health metric command requires a clean ModelContext"
            )
        }
        guard input.value > 0,
              input.value.isFinite,
              HealthMetricCatalog.metric(forKey: log.metricKey)?.unit(for: unitCode) != nil else {
            return updateFailure(
                log: log,
                human: human,
                unitCode: unitCode,
                error: "humanHealthMetric.invalidInput"
            )
        }
        guard log.sourceReportID == nil || log.unitCode == unitCode else {
            return updateFailure(
                log: log,
                human: human,
                unitCode: unitCode,
                error: "humanHealthMetric.importedUnitLocked"
            )
        }
        guard log.sourceReportID == nil || log.date == input.date else {
            return updateFailure(
                log: log,
                human: human,
                unitCode: unitCode,
                error: "humanHealthMetric.importedDateLocked"
            )
        }
        guard HumanHealthCommandOwnership.owns(log, human: human),
              MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return updateFailure(log: log, human: human, unitCode: unitCode)
        }

        let notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let didChangeValue = log.value != input.value
        let didChange = log.unitCode != unitCode
            || didChangeValue
            || log.date != input.date
            || log.notes != notes
        guard didChange else {
            return HumanHealthMetricUpdateCommandResult(
                humanID: human.id,
                logID: log.id,
                metricKey: log.metricKey,
                unitCode: log.unitCode,
                didChange: false,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        log.unitCode = unitCode
        log.value = input.value
        log.date = input.date
        log.notes = notes
        if log.sourceReportID != nil, didChangeValue {
            log.reportedFlag = .unknown
        }
        CloudSyncMutationRecorder.markModified(log, context: context)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            let logID = log.id
            let metricKey = log.metricKey
            context.rollback()
            return HumanHealthMetricUpdateCommandResult(
                humanID: human.id,
                logID: logID,
                metricKey: metricKey,
                unitCode: unitCode,
                didChange: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return HumanHealthMetricUpdateCommandResult(
            humanID: human.id,
            logID: log.id,
            metricKey: log.metricKey,
            unitCode: log.unitCode,
            didChange: true,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func deleteMetricLog(
        _ log: HumanHealthMetricLog,
        human: Human,
        context: ModelContext
    ) -> HumanHealthMetricDeleteCommandResult {
        guard !context.hasChanges,
              HumanHealthCommandOwnership.owns(log, human: human),
              MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return HumanHealthMetricDeleteCommandResult(
                humanID: human.id,
                metricKey: log.metricKey,
                logID: log.id,
                didChange: false,
                persistenceErrorDescription: nil
            )
        }
        let logID = log.id
        let metricKey = log.metricKey
        human.healthMetricLogs.removeAll { $0.id == logID }
        CloudSyncMutationRecorder.markDeleted(log, context: context)
        context.delete(log)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return HumanHealthMetricDeleteCommandResult(
                humanID: human.id,
                metricKey: metricKey,
                logID: logID,
                didChange: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return HumanHealthMetricDeleteCommandResult(
            humanID: human.id,
            metricKey: metricKey,
            logID: logID,
            didChange: true,
            persistenceErrorDescription: nil
        )
    }

    @MainActor
    private static func updateFailure(
        log: HumanHealthMetricLog,
        human: Human,
        unitCode: String,
        error: String? = nil
    ) -> HumanHealthMetricUpdateCommandResult {
        HumanHealthMetricUpdateCommandResult(
            humanID: human.id,
            logID: log.id,
            metricKey: log.metricKey,
            unitCode: unitCode,
            didChange: false,
            didPersist: false,
            persistenceErrorDescription: error
        )
    }
}

nonisolated struct HumanHealthReportCommandInput: Equatable, Sendable {
    let reportType: HealthReportType
    let conclusion: ReportConclusion
    let hospitalName: String
    let doctorName: String
    let reportDate: Date
    let nextCheckDate: Date?
    let summary: String
    let notes: String
    var recordedByHumanId: String? = nil
}

struct HumanHealthReportCommandResult: Equatable {
    let humanID: UUID
    let reportID: UUID
    let reportType: String
    let didChange: Bool
    let persistenceErrorDescription: String?
    var affectedMetricLogIDs: Set<UUID> = []
}

nonisolated enum HumanHealthReportInputValidation {
    static func error(
        for input: HumanHealthReportCommandInput,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let reportDay = calendar.startOfDay(for: input.reportDate)
        let today = calendar.startOfDay(for: now)
        guard reportDay <= today else { return "reportDate.future" }
        if let nextCheckDate = input.nextCheckDate,
           calendar.startOfDay(for: nextCheckDate) < reportDay {
            return "nextCheckDate.beforeReportDate"
        }
        return nil
    }
}

enum HumanHealthReportCommandService {
    @discardableResult
    @MainActor
    static func createReport(
        human: Human,
        input: HumanHealthReportCommandInput,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
        guard !context.hasChanges else {
            return failure(
                humanID: human.id,
                reportID: UUID(),
                reportType: input.reportType.rawValue,
                error: "Human health report command requires a clean ModelContext"
            )
        }
        if let validationError = HumanHealthReportInputValidation.error(for: input) {
            return failure(
                humanID: human.id,
                reportID: UUID(),
                reportType: input.reportType.rawValue,
                error: validationError
            )
        }
        guard let write = DomainMemberFactWriteAuthorizer.authorizeHumanFact(
            human: human,
            occurredAt: input.reportDate,
            writeKind: .care,
            context: context,
            logPrefix: "HumanHealthReportCommandService.createReport"
        ) else {
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: UUID(),
                reportType: input.reportType.rawValue,
                didChange: false,
                persistenceErrorDescription: nil
            )
        }
        let validatedRecorderID = HumanActionAttributionPolicy.activeHumanID(
            input.recordedByHumanId,
            context: context
        )
        let report = DomainMemberFactWriter.createHumanHealthReport(
            plan: write,
            human: human,
            values: DomainHumanHealthReportValues(
                reportType: input.reportType,
                conclusion: input.conclusion,
                hospitalName: input.hospitalName.trimmingCharacters(in: .whitespacesAndNewlines),
                doctorName: input.doctorName.trimmingCharacters(in: .whitespacesAndNewlines),
                reportDate: input.reportDate,
                nextCheckDate: input.nextCheckDate,
                summary: input.summary.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: input.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                recordedByHumanId: validatedRecorderID
            ),
            context: context
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            let reportID = report.id
            let reportType = report.reportTypeRaw
            context.rollback()
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: reportID,
                reportType: reportType,
                didChange: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: report.id,
            reportType: report.reportTypeRaw,
            didChange: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func updateReport(
        _ report: HumanHealthReport,
        human: Human,
        input: HumanHealthReportCommandInput,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
        guard !context.hasChanges else {
            return failure(
                humanID: human.id,
                reportID: report.id,
                reportType: report.reportTypeRaw,
                error: "Human health report command requires a clean ModelContext"
            )
        }
        if let validationError = HumanHealthReportInputValidation.error(for: input) {
            return failure(
                humanID: human.id,
                reportID: report.id,
                reportType: report.reportTypeRaw,
                error: validationError
            )
        }
        guard report.captureSource != .documentScan || input.reportType == .bloodTest else {
            return failure(
                humanID: human.id,
                reportID: report.id,
                reportType: report.reportTypeRaw,
                error: "documentScan.reportTypeLocked"
            )
        }
        guard HumanHealthCommandOwnership.owns(report, human: human),
              MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: report.id,
                reportType: report.reportTypeRaw,
                didChange: false,
                persistenceErrorDescription: nil
            )
        }
        let linkedLogs: [HumanHealthMetricLog]
        if report.captureSource == .documentScan, report.reportDate != input.reportDate {
            do {
                linkedLogs = try linkedMetricLogs(reportID: report.id, context: context)
            } catch {
                return HumanHealthReportCommandResult(
                    humanID: human.id,
                    reportID: report.id,
                    reportType: report.reportTypeRaw,
                    didChange: false,
                    persistenceErrorDescription: error.localizedDescription
                )
            }
            guard linkedLogs.allSatisfy({ HumanHealthCommandOwnership.owns($0, human: human) }) else {
                return HumanHealthReportCommandResult(
                    humanID: human.id,
                    reportID: report.id,
                    reportType: report.reportTypeRaw,
                    didChange: false,
                    persistenceErrorDescription: nil
                )
            }
        } else {
            linkedLogs = []
        }
        let previousReportDate = report.reportDate
        let logsToRedate = linkedLogs.allSatisfy { $0.date == previousReportDate }
            ? linkedLogs
            : []
        report.humanId = human.id.uuidString
        report.reportType = input.reportType
        report.conclusion = input.conclusion
        report.hospitalName = input.hospitalName.trimmingCharacters(in: .whitespacesAndNewlines)
        report.doctorName = input.doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        report.reportDate = input.reportDate
        report.nextCheckDate = input.nextCheckDate
        report.summary = input.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        report.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let requestedRecorderID = input.recordedByHumanId {
            report.recordedByHumanId = HumanActionAttributionPolicy.activeHumanID(
                requestedRecorderID,
                context: context
            )
        }
        for log in logsToRedate {
            log.date = input.reportDate
            CloudSyncMutationRecorder.markModified(log, context: context)
        }
        CloudSyncMutationRecorder.markModified(report, context: context, modifiedAt: input.reportDate)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            let reportID = report.id
            let reportType = report.reportTypeRaw
            context.rollback()
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: reportID,
                reportType: reportType,
                didChange: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: report.id,
            reportType: report.reportTypeRaw,
            didChange: true,
            persistenceErrorDescription: nil,
            affectedMetricLogIDs: Set(logsToRedate.map(\.id))
        )
    }

    @discardableResult
    @MainActor
    static func deleteReport(
        _ report: HumanHealthReport,
        human: Human,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
        guard !context.hasChanges else {
            return failure(
                humanID: human.id,
                reportID: report.id,
                reportType: report.reportTypeRaw,
                error: "Human health report command requires a clean ModelContext"
            )
        }
        guard HumanHealthCommandOwnership.owns(report, human: human),
              MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: report.id,
                reportType: report.reportTypeRaw,
                didChange: false,
                persistenceErrorDescription: nil
            )
        }
        let reportID = report.id
        let reportType = report.reportTypeRaw
        let linkedLogs: [HumanHealthMetricLog]
        do {
            linkedLogs = try linkedMetricLogs(reportID: reportID, context: context)
        } catch {
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: reportID,
                reportType: reportType,
                didChange: false,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        guard linkedLogs.allSatisfy({ HumanHealthCommandOwnership.owns($0, human: human) }) else {
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: reportID,
                reportType: reportType,
                didChange: false,
                persistenceErrorDescription: nil
            )
        }
        for log in linkedLogs {
            log.sourceReportID = nil
            CloudSyncMutationRecorder.markModified(log, context: context)
        }
        CloudSyncMutationRecorder.markDeleted(report, context: context)
        context.delete(report)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: reportID,
                reportType: reportType,
                didChange: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: reportID,
            reportType: reportType,
            didChange: true,
            persistenceErrorDescription: nil,
            affectedMetricLogIDs: Set(linkedLogs.map(\.id))
        )
    }

    private static func linkedMetricLogs(
        reportID: UUID,
        context: ModelContext
    ) throws -> [HumanHealthMetricLog] {
        try context.fetch(
            FetchDescriptor<HumanHealthMetricLog>(
                predicate: #Predicate<HumanHealthMetricLog> { log in
                    log.sourceReportID == reportID
                }
            )
        )
    }

    private static func failure(
        humanID: UUID,
        reportID: UUID,
        reportType: String,
        error: String
    ) -> HumanHealthReportCommandResult {
        HumanHealthReportCommandResult(
            humanID: humanID,
            reportID: reportID,
            reportType: reportType,
            didChange: false,
            persistenceErrorDescription: error
        )
    }
}

@MainActor
struct HumanHealthReportCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
    }

    @discardableResult
    func createReport(
        human: Human,
        input: HumanHealthReportCommandInput,
        note: String
    ) -> HumanHealthReportCommandResult {
        let result = HumanHealthReportCommandService.createReport(
            human: human,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthReport(result, action: "create", note: note)
        }
        return result
    }

    @discardableResult
    func updateReport(
        _ report: HumanHealthReport,
        human: Human,
        input: HumanHealthReportCommandInput,
        note: String
    ) -> HumanHealthReportCommandResult {
        let result = HumanHealthReportCommandService.updateReport(
            report,
            human: human,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthReport(result, action: "update", note: note)
        }
        return result
    }

    @discardableResult
    func deleteReport(
        _ report: HumanHealthReport,
        human: Human,
        note: String
    ) -> HumanHealthReportCommandResult {
        let result = HumanHealthReportCommandService.deleteReport(
            report,
            human: human,
            context: context
        )
        if result.didChange {
            revisions.publishHumanHealthReport(result, action: "delete", note: note)
        }
        return result
    }
}
