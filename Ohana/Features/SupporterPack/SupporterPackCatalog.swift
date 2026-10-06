//
//  SupporterPackCatalog.swift
//  Ohana
//
//  Stable commerce identifiers for Personal, plus the founding cosmetic IDs.
//

import Foundation

nonisolated enum PersonalPurchaseChoice: String, CaseIterable, Hashable, Sendable {
    case monthly
    case yearly
    case lifetime

    var productID: String {
        switch self {
        case .monthly:
            SupporterPackCatalog.personalMonthlyProductID
        case .yearly:
            SupporterPackCatalog.personalYearlyProductID
        case .lifetime:
            SupporterPackCatalog.personalLifetimeProductID
        }
    }
}

nonisolated enum SupporterPackCatalog {
    /// Retained permanently so existing Supporter Pack owners are grandfathered
    /// into Personal Lifetime after the commercial model changes.
    static let productID = "com.guanchen.li.Ohana.supporterPack"

    static let personalMonthlyProductID = "com.guanchen.li.Ohana.personal.monthly"
    static let personalYearlyProductID = "com.guanchen.li.Ohana.personal.yearly"
    static let personalLifetimeProductID = "com.guanchen.li.Ohana.personal.lifetime"
    static let familyYearlyProductID = "com.guanchen.li.Ohana.family.yearly"

    static let personalSubscriptionGroupID = "A4E5CF33-6538-4A3E-8DB6-9DF8E472FD9D"

    static let personalSubscriptionProductIDs = Set([
        personalMonthlyProductID,
        personalYearlyProductID
    ])
    static let purchasablePersonalProductIDs = personalSubscriptionProductIDs.union([
        personalLifetimeProductID
    ])
    static let personalEntitlementProductIDs = purchasablePersonalProductIDs.union([productID])
    static let familySubscriptionProductIDs: Set<String> = [familyYearlyProductID]
    static let purchasableProductIDs = purchasablePersonalProductIDs.union(familySubscriptionProductIDs)
    static let entitlementProductIDs = personalEntitlementProductIDs.union(familySubscriptionProductIDs)

    static func purchaseChoice(for productID: String) -> PersonalPurchaseChoice? {
        switch productID {
        case personalMonthlyProductID:
            .monthly
        case personalYearlyProductID:
            .yearly
        case personalLifetimeProductID, self.productID:
            // The retired Supporter Pack is a Personal Lifetime entitlement.
            .lifetime
        default:
            nil
        }
    }

    static func expectsNonConsumable(productID: String) -> Bool {
        productID == personalLifetimeProductID || productID == self.productID
    }

    // Keep these identifiers independent from StoreKit so existing local
    // ownership can be reconciled without changing the coconut economy.
    static let supporterIconItemID = "appicon_neon_smile"
    static let supporterIconLegacyOwnershipKey = "purchasedShopItems"
    static let weeklyPosterPreferenceKey = "supporter.weeklyPosterStyle.v1"
}

nonisolated enum CommerceEntitlementCache {
    /// Device-local Keychain account for the last StoreKit-verified Personal
    /// entitlement. The legacy key is intentionally reused so verified
    /// Supporter owners keep access during the migration. This is only an
    /// offline grace; StoreKit remains the ownership authority.
    static let supporterPackKeychainAccount = "commerce.entitlement.supporterPack.v1"
    static let familyKeychainAccount = "commerce.entitlement.family.v1"
}
