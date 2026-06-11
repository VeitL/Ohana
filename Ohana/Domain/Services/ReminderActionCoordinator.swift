//
//  ReminderActionCoordinator.swift
//  Ohana
//
//  Route/root-safe dispatcher for notification reminder actions.
//

import Foundation
import SwiftData

enum ReminderActionDispatchResult: Equatable {
    case completed
    case skipped
    case snoozed
    case ignoredAction
    case missingReminder
    case missingPet
    case missingHuman
    case missingMedication
    case missingMedicationSchedule
}

enum ReminderActionCoordinator {
    @MainActor
    @discardableResult
    static func handle(
        userInfo: [AnyHashable: Any]?,
        currentActiveHumanId: String,
        context: ModelContext,
        careEvents providedCareEvents: CareEventRecording? = nil,
        reminderCompletion providedReminderCompletion: ReminderCompleting? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        questManager providedQuestManager: QuestManager? = nil,
        medicationReminders providedMedicationReminders: MedicationReminderManaging? = nil,
        domainRevisions providedDomainRevisions: DomainRevisionPublishing? = nil
    ) -> ReminderActionDispatchResult {
        guard let action = userInfo?["action"] as? String else {
            return .ignoredAction
        }
        let executorId = currentActiveHumanId.isEmpty ? nil : currentActiveHumanId
        if let medicationResult = handleMedicationAction(
            action: action,
            userInfo: userInfo,
            executorId: executorId,
            context: context,
            careLedger: providedCareLedger ?? CareLedgerService(),
            questManager: providedQuestManager ?? QuestManager(),
            medicationReminders: providedMedicationReminders ?? SharedMedicationReminderManager(),
            domainRevisions: providedDomainRevisions ?? SharedDomainRevisionPublisher()
        ) {
            return medicationResult
        }
        guard let reminder = reminder(from: userInfo, context: context) else {
            return .missingReminder
        }

        let careEvents = providedCareEvents ?? CareEventService()
        let reminderCompletion = providedReminderCompletion ?? ReminderCompletionService()
        switch action {
        case "COMPLETE":
            return complete(reminder, executorId: executorId, context: context, careEvents: careEvents, reminderCompletion: reminderCompletion)
        case "SKIP":
            reminderCompletion.skip(reminder, by: executorId, context: context)
            return .skipped
        case "SNOOZE":
            reminderCompletion.snoozeOneDay(reminder, by: executorId, context: context, reschedule: true)
            return .snoozed
        default:
            return .ignoredAction
        }
    }

    @MainActor
    private static func handleMedicationAction(
        action: String,
        userInfo: [AnyHashable: Any]?,
        executorId: String?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        questManager: QuestManager,
        medicationReminders: MedicationReminderManaging,
        domainRevisions: DomainRevisionPublishing
    ) -> ReminderActionDispatchResult? {
        if userInfo?["humanMedicationId"] != nil {
            return handleHumanMedicationAction(
                action: action,
                userInfo: userInfo,
                context: context,
                careLedger: careLedger,
                domainRevisions: domainRevisions
            )
        }

        if userInfo?["medicationId"] != nil || userInfo?["petId"] != nil {
            return handlePetMedicationAction(
                action: action,
                userInfo: userInfo,
                executorId: executorId,
                context: context,
                questManager: questManager,
                medicationReminders: medicationReminders,
                domainRevisions: domainRevisions
            )
        }

        return nil
    }

    @MainActor
    private static func handleHumanMedicationAction(
        action: String,
        userInfo: [AnyHashable: Any]?,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        domainRevisions: DomainRevisionPublishing
    ) -> ReminderActionDispatchResult {
        guard action == "COMPLETE" || action == "SKIP" else {
            return .ignoredAction
        }
        guard let medicationId = uuidValue(userInfo?["humanMedicationId"]),
              let medication = humanMedication(for: medicationId, context: context) else {
            return .missingMedication
        }
        guard let humanID = UUID(uuidString: medication.humanId),
              let human = human(for: humanID, context: context) else {
            return .missingHuman
        }
        guard let scheduledAt = scheduledDate(from: userInfo) else {
            return .missingMedicationSchedule
        }

        let status: HumanMedicationStatus = action == "SKIP" ? .skipped : .taken
        let result = HumanMedicationDoseCommandService.setDoseStatus(
            human: human,
            medicationID: medicationId,
            scheduledTime: scheduledAt,
            status: status,
            context: context,
            source: .notification,
            careLedger: careLedger
        )
        domainRevisions.publishHumanMedicationDose(
            result,
            scheduledMinute: Int(scheduledAt.timeIntervalSince1970 / 60),
            note: action == "SKIP" ? "notification.human.medication.skip" : "notification.human.medication.complete"
        )
        return action == "SKIP" ? .skipped : .completed
    }

    @MainActor
    private static func handlePetMedicationAction(
        action: String,
        userInfo: [AnyHashable: Any]?,
        executorId: String?,
        context: ModelContext,
        questManager: QuestManager,
        medicationReminders: MedicationReminderManaging,
        domainRevisions: DomainRevisionPublishing
    ) -> ReminderActionDispatchResult {
        guard action == "COMPLETE" else {
            return .ignoredAction
        }
        guard let medicationId = uuidValue(userInfo?["medicationId"]),
              let medication = petMedication(for: medicationId, context: context) else {
            return .missingMedication
        }
        guard let pet = medication.pet ?? petContainingMedication(medicationId, context: context) else {
            return .missingPet
        }

        PetMedicationCommandExecutor(
            context: context,
            revisions: domainRevisions,
            questManager: questManager,
            medicationReminders: medicationReminders
        ).recordDose(
            medication: medication,
            pet: pet,
            awardCoconut: true,
            activeHumanSelection: FixedActiveHumanSelection(currentHumanId: executorId),
            note: "notification.pet.medication.complete"
        )
        medicationReminders.scheduleMedicationReminders(for: pet, context: context)
        return .completed
    }

    @MainActor
    private static func complete(
        _ reminder: Reminder,
        executorId: String?,
        context: ModelContext,
        careEvents: CareEventRecording,
        reminderCompletion: ReminderCompleting
    ) -> ReminderActionDispatchResult {
        if let event = reminder.event,
           event.feedRuleKindRaw == FeedRuleKind.manualReminder.rawValue {
            guard let pet = pet(for: event, context: context) else {
                return .missingPet
            }
            let foodRecords = FeedCommandFetch.foodRecords(petID: pet.id, context: context, fallback: [])
            let allEvents = FeedCommandFetch.latestEvents(context: context, fallback: [event])
            _ = ManualFeedCommand.completePlanned(
                pet: pet,
                reminder: reminder,
                foodRecords: foodRecords,
                allEvents: allEvents,
                context: context,
                executorId: executorId,
                careEvents: careEvents
            )
            return .completed
        }

        reminderCompletion.complete(reminder, by: executorId, context: context)
        return .completed
    }

    @MainActor
    private static func reminder(
        from userInfo: [AnyHashable: Any]?,
        context: ModelContext
    ) -> Reminder? {
        if let reminderId = userInfo?["reminderId"] as? String,
           let id = UUID(uuidString: reminderId),
           let reminder = firstReminder(
               predicate: #Predicate<Reminder> { reminder in
                   reminder.id == id
               },
               context: context
           ) {
            return reminder
        }

        if let notificationId = userInfo?["notificationId"] as? String,
           let reminder = firstReminder(
               predicate: #Predicate<Reminder> { reminder in
                   reminder.notificationId == notificationId
               },
               context: context
           ) {
            return reminder
        }

        if let createdAt = userInfo?["reminderCreatedAt"] as? TimeInterval {
            let lowerBound = Date(timeIntervalSince1970: createdAt - 0.001)
            let upperBound = Date(timeIntervalSince1970: createdAt + 0.001)
            return firstReminder(
                predicate: #Predicate<Reminder> { reminder in
                    reminder.createdAt >= lowerBound && reminder.createdAt <= upperBound
                },
                context: context
            )
        }

        return nil
    }

    @MainActor
    private static func firstReminder(
        predicate: Predicate<Reminder>,
        context: ModelContext
    ) -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func humanMedication(for id: UUID, context: ModelContext) -> HumanMedication? {
        var descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.id == id
            }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func petMedication(for id: UUID, context: ModelContext) -> PetMedication? {
        var descriptor = FetchDescriptor<PetMedication>(
            predicate: #Predicate<PetMedication> { medication in
                medication.id == id
            }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func human(for id: UUID, context: ModelContext) -> Human? {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func pet(for event: Event, context: ModelContext) -> Pet? {
        guard let id = UUID(uuidString: event.relatedEntityId) else { return nil }
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    private static func petContainingMedication(_ medicationId: UUID, context: ModelContext) -> Pet? {
        let descriptor = FetchDescriptor<Pet>()
        let pets = (try? context.fetch(descriptor)) ?? []
        return pets.first { pet in
            pet.medications.contains { $0.id == medicationId }
        }
    }

    private static func uuidValue(_ value: Any?) -> UUID? {
        if let value = value as? String {
            return UUID(uuidString: value)
        }
        return nil
    }

    private static func scheduledDate(from userInfo: [AnyHashable: Any]?) -> Date? {
        if let interval = userInfo?["scheduledAt"] as? TimeInterval {
            return Date(timeIntervalSince1970: interval)
        }
        if let number = userInfo?["scheduledAt"] as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        if let raw = userInfo?["scheduledAt"] as? String,
           let interval = TimeInterval(raw) {
            return Date(timeIntervalSince1970: interval)
        }
        return nil
    }
}

private struct FixedActiveHumanSelection: ActiveHumanSelecting {
    let currentHumanId: String?

    var currentHumanIdRaw: String {
        currentHumanId ?? ""
    }
}

@MainActor
protocol ReminderActionHandling {
    @discardableResult
    func handle(
        userInfo: [AnyHashable: Any]?,
        currentActiveHumanId: String,
        context: ModelContext,
        careEvents: CareEventRecording,
        reminderCompletion: ReminderCompleting,
        careLedger: CareLedgerRecording,
        questManager: QuestManager,
        medicationReminders: MedicationReminderManaging,
        domainRevisions: DomainRevisionPublishing
    ) -> ReminderActionDispatchResult
}

struct LiveReminderActionHandler: ReminderActionHandling {
    @discardableResult
    func handle(
        userInfo: [AnyHashable: Any]?,
        currentActiveHumanId: String,
        context: ModelContext,
        careEvents: CareEventRecording,
        reminderCompletion: ReminderCompleting,
        careLedger: CareLedgerRecording,
        questManager: QuestManager,
        medicationReminders: MedicationReminderManaging,
        domainRevisions: DomainRevisionPublishing
    ) -> ReminderActionDispatchResult {
        ReminderActionCoordinator.handle(
            userInfo: userInfo,
            currentActiveHumanId: currentActiveHumanId,
            context: context,
            careEvents: careEvents,
            reminderCompletion: reminderCompletion,
            careLedger: careLedger,
            questManager: questManager,
            medicationReminders: medicationReminders,
            domainRevisions: domainRevisions
        )
    }
}
