import Foundation
import SwiftData
import SwiftUI

nonisolated struct WeightInsightSubjectDescriptor: Equatable, Sendable {
    let id: UUID
    let name: String
    let isHuman: Bool

    var seriesID: String {
        "\(isHuman ? "human" : "pet"):\(id.uuidString)"
    }
}

nonisolated struct WeightInsightSnapshot: Equatable, Sendable {
    let revisionID: UUID
    let points: [WeightAbsolutePoint]
    let isTruncated: Bool
    let hasLoaded: Bool

    static let empty = WeightInsightSnapshot(
        revisionID: UUID(),
        points: [],
        isTruncated: false,
        hasLoaded: false
    )
}

@ModelActor
actor WeightInsightDataActor {
    private static let maximumRecordCount = 20_000

    func load(
        dayCount: Int?,
        subjectKey: String?,
        pets: [WeightInsightSubjectDescriptor],
        humans: [WeightInsightSubjectDescriptor],
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> WeightInsightSnapshot {
        try Task.checkCancellation()
        let cutoff = dayCount.flatMap {
            calendar.date(
                byAdding: .day,
                value: -($0 - 1),
                to: calendar.startOfDay(for: now)
            )
        }
        let selected = Self.parseSubjectKey(subjectKey)
        let petFetch = try fetchPetWeights(
            cutoff: cutoff,
            selectedPetID: selected?.kind == "pet" ? UUID(uuidString: selected?.id ?? "") : nil,
            shouldFetch: selected == nil || selected?.kind == "pet"
        )
        let humanFetch = try fetchHumanWeights(
            cutoff: cutoff,
            selectedHumanID: selected?.kind == "human" ? UUID(uuidString: selected?.id ?? "") : nil,
            shouldFetch: selected == nil || selected?.kind == "human"
        )
        try Task.checkCancellation()

        let petByID = Dictionary(uniqueKeysWithValues: pets.map { ($0.id, $0) })
        let humanByID = Dictionary(uniqueKeysWithValues: humans.map { ($0.id, $0) })
        let petPoints = petFetch.records.compactMap { event -> WeightAbsolutePoint? in
            guard let rawID = event.subjectId,
                  let id = UUID(uuidString: rawID),
                  let subject = petByID[id],
                  event.amountValue > 0 else { return nil }
            return WeightAbsolutePoint(
                id: event.id,
                date: event.occurredAt,
                seriesID: subject.seriesID,
                displayName: subject.name,
                weight: event.amountValue,
                isHuman: false
            )
        }
        let humanPoints = humanFetch.records.compactMap { log -> WeightAbsolutePoint? in
            guard let id = log.human?.id,
                  let subject = humanByID[id],
                  log.weight > 0 else { return nil }
            return WeightAbsolutePoint(
                id: log.id,
                date: log.date,
                seriesID: subject.seriesID,
                displayName: subject.name,
                weight: log.weight,
                isHuman: true
            )
        }

        return WeightInsightSnapshot(
            revisionID: UUID(),
            points: (petPoints + humanPoints).sorted { $0.date < $1.date },
            isTruncated: petFetch.isTruncated || humanFetch.isTruncated,
            hasLoaded: true
        )
    }

    private func fetchPetWeights(
        cutoff: Date?,
        selectedPetID: UUID?,
        shouldFetch: Bool
    ) throws -> (records: [CareLedgerEvent], isTruncated: Bool) {
        guard shouldFetch else { return ([], false) }
        let subjectKind = CareLedgerSubjectKind.pet.rawValue
        let eventKind = CareLedgerEventKind.weight.rawValue
        var descriptor: FetchDescriptor<CareLedgerEvent>
        if let selectedPetID {
            let subjectID = selectedPetID.uuidString
            if let cutoff {
                descriptor = FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.subjectKind == subjectKind &&
                            event.eventKind == eventKind &&
                            event.subjectId == subjectID &&
                            event.occurredAt >= cutoff
                    },
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.subjectKind == subjectKind &&
                            event.eventKind == eventKind &&
                            event.subjectId == subjectID
                    },
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                )
            }
        } else if let cutoff {
            descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == subjectKind &&
                        event.eventKind == eventKind &&
                        event.occurredAt >= cutoff
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == subjectKind && event.eventKind == eventKind
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = Self.maximumRecordCount + 1
        let fetched = try modelContext.fetch(descriptor) // route-first-frame: allow deferred-fetch
        return (
            Array(fetched.prefix(Self.maximumRecordCount)),
            fetched.count > Self.maximumRecordCount
        )
    }

    private func fetchHumanWeights(
        cutoff: Date?,
        selectedHumanID: UUID?,
        shouldFetch: Bool
    ) throws -> (records: [HumanWeightLog], isTruncated: Bool) {
        guard shouldFetch else { return ([], false) }
        var descriptor: FetchDescriptor<HumanWeightLog>
        if let selectedHumanID {
            if let cutoff {
                descriptor = FetchDescriptor<HumanWeightLog>(
                    predicate: #Predicate<HumanWeightLog> { log in
                        log.human?.id == selectedHumanID && log.date >= cutoff
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<HumanWeightLog>(
                    predicate: #Predicate<HumanWeightLog> { $0.human?.id == selectedHumanID },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else if let cutoff {
            descriptor = FetchDescriptor<HumanWeightLog>(
                predicate: #Predicate<HumanWeightLog> { $0.date >= cutoff },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<HumanWeightLog>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        }
        descriptor.fetchLimit = Self.maximumRecordCount + 1
        let fetched = try modelContext.fetch(descriptor) // route-first-frame: allow deferred-fetch
        return (
            Array(fetched.prefix(Self.maximumRecordCount)),
            fetched.count > Self.maximumRecordCount
        )
    }

    private static func parseSubjectKey(_ key: String?) -> (kind: String, id: String)? {
        guard let key, let separator = key.firstIndex(of: ":") else { return nil }
        let kind = String(key[..<separator])
        let id = String(key[key.index(after: separator)...])
        guard !kind.isEmpty, !id.isEmpty else { return nil }
        return (kind, id)
    }
}

struct IslandWeightDashboard: View {
    var standalone: Bool = true

    @Query private var pets: [Pet]
    @Query private var humans: [Human]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var snapshot = WeightInsightSnapshot.empty
    @State private var requestedDayCount: Int? = 30
    @State private var requestedSubjectKey: String?
    @State private var loadTask: Task<Void, Never>?

    init(standalone: Bool = true) {
        self.standalone = standalone

        var petDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.passedAwayDate == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        petDescriptor.fetchLimit = 500
        _pets = Query(petDescriptor)

        var humanDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { $0.passedAwayDate == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        humanDescriptor.fetchLimit = 500
        _humans = Query(humanDescriptor)
    }

    var body: some View {
        IslandWeightDashboardContentView(
            standalone: standalone,
            pets: pets,
            humans: humans,
            snapshot: snapshot,
            onFilterChange: requestSnapshot,
            onRefresh: { scheduleLoad(force: true) }
        )
        .onAppear { scheduleLoad() }
        .onChange(of: pets.count) { scheduleLoad(force: true) }
        .onChange(of: humans.count) { scheduleLoad(force: true) }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleLoad(force: true)
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func requestSnapshot(
        _ range: IslandWeightDashboardContentView.WeightTimeFilter,
        _ subjectKey: String?
    ) {
        guard requestedDayCount != range.dayCount || requestedSubjectKey != subjectKey else { return }
        requestedDayCount = range.dayCount
        requestedSubjectKey = subjectKey
        scheduleLoad(force: true)
    }

    private func scheduleLoad(force: Bool = false) {
        guard force || !snapshot.hasLoaded else { return }
        loadTask?.cancel()
        let container = modelContext.container
        let dayCount = requestedDayCount
        let subjectKey = requestedSubjectKey
        let petDescriptors = pets.map {
            WeightInsightSubjectDescriptor(id: $0.id, name: $0.name, isHuman: false)
        }
        let humanDescriptors = humans.map {
            WeightInsightSubjectDescriptor(id: $0.id, name: $0.name, isHuman: true)
        }
        loadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 80)
            guard !Task.isCancelled else { return }
            do {
                snapshot = try await WeightInsightDataActor(modelContainer: container).load(
                    dayCount: dayCount,
                    subjectKey: subjectKey,
                    pets: petDescriptors,
                    humans: humanDescriptors
                )
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Weight insight snapshot load failed: \(error.localizedDescription)",
                    category: "DashboardRecords"
                )
            }
            loadTask = nil
        }
    }
}
