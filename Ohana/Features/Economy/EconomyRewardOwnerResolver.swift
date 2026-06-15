//
//  EconomyRewardOwnerResolver.swift
//  Ohana
//

import Foundation
import SwiftData

struct EconomyRewardOwnerResolution: Equatable {
    let requestedExecutorId: String?
    let effectiveExecutorId: String?
    let rewardExecutorId: String?
    let usedFallback: Bool
}

enum EconomyRewardOwnerResolver {
    @MainActor
    static func executorResolution(
        executorId: String?,
        activeHumanSelection: ActiveHumanSelecting,
        context: ModelContext,
        logPrefix: String
    ) -> EconomyRewardOwnerResolution {
        let requestedExecutorId = normalizedExecutorId(executorId)
        guard let requestedExecutorId else {
            return EconomyRewardOwnerResolution(
                requestedExecutorId: nil,
                effectiveExecutorId: nil,
                rewardExecutorId: nil,
                usedFallback: false
            )
        }

        if explicitHuman(id: requestedExecutorId, context: context, logPrefix: logPrefix) != nil {
            return EconomyRewardOwnerResolution(
                requestedExecutorId: requestedExecutorId,
                effectiveExecutorId: requestedExecutorId,
                rewardExecutorId: requestedExecutorId,
                usedFallback: false
            )
        }

        if let fallback = activeHuman(
            selection: activeHumanSelection,
            context: context,
            logPrefix: logPrefix
        ) {
            return EconomyRewardOwnerResolution(
                requestedExecutorId: requestedExecutorId,
                effectiveExecutorId: fallback.id.uuidString,
                rewardExecutorId: fallback.id.uuidString,
                usedFallback: true
            )
        }

        return EconomyRewardOwnerResolution(
            requestedExecutorId: requestedExecutorId,
            effectiveExecutorId: nil,
            rewardExecutorId: requestedExecutorId,
            usedFallback: false
        )
    }

    @MainActor
    static func rewardHuman(
        executorId: String?,
        activeHumanSelection: ActiveHumanSelecting,
        context: ModelContext,
        logPrefix: String
    ) -> Human? {
        if hasExplicitExecutor(executorId) {
            if let explicit = explicitHuman(id: executorId, context: context, logPrefix: logPrefix) {
                return explicit
            }
            OhanaLog.warning(
                "[\(logPrefix)] falling back to active human for unresolved executorId=\(executorId ?? "")",
                category: "Economy"
            )
        }
        return activeHuman(selection: activeHumanSelection, context: context, logPrefix: logPrefix)
    }

    static func hasExplicitExecutor(_ executorId: String?) -> Bool {
        normalizedExecutorId(executorId) != nil
    }

    static func normalizedExecutorId(_ executorId: String?) -> String? {
        guard let executorId else { return nil }
        let trimmed = executorId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    static func explicitHuman(
        id humanId: String?,
        context: ModelContext,
        logPrefix: String
    ) -> Human? {
        guard let humanId, !humanId.isEmpty else { return nil }
        guard let id = UUID(uuidString: humanId) else {
            OhanaLog.warning("[\(logPrefix)] reward humanId=\(humanId) is invalid", category: "Economy")
            return nil
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        do {
            let human = try context.fetch(descriptor).first
            if let human, !EconomyWalletWritePolicy.canWrite(human) {
                OhanaLog.warning(
                    "[\(logPrefix)] reward humanId=\(humanId) wallet is frozen; skipping human share",
                    category: "Economy"
                )
                return nil
            }
            return human
        } catch {
            OhanaLog.warning(
                "[\(logPrefix)] failed to fetch reward humanId=\(humanId): \(error.localizedDescription)",
                category: "Economy"
            )
            return nil
        }
    }

    @MainActor
    static func activeHuman(
        selection: ActiveHumanSelecting,
        context: ModelContext,
        logPrefix: String
    ) -> Human? {
        guard let humanId = selection.currentHumanId else { return nil }
        guard let id = UUID(uuidString: humanId) else {
            OhanaLog.warning(
                "[\(logPrefix)] active humanId=\(humanId) is invalid; skipping human share",
                category: "Economy"
            )
            return nil
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        let human: Human?
        do {
            human = try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "[\(logPrefix)] failed to fetch active humanId=\(humanId): \(error.localizedDescription)",
                category: "Economy"
            )
            return nil
        }
        if human == nil {
            OhanaLog.warning("[\(logPrefix)] humanId=\(humanId) not found in context; skipping human share", category: "Economy")
        } else if let human, !EconomyWalletWritePolicy.canWrite(human) {
            OhanaLog.warning(
                "[\(logPrefix)] active humanId=\(humanId) wallet is frozen; skipping human share",
                category: "Economy"
            )
            return nil
        }
        return human
    }
}
