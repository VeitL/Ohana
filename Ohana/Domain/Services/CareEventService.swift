//
//  CareEventService.swift
//  Ohana
//
//  Centralized care/reminder/economy write paths.
//

import Foundation
import SwiftData

@MainActor
protocol CareEventEconomyAwarding {
    @discardableResult
    func awardCareAction(
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func awardSharedCareAction(
        type: QuestManager.OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        title: String?
    ) -> (humanGot: Int, petGot: Int)
}

@MainActor
struct CareEventServiceDependencies {
    let questManager: QuestManager
    let economy: CareEventEconomyAwarding
    let careLedger: CareLedgerRecording
    let reminderCompletion: ReminderCompleting
    let quickActionReminderCompletion: QuickActionReminderCompleting
    let familyTasks: FamilyTaskManaging
    let revisions: DomainRevisionPublishing

    static func live() -> CareEventServiceDependencies {
        let wallet = SwiftDataCoconutWalletManager()
        let revisions = SharedDomainRevisionPublisher()
        let questManager = QuestManager(wallet: wallet, revisions: revisions)
        let careLedger = CareLedgerService()
        let familyTasks = StaticFamilyTaskManager(wallet: wallet, careLedger: careLedger, questManager: questManager)
        let reminderCompletion = ReminderCompletionService(careLedger: careLedger, familyTasks: familyTasks)
        return CareEventServiceDependencies(
            questManager: questManager,
            economy: StaticCareEventEconomyAwarder(questManager: questManager),
            careLedger: careLedger,
            reminderCompletion: reminderCompletion,
            quickActionReminderCompletion: QuickActionReminderCompletionSyncService(reminderCompletion: reminderCompletion),
            familyTasks: familyTasks,
            revisions: revisions
        )
    }
}

@MainActor
final class CareEventService: CareEventRecording {
    let dependencies: CareEventServiceDependencies

    convenience init() {
        self.init(dependencies: .live())
    }

    init(dependencies: CareEventServiceDependencies) {
        self.dependencies = dependencies
    }

    struct CareRecordResult: Equatable {
        let logID: UUID
        let subjectID: UUID
        let careType: CareType
        let linkedPottyLogID: UUID?
        let coconutDelta: Int
    }

    @discardableResult
    @MainActor
    static func recordManualFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        foodKind: FeedFoodKind = .dry,
        dependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordManualFeedFact(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            foodKind: foodKind,
            dependencies: dependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordManualFeedFact(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        foodKind: FeedFoodKind = .dry,
        source: CareLedgerSource = .quickAction,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog) {
        let dependencies = providedDependencies ?? .live()
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: PetCareLog.manualFeedNoteMarker,
            foodKind: foodKind,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()

        dependencies.questManager.recordFirstMeal(actorId: executorId, context: context)
        let reward = dependencies.economy.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: source,
            sourceEventId: nil,
            sourceReminderId: nil,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            metadataJSON: dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        dependencies.quickActionReminderCompletion.completeNearestPetCareReminder(
            pet: pet,
            type: .feeding,
            context: context,
            executorId: executorId,
            now: date
        )
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: .feeding,
                linkedPottyLogID: nil,
                coconutDelta: dependencies.careLedger.rewardDelta(reward)
            ),
            reward,
            log
        )
    }

    @discardableResult
    @MainActor
    static func recordTreatFeed(
        pet: Pet,
        amountGrams: Double,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        treatKind: FeedTreatKind = .other,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> PetCareLog {
        let dependencies = providedDependencies ?? .live()
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: FeedLogMetadata.treatFeedNoteMarker,
            treatKind: treatKind,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            sourceEventId: nil,
            sourceReminderId: nil,
            coconutDelta: 0,
            metadataJSON: "",
            context: context,
            save: true
        )
        return log
    }

    @discardableResult
    @MainActor
    static func completePlannedFeed(
        pet: Pet,
        reminder: Reminder,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .precise,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int)? {
        let dependencies = providedDependencies ?? .live()
        guard let event = reminder.event else { return nil }
        let isCatchUp = reminder.scheduledAt < date
        guard !isCatchUp || FeedPlanCatchUpPolicy.isCatchUpEligible(reminder, now: date) else {
            return nil
        }

        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: feedAmount(from: event, fallback: pet.dailyPortionGrams),
            note: "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString)",
            foodKind: event.foodKind,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)

        reminder.statusEnum = .completed
        reminder.completedAt = date
        if let executorId {
            reminder.completedBy = executorId
        }
        event.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        dependencies.careLedger.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: executorId,
            source: .reminder,
            context: context,
            save: true
        )
        dependencies.familyTasks.syncCompletedReminder(reminder, completedBy: executorId, context: context)

        if isCatchUp {
            dependencies.careLedger.recordPetCare(
                log: log,
                pet: pet,
                source: .reminder,
                sourceEventId: event.id.uuidString,
                sourceReminderId: reminder.id.uuidString,
                coconutDelta: 0,
                metadataJSON: "",
                context: context,
                save: true
            )
            return (0, 0)
        }

        dependencies.questManager.recordFirstMeal(actorId: executorId, context: context)
        let reward = dependencies.economy.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            metadataJSON: dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        return reward
    }

    @discardableResult
    @MainActor
    static func completePlannedWater(
        pet: Pet,
        reminder: Reminder,
        amountMl: Double,
        context: ModelContext,
        executorId: String? = nil,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int)? {
        let dependencies = providedDependencies ?? .live()
        guard let event = reminder.event else { return nil }

        let log = PetCareLog(
            date: Date(),
            type: .watering,
            amountMl: max(0, amountMl),
            note: "\(PetCareLog.plannedWaterNotePrefix)\(event.id.uuidString)",
            pet: pet,
            executorId: executorId
        )
        context.insert(log)

        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        if let executorId {
            reminder.completedBy = executorId
        }
        event.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        dependencies.careLedger.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: executorId,
            source: .reminder,
            context: context,
            save: true
        )
        dependencies.familyTasks.syncCompletedReminder(reminder, completedBy: executorId, context: context)

        let reward = dependencies.economy.awardCareAction(type: .water, pet: pet, context: context, quality: .none)
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            metadataJSON: dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        return reward
    }

    @discardableResult
    @MainActor
    static func recordCare(
        pet: Pet,
        type: CareType,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        dependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordCareFact(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward,
            quality: quality,
            date: date,
            dependencies: dependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordCareFact(
        pet: Pet,
        type: CareType,
        amountMl: Double = 0,
        context: ModelContext,
        executorId: String? = nil,
        reward: QuestManager.OhanaActionType,
        quality: QuestManager.QualityBonus = .none,
        date: Date = Date(),
        source: CareLedgerSource = .quickAction,
        createsLinkedPottyLog: Bool = false,
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?) {
        let dependencies = providedDependencies ?? .live()
        let log = PetCareLog(
            date: date,
            type: type,
            amountMl: amountMl,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        let pottyLog: PetPottyLog?
        if createsLinkedPottyLog, type == .litter {
            let linked = PetPottyLog(date: date, type: .perfectPoop, pet: pet, executorId: executorId)
            context.insert(linked)
            pottyLog = linked
        } else {
            pottyLog = nil
        }
        context.safeSave()

        let award = dependencies.economy.awardCareAction(type: reward, pet: pet, context: context, quality: quality)
        dependencies.careLedger.recordPetCare(
            log: log,
            pet: pet,
            source: source,
            sourceEventId: nil,
            sourceReminderId: nil,
            coconutDelta: dependencies.careLedger.rewardDelta(award),
            metadataJSON: dependencies.careLedger.rewardMetadata(award, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        if let pottyLog {
            dependencies.careLedger.recordPetPotty(
                log: pottyLog,
                pet: pet,
                source: source,
                coconutDelta: 0,
                metadataJSON: "",
                context: context,
                save: true
            )
        }
        dependencies.quickActionReminderCompletion.completeNearestPetCareReminder(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            now: date
        )
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: type,
                linkedPottyLogID: pottyLog?.id,
                coconutDelta: dependencies.careLedger.rewardDelta(award)
            ),
            award,
            log,
            pottyLog
        )
    }

    @discardableResult
    @MainActor
    static func recordPotty(
        pet: Pet,
        type: PottyType = .perfectPoop,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let dependencies = providedDependencies ?? .live()
        let log = PetPottyLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = dependencies.economy.awardCareAction(type: .potty(isLitter: false), pet: pet, context: context, quality: .none)
        dependencies.careLedger.recordPetPotty(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            metadataJSON: dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager),
            context: context,
            save: true
        )
        dependencies.quickActionReminderCompletion.completeNearestPetPottyReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: date
        )
        return reward
    }

    struct HygieneRecordResult: Equatable {
        let logID: UUID
        let subjectID: UUID
        let hygieneType: HygieneType
        let coconutDelta: Int
    }

    @discardableResult
    @MainActor
    static func recordHygiene(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        recordHygieneFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: dependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordHygieneFact(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: HygieneRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHygieneLog) {
        let dependencies = providedDependencies ?? .live()
        let log = PetHygieneLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = dependencies.economy.awardCareAction(type: .care(type: type), pet: pet, context: context, quality: .none)
        let metadataJSON = dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager)
        dependencies.careLedger.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: type.rawValue,
            amountValue: 0,
            amountUnit: "",
            note: "",
            source: .quickAction,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "PetHygieneLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: true
        )
        dependencies.careLedger.syncOasisTreeEnergyIfNeeded(metadataJSON: metadataJSON, context: context)
        dependencies.quickActionReminderCompletion.completeNearestPetHygieneReminder(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            now: date
        )
        let result = HygieneRecordResult(
            logID: log.id,
            subjectID: pet.id,
            hygieneType: type,
            coconutDelta: dependencies.careLedger.rewardDelta(reward)
        )
        return (result, reward, log)
    }

    @discardableResult
    @MainActor
    static func recordHealth(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int) {
        let dependencies = providedDependencies ?? .live()
        let log = PetHealthLog(date: date, type: type, note: note, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = dependencies.economy.awardCareAction(type: .health, pet: pet, context: context, quality: .none)
        let metadataJSON = dependencies.careLedger.rewardMetadata(reward, questManager: dependencies.questManager)
        dependencies.careLedger.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: type.rawValue,
            amountValue: 0,
            amountUnit: "",
            note: note,
            source: .quickAction,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "PetHealthLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: true
        )
        dependencies.careLedger.syncOasisTreeEnergyIfNeeded(metadataJSON: metadataJSON, context: context)
        return reward
    }

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
        let dependencies = providedDependencies ?? .live()
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordManualFeed(
                pet: sourcePet,
                amountGrams: totalGrams,
                context: context,
                executorId: executorId,
                quality: quality,
                date: date,
                foodKind: foodKind,
                dependencies: dependencies
            )
        }

        let stockOwner = stockOwnerPet(for: liveTargets, preferred: sourcePet, foodKind: foodKind, context: context)
        dependencies.questManager.recordFirstMeal(actorId: executorId, context: context)
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
        return result.reward
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
        let dependencies = providedDependencies ?? .live()
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordCare(
                pet: sourcePet,
                type: .watering,
                amountMl: totalMl,
                context: context,
                executorId: executorId,
                reward: .water,
                date: date,
                dependencies: dependencies
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
        return result.reward
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
        let dependencies = providedDependencies ?? .live()
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordCare(
                pet: sourcePet,
                type: .litter,
                context: context,
                executorId: executorId,
                reward: .potty(isLitter: true),
                date: date,
                dependencies: dependencies
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
        return result.reward
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
        let dependencies = providedDependencies ?? .live()
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordCare(
                pet: sourcePet,
                type: type,
                context: context,
                executorId: executorId,
                reward: reward,
                quality: quality,
                date: date,
                dependencies: dependencies
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
        return result.reward
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
        currencyCode: String = "currency",
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
    ) -> PetPottyLog {
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
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
        return result.pottyLog ?? PetPottyLog(date: date, type: type, executorId: executorId)
    }

    static func feedAmount(from event: Event, fallback: Double) -> Double {
        if event.feedAmountGrams > 0 {
            return event.feedAmountGrams
        }
        let digits = event.title.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(digits) ?? fallback
    }
}
