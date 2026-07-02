//
//  CalendarEventInteractionPolicy.swift
//  Ohana
//
//  Keeps calendar row taps from treating generated feature schedules as
//  user-authored editable events.
//

import Foundation

enum CalendarEventTapInteraction: Equatable {
    case userEventDetail
    case relatedDestination
}

enum CalendarEventDetailAction: Equatable {
    case edit
    case complete
    case delete
}

enum CalendarEventInteractionPolicy {
    private static let plantPlanTitleMarker = "植物计划"

    static func tapInteraction(for event: Event, pets: [Pet]) -> CalendarEventTapInteraction {
        shouldOpenRelatedDestination(for: event, pets: pets) ? .relatedDestination : .userEventDetail
    }

    static func allowsUserEventDetail(for event: Event, pets: [Pet]) -> Bool {
        tapInteraction(for: event, pets: pets) == .userEventDetail
    }

    static func shouldOpenRelatedDestination(for event: Event, pets: [Pet]) -> Bool {
        if CarePlanCalendarSync.isGeneratedCalendarPlan(event, pets: pets) {
            return true
        }

        if let pet = MemberLifecycleActiveScheduleResolver.petTarget(
            for: event,
            pets: pets,
            includePassedAway: false
        ), isGeneratedPetCarePlan(event, pet: pet) {
            return true
        }

        switch DomainEntityLinkRegistry.role(for: event) {
        case .petAutoFeeder, .petWaterPlan, .petFoodStock, .petInsurance,
             .petMedicationPlan, .petMedicationDose, .humanNote, .humanMedicationPlan,
             .plantScoped:
            return true
        case .directPlant:
            return isGeneratedPlantCarePlan(event)
        case .directPet, .directHuman, .unscoped, .unknown:
            return false
        }
    }

    static func detailActions(for event: Event, allowsEditing: Bool) -> [CalendarEventDetailAction] {
        var actions: [CalendarEventDetailAction] = []
        if allowsEditing { actions.append(.edit) }
        if event.isActionableTask { actions.append(.complete) }
        if allowsEditing { actions.append(.delete) }
        return actions
    }

    static func detailDeletionScopes(for event: Event) -> [CalendarEventDeletionScope] {
        event.recurrenceDays > 0 ? [.singleOccurrence, .thisAndFuture] : [.wholeEvent]
    }

    static func showsScheduleConfigurationInReadOnlyDetail(for _: Event) -> Bool {
        false
    }

    private static func isGeneratedPetCarePlan(_ event: Event, pet: Pet) -> Bool {
        isGeneratedManualFeedPlan(event, pet: pet) ||
            FeedRuleMetadata.isAutoFeederEvent(event, pet: pet) ||
            WaterPlanWriter.isPlanEvent(event, pet: pet)
    }

    private static func isGeneratedManualFeedPlan(_ event: Event, pet: Pet) -> Bool {
        event.feedRuleKindRaw == FeedRuleKind.manualReminder.rawValue &&
            FeedRuleMetadata.isManualReminderEvent(event, pet: pet)
    }

    private static func isGeneratedPlantCarePlan(_ event: Event) -> Bool {
        guard
            event.isAllDay,
            event.recurrenceDays > 0,
            event.title.contains(plantPlanTitleMarker),
            let eventType = EventType(rawValue: event.eventType)
        else { return false }

        switch eventType {
        case .watering, .fertilizing, .plantRepotting, .plantPruning,
             .plantMisting, .plantRotation, .plantLeafCleaning,
             .plantPestCheck, .plantHealthCheck:
            return true
        case .birthday, .anniversary, .daily, .health, .task, .shoppingList,
             .chore, .vaccine, .externalDeworming, .internalDeworming,
             .grooming, .vetVisit, .foodChange, .litterBox, .medication,
             .petMedication, .petMedicationDose, .insurancePremium:
            return false
        }
    }
}
