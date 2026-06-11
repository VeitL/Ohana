import SwiftData
import XCTest
@testable import Ohana

@MainActor
final class CoconutWalletServiceTests: XCTestCase {
    func testCurrentSchemaCreatesInMemoryContainerAndKeepsLightweightStagesEmpty() throws {
        let container = try makeContainer()
        _ = ModelContext(container)

        let schemaNames = ArkMigrationPlan.schemas.map { String(describing: $0) }
        XCTAssertTrue(schemaNames.contains("ArkSchemaV64"))
        XCTAssertTrue(ArkMigrationPlan.stages.isEmpty)
    }

    func testBootstrapCreatesAccountsAndImportsLegacyHistoryWithoutDoubleCounting() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let human = Human(name: "Guan")
        human.coconutBalance = 10
        let pet = Pet(name: "Miso")
        pet.coconutBalance = 5
        context.insert(human)
        context.insert(pet)
        try context.save()

        let legacyLog = CoconutLogEntry(
            emoji: "🥥",
            title: "Legacy reward",
            amount: 7,
            actorId: human.id.uuidString,
            actorName: human.name
        )
        defaults.set(20, forKey: "quest_coconutCount")
        try defaults.set(JSONEncoder().encode([legacyLog]), forKey: "quest_coconutLogs")

        try CoconutEconomyBootstrapService.bootstrapIfNeeded(context: context, defaults: defaults)

        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        XCTAssertEqual(accounts.count, 3)
        XCTAssertEqual(accounts.reduce(0) { $0 + $1.balance }, 20)
        XCTAssertEqual(accounts.first { $0.accountKey == CoconutAccountKey.human(human.id) }?.balance, 10)
        XCTAssertEqual(accounts.first { $0.accountKey == CoconutAccountKey.pet(pet.id) }?.balance, 5)
        XCTAssertEqual(accounts.first { $0.accountKey == CoconutAccountKey.legacySystem }?.balance, 5)

        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        let legacyHistory = entries.filter { $0.entryKind == .legacyHistory }
        XCTAssertEqual(legacyHistory.count, 1)
        XCTAssertFalse(try XCTUnwrap(legacyHistory.first).affectsBalance)
        XCTAssertEqual(entries.filter(\.affectsBalance).reduce(0) { $0 + $1.delta }, 20)
    }

    func testBootstrapPreservesMemberBalancesWhenLegacyIslandCountIsLower() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let human = Human(name: "Guan")
        human.coconutBalance = 30
        context.insert(human)
        try context.save()
        defaults.set(10, forKey: "quest_coconutCount")

        try CoconutEconomyBootstrapService.bootstrapIfNeeded(context: context, defaults: defaults)

        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        XCTAssertEqual(accounts.reduce(0) { $0 + $1.balance }, 30)
        let system = try XCTUnwrap(accounts.first { $0.accountKey == CoconutAccountKey.legacySystem })
        XCTAssertEqual(system.balance, 0)
        XCTAssertTrue(system.metadataJSON.contains("\"mismatch\":true"))
    }

    func testWalletApplyWritesAccountsLedgerAndPreventsNegativeBalances() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let payer = Human(name: "Payer")
        payer.coconutBalance = 20
        let receiver = Human(name: "Receiver")
        receiver.coconutBalance = 1
        context.insert(payer)
        context.insert(receiver)
        try context.save()

        try CoconutWalletService.apply(
            deltas: [
                .human(
                    payer,
                    delta: -8,
                    entryKind: .transferOut,
                    source: .service,
                    title: "Transfer out",
                    transactionKey: "test-transfer-out"
                ),
                .human(
                    receiver,
                    delta: 8,
                    entryKind: .transferIn,
                    source: .service,
                    title: "Transfer in",
                    transactionKey: "test-transfer-in"
                )
            ],
            context: context,
            save: true,
            postsRewardFeedback: false
        )

        XCTAssertEqual(payer.coconutBalance, 12)
        XCTAssertEqual(receiver.coconutBalance, 9)
        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        XCTAssertEqual(accounts.reduce(0) { $0 + $1.balance }, 21)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count, 2)

        XCTAssertThrowsError(
            try CoconutWalletService.apply(
                deltas: [
                    .human(
                        payer,
                        delta: -99,
                        entryKind: .spend,
                        source: .service,
                        title: "Too much",
                        transactionKey: "test-too-much"
                    )
                ],
                context: context,
                save: true,
                postsRewardFeedback: false
            )
        )
        XCTAssertEqual(payer.coconutBalance, 12)
    }

    func testWalletApplyRejectsDuplicateKeysInsideSameBatch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Payer")
        human.coconutBalance = 20
        context.insert(human)
        try context.save()

        XCTAssertThrowsError(
            try CoconutWalletService.apply(
                deltas: [
                    .human(
                        human,
                        delta: -1,
                        entryKind: .spend,
                        source: .service,
                        title: "Duplicate A",
                        transactionKey: "same-batch-key"
                    ),
                    .human(
                        human,
                        delta: -1,
                        entryKind: .spend,
                        source: .service,
                        title: "Duplicate B",
                        transactionKey: "same-batch-key"
                    )
                ],
                context: context,
                save: true,
                postsRewardFeedback: false
            )
        ) { error in
            guard case let CoconutWalletError.duplicateTransaction(key) = error else {
                return XCTFail("Expected duplicateTransaction, got \(error)")
            }
            XCTAssertEqual(key, "same-batch-key")
        }

        XCTAssertEqual(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).count, 0)
        XCTAssertEqual(CoconutWalletService.balance(for: human, context: context), 20)
    }

    func testWalletApplyRejectsPartiallyDuplicateBatch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Payer")
        human.coconutBalance = 20
        context.insert(human)
        try context.save()

        try CoconutWalletService.apply(
            deltas: [
                .human(
                    human,
                    delta: -2,
                    entryKind: .spend,
                    source: .service,
                    title: "Existing",
                    transactionKey: "existing-key"
                )
            ],
            context: context,
            save: true,
            postsRewardFeedback: false
        )

        XCTAssertThrowsError(
            try CoconutWalletService.apply(
                deltas: [
                    .human(
                        human,
                        delta: -2,
                        entryKind: .spend,
                        source: .service,
                        title: "Existing replay",
                        transactionKey: "existing-key"
                    ),
                    .human(
                        human,
                        delta: -3,
                        entryKind: .spend,
                        source: .service,
                        title: "New skipped before fix",
                        transactionKey: "new-key"
                    )
                ],
                context: context,
                save: true,
                postsRewardFeedback: false
            )
        ) { error in
            guard case let CoconutWalletError.duplicateTransaction(key) = error else {
                return XCTFail("Expected duplicateTransaction, got \(error)")
            }
            XCTAssertEqual(key, "existing-key")
        }

        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(CoconutWalletService.balance(for: human, context: context), 18)
    }

    private var defaultsSuiteName: String {
        "CoconutWalletServiceTests"
    }

    private func makeDefaults() throws -> UserDefaults {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
