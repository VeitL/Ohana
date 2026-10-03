//
//  UITestCommerceFixture.swift
//  Ohana
//
//  Process-local commerce fixture for deterministic UI acceptance tests.
//

import Foundation

#if DEBUG
actor UITestEmptyCommerceStorefront: CommerceStorefrontClient {
    func products(for identifiers: Set<String>) async throws -> [CommerceStorefrontProduct] {
        [
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalMonthlyProductID,
                displayPrice: "$2.99",
                kind: .autoRenewableSubscription
            ),
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalYearlyProductID,
                displayPrice: "$14.99",
                kind: .autoRenewableSubscription,
                isEligibleForIntroOffer: true
            ),
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalLifetimeProductID,
                displayPrice: "$49.99"
            )
        ].filter { identifiers.contains($0.id) }
    }

    func purchase(productID _: String) async throws -> CommerceStorefrontPurchaseResult {
        .userCancelled
    }

    func currentEntitlements(productID _: String) async throws -> [CommerceStorefrontVerification] {
        []
    }

    func currentEntitlements(productIDs _: Set<String>) async throws -> [CommerceStorefrontVerification] {
        []
    }

    func storefrontUpdates() async -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    func transactionUpdates() async -> AsyncStream<CommerceStorefrontVerification> {
        AsyncStream { $0.finish() }
    }

    func finish(transactionID _: UInt64) async {}

    func sync() async throws {}
}

actor UITestOwnedCommerceStorefront: CommerceStorefrontClient {
    func products(for identifiers: Set<String>) async throws -> [CommerceStorefrontProduct] {
        [
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalMonthlyProductID,
                displayPrice: "$2.99",
                kind: .autoRenewableSubscription
            ),
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalYearlyProductID,
                displayPrice: "$14.99",
                kind: .autoRenewableSubscription,
                isEligibleForIntroOffer: true
            ),
            CommerceStorefrontProduct(
                id: SupporterPackCatalog.personalLifetimeProductID,
                displayPrice: "$49.99"
            )
        ].filter { identifiers.contains($0.id) }
    }

    func purchase(productID _: String) async throws -> CommerceStorefrontPurchaseResult {
        .userCancelled
    }

    func currentEntitlements(productID _: String) async throws -> [CommerceStorefrontVerification] {
        [ownedLifetimeEntitlement]
    }

    func currentEntitlements(productIDs _: Set<String>) async throws -> [CommerceStorefrontVerification] {
        [ownedLifetimeEntitlement]
    }

    func storefrontUpdates() async -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    func transactionUpdates() async -> AsyncStream<CommerceStorefrontVerification> {
        AsyncStream { $0.finish() }
    }

    func finish(transactionID _: UInt64) async {}

    func sync() async throws {}

    private var ownedLifetimeEntitlement: CommerceStorefrontVerification {
        .verified(CommerceStorefrontTransaction(
            id: 9_900_001,
            productID: SupporterPackCatalog.personalLifetimeProductID,
            isNonConsumable: true,
            isDirectPurchase: true,
            revocationDate: nil,
            isCurrentEntitlement: true
        ))
    }
}

final nonisolated class UITestEmptyCommerceEntitlementCache: CommerceEntitlementPersisting {
    func cachedSupporterPackEntitlement() -> Bool { false }
    func setCachedSupporterPackEntitlement(_: Bool) {}
    func cachedFamilyEntitlement() -> Bool { false }
    func setCachedFamilyEntitlement(_: Bool) {}
}

@MainActor
extension CommerceEntitlementService {
    static func serviceForCurrentAppLaunch() -> CommerceEntitlementService {
        if OhanaUITestLaunchOptions.requestsOwnedCommerceFixture {
            return CommerceEntitlementService(
                storefront: UITestOwnedCommerceStorefront(),
                persistence: UITestEmptyCommerceEntitlementCache()
            )
        }
        guard OhanaUITestLaunchOptions.requestsEmptyCommerceFixture else {
            return CommerceEntitlementService()
        }
        return CommerceEntitlementService(
            storefront: UITestEmptyCommerceStorefront(),
            persistence: UITestEmptyCommerceEntitlementCache()
        )
    }
}
#endif
