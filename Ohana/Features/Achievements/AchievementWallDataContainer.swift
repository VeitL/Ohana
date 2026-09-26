//
//  AchievementWallDataContainer.swift
//  Ohana
//
//  Screen-level SwiftData query container for the achievement wall.
//

import SwiftData
import SwiftUI

struct AchievementWallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = AchievementWallRouteData()
    @State private var achievementSnapshot = AchievementWallSnapshot.empty
    @State private var loadErrorMessage: String?
    @State private var dataLoadTask: Task<Void, Never>?

    let pet: Pet
    var allPets: [Pet] = []
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    var body: some View {
        Group {
            if routeData.hasLoaded {
                AchievementWallContentView(
                    pet: pet,
                    allPets: allPets,
                    onPresentCoconutLog: onPresentCoconutLog,
                    electronicPets: routeData.electronicPets,
                    critterFragments: routeData.critterFragments,
                    critterActionLogs: routeData.critterActionLogs,
                    gachaOwnedItems: routeData.gachaOwnedItems,
                    gachaDrawLogs: routeData.gachaDrawLogs,
                    allHumans: routeData.allHumans,
                    humanMedications: routeData.humanMedications,
                    humanMedicationLogs: routeData.humanMedicationLogs,
                    allExpenseLogs: routeData.allExpenseLogs,
                    careLedgerEvents: routeData.careLedgerEvents,
                    petActivitySummaries: routeData.petActivitySummaries,
                    achievementSnapshot: achievementSnapshot
                )
            } else if let loadErrorMessage {
                ContentUnavailableView {
                    Label("Unable to load achievements", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadErrorMessage)
                } actions: {
                    Button("Retry") { scheduleRouteDataLoad(force: true) }
                }
            } else {
                ProgressView("Loading achievements…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OhanaAppBackground())
            }
        }
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
        loadErrorMessage = nil
        dataLoadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else { return }
            let loaded = AchievementWallRouteData.load(from: modelContext)
            let activePets = ([pet] + allPets).filter { !$0.hasPassedAway }
            let scopes = activePets.map { AchievementScopeReference.pet($0.id) }
                + loaded.allHumans.filter { !$0.hasPassedAway }.map { AchievementScopeReference.human($0.id) }
                + [.island]
            do {
                let progression = AchievementProgressionActor(modelContainer: modelContext.container)
                _ = try await progression.reconcile(
                    AchievementProgressionRequest(affectedScopes: scopes, reason: .wallOpened)
                )
                let reader = AchievementWallReadActor(modelContainer: modelContext.container)
                achievementSnapshot = try await reader.load(scopes: scopes)
                routeData = loaded
            } catch {
                loadErrorMessage = error.localizedDescription
            }
            dataLoadTask = nil
        }
    }
}

private struct AchievementWallRouteData {
    var electronicPets: [OasisElectronicPet] = []
    var critterFragments: [OasisCritterFragmentBalance] = []
    var critterActionLogs: [OasisCritterActionLog] = []
    var gachaOwnedItems: [GachaOwnedItem] = []
    var gachaDrawLogs: [GachaDrawLog] = []
    var allHumans: [Human] = []
    var humanMedications: [HumanMedication] = []
    var humanMedicationLogs: [HumanMedicationLog] = []
    var allExpenseLogs: [PetExpenseLog] = []
    var careLedgerEvents: [CareLedgerEvent] = []
    var petActivitySummaries: [UUID: AchievementPetActivitySummary] = [:]
    var hasLoaded = false

    static func load(from context: ModelContext) -> AchievementWallRouteData {
        AchievementWallRouteData(
            electronicPets: fetch(
                FetchDescriptor<OasisElectronicPet>(sortBy: [SortDescriptor(\.obtainedAt, order: .reverse)]),
                context: context,
                name: "OasisElectronicPet"
            ),
            critterFragments: fetch(
                FetchDescriptor<OasisCritterFragmentBalance>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]),
                context: context,
                name: "OasisCritterFragmentBalance"
            ),
            critterActionLogs: fetch(
                FetchDescriptor<OasisCritterActionLog>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
                context: context,
                name: "OasisCritterActionLog"
            ),
            gachaOwnedItems: fetch(
                FetchDescriptor<GachaOwnedItem>(sortBy: [SortDescriptor(\.latestObtainedAt, order: .reverse)]),
                context: context,
                name: "GachaOwnedItem"
            ),
            gachaDrawLogs: fetch(
                FetchDescriptor<GachaDrawLog>(sortBy: [SortDescriptor(\.drawDate, order: .reverse)]),
                context: context,
                name: "GachaDrawLog"
            ),
            allHumans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
                context: context,
                name: "Human"
            ),
            humanMedications: fetch(
                FetchDescriptor<HumanMedication>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
                context: context,
                name: "HumanMedication"
            ),
            humanMedicationLogs: fetch(
                FetchDescriptor<HumanMedicationLog>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]),
                context: context,
                name: "HumanMedicationLog"
            ),
            allExpenseLogs: fetch(
                FetchDescriptor<PetExpenseLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]),
                context: context,
                name: "PetExpenseLog"
            ),
            careLedgerEvents: fetchCareLedgerEvents(context: context),
            petActivitySummaries: AchievementPetActivityRouteData.loadPetActivitySummaries(from: context),
            hasLoaded: true
        )
    }

    private static func fetchCareLedgerEvents(context: ModelContext) -> [CareLedgerEvent] {
        let petSubjectKind = CareLedgerSubjectKind.pet.rawValue
        return fetch(
            FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == petSubjectKind
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            ),
            context: context,
            name: "CareLedgerEvent"
        )
        .filter(isAchievementLedgerEvent)
    }

    private nonisolated static func isAchievementLedgerEvent(_ event: CareLedgerEvent) -> Bool {
        switch event.eventKindEnum {
        case .care, .potty, .walk, .hygiene, .health, .weight, .expense, .medication, .milestone:
            true
        case .workout, .reminder, .plantCare, .coconut, .unknown:
            false
        }
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
                "Achievement wall route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Achievements"
            )
            return []
        }
    }
}
