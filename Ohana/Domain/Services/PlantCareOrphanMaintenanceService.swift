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

private nonisolated struct PlantCareOrphanMaintenancePlan: Equatable, Sendable {
    let scannedEventCount: Int
    let eventModelIDsToDelete: [PersistentIdentifier]
    let missingPlantIDs: [UUID]
    let archivedPlantPlanCount: Int
    let missingPlantEventCount: Int
    let removedReminderCount: Int
}

@ModelActor
private actor PlantCareOrphanMaintenancePlanActor {
    func makePlan() throws -> PlantCareOrphanMaintenancePlan {
        try Task.checkCancellation()
        let plants = fetch(Plant.self, operation: "fetch plants for plant care orphan maintenance")
        let events = fetch(Event.self, operation: "fetch events for plant care orphan maintenance")
        try Task.checkCancellation()
        return PlantCareOrphanMaintenanceService.makePlan(plants: plants, events: events)
    }

    private func fetch<T: PersistentModel>(
        _ type: T.Type,
        operation: String
    ) -> [T] {
        do {
            return try modelContext.fetch(FetchDescriptor<T>())
        } catch {
            OhanaLog.warning(
                "PlantCareOrphanMaintenanceService failed to \(operation): \(error.localizedDescription)",
                category: "StartupMaintenance"
            )
            return []
        }
    }
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
        let plan = makePlan(plants: plants, events: events)
        return apply(
            plan,
            context: context,
            deletedAt: deletedAt,
            notifications: notifications,
            defaults: defaults
        )
    }

    @discardableResult
    static func runOffMainScan(
        context: ModelContext,
        deletedAt: Date = Date(),
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        defaults: UserDefaults = .standard
    ) async -> PlantCareOrphanMaintenanceResult {
        let actor = PlantCareOrphanMaintenancePlanActor(modelContainer: context.container)
        do {
            let plan = try await actor.makePlan()
            return apply(
                plan,
                context: context,
                deletedAt: deletedAt,
                notifications: notifications,
                defaults: defaults
            )
        } catch is CancellationError {
            return .empty
        } catch {
            OhanaLog.warning(
                "PlantCareOrphanMaintenanceService failed to build off-main plan: \(error.localizedDescription)",
                category: "StartupMaintenance"
            )
            return .empty
        }
    }

    fileprivate nonisolated static func makePlan(plants: [Plant], events: [Event]) -> PlantCareOrphanMaintenancePlan {
        guard !events.isEmpty else {
            return PlantCareOrphanMaintenancePlan(
                scannedEventCount: 0,
                eventModelIDsToDelete: [],
                missingPlantIDs: [],
                archivedPlantPlanCount: 0,
                missingPlantEventCount: 0,
                removedReminderCount: 0
            )
        }

        let plantsByID = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0.isArchived) })
        var eventModelIDsToDelete: [PersistentIdentifier] = []
        var eventIDsToDelete: Set<UUID> = []
        var missingPlantIDs: Set<UUID> = []
        var archivedPlanCount = 0
        var missingPlantEventCount = 0
        var removedReminderCount = 0

        for event in events {
            guard let plantID = DomainEntityLinkRegistry.plantId(for: event),
                  PlantReminderPreferenceStore.careType(forEventType: event.eventType) != nil
            else { continue }

            guard let plantIsArchived = plantsByID[plantID] else {
                if shouldDeleteMissingPlantEvent(event), eventIDsToDelete.insert(event.id).inserted {
                    eventModelIDsToDelete.append(event.persistentModelID)
                    removedReminderCount += event.reminders.count
                    missingPlantIDs.insert(plantID)
                    missingPlantEventCount += 1
                }
                continue
            }

            guard plantIsArchived,
                  PlantReminderPreferenceStore.isGeneratedPlantCareEvent(event),
                  eventIDsToDelete.insert(event.id).inserted
            else { continue }
            eventModelIDsToDelete.append(event.persistentModelID)
            removedReminderCount += event.reminders.count
            archivedPlanCount += 1
        }

        return PlantCareOrphanMaintenancePlan(
            scannedEventCount: events.count,
            eventModelIDsToDelete: eventModelIDsToDelete,
            missingPlantIDs: Array(missingPlantIDs),
            archivedPlantPlanCount: archivedPlanCount,
            missingPlantEventCount: missingPlantEventCount,
            removedReminderCount: removedReminderCount
        )
    }

    private static func apply(
        _ plan: PlantCareOrphanMaintenancePlan,
        context: ModelContext,
        deletedAt: Date,
        notifications: ReminderNotificationScheduling,
        defaults: UserDefaults
    ) -> PlantCareOrphanMaintenanceResult {
        guard !plan.eventModelIDsToDelete.isEmpty || !plan.missingPlantIDs.isEmpty else {
            return PlantCareOrphanMaintenanceResult(
                scannedEventCount: plan.scannedEventCount,
                removedEventCount: 0,
                removedReminderCount: 0,
                cleanedPreferencePlantCount: 0,
                archivedPlantPlanCount: 0,
                missingPlantEventCount: 0,
                didPersist: true,
                persistenceErrorDescription: nil
            )
        }

        var removedEventCount = 0
        for eventModelID in plan.eventModelIDsToDelete {
            guard let event = context.model(for: eventModelID) as? Event else { continue }
            PhysicalDeletionService.deleteEvent(
                event,
                context: context,
                deletedAt: deletedAt,
                notifications: notifications
            )
            removedEventCount += 1
        }

        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PlantCareOrphanMaintenanceResult(
                scannedEventCount: plan.scannedEventCount,
                removedEventCount: 0,
                removedReminderCount: 0,
                cleanedPreferencePlantCount: 0,
                archivedPlantPlanCount: 0,
                missingPlantEventCount: 0,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }

        for plantID in plan.missingPlantIDs {
            PlantReminderPreferenceStore.removePlantScopedOverrides(forPlantID: plantID, defaults: defaults)
        }

        return PlantCareOrphanMaintenanceResult(
            scannedEventCount: plan.scannedEventCount,
            removedEventCount: removedEventCount,
            removedReminderCount: plan.removedReminderCount,
            cleanedPreferencePlantCount: plan.missingPlantIDs.count,
            archivedPlantPlanCount: plan.archivedPlantPlanCount,
            missingPlantEventCount: plan.missingPlantEventCount,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    private nonisolated static func shouldDeleteMissingPlantEvent(_ event: Event) -> Bool {
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
