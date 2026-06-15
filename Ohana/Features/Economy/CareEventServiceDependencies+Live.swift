//
//  CareEventServiceDependencies+Live.swift
//  Ohana
//

import Foundation

@MainActor
extension CareEventServiceDependencies {
    static func liveEconomy() -> CareEventEconomyAwarding {
        let wallet = SwiftDataCoconutWalletManager()
        let revisions = SharedDomainRevisionPublisher()
        return StaticCareEventEconomyAwarder(questManager: QuestManager(wallet: wallet, revisions: revisions))
    }

    static func live() -> CareEventServiceDependencies {
        let wallet = SwiftDataCoconutWalletManager()
        let revisions = SharedDomainRevisionPublisher()
        let questManager = QuestManager(wallet: wallet, revisions: revisions)
        let careLedger = CareLedgerService()
        let familyTasks = StaticFamilyTaskManager(wallet: wallet, careLedger: careLedger, questManager: questManager)
        let reminderCompletion = ReminderCompletionService(careLedger: careLedger, familyTasks: familyTasks)
        return CareEventServiceDependencies(
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            careLedger: careLedger,
            reminderCompletion: reminderCompletion,
            quickActionReminderCompletion: QuickActionReminderCompletionSyncService(reminderCompletion: reminderCompletion),
            familyTasks: familyTasks,
            revisions: revisions
        )
    }
}
