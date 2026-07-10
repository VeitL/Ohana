import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct StartupMaintenanceBatchWorkersTests {
    @Test func memberThemeBatchUsesCursorAndPersistsOnlyItsPage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstPet = Pet(name: "Momo", species: "猫")
        firstPet.themeColorHex = OhanaThemeColorPolicy.darkPrimaryHex
        let secondPet = Pet(name: "Nori", species: "狗")
        secondPet.themeColorHex = "00AA88"
        let human = Human(name: "Guan")
        human.themeColorHex = OhanaThemeColorPolicy.lightPrimaryHex
        context.insert(firstPet)
        context.insert(secondPet)
        context.insert(human)
        try context.save()

        let actor = MemberThemeColorMaintenanceActor(modelContainer: container)
        let first = try await actor.runBatch(
            cursor: .initial,
            maximumRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(first.scannedRecordCount == 2)
        #expect(first.normalizedRecordCount == 1)
        #expect(first.nextCursor.source == .pet)
        #expect(first.nextCursor.offset == 2)
        #expect(!first.didComplete)

        let second = try await actor.runBatch(
            cursor: first.nextCursor,
            maximumRecordCount: 2,
            deadline: .distantFuture
        )
        #expect(second.normalizedRecordCount == 1)
        #expect(second.didComplete)

        let verification = ModelContext(container)
        let pets = try verification.fetch(FetchDescriptor<Pet>())
        let humans = try verification.fetch(FetchDescriptor<Human>())
        #expect(pets.first { $0.id == firstPet.id }?.themeColorHex == OhanaThemeColorPolicy.petFallbackHex)
        #expect(pets.first { $0.id == secondPet.id }?.themeColorHex == "00AA88")
        #expect(humans.first { $0.id == human.id }?.themeColorHex == OhanaThemeColorPolicy.humanFallbackHex)
    }

    @Test func autoFeederBatchPersistsOneBoundedPetPageWithoutDuplicates() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(year: 2026, month: 5, day: 8, hour: 21)
        let pet = Pet(name: "Momo", species: "猫")
        let event = Event(
            title: "自动喂食器",
            startDate: date(year: 2026, month: 5, day: 7, hour: 8),
            eventType: EventType.foodChange.rawValue,
            relatedEntityType: FeedRuleMetadata.autoFeederEntityType,
            relatedEntityId: pet.id.uuidString
        )
        event.recurrenceDays = 1
        event.feedRuleKindRaw = FeedRuleKind.autoFeeder.rawValue
        event.feedAmountGrams = 35
        context.insert(pet)
        context.insert(event)
        try context.save()

        let actor = StartupAutoFeederMaintenanceActor(modelContainer: container)
        let first = try await actor.runBatch(
            cursor: .initial,
            maximumPetCount: 1,
            deadline: .distantFuture,
            now: now,
            calendar: calendar
        )
        #expect(first.processedPetCount == 1)
        #expect(first.insertedLogCount == 2)
        #expect(!first.didComplete)

        let second = try await actor.runBatch(
            cursor: first.nextCursor,
            maximumPetCount: 1,
            deadline: .distantFuture,
            now: now,
            calendar: calendar
        )
        #expect(second.didComplete)

        let verification = ModelContext(container)
        let logs = try verification.fetch(FetchDescriptor<PetCareLog>())
        let ledger = try verification.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.autoFeedDedupKey.isEmpty == false })
        #expect(ledger.count(where: { $0.sourceEventId == event.id.uuidString }) == 2)
    }

    @Test func shopLegacyMigrationPersistsCursorOnlyAfterEachAtomicPage() async throws {
        let container = try makeContainer()
        let actor = StartupShopPurchaseMigrationActor(modelContainer: container)
        let itemIDs = ["fx_lime_glow", "title_guardian"]

        let first = try await actor.runBatch(
            eligibleItemIDs: itemIDs,
            cursor: .initial,
            maximumItemCount: 1,
            deadline: .distantFuture,
            now: Date(timeIntervalSinceReferenceDate: 42)
        )
        #expect(first.processedItemCount == 1)
        #expect(first.insertedRecordCount == 1)
        #expect(first.nextCursor.itemOffset == 1)
        #expect(!first.didComplete)

        let second = try await actor.runBatch(
            eligibleItemIDs: itemIDs,
            cursor: first.nextCursor,
            maximumItemCount: 1,
            deadline: .distantFuture,
            now: Date(timeIntervalSinceReferenceDate: 43)
        )
        #expect(second.didComplete)
        #expect(second.insertedRecordCount == 1)

        let records = try ModelContext(container).fetch(FetchDescriptor<ShopPurchaseRecord>())
        #expect(Set(records.map(\.itemId)) == Set(itemIDs))
        #expect(records.allSatisfy { record in record.isLegacyImport })
    }

    @Test func sharedCareLegacyCleanupPagesSourcesAndSetsCompletionCursor() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = Pet(name: "Momo", species: "猫")
        let session = SharedCareSession(
            actionKind: .feeding,
            sourcePetId: pet.id.uuidString,
            targetPetIds: [pet.id.uuidString]
        )
        session.note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.feedNotePrefix,
            sessionId: session.id,
            targetCount: 1,
            visibleNote: "Dinner"
        )
        let log = PetCareLog(
            date: Date(timeIntervalSinceReferenceDate: 200),
            type: .feeding,
            amountGrams: 40,
            note: SharedCareMetadata.legacyEncodedNote(
                prefix: SharedCareMetadata.feedNotePrefix,
                sessionId: session.id,
                targetCount: 1,
                visibleNote: "Meal"
            ),
            sharedSessionId: session.id.uuidString,
            pet: pet
        )
        context.insert(pet)
        context.insert(session)
        context.insert(log)
        try context.save()

        let actor = SharedCareLegacyNoteMaintenanceActor(modelContainer: container)
        var cursor = SharedCareLegacyNoteCleanupCursor.initial
        var final: SharedCareLegacyNoteCleanupBatchResult?
        for _ in 0 ..< 12 {
            let result = try await actor.runBatch(
                cursor: cursor,
                maximumRecordCount: 1,
                deadline: .distantFuture,
                cleanedAt: Date(timeIntervalSinceReferenceDate: 300)
            )
            if result.didComplete {
                final = result
                break
            }
            cursor = result.nextCursor
        }
        #expect(final?.didComplete == true)

        let verification = ModelContext(container)
        let storedSession = try #require(try verification.fetch(FetchDescriptor<SharedCareSession>()).first)
        let storedLog = try #require(try verification.fetch(FetchDescriptor<PetCareLog>()).first)
        #expect(storedSession.note == "Dinner")
        #expect(storedLog.note == "Meal")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV85.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
