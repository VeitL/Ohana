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
}

struct HumanHealthMetricDeleteCommandResult: Equatable {
    let humanID: UUID
    let metricKey: String
    let logID: UUID
    let didChange: Bool
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
        let log = DomainMemberFactWriter.createHumanHealthMetricLog(
            plan: write,
            human: human,
            metricKey: metricKey,
            unitCode: unitCode,
            value: value,
            notes: cleanNotes,
            context: context
        )
        context.safeSave()
        return HumanHealthMetricCommandResult(
            log: log,
            logID: log.id,
            subjectID: human.id,
            metricKey: metricKey
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
                didChange: false
            )
        }
        let logID = log.id
        let metricKey = log.metricKey
        human.healthMetricLogs.removeAll { $0.id == logID }
        CloudSyncMutationRecorder.markDeleted(log, context: context)
        context.delete(log)
        context.safeSave()
        return HumanHealthMetricDeleteCommandResult(
            humanID: human.id,
            metricKey: metricKey,
            logID: logID,
            didChange: true
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
}

struct HumanHealthReportCommandResult: Equatable {
    let humanID: UUID
    let reportID: UUID
    let reportType: String
    let didChange: Bool
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
                didChange: false
            )
        }
        let report = DomainMemberFactWriter.createHumanHealthReport(
            plan: write,
            human: human,
            reportType: input.reportType,
            conclusion: input.conclusion,
            hospitalName: input.hospitalName.trimmingCharacters(in: .whitespacesAndNewlines),
            doctorName: input.doctorName.trimmingCharacters(in: .whitespacesAndNewlines),
            reportDate: input.reportDate,
            nextCheckDate: input.nextCheckDate,
            summary: input.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: input.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            context: context
        )
        context.safeSave()
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: report.id,
            reportType: report.reportTypeRaw,
            didChange: true
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
                didChange: false
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
        CloudSyncMutationRecorder.markModified(report, context: context, modifiedAt: input.reportDate)
        context.safeSave()
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: report.id,
            reportType: report.reportTypeRaw,
            didChange: true
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
                didChange: false
            )
        }
        let reportID = report.id
        let reportType = report.reportTypeRaw
        CloudSyncMutationRecorder.markDeleted(report, context: context)
        context.delete(report)
        context.safeSave()
        return HumanHealthReportCommandResult(
            humanID: human.id,
            reportID: reportID,
            reportType: reportType,
            didChange: true
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
