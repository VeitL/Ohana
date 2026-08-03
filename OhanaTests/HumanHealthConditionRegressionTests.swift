import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanHealthConditionRegressionTests {
    @Test func conditionExecutorRejectsWritesWithoutTouchingUnrelatedPendingChanges() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let unrelatedHuman = Human(name: "Unrelated")
        let condition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "Tracked condition"
        )
        let observation = HumanHealthObservation(
            humanId: human.id.uuidString,
            conditionId: condition.id.uuidString,
            severity: 4
        )
        context.insert(human)
        context.insert(unrelatedHuman)
        context.insert(condition)
        context.insert(observation)
        try context.save()

        let revisionCenter = ReadModelRevisionCenter()
        let executor = HumanHealthConditionCommandExecutor(
            context: context,
            revisionCenter: revisionCenter
        )
        let initialRevision = revisionCenter.homeRevision

        func beginPendingEdit(_ name: String) {
            unrelatedHuman.name = name
            #expect(context.hasChanges)
        }

        func finishRejectedCommand(_ pendingName: String) throws {
            #expect(unrelatedHuman.name == pendingName)
            #expect(context.hasChanges)
            #expect(revisionCenter.homeRevision == initialRevision)
            context.rollback()
            #expect(!context.hasChanges)
            unrelatedHuman.name = "Unrelated"
            try context.save()
            #expect(unrelatedHuman.name == "Unrelated")
            #expect(!context.hasChanges)
        }

        beginPendingEdit("Pending create")
        let createResult = executor.createCondition(
            human: human,
            input: HumanHealthConditionCommandInput(name: "Must not be created")
        )
        #expect(!createResult.didChange)
        #expect(createResult.persistenceErrorDescription != nil)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthCondition>()) == 1)
        try finishRejectedCommand("Pending create")

        beginPendingEdit("Pending condition update")
        let updateConditionResult = executor.updateCondition(
            condition,
            human: human,
            input: HumanHealthConditionCommandInput(name: "Must not replace")
        )
        #expect(!updateConditionResult.didChange)
        #expect(updateConditionResult.persistenceErrorDescription != nil)
        #expect(condition.name == "Tracked condition")
        try finishRejectedCommand("Pending condition update")

        beginPendingEdit("Pending condition delete")
        let deleteConditionResult = executor.deleteCondition(condition, human: human)
        #expect(!deleteConditionResult.didChange)
        #expect(deleteConditionResult.persistenceErrorDescription != nil)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthCondition>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()) == 1)
        try finishRejectedCommand("Pending condition delete")

        beginPendingEdit("Pending observation create")
        let createObservationResult = executor.recordObservation(
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(severity: 8)
        )
        #expect(!createObservationResult.didChange)
        #expect(createObservationResult.persistenceErrorDescription != nil)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()) == 1)
        try finishRejectedCommand("Pending observation create")

        beginPendingEdit("Pending observation update")
        let updateObservationResult = executor.updateObservation(
            observation,
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(severity: 9)
        )
        #expect(!updateObservationResult.didChange)
        #expect(updateObservationResult.persistenceErrorDescription != nil)
        #expect(observation.severity == 4)
        try finishRejectedCommand("Pending observation update")

        beginPendingEdit("Pending observation delete")
        let deleteObservationResult = executor.deleteObservation(
            observation,
            condition: condition,
            human: human
        )
        #expect(!deleteObservationResult.didChange)
        #expect(deleteObservationResult.persistenceErrorDescription != nil)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()) == 1)
        try finishRejectedCommand("Pending observation delete")
    }

    @Test func routeDataBoundsEachConditionWithoutCrossConditionStarvation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let highFrequency = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "High frequency"
        )
        let sentinel = HumanHealthCondition(
            humanId: human.id.uuidString.lowercased(),
            name: "Sentinel"
        )
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        context.insert(human)
        context.insert(highFrequency)
        context.insert(sentinel)

        for index in 0 ... 1024 {
            context.insert(HumanHealthObservation(
                humanId: human.id.uuidString,
                conditionId: highFrequency.id.uuidString,
                recordedAt: now.addingTimeInterval(Double(-index)),
                severity: index % 11
            ))
        }
        let sentinelObservation = HumanHealthObservation(
            humanId: human.id.uuidString.lowercased(),
            conditionId: sentinel.id.uuidString.lowercased(),
            recordedAt: now.addingTimeInterval(-3600),
            severity: 7
        )
        context.insert(sentinelObservation)
        try context.save()

        let routeData = try HumanHealthConditionsRouteData.load(
            humanID: human.id,
            canViewMedication: false,
            now: now,
            context: context
        )

        let returnedConditionIDs = Set(routeData.conditions.map(\.id))
        let expectedConditionIDs: Set<UUID> = [highFrequency.id, sentinel.id]
        #expect(returnedConditionIDs == expectedConditionIDs)
        #expect(routeData.conditionSnapshots[highFrequency.id]?.totalCount == 1024)
        #expect(routeData.conditionSnapshots[sentinel.id]?.totalCount == 1)
        #expect(routeData.analysisLimitedConditionIDs == [highFrequency.id])
        #expect(routeData.conditionSnapshots[sentinel.id]?.latestSeverity == 7)
        #expect(routeData.recentObservationCount == 1026)
        #expect(routeData.sevenDayObservationCount == 1026)
    }

    @Test func historyPagingMergesCanonicalAndLowercaseUUIDKeys() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let condition = HumanHealthCondition(humanId: human.id.uuidString, name: "Mixed keys")
        let timestamp = Date(timeIntervalSinceReferenceDate: 800_000_000)
        context.insert(human)
        context.insert(condition)
        var expected: [HumanHealthObservation] = []
        for index in 0 ..< 45 {
            let humanID = index.isMultiple(of: 2)
                ? human.id.uuidString
                : human.id.uuidString.lowercased()
            let conditionID = index.isMultiple(of: 3)
                ? condition.id.uuidString.lowercased()
                : condition.id.uuidString
            expected.append(HumanHealthObservation(
                humanId: humanID,
                conditionId: conditionID,
                recordedAt: timestamp,
                severity: index % 11,
                createdAt: timestamp
            ))
        }
        for observation in expected {
            context.insert(observation)
        }
        try context.save()

        let first = try HumanHealthObservationHistoryQuery.page(
            humanID: human.id,
            conditionID: condition.id,
            limit: 40,
            context: context
        )
        let second = try HumanHealthObservationHistoryQuery.page(
            humanID: human.id,
            conditionID: condition.id,
            olderThan: first.nextCursor,
            limit: 40,
            context: context
        )

        #expect(first.records.count == 40)
        #expect(first.hasOlder)
        #expect(second.records.count == 5)
        #expect(!second.hasOlder)
        let returnedIDs = first.records.map(\.id) + second.records.map(\.id)
        let returnedIDSet = Set(returnedIDs)
        let expectedIDSet = Set(expected.map(\.id))
        #expect(returnedIDSet == expectedIDSet)
        #expect(returnedIDs.count == returnedIDSet.count)
    }

    @Test func historyPagingReadsWhitespaceLegacyKeysAndRejectsEmbeddedUUIDDecoys() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let legacyCondition = HumanHealthCondition(
            humanId: "  \(human.id.uuidString.lowercased())  ",
            name: "Legacy whitespace"
        )
        let embeddedOwnerDecoy = HumanHealthCondition(
            humanId: "not-an-owner-\(human.id.uuidString)",
            name: "Embedded owner decoy"
        )
        let legacyObservation = HumanHealthObservation(
            humanId: " \(human.id.uuidString.lowercased()) ",
            conditionId: " \(legacyCondition.id.uuidString.lowercased()) ",
            recordedAt: now.addingTimeInterval(-60),
            severity: 4
        )
        let embeddedConditionDecoy = HumanHealthObservation(
            humanId: human.id.uuidString,
            conditionId: "not-a-condition-\(legacyCondition.id.uuidString)",
            recordedAt: now.addingTimeInterval(-30),
            severity: 9
        )
        context.insert(human)
        context.insert(legacyCondition)
        context.insert(embeddedOwnerDecoy)
        context.insert(legacyObservation)
        context.insert(embeddedConditionDecoy)
        try context.save()

        let conditionPage = try HumanHealthConditionHistoryQuery.page(
            humanID: human.id,
            context: context
        )
        let observationPage = try HumanHealthObservationHistoryQuery.page(
            humanID: human.id,
            conditionID: legacyCondition.id,
            context: context
        )
        let recent = try HumanHealthConditionsRouteData.loadRecentObservations(
            humanID: human.id,
            conditionID: legacyCondition.id,
            now: now,
            context: context
        )

        #expect(conditionPage.records.map(\.id) == [legacyCondition.id])
        #expect(observationPage.records.map(\.id) == [legacyObservation.id])
        #expect(recent.observations.map(\.id) == [legacyObservation.id])
        #expect(!recent.isLimited)
    }

    @Test func trendSnapshotUsesUUIDAsFinalTimestampTieBreaker() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let lowerID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
        let higherID = try #require(UUID(uuidString: "FFFFFFFF-FFFF-4FFF-BFFF-FFFFFFFFFFFF"))
        let lower = HumanHealthObservation(
            humanId: UUID().uuidString,
            conditionId: UUID().uuidString,
            recordedAt: now,
            severity: 2,
            createdAt: now
        )
        lower.id = lowerID
        let higher = HumanHealthObservation(
            humanId: lower.humanId,
            conditionId: lower.conditionId,
            recordedAt: now,
            severity: 9,
            createdAt: now
        )
        higher.id = higherID

        let snapshot = HumanHealthConditionAnalysis.trendSnapshot(
            observations: [higher, lower],
            includeMedicationDetails: false,
            now: now
        )

        #expect(snapshot.latestSeverity == 9)
        let expectedPointIDs = [
            "human-health-severity-\(lowerID.uuidString)",
            "human-health-severity-\(higherID.uuidString)"
        ]
        #expect(snapshot.severityChartPoints.map(\.id) == expectedPointIDs)
    }

    @Test func routeLoadsLinkedMedicationHistoryAndLatestMetricsWithoutGlobalTruncation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let human = Human(name: "Avery")
        let targetMedication = HumanMedication(
            humanId: human.id.uuidString.lowercased(),
            name: "Target",
            startDate: now.addingTimeInterval(-7 * 86400)
        )
        targetMedication.createdAt = now
        let condition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "Linked records",
            linkedMedicationIDs: [targetMedication.id],
            linkedMetricKeys: ["tsh"]
        )
        context.insert(human)
        context.insert(condition)

        var fillerMedicationID = UUID()
        for index in 0 ... 64 {
            let filler = HumanMedication(
                humanId: human.id.uuidString,
                name: "Filler \(index)",
                startDate: now.addingTimeInterval(-7 * 86400)
            )
            filler.createdAt = now.addingTimeInterval(Double(-index - 1))
            if index == 0 { fillerMedicationID = filler.id }
            context.insert(filler)
        }
        context.insert(targetMedication)

        let targetDose = HumanMedicationLog(
            humanId: "  \(human.id.uuidString.lowercased())  ",
            medicationId: "  \(targetMedication.id.uuidString.lowercased())  ",
            scheduledTime: now.addingTimeInterval(-5 * 86400),
            status: .taken,
            recordedTime: now.addingTimeInterval(-5 * 86400 + 60)
        )
        context.insert(targetDose)
        for index in 0 ... 512 {
            context.insert(HumanMedicationLog(
                humanId: human.id.uuidString,
                medicationId: fillerMedicationID.uuidString,
                scheduledTime: now.addingTimeInterval(Double(-index)),
                status: .taken,
                recordedTime: now.addingTimeInterval(Double(-index))
            ))
        }

        let targetMetric = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 4.2,
            date: now.addingTimeInterval(-5 * 86400),
            human: human
        )
        context.insert(targetMetric)
        for index in 0 ..< 256 {
            context.insert(HumanHealthMetricLog(
                metricKey: "unlinked-\(index)",
                unitCode: "count",
                value: Double(index),
                date: now.addingTimeInterval(Double(-index)),
                human: human
            ))
        }
        try context.save()

        let routeData = try HumanHealthConditionsRouteData.load(
            humanID: human.id,
            canViewMedication: true,
            now: now,
            context: context
        )

        #expect(routeData.medications.map(\.id) == [targetMedication.id])
        #expect(routeData.medicationLogs.map(\.id) == [targetDose.id])
        #expect(routeData.metricLogs.map(\.id) == [targetMetric.id])
        #expect(!routeData.medicationAnalysisIsIncomplete)
    }

    @Test func replacingConditionPageAtomicallyReloadsEveryPageScopedAssociation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let human = Human(name: "Avery")
        let newerMedication = HumanMedication(
            humanId: human.id.uuidString,
            name: "Newer page medication",
            startDate: now.addingTimeInterval(-7 * 86400)
        )
        let olderMedication = HumanMedication(
            humanId: " \(human.id.uuidString.lowercased()) ",
            name: "Older page medication",
            startDate: now.addingTimeInterval(-7 * 86400)
        )
        let newerCondition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "Newer linked condition",
            linkedMedicationIDs: [newerMedication.id],
            linkedMetricKeys: ["page-newer"],
            createdAt: now,
            updatedAt: now
        )
        let olderDate = now.addingTimeInterval(-1000)
        let olderCondition = HumanHealthCondition(
            humanId: " \(human.id.uuidString.lowercased()) ",
            name: "Older linked condition",
            linkedMedicationIDs: [olderMedication.id],
            linkedMetricKeys: ["page-older"],
            createdAt: olderDate,
            updatedAt: olderDate
        )
        context.insert(human)
        context.insert(newerMedication)
        context.insert(olderMedication)
        context.insert(newerCondition)
        context.insert(olderCondition)
        for index in 0 ..< HumanHealthConditionsRouteData.conditionPageSize - 1 {
            let timestamp = now.addingTimeInterval(Double(-index - 1))
            context.insert(HumanHealthCondition(
                humanId: human.id.uuidString,
                name: "Newer filler \(index)",
                createdAt: timestamp,
                updatedAt: timestamp
            ))
        }

        let newerLog = HumanMedicationLog(
            humanId: human.id.uuidString,
            medicationId: newerMedication.id.uuidString,
            scheduledTime: now.addingTimeInterval(-60),
            status: .taken,
            recordedTime: now.addingTimeInterval(-30)
        )
        let olderLog = HumanMedicationLog(
            humanId: " \(human.id.uuidString.lowercased()) ",
            medicationId: " \(olderMedication.id.uuidString.lowercased()) ",
            scheduledTime: now.addingTimeInterval(-120),
            status: .taken,
            recordedTime: now.addingTimeInterval(-90)
        )
        let newerMetric = HumanHealthMetricLog(
            metricKey: "page-newer",
            unitCode: "count",
            value: 1,
            date: now,
            human: human
        )
        let olderMetric = HumanHealthMetricLog(
            metricKey: "page-older",
            unitCode: "count",
            value: 2,
            date: olderDate,
            human: human
        )
        let olderObservation = HumanHealthObservation(
            humanId: " \(human.id.uuidString.lowercased()) ",
            conditionId: " \(olderCondition.id.uuidString.lowercased()) ",
            recordedAt: olderDate,
            severity: 7
        )
        context.insert(newerLog)
        context.insert(olderLog)
        context.insert(newerMetric)
        context.insert(olderMetric)
        context.insert(olderObservation)
        try context.save()

        var routeData = try HumanHealthConditionsRouteData.load(
            humanID: human.id,
            canViewMedication: true,
            now: now,
            context: context
        )
        #expect(routeData.medications.map(\.id) == [newerMedication.id])
        #expect(routeData.medicationLogs.map(\.id) == [newerLog.id])
        #expect(routeData.metricLogs.map(\.id) == [newerMetric.id])

        let olderPage = try HumanHealthConditionHistoryQuery.page(
            humanID: human.id,
            olderThan: routeData.nextConditionCursor,
            limit: HumanHealthConditionsRouteData.conditionPageSize,
            context: context
        )
        try routeData.replaceConditionPage(
            olderPage,
            humanID: human.id,
            now: now,
            context: context
        )

        #expect(routeData.conditions.map(\.id) == [olderCondition.id])
        #expect(routeData.medications.map(\.id) == [olderMedication.id])
        #expect(routeData.medicationLogs.map(\.id) == [olderLog.id])
        #expect(routeData.metricLogs.map(\.id) == [olderMetric.id])
        #expect(routeData.conditionSnapshots[olderCondition.id]?.latestSeverity == 7)
        #expect(routeData.conditionSnapshots[newerCondition.id] == nil)
    }

    @Test func linkedMedicationAnalysisUsesPerPlanProbeAndExposesIncompleteState() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let human = Human(name: "Avery")
        let otherHuman = Human(name: "Morgan")
        let medication = HumanMedication(
            humanId: " \(human.id.uuidString.lowercased()) ",
            name: "High-frequency plan",
            startDate: now.addingTimeInterval(-7 * 86400)
        )
        let condition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "Bounded medication analysis",
            linkedMedicationIDs: [medication.id]
        )
        context.insert(human)
        context.insert(otherHuman)
        context.insert(medication)
        context.insert(condition)

        for index in 0 ... HumanHealthConditionsRouteData.medicationLogAnalysisLimitPerPlan {
            context.insert(HumanMedicationLog(
                humanId: " \(human.id.uuidString.lowercased()) ",
                medicationId: " \(medication.id.uuidString.lowercased()) ",
                scheduledTime: now.addingTimeInterval(Double(-index)),
                status: .taken,
                recordedTime: now.addingTimeInterval(Double(-index))
            ))
        }
        let foreignLog = HumanMedicationLog(
            humanId: otherHuman.id.uuidString,
            medicationId: medication.id.uuidString,
            scheduledTime: now,
            status: .taken,
            recordedTime: now
        )
        context.insert(foreignLog)
        try context.save()

        let routeData = try HumanHealthConditionsRouteData.load(
            humanID: human.id,
            canViewMedication: true,
            now: now,
            context: context
        )

        #expect(routeData.medicationAnalysisIsIncomplete)
        #expect(routeData.medicationAnalysisIncompleteConditionIDs == [condition.id])
        #expect(routeData.medicationLogs.count == HumanHealthConditionsRouteData.medicationLogAnalysisLimitPerPlan)
        #expect(!routeData.medicationLogs.contains(where: { $0.id == foreignLog.id }))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV97.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
