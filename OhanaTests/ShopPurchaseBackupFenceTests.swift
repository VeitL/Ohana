import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct ShopPurchaseBackupFenceTests {
    @Test func purchaseFailsWithoutWritesWhileBackupOwnsFence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        human.coconutBalance = item.cost
        context.insert(human)
        try context.save()

        let result = try ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: { throw FenceTestError.unexpectedContention },
            operation: {
                ShopPurchaseCommandService.purchase(
                    item: item,
                    buyer: human,
                    itemName: "Backdate Pack",
                    context: context,
                    wallet: SwiftDataCoconutWalletManager(),
                    careLedger: CareLedgerService()
                )
            }
        )

        #expect(!result.didPurchase)
        #expect(result.failure == .backupOrRestoreInProgress)
        #expect(human.coconutBalance == item.cost)
        #expect(try context.fetchCount(FetchDescriptor<ShopPurchaseAttempt>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<CareLedgerEvent>()) == 0)
    }

    @Test func backupAndRestoreFailImmediatelyWhilePurchaseOwnsFence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let manager = DataBackupManager(defaults: defaults)
        let backup = try manager.buildBackup(context: context)

        let observed = try ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: { throw FenceTestError.unexpectedContention },
            operation: {
                (
                    backup: catchesPendingShopPurchase {
                        _ = try manager.buildBackup(context: context)
                    },
                    restore: catchesPendingShopPurchase {
                        try manager.applyBackup(backup, context: context, projectionManager: nil)
                    }
                )
            }
        )

        #expect(observed.backup)
        #expect(observed.restore)
    }

    @Test func backgroundModelActorFenceBlocksMainActorPurchaseForTheSameContainer() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Guan")
        let item = try #require(ShopCatalog.item(id: "boost_backdate_pack"))
        human.coconutBalance = item.cost
        context.insert(human)
        try context.save()

        let release = DispatchSemaphore(value: 0)
        let (entered, enteredContinuation) = AsyncStream<Bool>.makeStream()
        let holder = ShopFenceHoldingActor(modelContainer: container)
        let holdingTask = Task.detached {
            await holder.holdFence(
                entered: enteredContinuation,
                release: release
            )
        }
        let didEnter = await entered.first(where: { _ in true }) ?? false
        #expect(didEnter)

        let result = ShopPurchaseCommandService.purchase(
            item: item,
            buyer: human,
            itemName: "Backdate Pack",
            context: context,
            wallet: SwiftDataCoconutWalletManager(),
            careLedger: CareLedgerService()
        )
        release.signal()
        let didHoldFence = await holdingTask.value
        #expect(didHoldFence)

        #expect(!result.didPurchase)
        #expect(result.failure == .backupOrRestoreInProgress)
        #expect(human.coconutBalance == item.cost)
        #expect(try context.fetchCount(FetchDescriptor<ShopPurchaseAttempt>()) == 0)
    }

    @Test func directRestoreRejectsAnUnresolvedPurchaseAttempt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (name, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let manager = DataBackupManager(defaults: defaults)
        let backup = try manager.buildBackup(context: context)
        let attempt = makeAttempt(state: .manualReview)
        context.insert(attempt)
        try context.save()

        #expect(catchesPendingShopPurchase {
            try manager.applyBackup(backup, context: context, projectionManager: nil)
        })
        #expect(attempt.state == .manualReview)
        #expect(try context.fetchCount(FetchDescriptor<ShopPurchaseAttempt>()) == 1)
    }

    @Test func avatarMemberSaveCannotConsumeInventoryWhileBackupOwnsFence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let base = AppServices(modelContainer: container)
        let service = MemberCreationService(
            activeHumanSelection: base.activeHumanSelection,
            wallet: base.coconutWallet,
            careLedger: base.careLedger,
            revisions: base.domainRevisions,
            questManager: base.questManager,
            shopInventory: base.shopInventory,
            shopPurchaseFulfillment: base.shopPurchaseFulfillment
        )
        var draft = MemberCreationDraft(kind: .human)
        draft.name = "Ava"
        draft.avatarSource = .avatar2D
        draft.avatarImageData = Data([0x89, 0x50, 0x4E, 0x47])
        draft.hasBirthday = false

        var didReject = false
        try ShopPurchaseBackupFence.withExclusiveAccess(
            context: context,
            unavailable: { throw FenceTestError.unexpectedContention },
            operation: {
                do {
                    _ = try service.save(
                        draft: draft,
                        existingPets: [],
                        existingHumans: [],
                        context: context,
                        countryCode: "CN"
                    )
                } catch let error as MemberCreationError {
                    guard case .saveFailed = error else { return }
                    didReject = true
                }
            }
        )

        #expect(didReject)
        #expect(try context.fetch(FetchDescriptor<Human>()).isEmpty)
    }

    @Test func runtimeAdapterSettlesBeforeRestoreChecksForUnresolvedAttempts() async throws {
        let sourceContainer = try makeContainer()
        let targetContainer = try makeContainer()
        let sourceDefaults = try isolatedDefaults()
        let targetDefaults = try isolatedDefaults()
        defer {
            sourceDefaults.defaults.removePersistentDomain(forName: sourceDefaults.name)
            targetDefaults.defaults.removePersistentDomain(forName: targetDefaults.name)
        }

        let sourceManager = DataBackupManager(defaults: sourceDefaults.defaults)
        let targetManager = DataBackupManager(defaults: targetDefaults.defaults)
        let backup = try sourceManager.buildBackup(context: sourceContainer.mainContext)
        let manifestURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("shop-purchase-fence-\(UUID().uuidString).json")
        try sourceManager.encode(backup).write(to: manifestURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: manifestURL) }

        let targetContext = targetContainer.mainContext
        let attempt = makeAttempt(state: .purchased)
        targetContext.insert(attempt)
        try targetContext.save()
        let adapter = SharedDataBackupManagerAdapter(
            projectionManager: TestCoconutProjection(),
            manager: targetManager
        )
        var didSettle = false
        adapter.registerShopPurchaseSettlement { context in
            didSettle = true
            attempt.state = .fulfilled
            attempt.updatedAt = Date()
            do {
                try context.save()
            } catch {
                Issue.record("Could not save the test settlement: \(error)")
            }
        }

        try await adapter.importJSON(from: manifestURL, context: targetContext, password: nil)

        #expect(didSettle)
        #expect(attempt.state == .fulfilled)
    }

    private func catchesPendingShopPurchase(_ operation: () throws -> Void) -> Bool {
        do {
            try operation()
            return false
        } catch BackupError.pendingShopPurchase {
            return true
        } catch {
            Issue.record("Unexpected error: \(error)")
            return false
        }
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV94.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func isolatedDefaults() throws -> (name: String, defaults: UserDefaults) {
        let name = "ShopPurchaseBackupFenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return (name, defaults)
    }

    private func makeAttempt(state: ShopPurchaseAttemptState) -> ShopPurchaseAttempt {
        let attemptID = UUID()
        return ShopPurchaseAttempt(
            id: attemptID,
            transactionKey: "shop:boost_backdate_pack:test:\(attemptID.uuidString)",
            itemId: "boost_backdate_pack",
            buyerHumanId: UUID().uuidString,
            price: 580,
            state: state
        )
    }
}

private enum FenceTestError: Error {
    case unexpectedContention
}

@ModelActor
private actor ShopFenceHoldingActor {
    func holdFence(
        entered: AsyncStream<Bool>.Continuation,
        release: DispatchSemaphore
    ) -> Bool {
        ShopPurchaseBackupFence.withExclusiveAccess(
            context: modelContext,
            unavailable: {
                entered.yield(false)
                entered.finish()
                return false
            },
            operation: {
                entered.yield(true)
                entered.finish()
                release.wait()
                return true
            }
        )
    }
}

@MainActor
private final class TestCoconutProjection: CoconutProjectionManaging {
    func replaceCoconutProjection(count _: Int, logs _: [CoconutLogEntry]) {}
    func recordWalletProjection(entries _: [CoconutLedgerEntry], postsRewardFeedback _: Bool) {}
}
