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

    var body: some View {
        CrewRosterOverlay(
            initialMode: initialMode,
            pets: routeData.pets,
            humans: routeData.humans,
            plants: [],
            pendingReminders: routeData.pendingReminders,
            familyTasks: routeData.familyTasks,
            careLedgerEntries: routeData.careLedgerEntries,
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
            onPresentCoconutLog: onPresentCoconutLog
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
    private static let pendingReminderFetchLimit = 80
    private static let activeFamilyTaskFetchLimit = 120

    var pets: [Pet] = []
    var humans: [Human] = []
    var pendingReminders: [Reminder] = []
    var familyTasks: [FamilyCollaborationTask] = []
    var careLedgerEntries: [FamilyCareLedgerEntry] = []
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
            // Same-device reward tasks are local Solo records, not online collaboration.
            pendingReminders: fetch(
                pendingReminderDescriptor(),
                context: context,
                name: "Reminder"
            ),
            familyTasks: fetch(
                activeFamilyTaskDescriptor(),
                context: context,
                name: "FamilyCollaborationTask"
            ),
            careLedgerEntries: FamilyCareLedgerEntry.fetchPetEntries(
                since: FamilyCareLedgerEntry.weekStart(),
                context: context
            ),
            petSummaries: CrewRosterPetSummary.load(pets: pets, context: context),
            hasLoaded: true
        )
    }

    private static func pendingReminderDescriptor() -> FetchDescriptor<Reminder> {
        let pendingStatus = "pending"
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus
            },
            sortBy: [
                SortDescriptor(\.scheduledAt),
                SortDescriptor(\.id)
            ]
        )
        descriptor.fetchLimit = pendingReminderFetchLimit
        return descriptor
    }

    private static func activeFamilyTaskDescriptor() -> FetchDescriptor<FamilyCollaborationTask> {
        let activeStatus = FamilyCollaborationTaskStatus.active.rawValue
        let claimedStatus = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReviewStatus = FamilyCollaborationTaskStatus.pendingReview.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.statusRaw == activeStatus ||
                    task.statusRaw == claimedStatus ||
                    task.statusRaw == pendingReviewStatus
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .reverse),
                SortDescriptor(\.id)
            ]
        )
        descriptor.fetchLimit = activeFamilyTaskFetchLimit
        return descriptor
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
