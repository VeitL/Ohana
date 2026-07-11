//
//  PlantCareFeatureScheduleCommandExecutor.swift
//  Ohana
//
//  Persistence and reminder handoff for the focused plant watering surface.
//

import Foundation
import SwiftData

struct PlantWaterScheduleControlSnapshot: Equatable {
    let planCalendarEnabled: Bool
    let systemReminderEnabled: Bool
    let completionCalendarEnabled: Bool
    let reminderLeadDays: Int
    let recurrenceEndDate: Date?

    var hasRecurrenceEndDate: Bool { recurrenceEndDate != nil }

    func resolvedRecurrenceEndDate(now: Date, calendar: Calendar) -> Date {
        recurrenceEndDate ?? calendar.date(byAdding: .month, value: 3, to: now) ?? now
    }
}

enum PlantWaterScheduleFactMutation {
    case intervalDays(Int)
    case startDate(Date)
}

enum PlantWaterSchedulePreferenceMutation {
    case planCalendarEnabled(Bool)
    case systemReminderEnabled(Bool)
    case completionCalendarEnabled(Bool)
    case reminderLeadDays(Int)
    case recurrenceEndDate(Date?)

    var requiresPlanResync: Bool {
        switch self {
        case .planCalendarEnabled, .systemReminderEnabled, .reminderLeadDays, .recurrenceEndDate:
            true
        case .completionCalendarEnabled:
            false
        }
    }

    var revisionAction: String? {
        switch self {
        case .planCalendarEnabled:
            "waterPlanCalendar"
        case .systemReminderEnabled:
            "waterSystemReminder"
        case .completionCalendarEnabled:
            "waterCompletionCalendar"
        case .reminderLeadDays, .recurrenceEndDate:
            nil
        }
    }
}

struct PlantWaterScheduleFactMutationResult: Equatable {
    let didChange: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?

    static let noChange = PlantWaterScheduleFactMutationResult(
        didChange: false,
        didPersist: true,
        persistenceErrorDescription: nil
    )

    static let saved = PlantWaterScheduleFactMutationResult(
        didChange: true,
        didPersist: true,
        persistenceErrorDescription: nil
    )

    static func failed(_ errorDescription: String?) -> PlantWaterScheduleFactMutationResult {
        PlantWaterScheduleFactMutationResult(
            didChange: true,
            didPersist: false,
            persistenceErrorDescription: errorDescription
        )
    }
}

@MainActor
struct PlantCareFeatureScheduleCommandExecutor {
    let context: ModelContext
    let reminderControls: PlantReminderControlling
    let revisions: DomainRevisionPublishing
    var defaults: UserDefaults = .standard
    var calendar: Calendar = .current

    init(context: ModelContext, services: AppServices) {
        self.context = context
        reminderControls = services.plantReminderControls
        revisions = services.domainRevisions
    }

    init(
        context: ModelContext,
        reminderControls: PlantReminderControlling,
        revisions: DomainRevisionPublishing,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.context = context
        self.reminderControls = reminderControls
        self.revisions = revisions
        self.defaults = defaults
        self.calendar = calendar
    }

    func controlSnapshot(for plant: Plant, now: Date = Date()) -> PlantWaterScheduleControlSnapshot {
        let planCalendarFallback = PlantReminderPreferenceStore.planCalendarFallback(
            for: .watering,
            plantRemindersEnabled: plant.remindersEnabled,
            defaults: defaults
        )
        return PlantWaterScheduleControlSnapshot(
            planCalendarEnabled: PlantReminderPreferenceStore.isPlanCalendarEnabled(
                forPlantID: plant.id,
                careType: .watering,
                fallback: planCalendarFallback,
                defaults: defaults
            ),
            systemReminderEnabled: PlantReminderPreferenceStore.isSystemReminderEnabled(
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            ),
            completionCalendarEnabled: PlantReminderPreferenceStore.isCompletionCalendarEnabled(
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            ),
            reminderLeadDays: PlantReminderPreferenceStore.reminderLeadDays(
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            ),
            recurrenceEndDate: PlantReminderPreferenceStore.recurrenceEndDate(
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            )
        )
    }

    @discardableResult
    func updateScheduleFact(
        _ mutation: PlantWaterScheduleFactMutation,
        for plant: Plant
    ) -> PlantWaterScheduleFactMutationResult {
        switch mutation {
        case let .intervalDays(days):
            let clampedDays = min(max(days, 1), 60)
            guard plant.wateringIntervalDays != clampedDays else { return .noChange }
            plant.wateringIntervalDays = clampedDays
        case let .startDate(date):
            let startDate = calendar.startOfDay(for: date)
            guard plant.lastWateredDate.map({ calendar.isDate($0, inSameDayAs: startDate) }) != true else {
                return .noChange
            }
            plant.lastWateredDate = startDate
        }

        CloudSyncMutationRecorder.markModified(plant, context: context)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return .failed(saveResult.errorDescription)
        }
        resyncPlan(for: plant)
        return .saved
    }

    func setPreference(_ mutation: PlantWaterSchedulePreferenceMutation, for plant: Plant) {
        switch mutation {
        case let .planCalendarEnabled(enabled):
            PlantReminderPreferenceStore.setPlanCalendarEnabled(
                enabled,
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            )
        case let .systemReminderEnabled(enabled):
            PlantReminderPreferenceStore.setSystemReminderEnabled(
                enabled,
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            )
        case let .completionCalendarEnabled(enabled):
            PlantReminderPreferenceStore.setCompletionCalendarEnabled(
                enabled,
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            )
        case let .reminderLeadDays(days):
            PlantReminderPreferenceStore.setReminderLeadDays(
                days,
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            )
        case let .recurrenceEndDate(date):
            PlantReminderPreferenceStore.setRecurrenceEndDate(
                date.map(calendar.startOfDay(for:)),
                forPlantID: plant.id,
                careType: .watering,
                defaults: defaults
            )
        }

        if mutation.requiresPlanResync {
            resyncPlan(for: plant)
        }
        if let action = mutation.revisionAction {
            revisions.publish(
                DomainMutationResult(
                    command: .plantCare(plantID: plant.id, action: action),
                    affectedEntityIDs: [plant.id],
                    wroteBusinessFact: false,
                    note: "plant.water.preference"
                )
            )
        }
    }

    func resyncPlan(for plant: Plant) {
        reminderControls.resyncPlans(plants: [plant], context: context)
    }
}
