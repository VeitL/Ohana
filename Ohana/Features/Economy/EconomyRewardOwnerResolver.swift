//
//  EconomyRewardOwnerResolver.swift
//  Ohana
//

import Foundation
import SwiftData

enum EconomyRewardOwnerResolver {
    @MainActor
    static func rewardHuman(
        executorId: String?,
        activeHumanSelection: ActiveHumanSelecting,
        context: ModelContext,
        logPrefix: String
    ) -> Human? {
        if hasExplicitExecutor(executorId) {
            return explicitHuman(id: executorId, context: context, logPrefix: logPrefix)
        }
        return activeHuman(selection: activeHumanSelection, context: context, logPrefix: logPrefix)
    }

    static func hasExplicitExecutor(_ executorId: String?) -> Bool {
        guard let executorId else { return false }
        return !executorId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
