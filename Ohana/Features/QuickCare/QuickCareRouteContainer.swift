//
//  QuickCareRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for quick-care detail sheets.
//

import SwiftData
import SwiftUI

struct QuickPlayDetailRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = QuickPlayRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.id = id
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if let pet = routeData.pet {
                QuickPlayDetailSheet(
                    pet: pet,
                    onRemove: onRemove,
                    onClose: onClose,
                    allEvents: routeData.allEvents,
                    playEntries: routeData.playEntries,
                    legacyPlayDeleteLogs: routeData.legacyPlayDeleteLogs
                )
            } else if routeData.hasLoaded {
                QuickCareMissingRouteEntityView(kind: "pet")
                    .onAppear(perform: onRemove)
            } else {
                QuickCareLoadingRouteEntityView(kind: "pet")
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
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = QuickPlayRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

struct QuickFeedDetailRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = QuickFeedRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let onRemove: () -> Void
    let onClose: (() -> Void)?
    let showsRemoveQuickActionFooter: Bool
    let showsCloseButton: Bool
    let opensManualSheetOnAppear: Bool

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        showsRemoveQuickActionFooter: Bool = true,
        showsCloseButton: Bool = true,
        opensManualSheetOnAppear: Bool = false
    ) {
        self.id = id
        self.onRemove = onRemove
        self.onClose = onClose
        self.showsRemoveQuickActionFooter = showsRemoveQuickActionFooter
        self.showsCloseButton = showsCloseButton
        self.opensManualSheetOnAppear = opensManualSheetOnAppear
    }

    var body: some View {
        Group {
            if let pet = routeData.pet {
                QuickFeedDetailSheet(
                    pet: pet,
                    onRemove: onRemove,
                    onClose: onClose,
                    showsRemoveQuickActionFooter: showsRemoveQuickActionFooter,
                    showsCloseButton: showsCloseButton,
                    opensManualSheetOnAppear: opensManualSheetOnAppear,
                    allEvents: routeData.allEvents,
                    allHumans: routeData.allHumans,
                    allPets: routeData.allPets,
                    feedingLedgerEntries: routeData.feedingLedgerEntries,
                    allCareLogs: routeData.allCareLogs,
                    allFoodRecords: routeData.allFoodRecords,
                    allSharedCareSessions: routeData.sharedCareSessions
                )
            } else if routeData.hasLoaded {
                QuickCareMissingRouteEntityView(kind: "pet")
                    .onAppear(perform: onRemove)
            } else {
                QuickCareLoadingRouteEntityView(kind: "pet")
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
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = QuickFeedRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

struct QuickWaterDetailRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = QuickWaterRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.id = id
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if let pet = routeData.pet {
                QuickWaterDetailSheet(
                    pet: pet,
                    onRemove: onRemove,
                    onClose: onClose,
                    allEvents: routeData.allEvents,
                    allPets: routeData.allPets,
                    waterEntries: routeData.waterEntries,
                    legacyWaterDeleteLogs: routeData.legacyWaterDeleteLogs
                )
            } else if routeData.hasLoaded {
                QuickCareMissingRouteEntityView(kind: "pet")
                    .onAppear(perform: onRemove)
            } else {
                QuickCareLoadingRouteEntityView(kind: "pet")
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
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = QuickWaterRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

struct QuickPottyDetailRouteContainer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var routeData = QuickPottyRouteData()
    @State private var dataLoadTask: Task<Void, Never>?

    let id: UUID
    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.id = id
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if let pet = routeData.pet {
                QuickPottyDetailSheet(
                    pet: pet,
                    onRemove: onRemove,
                    onClose: onClose,
                    allEvents: routeData.allEvents,
                    allPets: routeData.allPets,
                    pottyEntries: routeData.pottyEntries,
                    litterEntries: routeData.litterEntries,
                    legacyPottyDeleteLogs: routeData.legacyPottyDeleteLogs,
                    legacyLitterDeleteLogs: routeData.legacyLitterDeleteLogs
                )
            } else if routeData.hasLoaded {
                QuickCareMissingRouteEntityView(kind: "pet")
                    .onAppear(perform: onRemove)
            } else {
                QuickCareLoadingRouteEntityView(kind: "pet")
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
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            routeData = QuickPottyRouteData.load(id: id, from: modelContext)
            dataLoadTask = nil
        }
    }
}

private struct QuickPlayRouteData {
    var pet: Pet?
    var allEvents: [Event] = []
    var playEntries: [QuickPlayLedgerEntry] = []
    var legacyPlayDeleteLogs: [PetCareLog] = []
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> QuickPlayRouteData {
        let petKey = id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let playType = CareType.play.rawValue
        return QuickPlayRouteData(
            pet: fetchPet(id: id, context: context),
            allEvents: events(context: context),
            playEntries: QuickPlayLedgerEntry.entries(from: fetch(
                FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.subjectKind == petSubject &&
                            event.subjectId == petKey &&
                            event.eventKind == careKind &&
                            event.actionType == playType
                    },
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                ),
                context: context,
                name: "CareLedgerEvent"
            ), petID: id),
            legacyPlayDeleteLogs: fetch(
                FetchDescriptor<PetCareLog>(
                    predicate: #Predicate<PetCareLog> { log in
                        log.pet?.id == id &&
                            log.type == playType
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "PetCareLog"
            ),
            hasLoaded: true
        )
    }
}

private struct QuickFeedRouteData {
    var pet: Pet?
    var allEvents: [Event] = []
    var allHumans: [Human] = []
    var allPets: [Pet] = []
    var feedingLedgerEntries: [QuickFeedLedgerEntry] = []
    var allCareLogs: [PetCareLog] = []
    var allFoodRecords: [PetFoodRecord] = []
    var sharedCareSessions: [SharedCareSession] = []
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> QuickFeedRouteData {
        let petKey = id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingType = CareType.feeding.rawValue
        let sharedFeedingKind = SharedCareActionKind.feeding.rawValue
        let homeLogStartDate = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(-6 * 86400)
        let pet = fetchPet(id: id, context: context)
        let allEvents = events(context: context)
        let allCareLogs = fetch(
            FetchDescriptor<PetCareLog>(
                predicate: #Predicate<PetCareLog> { log in
                    log.type == feedingType &&
                        log.pet?.id == id &&
                        log.date >= homeLogStartDate
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            ),
            context: context,
            name: "PetCareLog"
        )
        let feedingLedgerEvents = fetch(
            FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == petSubject &&
                        event.subjectId == petKey &&
                        event.eventKind == careKind &&
                        event.actionType == feedingType &&
                        event.occurredAt >= homeLogStartDate
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
            ),
            context: context,
            name: "CareLedgerEvent"
        )
        let feedRuleState = pet.map { FeedRuleState(pet: $0, allEvents: allEvents, now: Date()) }

        return QuickFeedRouteData(
            pet: pet,
            allEvents: allEvents,
            allHumans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            ),
            allPets: pets(context: context),
            feedingLedgerEntries: pet.map {
                QuickFeedLedgerEntry.entries(
                    pet: $0,
                    feedingLedgerEvents: feedingLedgerEvents,
                    legacyCareLogs: allCareLogs,
                    manualPlanEvents: feedRuleState?.manualReminderEvents ?? [],
                    autoFeederEvents: feedRuleState?.autoFeederEvents ?? []
                )
            } ?? [],
            allCareLogs: allCareLogs,
            allFoodRecords: fetch(
                FetchDescriptor<PetFoodRecord>(
                    predicate: #Predicate<PetFoodRecord> { record in
                        record.pet?.id == id
                    },
                    sortBy: [SortDescriptor(\.startDate, order: .reverse)]
                ),
                context: context,
                name: "PetFoodRecord"
            ),
            sharedCareSessions: fetch(
                FetchDescriptor<SharedCareSession>(
                    predicate: #Predicate<SharedCareSession> { session in
                        session.actionKindRaw == sharedFeedingKind &&
                            session.stockOwnerPetId == petKey
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "SharedCareSession"
            ),
            hasLoaded: true
        )
    }
}

private struct QuickWaterRouteData {
    var pet: Pet?
    var allEvents: [Event] = []
    var allPets: [Pet] = []
    var waterEntries: [QuickWaterLedgerEntry] = []
    var legacyWaterDeleteLogs: [PetCareLog] = []
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> QuickWaterRouteData {
        let petKey = id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let wateringType = CareType.watering.rawValue
        let waterChangeType = CareType.waterChange.rawValue
        let filterCleanType = CareType.filterClean.rawValue

        return QuickWaterRouteData(
            pet: fetchPet(id: id, context: context),
            allEvents: events(context: context),
            allPets: pets(context: context),
            waterEntries: QuickWaterLedgerEntry.entries(from: fetch(
                FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.subjectKind == petSubject &&
                            event.subjectId == petKey &&
                            event.eventKind == careKind &&
                            (event.actionType == wateringType ||
                                event.actionType == waterChangeType ||
                                event.actionType == filterCleanType)
                    },
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                ),
                context: context,
                name: "CareLedgerEvent"
            ), petID: id),
            legacyWaterDeleteLogs: fetch(
                FetchDescriptor<PetCareLog>(
                    predicate: #Predicate<PetCareLog> { log in
                        (log.type == wateringType ||
                            log.type == waterChangeType ||
                            log.type == filterCleanType) &&
                            log.pet?.id == id
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "PetCareLog"
            ),
            hasLoaded: true
        )
    }
}

private struct QuickPottyRouteData {
    var pet: Pet?
    var allEvents: [Event] = []
    var allPets: [Pet] = []
    var pottyEntries: [PoopPottyLedgerEntry] = []
    var litterEntries: [PoopLitterLedgerEntry] = []
    var legacyPottyDeleteLogs: [PetPottyLog] = []
    var legacyLitterDeleteLogs: [PetCareLog] = []
    var hasLoaded = false

    static func load(id: UUID, from context: ModelContext) -> QuickPottyRouteData {
        let petKey = id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let pottyKind = CareLedgerEventKind.potty.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let litterType = CareType.litter.rawValue
        return QuickPottyRouteData(
            pet: fetchPet(id: id, context: context),
            allEvents: events(context: context),
            allPets: pets(context: context),
            pottyEntries: PoopPottyLedgerEntry.entries(from: fetch(
                FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.subjectKind == petSubject &&
                            event.subjectId == petKey &&
                            event.eventKind == pottyKind
                    },
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                ),
                context: context,
                name: "CareLedgerEvent"
            ), petID: id),
            litterEntries: PoopLitterLedgerEntry.entries(from: fetch(
                FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.subjectKind == petSubject &&
                            event.subjectId == petKey &&
                            event.eventKind == careKind &&
                            event.actionType == litterType
                    },
                    sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
                ),
                context: context,
                name: "CareLedgerEvent"
            ), petID: id),
            legacyPottyDeleteLogs: fetch(
                FetchDescriptor<PetPottyLog>(
                    predicate: #Predicate<PetPottyLog> { log in
                        log.pet?.id == id
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "PetPottyLog"
            ),
            legacyLitterDeleteLogs: fetch(
                FetchDescriptor<PetCareLog>(
                    predicate: #Predicate<PetCareLog> { log in
                        log.pet?.id == id &&
                            log.type == litterType
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                ),
                context: context,
                name: "PetCareLog"
            ),
            hasLoaded: true
        )
    }
}

private func fetchPet(id: UUID, context: ModelContext) -> Pet? {
    fetch(
        FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.id == id }
        ),
        context: context,
        name: "Pet"
    ).first
}

private func pets(context: ModelContext) -> [Pet] {
    fetch(
        FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
        context: context,
        name: "Pet"
    )
}

private func events(context: ModelContext) -> [Event] {
    fetch(
        FetchDescriptor<Event>(sortBy: [SortDescriptor(\.startDate)]),
        context: context,
        name: "Event"
    )
}

private func fetch<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    name: String
) -> [T] {
    do {
        return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
    } catch {
        OhanaLog.warning(
            "Quick care route data fetch failed for \(name): \(error.localizedDescription)",
            category: "QuickCare"
        )
        return []
    }
}

private struct QuickCareMissingRouteEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(OhanaFont.adaptive(size: 28, weight: .bold))
                .foregroundStyle(Color.goOrange)
            Text(L10n.current.tr(zh: "找不到对应资料", en: "Missing \(kind)", de: "\(kind) nicht gefunden"))
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground())
    }
}

private struct QuickCareLoadingRouteEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(kind)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground())
    }
}
