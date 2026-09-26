//
//  StarterJourneyExperienceReadModelActor.swift
//  Ohana
//
//  Bounded Human-only read model used by the lightweight Zen shell.
//

import Foundation
import SwiftData

@ModelActor
actor StarterJourneyExperienceReadModelActor {
    func loadHumanJourney(
        activeHumanID: String?
    ) throws -> HouseholdStarterJourneySnapshot {
        try Task.checkCancellation()

        let humans = try modelContext.fetch(FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\.createdAt)]
        ))
        let checkpointAction = HouseholdStarterJourneyService.checkpointActionType
        let checkpointModel = HouseholdStarterJourneyService.checkpointSourceModelName
        let rewardAction = HouseholdStarterJourneyService.rewardActionType
        let rewardModel = HouseholdStarterJourneyService.rewardSourceModelName
        let careLedgerEvents = try modelContext.fetch(FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate { event in
                (event.actionType == checkpointAction && event.legacyModelName == checkpointModel)
                    || (event.actionType == rewardAction && event.legacyModelName == rewardModel)
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        ))
        let rewardTransactionKey = HouseholdStarterJourneyService.rewardTransactionKey(
            for: .humanProfile
        )
        var rewardDescriptor = FetchDescriptor<CoconutLedgerEntry>(
            predicate: #Predicate { entry in
                entry.transactionKey == rewardTransactionKey
            },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        rewardDescriptor.fetchLimit = 1
        let rewardEntries = try modelContext.fetch(rewardDescriptor)

        try Task.checkCancellation()
        return HouseholdStarterJourneyService.buildSnapshot(
            enabled: true,
            activeHumanID: activeHumanID,
            humans: humans,
            pets: [],
            qualificationFacts: .empty,
            careLedgerEvents: careLedgerEvents,
            coconutLedgerEntries: rewardEntries
        )
    }
}
