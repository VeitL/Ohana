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

    /// 标记宠物离世：关闭未来活跃安排；历史与纪念内容只读保留。
    func markPassedAway(pet: Pet, date: Date = Date(), context: ModelContext) {
        pet.passedAwayDate = date
        MemberLifecycleActiveScheduleCleanup.removeFutureSchedules(for: pet, passedAwayAt: date, context: context)
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

enum MemberLifecycleActiveScheduleCleanup {
    @MainActor
    static func removeFutureSchedules(for pet: Pet, passedAwayAt date: Date, context: ModelContext) {
        removeFutureEvents(context: context, passedAwayAt: date) { event in
            MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                event,
                petId: pet.id.uuidString,
                petMedications: pet.medications,
                insurances: pet.insurances
            )
        }
    }

    @MainActor
    static func removeFutureSchedules(for human: Human, passedAwayAt date: Date, context: ModelContext) {
        let medications = fetchHumanMedications(humanKey: human.id.uuidString, context: context)
        removeFutureEvents(context: context, passedAwayAt: date) { event in
            MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                event,
                humanId: human.id.uuidString,
                humanMedications: medications
            )
        }
    }

    @MainActor
    private static func removeFutureEvents(
        context: ModelContext,
        passedAwayAt date: Date,
        belongsToMember: (Event) -> Bool
    ) {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        var didDelete = false
        for event in events where belongsToMember(event) && MemberLifecycleActiveScheduleResolver.isActiveSchedule(event, now: date) {
            if MemberLifecycleActiveScheduleResolver.retainedHistoryExists(in: event, cutoff: date) {
                if pruneFutureSchedule(from: event, context: context, deletedAt: date) {
                    didDelete = true
                }
            } else {
                tombstoneAndDelete(event, context: context, deletedAt: date)
                didDelete = true
            }
        }
        if didDelete {
            context.safeSave()
        }
    }

    @MainActor
    private static func pruneFutureSchedule(from event: Event, context: ModelContext, deletedAt: Date) -> Bool {
        var didChange = false
        for reminder in MemberLifecycleActiveScheduleResolver.futureActionableReminders(in: event, cutoff: deletedAt) {
            tombstoneAndDelete(reminder, context: context, deletedAt: deletedAt)
            didChange = true
        }
        if event.recurrenceDays > 0 {
            event.recurrenceDays = 0
            event.recurrenceEndDate = deletedAt
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: deletedAt)
            didChange = true
        }
        return didChange
    }

    @MainActor
    private static func fetchHumanMedications(humanKey: String, context: ModelContext) -> [HumanMedication] {
        let descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanKey
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func tombstoneAndDelete(_ event: Event, context: ModelContext, deletedAt: Date) {
        for reminder in event.reminders {
            tombstoneAndDelete(reminder, context: context, deletedAt: deletedAt)
        }
        CloudSyncMutationRecorder.markDeleted(event, context: context, deletedAt: deletedAt)
        context.delete(event)
    }

    @MainActor
    private static func tombstoneAndDelete(_ reminder: Reminder, context: ModelContext, deletedAt: Date) {
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        CloudSyncMutationRecorder.markDeleted(reminder, context: context, deletedAt: deletedAt)
        context.delete(reminder)
    }
}
