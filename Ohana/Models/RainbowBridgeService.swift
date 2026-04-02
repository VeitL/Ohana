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
    static func markPassedAway(pet: Pet, date: Date = Date(), context: ModelContext) {
        pet.passedAwayDate = date

        let petIdStr = pet.id.uuidString
        let now = Date()

        // 1. 删除该宠物关联的所有未来未完成 Reminder
        let reminderDesc = FetchDescriptor<Reminder>()
        if let reminders = try? context.fetch(reminderDesc) {
            for r in reminders where r.isPending && r.scheduledAt >= now {
                if r.event?.relatedEntityId == petIdStr {
                    NotificationManager.shared.cancel(notificationId: r.notificationId)
                    context.delete(r)
                }
            }
        }

        // 2. 删除该宠物关联的所有未来 Event（保留历史已发生事件）
        let eventDesc = FetchDescriptor<Event>()
        if let events = try? context.fetch(eventDesc) {
            for e in events where e.relatedEntityId == petIdStr && e.startDate > now {
                context.delete(e)
            }
        }

        context.safeSave()
    }

    /// 撤销离世标记（误操作恢复）
    static func undoPassedAway(pet: Pet, context: ModelContext) {
        pet.passedAwayDate = nil
        context.safeSave()
    }
}
