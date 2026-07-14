import SwiftData
import SwiftUI

struct CrewRosterOverlayRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = CrewRosterRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let initialMode: CrewRosterMode
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onInlinePetSaved: (Pet) -> Void = { _ in }
    var onInlineHumanSaved: (Human) -> Void = { _ in }
    var onAddEntity: ((EntityType) -> Void)?
    var onClose: (() -> Void)?
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var safeTopInset: CGFloat = 0
    var safeBottomInset: CGFloat = 0
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onOpenTaskCenter: (() -> Void)?

    var body: some View {
        CrewRosterOverlay(
            initialMode: initialMode,
            pets: routeData.pets,
            humans: routeData.humans,
            plants: [],
            petSummaries: routeData.petSummaries,
            onSelectPet: onSelectPet,
            onSelectHuman: onSelectHuman,
            onInlinePetSaved: onInlinePetSaved,
            onInlineHumanSaved: onInlineHumanSaved,
            onAddEntity: onAddEntity,
            onClose: onClose,
            hideToolbar: hideToolbar,
            searchTrigger: searchTrigger,
            safeTopInset: safeTopInset,
            safeBottomInset: safeBottomInset,
            onPresentCoconutLog: onPresentCoconutLog,
            onOpenTaskCenter: onOpenTaskCenter
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
            routeData = CrewRosterRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct CrewRosterRouteData {
    var pets: [Pet] = []
    var humans: [Human] = []
    var petSummaries: [UUID: CrewRosterPetSummary] = [:]
    var hasLoaded = false

    static func load(from context: ModelContext) -> CrewRosterRouteData {
        let pets = fetch(
            FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
            context: context,
            name: "Pet"
        )
        return CrewRosterRouteData(
            pets: pets,
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            petSummaries: CrewRosterPetSummary.load(pets: pets, context: context),
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
                "Crew roster route data fetch failed for \(name): \(error.localizedDescription)",
                category: "CrewRoster"
            )
            return []
        }
    }
}

struct CrewRosterPetSummary: Equatable {
    var documentCount: Int = 0

    static let empty = CrewRosterPetSummary()

    @MainActor
    static func load(pets: [Pet], context: ModelContext) -> [UUID: CrewRosterPetSummary] {
        var summaries: [UUID: CrewRosterPetSummary] = [:]
        for pet in pets {
            summaries[pet.id] = CrewRosterPetSummary(
                documentCount: documentCount(petID: pet.id, context: context)
            )
        }
        return summaries
    }

    @MainActor
    private static func documentCount(petID: UUID, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> { document in
                document.pet?.id == petID
            }
        )
        do {
            return try context.fetchCount(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Crew roster pet document count failed: \(error.localizedDescription)",
                category: "CrewRoster"
            )
            return 0
        }
    }
}
