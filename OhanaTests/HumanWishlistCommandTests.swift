import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HumanWishlistCommandTests {
    @Test func redeemWishlistItemSpendsHumanCoconutsThroughShopLedger() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let human = Human(name: "Ava")
        human.coconutBalance = 25
        context.insert(human)
        try context.save()
        try CoconutEconomyBootstrapService.bootstrapIfNeeded(
            context: context,
            legacyIslandCount: human.coconutBalance,
            legacyLogsJSON: "[]"
        )

        let create = try HumanWishlistCommandService.createItem(
            input: HumanWishlistCommandInput(title: "Headphones", cost: 10),
            for: human,
            context: context
        )
        #expect(create.coconutDelta == 0)
        #expect(CoconutWalletService.balance(for: human, context: context) == 25)

        let item = try #require(try context.fetch(FetchDescriptor<WishlistItem>()).first)
        let redeem = try HumanWishlistCommandService.redeemItem(
            item,
            for: human,
            redeemedById: human.id.uuidString,
            context: context
        )

        #expect(redeem.itemID == item.id)
        #expect(redeem.coconutDelta == -10)
        #expect(redeem.isRedeemed)
        #expect(item.isRedeemed)
        #expect(item.redeemedById == human.id.uuidString)
        #expect(CoconutWalletService.balance(for: human, context: context) == 15)

        let careLedger = try #require(try context.fetch(FetchDescriptor<CareLedgerEvent>()).first {
            $0.eventKind == CareLedgerEventKind.coconut.rawValue &&
                $0.actionType == "humanWishlistRedeem" &&
                $0.legacyModelName == "WishlistItem" &&
                $0.legacyModelId == item.id.uuidString
        })
        #expect(careLedger.source == CareLedgerSource.economy.rawValue)
        #expect(careLedger.actorId == human.id.uuidString)
        #expect(careLedger.subjectId == human.id.uuidString)
        #expect(careLedger.coconutDelta == -10)
        #expect(careLedger.privacyFieldRaw == HumanPrivateField.wishlist.rawValue)

        let walletSpend = try #require(try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).first {
            $0.transactionKey == "wishlist:\(item.id.uuidString):redeem"
        })
        #expect(walletSpend.ownerId == human.id.uuidString)
        #expect(walletSpend.delta == -10)
        #expect(walletSpend.balanceBefore == 25)
        #expect(walletSpend.balanceAfter == 15)
        #expect(walletSpend.entryKind == .spend)
        #expect(walletSpend.source == .shop)
        #expect(walletSpend.sourceModelName == "WishlistItem")
        #expect(walletSpend.sourceModelId == item.id.uuidString)
        #expect(walletSpend.careLedgerEventId == careLedger.id.uuidString)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV82.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
