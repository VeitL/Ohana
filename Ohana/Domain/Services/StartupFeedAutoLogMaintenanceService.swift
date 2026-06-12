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

        let eventsByPetId = Dictionary(grouping: events, by: \.relatedEntityId)
        var inserted = 0

        for (petIdRaw, petEvents) in eventsByPetId {
            guard let petID = UUID(uuidString: petIdRaw),
                  let pet = pet(id: petID, context: context)
            else { continue }

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
        let autoEntityType = FeedRuleMetadata.autoFeederEntityType
        let foodChangeType = EventType.foodChange.rawValue
        let autoKind = FeedRuleKind.autoFeeder.rawValue
        let legacyKind = ""

        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.relatedEntityType == autoEntityType &&
                    event.eventType == foodChangeType &&
                    (event.feedRuleKindRaw == autoKind || event.feedRuleKindRaw == legacyKind)
            },
            sortBy: [SortDescriptor(\Event.startDate, order: .forward)]
        )
        return fetchOrLog(descriptor, context: context, operation: "fetch auto-feeder events")
    }

    @MainActor
    private static func pet(id: UUID, context: ModelContext) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(descriptor, context: context, operation: "fetch pet").first
    }
}
