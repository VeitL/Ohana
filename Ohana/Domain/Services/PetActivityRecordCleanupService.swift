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
    let recycleBatchID: UUID?
}

@MainActor
struct PetActivityRecordCleanupService {
    private let notifications: ReminderNotificationScheduling

    init(notifications: ReminderNotificationScheduling = OhanaNotifications.current) {
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
        let petIdString = petId.uuidString
        let batchID = UUID()
        let batchKey = RecycleBinService.petActivityClearBatchId(batchID)
        let expiresAt = RecycleBinService.expirationDate(from: now)
        var deletedEventCount = 0
        var cancelledNotificationIDs: [String] = []

        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petIdString
            }
        )
        do {
            let events = try context.fetch(descriptor)
            for event in events where event.relatedEntityId == petIdString && event.trashedAt == nil {
                for reminder in event.reminders {
                    notifications.cancel(notificationId: reminder.notificationId)
                    cancelledNotificationIDs.append(reminder.notificationId)
                }
                RecycleBinService.moveToRecycleBin(
                    event,
                    now: now,
                    trashedByHumanId: deletedByHumanId,
                    batchId: batchKey,
                    context: context
                )
                deletedEventCount += 1
            }
        } catch {
            OhanaLog.warning(
                "[PetActivityRecordCleanupService] failed to fetch activity events for petId=\(petIdString): \(error.localizedDescription)",
                category: "Care"
            )
        }

        var deletedActivityRecordCount = 0
        deletedActivityRecordCount += recycleRecords(Array(pet.careLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.pottyLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.weightLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.expenseLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.hygieneLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.walkLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.healthLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.symptomLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.heatCycleLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.foodRecords), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.milestones), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.medications), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)
        deletedActivityRecordCount += recycleRecords(Array(pet.photoLogs), batchId: batchKey, now: now, deletedByHumanId: deletedByHumanId, context: context)

        let didResetStreak = pet.currentStreak != 0 || pet.lastCheckInDate != nil
        let metadata = PetActivityClearBatchMetadata(pet: pet)
        pet.currentStreak = 0
        pet.lastCheckInDate = nil
        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: now)

        if deletedEventCount > 0 || deletedActivityRecordCount > 0 || didResetStreak {
            context.insert(RecycleBinBatch(
                id: batchID,
                kindRaw: RecycleBinService.petActivityClearBatchKind,
                title: "\(pet.name) records cleared",
                subtitle: "\(deletedActivityRecordCount) records",
                sourceEntityName: String(describing: Pet.self),
                sourceEntityId: petId.uuidString,
                trashedAt: now,
                trashExpiresAt: expiresAt,
                trashedByHumanId: deletedByHumanId ?? "",
                metadataJSON: (try? String(data: JSONEncoder().encode(metadata), encoding: .utf8)) ?? ""
            ))
        }

        return PetActivityRecordCleanupResult(
            petID: petId,
            deletedActivityRecordCount: deletedActivityRecordCount,
            deletedEventCount: deletedEventCount,
            cancelledNotificationIDs: cancelledNotificationIDs,
            didResetStreak: didResetStreak,
            recycleBatchID: (deletedEventCount > 0 || deletedActivityRecordCount > 0 || didResetStreak) ? batchID : nil
        )
    }

    private func recycleRecords(
        _ records: [some PersistentModel & RecycleBinSoftDeletable],
        batchId: String,
        now: Date,
        deletedByHumanId: String?,
        context: ModelContext
    ) -> Int {
        let activeRecords = records.filter { $0.trashedAt == nil }
        for record in activeRecords {
            RecycleBinService.moveToRecycleBin(
                record,
                now: now,
                trashedByHumanId: deletedByHumanId,
                batchId: batchId,
                context: context
            )
        }
        return activeRecords.count
    }
}
