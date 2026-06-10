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
}

enum TodayFocusCommandService {
    @discardableResult
    @MainActor
    static func completeEvent(
        _ event: Event,
        on date: Date,
        context: ModelContext
    ) -> TodayFocusEventCompletionCommandResult {
        let wasOccurrenceComplete = event.isOccurrenceMarkedComplete(on: date)
        let wasCompleted = event.isCompleted

        event.setOccurrenceMarkedComplete(true, on: date)
        if event.recurrenceDays <= 0 {
            event.isCompleted = true
        }
        context.safeSave()

        return TodayFocusEventCompletionCommandResult(
            eventID: event.id,
            isCompleted: event.recurrenceDays <= 0 ? event.isCompleted : event.isOccurrenceMarkedComplete(on: date),
            didChange: !wasOccurrenceComplete || wasCompleted != event.isCompleted
        )
    }
}
