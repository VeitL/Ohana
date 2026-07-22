import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ShopTreePurchaseRecoveryTests {
    @Test func durableMarkerOwnsIdempotencyInsteadOfAggregateEnergy() throws {
        let defaultsName = "ShopTreePurchaseRecoveryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        defaults.removePersistentDomain(forName: defaultsName)
        defaults.set(100, forKey: "oasis_injectedEnergy")

        let firstPurchaseID = UUID()
        let secondPurchaseID = UUID()
        let first = OasisTreePreferenceStore.applyShopEnergyPurchase(
            firstPurchaseID,
            xp: 10,
            currentInjectedEnergy: 100,
            defaults: defaults
        )
        let repeated = OasisTreePreferenceStore.applyShopEnergyPurchase(
            firstPurchaseID,
            xp: 10,
            currentInjectedEnergy: first.injectedEnergy,
            defaults: defaults
        )
        let distinct = OasisTreePreferenceStore.applyShopEnergyPurchase(
            secondPurchaseID,
            xp: 10,
            currentInjectedEnergy: repeated.injectedEnergy,
            defaults: defaults
        )
        let restartedRepeat = OasisTreePreferenceStore.applyShopEnergyPurchase(
            firstPurchaseID,
            xp: 10,
            currentInjectedEnergy: 0,
            defaults: defaults
        )

        #expect(first == OasisShopEnergyPurchaseWrite(injectedEnergy: 110, didApplyEnergy: true))
        #expect(repeated == OasisShopEnergyPurchaseWrite(injectedEnergy: 110, didApplyEnergy: false))
        #expect(distinct == OasisShopEnergyPurchaseWrite(injectedEnergy: 120, didApplyEnergy: true))
        #expect(restartedRepeat == OasisShopEnergyPurchaseWrite(injectedEnergy: 120, didApplyEnergy: false))
        #expect(OasisTreePreferenceStore.hasAppliedShopEnergyPurchase(firstPurchaseID, defaults: defaults))
        #expect(OasisTreePreferenceStore.hasAppliedShopEnergyPurchase(secondPurchaseID, defaults: defaults))
        #expect(defaults.integer(forKey: "oasis_injectedEnergy") == 120)
        #expect(defaults.data(forKey: OasisTreePreferenceStore.shopEnergyPurchaseStateKey) != nil)
    }

    @Test func managerAddsEveryDistinctPurchaseAndCrashReplayOnlyCheckpointsLedger() throws {
        let defaults = UserDefaults.standard
        let oldInjectedEnergy = defaults.object(forKey: "oasis_injectedEnergy")
        let oldPurchaseState = defaults.object(forKey: OasisTreePreferenceStore.shopEnergyPurchaseStateKey)
        let oldLastRewardedLevel = defaults.object(forKey: "oasis_lastRewardedLevel")
        defer {
            restore(oldInjectedEnergy, forKey: "oasis_injectedEnergy", defaults: defaults)
            restore(
                oldPurchaseState,
                forKey: OasisTreePreferenceStore.shopEnergyPurchaseStateKey,
                defaults: defaults
            )
            restore(oldLastRewardedLevel, forKey: "oasis_lastRewardedLevel", defaults: defaults)
            defaults.synchronize()
        }
        defaults.set(100, forKey: "oasis_injectedEnergy")
        defaults.removeObject(forKey: OasisTreePreferenceStore.shopEnergyPurchaseStateKey)
        defaults.set(TreeLevel.lv10.rawValue, forKey: "oasis_lastRewardedLevel")
        defaults.synchronize()

        let container = try makeContainer()
        let context = container.mainContext
        let manager = OasisTreeManager()
        let firstPurchaseID = UUID()
        let secondPurchaseID = UUID()

        #expect(manager.applyPurchasedEnergyBoost(
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            injectedXP: OasisTreeEnergyInjectionPolicy.starterPackageXP,
            purchaseID: firstPurchaseID,
            modelContext: context
        ))
        #expect(manager.injectedEnergy == 110)

        // Under the old absolute-target heuristic, the first purchase could
        // make this distinct purchase look fulfilled. Its own marker is absent,
        // so it must contribute its full XP anyway.
        #expect(manager.applyPurchasedEnergyBoost(
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            injectedXP: OasisTreeEnergyInjectionPolicy.starterPackageXP,
            purchaseID: secondPurchaseID,
            modelContext: context
        ))
        #expect(manager.injectedEnergy == 120)

        #expect(manager.applyPurchasedEnergyBoost(
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            injectedXP: OasisTreeEnergyInjectionPolicy.starterPackageXP,
            purchaseID: firstPurchaseID,
            modelContext: context
        ))
        #expect(manager.injectedEnergy == 120)

        let crashWindowPurchaseID = UUID()
        let crashWrite = OasisTreePreferenceStore.applyShopEnergyPurchase(
            crashWindowPurchaseID,
            xp: OasisTreeEnergyInjectionPolicy.starterPackageXP,
            currentInjectedEnergy: manager.injectedEnergy
        )
        #expect(crashWrite.injectedEnergy == 130)

        let restartedManager = OasisTreeManager()
        #expect(restartedManager.injectedEnergy == 130)
        #expect(restartedManager.applyPurchasedEnergyBoost(
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            injectedXP: OasisTreeEnergyInjectionPolicy.starterPackageXP,
            purchaseID: crashWindowPurchaseID,
            modelContext: context
        ))
        #expect(restartedManager.injectedEnergy == 130)

        let events = try context.fetch(FetchDescriptor<CareLedgerEvent>())
        let purchaseIDs = Set(events.compactMap(\.sourceEventId))
        #expect(purchaseIDs == Set([
            firstPurchaseID.uuidString,
            secondPurchaseID.uuidString,
            crashWindowPurchaseID.uuidString
        ]))
        #expect(events.count(where: { $0.sourceEventId == firstPurchaseID.uuidString }) == 1)
        #expect(events.count(where: { $0.sourceEventId == crashWindowPurchaseID.uuidString }) == 1)
    }

    @Test func purchaseFulfillmentAndCrashReplayStaySingleDebitSingleTreeGrant() throws {
        let defaults = UserDefaults.standard
        let oldInjectedEnergy = defaults.object(forKey: "oasis_injectedEnergy")
        let oldPurchaseState = defaults.object(forKey: OasisTreePreferenceStore.shopEnergyPurchaseStateKey)
        let oldLastRewardedLevel = defaults.object(forKey: "oasis_lastRewardedLevel")
        let oldRegistryManager = OasisTreeManagerRegistry.current
        defer {
            OasisTreeManagerRegistry.current = oldRegistryManager
            restore(oldInjectedEnergy, forKey: "oasis_injectedEnergy", defaults: defaults)
            restore(
                oldPurchaseState,
                forKey: OasisTreePreferenceStore.shopEnergyPurchaseStateKey,
                defaults: defaults
            )
            restore(oldLastRewardedLevel, forKey: "oasis_lastRewardedLevel", defaults: defaults)
            defaults.synchronize()
        }
        defaults.set(100, forKey: "oasis_injectedEnergy")
        defaults.removeObject(forKey: OasisTreePreferenceStore.shopEnergyPurchaseStateKey)
        defaults.set(TreeLevel.lv10.rawValue, forKey: "oasis_lastRewardedLevel")
        defaults.synchronize()

        let container = try makeContainer()
        let context = container.mainContext
        let services = AppServices(modelContainer: container)
        let item = try #require(ShopCatalog.item(id: "boost_tree"))
        let buyer = Human(name: "Buyer")
        buyer.coconutBalance = item.cost
        context.insert(buyer)
        try context.save()

        let purchase = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: buyer,
            itemName: "Tree Energy",
            context: context,
            questManager: services.questManager,
            wallet: services.coconutWallet,
            careLedger: services.careLedger
        )
        let attemptID = try #require(purchase.attemptID)
        let attempt = try #require(
            context.fetch(FetchDescriptor<ShopPurchaseAttempt>()).first { $0.id == attemptID }
        )

        #expect(services.shopPurchaseFulfillment.fulfillConsumable(
            item: item,
            attemptID: attemptID,
            context: context,
            services: services
        ))
        #expect(attempt.state == .fulfilled)
        #expect(buyer.coconutBalance == 0)
        #expect(OasisTreePreferenceStore.injectedEnergy == 100 + OasisTreeEnergyInjectionPolicy.starterPackageXP)
        #expect(!OasisTreePreferenceStore.hasAppliedShopEnergyPurchase(attemptID))

        _ = OasisTreePreferenceStore.checkpointShopEnergyPurchase(
            attemptID,
            currentInjectedEnergy: OasisTreePreferenceStore.injectedEnergy
        )
        #expect(OasisTreePreferenceStore.hasAppliedShopEnergyPurchase(attemptID))
        #expect(ShopPurchaseRecoveryService.settleRecoverable(
            context: context,
            services: services
        ).isEmpty)
        #expect(!OasisTreePreferenceStore.hasAppliedShopEnergyPurchase(attemptID))

        attempt.state = .fulfilling
        attempt.fulfilledAt = nil
        try context.save()
        #expect(services.shopPurchaseFulfillment.fulfillConsumable(
            item: item,
            attemptID: attemptID,
            context: context,
            services: services
        ))

        #expect(attempt.state == .fulfilled)
        #expect(OasisTreePreferenceStore.injectedEnergy == 100 + OasisTreeEnergyInjectionPolicy.starterPackageXP)
        let walletEntries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(walletEntries.count(where: { $0.source == .shop && $0.delta < 0 }) == 1)
        let treeEvents = try context.fetch(FetchDescriptor<CareLedgerEvent>()).filter {
            $0.sourceEventId == attemptID.uuidString
        }
        #expect(treeEvents.count == 1)
    }

    @Test func fulfillmentPayloadStoresDeltaInsteadOfAggregateTarget() throws {
        let payload = ShopPurchaseFulfillmentPayload(
            purchasedAt: Date(timeIntervalSinceReferenceDate: 42),
            treeEnergyXP: OasisTreeEnergyInjectionPolicy.largePackageXP
        )
        let data = try JSONEncoder().encode(payload)
        let json = try #require(String(data: data, encoding: .utf8))
        let decoded = try JSONDecoder().decode(ShopPurchaseFulfillmentPayload.self, from: data)

        #expect(decoded == payload)
        #expect(decoded.version == ShopPurchaseFulfillmentPayload.currentVersion)
        #expect(json.contains("treeEnergyXP"))
        #expect(!json.contains("targetInjectedEnergy"))
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV92.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func restore(_ value: Any?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
