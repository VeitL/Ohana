//
//  QuestManager+BatchAward.swift
//  Ohana
//

import Foundation
import SwiftData

extension QuestManager {
    // MARK: - 批量打卡（任务三）

    /// Legacy batch care compatibility. Delegates fact, ledger, reward, reminder,
    /// revision, and Oasis side effects to the typed care chokepoints.
    /// - Parameters:
    ///   - type:    打卡类型（如 .feed / .water / .potty(isLitter:false) 等）
    ///   - pets:    目标宠物数组（冻结成员经 `CareFactWritePolicy` 过滤）
    ///   - context: ModelContext，用于统一照护写入
    /// - Returns:   (totalHuman, totalPet) 合并后的总发放椰子数
    @MainActor
    @discardableResult
    func batchAward(
        type: OhanaActionType,
        pets: [Pet],
        context: ModelContext
    ) -> (totalHuman: Int, totalPet: Int) {
        guard !pets.isEmpty else { return (0, 0) }

        let executorId = activeHumanSelection.currentHumanId
        let now = Date()
        let eligiblePets = pets.filter {
            CareFactWritePolicy.disposition(
                pet: $0,
                date: now,
                executorId: executorId,
                context: context
            ).allowsDerivedEffects
        }
        guard !eligiblePets.isEmpty else {
            lastEconomyRewardResult = .empty
            return (0, 0)
        }

        let dependencies = batchAwardDependencies()
        let careEvents: CareEventRecording = CareEventService(dependencies: dependencies)
        var total = (human: 0, pet: 0)
        for group in Self.sameSpeciesGroups(eligiblePets) {
            guard let sourcePet = group.first else { continue }
            let reward = recordBatchAwardGroup(
                type: type,
                sourcePet: sourcePet,
                targets: group,
                executorId: executorId,
                date: now,
                context: context,
                careEvents: careEvents,
                dependencies: dependencies
            )
            total.human += reward.humanGot
            total.pet += reward.petGot
        }
        return (total.human, total.pet)
    }

    private func recordBatchAwardGroup(
        type: OhanaActionType,
        sourcePet: Pet,
        targets: [Pet],
        executorId: String?,
        date: Date,
        context: ModelContext,
        careEvents: CareEventRecording,
        dependencies: CareEventServiceDependencies
    ) -> (humanGot: Int, petGot: Int) {
        switch type {
        case .feed:
            let result = careEvents.recordSharedManualFeedFact(
                sourcePet: sourcePet,
                targets: targets,
                totalGrams: 0,
                foodKind: .dry,
                context: context,
                executorId: executorId,
                quality: .none,
                date: date
            )
            guard result.didWriteFact, result.allowsDerivedEffects else { return (0, 0) }
            return result.reward
        case .water:
            let result = careEvents.recordSharedWateringFact(
                sourcePet: sourcePet,
                targets: targets,
                totalMl: 0,
                context: context,
                executorId: executorId,
                date: date
            )
            guard result.didWriteFact, result.allowsDerivedEffects else { return (0, 0) }
            return result.reward
        case let .potty(isLitter):
            if isLitter {
                let result = careEvents.recordSharedLitterCareFact(
                    sourcePet: sourcePet,
                    targets: targets,
                    context: context,
                    executorId: executorId,
                    date: date,
                    isFullChange: false
                )
                guard result.didWriteFact, result.allowsDerivedEffects else { return (0, 0) }
                return result.reward
            } else {
                return recordSharedBatchPotty(
                    sourcePet: sourcePet,
                    targets,
                    executorId: executorId,
                    date: date,
                    context: context,
                    dependencies: dependencies,
                    reward: type,
                    rewardTitle: batchRewardTitle(type: type, targets: targets)
                )
            }
        case let .care(type):
            return recordSharedBatchHygiene(
                sourcePet: sourcePet,
                targets,
                type: type,
                executorId: executorId,
                date: date,
                context: context,
                dependencies: dependencies,
                reward: .care(type: type),
                rewardTitle: batchRewardTitle(type: .care(type: type), targets: targets)
            )
        case let .general(_, _, _, title) where DomainCareRewardGeneralTitle.isLitterRewardTitle(title):
            let request = SharedCareRecordRequest(
                sourcePet: sourcePet,
                targets: targets,
                careType: .litter,
                actionKind: .litterScoop,
                executorID: executorId,
                reward: type,
                rewardTitle: batchRewardTitle(type: type, targets: targets),
                quality: .none,
                date: date,
                source: .quickAction
            )
            let result = careEvents.recordSharedCareFact(
                request,
                context: context
            )
            guard result.didWriteFact, result.allowsDerivedEffects else { return (0, 0) }
            return result.reward
        case let .general(_, _, _, title) where DomainCareRewardGeneralTitle.isPlayRewardTitle(title):
            let request = SharedCareRecordRequest(
                sourcePet: sourcePet,
                targets: targets,
                careType: .play,
                actionKind: .play,
                executorID: executorId,
                reward: type,
                rewardTitle: DomainCareRewardGeneralTitle.counted(DomainCareRewardGeneralTitle.sharedPlay, count: targets.count),
                quality: .none,
                date: date,
                source: .quickAction
            )
            let result = careEvents.recordSharedCareFact(
                request,
                context: context
            )
            guard result.didWriteFact, result.allowsDerivedEffects else { return (0, 0) }
            return result.reward
        default:
            lastEconomyRewardResult = .empty
            return (0, 0)
        }
    }

    private func recordSharedBatchPotty(
        sourcePet: Pet,
        _ targets: [Pet],
        executorId: String?,
        date: Date,
        context: ModelContext,
        dependencies: CareEventServiceDependencies,
        reward: OhanaActionType,
        rewardTitle: String
    ) -> (humanGot: Int, petGot: Int) {
        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .potty,
                sourcePet: sourcePet,
                targets: targets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                childLogStrategy: .potty(type: .perfectPoop),
                reward: reward,
                rewardTitle: rewardTitle,
                source: .quickAction
            ),
            context: context,
            dependencies: dependencies
        )
        guard result.didWriteFact, result.allowsDerivedEffects else { return (0, 0) }
        return result.reward
    }

    private func recordSharedBatchHygiene(
        sourcePet: Pet,
        _ targets: [Pet],
        type: HygieneType,
        executorId: String?,
        date: Date,
        context: ModelContext,
        dependencies: CareEventServiceDependencies,
        reward: OhanaActionType,
        rewardTitle: String
    ) -> (humanGot: Int, petGot: Int) {
        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .hygiene,
                sourcePet: sourcePet,
                targets: targets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                childLogStrategy: .hygiene(type: type),
                reward: reward,
                rewardTitle: rewardTitle,
                source: .quickAction
            ),
            context: context,
            dependencies: dependencies
        )
        guard result.didWriteFact, result.allowsDerivedEffects else { return (0, 0) }
        return result.reward
    }

    private func batchRewardTitle(type: OhanaActionType, targets: [Pet]) -> String {
        let petNames = targets.prefix(3).map(\.name).joined(separator: "、")
            + (targets.count > 3 ? " 等\(targets.count)只" : "")
        return "一键全家\(type.emoji) · \(petNames)"
    }

    private func batchAwardDependencies() -> CareEventServiceDependencies {
        let careLedger = CareLedgerService()
        let familyTasks = StaticFamilyTaskManager(wallet: wallet, careLedger: careLedger, questManager: self)
        let notifications = ReminderNotificationSchedulerRegistry.current
        let reminderCompletion = ReminderCompletionService(
            careLedger: careLedger,
            familyTasks: familyTasks,
            notifications: notifications
        )
        return CareEventServiceDependencies(
            economy: StaticCareEventEconomyAwarder(questManager: self),
            careLedger: careLedger,
            reminderCompletion: reminderCompletion,
            quickActionReminderCompletion: QuickActionReminderCompletionSyncService(reminderCompletion: reminderCompletion),
            familyTasks: familyTasks,
            revisions: revisions,
            notifications: notifications
        )
    }

    private static func sameSpeciesGroups(_ pets: [Pet]) -> [[Pet]] {
        Dictionary(grouping: pets) { SharedPetTargetResolver.normalizedSpecies($0.species) }
            .values
            .map { group in
                group.sorted { lhs, rhs in
                    if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                    return lhs.createdAt < rhs.createdAt
                }
            }
            .sorted { lhs, rhs in
                guard let left = lhs.first, let right = rhs.first else { return false }
                return SharedPetTargetResolver.normalizedSpecies(left.species) < SharedPetTargetResolver.normalizedSpecies(right.species)
            }
    }
}
