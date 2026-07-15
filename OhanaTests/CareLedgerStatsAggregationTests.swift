import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct CareLedgerStatsAggregationTests {
    @Test func sharedPetCoverageCountsAsOneWorkloadAndTwoCoveredObjects() throws {
        let human = Human(name: "Guan")
        let firstPet = Pet(name: "Miso", species: "cat")
        let secondPet = Pet(name: "Momo", species: "cat")
        let occurredAt = Date(timeIntervalSinceReferenceDate: 10000)
        let interval = DateInterval(
            start: occurredAt.addingTimeInterval(-60),
            end: occurredAt.addingTimeInterval(60)
        )
        let sessionID = UUID().uuidString
        let metadata = CareLedgerMetadata.addingString(
            CareLedgerMetadata.sharedSessionId,
            value: sessionID,
            to: ""
        )
        let events = [firstPet, secondPet].enumerated().map { index, pet in
            CareLedgerEvent(
                occurredAt: occurredAt,
                actorKind: .human,
                actorId: human.id.uuidString,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .care,
                actionType: CareType.litter.rawValue,
                coconutDelta: index == 0 ? 3 : 0,
                metadataJSON: metadata
            )
        }
        let service = CareLedgerStatsService()

        let entries = service.reportEntries(
            events: events,
            pets: [firstPet, secondPet],
            humans: [human],
            interval: interval,
            l: L10n("en")
        )
        let totals = service.totals(
            events: events,
            pets: [firstPet, secondPet],
            interval: interval
        )
        let entry = try #require(entries.first)

        #expect(entries.count == 1)
        #expect(entry.operationIdentity == "shared:\(sessionID.lowercased())")
        #expect(entry.coverageCount == 2)
        #expect(Set(entry.subjectCoverages.map(\.id)) == Set([firstPet.id.uuidString, secondPet.id.uuidString]))
        #expect(entry.participantActorIds == [human.id.uuidString])
        #expect(entry.coconuts == 3)
        #expect(totals.workloadCount == 1)
        #expect(totals.coverageCount == 2)
        #expect(totals.petCoverageCount == 2)
        #expect(totals.plantCoverageCount == 0)
    }

    @Test func plantBatchCoverageEntersWeeklyReportAndMemberContributionOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Alex")
        let firstPlant = Plant(name: "Fern", species: "fern")
        let secondPlant = Plant(name: "Pothos", species: "pothos")
        let now = Date(timeIntervalSinceReferenceDate: 20000)
        let transactionID = UUID().uuidString
        let firstLog = PlantCareLog(
            date: now,
            careType: .watering,
            executorId: human.id.uuidString,
            careTransactionId: transactionID
        )
        let secondLog = PlantCareLog(
            date: now,
            careType: .watering,
            executorId: human.id.uuidString,
            careTransactionId: transactionID
        )
        firstLog.plant = firstPlant
        secondLog.plant = secondPlant
        let metadata = CareLedgerMetadata.addingString(
            CareLedgerMetadata.careTransactionId,
            value: transactionID,
            to: ""
        )
        let firstLedger = plantLedger(
            log: firstLog,
            plant: firstPlant,
            human: human,
            metadata: metadata
        )
        let secondLedger = plantLedger(
            log: secondLog,
            plant: secondPlant,
            human: human,
            metadata: metadata
        )

        context.insert(human)
        context.insert(firstPlant)
        context.insert(secondPlant)
        context.insert(firstLog)
        context.insert(secondLog)
        context.insert(firstLedger)
        context.insert(secondLedger)
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let snapshot = FamilyWeeklyReportRouteSnapshot.load(
            from: context,
            languageCode: "en",
            now: now,
            calendar: calendar
        )
        let entry = try #require(snapshot.entries.first)
        let member = try #require(snapshot.rankedMembers.first)

        #expect(snapshot.entries.count == 1)
        #expect(snapshot.workloadCount == 1)
        #expect(snapshot.coverageCount == 2)
        #expect(snapshot.petCoverageCount == 0)
        #expect(snapshot.plantCoverageCount == 2)
        #expect(entry.coverageCount == 2)
        let allCoveragesArePlants = entry.subjectCoverages.allSatisfy(\.isPlant)
        #expect(allCoveragesArePlants)
        #expect(entry.actorId == human.id.uuidString)
        #expect(member.id == human.id.uuidString)
        #expect(member.count == 1)
        #expect(snapshot.topPet?.name == nil)
    }

    private func plantLedger(
        log: PlantCareLog,
        plant: Plant,
        human: Human,
        metadata: String
    ) -> CareLedgerEvent {
        CareLedgerEvent(
            occurredAt: log.date,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: log.careTypeRaw,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString,
            metadataJSON: metadata
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV91.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
