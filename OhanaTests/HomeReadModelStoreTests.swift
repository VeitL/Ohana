import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct HomeReadModelStoreTests {
    @Test func cancelledDeferredRefreshDoesNotPublishPayload() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        container.mainContext.insert(Human(name: "Owner"))
        try container.mainContext.save()

        store.requestRefresh(
            context: container.mainContext,
            activeHumanIdRaw: "",
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: false
        )
        store.cancel()

        try await Task.sleep(nanoseconds: 90_000_000)

        #expect(store.payload.signature.isEmpty)
        #expect(store.payload.source.humans.isEmpty)
    }

    @Test func forcedRefreshPublishesPayloadSnapshot() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let human = Human(name: "Owner")
        container.mainContext.insert(human)
        try container.mainContext.save()

        await store.refreshImmediately(
            context: container.mainContext,
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        #expect(!store.payload.signature.isEmpty)
        #expect(store.payload.source.humans.map(\.id) == [human.id])
    }

    @Test func eventFetchKeepsTodayWindowWhenHistoryHasManyEndedRecurringEvents() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oldStart = calendar.date(byAdding: .year, value: -4, to: today) ?? today.addingTimeInterval(-4 * 365 * 24 * 60 * 60)
        let oldEnd = calendar.date(byAdding: .day, value: 30, to: oldStart) ?? oldStart.addingTimeInterval(30 * 24 * 60 * 60)
        for index in 0 ..< 450 {
            let event = Event(
                title: "Ended recurring \(index)",
                startDate: calendar.date(byAdding: .day, value: index, to: oldStart) ?? oldStart
            )
            event.recurrenceDays = 1
            event.recurrenceEndDate = oldEnd
            container.mainContext.insert(event)
        }
        let todayEvent = Event(title: "Today check", startDate: today.addingTimeInterval(9 * 60 * 60))
        container.mainContext.insert(todayEvent)
        try container.mainContext.save()

        await store.refreshImmediately(
            context: container.mainContext,
            activeHumanIdRaw: "",
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        #expect(store.payload.source.events.contains { $0.id == todayEvent.id })
        #expect(!store.payload.source.events.contains { $0.title.hasPrefix("Ended recurring") })
    }

    @Test func forcedRefreshPublishesAvatarPreloadSignature() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let human = Human(name: "Owner")
        human.avatarImageData = Data([0, 1, 2, 3, 4, 5, 6, 7])
        container.mainContext.insert(human)
        try container.mainContext.save()

        await store.refreshImmediately(
            context: container.mainContext,
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        #expect(store.payload.avatarPreloadSignature.contains(human.id.uuidString))
        #expect(store.payload.avatarPreloadSignature.contains("8-"))
        #expect(store.payload.avatarPreloadPayloads.map(\.id) == [human.id])
    }

    @Test func activeHumanHeaderAvatarPreloadsWhenHumanIsNotAHomeCard() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let human = Human(name: "Hidden Owner")
        let avatarData = Data([9, 8, 7, 6, 5, 4])
        human.avatarImageData = avatarData
        human.shouldShowOnHome = false
        container.mainContext.insert(human)
        try container.mainContext.save()

        await store.refreshImmediately(
            context: container.mainContext,
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        #expect(store.payload.snapshot.cards.isEmpty)
        #expect(store.payload.activeHumanAvatar.id == human.id)
        #expect(store.payload.activeHumanAvatar.signature == FocusWalletAvatarCache.signature(for: avatarData))
        #expect(store.payload.avatarPreloadPayloads.map(\.id) == [human.id])
    }

    @Test func actorPayloadMatchesMainThreadSnapshotBuilder() async throws {
        let container = try makeContainer()
        let human = Human(name: "Owner")
        let pet = Pet(name: "Mochi", species: "Cat")
        container.mainContext.insert(human)
        container.mainContext.insert(pet)
        try container.mainContext.save()

        let input = HomeReadModelActorInput(
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            petBondVaultRevision: 0,
            equippedTitleRaw: "",
            language: AppLanguage.code,
            loadPlants: true
        )

        let actor = HomeReadModelActor(modelContainer: container)
        let actorPayload = try #require(await actor.refreshPayload(
            input: input,
            previousSignature: "",
            currentRevision: HomeRevision(),
            externalRevision: HomeRevision(),
            force: true
        ))

        let source = VerticalSolidHomeSourceState(
            pets: [pet],
            humans: [human],
            plants: [],
            electronicPets: [],
            events: [],
            pendingReminders: [],
            humanMedications: [],
            humanMedicationLogs: [],
            careLogs: [],
            walkLogs: [],
            pottyLogs: [],
            humanWeightLogs: [],
            familyTasks: [],
            exchangeRequests: [],
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            petBondVaultRevision: 0,
            equippedTitleRaw: "",
            language: AppLanguage.code
        )
        let mainSnapshot = VerticalSolidHomeSnapshotBuilder.build(
            from: source,
            privacy: StaticHumanPrivacyManager(),
            todayFocus: StaticTodayFocusManager(),
            healthAlerts: SharedPetHealthAlertEngine()
        )

        #expect(actorPayload.signature == VerticalSolidHomeSnapshotBuilder.signature(for: source))
        #expect(actorPayload.snapshot.cards.map(\.id) == mainSnapshot.cards.map(\.id))
        #expect(actorPayload.snapshot.todayFocus.refreshedQuests.map(\.id) == mainSnapshot.todayFocus.refreshedQuests.map(\.id))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV60.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
