//
//  OasisCompanionLifecycleCompatibilityService.swift
//  Ohana
//
//  Bounded, idempotent cleanup for pre-V94 companion lifecycle state.
//

import Foundation
import SwiftData

@MainActor
enum OasisCompanionLifecycleCompatibilityService {
    struct Result: Equatable, Sendable {
        let inspectedCount: Int
        let repairedCount: Int
        let hasMoreWork: Bool
    }

    static func reconcile(
        context: ModelContext,
        maximumCount: Int = 64,
        now: Date = Date()
    ) throws -> Result {
        let limit = max(1, maximumCount)
        let healthyRaw = OasisCritterLifeState.healthy.rawValue
        let sleepingRaw = OasisCritterLifeState.sleeping.rawValue
        var stateDescriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { critter in
                critter.lifeStateRaw != healthyRaw && critter.lifeStateRaw != sleepingRaw
            }
        )
        var reasonDescriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { $0.deathReasonRaw != "" }
        )
        var riskDescriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { $0.riskStartedAt != nil }
        )
        var criticalDescriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { $0.criticalStartedAt != nil }
        )
        var deathDateDescriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { $0.diedAt != nil }
        )
        var promptDescriptor = FetchDescriptor<OasisElectronicPet>(
            predicate: #Predicate<OasisElectronicPet> { $0.lastGentlePromptAt != nil }
        )
        stateDescriptor.fetchLimit = limit + 1
        reasonDescriptor.fetchLimit = limit + 1
        riskDescriptor.fetchLimit = limit + 1
        criticalDescriptor.fetchLimit = limit + 1
        deathDateDescriptor.fetchLimit = limit + 1
        promptDescriptor.fetchLimit = limit + 1
        let sourceBatches = try [
            context.fetch(stateDescriptor),
            context.fetch(reasonDescriptor),
            context.fetch(riskDescriptor),
            context.fetch(criticalDescriptor),
            context.fetch(deathDateDescriptor),
            context.fetch(promptDescriptor)
        ]
        var uniqueCandidates: [UUID: OasisElectronicPet] = [:]
        for candidate in sourceBatches.joined() {
            uniqueCandidates[candidate.id] = candidate
        }
        let candidates = uniqueCandidates.values.sorted { $0.obtainedAt < $1.obtainedAt }
        let batch = Array(candidates.prefix(limit))
        var repairedCount = 0

        for critter in batch {
            let before = OasisUpgradeRewardService.lifecycleFingerprint(for: critter)
            OasisUpgradeRewardService.normalizeLifecycle(for: critter, now: now)
            if OasisUpgradeRewardService.lifecycleFingerprint(for: critter) != before {
                repairedCount += 1
            }
        }

        if repairedCount > 0 {
            try context.save()
        }
        return Result(
            inspectedCount: batch.count,
            repairedCount: repairedCount,
            hasMoreWork: candidates.count > limit || sourceBatches.contains(where: { $0.count > limit })
        )
    }
}
