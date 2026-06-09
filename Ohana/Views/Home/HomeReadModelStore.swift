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

struct PreparedTabSnapshot: Identifiable {
    let id: VerticalSolidHomeTab
    let revision: HomeRevision
    let preparedAt: Date
    let title: String
}

struct HomeHeaderAvatarSnapshot: Equatable {
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
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: force ? 0 : 48)
            guard !Task.isCancelled else {
                finishRefreshTask(generation: generation)
                return
            }
            await refresh(
                context: context,
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
        context: ModelContext,
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
        let fetches = HomeReadModelFetches(context: context)
        let pets = fetches.pets()
        let humans = fetches.humans()
        guard await checkpoint(generation: generation, stage: "members", startedAt: startedAt) else { return }

        let plants = AppFeatureRouteGuard.shouldLoadPlantData ? fetches.plants() : []
        let electronicPets = fetches.electronicPets()
        guard await checkpoint(generation: generation, stage: "livingSurfaces", startedAt: startedAt) else { return }

        let events = fetches.events()
        let pendingReminders = fetches.pendingReminders()
        guard await checkpoint(generation: generation, stage: "schedule", startedAt: startedAt) else { return }

        let humanMedications = fetches.humanMedications()
        let humanMedicationLogs = fetches.humanMedicationLogs()
        let careLogs = fetches.careLogs()
        let walkLogs = fetches.walkLogs()
        let pottyLogs = fetches.pottyLogs()
        let humanWeightLogs = fetches.humanWeightLogs()
        guard await checkpoint(generation: generation, stage: "care", startedAt: startedAt) else { return }

        let familyTasks = fetches.familyTasks()
        let exchangeRequests = fetches.exchangeRequests()
        guard await checkpoint(generation: generation, stage: "collaboration", startedAt: startedAt) else { return }

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
            activeHumanIdRaw: activeHumanIdRaw,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: showDummyCards,
            petBondVaultRevision: petBondVaultRevision,
            equippedTitleRaw: equippedTitleRaw,
            language: language
        )
        let signature = VerticalSolidHomeSnapshotBuilder.signature(for: source)
        guard force || signature != lastSignature || externalRevision != revision else { return }

        let nextSnapshot = VerticalSolidHomeSnapshotBuilder.build(from: source)
        guard await checkpoint(generation: generation, stage: "snapshot", startedAt: startedAt) else { return }
        let activeHumanAvatar = HomeHeaderAvatarSnapshot(human: source.activeHuman)
        let avatarPreloadPayloads = avatarPayloads(
            snapshot: nextSnapshot,
            activeHuman: source.activeHuman
        )
        let avatarPreloadSignature = VerticalSolidHomePreloadPlanner.avatarSignature(for: avatarPreloadPayloads)
        let popoutPreloadPayloads = VerticalSolidHomePreloadPlanner.popoutPayloads(snapshot: nextSnapshot)
        let popoutPreloadSignature = VerticalSolidHomePreloadPlanner.popoutSignature(for: popoutPreloadPayloads)

        var nextRevision = externalRevision
        nextRevision.advance(for: externalRevision.lastCommand ?? .unknown(action: "homeReadModelRefresh"))

        snapshot = nextSnapshot
        revision = nextRevision
        payload = HomeReadModelPayload(
            source: source,
            snapshot: nextSnapshot,
            revision: nextRevision,
            signature: signature,
            activeHumanAvatar: activeHumanAvatar,
            avatarPreloadSignature: avatarPreloadSignature,
            avatarPreloadPayloads: avatarPreloadPayloads,
            popoutPreloadSignature: popoutPreloadSignature,
            popoutPreloadPayloads: popoutPreloadPayloads
        )
        preparedTabs[.home] = PreparedTabSnapshot(
            id: .home,
            revision: nextRevision,
            preparedAt: Date(),
            title: "home"
        )
        lastSignature = signature

        AppPerformanceMonitor.shared.record(
            "home_read_model_refresh",
            startedAt: startedAt,
            note: "pets=\(source.pets.count), humans=\(source.humans.count), events=\(source.events.count)"
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

private struct HomeReadModelFetches {
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
