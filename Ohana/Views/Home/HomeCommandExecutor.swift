//
//  HomeCommandExecutor.swift
//  Ohana
//
//  Side-effect boundary for home commands that need ModelContext.
//

import Foundation
import SwiftData

@MainActor
struct HomeCommandExecutor {
    let modelContext: ModelContext

    func scheduleMedicationReminders(for pet: Pet) {
        MedicationReminderService.shared.scheduleMedicationReminders(for: pet, context: modelContext)
    }

    func performActionType(
        _ actionType: String,
        pet: Pet,
        executorId: String?,
        allEvents: [Event],
        allFeedCareLogs: [PetCareLog],
        humans: [Human],
        now: Date,
        antiRepeatTitle: String,
        antiRepeatMessage: @escaping ((executorName: String, minutesAgo: Int)) -> String,
        openFeedDetail: @escaping (_ opensManualSheet: Bool) -> Void,
        completePlannedFeed: @escaping (Pet) -> Bool,
        showAntiRepeat: @escaping (_ title: String, _ message: String, _ pendingAction: @escaping () -> Void) -> Void,
        startWalk: (Pet) -> Void,
        openWaterManagement: (Pet) -> Void,
        openMedication: (Pet) -> Void,
        feedback: @escaping (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        ExpandedQuickActionExecutor.performActionType(
            actionType,
            pet: pet,
            executorId: executorId,
            allEvents: allEvents,
            allFeedCareLogs: allFeedCareLogs,
            humans: humans,
            modelContext: modelContext,
            now: now,
            antiRepeatTitle: antiRepeatTitle,
            antiRepeatMessage: antiRepeatMessage,
            openFeedDetail: openFeedDetail,
            completePlannedFeed: completePlannedFeed,
            showAntiRepeat: showAntiRepeat,
            startWalk: startWalk,
            openWaterManagement: openWaterManagement,
            openMedication: openMedication,
            feedback: feedback
        )
    }

    func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)? {
        CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: modelContext,
            executorId: executorId
        )
    }

    func applyPottyCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        ExpandedQuickActionExecutor.applyPottyCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            feedback: feedback
        )
    }

    func applyGroomCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        showSingleUseNotice: (String, String) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        ExpandedQuickActionExecutor.applyGroomCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            showSingleUseNotice: showSingleUseNotice,
            feedback: feedback
        )
    }

    func applyHealthCheckIn(
        raw: String,
        pet: Pet,
        executorId: String?,
        openHealth: (Pet) -> Void,
        feedback: (ExpandedQuickActionExecutor.Feedback) -> Void
    ) {
        ExpandedQuickActionExecutor.applyHealthCheckIn(
            raw: raw,
            pet: pet,
            executorId: executorId,
            modelContext: modelContext,
            openHealth: openHealth,
            feedback: feedback
        )
    }

    func recordMedicationDose(medication: PetMedication, pet: Pet) {
        PetMedicationDoseLogging.recordDose(
            medication: medication,
            pet: pet,
            modelContext: modelContext,
            awardCoconut: true
        )
        scheduleMedicationReminders(for: pet)
    }

    func completeTodayFocusEvent(_ event: Event, on date: Date = Date()) {
        event.setOccurrenceMarkedComplete(true, on: date)
        if event.recurrenceDays <= 0 {
            event.isCompleted = true
        }
        modelContext.safeSave()
    }

    func recordPlantCare(_ type: PlantCareType, plant: Plant, executorId: String?) {
        let now = Date()
        switch type {
        case .watering:
            plant.lastWateredDate = now
        case .fertilizing:
            plant.lastFertilizedDate = now
        }

        let log = PlantCareLog(date: now, careType: type, executorId: executorId)
        log.plant = plant
        modelContext.insert(log)

        let event = Event(
            title: "\(type.emoji) 给 \(plant.name)\(type.displayName)",
            startDate: now,
            isAllDay: false,
            eventType: type == .watering ? EventType.watering.rawValue : EventType.fertilizing.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString
        )
        event.assigneeId = executorId
        modelContext.insert(event)
        modelContext.safeSave()

        CareLedgerService.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: type.rawValue,
            note: log.note,
            source: .detail,
            sourceEventId: event.id.uuidString,
            legacyModelName: "PlantCareLog",
            legacyModelId: log.id.uuidString,
            context: modelContext
        )
    }

    func confirmCoconutExchange(_ request: CoconutExchangeRequest, receiver: Human) throws {
        try CoconutExchangeService.confirm(request, by: receiver, context: modelContext)
    }
}
