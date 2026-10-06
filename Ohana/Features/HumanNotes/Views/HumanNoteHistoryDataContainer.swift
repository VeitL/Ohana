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
    var showsCloseButton = true
    @Environment(AppServices.self) private var appServices
    @State private var refreshToken = 0

    var body: some View {
        HumanNoteHistoryDataContainer(
            human: human,
            showsCloseButton: showsCloseButton,
            refreshToken: refreshToken,
            onRecordsChanged: { refreshToken += 1 }
        )
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            refreshToken += 1
        }
    }
}

private struct HumanNoteHistoryDataContainer: View {
    let human: Human
    var showsCloseButton = true
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
                    notes: human.notes,
                    context: modelContext
                )
            }
        ) { data in
            HumanNoteHistoryContent(
                human: human,
                humans: data.humans,
                noteEntries: data.noteEntries,
                isLoading: !data.hasLoaded,
                showsCloseButton: showsCloseButton,
                onRecordsChanged: onRecordsChanged
            )
        }
    }
}

private struct HumanNoteHistoryRouteData {
    var humans: [Human] = []
    var noteEntries: [HumanNoteEntry] = []
    var hasLoaded = false

    @MainActor
    static func load(
        humanID: UUID,
        notes: String,
        context: ModelContext
    ) -> HumanNoteHistoryRouteData {
        var humansDescriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt)]
        )
        humansDescriptor.fetchLimit = 64
        var noteDescriptor = FetchDescriptor<HumanNoteRecord>(
            predicate: #Predicate<HumanNoteRecord> { $0.humanId == humanID },
            sortBy: [SortDescriptor(\HumanNoteRecord.sequence, order: .reverse)]
        )
        noteDescriptor.fetchLimit = 1024
        let records = fetch(noteDescriptor, context: context, name: "HumanNoteRecord").map {
            HumanNoteTimelineRecord(
                id: $0.id, humanID: $0.humanId, sequence: $0.sequence,
                date: $0.date, rawEntry: $0.rawEntry, recordedByHumanId: $0.recordedByHumanId
            )
        }
        return HumanNoteHistoryRouteData(
            humans: fetch(humansDescriptor, context: context, name: "Human"),
            noteEntries: HumanNoteTimelineBuilder.entries(notes: notes, humanID: humanID, records: records),
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
