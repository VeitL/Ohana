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
        guard let human, human.hasAvatarImageAttachment else {
            self = .empty
            return
        }
        id = human.id
        signature = human.avatarThumbnailSignature
    }
}

struct HomeReadModelPayload {
    let snapshot: HomeSnapshot
    let interaction: HomeInteractionSnapshot
    let revision: HomeRevision
    let signature: String
    let activeHumanAvatar: HomeHeaderAvatarSnapshot
    let avatarPreloadSignature: String
    let mediaPreloadRequests: [VerticalSolidHomeMediaPreloadRequest]
    let avatarPreloadPayloads: [FocusWalletAvatarCache.Payload]
    let popoutPreloadSignature: String
    let popoutPreloadPayloads: [FocusWalletAvatarCache.Payload]

    static let empty = HomeReadModelPayload(
        snapshot: .empty,
        interaction: .empty,
        revision: HomeRevision(),
        signature: "",
        activeHumanAvatar: .empty,
        avatarPreloadSignature: "",
        mediaPreloadRequests: [],
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
    let quickActionItemsRaw: String
    let language: String
    let loadPlants: Bool
}

nonisolated struct HomeReadModelActorResult: Sendable {
    let snapshot: HomeSnapshot
    let interaction: HomeInteractionSnapshot
    let signature: String
    let activeHumanAvatar: HomeHeaderAvatarSnapshot
    let avatarPreloadSignature: String
    let mediaPreloadRequests: [VerticalSolidHomeMediaPreloadRequest]
    let avatarPreloadPayloads: [FocusWalletAvatarCache.Payload]
    let popoutPreloadSignature: String
    let popoutPreloadPayloads: [FocusWalletAvatarCache.Payload]
    let petCount: Int
    let humanCount: Int
    let eventCount: Int
}

@MainActor
final class HomeReadModelStore: ObservableObject {
    private(set) var snapshot: HomeSnapshot = .empty
    private(set) var revision = HomeRevision()
    private(set) var preparedTabs: [VerticalSolidHomeTab: PreparedTabSnapshot] = [
        .home: PreparedTabSnapshot(
            id: .home,
            revision: HomeRevision(),
            preparedAt: Date(),
            title: "home"
        )
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
        quickActionItemsRaw: String = "",
        language: String,
        externalRevision: HomeRevision,
        force: Bool = false
    ) {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let container = context.container
        let refreshDelay = OnboardingHomeJoinHandoffGate.remainingHomeReadModelDelayMilliseconds(
            defaultDelayMilliseconds: force ? 0 : 48
        )
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: refreshDelay)
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
                quickActionItemsRaw: quickActionItemsRaw,
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
        quickActionItemsRaw: String = "",
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
            quickActionItemsRaw: quickActionItemsRaw,
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
        quickActionItemsRaw: String,
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
            quickActionItemsRaw: quickActionItemsRaw,
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

        var nextRevision = externalRevision
        nextRevision.advance(for: externalRevision.lastCommand ?? .unknown(action: "homeReadModelRefresh"))

        snapshot = actorResult.snapshot
        revision = nextRevision
        payload = HomeReadModelPayload(
            snapshot: actorResult.snapshot,
            interaction: actorResult.interaction,
            revision: nextRevision,
            signature: actorResult.signature,
            activeHumanAvatar: actorResult.activeHumanAvatar,
            avatarPreloadSignature: actorResult.avatarPreloadSignature,
            mediaPreloadRequests: actorResult.mediaPreloadRequests,
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
        let now = Date()
        let fetches = HomeReadModelFetches(context: modelContext, now: now)
        let pets = fetches.pets()
        let humans = fetches.humans()
        try Task.checkCancellation()

        let plants = input.loadPlants ? fetches.plants() : []
        if !plants.isEmpty {
            PlantUnlockPolicy.noteExistingPlantData()
        }
        let electronicPets = fetches.electronicPets()
        try Task.checkCancellation()

        let events = fetches.events()
        let pendingReminders = fetches.pendingReminders()
        try Task.checkCancellation()

        let humanMedications = fetches.humanMedications()
        let humanMedicationLogs = fetches.humanMedicationLogs()
        let healthAlertSources = fetches.healthAlertSources(pets: pets)
        let todayFocusCareLedgerEntries = fetches.todayFocusCareLedgerEntries()
        let feedingLedgerEntries = fetches.feedingLedgerEntries()
        let careLedgerEntries = fetches.careQuickActionEntries()
        let hygieneLedgerEntries = fetches.hygieneQuickActionEntries()
        let walkLedgerEntries = fetches.walkQuickActionEntries()
        let pottyLedgerEntries = fetches.pottyQuickActionEntries()
        let petExpenseLedgerEntries = fetches.petExpenseQuickActionEntries()
        let petWeightLedgerEntries = fetches.petWeightQuickActionEntries()
        let petMomentEntries = fetches.petMomentQuickActionEntries()
        let humanWeightLogs = fetches.humanWeightLogs()
        try Task.checkCancellation()

        let familyTasks = OnlineFeatureGate.allows(.onlineCollaboration) ? fetches.familyTasks() : []
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
            healthAlertSources: healthAlertSources,
            todayFocusCareLedgerEntries: todayFocusCareLedgerEntries,
            feedingLedgerEntries: feedingLedgerEntries,
            careLedgerEntries: careLedgerEntries,
            hygieneLedgerEntries: hygieneLedgerEntries,
            walkLedgerEntries: walkLedgerEntries,
            pottyLedgerEntries: pottyLedgerEntries,
            petExpenseLedgerEntries: petExpenseLedgerEntries,
            petWeightLedgerEntries: petWeightLedgerEntries,
            petMomentEntries: petMomentEntries,
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
        let signature = VerticalSolidHomeSnapshotBuilder.signature(for: source, now: now)
        guard force || signature != previousSignature || externalRevision != currentRevision else { return nil }

        let snapshot = VerticalSolidHomeSnapshotBuilder.buildForReadModelActor(from: source, now: now)
        let interaction = HomeInteractionSnapshotBuilder.build(
            from: source,
            quickActionItemsRaw: input.quickActionItemsRaw,
            now: now
        )
        try Task.checkCancellation()

        let activeHumanAvatar = HomeHeaderAvatarSnapshot(human: source.activeHuman)
        let mediaPreloadRequests = VerticalSolidHomePreloadPlanner.mediaRequests(
            snapshot: snapshot,
            pets: pets,
            humans: humans,
            activeHuman: source.activeHuman
        )
        let avatarPreloadSignature = VerticalSolidHomePreloadPlanner.mediaSignature(for: mediaPreloadRequests)

        return HomeReadModelActorResult(
            snapshot: snapshot,
            interaction: interaction,
            signature: signature,
            activeHumanAvatar: activeHumanAvatar,
            avatarPreloadSignature: avatarPreloadSignature,
            mediaPreloadRequests: mediaPreloadRequests,
            avatarPreloadPayloads: [],
            popoutPreloadSignature: "",
            popoutPreloadPayloads: [],
            petCount: pets.count,
            humanCount: humans.count,
            eventCount: events.count
        )
    }
}

private nonisolated struct HomeReadModelFetches {
    let context: ModelContext
    let now: Date
    private let calendar = Calendar.current

    func pets() -> [Pet] {
        var descriptor = FetchDescriptor<Pet>(
            sortBy: [SortDescriptor(\Pet.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return fetchOrLog(descriptor, operation: "fetch home pets")
    }

    func humans() -> [Human] {
        var descriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return fetchOrLog(descriptor, operation: "fetch home humans")
    }

    func plants() -> [Plant] {
        var descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\Plant.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 60
        return fetchOrLog(descriptor, operation: "fetch home plants")
    }

    func electronicPets() -> [OasisElectronicPet] {
        var descriptor = FetchDescriptor<OasisElectronicPet>(
            sortBy: [SortDescriptor(\OasisElectronicPet.obtainedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 24
        return fetchOrLog(descriptor, operation: "fetch home electronic pets")
    }

    func events() -> [Event] {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start.addingTimeInterval(14 * 24 * 60 * 60)
        var windowDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.startDate >= start && event.startDate <= end
            },
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        windowDescriptor.fetchLimit = 400
        let windowEvents: [Event] = fetchOrLog(windowDescriptor, operation: "fetch home event window")

        var recurringDescriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.recurrenceDays > 0 && event.startDate <= end
            },
            sortBy: [SortDescriptor(\Event.startDate, order: .reverse)]
        )
        recurringDescriptor.fetchLimit = 400
        let recurringEvents: [Event] = fetchOrLog(recurringDescriptor, operation: "fetch home recurring events")
            .filter { event in
                guard let recurrenceEndDate = event.recurrenceEndDate else { return true }
                return calendar.startOfDay(for: recurrenceEndDate) >= start
            }

        var seen: Set<UUID> = []
        return (windowEvents + recurringEvents)
            .filter { event in
                guard !seen.contains(event.id) else { return false }
                seen.insert(event.id)
                return true
            }
            .sorted { $0.startDate < $1.startDate }
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
        return fetchOrLog(descriptor, operation: "fetch home pending reminders")
    }

    func humanMedications() -> [HumanMedication] {
        var descriptor = FetchDescriptor<HumanMedication>(
            sortBy: [SortDescriptor(\HumanMedication.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return fetchOrLog(descriptor, operation: "fetch home human medications")
    }

    func humanMedicationLogs() -> [HumanMedicationLog] {
        let today = calendar.startOfDay(for: now)
        var descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                log.scheduledTime >= today
            },
            sortBy: [SortDescriptor(\HumanMedicationLog.scheduledTime, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return fetchOrLog(descriptor, operation: "fetch home human medication logs")
    }

    func healthAlertSources(pets: [Pet]) -> [PetHealthAlertSource] {
        PetHealthAlertSourceRouteData.load(pets: pets, from: context)
    }

    func todayFocusCareLedgerEntries() -> [TodayFocusCareLedgerEntry] {
        let today = calendar.startOfDay(for: now)
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let plantSubject = CareLedgerSubjectKind.plant.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let walkKind = CareLedgerEventKind.walk.rawValue
        let pottyKind = CareLedgerEventKind.potty.rawValue
        let weightKind = CareLedgerEventKind.weight.rawValue
        let plantCareKind = CareLedgerEventKind.plantCare.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= today &&
                    ((event.subjectKind == petSubject &&
                            (event.eventKind == careKind ||
                                event.eventKind == walkKind ||
                                event.eventKind == pottyKind ||
                                event.eventKind == weightKind)) ||
                        (event.subjectKind == plantSubject &&
                            event.eventKind == plantCareKind))
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 360
        do {
            return try context.fetch(descriptor).compactMap(Self.todayFocusCareLedgerEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model today focus care ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func feedingLedgerEntries() -> [HomeFeedQuickActionEntry] {
        let today = calendar.startOfDay(for: now)
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingAction = CareType.feeding.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= today &&
                    event.subjectKind == petSubject &&
                    event.eventKind == careKind &&
                    event.actionType == feedingAction
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 180
        do {
            return try context.fetch(descriptor).compactMap(Self.feedingLedgerEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model feeding ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func careQuickActionEntries() -> [HomeCareQuickActionEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingAction = CareType.feeding.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.eventKind == careKind &&
                    event.actionType != feedingAction
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 360
        do {
            return try context.fetch(descriptor).compactMap(Self.careQuickActionEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model care ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func hygieneQuickActionEntries() -> [HomeHygieneQuickActionEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let hygieneKind = CareLedgerEventKind.hygiene.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.eventKind == hygieneKind
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 240
        do {
            return try context.fetch(descriptor).compactMap(Self.hygieneQuickActionEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model hygiene ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func walkQuickActionEntries() -> [HomeWalkQuickActionEntry] {
        let today = calendar.startOfDay(for: now)
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let walkKind = CareLedgerEventKind.walk.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= today &&
                    event.subjectKind == petSubject &&
                    event.eventKind == walkKind
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        do {
            return try context.fetch(descriptor).compactMap(Self.walkQuickActionEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model walk ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func pottyQuickActionEntries() -> [HomePottyQuickActionEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let pottyKind = CareLedgerEventKind.potty.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.eventKind == pottyKind
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 180
        do {
            return try context.fetch(descriptor).compactMap(Self.pottyQuickActionEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model potty ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func petExpenseQuickActionEntries() -> [HomePetExpenseQuickActionEntry] {
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let monthStart = monthInterval?.start ?? calendar.startOfDay(for: now)
        let monthEnd = monthInterval?.end ?? now
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let expenseKind = CareLedgerEventKind.expense.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= monthStart &&
                    event.occurredAt < monthEnd &&
                    event.subjectKind == petSubject &&
                    event.eventKind == expenseKind
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 240
        do {
            return try context.fetch(descriptor).compactMap(Self.petExpenseQuickActionEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model pet expense ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func petWeightQuickActionEntries() -> [HomePetWeightQuickActionEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let weightKind = CareLedgerEventKind.weight.rawValue
        let petWeightAction = "petWeight"
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.eventKind == weightKind &&
                    event.actionType == petWeightAction
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 240
        do {
            return try context.fetch(descriptor).compactMap(Self.petWeightQuickActionEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model pet weight ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func petMomentQuickActionEntries() -> [HomePetMomentQuickActionEntry] {
        var descriptor = FetchDescriptor<PetPhotoLog>(
            sortBy: [SortDescriptor(\PetPhotoLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = 240
        do {
            return try context.fetch(descriptor).compactMap(Self.petMomentQuickActionEntry(from:))
        } catch {
            OhanaLog.warning(
                "Home read model pet moment fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    func humanWeightLogs() -> [HumanWeightLog] {
        let today = calendar.startOfDay(for: now)
        var descriptor = FetchDescriptor<HumanWeightLog>(
            predicate: #Predicate<HumanWeightLog> { log in
                log.date >= today
            },
            sortBy: [SortDescriptor(\HumanWeightLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return fetchOrLog(descriptor, operation: "fetch home human weight logs")
    }

    private static func feedingLedgerEntry(from event: CareLedgerEvent) -> HomeFeedQuickActionEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return HomeFeedQuickActionEntry(
            id: event.id,
            petId: subjectId,
            date: event.occurredAt,
            amountGrams: event.amountValue,
            source: feedSource(
                note: event.note,
                ledgerSource: event.sourceEnum,
                sourceEventId: event.sourceEventId,
                sourceReminderId: event.sourceReminderId
            )
        )
    }

    private static func todayFocusCareLedgerEntry(from event: CareLedgerEvent) -> TodayFocusCareLedgerEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return TodayFocusCareLedgerEntry(
            id: event.id,
            subjectId: subjectId,
            eventKind: event.eventKindEnum,
            actionType: event.actionType,
            date: event.occurredAt,
            amountValue: event.amountValue,
            sourceEventId: event.sourceEventId.flatMap(UUID.init(uuidString:)),
            actorId: event.actorId
        )
    }

    private static func careQuickActionEntry(from event: CareLedgerEvent) -> HomeCareQuickActionEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return HomeCareQuickActionEntry(
            id: event.id,
            petId: subjectId,
            actionType: event.actionType,
            date: event.occurredAt,
            amountValue: event.amountValue
        )
    }

    private static func hygieneQuickActionEntry(from event: CareLedgerEvent) -> HomeHygieneQuickActionEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }),
              let hygieneType = HygieneType(rawValue: event.actionType) else { return nil }
        return HomeHygieneQuickActionEntry(
            id: event.id,
            petId: subjectId,
            hygieneType: hygieneType,
            date: event.occurredAt
        )
    }

    private static func walkQuickActionEntry(from event: CareLedgerEvent) -> HomeWalkQuickActionEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return HomeWalkQuickActionEntry(
            id: event.id,
            petId: subjectId,
            startDate: event.occurredAt,
            distanceMeters: event.amountValue
        )
    }

    private static func pottyQuickActionEntry(from event: CareLedgerEvent) -> HomePottyQuickActionEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }),
              let pottyType = PottyType(rawValue: event.actionType) else { return nil }
        return HomePottyQuickActionEntry(
            id: event.id,
            petId: subjectId,
            date: event.occurredAt,
            pottyType: pottyType
        )
    }

    private static func petExpenseQuickActionEntry(from event: CareLedgerEvent) -> HomePetExpenseQuickActionEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return HomePetExpenseQuickActionEntry(
            id: event.id,
            petId: subjectId,
            date: event.occurredAt,
            amount: event.amountValue
        )
    }

    private static func petWeightQuickActionEntry(from event: CareLedgerEvent) -> HomePetWeightQuickActionEntry? {
        guard let subjectId = event.subjectId.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return HomePetWeightQuickActionEntry(
            id: event.id,
            petId: subjectId,
            date: event.occurredAt,
            weightKg: event.amountValue
        )
    }

    private static func petMomentQuickActionEntry(from log: PetPhotoLog) -> HomePetMomentQuickActionEntry? {
        guard let petId = log.pet?.id else { return nil }
        return HomePetMomentQuickActionEntry(id: log.id, petId: petId, date: log.date)
    }

    private static func feedSource(
        note: String,
        ledgerSource: CareLedgerSource,
        sourceEventId: String?,
        sourceReminderId: String?
    ) -> FeedLogSource {
        if note.hasPrefix("ohana_plan_feed:") || ledgerSource == .reminder || sourceReminderId != nil {
            return .manualReminder
        }
        if note.hasPrefix("ohana_auto_feed:") || (ledgerSource == .service && sourceEventId != nil) {
            return .autoMain
        }
        if note.hasPrefix("ohana_treat_feed") {
            return .treat
        }
        return .manualMain
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
        return fetchOrLog(descriptor, operation: "fetch home family tasks")
    }

    func exchangeRequests() -> [CoconutExchangeRequest] {
        guard CoconutExchangeFeatureGate.isEnabled else { return [] }
        let pendingStatus = CoconutExchangeRequestStatus.pending.rawValue
        var descriptor = FetchDescriptor<CoconutExchangeRequest>(
            predicate: #Predicate<CoconutExchangeRequest> { request in
                request.statusRaw == pendingStatus
            },
            sortBy: [SortDescriptor(\CoconutExchangeRequest.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 40
        return fetchOrLog(descriptor, operation: "fetch home exchange requests")
    }

    private func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "Home read model \(operation) failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }
}
