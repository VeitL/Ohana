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
    static func isFamilyTaskProjection(_ event: Event) -> Bool {
        let planID = event.familyTaskPlanId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let occurrenceKey = event.familyTaskOccurrenceKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !planID.isEmpty || !occurrenceKey.isEmpty
    }

    static func allowsDirectMutation(for event: Event) -> Bool {
        !isFamilyTaskProjection(event)
    }

    static func tapInteraction(for event: Event, pets: [Pet]) -> CalendarEventTapInteraction {
        shouldOpenRelatedDestination(for: event, pets: pets) ? .relatedDestination : .userEventDetail
    }

    static func allowsUserEventDetail(for event: Event, pets: [Pet]) -> Bool {
        tapInteraction(for: event, pets: pets) == .userEventDetail
    }

    static func shouldOpenRelatedDestination(for event: Event, pets: [Pet]) -> Bool {
        // A family-task occurrence owns its own role-aware workflow. Calendar
        // is only a read-only projection and must not redirect to another
        // feature that could expose unrelated mutation controls.
        if isFamilyTaskProjection(event) {
            return false
        }

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
            return PlantReminderPreferenceStore.isGeneratedPlantCareEvent(event)
        case .directPet, .directHuman, .unscoped, .unknown:
            return false
        }
    }

    static func detailActions(for event: Event, allowsEditing: Bool) -> [CalendarEventDetailAction] {
        guard allowsDirectMutation(for: event) else { return [] }
        var actions: [CalendarEventDetailAction] = []
        if allowsEditing { actions.append(.edit) }
        if event.isActionableTask { actions.append(.complete) }
        if allowsEditing { actions.append(.delete) }
        return actions
    }

    static func detailDeletionScopes(for event: Event) -> [CalendarEventDeletionScope] {
        guard allowsDirectMutation(for: event) else { return [] }
        return event.recurrenceDays > 0 ? [.singleOccurrence, .thisAndFuture] : [.wholeEvent]
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
}
