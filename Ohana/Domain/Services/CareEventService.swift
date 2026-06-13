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
        quality: QuestManager.QualityBonus,
        executorId: String?
    ) -> (humanGot: Int, petGot: Int)

    @discardableResult
    func awardSharedCareAction(
        type: QuestManager.OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QuestManager.QualityBonus,
        title: String?,
        executorId: String?
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

enum CareFactWriteDisposition: Equatable {
    case active
    case memorialHistoricalFactOnly
    case noOp

    var didWriteFact: Bool {
        self != .noOp
    }

    var writesFact: Bool {
        didWriteFact
    }

    var allowsDerivedEffects: Bool {
        self == .active
    }
}

enum CareFactWritePolicy {
    @MainActor
    static func disposition(
        pet: Pet,
        date: Date,
        executorId: String?,
        context: ModelContext
    ) -> CareFactWriteDisposition {
        guard pet.trashedAt == nil else { return .noOp }
        if executorIsRecycled(executorId, context: context) { return .noOp }

        guard let passedAwayDate = pet.passedAwayDate else { return .active }
        return isHistorical(date, relativeToPassingDate: passedAwayDate) ? .memorialHistoricalFactOnly : .noOp
    }

    @MainActor
    static func executorIsRecycled(_ executorId: String?, context: ModelContext) -> Bool {
        guard let executorId,
              let id = UUID(uuidString: executorId) else {
            return false
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        descriptor.fetchLimit = 1
        guard let human = try? context.fetch(descriptor).first else { return false }
        return human.trashedAt != nil
    }

    private static func isHistorical(_ date: Date, relativeToPassingDate passingDate: Date) -> Bool {
        let calendar = Calendar.current
        let dayAfterPassing = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: passingDate)
        ) ?? passingDate
        return date < dayAfterPassing
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
        let disposition: CareFactWriteDisposition

        init(
            logID: UUID,
            subjectID: UUID,
            careType: CareType,
            linkedPottyLogID: UUID?,
            coconutDelta: Int,
            disposition: CareFactWriteDisposition = .active
        ) {
            self.logID = logID
            self.subjectID = subjectID
            self.careType = careType
            self.linkedPottyLogID = linkedPottyLogID
            self.coconutDelta = coconutDelta
            self.disposition = disposition
        }

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }

    struct PottyRecordResult: Equatable {
        let logID: UUID?
        let subjectID: UUID
        let pottyType: PottyType
        let coconutDelta: Int
        let disposition: CareFactWriteDisposition

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }

    struct HealthRecordResult: Equatable {
        let logID: UUID?
        let subjectID: UUID
        let healthType: HealthLogType
        let coconutDelta: Int
        let disposition: CareFactWriteDisposition

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
    }

    private static func noOpManualFeedResult(
        pet: Pet,
        amountGrams: Double,
        executorId: String?,
        date: Date,
        foodKind: FeedFoodKind
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog) {
        let log = PetCareLog(
            date: date,
            type: .feeding,
            amountGrams: amountGrams,
            note: PetCareLog.manualFeedNoteMarker,
            foodKind: foodKind,
            pet: nil,
            executorId: executorId
        )
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: .feeding,
                linkedPottyLogID: nil,
                coconutDelta: 0,
                disposition: .noOp
            ),
            (0, 0),
            log
        )
    }

    private static func noOpCareFactResult(
        pet: Pet,
        type: CareType,
        amountMl: Double,
        executorId: String?,
        reward _: QuestManager.OhanaActionType,
        date: Date
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?) {
        let log = PetCareLog(date: date, type: type, amountMl: amountMl, pet: nil, executorId: executorId)
        return (
            CareRecordResult(
                logID: log.id,
                subjectID: pet.id,
                careType: type,
                linkedPottyLogID: nil,
                coconutDelta: 0,
                disposition: .noOp
            ),
            (0, 0),
            log,
            nil
        )
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
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            return noOpManualFeedResult(
                pet: pet,
                amountGrams: amountGrams,
                executorId: executorId,
                date: date,
                foodKind: foodKind
            )
        }
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
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: log.date)
        context.safeSave()

        guard disposition.allowsDerivedEffects else {
            return (
                CareRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    careType: .feeding,
                    linkedPottyLogID: nil,
                    coconutDelta: 0,
                    disposition: disposition
                ),
                (0, 0),
                log
            )
        }

        dependencies.questManager.recordFirstMeal(actorId: executorId, context: context)
        let reward = dependencies.economy.awardCareAction(
            type: .feed,
            pet: pet,
            context: context,
            quality: quality,
            executorId: executorId
        )
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
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            return PetCareLog(
                date: date,
                type: .feeding,
                amountGrams: amountGrams,
                note: FeedLogMetadata.treatFeedNoteMarker,
                treatKind: treatKind,
                pet: nil,
                executorId: executorId
            )
        }
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
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        context.safeSave()
        guard disposition.allowsDerivedEffects else { return log }
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
        guard CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        ) == .active else {
            return nil
        }
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
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: log.date)

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
        let reward = dependencies.economy.awardCareAction(
            type: .feed,
            pet: pet,
            context: context,
            quality: quality,
            executorId: executorId
        )
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
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (humanGot: Int, petGot: Int)? {
        let dependencies = providedDependencies ?? .live()
        guard let event = reminder.event else { return nil }
        guard CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        ) == .active else {
            return nil
        }
        let isCatchUp = reminder.scheduledAt < date
        guard !isCatchUp || WaterPlanCatchUpPolicy.isCatchUpEligible(reminder, now: date) else {
            return nil
        }

        let log = PetCareLog(
            date: date,
            type: .watering,
            amountMl: max(0, amountMl),
            note: "\(PetCareLog.plannedWaterNotePrefix)\(event.id.uuidString)",
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: log.date)

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

        let reward = dependencies.economy.awardCareAction(
            type: .water,
            pet: pet,
            context: context,
            quality: .none,
            executorId: executorId
        )
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
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            return noOpCareFactResult(
                pet: pet,
                type: type,
                amountMl: amountMl,
                executorId: executorId,
                reward: reward,
                date: date
            )
        }
        let log = PetCareLog(
            date: date,
            type: type,
            amountMl: amountMl,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        let pottyLog: PetPottyLog?
        if disposition.allowsDerivedEffects, createsLinkedPottyLog, type == .litter {
            let linked = PetPottyLog(date: date, type: .perfectPoop, pet: pet, executorId: executorId)
            context.insert(linked)
            CloudSyncMutationRecorder.markModified(linked, context: context, modifiedAt: date)
            pottyLog = linked
        } else {
            pottyLog = nil
        }
        context.safeSave()

        guard disposition.allowsDerivedEffects else {
            return (
                CareRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    careType: type,
                    linkedPottyLogID: nil,
                    coconutDelta: 0,
                    disposition: disposition
                ),
                (0, 0),
                log,
                nil
            )
        }

        let award = dependencies.economy.awardCareAction(
            type: reward,
            pet: pet,
            context: context,
            quality: quality,
            executorId: executorId
        )
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
        recordPottyFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordPottyFact(
        pet: Pet,
        type: PottyType = .perfectPoop,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: PottyRecordResult, reward: (humanGot: Int, petGot: Int), log: PetPottyLog?) {
        let dependencies = providedDependencies ?? .live()
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            return (
                PottyRecordResult(
                    logID: nil,
                    subjectID: pet.id,
                    pottyType: type,
                    coconutDelta: 0,
                    disposition: .noOp
                ),
                (0, 0),
                nil
            )
        }
        let log = PetPottyLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        context.safeSave()

        guard disposition.allowsDerivedEffects else {
            return (
                PottyRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    pottyType: type,
                    coconutDelta: 0,
                    disposition: disposition
                ),
                (0, 0),
                log
            )
        }
        let reward = dependencies.economy.awardCareAction(
            type: .potty(isLitter: false),
            pet: pet,
            context: context,
            quality: .none,
            executorId: executorId
        )
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
        let result = PottyRecordResult(
            logID: log.id,
            subjectID: pet.id,
            pottyType: type,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            disposition: disposition
        )
        return (result, reward, log)
    }

    struct HygieneRecordResult: Equatable {
        let logID: UUID
        let subjectID: UUID
        let hygieneType: HygieneType
        let coconutDelta: Int
        let disposition: CareFactWriteDisposition

        init(
            logID: UUID,
            subjectID: UUID,
            hygieneType: HygieneType,
            coconutDelta: Int,
            disposition: CareFactWriteDisposition = .active
        ) {
            self.logID = logID
            self.subjectID = subjectID
            self.hygieneType = hygieneType
            self.coconutDelta = coconutDelta
            self.disposition = disposition
        }

        var didWriteFact: Bool {
            disposition.didWriteFact
        }

        var allowsDerivedEffects: Bool {
            disposition.allowsDerivedEffects
        }
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
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            let log = PetHygieneLog(date: date, type: type, pet: nil, executorId: executorId)
            return (
                HygieneRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    hygieneType: type,
                    coconutDelta: 0,
                    disposition: .noOp
                ),
                (0, 0),
                log
            )
        }
        let log = PetHygieneLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        context.safeSave()

        guard disposition.allowsDerivedEffects else {
            return (
                HygieneRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    hygieneType: type,
                    coconutDelta: 0,
                    disposition: disposition
                ),
                (0, 0),
                log
            )
        }
        let reward = dependencies.economy.awardCareAction(
            type: .care(type: type),
            pet: pet,
            context: context,
            quality: .none,
            executorId: executorId
        )
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
        recordHealthFact(
            pet: pet,
            type: type,
            note: note,
            context: context,
            executorId: executorId,
            date: date,
            dependencies: providedDependencies
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordHealthFact(
        pet: Pet,
        type: HealthLogType,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date(),
        dependencies providedDependencies: CareEventServiceDependencies? = nil
    ) -> (result: HealthRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHealthLog?) {
        let dependencies = providedDependencies ?? .live()
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.writesFact else {
            return (
                HealthRecordResult(
                    logID: nil,
                    subjectID: pet.id,
                    healthType: type,
                    coconutDelta: 0,
                    disposition: .noOp
                ),
                (0, 0),
                nil
            )
        }
        let log = PetHealthLog(date: date, type: type, note: note, pet: pet, executorId: executorId)
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        context.safeSave()

        guard disposition.allowsDerivedEffects else {
            return (
                HealthRecordResult(
                    logID: log.id,
                    subjectID: pet.id,
                    healthType: type,
                    coconutDelta: 0,
                    disposition: disposition
                ),
                (0, 0),
                log
            )
        }
        let reward = dependencies.economy.awardCareAction(
            type: .health,
            pet: pet,
            context: context,
            quality: .none,
            executorId: executorId
        )
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
        let result = HealthRecordResult(
            logID: log.id,
            subjectID: pet.id,
            healthType: type,
            coconutDelta: dependencies.careLedger.rewardDelta(reward),
            disposition: disposition
        )
        return (result, reward, log)
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
    ) -> PetPottyLog {
        let liveTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: sourcePet)
        guard !liveTargets.isEmpty,
              !CareFactWritePolicy.executorIsRecycled(executorId, context: context) else {
            return PetPottyLog(date: date, type: type, executorId: executorId)
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
