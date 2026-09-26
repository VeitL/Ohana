import Combine
import SwiftData
import SwiftUI

nonisolated enum HumanMedicationRouteReadPolicy {
    static let medicationPlanLimit = 256
    static let recentLogLimit = 2048

    static var medicationPlanFetchLimit: Int { medicationPlanLimit + 1 }
    static var recentLogFetchLimit: Int { recentLogLimit + 1 }
}

struct HumanMedicationView: View {
    let human: Human
    var showsDoneButton: Bool = true
    var onDoseTaken: (() -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @State private var referenceNow: Date

    init(
        human: Human,
        showsDoneButton: Bool = true,
        onDoseTaken: (() -> Void)? = nil,
        referenceNow: Date = Date()
    ) {
        self.human = human
        self.showsDoneButton = showsDoneButton
        self.onDoseTaken = onDoseTaken
        _referenceNow = State(initialValue: referenceNow)
    }

    var body: some View {
        HumanMedicationQueryContent(
            human: human,
            showsDoneButton: showsDoneButton,
            onDoseTaken: onDoseTaken,
            referenceNow: referenceNow
        )
        .id(dayIdentity)
        .onAppear(perform: refreshReferenceDate)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshReferenceDate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshReferenceDate()
        }
        .task(id: dayIdentity) {
            await refreshAtNextDayBoundary()
        }
    }

    private var dayIdentity: Date {
        HumanMedicationTimelineRefreshPolicy.dayIdentity(for: referenceNow)
    }

    private func refreshReferenceDate() {
        referenceNow = Date()
    }

    private func refreshAtNextDayBoundary() async {
        guard AppWorkloadPolicy.shared.shouldRunEssentialDeadlineTimer() else { return }
        let now = Date()
        guard let nextDay = HumanMedicationTimelineRefreshPolicy.nextDayBoundary(after: now) else { return }
        let delaySeconds = max(0.25, nextDay.timeIntervalSince(now) + 0.1)
        do {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        } catch {
            return
        }
        guard !Task.isCancelled,
              AppWorkloadPolicy.shared.shouldRunEssentialDeadlineTimer() else { return }
        refreshReferenceDate()
    }
}

private struct HumanMedicationQueryContent: View {
    let human: Human
    let showsDoneButton: Bool
    let onDoseTaken: (() -> Void)?
    let referenceNow: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Query private var activeMeds: [HumanMedication]
    @Query private var allLogs: [HumanMedicationLog]
    @State private var inactiveReadRevision = 0

    init(
        human: Human,
        showsDoneButton: Bool,
        onDoseTaken: (() -> Void)?,
        referenceNow: Date
    ) {
        self.human = human
        self.showsDoneButton = showsDoneButton
        self.onDoseTaken = onDoseTaken
        self.referenceNow = referenceNow

        let humanKey = human.id.uuidString
        let humanKeyLower = humanKey.lowercased()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceNow)
        let logStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let logEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? referenceNow
        // Active plans are fetched independently so an old long-running plan
        // cannot be displaced by a large amount of recently stopped history.
        var activeMedicationDescriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { med in
                (med.humanId.contains(humanKey) || med.humanId.contains(humanKeyLower)) &&
                    med.isActive
            },
            sortBy: [SortDescriptor(\HumanMedication.createdAt, order: .reverse)]
        )
        activeMedicationDescriptor.fetchLimit = HumanMedicationRouteReadPolicy.medicationPlanFetchLimit
        _activeMeds = Query(activeMedicationDescriptor)

        // `contains` keeps legacy owner strings with surrounding whitespace
        // readable while the UUID-length key still scopes the query to this
        // Human. Presentation also canonicalizes every row before use.
        var logDescriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                (log.humanId.contains(humanKey) || log.humanId.contains(humanKeyLower)) &&
                    log.scheduledTime >= logStart && log.scheduledTime < logEnd
            },
            sortBy: [SortDescriptor(\HumanMedicationLog.scheduledTime, order: .reverse)]
        )
        logDescriptor.fetchLimit = HumanMedicationRouteReadPolicy.recentLogFetchLimit
        _allLogs = Query(logDescriptor)
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: HumanMedicationInactiveRouteData(),
            refreshToken: inactiveReadRevision,
            loadDelayMilliseconds: 24,
            reloadDelayMilliseconds: 24,
            shouldLoad: { !$0.hasLoaded },
            load: {
                HumanMedicationInactiveRouteData.load(
                    humanID: human.id,
                    context: modelContext
                )
            }
        ) { inactiveData in
            content(inactiveData: inactiveData)
        }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates.dropFirst()) { _ in
            inactiveReadRevision &+= 1
        }
    }

    private func content(inactiveData: HumanMedicationInactiveRouteData) -> some View {
        let humanID = human.id.uuidString
        let active = Array(activeMeds.lazy.filter {
            $0.isActive && HumanMedicationLogStore.canonicalID($0.humanId) == humanID
        }.prefix(HumanMedicationRouteReadPolicy.medicationPlanLimit))
        let inactive = Array(inactiveData.medications.lazy.filter {
            !$0.isActive && HumanMedicationLogStore.canonicalID($0.humanId) == humanID
        }.prefix(HumanMedicationRouteReadPolicy.medicationPlanLimit))
        let logs = Array(allLogs.lazy.filter {
            HumanMedicationLogStore.canonicalID($0.humanId) == humanID
        }.prefix(HumanMedicationRouteReadPolicy.recentLogLimit))
        var seenMedicationIDs: Set<UUID> = []
        let medications = (active + inactive)
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seenMedicationIDs.insert($0.id).inserted }
        return HumanMedicationContentView(
            human: human,
            allMeds: medications,
            allLogs: logs,
            readCompleteness: HumanMedicationRouteReadCompleteness(
                activePlans: activeMeds.count <= HumanMedicationRouteReadPolicy.medicationPlanLimit,
                inactivePlanHistory: inactiveData.isComplete,
                recentLogs: allLogs.count <= HumanMedicationRouteReadPolicy.recentLogLimit
            ),
            showsDoneButton: showsDoneButton,
            onDoseTaken: onDoseTaken,
            referenceNow: referenceNow
        )
    }
}

private struct HumanMedicationInactiveRouteData {
    var medications: [HumanMedication] = []
    var hasLoaded = false
    var isComplete = false

    @MainActor
    static func load(humanID: UUID, context: ModelContext) -> HumanMedicationInactiveRouteData {
        let humanKey = humanID.uuidString
        let humanKeyLower = humanKey.lowercased()
        var descriptor = FetchDescriptor<HumanMedication>(
            predicate: #Predicate<HumanMedication> { medication in
                (medication.humanId.contains(humanKey) || medication.humanId.contains(humanKeyLower)) &&
                    !medication.isActive
            },
            sortBy: [SortDescriptor(\HumanMedication.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = HumanMedicationRouteReadPolicy.medicationPlanFetchLimit
        do {
            let medications = try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
            return HumanMedicationInactiveRouteData(
                medications: medications,
                hasLoaded: true,
                isComplete: medications.count <= HumanMedicationRouteReadPolicy.medicationPlanLimit
            )
        } catch {
            OhanaLog.warning(
                "Human medication inactive plans failed to load: \(error.localizedDescription)",
                category: "Medication"
            )
            return HumanMedicationInactiveRouteData(hasLoaded: true, isComplete: false)
        }
    }
}
