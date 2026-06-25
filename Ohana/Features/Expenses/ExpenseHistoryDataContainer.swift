import SwiftData
import SwiftUI

struct ExpenseHistoryView: View {
    let pet: Pet
    var onRemove: (() -> Void)?
    var showsCloseButton: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = ExpenseHistoryRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    init(pet: Pet, onRemove: (() -> Void)? = nil, showsCloseButton: Bool = true) {
        self.pet = pet
        self.onRemove = onRemove
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        ExpenseHistoryContentView(
            pet: pet,
            expenseLogs: routeData.expenseLogs,
            allHumans: routeData.humans,
            allPets: routeData.pets,
            allSharedCareSessions: routeData.sharedCareSessions,
            onRemove: onRemove,
            showsCloseButton: showsCloseButton,
            onDataChanged: {
                scheduleRouteDataLoad(delayMilliseconds: 24, force: true)
            }
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
            routeData = ExpenseHistoryRouteData.load(petID: petID, from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct ExpenseHistoryRouteData {
    var expenseLogs: [PetExpenseLog] = []
    var humans: [Human] = []
    var pets: [Pet] = []
    var sharedCareSessions: [SharedCareSession] = []
    var hasLoaded = false

    static func load(petID: UUID, from context: ModelContext) -> ExpenseHistoryRouteData {
        ExpenseHistoryRouteData(
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
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            pets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            sharedCareSessions: fetch(
                FetchDescriptor<SharedCareSession>(sortBy: [SortDescriptor(\.date)]),
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
                "Expense history route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Expenses"
            )
            return []
        }
    }
}
