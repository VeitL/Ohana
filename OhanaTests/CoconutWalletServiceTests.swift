import SwiftData
import XCTest
@testable import Ohana

@MainActor
final class CoconutWalletServiceTests: XCTestCase {
    private static var processRetainedObjects: [AnyObject] = []

    @discardableResult
    private func retainUntilProcessExit<T: AnyObject>(_ object: T) -> T {
        Self.processRetainedObjects.append(object)
        return object
    }

    func testCurrentSchemaCreatesInMemoryContainerAndKeepsLightweightStagesEmpty() throws {
        let container = try makeContainer()
        _ = ModelContext(container)

        let schemaNames = ArkMigrationPlan.schemas.map { String(describing: $0) }
        XCTAssertTrue(schemaNames.contains("ArkSchemaV70"))
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

    func testFormalIslandTotalExcludesLegacySystemCompatibilityBalance() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let human = Human(name: "Guan")
        human.coconutBalance = 10
        let pet = Pet(name: "Miso")
        pet.coconutBalance = 5
        let projection = retainUntilProcessExit(QuestManager())
        context.insert(human)
        context.insert(pet)
        try context.save()
        defaults.set(20, forKey: "quest_coconutCount")

        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            defaults: defaults,
            projectionManager: projection
        )

        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        XCTAssertEqual(accounts.reduce(0) { $0 + $1.balance }, 20)
        XCTAssertEqual(accounts.first { $0.accountKey == CoconutAccountKey.legacySystem }?.balance, 5)
        XCTAssertEqual(CoconutWalletService.totalBalance(context: context), 15)
        XCTAssertEqual(projection.coconutCount, 15)
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

    func testRefreshProjectionRepairsDriftedFormalAccountFromLedgerReplay() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Guan")
        context.insert(human)
        try context.save()

        try CoconutWalletService.apply(
            deltas: [
                .human(
                    human,
                    delta: 12,
                    entryKind: .openingBalance,
                    source: .service,
                    title: "Opening",
                    transactionKey: "test-drift-opening"
                ),
                .human(
                    human,
                    delta: -4,
                    entryKind: .spend,
                    source: .shop,
                    title: "Spend",
                    transactionKey: "test-drift-spend"
                )
            ],
            context: context,
            save: true,
            postsRewardFeedback: false,
            updatesProjection: false
        )

        let accountKey = CoconutAccountKey.human(human.id)
        let account = try XCTUnwrap(fetchAccount(accountKey: accountKey, context: context))
        account.balance = 99
        human.coconutBalance = 99
        try context.save()

        let projection = retainUntilProcessExit(QuestManager())
        CoconutWalletService.refreshQuestProjection(context: context, manager: projection)

        XCTAssertEqual(account.balance, 8)
        XCTAssertEqual(human.coconutBalance, 8)
        XCTAssertEqual(CoconutWalletService.totalBalance(context: context), 8)
        XCTAssertEqual(projection.coconutCount, 8)
    }

    func testWealthTotalsAndLeaderboardExcludeLegacySystemAccount() {
        let human = Human(name: "Guan")
        let pet = Pet(name: "Miso")
        let model = retainUntilProcessExit(IslandWealthScreenModel())
        let humanAccount = CoconutAccount(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            displayName: human.name,
            balance: 10
        )
        let petAccount = CoconutAccount(
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            displayName: pet.name,
            balance: 5
        )
        let legacySystemAccount = CoconutAccount(
            accountKey: CoconutAccountKey.legacySystem,
            ownerKind: .system,
            ownerId: "",
            displayName: "Legacy island total",
            balance: 99
        )

        model.applyQuerySnapshot(
            pets: [pet],
            visibleHumans: [human],
            hiddenHumanIds: [],
            walletAccounts: [humanAccount, petAccount, legacySystemAccount],
            walletLedgerEntries: [],
            petColorMap: [:],
            selectedActorId: nil
        )

        XCTAssertEqual(model.totalAssets, 15)
        XCTAssertEqual(Set(model.leaderboard.map(\.entityId)), Set([human.id.uuidString, pet.id.uuidString]))
    }

    func testWealthTrendsExcludeLegacySystemLedgerEntries() {
        let human = Human(name: "Guan")
        let pet = Pet(name: "Miso")
        let model = retainUntilProcessExit(IslandWealthScreenModel())
        let humanAccount = CoconutAccount(
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            displayName: human.name,
            balance: 10
        )
        let petAccount = CoconutAccount(
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            displayName: pet.name,
            balance: 5
        )
        let formalLedger = CoconutLedgerEntry(
            transactionKey: "wealth:human",
            accountKey: CoconutAccountKey.human(human.id),
            ownerKind: .human,
            ownerId: human.id.uuidString,
            ownerName: human.name,
            delta: 10,
            balanceBefore: 0,
            balanceAfter: 10,
            entryKind: .reward,
            source: .careEvent,
            title: "Care",
            emoji: "🥥"
        )
        let systemLedger = CoconutLedgerEntry(
            transactionKey: "wealth:system",
            accountKey: CoconutAccountKey.legacySystem,
            ownerKind: .system,
            ownerId: "",
            ownerName: "System",
            delta: 99,
            balanceBefore: 0,
            balanceAfter: 99,
            entryKind: .reward,
            source: .service,
            title: "Legacy",
            emoji: "🥥",
            actorId: "system",
            actorName: "System"
        )

        model.timeRange = .all
        model.applyQuerySnapshot(
            pets: [pet],
            visibleHumans: [human],
            hiddenHumanIds: [],
            walletAccounts: [humanAccount, petAccount],
            walletLedgerEntries: [formalLedger, systemLedger],
            petColorMap: [:],
            selectedActorId: nil
        )

        XCTAssertEqual(model.periodIncome, 10)
        XCTAssertFalse(model.chartBars.contains { $0.entityId == "system" || $0.entityName == "其他/系统" })
        XCTAssertFalse(model.activeEntityNames.contains("System"))
    }

    func testWealthTotalIncludesHiddenHumanWalletButHidesLeaderboardRow() {
        let visibleHuman = Human(name: "Guan")
        let hiddenHuman = Human(name: "Private")
        let pet = Pet(name: "Miso")
        let model = retainUntilProcessExit(IslandWealthScreenModel())
        let visibleAccount = CoconutAccount(
            accountKey: CoconutAccountKey.human(visibleHuman.id),
            ownerKind: .human,
            ownerId: visibleHuman.id.uuidString,
            displayName: visibleHuman.name,
            balance: 10
        )
        let hiddenAccount = CoconutAccount(
            accountKey: CoconutAccountKey.human(hiddenHuman.id),
            ownerKind: .human,
            ownerId: hiddenHuman.id.uuidString,
            displayName: hiddenHuman.name,
            balance: 40
        )
        let petAccount = CoconutAccount(
            accountKey: CoconutAccountKey.pet(pet.id),
            ownerKind: .pet,
            ownerId: pet.id.uuidString,
            displayName: pet.name,
            balance: 5
        )

        model.applyQuerySnapshot(
            pets: [pet],
            allHumans: [visibleHuman, hiddenHuman],
            visibleHumans: [visibleHuman],
            hiddenHumanIds: [hiddenHuman.id.uuidString],
            walletAccounts: [visibleAccount, hiddenAccount, petAccount],
            walletLedgerEntries: [],
            petColorMap: [:],
            selectedActorId: nil
        )

        XCTAssertEqual(model.totalAssets, 55)
        XCTAssertEqual(model.displayedAssets, 55)
        XCTAssertEqual(Set(model.leaderboard.map(\.entityId)), Set([visibleHuman.id.uuidString, pet.id.uuidString]))
        XCTAssertFalse(model.leaderboard.contains { $0.entityId == hiddenHuman.id.uuidString })
    }

    func testWealthActiveAssetsExcludeFrozenWalletOwners() {
        let activeHuman = Human(name: "Guan")
        let hiddenHuman = Human(name: "Private")
        let recycledHuman = Human(name: "Recycled")
        recycledHuman.trashedAt = Date()
        let activePet = Pet(name: "Miso")
        let memorialPet = Pet(name: "Luna")
        memorialPet.passedAwayDate = Date()
        let model = retainUntilProcessExit(IslandWealthScreenModel())
        let accounts = [
            CoconutAccount(
                accountKey: CoconutAccountKey.human(activeHuman.id),
                ownerKind: .human,
                ownerId: activeHuman.id.uuidString,
                displayName: activeHuman.name,
                balance: 10
            ),
            CoconutAccount(
                accountKey: CoconutAccountKey.human(hiddenHuman.id),
                ownerKind: .human,
                ownerId: hiddenHuman.id.uuidString,
                displayName: hiddenHuman.name,
                balance: 40
            ),
            CoconutAccount(
                accountKey: CoconutAccountKey.human(recycledHuman.id),
                ownerKind: .human,
                ownerId: recycledHuman.id.uuidString,
                displayName: recycledHuman.name,
                balance: 80
            ),
            CoconutAccount(
                accountKey: CoconutAccountKey.pet(activePet.id),
                ownerKind: .pet,
                ownerId: activePet.id.uuidString,
                displayName: activePet.name,
                balance: 5
            ),
            CoconutAccount(
                accountKey: CoconutAccountKey.pet(memorialPet.id),
                ownerKind: .pet,
                ownerId: memorialPet.id.uuidString,
                displayName: memorialPet.name,
                balance: 12
            )
        ]

        model.applyQuerySnapshot(
            pets: [activePet, memorialPet],
            allHumans: [activeHuman, hiddenHuman, recycledHuman],
            visibleHumans: [activeHuman, recycledHuman],
            hiddenHumanIds: [hiddenHuman.id.uuidString],
            walletAccounts: accounts,
            walletLedgerEntries: [],
            petColorMap: [:],
            selectedActorId: nil
        )

        XCTAssertEqual(model.totalAssets, 55)
        XCTAssertEqual(Set(model.leaderboard.map(\.entityId)), Set([activeHuman.id.uuidString, activePet.id.uuidString]))
        XCTAssertFalse(model.leaderboard.contains { $0.entityId == hiddenHuman.id.uuidString })
        XCTAssertFalse(model.leaderboard.contains { $0.entityId == recycledHuman.id.uuidString })
        XCTAssertFalse(model.leaderboard.contains { $0.entityId == memorialPet.id.uuidString })

        model.selectedActorId = recycledHuman.id.uuidString
        XCTAssertEqual(model.displayedAssets, 0)
    }

    func testExchangeGateHidesShopAndTodayFocusSurfaces() {
        XCTAssertFalse(CoconutExchangeFeatureGate.isEnabled)
        XCTAssertFalse(ShopItem.ShopCategory.visibleCases.contains(.cashExchange))

        let receiver = Human(name: "Receiver")
        let request = CoconutExchangeRequest(
            senderId: UUID().uuidString,
            senderName: "Sender",
            receiverId: receiver.id.uuidString,
            receiverName: receiver.name,
            coconutCost: 500,
            currencyCode: "USD",
            localAmount: 0.5
        )
        let snapshot = TodayFocusSnapshot.make(
            pets: [],
            plants: [],
            reminders: [],
            events: [],
            humans: [receiver],
            activeHumanId: receiver.id.uuidString,
            careLedgerEntries: [],
            humanWeightLogs: [],
            familyTasks: [],
            exchangeRequests: [request],
            questProgress: TodayFocusQuestProgress(
                isPetWizardCompleted: true,
                isFirstMealRecorded: true,
                isThemeColorSet: true
            ),
            clinicalAlerts: [],
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
        XCTAssertTrue(snapshot.pendingExchangeRequests.isEmpty)

        let staleSnapshot = TodayFocusSnapshot(
            dayToken: TodayFocusSnapshot.dayToken(for: Date(timeIntervalSince1970: 1_800_000_000)),
            pets: [],
            plants: [],
            humans: [],
            refreshedQuests: [],
            assignedFamilyTasks: [],
            pendingExchangeRequests: [TodayFocusExchangeRequestSnapshot(request: request)],
            negativeSignals: []
        )
        let deck = TodayFocusCard.TodayFocusRenderDeck.make(
            snapshot: staleSnapshot,
            skippedFocusKeys: [],
            closedNegativeKeys: []
        )

        XCTAssertTrue(deck.pendingExchangeRequests.isEmpty)
        XCTAssertFalse(deck.cards.contains { content in
            if case .coconutExchange = content {
                return true
            }
            return false
        })
    }

    func testExchangeGateBlocksServiceWrites() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let sender = Human(name: "Sender")
        sender.coconutBalance = 500
        let receiver = Human(name: "Receiver")
        context.insert(sender)
        context.insert(receiver)
        try context.save()
        let option = try XCTUnwrap(CoconutExchangeOption.options(for: "US").first)

        XCTAssertThrowsError(
            try CoconutExchangeService.createRequest(
                sender: sender,
                receiver: receiver,
                option: option,
                note: "",
                context: context
            )
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<CoconutExchangeRequest>()).isEmpty)

        let request = CoconutExchangeRequest(
            senderId: sender.id.uuidString,
            senderName: sender.name,
            receiverId: receiver.id.uuidString,
            receiverName: receiver.name,
            coconutCost: option.coconutCost,
            currencyCode: option.currencyCode,
            localAmount: option.localAmount
        )
        context.insert(request)
        try context.save()

        XCTAssertThrowsError(try CoconutExchangeService.confirm(request, by: receiver, context: context))
        XCTAssertEqual(request.status, .pending)
        XCTAssertThrowsError(try CoconutExchangeService.cancel(request, by: sender, context: context))
        XCTAssertEqual(request.status, .pending)
        XCTAssertEqual(sender.coconutBalance, 500)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    func testWalletApplyRejectsFrozenMemberWrites() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Guan")
        human.coconutBalance = 20
        human.passedAwayDate = Date()
        let pet = Pet(name: "Miso")
        pet.coconutBalance = 20
        pet.trashedAt = Date()
        context.insert(human)
        context.insert(pet)
        try context.save()

        XCTAssertThrowsError(
            try CoconutWalletService.apply(
                deltas: [
                    .human(
                        human,
                        delta: -1,
                        entryKind: .spend,
                        source: .shop,
                        title: "Frozen spend",
                        transactionKey: "frozen-human-spend"
                    )
                ],
                context: context,
                save: true,
                postsRewardFeedback: false
            )
        ) { error in
            guard case CoconutWalletError.walletFrozen = error else {
                return XCTFail("Expected walletFrozen, got \(error)")
            }
        }

        XCTAssertThrowsError(
            try CoconutWalletService.apply(
                deltas: [
                    .pet(
                        pet,
                        delta: 1,
                        entryKind: .reward,
                        source: .service,
                        title: "Frozen reward",
                        transactionKey: "frozen-pet-reward"
                    )
                ],
                context: context,
                save: true,
                postsRewardFeedback: false
            )
        ) { error in
            guard case CoconutWalletError.walletFrozen = error else {
                return XCTFail("Expected walletFrozen, got \(error)")
            }
        }

        XCTAssertEqual(human.coconutBalance, 20)
        XCTAssertEqual(pet.coconutBalance, 20)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
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
        let schema = Schema(ArkSchemaV70.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func fetchAccount(accountKey: String, context: ModelContext) throws -> CoconutAccount? {
        var descriptor = FetchDescriptor<CoconutAccount>(
            predicate: #Predicate<CoconutAccount> { $0.accountKey == accountKey }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
