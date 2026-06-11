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
                record.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = QuickFeedCommandExecutor.fullFoodRecordsFetchCap
        return (try? context.fetch(descriptor)) ?? fallback
    }

    @MainActor
    static func latestEvents(context: ModelContext, fallback: [Event]) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        return (try? context.fetch(descriptor)) ?? fallback
    }
}
