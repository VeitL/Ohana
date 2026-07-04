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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var routeData = PetMomentsHubRouteData()
    @State private var routeDataGeneration = 0
    @State private var dataLoadTask: Task<Void, Never>?

    init(pet: Pet) {
        self.pet = pet
    }

    var body: some View {
        PetMomentsHubView(
            pet: pet,
            sharedCareSessions: routeData.sharedCareSessions,
            renderData: routeData.renderData,
            albumRenderData: routeData.albumRenderData,
            dataRevision: routeData.revision
        )
        .onAppear {
            scheduleRouteDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleRouteDataLoad(delayMilliseconds: 120, force: true)
        }
        .onChange(of: appLanguage) { _, _ in
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
        let targetRevision = routeData.revision &+ 1
        let container = modelContext.container
        let languageCode = appLanguage
        routeDataGeneration += 1
        let generation = routeDataGeneration

        dataLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else {
                clearDataLoadTask(generation: generation)
                return
            }

            let actor = PetMomentsHubRouteDataActor(modelContainer: container)
            do {
                let reference = try await actor.load(petID: petID, languageCode: languageCode)
                guard !Task.isCancelled, generation == routeDataGeneration else { return }
                var loaded = PetMomentsHubRouteData(reference: reference, context: modelContext)
                loaded.revision = targetRevision
                routeData = loaded
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Pet moments route actor load failed: \(error.localizedDescription)",
                    category: "Moments"
                )
            }
            clearDataLoadTask(generation: generation)
        }
    }

    private func clearDataLoadTask(generation: Int) {
        guard generation == routeDataGeneration else { return }
        dataLoadTask = nil
    }
}

private struct PetMomentsHubRouteData {
    var sharedCareSessions: [SharedCareSession] = []
    var renderData = PetMomentsHubRenderData.empty
    var albumRenderData = PetPhotoAlbumRenderData.empty
    var hasLoaded = false
    var revision = 0

    init() {}

    @MainActor
    init(reference: PetMomentsHubRouteDataReference, context: ModelContext) {
        sharedCareSessions = Self.rehydrate(reference.sharedCareSessions, as: SharedCareSession.self, context: context)
        renderData = reference.renderData
        albumRenderData = reference.albumRenderData
        hasLoaded = reference.hasLoaded
    }

    @MainActor
    private static func rehydrate<T: PersistentModel>(
        _ identifiers: [PersistentIdentifier],
        as _: T.Type,
        context: ModelContext
    ) -> [T] {
        identifiers.compactMap { context.model(for: $0) as? T }
    }
}

private nonisolated struct PetMomentsHubRouteDataReference: Sendable {
    var sharedCareSessions: [PersistentIdentifier] = []
    var renderData = PetMomentsHubRenderData.empty
    var albumRenderData = PetPhotoAlbumRenderData.empty
    var hasLoaded = false
}

@ModelActor
private actor PetMomentsHubRouteDataActor {
    func load(petID: UUID, languageCode: String) throws -> PetMomentsHubRouteDataReference {
        try Task.checkCancellation()

        let pets = fetch(
            FetchDescriptor<Pet>(
                predicate: #Predicate<Pet> { pet in
                    pet.id == petID
                }
            ),
            name: "Pet"
        )
        let careLogs = fetch(
            FetchDescriptor<PetCareLog>(
                predicate: #Predicate<PetCareLog> { log in
                    log.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "PetCareLog"
        )
        let pottyLogs = fetch(
            FetchDescriptor<PetPottyLog>(
                predicate: #Predicate<PetPottyLog> { log in
                    log.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "PetPottyLog"
        )
        let walkLogs = fetch(
            FetchDescriptor<PetWalkLog>(
                predicate: #Predicate<PetWalkLog> { log in
                    log.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            ),
            name: "PetWalkLog"
        )
        let healthLogs = fetch(
            FetchDescriptor<PetHealthLog>(
                predicate: #Predicate<PetHealthLog> { log in
                    log.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "PetHealthLog"
        )
        let expenseLogs = fetch(
            FetchDescriptor<PetExpenseLog>(
                predicate: #Predicate<PetExpenseLog> { log in
                    log.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "PetExpenseLog"
        )
        let weightLogs = fetch(
            FetchDescriptor<PetWeightLog>(
                predicate: #Predicate<PetWeightLog> { log in
                    log.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "PetWeightLog"
        )
        let photoLogs = fetch(
            FetchDescriptor<PetPhotoLog>(
                predicate: #Predicate<PetPhotoLog> { log in
                    log.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "PetPhotoLog"
        )
        let milestones = fetch(
            FetchDescriptor<PetMilestone>(
                predicate: #Predicate<PetMilestone> { milestone in
                    milestone.pet?.id == petID
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "PetMilestone"
        )
        let sharedCareSessions = fetch(
            FetchDescriptor<SharedCareSession>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            name: "SharedCareSession"
        )

        try Task.checkCancellation()
        let timelineRows = PetTimelineSourceRows(
            careLogs: careLogs,
            pottyLogs: pottyLogs,
            walkLogs: walkLogs,
            healthLogs: healthLogs,
            expenseLogs: expenseLogs,
            weightLogs: weightLogs,
            photoLogs: photoLogs,
            milestones: milestones
        )
        let renderData = pets.first.map {
            PetMomentsHubRenderData.build(
                pet: $0,
                timelineRows: timelineRows,
                sharedCareSessions: sharedCareSessions,
                l: L10n(languageCode)
            )
        } ?? .empty
        let albumRenderData = PetPhotoAlbumRenderData.build(
            photoLogs: photoLogs,
            languageCode: languageCode
        )

        try Task.checkCancellation()
        return PetMomentsHubRouteDataReference(
            sharedCareSessions: sharedCareSessions.map(\.persistentModelID),
            renderData: renderData,
            albumRenderData: albumRenderData,
            hasLoaded: true
        )
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        name: String
    ) -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Pet moments route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Moments"
            )
            return []
        }
    }
}
