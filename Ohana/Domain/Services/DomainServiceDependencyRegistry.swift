import Foundation
import SwiftData

@MainActor
enum DomainServiceDependencyRegistry {
    private static var makeCareEventDependencies: (() -> CareEventServiceDependencies)?
    private static var makeCareEventEconomy: (() -> CareEventEconomyAwarding)?
    private static var makeFamilyTasks: (() -> FamilyTaskManaging)?
    private static var makeReminderScheduling: ((CareLedgerRecording) -> ReminderSchedulingManaging)?
    private static var makeMedicationReminders: ((CareLedgerRecording) -> MedicationReminderManaging)?
    private static var makeReminderCompletion: ((CareLedgerRecording) -> ReminderCompleting)?

    static func register(
        careEventDependencies: (() -> CareEventServiceDependencies)? = nil,
        careEventEconomy: (() -> CareEventEconomyAwarding)? = nil,
        familyTasks: (() -> FamilyTaskManaging)? = nil,
        reminderScheduling: ((CareLedgerRecording) -> ReminderSchedulingManaging)? = nil,
        medicationReminders: ((CareLedgerRecording) -> MedicationReminderManaging)? = nil,
        reminderCompletion: ((CareLedgerRecording) -> ReminderCompleting)? = nil
    ) {
        if let careEventDependencies {
            makeCareEventDependencies = careEventDependencies
        }
        if let careEventEconomy {
            makeCareEventEconomy = careEventEconomy
        }
        if let familyTasks {
            makeFamilyTasks = familyTasks
        }
        if let reminderScheduling {
            makeReminderScheduling = reminderScheduling
        }
        if let medicationReminders {
            makeMedicationReminders = medicationReminders
        }
        if let reminderCompletion {
            makeReminderCompletion = reminderCompletion
        }
    }

    static func careEventDependencies() -> CareEventServiceDependencies {
        if let makeCareEventDependencies {
            return makeCareEventDependencies()
        }
        return debugCareEventDependencies()
    }

    static func careEventEconomy() -> CareEventEconomyAwarding {
        if let makeCareEventEconomy {
            return makeCareEventEconomy()
        }
        return debugCareEventEconomy()
    }

    static func familyTasks() -> FamilyTaskManaging {
        if let makeFamilyTasks {
            return makeFamilyTasks()
        }
        return debugFamilyTasks()
    }

    static func reminderScheduling(careLedger: CareLedgerRecording) -> ReminderSchedulingManaging {
        if let makeReminderScheduling {
            return makeReminderScheduling(careLedger)
        }
        return debugReminderScheduling()
    }

    static func medicationReminders(careLedger: CareLedgerRecording) -> MedicationReminderManaging {
        if let makeMedicationReminders {
            return makeMedicationReminders(careLedger)
        }
        return debugMedicationReminders()
    }

    static func reminderCompletion(careLedger: CareLedgerRecording) -> ReminderCompleting {
        if let makeReminderCompletion {
            return makeReminderCompletion(careLedger)
        }
        return ReminderCompletionService(
            careLedger: careLedger,
            familyTasks: familyTasks(),
            reminderScheduling: reminderScheduling(careLedger: careLedger),
            notifications: ReminderNotificationSchedulerRegistry.current
        )
    }

    private static func unregisteredDependency(_ name: String) -> Never {
        preconditionFailure("\(name) must be registered by AppServices or a feature boundary before Domain writes use it.")
    }

    private static func debugCareEventDependencies() -> CareEventServiceDependencies {
        #if DEBUG
            let careLedger = CareLedgerService()
            let economy = DomainNoOpCareEventEconomyAwarder()
            let reminderCompletion = DomainNoOpReminderCompleter()
            return CareEventServiceDependencies(
                economy: economy,
                careLedger: careLedger,
                reminderCompletion: reminderCompletion,
                quickActionReminderCompletion: DomainNoOpQuickActionReminderCompleter(),
                familyTasks: DomainNoOpFamilyTaskManager(),
                revisions: SharedDomainRevisionPublisher(),
                notifications: ReminderNotificationSchedulerRegistry.current
            )
        #else
            unregisteredDependency("CareEventServiceDependencies")
        #endif
    }

    private static func debugCareEventEconomy() -> CareEventEconomyAwarding {
        #if DEBUG
            DomainNoOpCareEventEconomyAwarder()
        #else
            unregisteredDependency("CareEventEconomyAwarding")
        #endif
    }

    private static func debugFamilyTasks() -> FamilyTaskManaging {
        #if DEBUG
            DomainNoOpFamilyTaskManager()
        #else
            unregisteredDependency("FamilyTaskManaging")
        #endif
    }

    private static func debugReminderScheduling() -> ReminderSchedulingManaging {
        #if DEBUG
            DomainNoOpReminderScheduler()
        #else
            unregisteredDependency("ReminderSchedulingManaging")
        #endif
    }

    private static func debugMedicationReminders() -> MedicationReminderManaging {
        #if DEBUG
            DomainNoOpMedicationReminderManager()
        #else
            unregisteredDependency("MedicationReminderManaging")
        #endif
    }
}

@MainActor
private final class DomainNoOpCareEventEconomyAwarder: CareEventEconomyAwarding {
    func awardCareAction(
        type _: DomainCareRewardAction,
        pet _: Pet?,
        context _: ModelContext,
        quality _: DomainCareRewardQuality,
        date _: Date,
        executorId _: String?
    ) -> (humanGot: Int, petGot: Int) {
        (0, 0)
    }

    func awardSharedCareAction(
        type _: DomainCareRewardAction,
        pets _: [Pet],
        context _: ModelContext,
        quality _: DomainCareRewardQuality,
        title _: String?,
        executorId _: String?
    ) -> (humanGot: Int, petGot: Int) {
        (0, 0)
    }

    func rewardMetadata(for _: (humanGot: Int, petGot: Int)?) -> String { "" }
    func recordFirstMeal(actorId _: String?, context _: ModelContext) {}
    func clearCooldown(petId _: UUID?, type _: DomainCareRewardAction) {}
    func refreshProjectionAfterRollback(context _: ModelContext) {}
}

@MainActor
private final class DomainNoOpReminderCompleter: ReminderCompleting {
    func complete(_: Reminder, by _: String?, context _: ModelContext) -> Bool { false }
    func skip(_: Reminder, by _: String?, context _: ModelContext) -> Bool { false }
    func reopen(_: Reminder, by _: String?, context _: ModelContext, reschedule _: Bool) -> Bool { false }
    func snoozeOneDay(_: Reminder, by _: String?, context _: ModelContext, reschedule _: Bool) -> Bool { false }
}

@MainActor
private final class DomainNoOpQuickActionReminderCompleter: QuickActionReminderCompleting {
    func completeNearestPetCareReminder(
        pet _: Pet,
        type _: CareType,
        context _: ModelContext,
        executorId _: String?,
        now _: Date
    ) -> Reminder? {
        nil
    }

    func completeNearestPetPottyReminder(
        pet _: Pet,
        context _: ModelContext,
        executorId _: String?,
        now _: Date
    ) -> Reminder? {
        nil
    }

    func completeNearestPetHygieneReminder(
        pet _: Pet,
        type _: HygieneType,
        context _: ModelContext,
        executorId _: String?,
        now _: Date
    ) -> Reminder? {
        nil
    }
}

@MainActor
private final class DomainNoOpFamilyTaskManager: FamilyTaskManaging {
    func migrateLegacyBountiesIfNeeded(context _: ModelContext) {}

    func assignReminder(
        _: Reminder,
        to _: Human,
        by _: Human?,
        rewardCoconuts _: Int,
        note _: String,
        context _: ModelContext
    ) -> FamilyCollaborationTask? {
        nil
    }

    func createHouseholdTask(
        title _: String,
        note _: String,
        assignedTo _: Human?,
        by _: Human?,
        rewardCoconuts _: Int,
        dueAt _: Date?,
        emoji _: String,
        context _: ModelContext
    ) -> FamilyCollaborationTask? {
        nil
    }

    func updateTask(
        _: FamilyCollaborationTask,
        title _: String,
        note _: String,
        assignedTo _: Human?,
        rewardCoconuts _: Int,
        dueAt _: Date?,
        emoji _: String,
        context _: ModelContext
    ) {}

    func delete(_: FamilyCollaborationTask, context _: ModelContext) {}
    func rejectCompletion(_: FamilyCollaborationTask, by _: Human?, context _: ModelContext) {}
    func confirmCompletion(_: FamilyCollaborationTask, by _: Human?, context _: ModelContext) {}
    func complete(_: FamilyCollaborationTask, by _: Human?, context _: ModelContext) {}
    func claim(_: FamilyCollaborationTask, by _: Human, context _: ModelContext) {}
    func syncCompletedReminder(_: Reminder, completedBy _: String?, context _: ModelContext) {}
    func syncReopenedReminder(_: Reminder, context _: ModelContext) {}
}

@MainActor
private final class DomainNoOpReminderScheduler: ReminderSchedulingManaging {
    func scheduleIfNeeded(
        reminder _: Reminder,
        context _: ModelContext,
        source _: CareLedgerSource,
        existingNotificationIds _: Set<String>?,
        operation _: String,
        saveLedger _: Bool
    ) async -> ReminderNotificationScheduleResult {
        .skippedUserDisabled("")
    }

    func scheduleManyIfNeeded(reminders _: [Reminder], context _: ModelContext, source _: CareLedgerSource) async {}
    func cancelAndReschedule(reminder _: Reminder, context _: ModelContext, source _: CareLedgerSource) async {}
    func refillMissingPendingNotifications(reminders _: [Reminder], context _: ModelContext) async {}
    func compensate(reminders _: [Reminder], context _: ModelContext) {}
}

@MainActor
private final class DomainNoOpMedicationReminderManager: MedicationReminderManaging {
    func dosesTakenToday(for _: UUID) -> Int { 0 }
    func recordDose(for _: UUID) {}
    func undoDose(for _: UUID) {}
    func scheduleMedicationReminders(for _: Pet, context _: ModelContext?) {}
    func scheduleHumanMedicationReminders(for _: Human, meds _: [HumanMedication], context _: ModelContext?) {}
}
