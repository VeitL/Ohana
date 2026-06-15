//
//  StartupFeedAutoLogMaintenanceService.swift
//  Ohana
//
//  Narrow startup maintenance for auto-feeder materialization.
//

import Foundation
import SwiftData

enum StartupFeedAutoLogMaintenanceService {
    @MainActor
    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "StartupFeedAutoLogMaintenanceService failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    @MainActor
    @discardableResult
    static func materializeDueAutoFeederLogs(
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let events = autoFeederEvents(context: context)
        guard !events.isEmpty else { return 0 }
        let pets = pets(context: context)
        guard !pets.isEmpty else { return 0 }

        var inserted = 0

        for pet in pets {
            let petEvents = events.filter { FeedRuleMetadata.isAutoFeederEvent($0, pet: pet) }
            guard !petEvents.isEmpty else { continue }

            inserted += FeedAutoLogMaterializer.materializeDueLogs(
                pet: pet,
                allEvents: petEvents,
                context: context,
                now: now,
                calendar: calendar
            )
        }

        return inserted
    }

    @MainActor
    private static func autoFeederEvents(context: ModelContext) -> [Event] {
        let foodChangeType = EventType.foodChange.rawValue
        let autoKind = FeedRuleKind.autoFeeder.rawValue
        let legacyKind = ""

        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.eventType == foodChangeType &&
                    (event.feedRuleKindRaw == autoKind || event.feedRuleKindRaw == legacyKind)
            },
            sortBy: [SortDescriptor(\Event.startDate, order: .forward)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch auto-feeder events")
    }

    @MainActor
    private static func pets(context: ModelContext) -> [Pet] {
        fetchOrLog(FetchDescriptor<Pet>(), context: context, operation: "fetch pets")
    }
}
