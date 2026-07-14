import Foundation
import SwiftData

struct FamilyTaskFunding {
    let creator: Human
    let reward: Int
}

enum FamilyTaskFundingPolicy {
    @MainActor
    static func resolve(
        createdById: String?,
        assignedTo human: Human?,
        rewardCoconuts: Int,
        context: ModelContext
    ) -> FamilyTaskFunding? {
        let reward = FamilyTaskService.cappedReward(rewardCoconuts)
        guard reward > 0,
              let human,
              let creator = EconomyRewardOwnerResolver.explicitHuman(
                  id: createdById,
                  context: context,
                  logPrefix: "FamilyTaskFundingPolicy"
              ),
              creator.id != human.id,
              MemberLifecycleGate.disposition(human: creator, writeKind: .collaboration).allowsDerivedEffects,
              MemberLifecycleGate.disposition(human: human, writeKind: .collaboration).allowsDerivedEffects,
              CoconutWalletService.balance(for: creator, context: context) >= reward else {
            return nil
        }
        return FamilyTaskFunding(creator: creator, reward: reward)
    }
}

extension FamilyTaskService {
    static func cappedReward(_ value: Int) -> Int {
        min(rewardCap, max(0, value))
    }

    static func canPerform(_ task: FamilyCollaborationTask, human: Human?) -> Bool {
        guard let humanId = human?.id.uuidString else { return false }
        return task.assignedToId == humanId || task.claimedById == humanId
    }

    @MainActor
    static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "FamilyTaskService failed to \(operation): \(error.localizedDescription)",
                category: "FamilyTasks"
            )
            return []
        }
    }
}
