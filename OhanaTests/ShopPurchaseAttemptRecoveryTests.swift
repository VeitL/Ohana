import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ShopPurchaseAttemptRecoveryTests {
    @Test func durableInventoryIgnoresStaleLegacyProjectionAndAppliesAttemptOnce() throws {
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let attemptID = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 20000)

        #expect(ShopInventoryStateStore.fulfillPurchase(
            itemID: "boost_backdate_pack",
            attemptID: attemptID,
            purchasedAt: now,
            now: now,
            defaults: defaults
        ))
        defaults.set(0, forKey: CheckInStreakStore.makeupPackKey)

        #expect(ShopInventoryStateStore.snapshot(defaults: defaults).backdatePassCount == 3)
        #expect(defaults.integer(forKey: CheckInStreakStore.makeupPackKey) == 3)
        #expect(ShopInventoryStateStore.hasAppliedPurchase(attemptID: attemptID, defaults: defaults))

        #expect(ShopInventoryStateStore.fulfillPurchase(
            itemID: "boost_backdate_pack",
            attemptID: attemptID,
            purchasedAt: now,
            now: now,
            defaults: defaults
        ))
        #expect(ShopInventoryStateStore.snapshot(defaults: defaults).backdatePassCount == 3)
    }

    @Test func expiredStreakPurchaseDoesNotGrantOrCheckpointInventory() throws {
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let attemptID = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 400_000)

        #expect(!ShopInventoryStateStore.fulfillPurchase(
            itemID: "boost_streak",
            attemptID: attemptID,
            purchasedAt: now.addingTimeInterval(-172_800),
            now: now,
            defaults: defaults
        ))
        #expect(ShopInventoryStateStore.snapshot(defaults: defaults).streakShieldExpiry == nil)
        #expect(!ShopInventoryStateStore.hasAppliedPurchase(attemptID: attemptID, defaults: defaults))
    }

    @Test func unresolvedConsumablePurchaseReturnsExistingAttemptWithoutSecondDebit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let startingBalance = item.cost * 2
        human.coconutBalance = startingBalance
        context.insert(human)
        try context.save()

        let wallet = SwiftDataCoconutWalletManager()
        let questManager = QuestManager(
            wallet: wallet,
            revisions: SharedDomainRevisionPublisher(center: ReadModelRevisionCenter())
        )
        let oldCoconutCount = questManager.coconutCount
        let oldCoconutLogs = questManager.coconutLogs
        defer {
            questManager.coconutCount = oldCoconutCount
            questManager.coconutLogs = oldCoconutLogs
        }
        questManager.coconutCount = startingBalance
        questManager.coconutLogs = []

        let first = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Backdate Pack",
            context: context,
            questManager: questManager,
            wallet: wallet,
            careLedger: CareLedgerService()
        )
        let second = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Backdate Pack",
            context: context,
            questManager: questManager,
            wallet: wallet,
            careLedger: CareLedgerService()
        )

        #expect(first.didPurchase)
        #expect(second.didPurchase)
        #expect(first.attemptID == second.attemptID)
        #expect(first.transactionKey == second.transactionKey)
        #expect(human.coconutBalance == startingBalance - item.cost)
        #expect(try context.fetchCount(FetchDescriptor<ShopPurchaseAttempt>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CareLedgerEvent>()) == 1)
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(walletEntries.count(where: { $0.source == .shop && $0.entryKind == .spend }) == 1)
        #expect(try context.fetch(FetchDescriptor<ShopPurchaseRecord>()).isEmpty)
    }

    @Test func startupRecoveryCompletesAnAlreadyAppliedInventoryAttemptExactlyOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let inventory = UserDefaultsShopInventoryManager(defaults: defaults)
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let human = Human(name: "Guan")
        let attemptID = UUID()
        let purchasedAt = Date().addingTimeInterval(-60)
        let attempt = ShopPurchaseAttempt(
            id: attemptID,
            transactionKey: "shop:\(item.id):\(human.id.uuidString):\(attemptID.uuidString)",
            itemId: item.id,
            buyerHumanId: human.id.uuidString,
            price: item.cost,
            state: .purchased,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: human.id, amount: item.cost)
            ]),
            fulfillmentPayloadJSON: try encoded(
                ShopPurchaseFulfillmentPayload(purchasedAt: purchasedAt)
            ),
            createdAt: purchasedAt
        )
        context.insert(human)
        context.insert(attempt)
        try context.save()

        #expect(inventory.fulfillPurchase(
            itemID: item.id,
            attemptID: attemptID,
            purchasedAt: purchasedAt
        ))
        #expect(inventory.consumableSnapshot().backdatePassCount == 3)

        let base = AppServices(modelContainer: container)
        let services = appServices(base: base, replacingInventoryWith: inventory)
        let results = ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            maximumCount: 1
        )

        #expect(results == [
            ShopPurchaseRecoveryResult(
                attemptID: attemptID,
                itemID: item.id,
                disposition: .fulfilled
            )
        ])
        #expect(attempt.state == .fulfilled)
        #expect(inventory.consumableSnapshot().backdatePassCount == 3)
        #expect(ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            maximumCount: 1
        ).isEmpty)
        #expect(inventory.consumableSnapshot().backdatePassCount == 3)
    }

    @Test func startupRecoveryRefundsAStreakShieldThatExpiredBeforeFulfillment() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let inventory = UserDefaultsShopInventoryManager(defaults: defaults)
        let item = try #require(ShopCatalog.item(id: "boost_streak"))
        let human = Human(name: "Guan")
        human.coconutBalance = 0
        let attemptID = UUID()
        let purchasedAt = Date().addingTimeInterval(-172_801)
        let attempt = ShopPurchaseAttempt(
            id: attemptID,
            transactionKey: "shop:\(item.id):\(human.id.uuidString):\(attemptID.uuidString)",
            itemId: item.id,
            buyerHumanId: human.id.uuidString,
            price: item.cost,
            state: .purchased,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: human.id, amount: item.cost)
            ]),
            fulfillmentPayloadJSON: try encoded(
                ShopPurchaseFulfillmentPayload(purchasedAt: purchasedAt)
            ),
            createdAt: purchasedAt
        )
        context.insert(human)
        context.insert(attempt)
        try context.save()

        let base = AppServices(modelContainer: container)
        let services = appServices(base: base, replacingInventoryWith: inventory)
        let oldCoconutCount = services.questManager.coconutCount
        let oldCoconutLogs = services.questManager.coconutLogs
        defer {
            services.questManager.coconutCount = oldCoconutCount
            services.questManager.coconutLogs = oldCoconutLogs
        }
        services.questManager.coconutCount = 0
        services.questManager.coconutLogs = []

        let results = ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            maximumCount: 1
        )

        #expect(results.first?.disposition == .refunded)
        #expect(attempt.state == .refunded)
        #expect(human.coconutBalance == item.cost)
        #expect(inventory.consumableSnapshot().streakShieldExpiry == nil)
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(walletEntries.count(where: { $0.source == .shop && $0.entryKind == .refund }) == 1)
    }

    @Test func freshAppIconAttemptWaitsForItsOSCallbackGraceBeforeRefundingMismatch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = try #require(ShopCatalog.item(id: "appicon_lime_night"))
        let human = Human(name: "Guan")
        human.coconutBalance = 0
        let attemptID = UUID()
        let purchasedAt = Date(timeIntervalSinceReferenceDate: 900_000)
        let graceDeadline = purchasedAt.addingTimeInterval(60)
        let attempt = ShopPurchaseAttempt(
            id: attemptID,
            transactionKey: "shop:\(item.id):\(human.id.uuidString):\(attemptID.uuidString)",
            itemId: item.id,
            buyerHumanId: human.id.uuidString,
            price: item.cost,
            state: .purchased,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: human.id, amount: item.cost)
            ]),
            fulfillmentPayloadJSON: try encoded(
                ShopPurchaseFulfillmentPayload(purchasedAt: purchasedAt)
            ),
            nextRetryAt: graceDeadline,
            createdAt: purchasedAt
        )
        context.insert(human)
        context.insert(attempt)
        try context.save()

        let base = AppServices(modelContainer: container)
        let services = appServices(
            base: base,
            replacingInventoryWith: base.shopInventory,
            appIcons: FixedAppIconManager(currentDescriptor: AppIconCatalog.icons[0])
        )
        let oldCoconutCount = services.questManager.coconutCount
        let oldCoconutLogs = services.questManager.coconutLogs
        defer {
            services.questManager.coconutCount = oldCoconutCount
            services.questManager.coconutLogs = oldCoconutLogs
        }
        services.questManager.coconutCount = 0
        services.questManager.coconutLogs = []

        let freshResults = ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            now: purchasedAt.addingTimeInterval(30),
            maximumCount: 1
        )

        #expect(freshResults.first?.disposition == .retryScheduled)
        #expect(attempt.state == .purchased)
        #expect(attempt.nextRetryAt == graceDeadline)
        #expect(human.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)

        let expiredResults = ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            now: graceDeadline.addingTimeInterval(1),
            maximumCount: 1
        )

        #expect(expiredResults.first?.disposition == .refunded)
        #expect(attempt.state == .refunded)
        #expect(human.coconutBalance == item.cost)
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(walletEntries.count(where: { $0.source == .shop && $0.entryKind == .refund }) == 1)
    }

    @Test func cofundedRecoveryRefundsTheExactFundingSnapshotOnlyOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let inventory = UserDefaultsShopInventoryManager(defaults: defaults)
        let base = AppServices(modelContainer: container)
        let services = appServices(base: base, replacingInventoryWith: inventory)
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let buyer = Human(name: "Buyer")
        let contributor = Human(name: "Contributor")
        buyer.coconutBalance = 100
        contributor.coconutBalance = item.cost - buyer.coconutBalance
        contributor.createdAt = buyer.createdAt.addingTimeInterval(1)
        let buyerStartingBalance = buyer.coconutBalance
        let contributorStartingBalance = contributor.coconutBalance
        context.insert(buyer)
        context.insert(contributor)
        try context.save()

        let purchase = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: buyer,
            itemName: "Backdate Pack",
            context: context,
            questManager: services.questManager,
            wallet: services.coconutWallet,
            careLedger: services.careLedger
        )
        let attemptID = try #require(purchase.attemptID)
        let attempt = try #require(
            context.fetch(FetchDescriptor<ShopPurchaseAttempt>()).first { $0.id == attemptID }
        )
        #expect(purchase.fundingContributions == [
            ShopPurchaseFundingContribution(humanID: buyer.id, amount: buyerStartingBalance),
            ShopPurchaseFundingContribution(humanID: contributor.id, amount: contributorStartingBalance)
        ])
        #expect(buyer.coconutBalance == 0)
        #expect(contributor.coconutBalance == 0)

        attempt.state = .refundPending
        try context.save()
        let firstRecovery = ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            maximumCount: 1
        )

        #expect(firstRecovery.first?.disposition == .refunded)
        #expect(attempt.state == .refunded)
        #expect(buyer.coconutBalance == buyerStartingBalance)
        #expect(contributor.coconutBalance == contributorStartingBalance)
        let firstWalletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(firstWalletEntries.count(where: { $0.source == .shop && $0.delta < 0 }) == 2)
        #expect(firstWalletEntries.count(where: { $0.source == .shop && $0.entryKind == .refund }) == 2)

        #expect(ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            maximumCount: 1
        ).isEmpty)
        #expect(buyer.coconutBalance == buyerStartingBalance)
        #expect(contributor.coconutBalance == contributorStartingBalance)
        let finalWalletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(finalWalletEntries.count(where: { $0.source == .shop && $0.entryKind == .refund }) == 2)
    }

    @Test func refundPendingAndManualReviewAttemptsCannotTriggerASecondDebit() throws {
        for state in [ShopPurchaseAttemptState.refundPending, .manualReview] {
            let container = try makeContainer()
            let context = container.mainContext
            let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
            let buyer = Human(name: "Buyer")
            buyer.coconutBalance = item.cost * 2
            let attempt = makeAttempt(state: state)
            attempt.buyerHumanId = buyer.id.uuidString
            attempt.price = item.cost
            context.insert(buyer)
            context.insert(attempt)
            try context.save()

            let result = ShopPurchaseCommandService.purchase(
                item: item,
                buyer: buyer,
                itemName: "Backdate Pack",
                context: context,
                wallet: SwiftDataCoconutWalletManager(),
                careLedger: CareLedgerService()
            )

            #expect(!result.didPurchase)
            #expect(result.failure == .persistenceFailed)
            #expect(result.attemptID == attempt.id)
            #expect(buyer.coconutBalance == item.cost * 2)
            #expect(try context.fetchCount(FetchDescriptor<ShopPurchaseAttempt>()) == 1)
            #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
        }
    }

    @Test func missingRefundFundingSnapshotMovesAttemptToManualReviewWithoutMintingCoconuts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let buyer = Human(name: "Buyer")
        buyer.coconutBalance = 0
        let attempt = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):\(buyer.id.uuidString):missing-snapshot",
            itemId: item.id,
            buyerHumanId: buyer.id.uuidString,
            price: item.cost,
            state: .refundPending,
            fundingContributionsJSON: "[]"
        )
        context.insert(buyer)
        context.insert(attempt)
        try context.save()
        let base = AppServices(modelContainer: container)
        let services = appServices(
            base: base,
            replacingInventoryWith: UserDefaultsShopInventoryManager(defaults: defaults)
        )

        let results = ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            maximumCount: 1
        )

        #expect(results.first?.disposition == .manualReview)
        #expect(attempt.state == .manualReview)
        #expect(attempt.lastError == "missingFundingSnapshot")
        #expect(buyer.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func backupRejectsEveryUnsettledAttemptAndAllowsOnlySettledAttempts() throws {
        let blockedStates: [ShopPurchaseAttemptState] = [
            .purchased,
            .fulfilling,
            .refundPending,
            .manualReview
        ]
        for state in blockedStates {
            let container = try makeContainer()
            let context = container.mainContext
            context.insert(makeAttempt(state: state))
            try context.save()
            let (name, defaults) = try isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }

            do {
                _ = try DataBackupManager(defaults: defaults).buildBackup(context: context)
                Issue.record("Expected backup to reject shop attempt state \(state.rawValue)")
            } catch BackupError.pendingShopPurchase {
                // Expected: the local-only recovery record cannot be omitted
                // while its debit or fulfillment remains unresolved.
            } catch {
                Issue.record("Unexpected backup error for \(state.rawValue): \(error)")
            }
        }

        for state in [ShopPurchaseAttemptState.fulfilled, .refunded] {
            let container = try makeContainer()
            let context = container.mainContext
            context.insert(makeAttempt(state: state))
            try context.save()
            let (name, defaults) = try isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }

            _ = try DataBackupManager(defaults: defaults).buildBackup(context: context)
        }
    }

    @Test func physicalHumanDeletionIsBlockedByAnUnsettledFundingSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let contributor = Human(name: "Contributor")
        let attemptID = UUID()
        let attempt = ShopPurchaseAttempt(
            id: attemptID,
            transactionKey: "shop:boost_backdate_pack:other:\(attemptID.uuidString)",
            itemId: "boost_backdate_pack",
            buyerHumanId: UUID().uuidString,
            price: 580,
            state: .manualReview,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: contributor.id, amount: 580)
            ])
        )
        context.insert(contributor)
        context.insert(attempt)
        try context.save()

        #expect(PhysicalDeletionService.deleteHuman(
            contributor,
            context: context
        ) == PhysicalDeletionService.pendingShopPurchaseDeletionBlockCode)
        let result = MemberDeletionCommandService.deleteHuman(
            contributor,
            activeHumanID: contributor.id.uuidString,
            context: context
        )

        #expect(!result.didPersist)
        #expect(!result.clearsActiveHumanID)
        #expect(try context.fetchCount(FetchDescriptor<Human>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ShopPurchaseAttempt>()) == 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV92.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func isolatedDefaults() throws -> (String, UserDefaults) {
        let name = "ShopPurchaseAttemptRecoveryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (name, defaults)
    }

    private func encoded(_ value: some Encodable) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try #require(String(data: data, encoding: .utf8))
    }

    private func makeAttempt(state: ShopPurchaseAttemptState) -> ShopPurchaseAttempt {
        let id = UUID()
        return ShopPurchaseAttempt(
            id: id,
            transactionKey: "shop:boost_backdate_pack:test:\(id.uuidString)",
            itemId: "boost_backdate_pack",
            buyerHumanId: UUID().uuidString,
            price: 580,
            state: state
        )
    }

    private func appServices(
        base: AppServices,
        replacingInventoryWith inventory: ShopInventoryManaging,
        appIcons: AppIconManaging? = nil
    ) -> AppServices {
        AppServices(
            careEvents: base.careEvents,
            activeHumanSelection: base.activeHumanSelection,
            coconutWallet: base.coconutWallet,
            coconutExchange: base.coconutExchange,
            careLedger: base.careLedger,
            questManager: base.questManager,
            familyTasks: base.familyTasks,
            gacha: base.gacha,
            memberCreation: base.memberCreation,
            oasisRewards: base.oasisRewards,
            privacy: base.privacy,
            passcodes: base.passcodes,
            appIcons: appIcons ?? base.appIcons,
            shopInventory: inventory,
            shopPurchaseFulfillment: base.shopPurchaseFulfillment,
            islandToasts: base.islandToasts,
            metricKit: base.metricKit,
            backups: base.backups,
            automaticBackups: base.automaticBackups,
            appReset: base.appReset,
            medicationReminders: base.medicationReminders,
            userNotifications: base.userNotifications,
            notificationRoutes: base.notificationRoutes,
            reminderActions: base.reminderActions,
            reminderScheduling: base.reminderScheduling,
            reminderCompletion: base.reminderCompletion,
            onboardingJourney: base.onboardingJourney,
            humanRequirements: base.humanRequirements,
            todayFocus: base.todayFocus,
            plantCarePlans: base.plantCarePlans,
            plantReminderControls: base.plantReminderControls,
            plantGrowthDiaryExports: base.plantGrowthDiaryExports,
            plantIntelligence: base.plantIntelligence,
            oasisTree: base.oasisTree,
            healthAlerts: base.healthAlerts,
            walking: base.walking,
            location: base.location,
            careLedgerStats: base.careLedgerStats,
            domainRevisions: base.domainRevisions,
            lifecycle: base.lifecycle,
            cloudSync: base.cloudSync,
            commerce: base.commerce,
            sharedCareUndo: base.sharedCareUndo
        )
    }

    private final class FixedAppIconManager: AppIconManaging {
        let supportsAlternateIcons = true
        let currentDescriptor: AppIconShopDescriptor

        init(currentDescriptor: AppIconShopDescriptor) {
            self.currentDescriptor = currentDescriptor
        }

        func setIcon(
            _: AppIconShopDescriptor,
            completion: @escaping (Result<Void, AppIconService.AppIconError>) -> Void
        ) {
            completion(.success(()))
        }
    }
}
