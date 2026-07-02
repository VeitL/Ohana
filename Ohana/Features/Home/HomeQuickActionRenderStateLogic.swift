//
//  HomeQuickActionRenderStateLogic.swift
//  Ohana
//
//  Actor-safe render state projection for Home expanded-card quick actions.
//

import Foundation

nonisolated enum HomeQuickActionRenderStateLogic {
    static func petRenderState(
        item: QuickActionItem,
        pet: Pet,
        source: VerticalSolidHomeSourceState,
        localization l: L10n,
        now: Date
    ) -> HomeQuickActionRenderSnapshot {
        let optionsArePresent = hasMenuOptions(actionType: item.actionType)
        let basePolicy = ExpandedQuickActionLogic.petMenuPolicy(
            for: item,
            pet: pet,
            allEvents: source.events,
            feedingLedgerEntries: source.feedingLedgerEntries,
            now: now
        )
        let menuPolicy = optionsArePresent
            ? HomeQuickActionMenuPolicySnapshot(showsMenu: basePolicy.showsMenu || optionsArePresent, showsQuickButton: false)
            : HomeQuickActionMenuPolicySnapshot(basePolicy)
        return HomeQuickActionRenderSnapshot(
            status: ExpandedQuickActionLogic.countText(
                item: item,
                pet: pet,
                allEvents: source.events,
                feedingLedgerEntries: source.feedingLedgerEntries,
                careLedgerEntries: source.careLedgerEntries,
                hygieneLedgerEntries: source.hygieneLedgerEntries,
                walkLedgerEntries: source.walkLedgerEntries,
                pottyLedgerEntries: source.pottyLedgerEntries,
                petExpenseLedgerEntries: source.petExpenseLedgerEntries,
                petWeightLedgerEntries: source.petWeightLedgerEntries,
                petMomentEntries: source.petMomentEntries,
                now: now,
                l: l
            ),
            isCompleted: ExpandedQuickActionLogic.isCompleted(
                item: item,
                pet: pet,
                allEvents: source.events,
                feedingLedgerEntries: source.feedingLedgerEntries,
                careLedgerEntries: source.careLedgerEntries,
                hygieneLedgerEntries: source.hygieneLedgerEntries,
                walkLedgerEntries: source.walkLedgerEntries,
                pottyLedgerEntries: source.pottyLedgerEntries,
                petWeightLedgerEntries: source.petWeightLedgerEntries,
                now: now
            ),
            showsAttention: ExpandedQuickActionLogic.showsAttentionDot(
                item: item,
                pet: pet,
                allEvents: source.events,
                feedingLedgerEntries: source.feedingLedgerEntries,
                careLedgerEntries: source.careLedgerEntries,
                walkLedgerEntries: source.walkLedgerEntries,
                pottyLedgerEntries: source.pottyLedgerEntries,
                now: now
            ),
            isLocked: false,
            menuPolicy: menuPolicy
        )
    }

    static func humanRenderState(
        item: QuickActionItem,
        human: Human,
        activeHumanID: UUID?,
        source: VerticalSolidHomeSourceState,
        localization l: L10n
    ) -> HomeQuickActionRenderSnapshot {
        let isLocked = isHumanQuickActionLocked(item, human: human, viewedBy: activeHumanID)
        let medicationWarning = item.actionType == "humanMedication"
            ? CarePlanOverdueStatusCalculator.humanMedicationWarning(
                for: human,
                medications: source.humanMedications,
                logs: source.humanMedicationLogs
            )
            : nil
        let status = medicationWarning?.compactText(l: l) ?? ExpandedQuickActionLogic.humanCountText(
            item: item,
            human: human,
            isLocked: isLocked,
            activeMedications: source.humanMedications,
            todayMedicationLogs: source.humanMedicationLogs
        )
        return HomeQuickActionRenderSnapshot(
            status: status,
            isCompleted: ExpandedQuickActionLogic.humanCompleted(
                item: item,
                human: human,
                isLocked: isLocked,
                todayMedicationLogs: source.humanMedicationLogs
            ),
            showsAttention: medicationWarning != nil,
            isLocked: isLocked,
            menuPolicy: HomeQuickActionMenuPolicySnapshot(ExpandedQuickActionLogic.humanMenuPolicy(actionType: item.actionType))
        )
    }

    private static func hasMenuOptions(actionType: String) -> Bool {
        switch actionType {
        case "groom", "potty", "health":
            true
        default:
            false
        }
    }

    private static func isHumanQuickActionLocked(_ item: QuickActionItem, human: Human, viewedBy viewerID: UUID?) -> Bool {
        guard HumanLocalPrivacyPolicy.isEnabled else { return false }
        guard item.entityKind == .human,
              let field = humanPrivateFieldRawValue(for: item.actionType),
              viewerID != human.id else {
            return false
        }
        return human.privateFields.contains(field)
    }

    private static func humanPrivateFieldRawValue(for actionType: String) -> String? {
        switch actionType {
        case "humanWeight", "weight":
            "weight"
        case "humanWorkout", "workout":
            "workout"
        case "humanMedication", "medication":
            "medication"
        case "humanNote", "note":
            "note"
        case "humanWishlist", "wish", "wishlist":
            "wishlist"
        case "humanExpense", "expense":
            "expense"
        default:
            nil
        }
    }
}
