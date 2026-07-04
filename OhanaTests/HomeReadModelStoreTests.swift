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
        #expect(store.payload.interaction.humansByID.isEmpty)
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
        #expect(Set(store.payload.interaction.humansByID.keys) == [human.id])
        #expect(store.payload.interaction.activeHuman?.id == human.id)
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

        #expect(store.payload.interaction.eventRoutesByEventID[todayEvent.id] != nil)
        #expect(store.payload.interaction.eventRoutesByEventID.count == 1)
    }

    @Test func forcedRefreshPublishesAvatarPreloadSignature() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let human = Human(name: "Owner")
        human.updateAvatarImageData(Data([0, 1, 2, 3, 4, 5, 6, 7]))
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
        #expect(store.payload.mediaPreloadRequests.map(\.id) == [human.id])
        #expect(store.payload.mediaPreloadRequests.first?.source == .human)
        #expect(store.payload.avatarPreloadPayloads.isEmpty)
    }

    @Test func forcedRefreshProjectsPetPhotoLogsIntoMomentInteractionState() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let pet = Pet(name: "Mochi", species: "Cat")
        let photo = PetPhotoLog(imageData: Data([1, 2, 3]), date: Date(), pet: pet)
        container.mainContext.insert(pet)
        container.mainContext.insert(photo)
        try container.mainContext.save()

        await store.refreshImmediately(
            context: container.mainContext,
            activeHumanIdRaw: "",
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            quickActionItemsRaw: "",
            language: "zh",
            externalRevision: HomeRevision(),
            force: true
        )

        let item = QuickActionItem(
            label: "记录",
            icon: "camera.circle.fill",
            colorHex: "FF6B9D",
            petId: pet.id,
            actionType: "moment",
            entityId: pet.id,
            entityKind: .pet
        )
        let state = store.payload.interaction.expandedActions(for: pet.id).state(for: item)

        #expect(state.status == "今天 1 条")
        #expect(store.payload.signature.contains(photo.id.uuidString))
    }

    @Test func activeHumanHeaderAvatarPreloadsWhenHumanIsNotAHomeCard() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let human = Human(name: "Hidden Owner")
        let avatarData = Data([9, 8, 7, 6, 5, 4])
        human.updateAvatarImageData(avatarData)
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
        #expect(store.payload.mediaPreloadRequests.map(\.id) == [human.id])
        #expect(store.payload.avatarPreloadPayloads.isEmpty)
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
            quickActionItemsRaw: "",
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
            healthAlertSources: PetHealthAlertSourceRouteData.load(pets: [pet], from: container.mainContext),
            todayFocusCareLedgerEntries: [],
            feedingLedgerEntries: [],
            careLedgerEntries: [],
            walkLedgerEntries: [],
            pottyLedgerEntries: [],
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
        #expect(actorPayload.interaction.petsByID[pet.id]?.id == pet.id)
        #expect(actorPayload.interaction.humansByID[human.id]?.id == human.id)
        #expect(actorPayload.snapshot.todayFocus.refreshedQuests.map(\.id) == mainSnapshot.todayFocus.refreshedQuests.map(\.id))
    }

    @Test func storeSourceDoesNotReintroduceMainContextCompatibilityFetch() throws {
        let file = try sourceFile(named: "HomeReadModelStore.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        let builderFile = try sourceFile(named: "VerticalSolidHomeSnapshotBuilder.swift")
        let builderSource = try String(contentsOf: builderFile, encoding: .utf8)
        let interactionFile = try sourceFile(named: "HomeInteractionSnapshot.swift")
        let interactionSource = try String(contentsOf: interactionFile, encoding: .utf8)
        let renderStateFile = try sourceFile(named: "HomeQuickActionRenderStateLogic.swift")
        let renderStateSource = try String(contentsOf: renderStateFile, encoding: .utf8)

        #expect(!source.contains("compatibilitySource"))
        #expect(!source.contains("payload.source"))
        #expect(!source.contains("container.mainContext"))
        #expect(source.contains("let healthAlertSources = fetches.healthAlertSources(pets: pets)"))
        #expect(source.contains("PetHealthAlertSourceRouteData.load(pets: pets, from: context)"))
        #expect(builderSource.contains("let healthAlertSources: [PetHealthAlertSource]"))
        #expect(builderSource.contains("scanAlerts(sources: source.healthAlertSources)"))
        #expect(!builderSource.contains("scanAlerts(pets: source.pets"))
        #expect(interactionSource.contains("HomeQuickActionRenderStateLogic.petRenderState("))
        #expect(interactionSource.contains("HomeQuickActionRenderStateLogic.humanRenderState("))
        #expect(!interactionSource.contains("ExpandedQuickActionLogic.countText("))
        #expect(!interactionSource.contains("ExpandedQuickActionLogic.isCompleted("))
        #expect(!interactionSource.contains("ExpandedQuickActionLogic.showsAttentionDot("))
        #expect(!interactionSource.contains("PrivacyService.isHumanQuickActionLocked("))
        #expect(renderStateSource.contains("nonisolated enum HomeQuickActionRenderStateLogic"))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func sourceFile(named fileName: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.lastPathComponent != "OhanaTests" {
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        let repoRoot = directory.deletingLastPathComponent()
        let file = repoRoot
            .appendingPathComponent("Ohana")
            .appendingPathComponent("Features")
            .appendingPathComponent("Home")
            .appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: file.path))
        return file
    }
}
