//
//  RainbowBridgeService.swift
//  Ohana
//
//  任务一：宠物生命周期 — 标记离世 + 自动清理未来提醒/事件
//

import Foundation
import SwiftData

@MainActor
struct RainbowBridgeService {

    /// 标记宠物离世：设置 passedAwayDate，删除未来未完成的 Reminder 和 Event
    func markPassedAway(pet: Pet, date: Date = Date(), context: ModelContext) {
        pet.passedAwayDate = date

        let petIdStr = pet.id.uuidString
        let now = Date()

        // 1. 删除该宠物关联的所有未来未完成 Reminder
        let pendingStatus = ReminderStatus.pending.rawValue
        let reminderDesc = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus && reminder.scheduledAt >= now
            }
        )
        let reminders = fetchModelsOrLog(reminderDesc, context: context, operation: "fetch future pet reminders")
        for reminder in reminders where reminder.event?.relatedEntityId == petIdStr {
            OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
            context.delete(reminder)
        }

        // 2. 删除该宠物关联的所有未来 Event（保留历史已发生事件）
        let eventDesc = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petIdStr && event.startDate > now
            }
        )
        let events = fetchModelsOrLog(eventDesc, context: context, operation: "fetch future pet events")
        for event in events {
            context.delete(event)
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
        context.safeSave()
    }
}
