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
        let petKey = pet.id.uuidString
        let medicationKeys = Set(pet.medications.map(\.id.uuidString))
        let insuranceKeys = Set(pet.insurances.map(\.id.uuidString))
        removeFutureEvents(context: context, passedAwayAt: date) { event in
            isPetEvent(event, petKey: petKey, medicationKeys: medicationKeys, insuranceKeys: insuranceKeys)
        }
    }

    @MainActor
    static func removeFutureSchedules(for human: Human, passedAwayAt date: Date, context: ModelContext) {
        let humanKey = human.id.uuidString
        let medicationKeys = fetchHumanMedicationKeys(humanKey: humanKey, context: context)
        removeFutureEvents(context: context, passedAwayAt: date) { event in
            isHumanEvent(event, humanKey: humanKey, medicationKeys: medicationKeys)
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
        for event in events where belongsToMember(event) && isFutureActiveSchedule(event, passedAwayAt: date) {
            tombstoneAndDelete(event, context: context, deletedAt: date)
            didDelete = true
        }
        if didDelete {
            context.safeSave()
        }
    }

    private static func isFutureActiveSchedule(_ event: Event, passedAwayAt date: Date) -> Bool {
        event.startDate >= date ||
            event.recurrenceDays > 0 ||
            event.reminders.contains { !$0.isCompleted && $0.scheduledAt >= date }
    }

    private static func isPetEvent(
        _ event: Event,
        petKey: String,
        medicationKeys: Set<String>,
        insuranceKeys: Set<String>
    ) -> Bool {
        let entityType = event.relatedEntityType.lowercased()
        if event.relatedEntityId == petKey {
            return entityType == EntityKind.pet.rawValue.lowercased()
                || entityType == "pet"
                || entityType == "pet_food_stock"
                || entityType == FeedRuleMetadata.autoFeederEntityType.lowercased()
                || entityType == WaterPlanWriter.entityType.lowercased()
        }
        if entityType == "pet_insurance" {
            return insuranceKeys.contains(event.relatedEntityId)
        }
        if entityType == PetMedicationDoseLogging.relatedEntityTypeMedication.lowercased() ||
            entityType == MedicationEventLink.petMedicationPlan.lowercased() {
            return medicationKeys.contains(event.relatedEntityId)
        }
        return false
    }

    private static func isHumanEvent(_ event: Event, humanKey: String, medicationKeys: Set<String>) -> Bool {
        let entityType = event.relatedEntityType.lowercased()
        if event.assigneeId == humanKey {
            return true
        }
        if event.relatedEntityId == humanKey {
            return entityType == EntityKind.human.rawValue.lowercased()
                || entityType == "human"
                || entityType == "human_note"
        }
        if entityType == MedicationEventLink.humanMedicationPlan.lowercased() {
            return medicationKeys.contains(event.relatedEntityId)
        }
        return false
    }

    @MainActor
    private static func fetchHumanMedicationKeys(humanKey: String, context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                medication.humanId == humanKey
            }
        )
        let medications = (try? context.fetch(descriptor)) ?? []
        return Set(medications.map(\.id.uuidString))
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
