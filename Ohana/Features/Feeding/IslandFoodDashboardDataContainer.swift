//
//  IslandFoodDashboardDataContainer.swift
//  Ohana
//
//  Screen-level food dashboard query container.
//

import SwiftData
import SwiftUI

struct IslandFoodDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = IslandFoodDashboardRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    init(
        standalone: Bool = true,
        onOpenPet: ((Pet) -> Void)? = nil
    ) {
        self.standalone = standalone
        self.onOpenPet = onOpenPet
    }

    var body: some View {
        IslandFoodDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: routeData.pets,
            allEvents: routeData.allEvents,
            allFeedingLedgerEntries: routeData.allFeedingLedgerEntries,
            legacyStockCareLogs: routeData.legacyStockCareLogs,
            allFoodRecords: routeData.allFoodRecords,
            allSharedCareSessions: routeData.allSharedCareSessions
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleRouteDataLoad(delayMilliseconds: UInt64 = 120, force: Bool = false) {
        guard force || !routeData.hasLoaded else { return }
        guard dataLoadTask == nil else { return }
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = IslandFoodDashboardRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct IslandFoodDashboardRouteData {
    var pets: [Pet] = []
    var allEvents: [Event] = []
    var allFeedingLedgerEntries: [FoodLedgerEntry] = []
    var legacyStockCareLogs: [PetCareLog] = []
    var allFoodRecords: [PetFoodRecord] = []
    var allSharedCareSessions: [SharedCareSession] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> IslandFoodDashboardRouteData {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingCareType = CareType.feeding.rawValue
        let sharedFeedingKind = SharedCareActionKind.feeding.rawValue
        let careLogWindowStart = Calendar.current.date(byAdding: .day, value: -730, to: Date()) ?? .distantPast
        let feedingLedgerEvents = fetch(
            FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == petSubject &&
                        event.eventKind == careKind &&
                        event.actionType == feedingCareType &&
                        event.occurredAt >= careLogWindowStart
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            ),
            context: context,
            name: "CareLedgerEvent"
        )

        return IslandFoodDashboardRouteData(
            pets: fetch(
                FetchDescriptor<Pet>(
                    predicate: #Predicate<Pet> { $0.passedAwayDate == nil },
                    sortBy: [SortDescriptor(\.name)]
                ),
                context: context,
                name: "Pet"
            ),
            allEvents: fetch(
                FetchDescriptor<Event>(sortBy: [SortDescriptor(\.startDate)]),
                context: context,
                name: "Event"
            ),
            allFeedingLedgerEntries: FoodLedgerEntry.entries(from: feedingLedgerEvents),
            legacyStockCareLogs: fetch(
                FetchDescriptor<PetCareLog>(
                    predicate: #Predicate<PetCareLog> { log in
                        log.type == feedingCareType &&
                            log.date >= careLogWindowStart
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "PetCareLog"
            ),
            allFoodRecords: fetch(
                FetchDescriptor<PetFoodRecord>(
                    predicate: #Predicate<PetFoodRecord> { $0.pet?.passedAwayDate == nil },
                    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                ),
                context: context,
                name: "PetFoodRecord"
            ),
            allSharedCareSessions: fetch(
                FetchDescriptor<SharedCareSession>(
                    predicate: #Predicate<SharedCareSession> { session in
                        session.actionKindRaw == sharedFeedingKind &&
                            session.date >= careLogWindowStart
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "SharedCareSession"
            ),
            hasLoaded: true
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Food dashboard route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Feeding"
            )
            return []
        }
    }
}
