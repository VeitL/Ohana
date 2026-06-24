//
//  PetActivityRecordCleanupService.swift
//  Ohana
//
//  Domain-owned cleanup for pet activity facts.
//

import Foundation
import SwiftData

struct PetActivityRecordCleanupResult: Equatable {
    let petID: UUID
    let deletedActivityRecordCount: Int
    let deletedEventCount: Int
    let cancelledNotificationIDs: [String]
    let didResetStreak: Bool
}

@MainActor
struct PetActivityRecordCleanupService {
    private let notifications: ReminderNotificationScheduling

    init(notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current) {
        self.notifications = notifications
    }

    @discardableResult
    func clearActivityRecords(
        for pet: Pet,
        context: ModelContext,
        now: Date = Date(),
        deletedByHumanId: String? = nil
    ) -> PetActivityRecordCleanupResult {
        let petId = pet.id
        guard MemberLifecycleGate.disposition(
            pet: pet,
            writeKind: .lifecycle(.clearActivityRecords)
        ).isAllowed else {
            return PetActivityRecordCleanupResult(
                petID: petId,
                deletedActivityRecordCount: 0,
                deletedEventCount: 0,
                cancelledNotificationIDs: [],
                didResetStreak: false
            )
        }
        var deletedEventCount = 0
        var cancelledNotificationIDs: [String] = []

        let descriptor = FetchDescriptor<Event>()
        do {
            let events = try context.fetch(descriptor)
            for event in events where MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: petId.uuidString) {
                guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                    event: event,
                    writeKind: .lifecycle(.clearActivityRecords),
                    source: .domainService,
                    context: context
                ) else { continue }
                let result = DomainScheduleWriter.deleteEvent(
                    event,
                    mutation: mutation,
                    context: context,
                    deletedAt: now,
                    deletedByHumanId: deletedByHumanId
                )
                DomainScheduleEffectsDispatcher.dispatch(delete: result, notifications: notifications)
                cancelledNotificationIDs.append(contentsOf: result.notificationIdsToCancel)
                if result.didDelete {
                    deletedEventCount += 1
                }
            }
        } catch {
            OhanaLog.warning(
                "[PetActivityRecordCleanupService] failed to fetch activity events for petId=\(petId.uuidString): \(error.localizedDescription)",
                category: "Care"
            )
        }

        var deletedActivityRecordCount = 0
        deletedActivityRecordCount += deleteRecords(Array(pet.careLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.pottyLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.weightLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.expenseLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.hygieneLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.walkLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.healthLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.symptomLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.heatCycleLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.foodRecords), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.milestones), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.medications), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.photoLogs), pet: pet, now: now, deletedByHumanId: deletedByHumanId, context: context)

        let didResetStreak = pet.currentStreak != 0 || pet.lastCheckInDate != nil
        pet.currentStreak = 0
        pet.lastCheckInDate = nil
        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: now)

        return PetActivityRecordCleanupResult(
            petID: petId,
            deletedActivityRecordCount: deletedActivityRecordCount,
            deletedEventCount: deletedEventCount,
            cancelledNotificationIDs: cancelledNotificationIDs,
            didResetStreak: didResetStreak
        )
    }

    private func deleteRecords(
        _ records: [some PersistentModel],
        pet: Pet,
        now: Date,
        deletedByHumanId: String?,
        context: ModelContext
    ) -> Int {
        var deletedCount = 0
        for record in records {
            guard PhysicalDeletionService.deletePetScopedRecord(
                record,
                pet: pet,
                context: context,
                deletedAt: now,
                deletedByHumanId: deletedByHumanId
            ) else { continue }
            deletedCount += 1
        }
        return deletedCount
    }
}
