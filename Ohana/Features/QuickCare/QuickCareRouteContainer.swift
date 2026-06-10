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

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey
            },
            sort: \.startDate
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
                allEvents: allEvents
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
    @Query private var allCareLogs: [PetCareLog]
    @Query private var allFoodRecords: [PetFoodRecord]

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
        let feedingType = CareType.feeding.rawValue
        let homeLogStartDate = Calendar.current.date(
            byAdding: .day,
            value: -6,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(-6 * 86400)

        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey ||
                    event.relatedEntityId == dryStockKey ||
                    event.relatedEntityId == wetStockKey
            },
            sort: \.startDate
        )
        _allCareLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                log.type == feedingType &&
                    log.pet?.id == id &&
                    log.date >= homeLogStartDate
            },
            sort: \.date,
            order: .reverse
        )
        _allFoodRecords = Query(
            filter: #Predicate<PetFoodRecord> { record in
                record.pet?.id == id
            },
            sort: \.startDate,
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
                allCareLogs: allCareLogs,
                allFoodRecords: allFoodRecords
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
    @Query private var waterCareLogs: [PetCareLog]

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        let wateringType = CareType.watering.rawValue
        let waterChangeType = CareType.waterChange.rawValue
        let filterCleanType = CareType.filterClean.rawValue

        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey
            },
            sort: \.startDate
        )
        _waterCareLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                (log.type == wateringType ||
                    log.type == waterChangeType ||
                    log.type == filterCleanType) &&
                    log.pet?.id == id
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
                waterCareLogs: waterCareLogs
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

    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        let petKey = id.uuidString
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petKey
            },
            sort: \.startDate
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
                allPets: allPets
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
