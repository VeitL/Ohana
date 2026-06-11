//
//  IslandFoodDashboardDataContainer.swift
//  Ohana
//
//  Screen-level food dashboard query container.
//

import SwiftData
import SwiftUI

struct IslandFoodDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Query private var pets: [Pet]
    @Query private var allEvents: [Event]
    @Query private var allCareLogs: [PetCareLog]
    @Query private var allFoodRecords: [PetFoodRecord]
    @Query private var allSharedCareSessions: [SharedCareSession]

    init(
        standalone: Bool = true,
        onOpenPet: ((Pet) -> Void)? = nil
    ) {
        self.standalone = standalone
        self.onOpenPet = onOpenPet

        let feedingEventType = EventType.foodChange.rawValue
        let stockReminderEntityType = FeedingPlanWriter.stockReminderEntityType
        let autoFeederEntityType = FeedRuleMetadata.autoFeederEntityType
        let feedingCareType = CareType.feeding.rawValue
        let sharedFeedingKind = SharedCareActionKind.feeding.rawValue
        let careLogWindowStart = Calendar.current.date(byAdding: .day, value: -730, to: Date()) ?? .distantPast

        _pets = Query(
            filter: #Predicate<Pet> { pet in
                pet.passedAwayDate == nil
            },
            sort: \.name
        )
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.eventType == feedingEventType ||
                    event.relatedEntityType == stockReminderEntityType ||
                    event.relatedEntityType == autoFeederEntityType
            },
            sort: \.startDate
        )
        _allCareLogs = Query(
            filter: #Predicate<PetCareLog> { log in
                log.type == feedingCareType && log.date >= careLogWindowStart
            },
            sort: \.date,
            order: .reverse
        )
        _allFoodRecords = Query(
            filter: #Predicate<PetFoodRecord> { record in
                record.pet?.passedAwayDate == nil
            },
            sort: \.startDate,
            order: .reverse
        )
        _allSharedCareSessions = Query(
            filter: #Predicate<SharedCareSession> { session in
                session.actionKindRaw == sharedFeedingKind &&
                    session.date >= careLogWindowStart
            },
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        IslandFoodDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets,
            allEvents: allEvents,
            allCareLogs: allCareLogs,
            allFoodRecords: allFoodRecords,
            allSharedCareSessions: allSharedCareSessions
        )
    }
}
