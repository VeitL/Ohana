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

    func confirmCoconutExchange(_ request: CoconutExchangeRequest, receiver: Human) throws {
        try CoconutExchangeService.confirm(request, by: receiver, context: modelContext)
    }
}
