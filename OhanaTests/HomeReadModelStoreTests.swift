import Foundation
@testable import Ohana
import SwiftData
import Testing

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

        store.requestRefresh(
            context: container.mainContext,
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        let didPublish = try await waitUntil {
            !store.payload.signature.isEmpty &&
                store.payload.source.humans.map(\.id) == [human.id]
        }

        #expect(didPublish)
        #expect(!store.payload.signature.isEmpty)
        #expect(store.payload.source.humans.map(\.id) == [human.id])
    }

    @Test func forcedRefreshPublishesAvatarPreloadSignature() async throws {
        let container = try makeContainer()
        let store = HomeReadModelStore()
        let human = Human(name: "Owner")
        human.avatarImageData = Data([0, 1, 2, 3, 4, 5, 6, 7])
        container.mainContext.insert(human)
        try container.mainContext.save()

        store.requestRefresh(
            context: container.mainContext,
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        let didPreload = try await waitUntil {
            store.payload.avatarPreloadSignature.contains(human.id.uuidString) &&
                store.payload.avatarPreloadSignature.contains("8-") &&
                store.payload.avatarPreloadPayloads.map(\.id) == [human.id]
        }

        #expect(didPreload)
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

        store.requestRefresh(
            context: container.mainContext,
            activeHumanIdRaw: human.id.uuidString,
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            language: AppLanguage.code,
            externalRevision: HomeRevision(),
            force: true
        )

        let didPreload = try await waitUntil {
            store.payload.activeHumanAvatar.id == human.id &&
                store.payload.activeHumanAvatar.signature == FocusWalletAvatarCache.signature(for: avatarData) &&
                store.payload.avatarPreloadPayloads.map(\.id) == [human.id]
        }

        #expect(didPreload)
        #expect(store.payload.snapshot.cards.isEmpty)
        #expect(store.payload.activeHumanAvatar.id == human.id)
        #expect(store.payload.activeHumanAvatar.signature == FocusWalletAvatarCache.signature(for: avatarData))
        #expect(store.payload.avatarPreloadPayloads.map(\.id) == [human.id])
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV56.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func waitUntil(
        timeout: TimeInterval = 8,
        condition: () -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }
}
