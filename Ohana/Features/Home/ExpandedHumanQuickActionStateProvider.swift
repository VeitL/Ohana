//
//  ExpandedHumanQuickActionStateProvider.swift
//  Ohana
//
//  Read-only state for human quick actions on the expanded home card.
//

import Foundation

enum ExpandedHumanQuickActionStateProvider {
    static func completed(
        item: QuickActionItem,
        human: Human,
        viewedBy activeHumanId: UUID?,
        privacy: HumanPrivacyManaging,
        todayMedicationLogs: [HumanMedicationLog]
    ) -> Bool {
        ExpandedQuickActionLogic.humanCompleted(
            item: item,
            human: human,
            isLocked: isPrivate(item, human: human, viewedBy: activeHumanId, privacy: privacy),
            todayMedicationLogs: logs(for: human, in: todayMedicationLogs, limit: 48)
        )
    }

    static func countText(
        item: QuickActionItem,
        human: Human,
        viewedBy activeHumanId: UUID?,
        privacy: HumanPrivacyManaging,
        activeMedications: [HumanMedication],
        todayMedicationLogs: [HumanMedicationLog],
        recentExpenses: [PetExpenseLog]
    ) -> String? {
        ExpandedQuickActionLogic.humanCountText(
            item: item,
            human: human,
            isLocked: isPrivate(item, human: human, viewedBy: activeHumanId, privacy: privacy),
            activeMedications: medications(for: human, in: activeMedications, limit: 24),
            todayMedicationLogs: logs(for: human, in: todayMedicationLogs, limit: 48),
            expenses: item.actionType == "humanExpense"
                ? expenses(for: human, in: recentExpenses, limit: 80)
                : []
        )
    }

    static func isPrivate(
        _ item: QuickActionItem,
        human: Human,
        viewedBy activeHumanId: UUID?,
        privacy: HumanPrivacyManaging
    ) -> Bool {
        privacy.isHumanQuickActionLocked(item, human: human, viewedBy: activeHumanId)
    }

    private static func medications(for human: Human, in medications: [HumanMedication], limit: Int) -> [HumanMedication] {
        let humanId = human.id.uuidString
        return Array(medications.lazy.filter { $0.humanId == humanId }.prefix(limit))
    }

    private static func logs(for human: Human, in logs: [HumanMedicationLog], limit: Int) -> [HumanMedicationLog] {
        let humanId = human.id.uuidString
        return Array(logs.lazy.filter { $0.humanId == humanId }.prefix(limit))
    }

    private static func expenses(for human: Human, in expenses: [PetExpenseLog], limit: Int) -> [PetExpenseLog] {
        let humanId = human.id.uuidString
        return Array(expenses.lazy.filter { $0.executorId == humanId }.prefix(limit))
    }
}
