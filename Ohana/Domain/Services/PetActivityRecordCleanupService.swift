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

    init(notifications: ReminderNotificationScheduling = OhanaNotifications.current) {
        self.notifications = notifications
    }

    @discardableResult
    func clearActivityRecords(for pet: Pet, context: ModelContext) -> PetActivityRecordCleanupResult {
        let petId = pet.id
        let petIdString = petId.uuidString
        var deletedEventCount = 0
        var cancelledNotificationIDs: [String] = []

        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityId == petIdString
            }
        )
        do {
            let events = try context.fetch(descriptor)
            for event in events where event.relatedEntityId == petIdString {
                for reminder in event.reminders {
                    notifications.cancel(notificationId: reminder.notificationId)
                    cancelledNotificationIDs.append(reminder.notificationId)
                }
                context.delete(event)
                deletedEventCount += 1
            }
        } catch {
            OhanaLog.warning(
                "[PetActivityRecordCleanupService] failed to fetch activity events for petId=\(petIdString): \(error.localizedDescription)",
                category: "Care"
            )
        }

        var deletedActivityRecordCount = 0
        deletedActivityRecordCount += deleteRecords(Array(pet.careLogs), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.pottyLogs), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.weightLogs), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.expenseLogs), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.hygieneLogs), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.walkLogs), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.healthLogs), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.foodRecords), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.milestones), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.medications), context: context)
        deletedActivityRecordCount += deleteRecords(Array(pet.photoLogs), context: context)

        let didResetStreak = pet.currentStreak != 0 || pet.lastCheckInDate != nil
        pet.currentStreak = 0
        pet.lastCheckInDate = nil

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
        context: ModelContext
    ) -> Int {
        for record in records {
            context.delete(record)
        }
        return records.count
    }
}
