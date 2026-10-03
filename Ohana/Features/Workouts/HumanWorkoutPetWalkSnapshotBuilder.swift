//
//  HumanWorkoutPetWalkSnapshotBuilder.swift
//  Ohana
//
//  Builds lightweight read-only dog-walk snapshots for the human workout screen.
//

import Foundation
import SwiftData

nonisolated struct HumanWorkoutPetWalkCandidate: Equatable, Sendable {
    let sourceID: String
    let sharedSessionID: String
    let startDate: Date
    let durationMinutes: Int
    let distanceKm: Double
    let petName: String?
}

nonisolated struct HumanWorkoutPetWalkSnapshot: Equatable, Identifiable, Sendable {
    let id: String
    let startDate: Date
    let durationMinutes: Int
    let distanceKm: Double
    let petNames: [String]
    let sourcePetWalkLogIDs: Set<String>

    var petName: String? {
        petNames.isEmpty ? nil : petNames.joined(separator: ", ")
    }

    var sourcePetWalkLogID: String {
        sourcePetWalkLogIDs.sorted().first ?? ""
    }

    func containsSourcePetWalkLogID(_ id: String) -> Bool {
        sourcePetWalkLogIDs.contains(id)
    }

    fileprivate init(candidate: HumanWorkoutPetWalkCandidate, groupingKey: String) {
        id = groupingKey
        startDate = candidate.startDate
        durationMinutes = max(1, candidate.durationMinutes)
        distanceKm = max(0, candidate.distanceKm)
        petNames = candidate.petName.map { [$0] } ?? []
        sourcePetWalkLogIDs = [candidate.sourceID]
    }

    fileprivate init(
        id: String,
        startDate: Date,
        durationMinutes: Int,
        distanceKm: Double,
        petNames: [String],
        sourcePetWalkLogIDs: Set<String>
    ) {
        self.id = id
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.petNames = petNames
        self.sourcePetWalkLogIDs = sourcePetWalkLogIDs
    }

    fileprivate func merging(_ candidate: HumanWorkoutPetWalkCandidate) -> HumanWorkoutPetWalkSnapshot {
        let candidatePetNames = candidate.petName.map { Set([$0]) } ?? []
        return HumanWorkoutPetWalkSnapshot(
            id: id,
            startDate: min(startDate, candidate.startDate),
            durationMinutes: max(durationMinutes, max(1, candidate.durationMinutes)),
            distanceKm: max(distanceKm, max(0, candidate.distanceKm)),
            petNames: Array(Set(petNames).union(candidatePetNames)).sorted(),
            sourcePetWalkLogIDs: sourcePetWalkLogIDs.union([candidate.sourceID])
        )
    }
}

nonisolated struct HumanWorkoutPetWalkDeduplicationResult: Equatable, Sendable {
    let snapshots: [HumanWorkoutPetWalkSnapshot]
    let wasTruncated: Bool
}

nonisolated enum HumanWorkoutPetWalkDeduplicationPolicy {
    static func makeSnapshots(
        candidates: [HumanWorkoutPetWalkCandidate],
        limit: Int
    ) -> HumanWorkoutPetWalkDeduplicationResult {
        let safeLimit = max(1, min(limit, 512))
        var snapshots: [HumanWorkoutPetWalkSnapshot] = []
        var indexByGroupingKey: [String: Int] = [:]

        for candidate in candidates {
            let groupingKey = groupingKey(for: candidate)
            if let index = indexByGroupingKey[groupingKey] {
                snapshots[index] = snapshots[index].merging(candidate)
            } else {
                indexByGroupingKey[groupingKey] = snapshots.count
                snapshots.append(HumanWorkoutPetWalkSnapshot(candidate: candidate, groupingKey: groupingKey))
            }
        }

        return HumanWorkoutPetWalkDeduplicationResult(
            snapshots: Array(snapshots.prefix(safeLimit)),
            wasTruncated: snapshots.count > safeLimit
        )
    }

    private static func groupingKey(for candidate: HumanWorkoutPetWalkCandidate) -> String {
        let sessionID = candidate.sharedSessionID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return sessionID.isEmpty ? "walk:\(candidate.sourceID)" : "session:\(sessionID)"
    }
}

nonisolated struct HumanWorkoutPetWalkSnapshotPage: Equatable, Sendable {
    let snapshots: [HumanWorkoutPetWalkSnapshot]
    let readState: HumanWorkoutHistoryReadState
}

enum HumanWorkoutPetWalkSnapshotBuilder {
    @MainActor
    static func page(
        for human: Human,
        since startDate: Date,
        through endDate: Date,
        limit: Int,
        context: ModelContext
    ) -> HumanWorkoutPetWalkSnapshotPage {
        let humanID = human.id.uuidString
        let safeLimit = max(1, min(limit, 512))
        let rawLimit = safeLimit * 4
        var descriptor = FetchDescriptor<PetWalkLog>(
            predicate: #Predicate<PetWalkLog> { walk in
                walk.startDate >= startDate && walk.startDate <= endDate
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = rawLimit + 1
        do {
            let walks: [PetWalkLog] = try context.fetch(descriptor)
            let rawWasTruncated = walks.count > rawLimit
            let candidates = walks.prefix(rawLimit).compactMap { walk -> HumanWorkoutPetWalkCandidate? in
                guard !walk.isRecoveryCheckpoint,
                      walk.endDate != nil,
                      walk.executorIds.contains(humanID) else {
                    return nil
                }
                return HumanWorkoutPetWalkCandidate(
                    sourceID: walk.id.uuidString,
                    sharedSessionID: walk.sharedSessionId,
                    startDate: walk.startDate,
                    durationMinutes: max(1, Int((walk.durationSeconds / 60).rounded())),
                    distanceKm: max(0, walk.distanceMeters / 1000),
                    petName: walk.pet?.name
                )
            }
            let deduplicated = HumanWorkoutPetWalkDeduplicationPolicy.makeSnapshots(
                candidates: candidates,
                limit: safeLimit
            )
            return HumanWorkoutPetWalkSnapshotPage(
                snapshots: deduplicated.snapshots,
                readState: rawWasTruncated || deduplicated.wasTruncated ? .truncated : .complete
            )
        } catch {
            OhanaLog.warning(
                "HumanWorkoutPetWalkSnapshotBuilder failed to fetch pet walks: \(error.localizedDescription)",
                category: "Care"
            )
            return HumanWorkoutPetWalkSnapshotPage(snapshots: [], readState: .unavailable)
        }
    }
}
