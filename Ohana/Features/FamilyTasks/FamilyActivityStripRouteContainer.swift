import SwiftData
import SwiftUI

struct FamilyActivityStripRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    let pet: Pet
    var style: FamilyActivityStripView.Style = .full
    var onExpand: () -> Void = {}

    @Query(sort: \Human.createdAt) private var humans: [Human]
    @State private var entries: [FamilyActivityEntry] = []
    @State private var dataLoadTask: Task<Void, Never>?

    init(
        pet: Pet,
        style: FamilyActivityStripView.Style = .full,
        onExpand: @escaping () -> Void = {}
    ) {
        self.pet = pet
        self.style = style
        self.onExpand = onExpand
    }

    var body: some View {
        FamilyActivityStripView(
            petName: pet.name,
            humans: humans,
            entries: entries,
            style: style,
            onExpand: onExpand
        )
        .onAppear {
            scheduleDataLoad()
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleDataLoad(delayMilliseconds: 120, force: true)
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleDataLoad(delayMilliseconds: UInt64 = 32, force: Bool = false) {
        guard force || entries.isEmpty else { return }
        guard dataLoadTask == nil else { return }
        let petID = pet.id
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            entries = Self.loadEntries(petID: petID, context: modelContext)
            dataLoadTask = nil
        }
    }

    private static func loadEntries(
        petID: UUID,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [FamilyActivityEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let petIDString = petID.uuidString
        let dayStart = calendar.startOfDay(for: now)
        do {
            var descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == petSubject &&
                        event.subjectId == petIDString &&
                        event.occurredAt >= dayStart
                },
                sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
            )
            descriptor.fetchLimit = 80
            return FamilyActivityEntry.entries(
                from: try context.fetch(descriptor), // route-first-frame: allow deferred-fetch
                petID: petID,
                calendar: calendar,
                now: now
            )
        } catch {
            OhanaLog.warning(
                "FamilyActivityStripRouteContainer failed to fetch ledger entries: \(error.localizedDescription)",
                category: "FamilyTasks"
            )
            return []
        }
    }
}
