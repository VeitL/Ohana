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
    }

    /// 撤销离世标记（误操作恢复）
    func undoPassedAway(pet: Pet, context: ModelContext) {
        pet.passedAwayDate = nil
        CloudSyncMutationRecorder.markModified(pet, context: context)
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
                if tombstoneAndDelete(event, context: context, deletedAt: date).didDelete {
                    didDelete = true
                }
            }
        }
        _ = didDelete
    }

    @MainActor
    private static func pruneFutureSchedule(from event: Event, context: ModelContext, deletedAt: Date) -> Bool {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .lifecycle(.cleanupActiveSchedules),
            source: .domainService,
            context: context
        ) else { return false }
        var didChange = false
        for reminder in MemberLifecycleActiveScheduleResolver.futureActionableReminders(in: event, cutoff: deletedAt) {
            let result = DomainScheduleWriter.deleteReminder(
                reminder,
                mutation: mutation,
                context: context,
                deletedAt: deletedAt
            )
            DomainScheduleEffectsDispatcher.dispatch(delete: result)
            didChange = result.didDelete || didChange
        }
        if event.recurrenceDays > 0 {
            didChange = DomainScheduleWriter.truncateRecurringEvent(
                event,
                recurrenceEndDate: deletedAt,
                mutation: mutation,
                context: context,
                modifiedAt: deletedAt
            ) || didChange
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
    private static func tombstoneAndDelete(
        _ event: Event,
        context: ModelContext,
        deletedAt: Date
    ) -> DomainScheduleDeleteResult {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .lifecycle(.cleanupActiveSchedules),
            source: .domainService,
            context: context
        ) else { return .notDeleted }
        let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context, deletedAt: deletedAt)
        DomainScheduleEffectsDispatcher.dispatch(delete: result)
        return result
    }
}
