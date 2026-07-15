//
//  TodayFocusEventActionHumanPolicy.swift
//  Ohana
//
//  Keeps Today Focus presentation free from schedule-domain static calls.
//

import Foundation

nonisolated enum TodayFocusEventActionHumanPolicy {
    static func requiresAttribution(event: Event) -> Bool {
        if CalendarTaskCompletionSyncService.isPetTask(event: event) {
            return true
        }
        if let careKind = TaskCareKind(rawValue: event.taskCareKindRaw) {
            return careKind.plantCareType != nil
        }
        return PlantReminderPreferenceStore.careType(forEventType: event.eventType) != nil
    }
}

@MainActor
extension Event {
    var requiresTodayFocusActionHuman: Bool {
        TodayFocusEventActionHumanPolicy.requiresAttribution(event: self)
    }
}
