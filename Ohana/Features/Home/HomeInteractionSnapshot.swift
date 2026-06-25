//
//  HomeInteractionSnapshot.swift
//  Ohana
//
//  Pure interaction data for the high-frequency Home render path.
//

import Foundation

nonisolated struct HomePetInteractionSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let species: String
    let hasPassedAway: Bool

    var isActive: Bool { !hasPassedAway }
}

nonisolated struct HomeHumanInteractionSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let avatarEmoji: String
    let hasPassedAway: Bool

    var isActive: Bool { !hasPassedAway }
}

nonisolated struct HomeQuickActionMenuPolicySnapshot: Equatable, Sendable {
    let showsMenu: Bool
    let showsQuickButton: Bool

    static let none = HomeQuickActionMenuPolicySnapshot(showsMenu: false, showsQuickButton: false)

    init(_ policy: ExpandedQuickMenuPolicy) {
        showsMenu = policy.showsMenu
        showsQuickButton = policy.showsQuickButton
    }

    init(showsMenu: Bool, showsQuickButton: Bool) {
        self.showsMenu = showsMenu
        self.showsQuickButton = showsQuickButton
    }

    var expandedPolicy: ExpandedQuickMenuPolicy {
        ExpandedQuickMenuPolicy(showsMenu: showsMenu, showsQuickButton: showsQuickButton)
    }
}

nonisolated struct HomeQuickActionRenderSnapshot: Equatable, Sendable {
    let status: String?
    let isCompleted: Bool
    let showsAttention: Bool
    let isLocked: Bool
    let menuPolicy: HomeQuickActionMenuPolicySnapshot
}

nonisolated struct HomeExpandedActionSnapshot: @unchecked Sendable {
    var currentItems: [QuickActionItem]
    var visibleItems: [QuickActionItem]
    var candidateItems: [QuickActionItem]
    var statesByActionType: [String: HomeQuickActionRenderSnapshot]
    var fabShortcuts: [ExpandedCardFabShortcut]

    static let empty = HomeExpandedActionSnapshot(
        currentItems: [],
        visibleItems: [],
        candidateItems: [],
        statesByActionType: [:],
        fabShortcuts: []
    )

    func state(for item: QuickActionItem) -> HomeQuickActionRenderSnapshot {
        statesByActionType[item.actionType] ?? HomeQuickActionRenderSnapshot(
            status: nil,
            isCompleted: false,
            showsAttention: false,
            isLocked: false,
            menuPolicy: .none
        )
    }
}

nonisolated enum HomeReminderRouteSnapshot: @unchecked Sendable {
    case petQuick(String, UUID)
    case petFeature(PetFeature, UUID)
    case petHealth(UUID, PetHealthInitialSection)
    case humanQuick(String, UUID)
    case humanDetail(UUID)
    case plant(UUID)
    case functionMenu(FMDest)
    case calendar(entityId: String?, humanId: String?)
}

nonisolated struct HomeInteractionSnapshot: @unchecked Sendable {
    let activeHuman: HomeHumanInteractionSnapshot?
    let islandCoconutBalance: Int
    let petsByID: [UUID: HomePetInteractionSnapshot]
    let humansByID: [UUID: HomeHumanInteractionSnapshot]
    let plantIDs: Set<UUID>
    let firstActivePetID: UUID?
    let petMedicationTargetsByMedicationID: [UUID: UUID]
    let eventRoutesByEventID: [UUID: HomeReminderRouteSnapshot]
    let expandedActionsByCardID: [UUID: HomeExpandedActionSnapshot]

    static let empty = HomeInteractionSnapshot(
        activeHuman: nil,
        islandCoconutBalance: 0,
        petsByID: [:],
        humansByID: [:],
        plantIDs: [],
        firstActivePetID: nil,
        petMedicationTargetsByMedicationID: [:],
        eventRoutesByEventID: [:],
        expandedActionsByCardID: [:]
    )

    func pet(id: UUID) -> HomePetInteractionSnapshot? {
        petsByID[id]
    }

    func activePet(id: UUID) -> HomePetInteractionSnapshot? {
        guard let pet = petsByID[id], pet.isActive else { return nil }
        return pet
    }

    func containsHuman(_ id: UUID) -> Bool {
        humansByID[id] != nil
    }

    func activeHumanSnapshot(id: UUID) -> HomeHumanInteractionSnapshot? {
        guard let human = humansByID[id], human.isActive else { return nil }
        return human
    }

    func expandedActions(for cardID: UUID) -> HomeExpandedActionSnapshot {
        expandedActionsByCardID[cardID] ?? .empty
    }
}

nonisolated enum HomeInteractionSnapshotBuilder {
    static func build(
        from source: VerticalSolidHomeSourceState,
        quickActionItemsRaw: String,
        now: Date
    ) -> HomeInteractionSnapshot {
        let activeHuman = source.activeHuman.map(HomeHumanInteractionSnapshot.init)
        let activeHumanID = source.activeHumanId
        let l = L10n(source.language)
        let petsByID = Dictionary(uniqueKeysWithValues: source.pets.map { ($0.id, HomePetInteractionSnapshot(pet: $0)) })
        let humansByID = Dictionary(uniqueKeysWithValues: source.humans.map { ($0.id, HomeHumanInteractionSnapshot(human: $0)) })
        let firstActivePetID = source.pets.first(where: { !$0.hasPassedAway })?.id
        let petMedicationTargets = Dictionary(
            uniqueKeysWithValues: source.pets.flatMap { pet in
                pet.medications.map { medication in
                    (medication.id, pet.id)
                }
            }
        )
        let eventRoutes = Dictionary(
            uniqueKeysWithValues: source.events.map { event in
                (
                    event.id,
                    HomeReminderRouteSnapshot(
                        destination: FocusHomeReminderDeepLinkRouter.destination(
                            for: event,
                            pets: source.pets,
                            humans: source.humans,
                            plants: source.plants,
                            humanMedications: source.humanMedications
                        )
                    )
                )
            }
        )
        var expandedActions: [UUID: HomeExpandedActionSnapshot] = [:]
        for pet in source.pets {
            expandedActions[pet.id] = petActionSnapshot(
                pet: pet,
                source: source,
                quickActionItemsRaw: quickActionItemsRaw,
                localization: l,
                now: now
            )
        }
        for human in source.humans {
            expandedActions[human.id] = humanActionSnapshot(
                human: human,
                activeHumanID: activeHumanID,
                source: source,
                quickActionItemsRaw: quickActionItemsRaw,
                localization: l
            )
        }
        return HomeInteractionSnapshot(
            activeHuman: activeHuman,
            islandCoconutBalance: source.humans.reduce(0) { $0 + $1.coconutBalance }
                + source.pets.reduce(0) { $0 + $1.coconutBalance },
            petsByID: petsByID,
            humansByID: humansByID,
            plantIDs: Set(source.plants.map(\.id)),
            firstActivePetID: firstActivePetID,
            petMedicationTargetsByMedicationID: petMedicationTargets,
            eventRoutesByEventID: eventRoutes,
            expandedActionsByCardID: expandedActions
        )
    }

    private static func petActionSnapshot(
        pet: Pet,
        source: VerticalSolidHomeSourceState,
        quickActionItemsRaw: String,
        localization l: L10n,
        now: Date
    ) -> HomeExpandedActionSnapshot {
        let currentItems = stableItems(
            ExpandedQuickActionStore.petItems(
                raw: quickActionItemsRaw,
                pet: pet,
                localization: l,
                waterLabel: l.homeQAWater,
                managementLabel: l.tr(zh: "管理", en: "Manage", de: "Verwalten")
            ),
            entityID: pet.id,
            kind: .pet
        )
        let visibleItems = Array(currentItems.prefix(QuickActionLimit.maxItemsPerEntity))
        let candidateItems = stableItems(
            QuickActionPickerCatalog.options(for: pet).map { option in
                QuickActionItem(
                    id: "\(EntityKind.pet.rawValue)-\(pet.id.uuidString)-\(option.id)",
                    label: option.label,
                    icon: option.icon,
                    colorHex: option.colorHex,
                    petId: pet.id,
                    actionType: option.id,
                    entityId: pet.id,
                    entityKind: .pet
                )
            },
            entityID: pet.id,
            kind: .pet
        )
        let states = stateDictionary(for: visibleItems + candidateItems) { item in
            HomeQuickActionRenderStateLogic.petRenderState(
                item: item,
                pet: pet,
                source: source,
                localization: l,
                now: now
            )
        }
        return HomeExpandedActionSnapshot(
            currentItems: currentItems,
            visibleItems: visibleItems,
            candidateItems: candidateItems,
            statesByActionType: states,
            fabShortcuts: FocusHomeFabShortcutPolicy.petShortcuts(
                for: pet,
                displayedItems: visibleItems,
                localization: l
            )
        )
    }

    private static func humanActionSnapshot(
        human: Human,
        activeHumanID: UUID?,
        source: VerticalSolidHomeSourceState,
        quickActionItemsRaw: String,
        localization l: L10n
    ) -> HomeExpandedActionSnapshot {
        let currentItems = stableItems(
            ExpandedQuickActionStore.humanItems(
                raw: quickActionItemsRaw,
                human: human,
                localization: l
            ),
            entityID: human.id,
            kind: .human
        )
        let visibleItems = Array(currentItems.prefix(QuickActionLimit.maxItemsPerEntity))
        let candidateItems = stableItems(
            ExpandedQuickActionDefaults.humanItems(for: human, localization: l),
            entityID: human.id,
            kind: .human
        )
        let states = stateDictionary(for: visibleItems + candidateItems) { item in
            HomeQuickActionRenderStateLogic.humanRenderState(
                item: item,
                human: human,
                activeHumanID: activeHumanID,
                source: source,
                localization: l
            )
        }
        return HomeExpandedActionSnapshot(
            currentItems: currentItems,
            visibleItems: visibleItems,
            candidateItems: candidateItems,
            statesByActionType: states,
            fabShortcuts: FocusHomeFabShortcutPolicy.humanShortcuts(
                for: human,
                displayedItems: visibleItems,
                localization: l
            )
        )
    }

    private static func stableItems(_ items: [QuickActionItem], entityID: UUID, kind: EntityKind) -> [QuickActionItem] {
        items.map { item in
            var stableItem = item
            stableItem.id = "\(kind.rawValue)-\(entityID.uuidString)-\(item.actionType)"
            return stableItem
        }
    }

    private static func stateDictionary(
        for items: [QuickActionItem],
        makeState: (QuickActionItem) -> HomeQuickActionRenderSnapshot
    ) -> [String: HomeQuickActionRenderSnapshot] {
        items.reduce(into: [:]) { result, item in
            result[item.actionType] = makeState(item)
        }
    }
}

private extension HomePetInteractionSnapshot {
    nonisolated init(pet: Pet) {
        self.init(
            id: pet.id,
            species: pet.species,
            hasPassedAway: pet.hasPassedAway
        )
    }
}

private extension HomeHumanInteractionSnapshot {
    nonisolated init(human: Human) {
        self.init(
            id: human.id,
            name: human.name,
            avatarEmoji: human.avatarEmoji,
            hasPassedAway: human.hasPassedAway
        )
    }
}

private extension HomeReminderRouteSnapshot {
    nonisolated init(destination: FocusHomeReminderDestination) {
        switch destination {
        case let .petQuick(key, pet):
            self = .petQuick(key, pet.id)
        case let .petFeature(feature, pet):
            self = .petFeature(feature, pet.id)
        case let .petHealth(pet, section):
            self = .petHealth(pet.id, section)
        case let .humanQuick(key, human):
            self = .humanQuick(key, human.id)
        case let .humanDetail(human):
            self = .humanDetail(human.id)
        case let .plant(plant):
            self = .plant(plant.id)
        case let .functionMenu(destination):
            self = .functionMenu(destination)
        case let .calendar(entityId, humanId):
            self = .calendar(entityId: entityId, humanId: humanId)
        }
    }
}
