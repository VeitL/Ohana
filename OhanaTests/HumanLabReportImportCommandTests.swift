import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanLabReportImportCommandTests {
    @Test func v98KeepsTheV97ModelSetAndMakesLabProvenanceTheLatestLightweightSchema() {
        let v97 = Set(ArkSchemaV97.models.map { String(describing: $0) })
        let v98 = Set(ArkSchemaV98.models.map { String(describing: $0) })
        let manualReport = HumanHealthReport(humanId: UUID().uuidString)
        let manualMetric = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2.5
        )

        #expect(v98 == v97)
        #expect(ObjectIdentifier(ArkMigrationPlan.schemas.last!) == ObjectIdentifier(ArkSchemaV98.self))
        #expect(ArkMigrationPlan.stages.isEmpty)
        #expect(manualReport.captureSource == .manual)
        #expect(manualMetric.sourceReportID == nil)
        #expect(manualMetric.sourceLabel.isEmpty)
        #expect(manualMetric.referenceLow == nil)
        #expect(manualMetric.referenceHigh == nil)
        #expect(manualMetric.referenceRangeText.isEmpty)
        #expect(manualMetric.reportedFlag == .unknown)
    }

    @Test func freeAccessCannotPersistANewDocumentScan() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Free Scanner")
        context.insert(human)
        try context.save()

        let input = HumanLabReportImportInput(
            reportType: .bloodTest,
            conclusion: .normal,
            reportDate: Date(timeIntervalSinceReferenceDate: 810_000_000),
            metrics: [
                HumanLabMetricImportInput(
                    metricKey: "tsh",
                    unitCode: "mIU_L",
                    value: 2.4,
                    sourceLabel: "TSH"
                )
            ]
        )

        let result = HumanLabReportImportCommandService.importReport(
            human: human,
            input: input,
            personalAccessLevel: .free,
            context: context
        )

        #expect(!result.didChange)
        #expect(!result.didPersist)
        #expect(!result.isIdempotentReplay)
        #expect(result.persistenceErrorDescription == "personal.documentScanning.required")
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthReport>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()) == 0)
        #expect(!context.hasChanges)
    }

    @Test func reviewedReportImportsAtomicallyReplaysIdempotentlyAndPublishesOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let human = Human(name: "Avery")
        context.insert(human)
        try context.save()

        let reportDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let input = HumanLabReportImportInput(
            reportID: UUID(),
            reportType: .bloodTest,
            conclusion: .attention,
            hospitalName: " City Lab ",
            doctorName: " Dr. Lin ",
            reportDate: reportDate,
            summary: " Reviewed on device ",
            notes: " Fasting ",
            metrics: [
                HumanLabMetricImportInput(
                    logID: UUID(),
                    metricKey: "tsh",
                    unitCode: "mIU_L",
                    value: 4.8,
                    sourceLabel: " 促甲状腺激素 (TSH) ",
                    referenceLow: 0.4,
                    referenceHigh: 4.0,
                    referenceRangeText: " 0.4 - 4.0 ",
                    reportedFlag: .high
                ),
                HumanLabMetricImportInput(
                    logID: UUID(),
                    metricKey: "hba1c",
                    unitCode: "percent",
                    value: 5.4,
                    sourceLabel: " HbA1c ",
                    referenceLow: 4.0,
                    referenceHigh: 5.6,
                    referenceRangeText: "4.0–5.6",
                    reportedFlag: .normal
                )
            ]
        )
        let executor = HumanLabReportImportCommandExecutor(
            context: context,
            revisionCenter: revisionCenter,
            personalAccessLevel: .personal
        )

        let first = executor.importReport(
            human: human,
            input: input,
            note: "test.lab.import"
        )

        let report = try #require(try context.fetch(FetchDescriptor<HumanHealthReport>()).first)
        let logs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())
        let logsByKey = Dictionary(uniqueKeysWithValues: logs.map { ($0.metricKey, $0) })
        let tsh = try #require(logsByKey["tsh"])
        let firstRevision = revisionCenter.homeRevision.value
        let firstMutation = try #require(revisionCenter.lastMutation)

        #expect(first.didChange)
        #expect(first.didPersist)
        #expect(!first.isIdempotentReplay)
        #expect(first.reportID == input.reportID)
        #expect(first.logIDs == Set(input.metrics.map(\.logID)))
        #expect(report.captureSource == .documentScan)
        #expect(report.hospitalName == "City Lab")
        #expect(report.doctorName == "Dr. Lin")
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.sourceReportID == report.id && $0.date == reportDate })
        #expect(tsh.sourceLabel == "促甲状腺激素 (TSH)")
        #expect(tsh.referenceLow == 0.4)
        #expect(tsh.referenceHigh == 4.0)
        #expect(tsh.referenceRangeText == "0.4 - 4.0")
        #expect(tsh.reportedFlag == .high)
        #expect(firstRevision == 1)
        #expect(firstMutation.command == .humanLabReportImport(
            humanID: human.id,
            reportID: input.reportID,
            metricCount: 2
        ))
        #expect(firstMutation.affectedEntityIDs == first.logIDs.union([human.id, report.id]))

        let replay = executor.importReport(
            human: human,
            input: input,
            note: "test.lab.import.retry"
        )

        #expect(!replay.didChange)
        #expect(replay.didPersist)
        #expect(replay.isIdempotentReplay)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthReport>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()) == 2)
        #expect(revisionCenter.homeRevision.value == firstRevision)
        #expect(revisionCenter.lastMutation?.id == firstMutation.id)

        let correctedReportDate = reportDate.addingTimeInterval(86400)
        let updateResult = HumanHealthReportCommandExecutor(
            context: context,
            revisionCenter: revisionCenter
        ).updateReport(
            report,
            human: human,
            input: HumanHealthReportCommandInput(
                reportType: .bloodTest,
                conclusion: .attention,
                hospitalName: "City Lab",
                doctorName: "Dr. Lin",
                reportDate: correctedReportDate,
                nextCheckDate: nil,
                summary: "Reviewed on device",
                notes: "Fasting"
            ),
            note: "test.lab.report.dateCorrection"
        )
        let correctedLogs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())

        #expect(updateResult.didChange)
        #expect(updateResult.affectedMetricLogIDs == first.logIDs)
        #expect(correctedLogs.allSatisfy { $0.date == correctedReportDate })
        #expect(revisionCenter.lastMutation?.affectedEntityIDs == first.logIDs.union([human.id, report.id]))

        let deleteResult = HumanHealthReportCommandService.deleteReport(
            report,
            human: human,
            context: context
        )
        let retainedLogs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())

        #expect(deleteResult.didChange)
        #expect(deleteResult.affectedMetricLogIDs == first.logIDs)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthReport>()) == 0)
        #expect(retainedLogs.count == 2)
        #expect(retainedLogs.allSatisfy { $0.sourceReportID == nil })
        #expect(retainedLogs.first(where: { $0.id == tsh.id })?.referenceRangeText == "0.4 - 4.0")
    }

    @Test func invalidOrReadOnlyImportWritesNoPartialReportOrMetrics() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let activeHuman = Human(name: "Active")
        let memorialHuman = Human(name: "Memorial")
        memorialHuman.passedAwayDate = Date(timeIntervalSinceReferenceDate: 700_000_000)
        context.insert(activeHuman)
        context.insert(memorialHuman)
        try context.save()

        let invalidInput = HumanLabReportImportInput(
            metrics: [
                HumanLabMetricImportInput(
                    metricKey: "tsh",
                    unitCode: "mIU_L",
                    value: 2.8
                ),
                HumanLabMetricImportInput(
                    metricKey: "not_in_catalog",
                    unitCode: "unknown",
                    value: 1
                )
            ]
        )
        let invalid = HumanLabReportImportCommandService.importReport(
            human: activeHuman,
            input: invalidInput,
            personalAccessLevel: .personal,
            context: context
        )
        let readOnly = HumanLabReportImportCommandService.importReport(
            human: memorialHuman,
            input: HumanLabReportImportInput(
                metrics: [
                    HumanLabMetricImportInput(
                        metricKey: "tsh",
                        unitCode: "mIU_L",
                        value: 2.8
                    )
                ]
            ),
            personalAccessLevel: .personal,
            context: context
        )

        #expect(!invalid.didChange)
        #expect(!invalid.didPersist)
        #expect(!readOnly.didChange)
        #expect(!readOnly.didPersist)
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).isEmpty)
        #expect(activeHuman.healthMetricLogs.isEmpty)
        #expect(memorialHuman.healthMetricLogs.isEmpty)
        #expect(!context.hasChanges)
    }

    @Test func saveFailureAfterInsertRollsBackTheBatchAndPublishesNoRevision() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let human = Human(name: "Rollback Lab")
        context.insert(human)
        try context.save()
        let input = HumanLabReportImportInput(
            reportDate: Date(timeIntervalSinceReferenceDate: 800_000_000),
            metrics: [
                HumanLabMetricImportInput(
                    metricKey: "tsh",
                    unitCode: "mIU_L",
                    value: 2.8,
                    sourceLabel: "TSH"
                )
            ]
        )
        let executor = HumanLabReportImportCommandExecutor(
            context: context,
            revisionCenter: revisionCenter,
            personalAccessLevel: .personal
        )
        let revisionBeforeImport = revisionCenter.homeRevision.value

        let result = executor.importReport(
            human: human,
            input: input,
            note: "test.lab.saveFailure",
            saveChanges: { _ in
                .failed(NSError(domain: "HumanLabReportImportSaveTests", code: 1))
            }
        )

        #expect(!result.didChange)
        #expect(!result.didPersist)
        #expect(!result.isIdempotentReplay)
        #expect(result.persistenceErrorDescription != nil)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthReport>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CloudSyncRecordState>()) == 0)
        #expect(human.healthMetricLogs.isEmpty)
        #expect(!context.hasChanges)
        #expect(revisionCenter.homeRevision.value == revisionBeforeImport)
        #expect(revisionCenter.lastMutation == nil)
    }

    @Test func multiDateReportPersistsEachMeasurementDateAndReportDateChangePreservesThem() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let human = Human(name: "Multi-date Lab")
        context.insert(human)
        try context.save()

        let reportDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let immuneDate = reportDate.addingTimeInterval(-86400)
        let chemistryDate = reportDate.addingTimeInterval(-172_800)
        let input = HumanLabReportImportInput(
            reportID: UUID(),
            reportType: .bloodTest,
            conclusion: .attention,
            reportDate: reportDate,
            metrics: [
                HumanLabMetricImportInput(
                    measuredAt: reportDate,
                    metricKey: "quick",
                    unitCode: "percent",
                    value: 114.9,
                    sourceLabel: "Quick"
                ),
                HumanLabMetricImportInput(
                    measuredAt: immuneDate,
                    metricKey: "b_cells_abs",
                    unitCode: "per_uL",
                    value: 349,
                    sourceLabel: "B-Zellen absolut"
                ),
                HumanLabMetricImportInput(
                    measuredAt: chemistryDate,
                    metricKey: "urea",
                    unitCode: "mg_dL",
                    value: 30,
                    sourceLabel: "Harnstoff"
                )
            ]
        )
        let importExecutor = HumanLabReportImportCommandExecutor(
            context: context,
            revisionCenter: revisionCenter,
            personalAccessLevel: .personal
        )

        let first = importExecutor.importReport(
            human: human,
            input: input,
            note: "test.lab.multiDateImport"
        )
        let report = try #require(try context.fetch(FetchDescriptor<HumanHealthReport>()).first)
        let importedLogs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())
        let importedDates = Dictionary(uniqueKeysWithValues: importedLogs.map { ($0.metricKey, $0.date) })

        #expect(first.didPersist)
        #expect(first.didChange)
        #expect(importedDates == [
            "quick": reportDate,
            "b_cells_abs": immuneDate,
            "urea": chemistryDate
        ])

        let replay = importExecutor.importReport(
            human: human,
            input: input,
            note: "test.lab.multiDateReplay"
        )
        #expect(replay.didPersist)
        #expect(!replay.didChange)
        #expect(replay.isIdempotentReplay)

        let correctedReportDate = reportDate.addingTimeInterval(86400)
        let updateResult = HumanHealthReportCommandExecutor(
            context: context,
            revisionCenter: revisionCenter
        ).updateReport(
            report,
            human: human,
            input: HumanHealthReportCommandInput(
                reportType: .bloodTest,
                conclusion: .attention,
                hospitalName: "",
                doctorName: "",
                reportDate: correctedReportDate,
                nextCheckDate: nil,
                summary: "",
                notes: ""
            ),
            note: "test.lab.multiDateReportCorrection"
        )
        let retainedLogs = try context.fetch(FetchDescriptor<HumanHealthMetricLog>())
        let retainedDates = Dictionary(uniqueKeysWithValues: retainedLogs.map { ($0.metricKey, $0.date) })

        #expect(updateResult.didChange)
        #expect(updateResult.affectedMetricLogIDs.isEmpty)
        #expect(report.reportDate == correctedReportDate)
        #expect(retainedDates == importedDates)
        #expect(revisionCenter.lastMutation?.affectedEntityIDs == Set([human.id, report.id]))
    }

    @Test func conflictingRetryNeverOverwritesThePersistedBatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        context.insert(human)
        try context.save()

        let metricID = UUID()
        let reportID = UUID()
        let original = HumanLabReportImportInput(
            reportID: reportID,
            reportDate: Date(timeIntervalSinceReferenceDate: 800_000_000),
            metrics: [
                HumanLabMetricImportInput(
                    logID: metricID,
                    metricKey: "tsh",
                    unitCode: "mIU_L",
                    value: 2.8
                )
            ]
        )
        let first = HumanLabReportImportCommandService.importReport(
            human: human,
            input: original,
            personalAccessLevel: .personal,
            context: context
        )
        let conflict = HumanLabReportImportCommandService.importReport(
            human: human,
            input: HumanLabReportImportInput(
                reportID: reportID,
                reportDate: original.reportDate,
                metrics: [
                    HumanLabMetricImportInput(
                        logID: metricID,
                        metricKey: "tsh",
                        unitCode: "mIU_L",
                        value: 9.9
                    )
                ]
            ),
            personalAccessLevel: .personal,
            context: context
        )
        let persistedLog = try #require(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).first)

        #expect(first.didPersist)
        #expect(!conflict.didChange)
        #expect(!conflict.didPersist)
        #expect(!conflict.isIdempotentReplay)
        #expect(persistedLog.value == 2.8)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthReport>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()) == 1)
        #expect(!context.hasChanges)
    }

    @Test func pendingContextChangesAreNeitherSavedNorRolledBackByImport() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        context.insert(human)
        try context.save()
        human.name = "Unsaved local edit"

        let result = HumanLabReportImportCommandService.importReport(
            human: human,
            input: HumanLabReportImportInput(
                metrics: [
                    HumanLabMetricImportInput(
                        metricKey: "tsh",
                        unitCode: "mIU_L",
                        value: 2.8
                    )
                ]
            ),
            personalAccessLevel: .personal,
            context: context
        )

        #expect(!result.didChange)
        #expect(!result.didPersist)
        #expect(result.persistenceErrorDescription != nil)
        #expect(human.name == "Unsaved local edit")
        #expect(context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<HumanHealthReport>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV98.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
