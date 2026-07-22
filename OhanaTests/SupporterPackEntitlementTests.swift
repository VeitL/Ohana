import Foundation
import Testing
@testable import Ohana

@Suite("Personal StoreKit entitlement")
@MainActor
struct SupporterPackEntitlementTests {
    @Test func compatibilityPurchaseBuysPersonalLifetimeAndFinishesTransaction() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        await storefront.setPurchaseResult(.success(.verified(activeTransaction(id: 11))))
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)

        await service.start()
        let outcome = await service.purchaseSupporterPack()

        #expect(outcome == .purchased)
        #expect(service.hasPersonalEntitlement)
        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .ownedVerified)
        #expect(service.displayPrice == "$49.99")
        #expect(service.displayPrice(for: .monthly) == "$2.99")
        #expect(service.displayPrice(for: .yearly) == "$14.99")
        #expect(service.displayPrice(for: .lifetime) == "$49.99")
        #expect(!service.isEligibleForIntroOffer(for: .monthly))
        #expect(service.isEligibleForIntroOffer(for: .yearly))
        #expect(!service.isEligibleForIntroOffer(for: .lifetime))
        #expect(service.activePersonalPurchaseChoices == [.lifetime])
        #expect(cache.cachedSupporterPackEntitlement())
        #expect(await storefront.finishedTransactionIDs() == [11])
        #expect(await storefront.entitlementInvocationCount() == 2)
        #expect(service.lastErrorMessage == nil)
    }

    @Test func monthlyAndYearlyChoicesPurchaseTheirOwnSubscriptions() async {
        for (offset, choice) in [PersonalPurchaseChoice.monthly, .yearly].enumerated() {
            let storefront = TestCommerceStorefront()
            let transaction = CommerceStorefrontTransaction(
                id: UInt64(100 + offset),
                productID: choice.productID,
                kind: .autoRenewableSubscription,
                revocationDate: nil,
                expirationDate: .distantFuture
            )
            await storefront.setPurchaseResult(.success(.verified(transaction)))
            let service = CommerceEntitlementService(
                storefront: storefront,
                persistence: TestCommerceEntitlementCache(initialValue: false)
            )

            await service.start()
            let outcome = await service.purchasePersonal(choice)

            #expect(outcome == .purchased)
            #expect(service.hasPersonalEntitlement)
            #expect(service.activePersonalPurchaseChoices == [choice])
            #expect(await storefront.purchaseInvocations() == [choice.productID])
            #expect(await storefront.finishedTransactionIDs() == [transaction.id])
        }
    }

    @Test func familyYearlyInheritsPersonalAndUsesAnIndependentVerifiedCache() async {
        let storefront = TestCommerceStorefront()
        let family = CommerceStorefrontTransaction(
            id: 119,
            productID: SupporterPackCatalog.familyYearlyProductID,
            kind: .autoRenewableSubscription,
            revocationDate: nil,
            expirationDate: .distantFuture
        )
        await storefront.setPurchaseResult(.success(.verified(family)))
        let cache = TestCommerceEntitlementCache(initialValue: false)
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: cache,
            familyPurchasesEnabled: { true }
        )

        await service.start()
        let outcome = await service.purchaseFamilyYearly()

        #expect(outcome == .purchased)
        #expect(service.hasFamilyEntitlement)
        #expect(service.hasPersonalEntitlement)
        #expect(service.ohanaPlanLevel == .family)
        #expect(service.familyDisplayPrice == "$39.99")
        #expect(service.activeFamilyProductIDs == [SupporterPackCatalog.familyYearlyProductID])
        #expect(cache.cachedFamilyEntitlement())
        #expect(!cache.cachedSupporterPackEntitlement())
    }

    @Test func familyPurchaseIsFailClosedWhenGuardianRuntimeIsDisabled() async {
        let storefront = TestCommerceStorefront()
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false),
            familyPurchasesEnabled: { false }
        )

        await service.start()
        let outcome = await service.purchaseFamilyYearly()

        #expect(outcome == .failed)
        #expect(!service.hasFamilyEntitlement)
        #expect(service.familyDisplayPrice == nil)
        #expect(await storefront.purchaseInvocations().isEmpty)
    }

    @Test func expiredFamilyFallsBackToAnIndependentPersonalLifetimeEntitlement() async {
        let storefront = TestCommerceStorefront()
        let expiredFamily = CommerceStorefrontTransaction(
            id: 121,
            productID: SupporterPackCatalog.familyYearlyProductID,
            kind: .autoRenewableSubscription,
            revocationDate: nil,
            expirationDate: .distantPast
        )
        await storefront.setCurrentEntitlements([
            .verified(expiredFamily),
            .verified(activeTransaction(id: 122))
        ])
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )

        await service.start()

        #expect(!service.hasFamilyEntitlement)
        #expect(service.hasPersonalEntitlement)
        #expect(service.ohanaPlanLevel == .personal)
    }

    @Test func legacySupporterPackIsGrandfatheredAsPersonalLifetime() async {
        let storefront = TestCommerceStorefront()
        let legacy = CommerceStorefrontTransaction(
            id: 120,
            productID: SupporterPackCatalog.productID,
            revocationDate: nil
        )
        await storefront.setCurrentEntitlements([.verified(legacy)])
        let cache = TestCommerceEntitlementCache(initialValue: false)
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)

        await service.start()

        #expect(service.hasPersonalEntitlement)
        #expect(service.hasSupporterPack)
        #expect(service.hasLegacySupporterPackEntitlement)
        #expect(service.activePersonalPurchaseChoices == [.lifetime])
        #expect(cache.cachedSupporterPackEntitlement())
    }

    @Test func expiredSubscriptionDoesNotUnlockOrKeepTheOfflineCache() async {
        let storefront = TestCommerceStorefront()
        let expired = CommerceStorefrontTransaction(
            id: 130,
            productID: SupporterPackCatalog.personalYearlyProductID,
            kind: .autoRenewableSubscription,
            revocationDate: nil,
            expirationDate: .distantPast
        )
        await storefront.setCurrentEntitlements([.verified(expired)])
        let cache = TestCommerceEntitlementCache(initialValue: true)
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)

        await service.start()

        #expect(!service.hasPersonalEntitlement)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
    }

    @Test func storefrontCurrentEntitlementPreservesAppleGrantedGraceAccess() async {
        let storefront = TestCommerceStorefront()
        let graceEntitlement = CommerceStorefrontTransaction(
            id: 131,
            productID: SupporterPackCatalog.personalYearlyProductID,
            kind: .autoRenewableSubscription,
            revocationDate: nil,
            expirationDate: .distantPast,
            isCurrentEntitlement: true
        )
        await storefront.setCurrentEntitlements([.verified(graceEntitlement)])
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )

        await service.start()

        #expect(service.hasPersonalEntitlement)
        #expect(service.entitlementStatus == .ownedVerified)
        #expect(service.activePersonalPurchaseChoices == [.yearly])
    }

    @Test func revokingOneChoiceKeepsAnotherVerifiedChoiceActive() async {
        let storefront = TestCommerceStorefront()
        let monthly = CommerceStorefrontTransaction(
            id: 140,
            productID: SupporterPackCatalog.personalMonthlyProductID,
            kind: .autoRenewableSubscription,
            revocationDate: nil,
            expirationDate: .distantFuture
        )
        let lifetime = activeTransaction(id: 141)
        await storefront.setCurrentEntitlements([.verified(monthly), .verified(lifetime)])
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        #expect(service.activePersonalPurchaseChoices == [.monthly, .lifetime])

        let revokedMonthly = CommerceStorefrontTransaction(
            id: 142,
            productID: SupporterPackCatalog.personalMonthlyProductID,
            kind: .autoRenewableSubscription,
            revocationDate: Date(),
            expirationDate: .distantFuture
        )
        await storefront.sendUpdate(.verified(revokedMonthly))
        await waitUntil {
            !service.activePersonalProductIDs.contains(SupporterPackCatalog.personalMonthlyProductID)
        }

        #expect(service.hasPersonalEntitlement)
        #expect(service.activePersonalPurchaseChoices == [.lifetime])
        #expect(await storefront.finishedTransactionIDs() == [142])
    }

    @Test func unverifiedPurchaseNeverUnlocksOrFinishes() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        await storefront.setPurchaseResult(.success(.unverified(
            productID: SupporterPackCatalog.personalLifetimeProductID
        )))
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)

        await service.start()
        let outcome = await service.purchaseSupporterPack()

        #expect(outcome == .failed)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
        #expect(await storefront.finishedTransactionIDs().isEmpty)
        #expect(service.lastErrorMessage != nil)
    }

    @Test func verifiedTransactionWithWrongProductTypeNeverUnlocksOrFinishes() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        await storefront.setPurchaseResult(.success(.verified(
            CommerceStorefrontTransaction(
                id: 12,
                productID: SupporterPackCatalog.personalLifetimeProductID,
                isNonConsumable: false,
                revocationDate: nil
            )
        )))
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)

        await service.start()
        let outcome = await service.purchaseSupporterPack()

        #expect(outcome == .failed)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
        #expect(await storefront.finishedTransactionIDs().isEmpty)
        #expect(service.lastErrorMessage != nil)
    }

    @Test func familySharedTransactionNeverUnlocksTheNonSharedPack() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        await storefront.setPurchaseResult(.success(.verified(
            CommerceStorefrontTransaction(
                id: 13,
                productID: SupporterPackCatalog.personalLifetimeProductID,
                isDirectPurchase: false,
                revocationDate: nil
            )
        )))
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)

        await service.start()
        let outcome = await service.purchaseSupporterPack()

        #expect(outcome == .failed)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
        #expect(await storefront.finishedTransactionIDs().isEmpty)
        #expect(service.lastErrorMessage != nil)
    }

    @Test func pendingPreventsASecondStorefrontPurchase() async {
        let storefront = TestCommerceStorefront()
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()

        await storefront.setPurchaseResult(.pending)
        #expect(await service.purchaseSupporterPack() == .pending)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(service.isPurchasePending)
        #expect(service.lastErrorMessage == nil)
        #expect(await storefront.purchaseInvocationCount() == 1)

        #expect(await service.purchaseSupporterPack() == .pending)
        #expect(await storefront.purchaseInvocationCount() == 1)
    }

    @Test func explicitRestoreClearsDeclinedPendingStateWhenNoPurchaseExists() async {
        let storefront = TestCommerceStorefront()
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        await storefront.setPurchaseResult(.pending)
        #expect(await service.purchaseSupporterPack() == .pending)
        #expect(service.isPurchasePending)

        let outcome = await service.restorePurchases()

        #expect(outcome == .noPurchases)
        #expect(!service.isPurchasePending)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
    }

    @Test func cancellationRemainsNonEntitledWithoutAnError() async {
        let storefront = TestCommerceStorefront()
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        await storefront.setPurchaseResult(.userCancelled)

        #expect(await service.purchaseSupporterPack() == .cancelled)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!service.isPurchasePending)
        #expect(service.lastErrorMessage == nil)
    }

    @Test func storefrontPurchaseFailureLeavesFreeAppAndEntitlementUntouched() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)
        await service.start()
        await storefront.setOffline(true)

        #expect(await service.purchaseSupporterPack() == .failed)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
        #expect(service.lastErrorMessage != nil)
    }

    @Test func pendingTransactionUpdateUnlocksAndReenablesPurchaseState() async {
        let storefront = TestCommerceStorefront()
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        await storefront.setPurchaseResult(.pending)
        #expect(await service.purchaseSupporterPack() == .pending)
        #expect(service.isPurchasePending)

        await storefront.sendUpdate(.verified(activeTransaction(id: 15)))
        await waitUntil { service.hasSupporterPack }

        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .ownedVerified)
        #expect(!service.isPurchasePending)
        #expect(await storefront.finishedTransactionIDs() == [15])
    }

    @Test func verifiedRevocationUpdateRemovesCachedEntitlementAndFinishes() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: true)
        let legacy = CommerceStorefrontTransaction(
            id: 20,
            productID: SupporterPackCatalog.productID,
            revocationDate: nil
        )
        await storefront.setCurrentEntitlements([.verified(legacy)])
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)
        await service.start()
        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .ownedVerified)

        let revoked = CommerceStorefrontTransaction(
            id: 21,
            productID: SupporterPackCatalog.productID,
            revocationDate: Date(timeIntervalSince1970: 1000)
        )
        await storefront.sendUpdate(.verified(revoked))
        await waitUntil { !service.hasSupporterPack }

        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
        #expect(await storefront.finishedTransactionIDs() == [21])
    }

    @Test func restoreSyncRefreshesVerifiedEntitlement() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        await storefront.setEntitlementsAfterSync([.verified(activeTransaction(id: 30))])
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)
        await service.start()
        #expect(!service.hasSupporterPack)

        let outcome = await service.restorePurchases()

        #expect(outcome == .restored)
        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .ownedVerified)
        #expect(cache.cachedSupporterPackEntitlement())
        #expect(await storefront.syncInvocationCount() == 1)
        #expect(service.lastErrorMessage == nil)
    }

    @Test func restoreWithNoPurchaseReportsAnExplicitEmptyResult() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)
        await service.start()

        let outcome = await service.restorePurchases()

        #expect(outcome == .noPurchases)
        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
        #expect(await storefront.syncInvocationCount() == 1)
        #expect(service.lastErrorMessage == nil)
    }

    @Test func foregroundRefreshDoesNotPolluteAnInFlightRestoreOutcome() async {
        let storefront = TestCommerceStorefront()
        await storefront.setEntitlementsAfterSync([.verified(activeTransaction(id: 35))])
        await storefront.setSyncDelay(nanoseconds: 80_000_000)
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()

        let restore = Task { @MainActor in
            await service.restorePurchases()
        }
        let restoreStarted = await waitUntilAsync {
            await storefront.syncInvocationCount() == 1
        }
        #expect(restoreStarted)
        let entitlementCallsBeforeForeground = await storefront.entitlementInvocationCount()

        await service.refreshEntitlements()
        let outcome = await restore.value

        #expect(outcome == .restored)
        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .ownedVerified)
        #expect(await storefront.entitlementInvocationCount() == entitlementCallsBeforeForeground + 1)
    }

    @Test func foregroundRefreshAppliesVerifiedRevocation() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: false)
        await storefront.setCurrentEntitlements([.verified(activeTransaction(id: 40))])
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)
        await service.start()
        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .ownedVerified)

        let revoked = CommerceStorefrontTransaction(
            id: 41,
            productID: SupporterPackCatalog.personalLifetimeProductID,
            revocationDate: Date(timeIntervalSince1970: 2000)
        )
        await storefront.setCurrentEntitlements([.verified(revoked)])
        await service.refreshEntitlements()

        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
        #expect(!cache.cachedSupporterPackEntitlement())
    }

    @Test func newerEntitlementRefreshCannotBeOverwrittenByAnOlderSnapshot() async {
        let storefront = TestCommerceStorefront()
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        await storefront.enqueueEntitlementResponse(
            [.verified(activeTransaction(id: 45))],
            delayNanoseconds: 80_000_000
        )
        await storefront.enqueueEntitlementResponse([], delayNanoseconds: 0)

        let olderRefresh = Task { @MainActor in
            await service.refreshEntitlements()
        }
        let olderRefreshStarted = await waitUntilAsync {
            await storefront.entitlementInvocationCount() >= 2
        }
        #expect(olderRefreshStarted)
        let newerRefresh = Task { @MainActor in
            await service.refreshEntitlements()
        }
        await olderRefresh.value
        await newerRefresh.value

        #expect(!service.hasSupporterPack)
        #expect(service.entitlementStatus == .notOwnedVerified)
    }

    @Test func restoreWithOnlyUnverifiedResultPreservesCacheButDoesNotClaimSuccess() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: true)
        await storefront.setCurrentEntitlements([.verified(activeTransaction(id: 50))])
        await storefront.setEntitlementsAfterSync([.unverified(
            productID: SupporterPackCatalog.personalLifetimeProductID
        )])
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)
        await service.start()
        #expect(service.entitlementStatus == .ownedVerified)

        let outcome = await service.restorePurchases()

        #expect(outcome == .failed)
        #expect(service.hasSupporterPack)
        #expect(cache.cachedSupporterPackEntitlement())
        #expect(service.entitlementStatus == .temporarilyUnknown)
        #expect(service.lastErrorMessage != nil)
    }

    @Test func restoreFailureNeverClaimsCachedEntitlementWasRestored() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: true)
        await storefront.setCurrentEntitlements([.verified(activeTransaction(id: 55))])
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)
        await service.start()
        #expect(service.entitlementStatus == .ownedVerified)
        await storefront.setOffline(true)

        let outcome = await service.restorePurchases()

        #expect(outcome == .failed)
        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .temporarilyUnknown)
        #expect(service.lastErrorMessage != nil)
    }

    @Test func explicitProductReloadRecoversStoreKitDisplayPrice() async {
        let storefront = TestCommerceStorefront()
        await storefront.setOffline(true)
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        #expect(service.displayPrice == nil)

        await storefront.setOffline(false)
        await service.reloadSupporterProduct()

        #expect(service.displayPrice == "$49.99")
        #expect(service.lastErrorMessage == nil)
    }

    @Test func storefrontChangeReloadsLocalizedProductsAndRevalidatesEntitlement() async {
        let storefront = TestCommerceStorefront()
        await storefront.setCurrentEntitlements([.verified(activeTransaction(id: 57))])
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        #expect(service.displayPrice == "$49.99")
        #expect(service.entitlementStatus == .ownedVerified)

        let entitlementCallsBeforeChange = await storefront.entitlementInvocationCount()
        await storefront.setProductDisplayPrices(
            monthly: "2,99 \u{20AC}",
            yearly: "14,99 \u{20AC}",
            lifetime: "49,99 \u{20AC}"
        )
        await storefront.sendStorefrontUpdate()
        await waitUntil {
            service.displayPrice == "49,99 \u{20AC}"
        }

        #expect(service.displayPrice(for: .monthly) == "2,99 \u{20AC}")
        #expect(service.displayPrice(for: .yearly) == "14,99 \u{20AC}")
        #expect(service.displayPrice(for: .lifetime) == "49,99 \u{20AC}")
        #expect(service.hasPersonalEntitlement)
        #expect(service.entitlementStatus == .ownedVerified)
        #expect(await storefront.entitlementInvocationCount() == entitlementCallsBeforeChange + 1)
    }

    @Test func foregroundRefreshReloadsSameStorefrontAccountOfferEligibility() async {
        let storefront = TestCommerceStorefront()
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )
        await service.start()
        #expect(service.isEligibleForIntroOffer(for: .yearly))
        let productCallsBeforeRefresh = await storefront.productInvocationCount()

        await storefront.setYearlyIntroOfferEligible(false)
        await service.refreshEntitlements()

        #expect(!service.isEligibleForIntroOffer(for: .yearly))
        #expect(await storefront.productInvocationCount() == productCallsBeforeRefresh + 1)
        #expect(service.entitlementStatus == .notOwnedVerified)
    }

    @Test func ineligibleYearlySubscriberIsNotOfferedTheIntroductoryTrial() async {
        let storefront = TestCommerceStorefront()
        await storefront.setYearlyIntroOfferEligible(false)
        let service = CommerceEntitlementService(
            storefront: storefront,
            persistence: TestCommerceEntitlementCache(initialValue: false)
        )

        await service.start()

        #expect(service.displayPrice(for: .yearly) == "$14.99")
        #expect(!service.isEligibleForIntroOffer(for: .yearly))
    }

    @Test func offlineStorefrontPreservesLastVerifiedCacheAndDoesNotBlockStart() async {
        let storefront = TestCommerceStorefront()
        let cache = TestCommerceEntitlementCache(initialValue: true)
        await storefront.setOffline(true)
        let service = CommerceEntitlementService(storefront: storefront, persistence: cache)

        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .temporarilyUnknown)

        await service.start()

        #expect(service.hasSupporterPack)
        #expect(service.entitlementStatus == .temporarilyUnknown)
        #expect(cache.cachedSupporterPackEntitlement())
        #expect(service.displayPrice == nil)
        #expect(!service.isLoadingProduct)
        #expect(service.lastErrorMessage == nil)
    }

    @Test func verifiedCacheSurvivesServiceRelaunchWhileStoreKitIsOffline() async {
        let cache = TestCommerceEntitlementCache(initialValue: false)
        do {
            let purchasingStorefront = TestCommerceStorefront()
            await purchasingStorefront.setPurchaseResult(.success(.verified(activeTransaction(id: 60))))
            let purchasingService = CommerceEntitlementService(
                storefront: purchasingStorefront,
                persistence: cache
            )
            await purchasingService.start()
            #expect(await purchasingService.purchaseSupporterPack() == .purchased)
            #expect(cache.cachedSupporterPackEntitlement())
        }

        let offlineStorefront = TestCommerceStorefront()
        await offlineStorefront.setOffline(true)
        let relaunchedService = CommerceEntitlementService(
            storefront: offlineStorefront,
            persistence: cache
        )
        await relaunchedService.start()

        #expect(relaunchedService.hasSupporterPack)
        #expect(relaunchedService.entitlementStatus == .temporarilyUnknown)
        #expect(cache.cachedSupporterPackEntitlement())
    }

    private func activeTransaction(id: UInt64) -> CommerceStorefrontTransaction {
        CommerceStorefrontTransaction(
            id: id,
            productID: SupporterPackCatalog.personalLifetimeProductID,
            revocationDate: nil
        )
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0 ..< 50 {
            if condition() { return }
            await Task.yield()
        }
    }

    private func waitUntilAsync(_ condition: () async -> Bool) async -> Bool {
        for _ in 0 ..< 100 {
            if await condition() { return true }
            await Task.yield()
        }
        return false
    }
}

private nonisolated enum TestCommerceError: LocalizedError {
    case offline

    var errorDescription: String? { "Offline" }
}

private final nonisolated class TestCommerceEntitlementCache: CommerceEntitlementPersisting, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool
    private var familyValue: Bool

    init(initialValue: Bool, familyValue: Bool = false) {
        value = initialValue
        self.familyValue = familyValue
    }

    func cachedSupporterPackEntitlement() -> Bool {
        lock.withLock { value }
    }

    func setCachedSupporterPackEntitlement(_ isEntitled: Bool) {
        lock.withLock { value = isEntitled }
    }

    func cachedFamilyEntitlement() -> Bool {
        lock.withLock { familyValue }
    }

    func setCachedFamilyEntitlement(_ isEntitled: Bool) {
        lock.withLock { familyValue = isEntitled }
    }
}

private actor TestCommerceStorefront: CommerceStorefrontClient {
    private var purchaseResult: CommerceStorefrontPurchaseResult = .pending
    private var current: [CommerceStorefrontVerification] = []
    private var queuedEntitlementResponses: [(delayNanoseconds: UInt64, verifications: [CommerceStorefrontVerification])] = []
    private var entitlementsAfterSync: [CommerceStorefrontVerification]?
    private var finishedIDs: [UInt64] = []
    private var purchasedProductIDs: [String] = []
    private var purchaseCount = 0
    private var productCount = 0
    private var syncCount = 0
    private var entitlementCount = 0
    private var syncDelayNanoseconds: UInt64 = 0
    private var isOffline = false
    private var isYearlyIntroOfferEligible = true
    private var monthlyDisplayPrice = "$2.99"
    private var yearlyDisplayPrice = "$14.99"
    private var lifetimeDisplayPrice = "$49.99"
    private var familyDisplayPrice = "$39.99"
    private let storefrontUpdateStream: AsyncStream<Void>
    private let storefrontUpdateContinuation: AsyncStream<Void>.Continuation
    private let updateStream: AsyncStream<CommerceStorefrontVerification>
    private let updateContinuation: AsyncStream<CommerceStorefrontVerification>.Continuation

    init() {
        let storefrontStream = AsyncStream<Void>.makeStream()
        storefrontUpdateStream = storefrontStream.stream
        storefrontUpdateContinuation = storefrontStream.continuation
        let stream = AsyncStream<CommerceStorefrontVerification>.makeStream()
        updateStream = stream.stream
        updateContinuation = stream.continuation
    }

    func products(for identifiers: Set<String>) async throws -> [CommerceStorefrontProduct] {
        if isOffline { throw TestCommerceError.offline }
        productCount += 1
        let products = [
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalMonthlyProductID,
                displayPrice: monthlyDisplayPrice,
                kind: .autoRenewableSubscription
            ),
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalYearlyProductID,
                displayPrice: yearlyDisplayPrice,
                kind: .autoRenewableSubscription,
                isEligibleForIntroOffer: isYearlyIntroOfferEligible
            ),
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalLifetimeProductID,
                displayPrice: lifetimeDisplayPrice
            ),
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.familyYearlyProductID,
                displayPrice: familyDisplayPrice,
                kind: .autoRenewableSubscription
            )
        ]
        return products.filter { identifiers.contains($0.id) }
    }

    func purchase(productID: String) async throws -> CommerceStorefrontPurchaseResult {
        if isOffline { throw TestCommerceError.offline }
        purchaseCount += 1
        purchasedProductIDs.append(productID)
        if case let .success(.verified(transaction)) = purchaseResult {
            applyToCurrentEntitlements(transaction)
        }
        return purchaseResult
    }

    func currentEntitlements(productID: String) async throws -> [CommerceStorefrontVerification] {
        if isOffline { throw TestCommerceError.offline }
        entitlementCount += 1
        if !queuedEntitlementResponses.isEmpty {
            let response = queuedEntitlementResponses.removeFirst()
            if response.delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: response.delayNanoseconds)
            }
            return response.verifications
        }
        return current
    }

    func currentEntitlements(productIDs: Set<String>) async throws -> [CommerceStorefrontVerification] {
        if isOffline { throw TestCommerceError.offline }
        entitlementCount += 1
        let response: [CommerceStorefrontVerification]
        if !queuedEntitlementResponses.isEmpty {
            let queued = queuedEntitlementResponses.removeFirst()
            if queued.delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: queued.delayNanoseconds)
            }
            response = queued.verifications
        } else {
            response = current
        }
        return response.filter { verification in
            switch verification {
            case let .verified(transaction):
                productIDs.contains(transaction.productID)
            case let .unverified(productID):
                productID.map(productIDs.contains) == true
            }
        }
    }

    func storefrontUpdates() async -> AsyncStream<Void> {
        storefrontUpdateStream
    }

    func transactionUpdates() async -> AsyncStream<CommerceStorefrontVerification> {
        updateStream
    }

    func finish(transactionID: UInt64) async {
        finishedIDs.append(transactionID)
    }

    func sync() async throws {
        if isOffline { throw TestCommerceError.offline }
        syncCount += 1
        if syncDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: syncDelayNanoseconds)
        }
        if let entitlementsAfterSync {
            current = entitlementsAfterSync
        }
    }

    func setPurchaseResult(_ result: CommerceStorefrontPurchaseResult) {
        purchaseResult = result
    }

    func setCurrentEntitlements(_ verifications: [CommerceStorefrontVerification]) {
        current = verifications
    }

    func enqueueEntitlementResponse(
        _ verifications: [CommerceStorefrontVerification],
        delayNanoseconds: UInt64
    ) {
        queuedEntitlementResponses.append((delayNanoseconds, verifications))
    }

    func setEntitlementsAfterSync(_ verifications: [CommerceStorefrontVerification]) {
        entitlementsAfterSync = verifications
    }

    func setSyncDelay(nanoseconds: UInt64) {
        syncDelayNanoseconds = nanoseconds
    }

    func setOffline(_ value: Bool) {
        isOffline = value
    }

    func setYearlyIntroOfferEligible(_ value: Bool) {
        isYearlyIntroOfferEligible = value
    }

    func setProductDisplayPrices(monthly: String, yearly: String, lifetime: String) {
        monthlyDisplayPrice = monthly
        yearlyDisplayPrice = yearly
        lifetimeDisplayPrice = lifetime
    }

    func sendStorefrontUpdate() {
        storefrontUpdateContinuation.yield(())
    }

    func sendUpdate(_ update: CommerceStorefrontVerification) {
        if case let .verified(transaction) = update {
            applyToCurrentEntitlements(transaction)
        }
        updateContinuation.yield(update)
    }

    private func applyToCurrentEntitlements(_ transaction: CommerceStorefrontTransaction) {
        current.removeAll { verification in
            guard case let .verified(existing) = verification else { return false }
            return existing.productID == transaction.productID
        }
        let isUnrevoked = transaction.revocationDate == nil
        let isUnexpired = transaction.expirationDate.map { $0 > Date() } ?? true
        if isUnrevoked, isUnexpired || transaction.isCurrentEntitlement {
            current.append(.verified(transaction))
        }
    }

    func finishedTransactionIDs() -> [UInt64] {
        finishedIDs
    }

    func syncInvocationCount() -> Int {
        syncCount
    }

    func purchaseInvocationCount() -> Int {
        purchaseCount
    }

    func productInvocationCount() -> Int {
        productCount
    }

    func purchaseInvocations() -> [String] {
        purchasedProductIDs
    }

    func entitlementInvocationCount() -> Int {
        entitlementCount
    }
}
