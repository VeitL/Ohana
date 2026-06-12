//
//  RainbowBridgeService.swift
//  Ohana
//
//  Pet lifecycle boundary for memorial mode.
//

import Foundation
import SwiftData

@MainActor
struct RainbowBridgeService {
    private static let memorialBatchPrefix = "memorial:"
    private static let memorialReminderActorPrefix = "system:memorial:"
    private static let memorialTrashedBy = "system:memorial"

    /// 标记宠物离世：设置 passedAwayDate，并让未来计划退出活跃流但保留数据。
    func markPassedAway(pet: Pet, date: Date = Date(), context: ModelContext) {
        pet.passedAwayDate = date

        let petIdStr = pet.id.uuidString
        let cutoff = date
        let batchId = Self.memorialBatchId(for: pet)
        let actorId = Self.memorialReminderActorId(for: pet)

        let pendingStatus = ReminderStatus.pending.rawValue
        let reminderDesc = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus && reminder.scheduledAt >= cutoff
            }
        )
        let reminders = fetchModelsOrLog(reminderDesc, context: context, operation: "fetch future pet reminders")
        for reminder in reminders where reminder.event?.relatedEntityId == petIdStr {
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            reminder.statusEnum = .skipped
            reminder.completedAt = nil
            reminder.completedBy = actorId
        }

        let eventDesc = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petIdStr && event.startDate > cutoff && event.trashedAt == nil
            }
        )
        let events = fetchModelsOrLog(eventDesc, context: context, operation: "fetch future pet events")
        for event in events {
            event.trashedAt = date
            event.trashExpiresAt = nil
            event.trashBatchId = batchId
            event.trashedByHumanId = Self.memorialTrashedBy
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: date)
        }

        context.safeSave()
    }

    private func fetchModelsOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "RainbowBridgeService failed to \(operation): \(error.localizedDescription)",
                category: "Memorial"
            )
            return []
        }
    }

    /// 撤销离世标记（误操作恢复）
    func undoPassedAway(pet: Pet, context: ModelContext) {
        pet.passedAwayDate = nil

        let petIdStr = pet.id.uuidString
        let batchId = Self.memorialBatchId(for: pet)
        let actorId = Self.memorialReminderActorId(for: pet)

        let skippedStatus = ReminderStatus.skipped.rawValue
        let reminderDesc = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == skippedStatus && reminder.completedBy == actorId
            }
        )
        let reminders = fetchModelsOrLog(reminderDesc, context: context, operation: "fetch memorial-suppressed reminders")
        var remindersToReschedule: [Reminder] = []
        for reminder in reminders where reminder.event?.relatedEntityId == petIdStr {
            reminder.statusEnum = .pending
            reminder.completedAt = nil
            reminder.completedBy = ""
            reminder.event?.setOccurrenceMarkedComplete(false, on: reminder.scheduledAt)
            if reminder.scheduledAt > Date() {
                remindersToReschedule.append(reminder)
            }
        }

        let eventDesc = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petIdStr && event.trashBatchId == batchId
            }
        )
        let events = fetchModelsOrLog(eventDesc, context: context, operation: "fetch memorial-suppressed events")
        for event in events where event.trashedByHumanId == Self.memorialTrashedBy {
            event.trashedAt = nil
            event.trashExpiresAt = nil
            event.trashBatchId = ""
            event.trashedByHumanId = ""
            CloudSyncMutationRecorder.markModified(event, context: context)
        }

        context.safeSave()

        guard !remindersToReschedule.isEmpty else { return }
        Task { @MainActor in
            await ReminderSchedulingService.scheduleManyIfNeeded(
                reminders: remindersToReschedule,
                context: context,
                source: .service
            )
        }
    }

    private static func memorialBatchId(for pet: Pet) -> String {
        "\(memorialBatchPrefix)\(pet.id.uuidString)"
    }

    private static func memorialReminderActorId(for pet: Pet) -> String {
        "\(memorialReminderActorPrefix)\(pet.id.uuidString)"
    }
}
