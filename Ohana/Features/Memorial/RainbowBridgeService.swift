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
    init() {}

    init(reminderScheduling: ReminderSchedulingManaging) {}

    /// 标记宠物离世：只设置生命周期字段；既有数据只读保留，不再改写计划/提醒/事实。
    func markPassedAway(pet: Pet, date: Date = Date(), context: ModelContext) {
        pet.passedAwayDate = date
        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: date)
        context.safeSave()
    }

    /// 撤销离世标记（误操作恢复）
    func undoPassedAway(pet: Pet, context: ModelContext) {
        pet.passedAwayDate = nil
        CloudSyncMutationRecorder.markModified(pet, context: context)
        context.safeSave()
    }
}
