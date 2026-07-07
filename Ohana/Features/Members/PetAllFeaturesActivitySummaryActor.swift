//
//  PetAllFeaturesActivitySummaryActor.swift
//  Ohana
//
//  Builds single-pet feature hub summaries off the main actor.
//

import Foundation
import SwiftData

@ModelActor
actor PetAllFeaturesActivitySummaryActor {
    func load(petID: UUID, now: Date = Date()) throws -> PetAllFeaturesActivitySummary {
        try Task.checkCancellation()
        let summary = PetAllFeaturesActivitySummary.load(
            petID: petID,
            context: modelContext,
            now: now
        )
        try Task.checkCancellation()
        return summary
    }
}
