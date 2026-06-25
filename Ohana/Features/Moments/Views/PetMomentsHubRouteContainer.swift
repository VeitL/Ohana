//
//  PetMomentsHubRouteContainer.swift
//  Ohana
//
//  Route-scoped data boundary for the pet moments hub.
//

import SwiftData
import SwiftUI

struct PetMomentsHubRouteContainer: View {
    let pet: Pet

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = PetMomentsHubRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    init(pet: Pet) {
        self.pet = pet
    }

    var body: some View {
        PetMomentsHubView(
            pet: pet,
            timelineRows: routeData.timelineRows,
            sharedCareSessions: routeData.sharedCareSessions
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
        let petID = pet.id
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = PetMomentsHubRouteData.load(petID: petID, from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct PetMomentsHubRouteData {
    var timelineRows = PetTimelineSourceRows.empty
    var sharedCareSessions: [SharedCareSession] = []
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext) -> PetMomentsHubRouteData {
        PetMomentsHubRouteData(
            timelineRows: PetTimelineSourceRows(
                careLogs: fetch(
                    FetchDescriptor<PetCareLog>(
                        predicate: #Predicate<PetCareLog> { log in
                            log.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    ),
                    context: context,
                    name: "PetCareLog"
                ),
                pottyLogs: fetch(
                    FetchDescriptor<PetPottyLog>(
                        predicate: #Predicate<PetPottyLog> { log in
                            log.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    ),
                    context: context,
                    name: "PetPottyLog"
                ),
                walkLogs: fetch(
                    FetchDescriptor<PetWalkLog>(
                        predicate: #Predicate<PetWalkLog> { log in
                            log.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                    ),
                    context: context,
                    name: "PetWalkLog"
                ),
                healthLogs: fetch(
                    FetchDescriptor<PetHealthLog>(
                        predicate: #Predicate<PetHealthLog> { log in
                            log.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    ),
                    context: context,
                    name: "PetHealthLog"
                ),
                expenseLogs: fetch(
                    FetchDescriptor<PetExpenseLog>(
                        predicate: #Predicate<PetExpenseLog> { log in
                            log.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    ),
                    context: context,
                    name: "PetExpenseLog"
                ),
                weightLogs: fetch(
                    FetchDescriptor<PetWeightLog>(
                        predicate: #Predicate<PetWeightLog> { log in
                            log.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    ),
                    context: context,
                    name: "PetWeightLog"
                ),
                photoLogs: fetch(
                    FetchDescriptor<PetPhotoLog>(
                        predicate: #Predicate<PetPhotoLog> { log in
                            log.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    ),
                    context: context,
                    name: "PetPhotoLog"
                ),
                milestones: fetch(
                    FetchDescriptor<PetMilestone>(
                        predicate: #Predicate<PetMilestone> { milestone in
                            milestone.pet?.id == petID
                        },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    ),
                    context: context,
                    name: "PetMilestone"
                )
            ),
            sharedCareSessions: fetch(
                FetchDescriptor<SharedCareSession>(
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
                "Pet moments route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Moments"
            )
            return []
        }
    }
}
