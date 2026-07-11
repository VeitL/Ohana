//
//  HomeQuickActionRenderStateLogic.swift
//  Ohana
//
//  Actor-safe render state projection for Home expanded-card quick actions.
//

import Foundation

nonisolated struct HomePetQuickActionRenderContext {
    let events: [Event]
    let feedingEntries: [HomeFeedQuickActionEntry]
    let careEntries: [HomeCareQuickActionEntry]
    let hygieneEntries: [HomeHygieneQuickActionEntry]
    let walkEntries: [HomeWalkQuickActionEntry]
    let pottyEntries: [HomePottyQuickActionEntry]
    let expenseEntries: [HomePetExpenseQuickActionEntry]
    let weightEntries: [HomePetWeightQuickActionEntry]
    let momentEntries: [HomePetMomentQuickActionEntry]

    init(petID: UUID, source: VerticalSolidHomeSourceState) {
        events = source.events
        feedingEntries = source.feedingLedgerEntries.filter { $0.petId == petID }
        careEntries = source.careLedgerEntries.filter { $0.petId == petID }
        hygieneEntries = source.hygieneLedgerEntries.filter { $0.petId == petID }
        walkEntries = source.walkLedgerEntries.filter { $0.petId == petID }
        pottyEntries = source.pottyLedgerEntries.filter { $0.petId == petID }
        expenseEntries = source.petExpenseLedgerEntries.filter { $0.petId == petID }
        weightEntries = source.petWeightLedgerEntries.filter { $0.petId == petID }
        momentEntries = source.petMomentEntries.filter { $0.petId == petID }
    }
}

nonisolated enum HomeQuickActionRenderStateLogic {
    static func petRenderState(
        item: QuickActionItem,
        pet: Pet,
        context: HomePetQuickActionRenderContext,
        localization l: L10n,
        now: Date
    ) -> HomeQuickActionRenderSnapshot {
        let optionsArePresent = hasMenuOptions(actionType: item.actionType)
        let basePolicy = ExpandedQuickActionLogic.petMenuPolicy(
            for: item,
            pet: pet,
            allEvents: context.events,
            feedingLedgerEntries: context.feedingEntries,
            now: now
        )
        let menuPolicy = optionsArePresent
            ? HomeQuickActionMenuPolicySnapshot(showsMenu: basePolicy.showsMenu || optionsArePresent, showsQuickButton: false)
            : HomeQuickActionMenuPolicySnapshot(basePolicy)
        return HomeQuickActionRenderSnapshot(
            status: ExpandedQuickActionLogic.countText(
                item: item,
                pet: pet,
                allEvents: context.events,
                feedingLedgerEntries: context.feedingEntries,
                careLedgerEntries: context.careEntries,
                hygieneLedgerEntries: context.hygieneEntries,
                walkLedgerEntries: context.walkEntries,
                pottyLedgerEntries: context.pottyEntries,
                petExpenseLedgerEntries: context.expenseEntries,
                petWeightLedgerEntries: context.weightEntries,
                petMomentEntries: context.momentEntries,
                now: now,
                l: l
            ),
            isCompleted: ExpandedQuickActionLogic.isCompleted(
                item: item,
                pet: pet,
                allEvents: context.events,
                feedingLedgerEntries: context.feedingEntries,
                careLedgerEntries: context.careEntries,
                hygieneLedgerEntries: context.hygieneEntries,
                walkLedgerEntries: context.walkEntries,
                pottyLedgerEntries: context.pottyEntries,
                petWeightLedgerEntries: context.weightEntries,
                now: now
            ),
            attentionLevel: ExpandedQuickActionLogic.attentionLevel(
                item: item,
                pet: pet,
                allEvents: context.events,
                feedingLedgerEntries: context.feedingEntries,
                careLedgerEntries: context.careEntries,
                hygieneLedgerEntries: context.hygieneEntries,
                walkLedgerEntries: context.walkEntries,
                pottyLedgerEntries: context.pottyEntries,
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
        localization l: L10n,
        now: Date
    ) -> HomeQuickActionRenderSnapshot {
        let isLocked = isHumanQuickActionLocked(item, human: human, viewedBy: activeHumanID)
        let warningCount = CarePlanOverdueStatusCalculator.humanWarningCount(
            matching: item.actionType,
            for: human,
            events: source.events,
            medications: source.humanMedications,
            logs: source.humanMedicationLogs,
            now: now
        )
        let attentionLevel: HomeQuickActionAttentionLevel = if warningCount > 0 {
            .urgent
        } else if CarePlanOverdueStatusCalculator.humanDueTodayCount(
            for: item.actionType,
            human: human,
            events: source.events,
            medications: source.humanMedications,
            logs: source.humanMedicationLogs,
            now: now
        ) > 0 {
            .due
        } else {
            .none
        }
        let medicationWarning = item.actionType == "humanMedication" && attentionLevel == .urgent
            ? CarePlanOverdueStatusCalculator.humanMedicationWarning(
                for: human,
                medications: source.humanMedications,
                logs: source.humanMedicationLogs,
                now: now
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
            attentionLevel: attentionLevel,
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
