import Foundation
import SwiftUI

private struct SupporterPackEntitlementEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Read-only semantic entitlement injected by the app root. A false default
    /// keeps previews and isolated surfaces safely on the free appearance.
    var hasSupporterPackEntitlement: Bool {
        get { self[SupporterPackEntitlementEnvironmentKey.self] }
        set { self[SupporterPackEntitlementEnvironmentKey.self] = newValue }
    }
}

enum SupporterWeeklyPosterStyle: String, CaseIterable, Identifiable {
    case standard
    case supporter

    var id: String { rawValue }
}

/// Pure access rules shared by settings, renderers, and tests.
///
/// StoreKit ownership and Coconut ownership intentionally remain separate facts.
/// The policy only combines them at the point where a visual asset is used.
enum SupporterPackAccessPolicy {
    static let neonSmileIconItemID = SupporterPackCatalog.supporterIconItemID

    static func canSelectBackground(
        _ style: AppBackgroundStyle,
        hasSupporterPack: Bool
    ) -> Bool {
        !style.isSupporterPackStyle || hasSupporterPack
    }

    static func resolvedBackgroundStyle(
        requested style: AppBackgroundStyle,
        hasSupporterPack: Bool
    ) -> AppBackgroundStyle {
        canSelectBackground(style, hasSupporterPack: hasSupporterPack) ? style : .goIsland
    }

    static func canUseNeonSmileIcon(
        hasSupporterPack: Bool,
        hasCoconutOwnership: Bool
    ) -> Bool {
        hasSupporterPack || hasCoconutOwnership
    }

    static func shouldOfferDefaultIconAfterEntitlementRefresh(
        status: CommerceEntitlementStatus,
        currentIconItemID: String,
        hasCoconutOwnership: Bool
    ) -> Bool {
        status == .notOwnedVerified &&
            currentIconItemID == neonSmileIconItemID &&
            !hasCoconutOwnership
    }

    static func resolvedPosterStyle(
        requested style: SupporterWeeklyPosterStyle,
        hasSupporterPack: Bool
    ) -> SupporterWeeklyPosterStyle {
        if style == .supporter, !hasSupporterPack {
            return .standard
        }
        return style
    }
}
