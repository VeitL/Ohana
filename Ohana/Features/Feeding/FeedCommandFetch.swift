//
//  FeedCommandFetch.swift
//  Ohana
//
//  Narrow fetch helpers for feeding write-side commands.
//

import Foundation
import SwiftData

enum FeedCommandFetch {
    @MainActor
    static func foodRecords(petID: UUID, context: ModelContext, fallback: [PetFoodRecord]) -> [PetFoodRecord] {
        var descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { record in
                record.pet?.id == petID &&
                    record.trashedAt == nil &&
                    record.pet?.trashedAt == nil
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = QuickFeedCommandExecutor.fullFoodRecordsFetchCap
        return fetchOrLog(
            descriptor,
            context: context,
            fallback: fallback,
            operation: "fetch food records"
        )
    }

    @MainActor
    static func latestEvents(context: ModelContext, fallback: [Event]) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.trashedAt == nil
            },
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        return fetchOrLog(
            descriptor,
            context: context,
            fallback: fallback,
            operation: "fetch latest events"
        )
    }

    @MainActor
    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        fallback: [T],
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "FeedCommandFetch failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return fallback
        }
    }
}
