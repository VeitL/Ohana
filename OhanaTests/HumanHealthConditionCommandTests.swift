import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanHealthConditionCommandTests {
    @Test func v97AddsOnlyConditionTrackingModelsAndRemainsLightweight() {
        let v96 = Set(ArkSchemaV96.models.map { String(describing: $0) })
        let v97 = Set(ArkSchemaV97.models.map { String(describing: $0) })

        #expect(v97.subtracting(v96) == [
            String(describing: HumanHealthCondition.self),
            String(describing: HumanHealthObservation.self)
        ])
        #expect(v96.subtracting(v97).isEmpty)
        #expect(ObjectIdentifier(ArkMigrationPlan.schemas.last!) == ObjectIdentifier(ArkSchemaV99.self))
        #expect(ArkMigrationPlan.stages.isEmpty)
    }

    @Test func v96StoreOpensOnV97AndPreservesExistingHuman() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaHumanHealthV97Migration-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let humanID = UUID()
        do {
            let schema = Schema(ArkSchemaV96.models)
            let configuration = ModelConfiguration(
                "HumanHealthV96Source",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let human = Human(name: "Existing Human")
            human.id = humanID
            container.mainContext.insert(human)
            try container.mainContext.save()
        }

        do {
            let schema = Schema(ArkSchemaV97.models)
            let configuration = ModelConfiguration(
                "HumanHealthV97Target",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ArkMigrationPlan.self,
                configurations: [configuration]
            )
            let humans = try container.mainContext.fetch(FetchDescriptor<Human>())

            #expect(humans.count == 1)
            #expect(humans.first?.id == humanID)
            #expect(humans.first?.name == "Existing Human")
            #expect(try container.mainContext.fetchCount(FetchDescriptor<HumanHealthCondition>()) == 0)
            #expect(try container.mainContext.fetchCount(FetchDescriptor<HumanHealthObservation>()) == 0)
        }
    }

    @Test func commandsValidateOwnershipAndCascadeConditionObservations() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let otherHuman = Human(name: "Morgan")
        let medication = HumanMedication(
            humanId: "  \(human.id.uuidString.lowercased())  ",
            name: "Levothyroxine"
        )
        let otherMedication = HumanMedication(humanId: otherHuman.id.uuidString, name: "Other")
        context.insert(human)
        context.insert(otherHuman)
        context.insert(medication)
        context.insert(otherMedication)
        try context.save()

        let created = HumanHealthConditionCommandService.createCondition(
            human: human,
            input: HumanHealthConditionCommandInput(
                name: " Thyroid follow-up ",
                category: .thyroid,
                startedOn: Date(timeIntervalSinceReferenceDate: 100),
                linkedMedicationIDs: [medication.id, otherMedication.id],
                linkedMetricKeys: ["tsh", "tsh", " "]
            ),
            context: context
        )
        #expect(created.didChange)

        let condition = try #require(
            try context.fetch(FetchDescriptor<HumanHealthCondition>()).first {
                $0.id == created.conditionID
            }
        )
        #expect(condition.name == "Thyroid follow-up")
        #expect(condition.category == .thyroid)
        #expect(condition.linkedMedicationIDs == [medication.id])
        #expect(condition.linkedMetricKeys == ["tsh"])

        let deniedForeignUpdate = HumanHealthConditionCommandService.updateCondition(
            condition,
            human: otherHuman,
            input: HumanHealthConditionCommandInput(name: "Wrong owner"),
            context: context
        )
        #expect(!deniedForeignUpdate.didChange)
        #expect(condition.name == "Thyroid follow-up")

        let updatedCondition = HumanHealthConditionCommandService.updateCondition(
            condition,
            human: human,
            input: HumanHealthConditionCommandInput(
                name: "Thyroid monitoring",
                category: .thyroid,
                trackingStatus: .monitoring,
                linkedMedicationIDs: [medication.id],
                linkedMetricKeys: ["tsh"]
            ),
            context: context
        )
        #expect(updatedCondition.didChange)
        #expect(condition.name == "Thyroid monitoring")
        #expect(condition.trackingStatus == .monitoring)

        let recorded = HumanHealthConditionCommandService.recordObservation(
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(
                recordedAt: Date(timeIntervalSinceReferenceDate: 200),
                severity: 6,
                moodScore: 7,
                sleepHours: 6.5,
                symptomTags: ["Fatigue", "Fatigue", " "],
                medicationResponse: .helpful
            ),
            context: context
        )
        #expect(recorded.didChange)

        let observation = try #require(
            try context.fetch(FetchDescriptor<HumanHealthObservation>()).first {
                $0.id == recorded.observationID
            }
        )
        #expect(observation.conditionId == condition.id.uuidString)
        #expect(observation.symptomTags == ["Fatigue"])
        #expect(observation.medicationResponse == .helpful)

        let invalidMood = HumanHealthConditionCommandService.updateObservation(
            observation,
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(severity: 4, moodScore: 0),
            context: context
        )
        #expect(!invalidMood.didChange)
        #expect(observation.severity == 6)

        let updatedObservation = HumanHealthConditionCommandService.updateObservation(
            observation,
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(
                recordedAt: observation.recordedAt,
                severity: 4,
                moodScore: 8,
                sleepHours: 7,
                symptomTags: ["Improving"],
                medicationResponse: .helpful
            ),
            context: context
        )
        #expect(updatedObservation.didChange)
        #expect(observation.severity == 4)
        #expect(observation.moodScore == 8)

        let secondObservation = HumanHealthConditionCommandService.recordObservation(
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(severity: 2),
            context: context
        )
        let second = try #require(
            try context.fetch(FetchDescriptor<HumanHealthObservation>()).first {
                $0.id == secondObservation.observationID
            }
        )
        let deletedObservation = HumanHealthConditionCommandService.deleteObservation(
            second,
            condition: condition,
            human: human,
            context: context
        )
        #expect(deletedObservation.didChange)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()) == 1)

        let deleted = HumanHealthConditionCommandService.deleteCondition(
            condition,
            human: human,
            context: context
        )
        #expect(deleted.didChange)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthCondition>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()) == 0)
    }

    @Test func conditionWritesFailClosedForMemorialHumans() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        human.passedAwayDate = Date(timeIntervalSinceReferenceDate: 1000)
        context.insert(human)
        try context.save()

        let result = HumanHealthConditionCommandService.createCondition(
            human: human,
            input: HumanHealthConditionCommandInput(name: "Must not persist"),
            context: context
        )

        #expect(!result.didChange)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthCondition>()) == 0)
    }

    @Test func routeDataDoesNotFetchMedicationWhenMedicationPrivacyIsLocked() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let medication = HumanMedication(humanId: human.id.uuidString, name: "Private medication")
        let condition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "Visible condition",
            linkedMedicationIDs: [medication.id]
        )
        let log = HumanMedicationLog(
            humanId: human.id.uuidString,
            medicationId: medication.id.uuidString,
            scheduledTime: Date(),
            status: .taken,
            recordedTime: Date()
        )
        context.insert(human)
        context.insert(medication)
        context.insert(condition)
        context.insert(log)
        try context.save()

        let data = try HumanHealthConditionsRouteData.load(
            humanID: human.id,
            canViewMedication: false,
            context: context
        )

        #expect(data.conditions.map(\.id) == [condition.id])
        #expect(data.medications.isEmpty)
        #expect(data.medicationLogs.isEmpty)

        let visibleData = try HumanHealthConditionsRouteData.load(
            humanID: human.id,
            canViewMedication: true,
            context: context
        )
        #expect(visibleData.medications.map(\.id) == [medication.id])
        #expect(visibleData.medicationLogs.map(\.id) == [log.id])
    }

    @Test func lockedMedicationFieldsArePreservedByNonMedicationEdits() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let medication = HumanMedication(humanId: human.id.uuidString, name: "Private medication")
        let condition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "Condition",
            linkedMedicationIDs: [medication.id]
        )
        let observation = HumanHealthObservation(
            humanId: human.id.uuidString,
            conditionId: condition.id.uuidString,
            severity: 6,
            medicationResponse: .helpful,
            sideEffects: "Private side effect"
        )
        context.insert(human)
        context.insert(medication)
        context.insert(condition)
        context.insert(observation)
        try context.save()

        let conditionResult = HumanHealthConditionCommandService.updateCondition(
            condition,
            human: human,
            input: HumanHealthConditionCommandInput(
                name: "Updated condition",
                linkedMedicationIDs: nil
            ),
            context: context
        )
        let observationResult = HumanHealthConditionCommandService.updateObservation(
            observation,
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(
                severity: 4,
                medicationResponse: nil,
                sideEffects: nil
            ),
            context: context
        )

        #expect(conditionResult.didChange)
        #expect(observationResult.didChange)
        #expect(condition.linkedMedicationIDs == [medication.id])
        #expect(observation.severity == 4)
        #expect(observation.medicationResponse == .helpful)
        #expect(observation.sideEffects == "Private side effect")
    }

    @Test func commandsRejectFutureConditionAndObservationDates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        context.insert(human)
        try context.save()

        let future = Date().addingTimeInterval(86400)
        let deniedCondition = HumanHealthConditionCommandService.createCondition(
            human: human,
            input: HumanHealthConditionCommandInput(
                name: "Future condition",
                startedOn: future
            ),
            context: context
        )
        #expect(!deniedCondition.didChange)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthCondition>()) == 0)

        let allowedCondition = HumanHealthConditionCommandService.createCondition(
            human: human,
            input: HumanHealthConditionCommandInput(
                name: "Current condition",
                startedOn: Date().addingTimeInterval(-86400)
            ),
            context: context
        )
        let condition = try #require(
            try context.fetch(FetchDescriptor<HumanHealthCondition>()).first {
                $0.id == allowedCondition.conditionID
            }
        )

        let deniedObservation = HumanHealthConditionCommandService.recordObservation(
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(recordedAt: future, severity: 5),
            context: context
        )
        #expect(!deniedObservation.didChange)
        #expect(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()) == 0)

        let allowedObservation = HumanHealthConditionCommandService.recordObservation(
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(
                recordedAt: Date().addingTimeInterval(-60),
                severity: 4
            ),
            context: context
        )
        let observation = try #require(
            try context.fetch(FetchDescriptor<HumanHealthObservation>()).first {
                $0.id == allowedObservation.observationID
            }
        )
        let deniedUpdate = HumanHealthConditionCommandService.updateObservation(
            observation,
            condition: condition,
            human: human,
            input: HumanHealthObservationCommandInput(recordedAt: future, severity: 9),
            context: context
        )
        #expect(!deniedUpdate.didChange)
        #expect(observation.severity == 4)
    }

    @Test func conditionDeletionNormalizesEveryChildReference() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let otherHuman = Human(name: "Morgan")
        let condition = HumanHealthCondition(humanId: human.id.uuidString, name: "Target")
        let retainedCondition = HumanHealthCondition(humanId: human.id.uuidString, name: "Retained")
        let targetIDs = [
            condition.id.uuidString,
            condition.id.uuidString.lowercased(),
            "  \(condition.id.uuidString.lowercased())  "
        ]
        let targetObservations = targetIDs.enumerated().map { index, rawConditionID in
            HumanHealthObservation(
                humanId: index == 2 ? otherHuman.id.uuidString : human.id.uuidString,
                conditionId: rawConditionID,
                severity: index + 1
            )
        }
        let retainedObservation = HumanHealthObservation(
            humanId: human.id.uuidString,
            conditionId: retainedCondition.id.uuidString,
            severity: 8
        )
        context.insert(human)
        context.insert(otherHuman)
        context.insert(condition)
        context.insert(retainedCondition)
        targetObservations.forEach(context.insert)
        context.insert(retainedObservation)
        try context.save()

        let result = HumanHealthConditionCommandService.deleteCondition(
            condition,
            human: human,
            context: context
        )

        #expect(result.didChange)
        let remaining = try context.fetch(FetchDescriptor<HumanHealthObservation>())
        #expect(remaining.map(\.id) == [retainedObservation.id])
        #expect(try context.fetch(FetchDescriptor<HumanHealthCondition>()).map(\.id) == [retainedCondition.id])
    }

    @Test func observationHistoryUsesStableBoundedPagesAcrossAllTime() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        let otherHuman = Human(name: "Morgan")
        let condition = HumanHealthCondition(humanId: human.id.uuidString, name: "Target")
        let otherCondition = HumanHealthCondition(humanId: human.id.uuidString, name: "Other")
        context.insert(human)
        context.insert(otherHuman)
        context.insert(condition)
        context.insert(otherCondition)

        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let expected = (0 ..< 95).map { index in
            HumanHealthObservation(
                humanId: human.id.uuidString,
                conditionId: index == 0 ? condition.id.uuidString.lowercased() : condition.id.uuidString,
                recordedAt: base,
                severity: index % 11,
                createdAt: base
            )
        }
        expected.forEach(context.insert)
        context.insert(HumanHealthObservation(
            humanId: human.id.uuidString,
            conditionId: otherCondition.id.uuidString,
            recordedAt: base,
            severity: 3
        ))
        context.insert(HumanHealthObservation(
            humanId: otherHuman.id.uuidString,
            conditionId: condition.id.uuidString,
            recordedAt: base,
            severity: 4
        ))
        try context.save()

        var cursor: HumanHealthHistoryPageCursor?
        var pages: [[HumanHealthObservation]] = []
        repeat {
            let page = try HumanHealthObservationHistoryQuery.page(
                humanID: human.id,
                conditionID: condition.id,
                olderThan: cursor,
                limit: 40,
                context: context
            )
            pages.append(page.records)
            cursor = page.nextCursor
            if !page.hasOlder { break }
        } while true

        #expect(pages.map(\.count) == [40, 40, 15])
        let returnedIDs = pages.flatMap(\.self).map(\.id)
        #expect(returnedIDs.count == 95)
        #expect(Set(returnedIDs).count == 95)
        #expect(Set(returnedIDs) == Set(expected.map(\.id)))
        #expect(pages.flatMap(\.self).allSatisfy {
            UUID(uuidString: $0.humanId) == human.id && UUID(uuidString: $0.conditionId) == condition.id
        })
    }

    @Test func conditionHistoryPagesKeepEveryConditionAccessible() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Avery")
        context.insert(human)
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        var conditions: [HumanHealthCondition] = []
        for index in 0 ..< 70 {
            let humanID = index == 69
                ? human.id.uuidString.lowercased()
                : human.id.uuidString
            let timestamp = base.addingTimeInterval(Double(-index))
            conditions.append(HumanHealthCondition(
                humanId: humanID,
                name: "Condition \(index)",
                createdAt: timestamp,
                updatedAt: timestamp
            ))
        }
        for condition in conditions {
            context.insert(condition)
        }
        try context.save()

        let first = try HumanHealthConditionHistoryQuery.page(
            humanID: human.id,
            context: context
        )
        let second = try HumanHealthConditionHistoryQuery.page(
            humanID: human.id,
            olderThan: first.nextCursor,
            context: context
        )
        let routeData = try HumanHealthConditionsRouteData.load(
            humanID: human.id,
            canViewMedication: false,
            now: base,
            context: context
        )

        #expect(first.records.count == 64)
        #expect(first.hasOlder)
        #expect(second.records.count == 6)
        #expect(!second.hasOlder)
        #expect(Set(first.records.map(\.id)).isDisjoint(with: Set(second.records.map(\.id))))
        let returnedIDs = Set(first.records.map(\.id) + second.records.map(\.id))
        let expectedIDs = Set(conditions.map(\.id))
        #expect(returnedIDs == expectedIDs)
        #expect(routeData.activeConditionCount == 70)
        #expect(routeData.conditions.count == HumanHealthConditionsRouteData.conditionPageSize)
        #expect(routeData.hasOlderConditions)
    }

    @Test func physicalHumanDeletionRemovesOwnedTrackingAndScrubsRetainedAttribution() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recorder = Human(name: "Recorder")
        let subject = Human(name: "Subject")
        context.insert(recorder)
        context.insert(subject)

        let ownedCondition = HumanHealthCondition(
            humanId: recorder.id.uuidString,
            name: "Owned",
            recordedByHumanId: recorder.id.uuidString
        )
        let ownedObservation = HumanHealthObservation(
            humanId: recorder.id.uuidString,
            conditionId: ownedCondition.id.uuidString,
            severity: 3,
            recordedByHumanId: recorder.id.uuidString
        )
        let mismatchedOwnedObservation = HumanHealthObservation(
            humanId: subject.id.uuidString,
            conditionId: " \(ownedCondition.id.uuidString.lowercased()) ",
            severity: 4,
            recordedByHumanId: subject.id.uuidString
        )
        let retainedCondition = HumanHealthCondition(
            humanId: subject.id.uuidString,
            name: "Retained",
            recordedByHumanId: recorder.id.uuidString
        )
        let retainedObservation = HumanHealthObservation(
            humanId: subject.id.uuidString,
            conditionId: retainedCondition.id.uuidString,
            severity: 2,
            recordedByHumanId: recorder.id.uuidString
        )
        context.insert(ownedCondition)
        context.insert(ownedObservation)
        context.insert(mismatchedOwnedObservation)
        context.insert(retainedCondition)
        context.insert(retainedObservation)
        try context.save()

        _ = PhysicalDeletionService.deleteHuman(recorder, context: context)
        try context.save()

        let conditions = try context.fetch(FetchDescriptor<HumanHealthCondition>())
        let observations = try context.fetch(FetchDescriptor<HumanHealthObservation>())
        #expect(conditions.map(\.id) == [retainedCondition.id])
        #expect(observations.map(\.id) == [retainedObservation.id])
        #expect(conditions.first?.recordedByHumanId == nil)
        #expect(observations.first?.recordedByHumanId == nil)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV97.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
