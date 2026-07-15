//
//  HumanNoteHistoryDataContainer.swift
//  Ohana
//
//  Bounded SwiftData subscriptions for the Human note timeline.
//

import SwiftData
import SwiftUI

struct HumanNoteHistorySheet: View {
    let human: Human
    @State private var refreshToken = 0

    var body: some View {
        HumanNoteHistoryDataContainer(
            human: human,
            refreshToken: refreshToken,
            onRecordsChanged: { refreshToken += 1 }
        )
    }
}

private struct HumanNoteHistoryDataContainer: View {
    let human: Human
    let refreshToken: Int
    let onRecordsChanged: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: HumanNoteHistoryRouteData(),
            refreshToken: refreshToken,
            loadDelayMilliseconds: 24,
            reloadDelayMilliseconds: 24,
            shouldLoad: { !$0.hasLoaded },
            load: {
                HumanNoteHistoryRouteData.load(
                    humanID: human.id,
                    context: modelContext
                )
            }
        ) { data in
            HumanNoteHistoryContent(
                human: human,
                humans: data.humans,
                noteRecords: data.noteRecords,
                onRecordsChanged: onRecordsChanged
            )
        }
    }
}

private struct HumanNoteHistoryRouteData {
    var humans: [Human] = []
    var noteRecords: [HumanNoteRecord] = []
    var hasLoaded = false

    @MainActor
    static func load(
        humanID: UUID,
        context: ModelContext
    ) -> HumanNoteHistoryRouteData {
        var humansDescriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt)]
        )
        humansDescriptor.fetchLimit = 64
        var noteDescriptor = FetchDescriptor<HumanNoteRecord>(
            predicate: #Predicate<HumanNoteRecord> { $0.humanId == humanID },
            sortBy: [SortDescriptor(\HumanNoteRecord.sequence)]
        )
        noteDescriptor.fetchLimit = 1024
        return HumanNoteHistoryRouteData(
            humans: fetch(humansDescriptor, context: context, name: "Human"),
            noteRecords: fetch(noteDescriptor, context: context, name: "HumanNoteRecord"),
            hasLoaded: true
        )
    }

    @MainActor
    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Human note history failed to load \(name): \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }
    }
}
