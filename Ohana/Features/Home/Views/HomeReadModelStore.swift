//
//  HomeReadModelStore.swift
//  Ohana
//
//  Narrow SwiftData fetch boundary for the high-frequency home shell.
//

import Combine
import Foundation
import SwiftData

typealias HomeSnapshot = VerticalSolidHomeSnapshot

nonisolated struct PreparedTabSnapshot: Identifiable {
    let id: VerticalSolidHomeTab
    let revision: HomeRevision
    let preparedAt: Date
    let title: String
}

nonisolated struct HomeHeaderAvatarSnapshot: Equatable, Sendable {
    let id: UUID?
    let signature: String

    static let empty = HomeHeaderAvatarSnapshot(id: nil, signature: "")

    init(id: UUID?, signature: String) {
        self.id = id
        self.signature = signature
    }

    init(human: Human?) {
        guard let human, let data = human.avatarImageData else {
            self = .empty
            return
        }
        id = human.id
        signature = FocusWalletAvatarCache.signature(for: data)
    }
}

struct HomeReadModelPayload {
    let source: VerticalSolidHomeSourceState
    let snapshot: HomeSnapshot
    let revision: HomeRevision
    let signature: String
    let activeHumanAvatar: HomeHeaderAvatarSnapshot
    let avatarPreloadSignature: String
    let avatarPreloadPayloads: [FocusWalletAvatarCache.Payload]
    let popoutPreloadSignature: String
    let popoutPreloadPayloads: [FocusWalletAvatarCache.Payload]

    static let empty = HomeReadModelPayload(
        source: VerticalSolidHomeSourceState(
            pets: [],
            humans: [],
            plants: [],
            electronicPets: [],
            events: [],
            pendingReminders: [],
            humanMedications: [],
            humanMedicationLogs: [],
            careLogs: [],
            walkLogs: [],
            pottyLogs: [],
            humanWeightLogs: [],
            familyTasks: [],
            exchangeRequests: [],
            activeHumanIdRaw: "",
            hiddenPetIDsRaw: "",
            homeCardOrderRaw: "",
            showDummyCards: false,
            petBondVaultRevision: 0,
            equippedTitleRaw: "",
            language: AppLanguage.code
        ),
        snapshot: .empty,
        revision: HomeRevision(),
        signature: "",
        activeHumanAvatar: .empty,
        avatarPreloadSignature: "",
        avatarPreloadPayloads: [],
        popoutPreloadSignature: "",
        popoutPreloadPayloads: []
    )
}

nonisolated struct HomeReadModelActorInput: Sendable {
    let activeHumanIdRaw: String
    let hiddenPetIDsRaw: String
    let homeCardOrderRaw: String
    let showDummyCards: Bool
    let petBondVaultRevision: Int
    let equippedTitleRaw: String
    let language: String
    let loadPlants: Bool
}

nonisolated struct HomeReadModelActorResult: Sendable {
    let snapshot: HomeSnapshot
    let signature: String
    let activeHumanAvatar: HomeHeaderAvatarSnapshot
    let avatarPreloadSignature: String
    let avatarPreloadPayloads: [FocusWalletAvatarCache.Payload]
    let popoutPreloadSignature: String
    let popoutPreloadPayloads: [FocusWalletAvatarCache.Payload]
    let petCount: Int
    let humanCount: Int
    let eventCount: Int
}

@MainActor
final class HomeReadModelStore: ObservableObject {
    @Published private(set) var snapshot: HomeSnapshot = .empty
    @Published private(set) var revision = HomeRevision()
    @Published private(set) var preparedTabs: [VerticalSolidHomeTab: PreparedTabSnapshot] = [
        .home: PreparedTabSnapshot(
            id: .home,
            revision: HomeRevision(),
            preparedAt: Date(),
            title: "home"
        ),
    ]
    @Published private(set) var payload = HomeReadModelPayload.empty

    private var lastSignature = ""
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private let privacy: HumanPrivacyManaging
    private let todayFocus: TodayFocusManaging
    private let healthAlerts: PetHealthAlerting

    init(
        privacy: HumanPrivacyManaging? = nil,
        todayFocus: TodayFocusManaging? = nil,
        healthAlerts: PetHealthAlerting? = nil
    ) {
        self.privacy = privacy ?? StaticHumanPrivacyManager()
        self.todayFocus = todayFocus ?? StaticTodayFocusManager()
        self.healthAlerts = healthAlerts ?? SharedPetHealthAlertEngine()
    }

    func requestRefresh(
        context: ModelContext,
        activeHumanIdRaw: String,
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        petBondVaultRevision: Int = 0,
        equippedTitleRaw: String = "",
        language: String,
        externalRevision: HomeRevision,
        force: Bool = false
    ) {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let container = context.container
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: force ? 0 : 48)
            guard !Task.isCancelled else {
                self?.finishRefreshTask(generation: generation)
                return
            }
            await self?.refresh(
                container: container,
                activeHumanIdRaw: activeHumanIdRaw,
                hiddenPetIDsRaw: hiddenPetIDsRaw,
                homeCardOrderRaw: homeCardOrderRaw,
                showDummyCards: showDummyCards,
                petBondVaultRevision: petBondVaultRevision,
                equippedTitleRaw: equippedTitleRaw,
                language: language,
                externalRevision: externalRevision,
                generation: generation,
                force: force
            )
            self?.finishRefreshTask(generation: generation)
        }
    }

    func refreshImmediately(
        context: ModelContext,
        activeHumanIdRaw: String,
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        petBondVaultRevision: Int = 0,
        equippedTitleRaw: String = "",
        language: String,
        externalRevision: HomeRevision,
        force: Bool = true
    ) async {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        refreshTask?.cancel()
        refreshTask = nil
        await refresh(
            container: context.container,
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            petBondVaultRevision: petBondVaultRevision,
            equippedTitleRaw: equippedTitleRaw,
            language: language,
            externalRevision: externalRevision,
            generation: generation,
            force: force
        )
        finishRefreshTask(generation: generation)
    }

    func cancel() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func finishRefreshTask(generation: Int) {
        guard generation == refreshGeneration else { return }
        refreshTask = nil
    }

    private func refresh(
        container: ModelContainer,
        activeHumanIdRaw: String,
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        petBondVaultRevision: Int,
        equippedTitleRaw: String,
        language: String,
        externalRevision: HomeRevision,
        generation: Int,
        force: Bool = false
    ) async {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let input = HomeReadModelActorInput(
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            petBondVaultRevision: petBondVaultRevision,
            equippedTitleRaw: equippedTitleRaw,
            language: language,
            loadPlants: AppFeatureRouteGuard.shouldLoadPlantData
        )

        let actor = HomeReadModelActor(modelContainer: container)
        let actorResult: HomeReadModelActorResult?
        do {
            actorResult = try await actor.refreshPayload(
                input: input,
                previousSignature: lastSignature,
                currentRevision: revision,
                externalRevision: externalRevision,
                force: force
            )
        } catch is CancellationError {
            return
        } catch {
            AppPerformanceMonitor.shared.record(
                "home_read_model_refresh_failed",
                startedAt: startedAt,
                note: error.localizedDescription
            )
            return
        }

        guard let actorResult else { return }
        guard await checkpoint(generation: generation, stage: "actorPayload", startedAt: startedAt) else { return }

        let source = compatibilitySource(container: container, input: input)
        guard await checkpoint(generation: generation, stage: "compatibilitySource", startedAt: startedAt) else { return }

        var nextRevision = externalRevision
        nextRevision.advance(for: externalRevision.lastCommand ?? .unknown(action: "homeReadModelRefresh"))

        snapshot = actorResult.snapshot
        revision = nextRevision
        payload = HomeReadModelPayload(
            source: source,
            snapshot: actorResult.snapshot,
            revision: nextRevision,
            signature: actorResult.signature,
            activeHumanAvatar: actorResult.activeHumanAvatar,
            avatarPreloadSignature: actorResult.avatarPreloadSignature,
            avatarPreloadPayloads: actorResult.avatarPreloadPayloads,
            popoutPreloadSignature: actorResult.popoutPreloadSignature,
            popoutPreloadPayloads: actorResult.popoutPreloadPayloads
        )
        preparedTabs[.home] = PreparedTabSnapshot(
            id: .home,
            revision: nextRevision,
            preparedAt: Date(),
            title: "home"
        )
        lastSignature = actorResult.signature

        AppPerformanceMonitor.shared.record(
            "home_read_model_refresh",
            startedAt: startedAt,
            note: "pets=\(actorResult.petCount), humans=\(actorResult.humanCount), events=\(actorResult.eventCount)"
        )
    }

    private func checkpoint(generation: Int, stage: String, startedAt: CFAbsoluteTime) async -> Bool {
        await Task.yield()
        guard !Task.isCancelled, generation == refreshGeneration else {
            AppPerformanceMonitor.shared.record(
                "home_read_model_refresh_cancelled",
                startedAt: startedAt,
                note: stage
            )
            return false
        }
        return true
    }

    private func compatibilitySource(
        container: ModelContainer,
        input: HomeReadModelActorInput
    ) -> VerticalSolidHomeSourceState {
        let fetches = HomeReadModelFetches(context: container.mainContext)
        return VerticalSolidHomeSourceState(
            pets: fetches.pets(),
            humans: fetches.humans(),
            plants: input.loadPlants ? fetches.plants() : [],
            electronicPets: fetches.electronicPets(),
            events: fetches.events(),
            pendingReminders: fetches.pendingReminders(),
            humanMedications: fetches.humanMedications(),
            humanMedicationLogs: fetches.humanMedicationLogs(),
            careLogs: fetches.careLogs(),
            walkLogs: fetches.walkLogs(),
            pottyLogs: fetches.pottyLogs(),
            humanWeightLogs: fetches.humanWeightLogs(),
            familyTasks: fetches.familyTasks(),
            exchangeRequests: fetches.exchangeRequests(),
            activeHumanIdRaw: input.activeHumanIdRaw,
            hiddenPetIDsRaw: input.hiddenPetIDsRaw,
            homeCardOrderRaw: input.homeCardOrderRaw,
            showDummyCards: input.showDummyCards,
            petBondVaultRevision: input.petBondVaultRevision,
            equippedTitleRaw: input.equippedTitleRaw,
            language: input.language
        )
    }

    private func avatarPayloads(
        snapshot: HomeSnapshot,
        activeHuman: Human?
    ) -> [FocusWalletAvatarCache.Payload] {
        var payloads = VerticalSolidHomePreloadPlanner.avatarPayloads(snapshot: snapshot)
        guard let activeHuman,
              activeHuman.avatarImageData != nil,
              !payloads.contains(where: { $0.id == activeHuman.id }) else {
            return payloads
        }
        payloads.append(FocusWalletAvatarCache.Payload(id: activeHuman.id, data: activeHuman.avatarImageData))
        return payloads
    }

    func markPrepared(_ tab: VerticalSolidHomeTab) {
        preparedTabs[tab] = PreparedTabSnapshot(
            id: tab,
            revision: revision,
            preparedAt: Date(),
            title: String(describing: tab)
        )
    }
}

@ModelActor
actor HomeReadModelActor {
    func refreshPayload(
        input: HomeReadModelActorInput,
        previousSignature: String,
        currentRevision: HomeRevision,
        externalRevision: HomeRevision,
        force: Bool
    ) throws -> HomeReadModelActorResult? {
        let fetches = HomeReadModelFetches(context: modelContext)
        let pets = fetches.pets()
        let humans = fetches.humans()
        try Task.checkCancellation()

        let plants = input.loadPlants ? fetches.plants() : []
        let electronicPets = fetches.electronicPets()
        try Task.checkCancellation()

        let events = fetches.events()
        let pendingReminders = fetches.pendingReminders()
        try Task.checkCancellation()

        let humanMedications = fetches.humanMedications()
        let humanMedicationLogs = fetches.humanMedicationLogs()
        let careLogs = fetches.careLogs()
        let walkLogs = fetches.walkLogs()
        let pottyLogs = fetches.pottyLogs()
        let humanWeightLogs = fetches.humanWeightLogs()
        try Task.checkCancellation()

        let familyTasks = fetches.familyTasks()
        let exchangeRequests = fetches.exchangeRequests()
        try Task.checkCancellation()

        let source = VerticalSolidHomeSourceState(
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            events: events,
            pendingReminders: pendingReminders,
            humanMedications: humanMedications,
            humanMedicationLogs: humanMedicationLogs,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            familyTasks: familyTasks,
            exchangeRequests: exchangeRequests,
            activeHumanIdRaw: input.activeHumanIdRaw,
            hiddenPetIDsRaw: input.hiddenPetIDsRaw,
            homeCardOrderRaw: input.homeCardOrderRaw,
            showDummyCards: input.showDummyCards,
            petBondVaultRevision: input.petBondVaultRevision,
            equippedTitleRaw: input.equippedTitleRaw,
            language: input.language
        )
        let signature = VerticalSolidHomeSnapshotBuilder.signature(for: source)
        guard force || signature != previousSignature || externalRevision != currentRevision else { return nil }

        let snapshot = VerticalSolidHomeSnapshotBuilder.buildForReadModelActor(from: source)
        try Task.checkCancellation()

        let activeHumanAvatar = HomeHeaderAvatarSnapshot(human: source.activeHuman)
        let avatarPreloadPayloads = Self.avatarPayloads(
            snapshot: snapshot,
            activeHuman: source.activeHuman
        )
        let avatarPreloadSignature = VerticalSolidHomePreloadPlanner.avatarSignature(for: avatarPreloadPayloads)
        let popoutPreloadPayloads = VerticalSolidHomePreloadPlanner.popoutPayloads(snapshot: snapshot)
        let popoutPreloadSignature = VerticalSolidHomePreloadPlanner.popoutSignature(for: popoutPreloadPayloads)

        return HomeReadModelActorResult(
            snapshot: snapshot,
            signature: signature,
            activeHumanAvatar: activeHumanAvatar,
            avatarPreloadSignature: avatarPreloadSignature,
            avatarPreloadPayloads: avatarPreloadPayloads,
            popoutPreloadSignature: popoutPreloadSignature,
            popoutPreloadPayloads: popoutPreloadPayloads,
            petCount: pets.count,
            humanCount: humans.count,
            eventCount: events.count
        )
    }

    private static func avatarPayloads(
        snapshot: HomeSnapshot,
        activeHuman: Human?
    ) -> [FocusWalletAvatarCache.Payload] {
        var payloads = VerticalSolidHomePreloadPlanner.avatarPayloads(snapshot: snapshot)
        guard let activeHuman,
              activeHuman.avatarImageData != nil,
              !payloads.contains(where: { $0.id == activeHuman.id }) else {
            return payloads
        }
        payloads.append(FocusWalletAvatarCache.Payload(id: activeHuman.id, data: activeHuman.avatarImageData))
        return payloads
    }
}

nonisolated private struct HomeReadModelFetches {
    let context: ModelContext
    private let calendar = Calendar.current

    func pets() -> [Pet] {
        var descriptor = FetchDescriptor<Pet>(
            sortBy: [SortDescriptor(\Pet.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    func humans() -> [Human] {
        var descriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return (try? context.fetch(descriptor)) ?? []
    }

    func plants() -> [Plant] {
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\Plant.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 60
        return (try? context.fetch(descriptor)) ?? []
    }

    func electronicPets() -> [OasisElectronicPet] {
        var descriptor = FetchDescriptor<OasisElectronicPet>(
            sortBy: [SortDescriptor(\OasisElectronicPet.obtainedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 24
        return (try? context.fetch(descriptor)) ?? []
    }

    func events() -> [Event] {
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? Date(timeIntervalSinceNow: 14 * 24 * 60 * 60)
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.startDate >= start && event.startDate <= end
            },
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        descriptor.fetchLimit = 160
        return (try? context.fetch(descriptor)) ?? []
    }

    func pendingReminders() -> [Reminder] {
        let pendingStatus = "pending"
        let failedStatus = "failed"
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.status == pendingStatus || reminder.status == failedStatus
            },
            sortBy: [SortDescriptor(\Reminder.scheduledAt)]
        )
        descriptor.fetchLimit = 60
        return (try? context.fetch(descriptor)) ?? []
    }

    func humanMedications() -> [HumanMedication] {
        var descriptor = FetchDescriptor<HumanMedication>(
            sortBy: [SortDescriptor(\HumanMedication.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    func humanMedicationLogs() -> [HumanMedicationLog] {
        let today = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                log.scheduledTime >= today
            },
            sortBy: [SortDescriptor(\HumanMedicationLog.scheduledTime, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    func careLogs() -> [PetCareLog] {
        let today = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.date >= today
            },
            sortBy: [SortDescriptor(\PetCareLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = 180
        return (try? context.fetch(descriptor)) ?? []
    }

    func walkLogs() -> [PetWalkLog] {
        let today = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { log in
                log.startDate >= today
            },
            sortBy: [SortDescriptor(\PetWalkLog.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    func pottyLogs() -> [PetPottyLog] {
        let today = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<PetPottyLog>(
            predicate: #Predicate<PetPottyLog> { log in
                log.date >= today
            },
            sortBy: [SortDescriptor(\PetPottyLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = 120
        return (try? context.fetch(descriptor)) ?? []
    }

    func humanWeightLogs() -> [HumanWeightLog] {
        let today = calendar.startOfDay(for: Date())
        var descriptor = FetchDescriptor<HumanWeightLog>(
            predicate: #Predicate<HumanWeightLog> { log in
                log.date >= today
            },
            sortBy: [SortDescriptor(\HumanWeightLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return (try? context.fetch(descriptor)) ?? []
    }

    func familyTasks() -> [FamilyCollaborationTask] {
        let activeStatus = FamilyCollaborationTaskStatus.active.rawValue
        let claimedStatus = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReviewStatus = FamilyCollaborationTaskStatus.pendingReview.rawValue
        var descriptor = FetchDescriptor<FamilyCollaborationTask>(
            predicate: #Predicate<FamilyCollaborationTask> { task in
                task.statusRaw == activeStatus ||
                task.statusRaw == claimedStatus ||
                task.statusRaw == pendingReviewStatus
            },
            sortBy: [SortDescriptor(\FamilyCollaborationTask.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    func exchangeRequests() -> [CoconutExchangeRequest] {
        let pendingStatus = CoconutExchangeRequestStatus.pending.rawValue
        var descriptor = FetchDescriptor<CoconutExchangeRequest>(
            predicate: #Predicate<CoconutExchangeRequest> { request in
                request.statusRaw == pendingStatus
            },
            sortBy: [SortDescriptor(\CoconutExchangeRequest.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return (try? context.fetch(descriptor)) ?? []
    }
}
