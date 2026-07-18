import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ShopManualRecoveryTests {
    @Test func manualRefundWaitsForOriginalPayerThenRefundsExactlyOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let payer = Human(name: "Original payer")
        payer.coconutBalance = 0
        let attempt = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):\(payer.id.uuidString):manual-refund",
            itemId: item.id,
            buyerHumanId: payer.id.uuidString,
            price: item.cost,
            state: .manualReview,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: payer.id, amount: item.cost)
            ]),
            lastError: "missingOrFrozenRefundRecipient"
        )
        context.insert(attempt)
        try context.save()

        let services = AppServices(modelContainer: container)
        services.questManager.coconutCount = 0
        services.questManager.coconutLogs = []

        let blocked = ShopPurchaseRecoveryService.retryManualReview(
            itemID: item.id,
            context: context,
            services: services
        )

        #expect(blocked.disposition == .stillNeedsAttention)
        #expect(blocked.reasonCode == "missingOrFrozenRefundRecipient")
        #expect(attempt.state == .manualReview)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)

        context.insert(payer)
        try context.save()
        let recovered = ShopPurchaseRecoveryService.retryManualReview(
            itemID: item.id,
            context: context,
            services: services
        )

        #expect(recovered.disposition == .refunded)
        #expect(attempt.state == .refunded)
        #expect(payer.coconutBalance == item.cost)
        var walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(walletEntries.count(where: { $0.source == .shop && $0.entryKind == .refund }) == 1)

        let repeated = ShopPurchaseRecoveryService.retryManualReview(
            itemID: item.id,
            context: context,
            services: services
        )

        #expect(repeated.disposition == .stillNeedsAttention)
        #expect(repeated.reasonCode == "manualReviewAttemptUnavailable")
        #expect(payer.coconutBalance == item.cost)
        walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(walletEntries.count(where: { $0.source == .shop && $0.entryKind == .refund }) == 1)
    }

    @Test func manualFulfillmentReusesOutboxWithoutAnotherDebit() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let buyer = Human(name: "Buyer")
        buyer.coconutBalance = 0
        let purchasedAt = Date().addingTimeInterval(-30)
        let attempt = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):\(buyer.id.uuidString):manual-fulfillment",
            itemId: item.id,
            buyerHumanId: buyer.id.uuidString,
            price: item.cost,
            state: .manualReview,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: buyer.id, amount: item.cost)
            ]),
            fulfillmentPayloadJSON: try encoded(
                ShopPurchaseFulfillmentPayload(purchasedAt: purchasedAt)
            ),
            lastError: "catalogItemMissing",
            createdAt: purchasedAt
        )
        context.insert(buyer)
        context.insert(attempt)
        try context.save()

        let inventory = UserDefaultsShopInventoryManager(defaults: defaults)
        let base = AppServices(modelContainer: container)
        let services = appServices(base: base, replacingInventoryWith: inventory)
        let result = ShopPurchaseRecoveryService.retryManualReview(
            itemID: item.id,
            context: context,
            services: services
        )

        #expect(result.disposition == .fulfilled)
        #expect(attempt.state == .fulfilled)
        #expect(inventory.consumableSnapshot().backdatePassCount == 3)
        #expect(buyer.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func invalidFundingSnapshotIsRebuiltOnlyFromTheOriginalDebitLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let buyer = Human(name: "Buyer")
        buyer.coconutBalance = item.cost
        context.insert(buyer)
        try context.save()

        let services = AppServices(modelContainer: container)
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
        #expect(buyer.coconutBalance == 0)

        attempt.state = .manualReview
        attempt.lastError = "invalidFundingSnapshot"
        attempt.fundingContributionsJSON = try encoded([
            ShopPurchaseFundingContribution(humanID: buyer.id, amount: item.cost + 1)
        ])
        try context.save()

        let result = ShopPurchaseRecoveryService.retryManualReview(
            itemID: item.id,
            context: context,
            services: services
        )

        #expect(result.disposition == .refunded)
        #expect(attempt.state == .refunded)
        #expect(buyer.coconutBalance == item.cost)
        let rebuilt = try JSONDecoder().decode(
            [ShopPurchaseFundingContribution].self,
            from: Data(attempt.fundingContributionsJSON.utf8)
        )
        #expect(rebuilt == [
            ShopPurchaseFundingContribution(humanID: buyer.id, amount: item.cost)
        ])
        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(entries.count(where: { $0.source == .shop && $0.delta < 0 }) == 1)
        #expect(entries.count(where: { $0.source == .shop && $0.entryKind == .refund }) == 1)
    }

    @Test func legacyFulfillingInventoryAttemptStopsWithoutDuplicateGrantOrRefund() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let inventory = UserDefaultsShopInventoryManager(defaults: defaults)
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let buyer = Human(name: "Buyer")
        buyer.coconutBalance = 0
        let attempt = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):\(buyer.id.uuidString):legacy-fulfilling",
            itemId: item.id,
            buyerHumanId: buyer.id.uuidString,
            price: item.cost,
            state: .fulfilling,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: buyer.id, amount: item.cost)
            ]),
            fulfillmentPayloadJSON: "{\"version\":1,\"purchasedAt\":0}"
        )
        context.insert(buyer)
        context.insert(attempt)
        try context.save()
        inventory.addBackdatePasses(3)

        let base = AppServices(modelContainer: container)
        let services = appServices(base: base, replacingInventoryWith: inventory)
        let result = ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services,
            maximumCount: 1
        )

        #expect(result.first?.disposition == .manualReview)
        #expect(attempt.state == .manualReview)
        #expect(attempt.lastError == "legacyFulfillmentUnverifiable")
        #expect(inventory.consumableSnapshot().backdatePassCount == 3)
        #expect(buyer.coconutBalance == 0)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
    }

    @Test func unrecognizedManualReasonPreservesOutboxAndExplainsWhy() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let attempt = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):unknown:manual-reason",
            itemId: item.id,
            buyerHumanId: UUID().uuidString,
            price: item.cost,
            state: .manualReview,
            lastError: "legacyUnknownFailure"
        )
        context.insert(attempt)
        try context.save()

        let result = ShopPurchaseRecoveryService.retryManualReview(
            itemID: item.id,
            context: context,
            services: AppServices(modelContainer: container)
        )

        #expect(result.disposition == .stillNeedsAttention)
        #expect(result.reasonCode == "unrecognizedManualReviewReason")
        #expect(attempt.state == .manualReview)
        #expect(attempt.lastError == "legacyUnknownFailure")
        #expect(try context.fetchCount(FetchDescriptor<ShopPurchaseAttempt>()) == 1)
    }

    @Test func activeAttemptQuerySkipsNewerSettledAttemptWithoutChargingAgain() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let buyer = Human(name: "Buyer")
        buyer.coconutBalance = item.cost * 2
        let pendingID = UUID()
        let pending = ShopPurchaseAttempt(
            id: pendingID,
            transactionKey: "shop:\(item.id):\(buyer.id.uuidString):pending",
            itemId: item.id,
            buyerHumanId: buyer.id.uuidString,
            price: item.cost,
            state: .purchased,
            fundingContributionsJSON: try encoded([
                ShopPurchaseFundingContribution(humanID: buyer.id, amount: item.cost)
            ]),
            createdAt: Date().addingTimeInterval(-60)
        )
        let settled = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):\(buyer.id.uuidString):settled",
            itemId: item.id,
            buyerHumanId: buyer.id.uuidString,
            price: item.cost,
            state: .fulfilled,
            createdAt: Date()
        )
        context.insert(buyer)
        context.insert(pending)
        context.insert(settled)
        try context.save()

        let wallet = SwiftDataCoconutWalletManager()
        let questManager = QuestManager(
            wallet: wallet,
            revisions: SharedDomainRevisionPublisher(center: ReadModelRevisionCenter())
        )
        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: buyer,
            itemName: "Backdate Pack",
            context: context,
            questManager: questManager,
            wallet: wallet,
            careLedger: CareLedgerService()
        )

        #expect(result.didPurchase)
        #expect(result.attemptID == pendingID)
        #expect(buyer.coconutBalance == item.cost * 2)
        #expect(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareLedgerEvent>()).isEmpty)
    }

    @Test func recoverableAttemptQuerySkipsNewerManualEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        let buyer = Human(name: "Buyer")
        let pending = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):\(buyer.id.uuidString):recoverable",
            itemId: item.id,
            buyerHumanId: buyer.id.uuidString,
            price: item.cost,
            state: .purchased,
            fulfillmentPayloadJSON: try encoded(
                ShopPurchaseFulfillmentPayload(purchasedAt: Date().addingTimeInterval(-60))
            ),
            createdAt: Date().addingTimeInterval(-60)
        )
        let manual = ShopPurchaseAttempt(
            transactionKey: "shop:\(item.id):\(buyer.id.uuidString):manual",
            itemId: item.id,
            buyerHumanId: buyer.id.uuidString,
            price: item.cost,
            state: .manualReview,
            lastError: "legacyUnknownFailure",
            createdAt: Date()
        )
        context.insert(buyer)
        context.insert(pending)
        context.insert(manual)
        try context.save()

        let inventory = UserDefaultsShopInventoryManager(defaults: defaults)
        let base = AppServices(modelContainer: container)
        let services = appServices(base: base, replacingInventoryWith: inventory)
        let didFulfill = ShopPurchaseFulfillmentService().fulfillConsumable(
            item: item,
            context: context,
            services: services
        )

        #expect(didFulfill)
        #expect(pending.state == .fulfilled)
        #expect(manual.state == .manualReview)
        #expect(inventory.consumableSnapshot().backdatePassCount == 3)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV92.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func isolatedDefaults() throws -> (String, UserDefaults) {
        let name = "ShopManualRecoveryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (name, defaults)
    }

    private func encoded(_ value: some Encodable) throws -> String {
        let data = try JSONEncoder().encode(value)
        return try #require(String(data: data, encoding: .utf8))
    }

    private func appServices(
        base: AppServices,
        replacingInventoryWith inventory: ShopInventoryManaging
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
            appIcons: base.appIcons,
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
}
