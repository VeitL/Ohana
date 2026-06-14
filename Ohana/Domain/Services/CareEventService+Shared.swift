//
//  CareEventService+Shared.swift
//  Ohana
//

import Foundation
import SwiftData

extension CareEventService {
    @discardableResult
    @MainActor
    static func recordSharedManualFeed(
        sourcePet: Pet,
        targets: [Pet],
        totalGrams: Double,
        foodKind: FeedFoodKind,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordSharedManualFeedFact(
            sourcePet: sourcePet,
            targets: targets,
            totalGrams: totalGrams,
            foodKind: foodKind,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordSharedManualFeedFact(
        sourcePet: Pet,
        targets: [Pet],
        totalGrams: Double,
        foodKind: FeedFoodKind,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? .live()
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
        guard !liveTargets.isEmpty else { return .noOp() }
        guard liveTargets.count > 1 else {
            let target = liveTargets[0]
            let recorded = recordManualFeedFact(
                pet: target,
                amountGrams: totalGrams,
                context: context,
                executorId: executorId,
                quality: quality,
                date: date,
                foodKind: foodKind,
                dependencies: dependencies
            )
            return sharedResult(
                target: target,
                careLogID: recorded.result.logID,
                reward: recorded.reward,
                disposition: recorded.result.disposition
            )
        }

        let stockOwner = stockOwnerPet(for: liveTargets, preferred: sourcePet, foodKind: foodKind, context: context)
        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .feeding,
                sourcePet: sourcePet,
                targets: liveTargets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                totalAmountGrams: totalGrams,
                foodKind: foodKind,
                stockOwnerPet: stockOwner,
                childLogStrategy: .care(type: .feeding),
                reward: .feed,
                rewardQuality: quality,
                rewardTitle: "共同喂食 · \(liveTargets.count)只",
                reminderCareType: .feeding
            ),
            context: context,
            dependencies: dependencies
        )
        if result.allowsDerivedEffects {
            dependencies.questManager.recordFirstMeal(actorId: executorId, context: context)
        }
        return result
    }

    @discardableResult
    @MainActor
    static func recordSharedWatering(
        sourcePet: Pet,
        targets: [Pet],
        totalMl: Double,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordSharedWateringFact(
            sourcePet: sourcePet,
            targets: targets,
            totalMl: totalMl,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordSharedWateringFact(
        sourcePet: Pet,
        targets: [Pet],
        totalMl: Double,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? .live()
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
        guard !liveTargets.isEmpty else { return .noOp() }
        guard liveTargets.count > 1 else {
            let target = liveTargets[0]
            let recorded = recordCareFact(
                pet: target,
                type: .watering,
                amountMl: totalMl,
                context: context,
                executorId: executorId,
                reward: .water,
                date: date,
                dependencies: dependencies
            )
            return sharedResult(
                target: target,
                careLogID: recorded.result.logID,
                reward: recorded.reward,
                disposition: recorded.result.disposition
            )
        }

        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .watering,
                sourcePet: sourcePet,
                targets: liveTargets,
                date: date,
                executorId: executorId,
                allocationMode: totalMl > 0 ? .equal : .unknown,
                totalAmountMl: totalMl,
                childLogStrategy: .care(type: .watering),
                reward: .water,
                rewardTitle: "共同喂水 · \(liveTargets.count)只",
                reminderCareType: .watering
            ),
            context: context,
            dependencies: dependencies
        )
        return result
    }

    @discardableResult
    @MainActor
    static func recordSharedLitterCare(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        isFullChange: Bool = false,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordSharedLitterCareFact(
            sourcePet: sourcePet,
            targets: targets,
            context: context,
            executorId: executorId,
            date: date,
            isFullChange: isFullChange,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordSharedLitterCareFact(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        isFullChange: Bool = false,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? .live()
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
        guard !liveTargets.isEmpty else { return .noOp() }
        guard liveTargets.count > 1 else {
            let target = liveTargets[0]
            let recorded = recordCareFact(
                pet: target,
                type: .litter,
                context: context,
                executorId: executorId,
                reward: .potty(isLitter: true),
                date: date,
                dependencies: dependencies
            )
            return sharedResult(
                target: target,
                careLogID: recorded.result.logID,
                reward: recorded.reward,
                disposition: recorded.result.disposition
            )
        }

        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: isFullChange ? .litterChange : .litterScoop,
                sourcePet: sourcePet,
                targets: liveTargets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                childLogStrategy: .care(type: .litter),
                reward: .potty(isLitter: true),
                rewardTitle: isFullChange ? "共同换砂 · \(liveTargets.count)只" : "共同铲砂 · \(liveTargets.count)只",
                reminderCareType: .litter
            ),
            context: context,
            dependencies: dependencies
        )
        return result
    }

    @discardableResult
    @MainActor
    static func recordSharedCare(
        sourcePet: Pet,
        targets: [Pet],
        type: CareType,
        actionKind: SharedCareActionKind,
        context: ModelContext,
        executorId: String? = nil,
        reward: QuestManager.OhanaActionType,
        rewardTitle: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        source: CareLedgerSource = .quickAction,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordSharedCareFact(
            sourcePet: sourcePet,
            targets: targets,
            type: type,
            actionKind: actionKind,
            context: context,
            executorId: executorId,
            reward: reward,
            rewardTitle: rewardTitle,
            quality: quality,
            date: date,
            source: source,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordSharedCareFact(
        sourcePet: Pet,
        targets: [Pet],
        type: CareType,
        actionKind: SharedCareActionKind,
        context: ModelContext,
        executorId: String? = nil,
        reward: QuestManager.OhanaActionType,
        rewardTitle: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        source: CareLedgerSource = .quickAction,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? .live()
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
        guard !liveTargets.isEmpty else { return .noOp() }
        guard liveTargets.count > 1 else {
            let target = liveTargets[0]
            let recorded = recordCareFact(
                pet: target,
                type: type,
                context: context,
                executorId: executorId,
                reward: reward,
                quality: quality,
                date: date,
                dependencies: dependencies
            )
            return sharedResult(
                target: target,
                careLogID: recorded.result.logID,
                reward: recorded.reward,
                disposition: recorded.result.disposition
            )
        }

        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: actionKind,
                sourcePet: sourcePet,
                targets: liveTargets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                childLogStrategy: .care(type: type),
                reward: reward,
                rewardQuality: quality,
                rewardTitle: rewardTitle,
                reminderCareType: type,
                source: source
            ),
            context: context,
            dependencies: dependencies
        )
        return result
    }

    private static func sharedResult(
        target: Pet,
        careLogID: UUID,
        reward: (humanGot: Int, petGot: Int),
        disposition: CareFactWriteDisposition
    ) -> SharedPetActionResult {
        SharedPetActionResult(
            sessionID: careLogID,
            targetPetIDs: disposition.didWriteFact ? [target.id] : [],
            careLogIDs: disposition.didWriteFact ? [careLogID] : [],
            pottyLogID: nil,
            pottyLog: nil,
            expenseLogIDs: [],
            walkLogIDs: [],
            walkLogs: [],
            reward: reward,
            disposition: disposition
        )
    }

    @discardableResult
    @MainActor
    static func recordSharedExpense(
        sourcePet: Pet,
        targets: [Pet],
        amount: Double,
        category: ExpenseCategory,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        currencyCode: String = AppCurrency.code,
        source: CareLedgerSource = .detail,
        dependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .expense,
                sourcePet: sourcePet,
                targets: targets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                totalExpenseAmount: amount,
                currencyCode: currencyCode,
                note: note,
                childLogStrategy: .expense(category: category, note: note),
                reward: .expense,
                rewardTitle: "共享花费 · \(category.rawValue)",
                source: source
            ),
            context: context,
            dependencies: dependencies
        )
    }

    @discardableResult
    @MainActor
    static func recordSharedWalk(
        sourcePet: Pet,
        targets: [Pet],
        distanceMeters: Double,
        endDate: Date?,
        context: ModelContext,
        executorId: String? = nil,
        executorIds: [String] = [],
        startDate: Date = Date(),
        behaviorNotes: String? = nil,
        moodRating: Int = 0,
        source: CareLedgerSource = .quickAction,
        dependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let reward: QuestManager.OhanaActionType? = CoconutWalkRewardPolicy.isRewardable(distanceMeters: distanceMeters)
            ? .walk(distanceMeters: distanceMeters)
            : nil
        let coconutsEarned = PetWalkLog.coconuts(for: distanceMeters)
        return SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .walk,
                sourcePet: sourcePet,
                targets: targets,
                date: startDate,
                executorId: executorId,
                executorIds: executorIds,
                allocationMode: .equal,
                childLogStrategy: .walk(
                    distanceMeters: distanceMeters,
                    endDate: endDate,
                    coconutsEarned: coconutsEarned,
                    behaviorNotes: behaviorNotes,
                    moodRating: moodRating
                ),
                reward: reward,
                rewardTitle: "共同散步 · \(SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet).count)只",
                source: source
            ),
            context: context,
            dependencies: dependencies
        )
    }

    @discardableResult
    @MainActor
    static func recordUnknownSharedPotty(
        sourcePet: Pet,
        targets: [Pet],
        type: PottyType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies: CareEventServiceDependencies? = nil
    ) -> PetPottyLog? {
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
        guard !liveTargets.isEmpty else {
            return nil
        }
        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .pottyUnknown,
                sourcePet: sourcePet,
                targets: liveTargets,
                date: date,
                executorId: executorId,
                allocationMode: .unknown,
                childLogStrategy: .unknownPotty(type: type)
            ),
            context: context,
            dependencies: dependencies
        )
        return result.pottyLog
    }
}
