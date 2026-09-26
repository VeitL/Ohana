import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanHealthMetricPresentationTests {
    @Test func logOrderingUsesDateThenCreatedAtThenUUID() throws {
        let lowID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let highID = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))
        let baseDate = Date(timeIntervalSinceReferenceDate: 1000)
        let baseCreatedAt = Date(timeIntervalSinceReferenceDate: 2000)
        let keys = [
            HumanHealthMetricLogSortKey(date: baseDate, createdAt: baseCreatedAt, id: lowID),
            HumanHealthMetricLogSortKey(date: baseDate, createdAt: baseCreatedAt, id: highID),
            HumanHealthMetricLogSortKey(
                date: baseDate,
                createdAt: baseCreatedAt.addingTimeInterval(1),
                id: lowID
            ),
            HumanHealthMetricLogSortKey(
                date: baseDate.addingTimeInterval(1),
                createdAt: baseCreatedAt,
                id: lowID
            )
        ]

        let newestFirst = keys.sorted(by: HumanHealthMetricLogOrdering.newestFirst)
        let oldestFirst = keys.sorted(by: HumanHealthMetricLogOrdering.oldestFirst)

        #expect(newestFirst == Array(oldestFirst.reversed()))
        #expect(newestFirst == [keys[3], keys[2], keys[1], keys[0]])
    }

    @Test func detailSnapshotKeepsLatestDescendingAndChartAscending() throws {
        let lowID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let middleID = try #require(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let highID = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))
        let metric = try #require(HealthMetricCatalog.metric(forKey: "tsh"))
        let date = Date(timeIntervalSinceReferenceDate: 3000)
        let createdAt = Date(timeIntervalSinceReferenceDate: 4000)
        let logs = [
            makeLog(id: lowID, value: 1, date: date, createdAt: createdAt),
            makeLog(id: highID, value: 3, date: date, createdAt: createdAt),
            makeLog(id: middleID, value: 2, date: date, createdAt: createdAt)
        ]

        let snapshot = HumanHealthMetricDetailLogSnapshot(
            logs: logs,
            metric: metric,
            selectedUnitCode: "mIU_L",
            appCountry: "CN"
        )

        #expect(snapshot.allMetricLogs.map(\.id) == [highID, middleID, lowID])
        #expect(snapshot.selectedUnitLogs.map(\.id) == [highID, middleID, lowID])
        #expect(snapshot.chartLogs.map(\.id) == [lowID, middleID, highID])
        #expect(snapshot.chartPoints.map(\.id) == [lowID, middleID, highID].map(\.uuidString))
    }

    @Test func checkupOutlierCountUsesOnlyLatestValuePerMetric() {
        let human = Human(name: "Human")
        let olderAbnormalTSH = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 8.0,
            date: Date(timeIntervalSinceReferenceDate: 100),
            human: human
        )
        let latestNormalTSH = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2.0,
            date: Date(timeIntervalSinceReferenceDate: 200),
            human: human
        )
        let latestAbnormalHbA1c = HumanHealthMetricLog(
            metricKey: "hba1c",
            unitCode: "percent",
            value: 7.0,
            date: Date(timeIntervalSinceReferenceDate: 300),
            human: human
        )

        let snapshot = HumanHealthCheckupLogSnapshot(logs: [
            olderAbnormalTSH,
            latestNormalTSH,
            latestAbnormalHbA1c
        ])

        #expect(snapshot.trackedMetricCount == 2)
        #expect(snapshot.abnormalLatestMetricCount == 1)
        #expect(snapshot.latestByKey["tsh"]?.id == latestNormalTSH.id)
    }

    @Test func checkupSnapshotUsesASentinelAndMarksCountsIncomplete() {
        let logs = (0 ..< HumanHealthMetricReadPolicy.checkupProbeLimit).map { offset in
            HumanHealthMetricLog(
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: 2,
                date: Date(timeIntervalSinceReferenceDate: Double(offset))
            )
        }

        let snapshot = HumanHealthCheckupLogSnapshot(logs: logs)

        #expect(snapshot.sortedLogs.count == HumanHealthMetricReadPolicy.checkupFetchLimit)
        #expect(snapshot.didReachFetchLimit)
        #expect(snapshot.trackedMetricCount == 1)
    }

    @Test func detailSnapshotBoundsVisibleHistoryAndChart() throws {
        let metric = try #require(HealthMetricCatalog.metric(forKey: "tsh"))
        let logs = (0 ... HumanHealthMetricReadPolicy.detailHistoryLimit).map { offset in
            HumanHealthMetricLog(
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: 1.0 + Double(offset) / 100,
                date: Date(timeIntervalSinceReferenceDate: Double(offset))
            )
        }

        let snapshot = HumanHealthMetricDetailLogSnapshot(
            logs: logs,
            metric: metric,
            selectedUnitCode: "mIU_L",
            appCountry: "CN"
        )

        #expect(snapshot.selectedUnitLogs.count == HumanHealthMetricReadPolicy.detailHistoryLimit + 1)
        #expect(snapshot.visibleHistoryLogs.count == HumanHealthMetricReadPolicy.detailHistoryLimit)
        #expect(snapshot.hasMoreHistory)
        #expect(snapshot.chartLogs.count == HumanHealthMetricReadPolicy.detailChartLimit)
        let firstChartLog = try #require(snapshot.chartLogs.first)
        let lastChartLog = try #require(snapshot.chartLogs.last)
        #expect(firstChartLog.date < lastChartLog.date)
    }

    @Test func detailSnapshotMarksTheBoundedFetchCeiling() throws {
        let metric = try #require(HealthMetricCatalog.metric(forKey: "tsh"))
        let logs = (0 ..< HumanHealthMetricReadPolicy.detailFetchLimit).map { offset in
            HumanHealthMetricLog(
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: 1.0 + Double(offset) / 100,
                date: Date(timeIntervalSinceReferenceDate: Double(offset))
            )
        }

        let snapshot = HumanHealthMetricDetailLogSnapshot(
            logs: logs,
            metric: metric,
            selectedUnitCode: "mIU_L",
            appCountry: "CN"
        )

        #expect(snapshot.didReachFetchLimit)
        #expect(snapshot.allMetricLogs.count == HumanHealthMetricReadPolicy.detailFetchLimit)
    }

    @Test func detailSnapshotCanDiscloseASentinelEvenForAnEmptyVisibleState() throws {
        let metric = try #require(HealthMetricCatalog.metric(forKey: "tsh"))

        let snapshot = HumanHealthMetricDetailLogSnapshot(
            logs: [],
            metric: metric,
            selectedUnitCode: "mIU_L",
            appCountry: "CN",
            didReachFetchLimit: true
        )

        #expect(snapshot.selectedUnitLogs.isEmpty)
        #expect(snapshot.didReachFetchLimit)
    }

    @Test func detailQueryOwnsBoundedUnitReadsOutsideTheView() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let human = Human(name: "Query")
        let older = HumanHealthMetricLog(
            metricKey: "fbg",
            unitCode: "mmol_L",
            value: 5.1,
            date: Date(timeIntervalSinceReferenceDate: 100),
            human: human
        )
        let latest = HumanHealthMetricLog(
            metricKey: "fbg",
            unitCode: "mg_dL",
            value: 96,
            date: Date(timeIntervalSinceReferenceDate: 200),
            human: human
        )
        let unrelated = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2.2,
            date: Date(timeIntervalSinceReferenceDate: 300),
            human: human
        )
        context.insert(human)
        context.insert(older)
        context.insert(latest)
        context.insert(unrelated)
        try context.save()

        let preferredUnitCode = HumanHealthMetricDetailQuery.preferredUnitCode(
            humanID: human.id,
            metricKey: "fbg",
            validUnitCodes: ["mmol_L", "mg_dL"],
            fallbackUnitCode: "mmol_L",
            context: context
        )
        let page = try HumanHealthMetricDetailQuery.page(
            humanID: human.id,
            metricKey: "fbg",
            unitCode: "mg_dL",
            context: context
        )

        #expect(preferredUnitCode == "mg_dL")
        #expect(page.logs.map(\.id) == [latest.id])
        #expect(!page.didReachFetchLimit)
    }

    @Test func checkupRouteReadIsOwnerScopedAndBounded() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let human = Human(name: "Checkup")
        let otherHuman = Human(name: "Other")
        context.insert(human)
        context.insert(otherHuman)

        let targetCount = HumanHealthMetricReadPolicy.checkupProbeLimit + 3
        for offset in 0 ..< targetCount {
            context.insert(HumanHealthMetricLog(
                metricKey: "tsh",
                unitCode: "mIU_L",
                value: Double(offset + 1),
                date: Date(timeIntervalSinceReferenceDate: Double(offset)),
                human: human
            ))
        }
        context.insert(HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 999,
            date: Date(timeIntervalSinceReferenceDate: 10000),
            human: otherHuman
        ))
        try context.save()

        let routeData = HumanHealthCheckupRouteData.load(
            humanID: human.id,
            context: context
        )

        #expect(routeData.hasLoaded)
        #expect(routeData.metricLogs.count == HumanHealthMetricReadPolicy.checkupProbeLimit)
        #expect(routeData.metricLogs.allSatisfy { $0.human?.id == human.id })
        #expect(routeData.metricLogs.first?.value == Double(targetCount))
        #expect(routeData.metricLogs.last?.value == 4)
    }

    @Test func checkupRouteDefersFirstFrameAndListensForMutationRevisions() throws {
        let routeSource = try source("Ohana/Features/Health/HumanHealthCheckupDataContainer.swift")

        #expect(!routeSource.contains("@Query"))
        #expect(routeSource.contains("RouteFirstFrameDeferredLoad("))
        #expect(routeSource.contains("descriptor.fetchLimit = HumanHealthMetricReadPolicy.checkupProbeLimit"))
        #expect(routeSource.contains("homeRevisionUpdates"))
        #expect(routeSource.contains("route-first-frame: allow deferred-fetch"))
    }

    @Test func changingMetricUnitClearsAnUnconvertedValue() {
        #expect(HumanHealthMetricUnitChangePolicy.valueText(
            afterChangingFrom: "mg_dL",
            to: "mmol_L",
            currentValueText: "100"
        ).isEmpty)
        #expect(HumanHealthMetricUnitChangePolicy.valueText(
            afterChangingFrom: "mg_dL",
            to: "mg_dL",
            currentValueText: "100"
        ) == "100")
    }

    @Test func saveSuccessClearsPendingAndAllowsDismissal() {
        let human = Human(name: "Human")
        let log = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2.4,
            human: human
        )
        var state = HumanHealthMetricPresentationState()

        #expect(state.beginSave(isReadOnly: false) == .started)
        #expect(state.isSaving)
        #expect(state.completeSave(result: HumanHealthMetricCommandResult(
            log: log,
            logID: log.id,
            subjectID: human.id,
            metricKey: log.metricKey,
            didPersist: true,
            persistenceErrorDescription: nil
        )) == .persisted)
        #expect(!state.isSaving)
    }

    @Test func nilSaveResultClearsPendingWithoutRequestingDismissal() {
        var state = HumanHealthMetricPresentationState()

        #expect(state.beginSave(isReadOnly: false) == .started)
        #expect(state.completeSave(result: nil) == .failed)
        #expect(!state.isSaving)
    }

    @Test func failedDeleteClearsPendingAndKeepsPresentation() {
        let logID = UUID()
        var state = HumanHealthMetricPresentationState()

        #expect(state.beginDelete(logID: logID, isReadOnly: false) == .started)
        #expect(state.isDeletePending(logID: logID))
        #expect(state.completeDelete(logID: logID, result: HumanHealthMetricDeleteCommandResult(
            humanID: UUID(),
            metricKey: "tsh",
            logID: logID,
            didChange: false,
            persistenceErrorDescription: "Injected save failure"
        )) == .failed)
        #expect(!state.isDeletePending(logID: logID))
    }

    @Test func successfulDeleteClearsPendingAndReturnsDeletedCompletion() {
        let logID = UUID()
        var state = HumanHealthMetricPresentationState()

        #expect(state.beginDelete(logID: logID, isReadOnly: false) == .started)
        #expect(state.completeDelete(logID: logID, result: HumanHealthMetricDeleteCommandResult(
            humanID: UUID(),
            metricKey: "tsh",
            logID: logID,
            didChange: true,
            persistenceErrorDescription: nil
        )) == .deleted)
        #expect(!state.isDeletePending(logID: logID))
    }

    @Test func memorialMemberRejectsPresentationAndDomainWrites() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let human = Human(name: "Memory")
        human.passedAwayDate = Date().addingTimeInterval(-86400)
        let log = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 2.4,
            human: human
        )
        context.insert(human)
        human.healthMetricLogs.append(log)
        context.insert(log)
        try context.save()

        var state = HumanHealthMetricPresentationState()
        #expect(state.beginSave(isReadOnly: true) == .rejectedReadOnly)
        #expect(state.beginDelete(logID: log.id, isReadOnly: true) == .rejectedReadOnly)

        let recordResult = HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 3.1,
            date: Date(),
            notes: "",
            context: context
        )
        let deleteResult = HumanHealthMetricCommandService.deleteMetricLog(
            log,
            human: human,
            context: context
        )

        #expect(recordResult == nil)
        #expect(!deleteResult.didChange)
        #expect(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).map(\.id) == [log.id])
        #expect(human.healthMetricLogs.map(\.id) == [log.id])
    }

    @Test func personalScanMetricRemainsEditableAtFreeAccessAndSafelyKeepsSourceProvenance() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let revisionCenter = ReadModelRevisionCenter()
        let human = Human(name: "Downgraded")
        context.insert(human)
        try context.save()

        let reportID = UUID()
        let logID = UUID()
        let originalDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let importResult = HumanLabReportImportCommandService.importReport(
            human: human,
            input: HumanLabReportImportInput(
                reportID: reportID,
                reportDate: originalDate,
                recordedByHumanId: human.id.uuidString,
                metrics: [
                    HumanLabMetricImportInput(
                        logID: logID,
                        metricKey: "fbg",
                        unitCode: "mmol_L",
                        value: 7.0,
                        sourceLabel: "Fasting Glucose",
                        referenceLow: 3.9,
                        referenceHigh: 6.1,
                        referenceRangeText: "3.9–6.1",
                        reportedFlag: .high,
                        notes: "Imported"
                    )
                ]
            ),
            personalAccessLevel: .personal,
            context: context
        )
        #expect(importResult.didPersist)

        let log = try #require(try context.fetch(FetchDescriptor<HumanHealthMetricLog>()).first)
        let provenance = (
            id: log.id,
            humanID: log.human?.id,
            metricKey: log.metricKey,
            sourceReportID: log.sourceReportID,
            sourceLabel: log.sourceLabel,
            referenceLow: log.referenceLow,
            referenceHigh: log.referenceHigh,
            referenceRangeText: log.referenceRangeText,
            reportedFlag: log.reportedFlag,
            recordedByHumanId: log.recordedByHumanId,
            createdAt: log.createdAt
        )
        let careLedger = CareLedgerService()
        let executor = HumanCareCommandExecutor(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            careLedger: careLedger,
            personalAccessLevel: .free,
            reminderScheduling: ReminderSchedulingManager(careLedger: careLedger),
            medicationReminders: SharedMedicationReminderManager(careLedger: careLedger)
        )
        #expect(executor.personalAccessLevel == .free)

        let invalidUnitResult = executor.updateHealthMetric(
            log,
            human: human,
            input: HumanHealthMetricUpdateInput(
                unitCode: "not-a-fbg-unit",
                value: 5.2,
                date: originalDate,
                notes: "Invalid unit"
            ),
            note: "test.health.metric.invalidUnit"
        )
        #expect(!invalidUnitResult.didPersist)
        #expect(!invalidUnitResult.didChange)
        #expect(log.value == 7.0)
        #expect(revisionCenter.lastMutation == nil)

        let crossUnitResult = executor.updateHealthMetric(
            log,
            human: human,
            input: HumanHealthMetricUpdateInput(
                unitCode: "mg_dL",
                value: 94,
                date: originalDate,
                notes: "Unsafe unit change"
            ),
            note: "test.health.metric.importedUnitLocked"
        )
        #expect(!crossUnitResult.didPersist)
        #expect(!crossUnitResult.didChange)
        #expect(crossUnitResult.persistenceErrorDescription == "humanHealthMetric.importedUnitLocked")
        #expect(log.unitCode == "mmol_L")
        #expect(log.value == 7.0)
        #expect(revisionCenter.lastMutation == nil)

        let changedDateResult = executor.updateHealthMetric(
            log,
            human: human,
            input: HumanHealthMetricUpdateInput(
                unitCode: "mmol_L",
                value: 5.2,
                date: originalDate.addingTimeInterval(3600),
                notes: "Unsafe date change"
            ),
            note: "test.health.metric.importedDateLocked"
        )
        #expect(!changedDateResult.didPersist)
        #expect(!changedDateResult.didChange)
        #expect(changedDateResult.persistenceErrorDescription == "humanHealthMetric.importedDateLocked")
        #expect(log.date == originalDate)
        #expect(log.value == 7.0)
        #expect(revisionCenter.lastMutation == nil)

        let notesOnlyResult = executor.updateHealthMetric(
            log,
            human: human,
            input: HumanHealthMetricUpdateInput(
                unitCode: "mmol_L",
                value: 7.0,
                date: originalDate,
                notes: "Notes reviewed"
            ),
            note: "test.health.metric.notesOnly"
        )
        #expect(notesOnlyResult.didPersist)
        #expect(notesOnlyResult.didChange)
        #expect(log.notes == "Notes reviewed")
        #expect(log.reportedFlag == .high)
        #expect(log.sourceReportID == provenance.sourceReportID)
        #expect(log.referenceLow == provenance.referenceLow)
        #expect(log.referenceHigh == provenance.referenceHigh)
        #expect(log.referenceRangeText == provenance.referenceRangeText)

        let updateResult = executor.updateHealthMetric(
            log,
            human: human,
            input: HumanHealthMetricUpdateInput(
                unitCode: "mmol_L",
                value: 5.2,
                date: originalDate,
                notes: "  Reviewed correction  "
            ),
            note: "test.health.metric.updateAfterDowngrade"
        )

        #expect(updateResult.didPersist)
        #expect(updateResult.didChange)
        #expect(updateResult.unitCode == "mmol_L")
        #expect(log.value == 5.2)
        #expect(log.date == originalDate)
        #expect(log.notes == "Reviewed correction")
        #expect(log.id == provenance.id)
        #expect(log.human?.id == provenance.humanID)
        #expect(log.metricKey == provenance.metricKey)
        #expect(log.sourceReportID == provenance.sourceReportID)
        #expect(log.sourceLabel == provenance.sourceLabel)
        #expect(log.referenceLow == provenance.referenceLow)
        #expect(log.referenceHigh == provenance.referenceHigh)
        #expect(log.referenceRangeText == provenance.referenceRangeText)
        #expect(provenance.reportedFlag == .high)
        #expect(log.reportedFlag == .unknown)
        #expect(log.recordedByHumanId == provenance.recordedByHumanId)
        #expect(log.createdAt == provenance.createdAt)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()) == 1)
        #expect(revisionCenter.lastMutation?.command == .humanHealthMetricUpdate(
            humanID: human.id,
            metricKey: "fbg",
            logID: logID
        ))
        #expect(revisionCenter.lastMutation?.affectedEntityIDs == [human.id, logID])
        #expect(revisionCenter.lastMutation?.wroteBusinessFact == true)
        #expect(!context.hasChanges)
    }

    @Test func manualMetricCanChangeCatalogUnitAndDateThroughTheSameCommand() throws {
        let container = try SharedModelContainer.makePreview()
        let context = container.mainContext
        let human = Human(name: "Manual")
        context.insert(human)
        try context.save()
        let originalDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let recordResult = try #require(HumanHealthMetricCommandService.recordMetric(
            human: human,
            metricKey: "fbg",
            unitCode: "mmol_L",
            value: 5.2,
            date: originalDate,
            notes: "Manual",
            context: context
        ))
        let changedDate = originalDate.addingTimeInterval(7200)

        let updateResult = HumanHealthMetricCommandService.updateMetricLog(
            recordResult.log,
            human: human,
            input: HumanHealthMetricUpdateInput(
                unitCode: "mg_dL",
                value: 94,
                date: changedDate,
                notes: "Converted manually"
            ),
            context: context
        )

        #expect(updateResult.didPersist)
        #expect(updateResult.didChange)
        #expect(recordResult.log.sourceReportID == nil)
        #expect(recordResult.log.unitCode == "mg_dL")
        #expect(recordResult.log.value == 94)
        #expect(recordResult.log.date == changedDate)
        #expect(recordResult.log.notes == "Converted manually")
        #expect(!context.hasChanges)
    }

    @Test func metricEditUIExposesANormalActionAndNeverMutatesPersistentFactsDirectly() throws {
        let commands = try source("Ohana/Features/HumanHealth/HumanHealthCommands.swift")
        let executor = try source("Ohana/Features/HumanNotes/HumanNoteCommands.swift")
        let detail = try source("Ohana/Features/Health/Views/HumanHealthMetricDetailView.swift")
        let editor = try source("Ohana/Features/Health/Views/HumanHealthMetricEditSheet.swift")

        #expect(commands.contains("HealthMetricCatalog.metric(forKey: log.metricKey)?.unit(for: unitCode) != nil"))
        #expect(commands.contains("log.sourceReportID == nil || log.unitCode == unitCode"))
        #expect(commands.contains("log.sourceReportID == nil || log.date == input.date"))
        #expect(commands.contains("log.sourceReportID != nil, didChangeValue"))
        #expect(commands.contains("log.reportedFlag = .unknown"))
        #expect(!commands.contains("personalAccessLevel"))
        #expect(!commands.contains("PersonalFeatureAccessPolicy"))
        #expect(detail.contains("HumanHealthMetricEditSheet("))
        #expect(detail.contains("human-health-metric-edit-action"))
        #expect(editor.contains(".updateHealthMetric("))
        #expect(editor.contains("if log.sourceReportID != nil"))
        #expect(!editor.contains("log.value ="))
        #expect(!editor.contains("log.unitCode ="))
        #expect(!editor.contains("log.date ="))
        #expect(!editor.contains("log.notes ="))
        #expect(!editor.contains("log.reportedFlag ="))
        #expect(!detail.contains("log.value ="))
        #expect(!detail.contains("log.unitCode ="))
        #expect(!detail.contains("modelContext.fetch("))

        let updateStart = try #require(executor.range(of: "func updateHealthMetric("))
        let updateTail = executor[updateStart.lowerBound...]
        let deleteStart = try #require(updateTail.range(of: "func deleteHealthMetric("))
        let updateFunction = updateTail[..<deleteStart.lowerBound]
        #expect(!updateFunction.contains("personalAccessLevel"))
        #expect(updateFunction.contains("publishHumanHealthMetricUpdate"))
    }

    private func makeLog(
        id: UUID,
        value: Double,
        date: Date,
        createdAt: Date
    ) -> HumanHealthMetricLog {
        let log = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: value,
            date: date
        )
        log.id = id
        log.createdAt = createdAt
        return log
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }
}
