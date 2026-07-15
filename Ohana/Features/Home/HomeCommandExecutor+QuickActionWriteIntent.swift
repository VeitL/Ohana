//
//  HomeCommandExecutor+QuickActionWriteIntent.swift
//  Ohana
//

import Foundation

extension HomeCommandExecutor {
    func quickActionWillImmediatelyWriteFact(
        action: HomePetQuickActionKind,
        petID: UUID,
        now: Date
    ) -> Bool {
        guard let pet = fetchPet(id: petID),
              MemberLifecycleGate.disposition(pet: pet, writeKind: .care).allowsCareFactWrite else {
            return false
        }
        let events = action.needsEvents ? fetchQuickCareEvents(pet: pet, now: now) : []
        return ExpandedQuickActionExecutor.willImmediatelyWriteFact(
            action: action,
            pet: pet,
            allEvents: events,
            now: now
        )
    }
}
