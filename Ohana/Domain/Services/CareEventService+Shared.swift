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
        quality: DomainCareRewardQuality = .none,
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
        quality: DomainCareRewardQuality = .none,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
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
                disposition: recorded.result.disposition,
                didPersist: recorded.result.didPersist,
                persistenceErrorDescription: recorded.result.persistenceErrorDescription
            )
        }

        let l = L10n.current
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
                rewardTitle: sharedCareRewardTitle(.feeding, targetCount: liveTargets.count, l: l),
                reminderCareType: .feeding
            ),
            context: context,
            dependencies: dependencies
        )
        if result.allowsDerivedEffects {
            dependencies.economy.recordFirstMeal(actorId: executorId, context: context)
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
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
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
                disposition: recorded.result.disposition,
                didPersist: recorded.result.didPersist,
                persistenceErrorDescription: recorded.result.persistenceErrorDescription
            )
        }

        let l = L10n.current
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
                rewardTitle: sharedCareRewardTitle(.watering, targetCount: liveTargets.count, l: l),
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
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
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
                disposition: recorded.result.disposition,
                didPersist: recorded.result.didPersist,
                persistenceErrorDescription: recorded.result.persistenceErrorDescription
            )
        }

        let l = L10n.current
        let actionKind: SharedCareActionKind = isFullChange ? .litterChange : .litterScoop
        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: actionKind,
                sourcePet: sourcePet,
                targets: liveTargets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                childLogStrategy: .care(type: .litter),
                reward: .potty(isLitter: true),
                rewardTitle: sharedCareRewardTitle(actionKind, targetCount: liveTargets.count, l: l),
                reminderCareType: .litter
            ),
            context: context,
            dependencies: dependencies
        )
        return result
    }

    /// Records only the authoritative real-world facts plus the durable undo receipt.
    /// Rewards, ledger projection, reminder/task completion, and plan side effects are
    /// deliberately deferred until the receipt is finalized.
    @discardableResult
    @MainActor
    static func recordPendingSharedLitterScoopFact(
        sourcePet: Pet,
        targets: [Pet],
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        undoDeadline: Date,
        corePayloadJSON: String = "{}",
        externalEffectsPayloadJSON: String = "{}",
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else { return .noOp() }
        return SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .litterScoop,
                sourcePet: sourcePet,
                targets: liveTargets,
                date: date,
                executorId: executorId,
                allocationMode: .equal,
                childLogStrategy: .care(type: .litter),
                reward: .potty(isLitter: true),
                rewardTitle: sharedCareRewardTitle(.litterScoop, targetCount: liveTargets.count, l: .current),
                reminderCareType: .litter
            ),
            context: context,
            dependencies: dependencies,
            deferredFinalization: SharedCareDeferredFinalizationRequest(
                undoDeadline: undoDeadline,
                corePayloadJSON: corePayloadJSON,
                externalEffectsPayloadJSON: externalEffectsPayloadJSON
            )
        )
    }

    @discardableResult
    @MainActor
    static func recordSharedCare(
        _ request: SharedCareRecordRequest,
        context: ModelContext,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordSharedCareFact(
            request,
            context: context,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordSharedCareFact(
        _ request: SharedCareRecordRequest,
        context: ModelContext,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let dependencies = providedDependencies ?? DomainServiceDependencyRegistry.careEventDependencies()
        let liveTargets = SharedPetTargetResolver.normalizedTargets(request.targets, fallback: request.sourcePet)
        guard !liveTargets.isEmpty else { return .noOp() }
        guard liveTargets.count > 1 else {
            let target = liveTargets[0]
            let recorded = recordCareFact(
                pet: target,
                type: request.careType,
                context: context,
                executorId: request.executorID,
                reward: request.reward,
                quality: request.quality,
                date: request.date,
                dependencies: dependencies
            )
            return sharedResult(
                target: target,
                careLogID: recorded.result.logID,
                reward: recorded.reward,
                disposition: recorded.result.disposition,
                didPersist: recorded.result.didPersist,
                persistenceErrorDescription: recorded.result.persistenceErrorDescription
            )
        }

        let result = SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: request.actionKind,
                sourcePet: request.sourcePet,
                targets: liveTargets,
                date: request.date,
                executorId: request.executorID,
                allocationMode: .equal,
                childLogStrategy: .care(type: request.careType),
                reward: request.reward,
                rewardQuality: request.quality,
                rewardTitle: request.rewardTitle,
                reminderCareType: request.careType,
                source: request.source
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
        disposition: CareFactWriteDisposition,
        didPersist: Bool,
        persistenceErrorDescription: String?
    ) -> SharedPetActionResult {
        SharedPetActionResult(
            sessionID: careLogID,
            targetPetIDs: didPersist && disposition.didWriteFact ? [target.id] : [],
            careLogIDs: didPersist && disposition.didWriteFact ? [careLogID] : [],
            pottyLogID: nil,
            pottyLog: nil,
            expenseLogIDs: [],
            walkLogIDs: [],
            walkLogs: [],
            reward: reward,
            disposition: disposition,
            didPersist: didPersist,
            persistenceErrorDescription: persistenceErrorDescription
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
        attribution: ExpenseActorAttribution = ExpenseActorAttribution(),
        date: Date = Date(),
        currencyCode: String = AppCurrency.code,
        source: CareLedgerSource = .detail,
        dependencies: CareEventServiceDependencies? = nil
    ) -> SharedPetActionResult {
        let targetCount = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet).count
        let attribution = attribution.validated(context: context)
        return SharedPetActionRecorder.record(
            SharedPetActionDescriptor(
                actionKind: .expense,
                sourcePet: sourcePet,
                targets: targets,
                date: date,
                executorId: attribution.executorId,
                recordedByHumanId: attribution.recordedByHumanId,
                allocationMode: .equal,
                totalExpenseAmount: amount,
                currencyCode: currencyCode,
                note: note,
                childLogStrategy: .expense(category: category, note: note),
                reward: .expense,
                rewardTitle: sharedCareRewardTitle(.expense, targetCount: targetCount, category: category, l: .current),
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
        let targetCount = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet).count
        let reward: DomainCareRewardAction? = CoconutWalkRewardPolicy.isRewardable(distanceMeters: distanceMeters)
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
                rewardTitle: sharedCareRewardTitle(.walk, targetCount: targetCount, l: .current),
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

    static func sharedCareRewardTitle(
        _ actionKind: SharedCareActionKind,
        targetCount: Int,
        category: ExpenseCategory? = nil,
        l: L10n = .current
    ) -> String {
        let count = sharedCareTargetCount(targetCount, l: l)
        switch actionKind {
        case .feeding:
            return l.tr(zh: "共同喂食 · \(count)", en: "Shared feeding · \(count)", de: "Gemeinsam füttern · \(count)")
        case .watering:
            return l.tr(zh: "共同喂水 · \(count)", en: "Shared watering · \(count)", de: "Gemeinsam Wasser · \(count)")
        case .litterChange:
            return l.tr(zh: "共同换砂 · \(count)", en: "Shared litter change · \(count)", de: "Gemeinsamer Streuwechsel · \(count)")
        case .litterScoop:
            return l.tr(zh: "共同铲砂 · \(count)", en: "Shared litter scoop · \(count)", de: "Gemeinsam Klo säubern · \(count)")
        case .expense:
            let categoryTitle = category.map { l.expenseCategoryTitle($0) } ?? l.tr(zh: "花费", en: "Expense", de: "Ausgabe")
            return l.tr(zh: "共享花费 · \(categoryTitle)", en: "Shared expense · \(categoryTitle)", de: "Geteilte Ausgabe · \(categoryTitle)")
        case .walk:
            return l.tr(zh: "共同散步 · \(count)", en: "Shared walk · \(count)", de: "Gemeinsamer Spaziergang · \(count)")
        case .play:
            return l.tr(zh: "共同陪玩 · \(count)", en: "Shared play · \(count)", de: "Gemeinsames Spielen · \(count)")
        case .waterChange:
            return l.tr(zh: "共同换水 · \(count)", en: "Shared water change · \(count)", de: "Gemeinsamer Wasserwechsel · \(count)")
        case .filterClean:
            return l.tr(zh: "共同清理滤材 · \(count)", en: "Shared filter cleaning · \(count)", de: "Gemeinsam Filter reinigen · \(count)")
        case .cageCleaning:
            return l.tr(zh: "共同清笼 · \(count)", en: "Shared cage cleaning · \(count)", de: "Gemeinsam Käfig reinigen · \(count)")
        case .freeFlight:
            return l.tr(zh: "共同放飞 · \(count)", en: "Shared free flight · \(count)", de: "Gemeinsamer Freiflug · \(count)")
        case .misting:
            return l.tr(zh: "共同保湿 · \(count)", en: "Shared misting · \(count)", de: "Gemeinsam befeuchten · \(count)")
        case .substrateChange:
            return l.tr(zh: "共同换垫 · \(count)", en: "Shared substrate change · \(count)", de: "Gemeinsamer Substratwechsel · \(count)")
        case .potty, .pottyUnknown, .hygiene:
            return l.tr(zh: "共同照护 · \(count)", en: "Shared care · \(count)", de: "Gemeinsame Pflege · \(count)")
        }
    }

    private static func sharedCareTargetCount(_ targetCount: Int, l: L10n) -> String {
        let count = max(0, targetCount)
        let enUnit = count == 1 ? "pet" : "pets"
        let deUnit = count == 1 ? "Haustier" : "Haustiere"
        return l.tr(zh: "\(count)只", en: "\(count) \(enUnit)", de: "\(count) \(deUnit)")
    }
}
