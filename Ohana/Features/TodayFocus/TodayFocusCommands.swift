//
//  TodayFocusCommands.swift
//  Ohana
//
//  Domain write boundaries for Today Focus event completion.
//

import Foundation
import SwiftData

struct TodayFocusEventCompletionCommandResult: Equatable {
    let eventID: UUID
    let isCompleted: Bool
    let didChange: Bool
    let didWriteFact: Bool
    let allowsDerivedEffects: Bool

    init(
        eventID: UUID,
        isCompleted: Bool,
        didChange: Bool,
        didWriteFact: Bool? = nil,
        allowsDerivedEffects: Bool? = nil
    ) {
        self.eventID = eventID
        self.isCompleted = isCompleted
        self.didChange = didChange
        self.didWriteFact = didWriteFact ?? didChange
        self.allowsDerivedEffects = allowsDerivedEffects ?? didChange
    }
}

enum TodayFocusCommandService {
    @discardableResult
    @MainActor
    static func completeEvent(
        _ event: Event,
        on date: Date,
        context: ModelContext,
        executorId: String? = nil
    ) -> TodayFocusEventCompletionCommandResult {
        let wasOccurrenceComplete = event.isOccurrenceMarkedComplete(on: date)
        let wasCompleted = event.isCompleted
        var completionResult: CalendarEventCompletionResult?

        if !wasOccurrenceComplete {
            let pet = pet(for: event, context: context)
            if CalendarTaskCompletionSyncService.isPetTask(event: event), pet == nil {
                return TodayFocusEventCompletionCommandResult(
                    eventID: event.id,
                    isCompleted: wasCompleted,
                    didChange: false,
                    didWriteFact: false,
                    allowsDerivedEffects: false
                )
            }
            completionResult = CalendarEventCommandService.toggleCompletion(
                event: event,
                occurrenceDate: date,
                pets: pet.map { [$0] } ?? [],
                context: context,
                executorId: executorId
            )
        }

        return TodayFocusEventCompletionCommandResult(
            eventID: event.id,
            isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: date),
            didChange: wasOccurrenceComplete != event.isOccurrenceMarkedComplete(on: date) || wasCompleted != event.isCompleted,
            didWriteFact: completionResult?.didWriteFact ?? false,
            allowsDerivedEffects: completionResult?.allowsDerivedEffects ?? false
        )
    }

    @MainActor
    private static func pet(for event: Event, context: ModelContext) -> Pet? {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet",
              let petId = UUID(uuidString: event.relatedEntityId) else { return nil }
        var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == petId })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "TodayFocusCommandService failed to fetch completion pet: \(error.localizedDescription)",
                category: "TodayFocus"
            )
            return nil
        }
    }
}
