//
//  QuickCareRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for quick-care detail sheets.
//

import SwiftData
import SwiftUI

struct QuickPlayDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query private var playLedgerEvents: [CareLedgerEvent]
    @Query private var legacyPlayDeleteLogs: [PetCareLog]

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let playType = CareType.play.rawValue
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id && pet.trashedAt == nil
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey &&
                    event.trashedAt == nil
            },
            sort: \.startDate
        )
        _playLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petKey &&
                    event.eventKind == careKind &&
                    event.actionType == playType
            },
            sort: \.occurredAt,
            order: .reverse
        )
        _legacyPlayDeleteLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                log.pet?.id == id &&
                    log.type == playType &&
                    log.trashedAt == nil &&
                    log.pet?.trashedAt == nil
            },
            sort: \.date,
            order: .reverse
        )
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        if let pet = pets.first {
            QuickPlayDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                allEvents: allEvents,
                playLedgerEvents: playLedgerEvents,
                legacyPlayDeleteLogs: legacyPlayDeleteLogs
            )
        } else {
            QuickCareMissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
    }
}

struct QuickFeedDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query private var feedingLedgerEvents: [CareLedgerEvent]
    @Query private var allCareLogs: [PetCareLog]
    @Query private var allFoodRecords: [PetFoodRecord]
    @Query private var sharedCareSessions: [SharedCareSession]

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
        let petKey = id.uuidString
        let dryStockKey = "\(petKey):\(FeedFoodKind.dry.rawValue)"
        let wetStockKey = "\(petKey):\(FeedFoodKind.wet.rawValue)"
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingType = CareType.feeding.rawValue
        let sharedFeedingKind = SharedCareActionKind.feeding.rawValue
        let homeLogStartDate = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(-6 * 86400)

        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id && pet.trashedAt == nil
        })
        _allHumans = Query(
            filter: #Predicate<Human> { human in
                human.trashedAt == nil
            },
            sort: \.createdAt
        )
        _allPets = Query(
            filter: #Predicate<Pet> { pet in
                pet.trashedAt == nil
            },
            sort: \.createdAt
        )
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                (event.relatedEntityId == petKey ||
                    event.relatedEntityId == dryStockKey ||
                    event.relatedEntityId == wetStockKey) &&
                    event.trashedAt == nil
            },
            sort: \.startDate
        )
        _feedingLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petKey &&
                    event.eventKind == careKind &&
                    event.actionType == feedingType &&
                    event.occurredAt >= homeLogStartDate
            },
            sort: \.occurredAt,
            order: .reverse
        )
        _allCareLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                log.type == feedingType &&
                    log.pet?.id == id &&
                    log.date >= homeLogStartDate &&
                    log.trashedAt == nil &&
                    log.pet?.trashedAt == nil
            },
            sort: \.date,
            order: .reverse
        )
        _allFoodRecords = Query(
            filter: #Predicate<PetFoodRecord> { record in
                record.pet?.id == id &&
                    record.trashedAt == nil &&
                    record.pet?.trashedAt == nil
            },
            sort: \.startDate,
            order: .reverse
        )
        _sharedCareSessions = Query(
            filter: #Predicate<SharedCareSession> { session in
                session.actionKindRaw == sharedFeedingKind &&
                    session.stockOwnerPetId == petKey
            },
            sort: \.date,
            order: .reverse
        )
        self.onRemove = onRemove
        self.onClose = onClose
        self.showsRemoveQuickActionFooter = showsRemoveQuickActionFooter
        self.showsCloseButton = showsCloseButton
        self.opensManualSheetOnAppear = opensManualSheetOnAppear
    }

    var body: some View {
        if let pet = pets.first {
            QuickFeedDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                showsRemoveQuickActionFooter: showsRemoveQuickActionFooter,
                showsCloseButton: showsCloseButton,
                opensManualSheetOnAppear: opensManualSheetOnAppear,
                allEvents: allEvents,
                allHumans: allHumans,
                allPets: allPets,
                feedingLedgerEvents: feedingLedgerEvents,
                allCareLogs: allCareLogs,
                allFoodRecords: allFoodRecords,
                allSharedCareSessions: sharedCareSessions
            )
        } else {
            QuickCareMissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
    }
}

struct QuickWaterDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query private var waterLedgerEvents: [CareLedgerEvent]
    @Query private var legacyWaterDeleteLogs: [PetCareLog]

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let wateringType = CareType.watering.rawValue
        let waterChangeType = CareType.waterChange.rawValue
        let filterCleanType = CareType.filterClean.rawValue

        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id && pet.trashedAt == nil
        })
        _allPets = Query(
            filter: #Predicate<Pet> { pet in
                pet.trashedAt == nil
            },
            sort: \.createdAt
        )
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey &&
                    event.trashedAt == nil
            },
            sort: \.startDate
        )
        _waterLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petKey &&
                    event.eventKind == careKind
            },
            sort: \.occurredAt,
            order: .reverse
        )
        _legacyWaterDeleteLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                (log.type == wateringType ||
                    log.type == waterChangeType ||
                    log.type == filterCleanType) &&
                    log.pet?.id == id &&
                    log.trashedAt == nil &&
                    log.pet?.trashedAt == nil
            },
            sort: \.date,
            order: .reverse
        )
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        if let pet = pets.first {
            QuickWaterDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                allEvents: allEvents,
                allPets: allPets,
                waterLedgerEvents: waterLedgerEvents,
                legacyWaterDeleteLogs: legacyWaterDeleteLogs
            )
        } else {
            QuickCareMissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
    }
}

struct QuickPottyDetailRouteContainer: View {
    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query private var pottyLedgerEvents: [CareLedgerEvent]
    @Query private var legacyPottyDeleteLogs: [PetPottyLog]
    @Query private var legacyLitterDeleteLogs: [PetCareLog]

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let pottyKind = CareLedgerEventKind.potty.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let litterType = CareType.litter.rawValue
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id && pet.trashedAt == nil
        })
        _allPets = Query(
            filter: #Predicate<Pet> { pet in
                pet.trashedAt == nil
            },
            sort: \.createdAt
        )
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey &&
                    event.trashedAt == nil
            },
            sort: \.startDate
        )
        _pottyLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petKey &&
                    (event.eventKind == pottyKind ||
                        (event.eventKind == careKind && event.actionType == litterType))
            },
            sort: \.occurredAt,
            order: .reverse
        )
        _legacyPottyDeleteLogs = Query(
            filter: #Predicate<PetPottyLog> { log in
                log.pet?.id == id &&
                    log.trashedAt == nil &&
                    log.pet?.trashedAt == nil
            },
            sort: \.date,
            order: .reverse
        )
        _legacyLitterDeleteLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                log.pet?.id == id &&
                    log.type == litterType &&
                    log.trashedAt == nil &&
                    log.pet?.trashedAt == nil
            },
            sort: \.date,
            order: .reverse
        )
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        if let pet = pets.first {
            QuickPottyDetailSheet(
                pet: pet,
                onRemove: onRemove,
                onClose: onClose,
                allEvents: allEvents,
                allPets: allPets,
                pottyLedgerEvents: pottyLedgerEvents,
                legacyPottyDeleteLogs: legacyPottyDeleteLogs,
                legacyLitterDeleteLogs: legacyLitterDeleteLogs
            )
        } else {
            QuickCareMissingRouteEntityView(kind: "pet")
                .onAppear(perform: onRemove)
        }
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
