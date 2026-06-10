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
}

enum ReminderActionCoordinator {
    @MainActor
    @discardableResult
    static func handle(
        userInfo: [AnyHashable: Any]?,
        currentActiveHumanId: String,
        context: ModelContext,
        careEvents providedCareEvents: CareEventRecording? = nil,
        reminderCompletion providedReminderCompletion: ReminderCompleting? = nil
    ) -> ReminderActionDispatchResult {
        guard let action = userInfo?["action"] as? String else {
            return .ignoredAction
        }
        guard let reminder = reminder(from: userInfo, context: context) else {
            return .missingReminder
        }

        let executorId = currentActiveHumanId.isEmpty ? nil : currentActiveHumanId
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
            _ = careEvents.completePlannedFeed(
                pet: pet,
                reminder: reminder,
                context: context,
                quality: .precise,
                executorId: executorId,
                date: Date()
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
}

@MainActor
protocol ReminderActionHandling {
    @discardableResult
    func handle(
        userInfo: [AnyHashable: Any]?,
        currentActiveHumanId: String,
        context: ModelContext,
        careEvents: CareEventRecording,
        reminderCompletion: ReminderCompleting
    ) -> ReminderActionDispatchResult
}

struct LiveReminderActionHandler: ReminderActionHandling {
    @discardableResult
    func handle(
        userInfo: [AnyHashable: Any]?,
        currentActiveHumanId: String,
        context: ModelContext,
        careEvents: CareEventRecording,
        reminderCompletion: ReminderCompleting
    ) -> ReminderActionDispatchResult {
        ReminderActionCoordinator.handle(
            userInfo: userInfo,
            currentActiveHumanId: currentActiveHumanId,
            context: context,
            careEvents: careEvents,
            reminderCompletion: reminderCompletion
        )
    }
}
