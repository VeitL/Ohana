//
//  HumanWorkoutPetWalkSnapshotBuilder.swift
//  Ohana
//
//  Builds lightweight read-only dog-walk snapshots for the human workout screen.
//

import Foundation
import SwiftData

struct HumanWorkoutPetWalkSnapshot: Equatable, Identifiable {
    let id: String
    let startDate: Date
    let durationMinutes: Int
    let distanceKm: Double
    let petName: String?

    var sourcePetWalkLogID: String { id }

    init(walk: PetWalkLog) {
        id = walk.id.uuidString
        startDate = walk.startDate
        durationMinutes = max(1, Int((walk.durationSeconds / 60).rounded()))
        distanceKm = max(0, walk.distanceMeters / 1000)
        petName = walk.pet?.name
    }
}

enum HumanWorkoutPetWalkSnapshotBuilder {
    @MainActor
    static func snapshots(
        for human: Human,
        context: ModelContext
    ) -> [HumanWorkoutPetWalkSnapshot] {
        let humanID = human.id.uuidString
        let descriptor = FetchDescriptor<PetWalkLog>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor).compactMap { walk in
                guard !walk.isRecoveryCheckpoint,
                      walk.endDate != nil,
                      walk.executorIds.contains(humanID) else {
                    return nil
                }
                return HumanWorkoutPetWalkSnapshot(walk: walk)
            }
        } catch {
            OhanaLog.warning(
                "HumanWorkoutPetWalkSnapshotBuilder failed to fetch pet walks: \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }
}
