//
//  WalkActionHumanSelectionPolicy.swift
//  Ohana
//
//  Keeps walk attribution lightweight while preventing an eligible household
//  member from being silently dropped when a walk starts.
//

import Foundation

nonisolated enum WalkActionHumanSelectionPolicy {
    static func reconciledSelection(
        selectedIDs: Set<String>,
        eligibleIDs: [String],
        currentHumanID: String?
    ) -> Set<String> {
        let eligible = Set(eligibleIDs)
        let validSelection = selectedIDs.intersection(eligible)

        if validSelection.count == 1 {
            return validSelection
        }
        if let currentHumanID, eligible.contains(currentHumanID) {
            return [currentHumanID]
        }
        if eligible.count == 1 {
            return eligible
        }
        return []
    }

    static func canStart(eligibleIDs: [String], selectedIDs: [String]) -> Bool {
        eligibleIDs.isEmpty || !Set(selectedIDs).isDisjoint(with: eligibleIDs)
    }
}
