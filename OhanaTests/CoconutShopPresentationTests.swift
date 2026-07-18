import Foundation
import Testing
@testable import Ohana

struct CoconutShopPresentationTests {
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

    @Test func manualRecoveryOnlyOffersRetryWhenAStoredPrerequisiteCanChange() {
        for reason in [
            "catalogItemMissing",
            "missingFundingSnapshot",
            "invalidFundingSnapshot",
            "missingOrFrozenRefundRecipient",
            "manualRecoveryPersistenceFailed"
        ] {
            #expect(ShopManualRecoveryActionPolicy.canRetry(reasonCode: reason))
        }

        for reason in [
            "catalogPriceChanged",
            "invalidPurchaseSnapshot",
            "legacyFulfillmentUnverifiable",
            "unsupportedFulfillmentKind",
            "legacyUnknownFailure"
        ] {
            #expect(!ShopManualRecoveryActionPolicy.canRetry(reasonCode: reason))
        }
        #expect(!ShopManualRecoveryActionPolicy.canRetry(reasonCode: nil))
    }

    @Test func refundFundingSnapshotRequiresPositiveUniqueExactContributions() {
        let first = UUID()
        let second = UUID()
        #expect(ShopPurchaseFundingSnapshotValidator.isValid([
            ShopPurchaseFundingContribution(humanID: first, amount: 100),
            ShopPurchaseFundingContribution(humanID: second, amount: 200)
        ], expectedTotal: 300))
        #expect(!ShopPurchaseFundingSnapshotValidator.isValid([
            ShopPurchaseFundingContribution(humanID: first, amount: 150),
            ShopPurchaseFundingContribution(humanID: first, amount: 150)
        ], expectedTotal: 300))
        #expect(!ShopPurchaseFundingSnapshotValidator.isValid([
            ShopPurchaseFundingContribution(humanID: first, amount: -1),
            ShopPurchaseFundingContribution(humanID: second, amount: 301)
        ], expectedTotal: 300))
        #expect(!ShopPurchaseFundingSnapshotValidator.isValid([
            ShopPurchaseFundingContribution(humanID: first, amount: Int.max),
            ShopPurchaseFundingContribution(humanID: second, amount: 1)
        ], expectedTotal: Int.max))
    }
}
