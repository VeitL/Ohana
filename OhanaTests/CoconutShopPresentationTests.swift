import Foundation
import Testing
@testable import Ohana

struct CoconutShopPresentationTests {
    @Test func categoryRoutesMapToTheSinglePageSections() {
        #expect(ShopShelfSection.destination(for: .plantDecor) == .oasis)
        #expect(ShopShelfSection.destination(for: .appIcon) == .appIcons)
        #expect(ShopShelfSection.destination(for: .effect) == .members)
        #expect(ShopShelfSection.destination(for: .avatar2d) == .members)
        for category in [ShopItem.ShopCategory.title_, .boost, .cashExchange] {
            #expect(ShopShelfSection.destination(for: category) == .oasis)
        }
        #expect(ShopShelfSection.allCases.flatMap { section in
            ShopCatalog.allItems().filter(section.contains)
        }.map(\.id) == ShopCatalog.allItems().map(\.id))
    }

    @Test func readinessNeverTreatsLoadingOrFailedDataAsZeroBalance() {
        #expect(
            ShopPurchaseReadiness.resolve(
                dataState: .loading,
                hasBuyer: true,
                buyerCanWrite: true,
                spendableBalance: 0,
                cost: 300
            ) == .loading
        )
        #expect(
            ShopPurchaseReadiness.resolve(
                dataState: .failed,
                hasBuyer: true,
                buyerCanWrite: true,
                spendableBalance: 0,
                cost: 300
            ) == .loading
        )
    }

    @Test func readinessRequiresAnActiveWritableBuyer() {
        #expect(
            ShopPurchaseReadiness.resolve(
                dataState: .loaded,
                hasBuyer: false,
                buyerCanWrite: false,
                spendableBalance: 500,
                cost: 300
            ) == .missingBuyer
        )
        #expect(
            ShopPurchaseReadiness.resolve(
                dataState: .loaded,
                hasBuyer: true,
                buyerCanWrite: false,
                spendableBalance: 500,
                cost: 300
            ) == .walletFrozen
        )
    }

    @Test func readinessUsesIslandSpendableBalanceAndReportsExactShortfall() {
        #expect(
            ShopPurchaseReadiness.resolve(
                dataState: .loaded,
                hasBuyer: true,
                buyerCanWrite: true,
                spendableBalance: 500,
                cost: 300
            ) == .ready
        )
        #expect(
            ShopPurchaseReadiness.resolve(
                dataState: .loaded,
                hasBuyer: true,
                buyerCanWrite: true,
                spendableBalance: 120,
                cost: 300
            ) == .insufficient(missing: 180)
        )
    }

    @Test func manualRecoveryOffersRetryForRecoverableFinalSaleStates() {
        for reason in [
            "catalogItemMissing",
            "catalogPriceChanged",
            "unsupportedFulfillmentKind",
            "missingFundingSnapshot",
            "invalidFundingSnapshot",
            "missingOrFrozenRefundRecipient",
            "invalidPurchaseSnapshot",
            "manualRecoveryPersistenceFailed"
        ] {
            #expect(ShopManualRecoveryActionPolicy.canRetry(reasonCode: reason))
        }

        for reason in [
            "legacyFulfillmentUnverifiable",
            "legacyUnknownFailure"
        ] {
            #expect(!ShopManualRecoveryActionPolicy.canRetry(reasonCode: reason))
        }
        #expect(!ShopManualRecoveryActionPolicy.canRetry(reasonCode: nil))
    }

    @Test func limeGlowOnlyAppliesToActivePetCards() {
        #expect(HomeShopEffectPresentationPolicy.showsLimeGlow(
            isEquipped: true,
            isHuman: false,
            isElectronicPet: false,
            hasPassedAway: false
        ))
        #expect(!HomeShopEffectPresentationPolicy.showsLimeGlow(
            isEquipped: false,
            isHuman: false,
            isElectronicPet: false,
            hasPassedAway: false
        ))
        #expect(!HomeShopEffectPresentationPolicy.showsLimeGlow(
            isEquipped: true,
            isHuman: true,
            isElectronicPet: false,
            hasPassedAway: false
        ))
        #expect(!HomeShopEffectPresentationPolicy.showsLimeGlow(
            isEquipped: true,
            isHuman: false,
            isElectronicPet: true,
            hasPassedAway: false
        ))
        #expect(!HomeShopEffectPresentationPolicy.showsLimeGlow(
            isEquipped: true,
            isHuman: false,
            isElectronicPet: false,
            hasPassedAway: true
        ))
    }
}
