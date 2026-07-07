//
//  PlantCareOrphanMaintenanceService.swift
//  Ohana
//
//  Repairs plant-care calendar/reminder rows that outlived their plant lifecycle.
//

import Foundation
import SwiftData

struct PlantCareOrphanMaintenanceResult: Equatable, Sendable {
    let scannedEventCount: Int
    let removedEventCount: Int
    let removedReminderCount: Int
    let cleanedPreferencePlantCount: Int
    let archivedPlantPlanCount: Int
    let missingPlantEventCount: Int
    let didPersist: Bool
    let persistenceErrorDescription: String?

    static let empty = PlantCareOrphanMaintenanceResult(
        scannedEventCount: 0,
        removedEventCount: 0,
        removedReminderCount: 0,
        cleanedPreferencePlantCount: 0,
        archivedPlantPlanCount: 0,
        missingPlantEventCount: 0,
        didPersist: true,
        persistenceErrorDescription: nil
    )
}

@MainActor
enum PlantCareOrphanMaintenanceService {
    @discardableResult
    static func run(
        context: ModelContext,
        deletedAt: Date = Date(),
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) -> PlantCareOrphanMaintenanceResult {
        let plants = fetch(Plant.self, context: context, operation: "fetch plants for plant care orphan maintenance")
        let events = fetch(Event.self, context: context, operation: "fetch events for plant care orphan maintenance")
        guard !events.isEmpty else { return .empty }

        let plantsByID = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })
        var eventIDsToDelete: Set<UUID> = []
        var missingPlantIDs: Set<UUID> = []
        var archivedPlanCount = 0
        var missingPlantEventCount = 0

        for event in events {
            guard let plantID = DomainEntityLinkRegistry.plantId(for: event),
                  PlantReminderPreferenceStore.careType(forEventType: event.eventType) != nil
            else { continue }

            guard let plant = plantsByID[plantID] else {
                if shouldDeleteMissingPlantEvent(event) {
                    eventIDsToDelete.insert(event.id)
                    missingPlantIDs.insert(plantID)
                    missingPlantEventCount += 1
                }
                continue
            }

            guard plant.isArchived,
                  PlantReminderPreferenceStore.isGeneratedPlantCareEvent(event)
            else { continue }
            eventIDsToDelete.insert(event.id)
            archivedPlanCount += 1
        }

        guard !eventIDsToDelete.isEmpty || !missingPlantIDs.isEmpty else {
            return PlantCareOrphanMaintenanceResult(
                scannedEventCount: events.count,
                removedEventCount: 0,
                removedReminderCount: 0,
                cleanedPreferencePlantCount: 0,
                archivedPlantPlanCount: 0,
                missingPlantEventCount: 0,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        var removedReminderCount = 0
        for event in events where eventIDsToDelete.contains(event.id) {
            removedReminderCount += event.reminders.count
            PhysicalDeletionService.deleteEvent(
                event,
                context: context,
                deletedAt: deletedAt,
                notifications: notifications
            )
        }

        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PlantCareOrphanMaintenanceResult(
                scannedEventCount: events.count,
                removedEventCount: 0,
                removedReminderCount: 0,
                cleanedPreferencePlantCount: 0,
                archivedPlantPlanCount: 0,
                missingPlantEventCount: 0,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }

        for plantID in missingPlantIDs {
            PlantReminderPreferenceStore.removePlantScopedOverrides(forPlantID: plantID, defaults: defaults)
        }

        return PlantCareOrphanMaintenanceResult(
            scannedEventCount: events.count,
            removedEventCount: eventIDsToDelete.count,
            removedReminderCount: removedReminderCount,
            cleanedPreferencePlantCount: missingPlantIDs.count,
            archivedPlantPlanCount: archivedPlanCount,
            missingPlantEventCount: missingPlantEventCount,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private static func shouldDeleteMissingPlantEvent(_ event: Event) -> Bool {
        PlantReminderPreferenceStore.isGeneratedPlantCareEvent(event) ||
            PlantReminderPreferenceStore.isPlantCareCompletionEvent(event)
    }

    private static func fetch<T: PersistentModel>(
        _ type: T.Type,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            OhanaLog.warning(
                "PlantCareOrphanMaintenanceService failed to \(operation): \(error.localizedDescription)",
                category: "StartupMaintenance"
            )
            return []
        }
    }
}
