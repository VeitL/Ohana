import Foundation
import Testing
@testable import Ohana

@MainActor
struct SupporterPackAccessPolicyTests {
    @Test("Supporter background styles are an explicit three-style set")
    func supporterBackgroundSetIsStable() {
        #expect(Set(AppBackgroundStyle.supporterPackOptions) == Set([.goDefault, .midnight, .neonGrid]))
        #expect(AppBackgroundStyle.freeOfficialPairOptions.allSatisfy { !$0.isSupporterPackStyle })
    }

    @Test("Locked background storage falls back to the free island renderer")
    func lockedBackgroundFallsBackAtRenderBoundary() {
        for style in AppBackgroundStyle.supporterPackOptions {
            #expect(
                SupporterPackAccessPolicy.resolvedBackgroundStyle(
                    requested: style,
                    hasSupporterPack: false
                ) == .goIsland
            )
            #expect(
                SupporterPackAccessPolicy.resolvedBackgroundStyle(
                    requested: style,
                    hasSupporterPack: true
                ) == style
            )
        }
    }

    @Test("Free backgrounds never require Supporter Pack")
    func freeBackgroundsStayFree() {
        for style in AppBackgroundStyle.freeOfficialPairOptions + [.customPhoto] {
            #expect(SupporterPackAccessPolicy.canSelectBackground(style, hasSupporterPack: false))
        }
    }

    @Test("Neon Smile accepts either StoreKit or Coconut ownership")
    func neonSmileUsesOwnershipUnionWithoutConflatingSources() {
        #expect(!SupporterPackAccessPolicy.canUseNeonSmileIcon(hasSupporterPack: false, hasCoconutOwnership: false))
        #expect(SupporterPackAccessPolicy.canUseNeonSmileIcon(hasSupporterPack: true, hasCoconutOwnership: false))
        #expect(SupporterPackAccessPolicy.canUseNeonSmileIcon(hasSupporterPack: false, hasCoconutOwnership: true))
        #expect(SupporterPackAccessPolicy.canUseNeonSmileIcon(hasSupporterPack: true, hasCoconutOwnership: true))
    }

    @Test("Neon Smile falls back only after verified loss and without Coconut ownership")
    func neonSmileRevocationFallbackIsConservative() {
        #expect(SupporterPackAccessPolicy.shouldOfferDefaultIconAfterEntitlementRefresh(
            status: .notOwnedVerified,
            currentIconItemID: SupporterPackCatalog.supporterIconItemID,
            hasCoconutOwnership: false
        ))
        for status in [
            CommerceEntitlementStatus.checking,
            .ownedVerified,
            .temporarilyUnknown
        ] {
            #expect(!SupporterPackAccessPolicy.shouldOfferDefaultIconAfterEntitlementRefresh(
                status: status,
                currentIconItemID: SupporterPackCatalog.supporterIconItemID,
                hasCoconutOwnership: false
            ))
        }
        #expect(!SupporterPackAccessPolicy.shouldOfferDefaultIconAfterEntitlementRefresh(
            status: .notOwnedVerified,
            currentIconItemID: SupporterPackCatalog.supporterIconItemID,
            hasCoconutOwnership: true
        ))
        #expect(!SupporterPackAccessPolicy.shouldOfferDefaultIconAfterEntitlementRefresh(
            status: .notOwnedVerified,
            currentIconItemID: AppIconCatalog.defaultItemId,
            hasCoconutOwnership: false
        ))
    }

    @Test("Standard sharing remains available without a purchase")
    func posterStyleDoesNotLockExistingSharing() {
        #expect(
            SupporterPackAccessPolicy.resolvedPosterStyle(
                requested: .standard,
                hasSupporterPack: false
            ) == .standard
        )
        #expect(
            SupporterPackAccessPolicy.resolvedPosterStyle(
                requested: .supporter,
                hasSupporterPack: false
            ) == .standard
        )
        #expect(
            SupporterPackAccessPolicy.resolvedPosterStyle(
                requested: .supporter,
                hasSupporterPack: true
            ) == .supporter
        )
    }

    @Test("Purchase UI explains Free and handles unavailable and restore-empty states")
    func purchaseUIContractIsExplicit() throws {
        let source = try source("Ohana/Features/SupporterPack/SupporterPackView.swift")

        #expect(source.contains("personal-plan-free-card"))
        #expect(source.contains("Free has no ads and never locks your records"))
        #expect(source.contains("@State private var selectedChoice: PersonalPurchaseChoice?"))
        #expect(source.contains("commerce.displayPrice(for: selectedChoice) == nil"))
        #expect(source.contains("commerce.isPurchasePending"))
        #expect(source.contains("personal-plan-reload-products-action"))
        #expect(source.contains("await commerce.reloadPersonalProducts()"))
        #expect(source.contains("commerce.isEligibleForIntroOffer(for: .yearly)"))
        #expect(source.contains("hasVerifiedSubscriptionEntitlement"))
        #expect(source.contains("shouldWaitForEntitlementVerification"))
        #expect(source.contains("personal-plan-verifying-entitlement"))
        #expect(source.contains("has no Personal or Supporter Pack purchase to restore"))
        #expect(!source.contains("setCachedSupporterPackEntitlement(true)"))
        #expect(!source.contains("CommerceEntitlementCache.supporterPackKey) = true"))
    }

    @Test("Visual gates exist at both selection and rendering boundaries")
    func visualGateUIContractIsDefenseInDepth() throws {
        let pickerSource = try source("Ohana/Features/Settings/Views/AppBackgroundPickerSheet.swift")
        let rendererSource = try source("Ohana/Shared/Design/ArkBackgroundView.swift")
        let reportSource = try source("Ohana/Features/FamilyReports/Views/WeeklyReportCard.swift")

        #expect(pickerSource.contains("style.isSupporterPackStyle && !hasSupporterPack"))
        #expect(pickerSource.contains("showingSupporterPack = true"))
        #expect(rendererSource.components(separatedBy: "SupporterPackAccessPolicy.resolvedBackgroundStyle").count >= 4)
        #expect(reportSource.contains("weekly-report-poster-style-menu"))
        #expect(reportSource.contains("SupporterWeeklyPosterStyle.standard.rawValue"))
        #expect(reportSource.contains("Founding Ohana"))
        #expect(!pickerSource.contains("CommerceEntitlementCache.supporterPackKey"))
        #expect(!rendererSource.contains("CommerceEntitlementCache.supporterPackKey"))
        #expect(!reportSource.contains("CommerceEntitlementCache.supporterPackKey"))
    }

    @Test("Settings exposes Personal contextually without an onboarding popup")
    func settingsEntryIsContextual() throws {
        let settingsSource = try source("Ohana/Features/Settings/Views/SettingsView.swift")
        let sectionSource = try source("Ohana/Features/Settings/Views/SettingsView+MainSections.swift")

        #expect(settingsSource.contains("PersonalPlanView()"))
        #expect(sectionSource.contains("settings-personal-plan-action"))
        #expect(!settingsSource.contains("showingPersonalPlan = true\n            syncStoredRegionalDefaultsIfNeeded"))
    }

    @Test("A second Free pet is checked before the creation form")
    func petEntryChecksQuotaBeforeBuildingTheDraft() throws {
        let routeSource = try source("Ohana/Features/Members/Views/AddEntityRoute.swift")
        let serviceSource = try source("Ohana/Features/Members/MemberCreationService.swift")
        let planSource = try source("Ohana/Features/SupporterPack/SupporterPackView.swift")

        #expect(routeSource.contains("creationAccessDenial("))
        #expect(routeSource.contains("case let .upgradeRequired(denial)"))
        #expect(routeSource.contains("PersonalPlanView(prompt: PersonalUpgradePrompt(denial: denial))"))
        #expect(serviceSource.contains("try requirePersonalAccess(for: .addActivePet(), context: context)"))
        #expect(planSource.contains("if let prompt"))
        #expect(planSource.contains("upgradeReasonCard(prompt)"))
        #expect(planSource.contains("if commerce.hasPersonalEntitlement"))
        #expect(planSource.contains("if prompt == nil"))
        #expect(planSource.contains(".accessibilityLabel(purchaseChoiceAccessibilityLabel(choice))"))
        #expect(planSource.contains("components.append(choiceDetail(choice))"))
    }

    private func source(_ path: String) throws -> String {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}
