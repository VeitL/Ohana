//
//  HumanHealthCommands.swift
//  Ohana
//
//  Domain write boundaries for human health metrics and reports.
//

import Foundation
import SwiftData

struct HumanHealthMetricCommandResult {
    let log: HumanHealthMetricLog
    let logID: UUID
    let subjectID: UUID
    let metricKey: String
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
        guard value > 0, value.isFinite else { return nil }
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
    static func deleteMetricLog(
        _ log: HumanHealthMetricLog,
        human: Human,
        context: ModelContext
    ) -> HumanHealthMetricDeleteCommandResult {
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
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
}

struct HumanHealthReportCommandInput: Equatable {
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
}

enum HumanHealthReportCommandService {
    @discardableResult
    @MainActor
    static func createReport(
        human: Human,
        input: HumanHealthReportCommandInput,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
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
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return HumanHealthReportCommandResult(
                humanID: human.id,
                reportID: report.id,
                reportType: report.reportTypeRaw,
                didChange: false,
                persistenceErrorDescription: nil
            )
        }
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
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func deleteReport(
        _ report: HumanHealthReport,
        human: Human,
        context: ModelContext
    ) -> HumanHealthReportCommandResult {
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
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
            persistenceErrorDescription: nil
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
