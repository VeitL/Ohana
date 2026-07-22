//
//  MemberProfileCompletenessReadService.swift
//  Ohana
//
//  Bounded read support for explicit profile-category confirmations.
//

import Foundation
import SwiftData

nonisolated enum MemberProfileCompletionResolutionMapper {
    static func resolvedCategories(
        kind: MemberProfileCompletionKind,
        subjectID: UUID,
        resolutions: [String: HouseholdStarterJourneyResolution]
    ) -> Set<MemberProfileCompletionCategory> {
        switch kind {
        case .human:
            var result: Set<MemberProfileCompletionCategory> = []
            if hasResolution(.humanAppearance, subjectID: subjectID, resolutions: resolutions) {
                result.insert(.humanAppearance)
            }
            let focusedMappings: [(String, MemberProfileCompletionCategory)] = [
                ("humanLifeStage", .humanLifeStage),
                ("humanBodyProfile", .humanBodyProfile),
                ("humanPersonalityContext", .humanPersonalityContext)
            ]
            for (rawCheckpoint, category) in focusedMappings
                where HouseholdStarterJourneyCheckpoint(rawValue: rawCheckpoint)
                    .map({ hasResolution($0, subjectID: subjectID, resolutions: resolutions) }) == true {
                result.insert(category)
            }
            if hasResolution(.humanOptionalDetails, subjectID: subjectID, resolutions: resolutions) {
                result.formUnion([.humanLifeStage, .humanBodyProfile, .humanPersonalityContext])
            }
            return result
        case .pet:
            let mappings: [(HouseholdStarterJourneyCheckpoint, MemberProfileCompletionCategory)] = [
                (.petLifeStage, .petLifeStage),
                (.petBodyProfile, .petBodyProfile),
                (.petPersonalityAppearance, .petPersonalityAppearance),
                (.petDailyCare, .petDailyCare)
            ]
            return Set(mappings.compactMap { checkpoint, category in
                hasResolution(checkpoint, subjectID: subjectID, resolutions: resolutions)
                    ? category
                    : nil
            })
        case .plant:
            return []
        }
    }

    private static func hasResolution(
        _ checkpoint: HouseholdStarterJourneyCheckpoint,
        subjectID: UUID,
        resolutions: [String: HouseholdStarterJourneyResolution]
    ) -> Bool {
        let key = HouseholdStarterJourneyService.checkpointRecordKey(
            task: checkpoint.task,
            checkpoint: checkpoint,
            subjectID: subjectID
        )
        return resolutions[key] != nil
    }
}

@MainActor
enum MemberProfileCompletenessReadService {
    static func explicitlyResolvedCategories(
        kind: MemberProfileCompletionKind,
        subjectID: UUID,
        context: ModelContext
    ) -> Set<MemberProfileCompletionCategory> {
        guard kind != .plant else { return [] }
        var checkpoints: [HouseholdStarterJourneyCheckpoint] = switch kind {
        case .human:
            HouseholdStarterJourneyTask.humanProfile.checkpoints
        case .pet:
            HouseholdStarterJourneyTask.petProfile.checkpoints
        case .plant:
            []
        }
        if kind == .human,
           let legacyCheckpoint = HouseholdStarterJourneyCheckpoint(rawValue: "humanOptionalDetails"),
           !checkpoints.contains(legacyCheckpoint) {
            checkpoints.append(legacyCheckpoint)
        }
        let actionType = HouseholdStarterJourneyService.checkpointActionType
        let modelName = HouseholdStarterJourneyService.checkpointSourceModelName
        var events: [CareLedgerEvent] = []

        do {
            for checkpoint in checkpoints {
                let recordKey = HouseholdStarterJourneyService.checkpointRecordKey(
                    task: checkpoint.task,
                    checkpoint: checkpoint,
                    subjectID: subjectID
                )
                var descriptor = FetchDescriptor<CareLedgerEvent>(
                    predicate: #Predicate<CareLedgerEvent> { event in
                        event.actionType == actionType
                            && event.legacyModelName == modelName
                            && event.legacyModelId == recordKey
                    },
                    sortBy: [
                        SortDescriptor(\.occurredAt, order: .reverse),
                        SortDescriptor(\.createdAt, order: .reverse),
                        SortDescriptor(\.id, order: .reverse)
                    ]
                )
                descriptor.fetchLimit = 1
                if let event = try context.fetch(descriptor).first {
                    events.append(event)
                }
            }
        } catch {
            OhanaLog.warning(
                "Profile completion checkpoint read failed: \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }

        return MemberProfileCompletionResolutionMapper.resolvedCategories(
            kind: kind,
            subjectID: subjectID,
            resolutions: HouseholdStarterJourneyService.checkpointResolutions(from: events)
        )
    }
}
