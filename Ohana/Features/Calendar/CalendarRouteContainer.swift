import SwiftData
import SwiftUI

struct CalendarRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = CalendarRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    var preselectedPetId: String?
    var preselectedHumanId: String?
    var hideToolbar: Bool = false
    var showsEmbeddedControls: Bool = false
    var addEventTrigger: Int = 0
    var isEmbeddedPrepared: Bool = true
    var isEmbeddedVisible: Bool = true
    var isEmbeddedActive: Bool = true
    var onRequestAddEvent: (() -> Void)?
    var onOpenEventDestination: ((FocusHomeReminderDestination) -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    var body: some View {
        CalendarView(
            preselectedPetId: preselectedPetId,
            preselectedHumanId: preselectedHumanId,
            hideToolbar: hideToolbar,
            showsEmbeddedControls: showsEmbeddedControls,
            addEventTrigger: addEventTrigger,
            isEmbeddedPrepared: isEmbeddedPrepared,
            isEmbeddedVisible: isEmbeddedVisible,
            isEmbeddedActive: isEmbeddedActive,
            onRequestAddEvent: onRequestAddEvent,
            onOpenEventDestination: onOpenEventDestination,
            onPresentCoconutLog: onPresentCoconutLog,
            events: routeData.events,
            pets: routeData.pets,
            humans: routeData.humans,
            plants: [],
            insurances: routeData.insurances,
            petMedications: routeData.petMedications,
            humanMedications: routeData.humanMedications
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
            routeData = CalendarRouteData.load(from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct CalendarRouteData {
    var events: [Event] = []
    var pets: [Pet] = []
    var humans: [Human] = []
    var insurances: [PetInsurance] = []
    var petMedications: [PetMedication] = []
    var humanMedications: [HumanMedication] = []
    var hasLoaded = false

    static func load(from context: ModelContext) -> CalendarRouteData {
        CalendarRouteData(
            events: fetch(
                FetchDescriptor<Event>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]),
                context: context,
                name: "Event"
            ),
            pets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            insurances: fetch(
                FetchDescriptor<PetInsurance>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "PetInsurance"
            ),
            petMedications: fetch(
                FetchDescriptor<PetMedication>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "PetMedication"
            ),
            humanMedications: fetch(
                FetchDescriptor<HumanMedication>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "HumanMedication"
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
                "Calendar route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Calendar"
            )
            return []
        }
    }
}
