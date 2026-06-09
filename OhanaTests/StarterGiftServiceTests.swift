import Foundation
import SwiftData
@testable import Ohana
import Testing

@MainActor
struct StarterGiftServiceTests {
    @Test func freshInstallMarksGiftPendingUntilHumanExists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: nil,
            context: context,
            defaults: defaults
        )

        #expect(result == .pendingHuman)
        #expect(defaults.bool(forKey: StarterGiftService.Key.pending))
        #expect(!defaults.bool(forKey: StarterGiftService.Key.claimed))
    }

    @Test func pendingGiftClaimsOnceForFirstHuman() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        let oldCount = QuestManager.shared.coconutCount
        let oldLogs = QuestManager.shared.coconutLogs
        defer {
            QuestManager.shared.coconutCount = oldCount
            QuestManager.shared.coconutLogs = oldLogs
            QuestManager.shared.flushToDefaults()
            defaults.removePersistentDomain(forName: suiteName)
        }

        _ = StarterGiftService.prepareOrClaim(activeHumanID: nil, context: context, defaults: defaults)

        let human = Human(name: "Guan")
        context.insert(human)
        context.safeSave()
        QuestManager.shared.coconutCount = 0
        QuestManager.shared.coconutLogs = []

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )

        #expect(result == .claimed(humanID: human.id, amount: StarterGiftService.giftAmount))
        #expect(human.coconutBalance == StarterGiftService.giftAmount)
        #expect(QuestManager.shared.coconutCount == StarterGiftService.giftAmount)
        #expect(defaults.bool(forKey: StarterGiftService.Key.claimed))
        #expect(!defaults.bool(forKey: StarterGiftService.Key.pending))

        let ledger = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        #expect(ledger.count == 1)
        #expect(ledger.first?.actionType == "starterGift")
        #expect(ledger.first?.coconutDelta == StarterGiftService.giftAmount)
        #expect(ledger.first?.metadataJSON.contains("\"growthXP\":0") == true)
    }

    @Test func existingUserIsMarkedHandledWithoutGift() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let suiteName = makeDefaultsSuiteName()
        let defaults = try makeDefaults(suiteName: suiteName)
        let human = Human(name: "Existing")
        let pet = Pet(name: "Momo", species: "cat")
        context.insert(human)
        context.insert(pet)
        context.safeSave()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: human.id.uuidString,
            context: context,
            defaults: defaults
        )

        #expect(result == .markedExistingUser)
        #expect(defaults.bool(forKey: StarterGiftService.Key.claimed))
        #expect(defaults.bool(forKey: StarterGiftService.Key.ceremonySeen))
        #expect(human.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    private func makeDefaultsSuiteName() -> String {
        "StarterGiftServiceTests.\(UUID().uuidString)"
    }

    private func makeDefaults(suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV56.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
