//
//  CareEventService.swift
//  Ohana
//
//  Centralized care/reminder/economy write paths.
//

import Foundation
import SwiftData

enum CareEventService {
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
        foodKind: FeedFoodKind = .dry
    ) -> (humanGot: Int, petGot: Int) {
        recordManualFeedFact(
            pet: pet,
            amountGrams: amountGrams,
            context: context,
            executorId: executorId,
            quality: quality,
            date: date,
            foodKind: foodKind
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
        source: CareLedgerSource = .quickAction
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog) {
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

        QuestManager.shared.recordFirstMeal()
        let reward = CoconutEconomyService.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: source,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            metadataJSON: CareLedgerService.rewardMetadata(reward),
            context: context
        )
        QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
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
                coconutDelta: CareLedgerService.rewardDelta(reward)
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
        treatKind: FeedTreatKind = .other
    ) -> PetCareLog {
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
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: 0,
            context: context
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
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int)? {
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
        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: executorId,
            source: .reminder,
            context: context
        )
        FamilyTaskService.syncCompletedReminder(reminder, completedBy: executorId, context: context)

        if isCatchUp {
            CareLedgerService.recordPetCare(
                log: log,
                pet: pet,
                source: .reminder,
                sourceEventId: event.id.uuidString,
                sourceReminderId: reminder.id.uuidString,
                coconutDelta: 0,
                context: context
            )
            return (0, 0)
        }

        QuestManager.shared.recordFirstMeal()
        let reward = CoconutEconomyService.awardCareAction(type: .feed, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            metadataJSON: CareLedgerService.rewardMetadata(reward),
            context: context
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
        executorId: String? = nil
    ) -> (humanGot: Int, petGot: Int)? {
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
        CareLedgerService.recordReminderState(
            reminder: reminder,
            actionType: "completePlannedCare",
            actorId: executorId,
            source: .reminder,
            context: context
        )
        FamilyTaskService.syncCompletedReminder(reminder, completedBy: executorId, context: context)

        let reward = CoconutEconomyService.awardCareAction(type: .water, pet: pet, context: context)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: .reminder,
            sourceEventId: event.id.uuidString,
            sourceReminderId: reminder.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            metadataJSON: CareLedgerService.rewardMetadata(reward),
            context: context
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
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        recordCareFact(
            pet: pet,
            type: type,
            amountMl: amountMl,
            context: context,
            executorId: executorId,
            reward: reward,
            quality: quality,
            date: date
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
        createsLinkedPottyLog: Bool = false
    ) -> (result: CareRecordResult, reward: (humanGot: Int, petGot: Int), log: PetCareLog, pottyLog: PetPottyLog?) {
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

        let award = CoconutEconomyService.awardCareAction(type: reward, pet: pet, context: context, quality: quality)
        CareLedgerService.recordPetCare(
            log: log,
            pet: pet,
            source: source,
            coconutDelta: CareLedgerService.rewardDelta(award),
            metadataJSON: CareLedgerService.rewardMetadata(award),
            context: context
        )
        if let pottyLog {
            CareLedgerService.recordPetPotty(
                log: pottyLog,
                pet: pet,
                source: source,
                coconutDelta: 0,
                context: context
            )
        }
        QuickActionReminderCompletionSyncService.completeNearestPetCareReminder(
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
                coconutDelta: CareLedgerService.rewardDelta(award)
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
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetPottyLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = CoconutEconomyService.awardCareAction(type: .potty(isLitter: false), pet: pet, context: context)
        CareLedgerService.recordPetPotty(
            log: log,
            pet: pet,
            source: .quickAction,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            metadataJSON: CareLedgerService.rewardMetadata(reward),
            context: context
        )
        QuickActionReminderCompletionSyncService.completeNearestPetPottyReminder(
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
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        recordHygieneFact(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            date: date
        ).reward
    }

    @discardableResult
    @MainActor
    static func recordHygieneFact(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String? = nil,
        date: Date = Date()
    ) -> (result: HygieneRecordResult, reward: (humanGot: Int, petGot: Int), log: PetHygieneLog) {
        let log = PetHygieneLog(date: date, type: type, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = CoconutEconomyService.awardCareAction(type: .care(type: type), pet: pet, context: context)
        let metadataJSON = CareLedgerService.rewardMetadata(reward)
        CareLedgerService.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .hygiene,
            actionType: type.rawValue,
            source: .quickAction,
            legacyModelName: "PetHygieneLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            metadataJSON: metadataJSON,
            context: context
        )
        CareLedgerService.syncOasisTreeEnergyIfNeeded(metadataJSON: metadataJSON, context: context)
        QuickActionReminderCompletionSyncService.completeNearestPetHygieneReminder(
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
            coconutDelta: CareLedgerService.rewardDelta(reward)
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
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let log = PetHealthLog(date: date, type: type, note: note, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()

        let reward = CoconutEconomyService.awardCareAction(type: .health, pet: pet, context: context)
        let metadataJSON = CareLedgerService.rewardMetadata(reward)
        CareLedgerService.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .health,
            actionType: type.rawValue,
            note: note,
            source: .quickAction,
            legacyModelName: "PetHealthLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: CareLedgerService.rewardDelta(reward),
            metadataJSON: metadataJSON,
            context: context
        )
        CareLedgerService.syncOasisTreeEnergyIfNeeded(metadataJSON: metadataJSON, context: context)
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
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordManualFeed(
                pet: sourcePet,
                amountGrams: totalGrams,
                context: context,
                executorId: executorId,
                quality: quality,
                date: date,
                foodKind: foodKind
            )
        }

        let stockOwner = stockOwnerPet(for: liveTargets, preferred: sourcePet, foodKind: foodKind, context: context)
        QuestManager.shared.recordFirstMeal()
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
            context: context
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
        date: Date = Date()
    ) -> (humanGot: Int, petGot: Int) {
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordCare(
                pet: sourcePet,
                type: .watering,
                amountMl: totalMl,
                context: context,
                executorId: executorId,
                reward: .water,
                date: date
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
            context: context
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
        isFullChange: Bool = false
    ) -> (humanGot: Int, petGot: Int) {
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordCare(
                pet: sourcePet,
                type: .litter,
                context: context,
                executorId: executorId,
                reward: .potty(isLitter: true),
                date: date
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
            context: context
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
        source: CareLedgerSource = .quickAction
    ) -> (humanGot: Int, petGot: Int) {
        let liveTargets = normalizedTargets(targets, fallback: sourcePet)
        guard liveTargets.count > 1 else {
            return recordCare(
                pet: sourcePet,
                type: type,
                context: context,
                executorId: executorId,
                reward: reward,
                quality: quality,
                date: date
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
            context: context
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
        source: CareLedgerSource = .detail
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
            context: context
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
        source: CareLedgerSource = .quickAction
    ) -> SharedPetActionResult {
        let reward = QuestManager.OhanaActionType.walk(distanceMeters: distanceMeters)
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
            context: context
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
        date: Date = Date()
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
            context: context
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

enum CalendarTaskCompletionSyncService {
    private static let calendarSource = CareLedgerSource.calendar.rawValue

    @MainActor
    static func syncPetTask(
        event: Event,
        occurrenceDate: Date,
        isCompleted: Bool,
        pets: [Pet],
        context: ModelContext,
        executorId: String?
    ) {
        guard event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet",
              let pet = pets.first(where: { $0.id.uuidString == event.relatedEntityId }) else { return }

        if !isCompleted {
            deleteCalendarGeneratedRecords(event: event, occurrenceDate: occurrenceDate, context: context)
            return
        }
        guard calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context).isEmpty else { return }

        let occurredAt = occurrenceTimestamp(for: event, occurrenceDate: occurrenceDate)
        if let careType = careType(for: event) {
            insertCareLog(
                pet: pet,
                event: event,
                careType: careType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                executorId: executorId,
                context: context
            )
        } else if let pottyType = pottyType(for: event) {
            insertPottyLog(
                pet: pet,
                event: event,
                pottyType: pottyType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                executorId: executorId,
                context: context
            )
        } else if let hygieneType = hygieneType(for: event) {
            insertHygieneLog(
                pet: pet,
                event: event,
                hygieneType: hygieneType,
                occurredAt: occurredAt,
                occurrenceDate: occurrenceDate,
                executorId: executorId,
                context: context
            )
        }
    }

    @MainActor
    private static func insertCareLog(
        pet: Pet,
        event: Event,
        careType: CareType,
        occurredAt: Date,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext
    ) {
        let amountGrams = careType == .feeding ? CareEventService.feedAmount(from: event, fallback: pet.dailyPortionGrams) : 0
        let amountMl = careType == .watering ? 250.0 : 0
        let log = PetCareLog(
            date: occurredAt,
            type: careType,
            amountGrams: amountGrams,
            amountMl: amountMl,
            note: noteMarker(for: event, occurrenceDate: occurrenceDate, careType: careType),
            foodKind: event.foodKind,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        context.safeSave()
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            eventKind: .care,
            actionType: careType.rawValue,
            amountValue: careType == .feeding ? amountGrams : amountMl,
            amountUnit: careType == .feeding ? "g" : (careType == .watering ? "ml" : ""),
            legacyModelName: "PetCareLog",
            legacyModelId: log.id.uuidString,
            context: context
        )
    }

    @MainActor
    private static func insertPottyLog(
        pet: Pet,
        event: Event,
        pottyType: PottyType,
        occurredAt: Date,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext
    ) {
        let log = PetPottyLog(date: occurredAt, type: pottyType, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            eventKind: .potty,
            actionType: pottyType.rawValue,
            legacyModelName: "PetPottyLog",
            legacyModelId: log.id.uuidString,
            context: context
        )
    }

    @MainActor
    private static func insertHygieneLog(
        pet: Pet,
        event: Event,
        hygieneType: HygieneType,
        occurredAt: Date,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext
    ) {
        let log = PetHygieneLog(date: occurredAt, type: hygieneType, pet: pet, executorId: executorId)
        context.insert(log)
        context.safeSave()
        recordCalendarLedger(
            occurredAt: occurredAt,
            executorId: executorId,
            pet: pet,
            event: event,
            occurrenceDate: occurrenceDate,
            eventKind: .hygiene,
            actionType: hygieneType.rawValue,
            legacyModelName: "PetHygieneLog",
            legacyModelId: log.id.uuidString,
            context: context
        )
    }

    @MainActor
    private static func recordCalendarLedger(
        occurredAt: Date,
        executorId: String?,
        pet: Pet,
        event: Event,
        occurrenceDate: Date,
        eventKind: CareLedgerEventKind,
        actionType: String,
        amountValue: Double = 0,
        amountUnit: String = "",
        legacyModelName: String,
        legacyModelId: String,
        context: ModelContext
    ) {
        CareLedgerService.record(
            occurredAt: occurredAt,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: eventKind,
            actionType: actionType,
            amountValue: amountValue,
            amountUnit: amountUnit,
            note: event.title,
            source: .calendar,
            sourceEventId: event.id.uuidString,
            legacyModelName: legacyModelName,
            legacyModelId: legacyModelId,
            metadataJSON: occurrenceMetadata(for: occurrenceDate),
            context: context
        )
    }

    @MainActor
    private static func deleteCalendarGeneratedRecords(event: Event, occurrenceDate: Date, context: ModelContext) {
        let ledgers = calendarLedgerEntries(event: event, occurrenceDate: occurrenceDate, context: context)
        for ledger in ledgers {
            deleteLegacyModel(name: ledger.legacyModelName, idString: ledger.legacyModelId, context: context)
            context.delete(ledger)
        }
        if !ledgers.isEmpty { context.safeSave() }
    }

    @MainActor
    private static func deleteLegacyModel(name: String?, idString: String?, context: ModelContext) {
        guard let name, let idString, let id = UUID(uuidString: idString) else { return }
        switch name {
        case "PetCareLog":
            var descriptor = FetchDescriptor<PetCareLog>(predicate: #Predicate<PetCareLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = try? context.fetch(descriptor).first { context.delete(model) }
        case "PetPottyLog":
            var descriptor = FetchDescriptor<PetPottyLog>(predicate: #Predicate<PetPottyLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = try? context.fetch(descriptor).first { context.delete(model) }
        case "PetHygieneLog":
            var descriptor = FetchDescriptor<PetHygieneLog>(predicate: #Predicate<PetHygieneLog> { $0.id == id })
            descriptor.fetchLimit = 1
            if let model = try? context.fetch(descriptor).first { context.delete(model) }
        default:
            return
        }
    }

    @MainActor
    private static func calendarLedgerEntries(event: Event, occurrenceDate: Date, context: ModelContext) -> [CareLedgerEvent] {
        let eventId = event.id.uuidString
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { $0.sourceEventId == eventId }
        )
        descriptor.fetchLimit = 20
        let key = occurrenceKey(for: occurrenceDate)
        return ((try? context.fetch(descriptor)) ?? []).filter {
            $0.source == calendarSource && $0.metadataJSON.contains("\"occurrence\":\"\(key)\"")
        }
    }

    private static func occurrenceTimestamp(for event: Event, occurrenceDate: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(occurrenceDate) { return Date() }
        if event.isAllDay { return calendar.startOfDay(for: occurrenceDate) }
        return Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
    }

    private static func noteMarker(for event: Event, occurrenceDate: Date, careType: CareType) -> String {
        let key = occurrenceKey(for: occurrenceDate)
        if careType == .feeding {
            return "\(PetCareLog.plannedFeedNotePrefix)\(event.id.uuidString):calendar:\(key)"
        }
        return "ohana_calendar_event:\(event.id.uuidString):\(key)"
    }

    private static func occurrenceMetadata(for occurrenceDate: Date) -> String {
        "{\"occurrence\":\"\(occurrenceKey(for: occurrenceDate))\"}"
    }

    private static func occurrenceKey(for occurrenceDate: Date) -> String {
        Event.occurrenceStorageKey(for: occurrenceDate)
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    private static func careType(for event: Event) -> CareType? {
        let text = normalizedText(for: event)
        if text.contains("换水") || text.contains("water change") { return .waterChange }
        if text.contains("滤") || text.contains("filter") { return .filterClean }
        if text.contains("猫砂") || text.contains("铲") || event.eventType == EventType.litterBox.rawValue { return .litter }
        if text.contains("喂水") || text.contains("喝水") || text.contains("饮水") || text.contains("drink") { return .watering }
        if event.eventType == EventType.foodChange.rawValue || text.contains("喂") || text.contains("feed") || text.contains("吃") { return .feeding }
        if text.contains("逗") || text.contains("陪玩") || text.contains("play") { return .play }
        return nil
    }

    private static func pottyType(for event: Event) -> PottyType? {
        let text = normalizedText(for: event)
        if text.contains("便") || text.contains("potty") || text.contains("poop") { return .perfectPoop }
        return nil
    }

    private static func hygieneType(for event: Event) -> HygieneType? {
        let text = normalizedText(for: event)
        guard event.eventType == EventType.grooming.rawValue
                || text.contains("洗") || text.contains("澡") || text.contains("刷牙")
                || text.contains("剪") || text.contains("梳") || text.contains("清耳")
                || text.contains("groom") || text.contains("bath") else { return nil }
        if text.contains("刷牙") || text.contains("teeth") { return .teeth }
        if text.contains("剪") || text.contains("nail") { return .nails }
        if text.contains("耳") || text.contains("ear") { return .ears }
        if text.contains("梳") || text.contains("brush") { return .brushing }
        return .bath
    }
}

enum ReminderCompletionService {
    @MainActor
    static func complete(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        reminder.statusEnum = .completed
        reminder.completedAt = Date()
        reminder.completedBy = humanId ?? ""
        reminder.event?.setOccurrenceMarkedComplete(true, on: reminder.scheduledAt)
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "complete", actorId: humanId, source: .service, context: context)
        FamilyTaskService.syncCompletedReminder(reminder, completedBy: humanId, context: context)
    }

    @MainActor
    static func skip(_ reminder: Reminder, by humanId: String?, context: ModelContext) {
        reminder.statusEnum = .skipped
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        OhanaNotifications.current.cancel(notificationId: reminder.notificationId)
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "skip", actorId: humanId, source: .service, context: context)
    }

    @MainActor
    static func reopen(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.event?.setOccurrenceMarkedComplete(false, on: reminder.scheduledAt)
        if reschedule {
            Task { @MainActor in
                await ReminderSchedulingService.scheduleIfNeeded(reminder: reminder, context: context, source: .service)
            }
        }
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "reopen", actorId: humanId, source: .service, context: context)
        FamilyTaskService.syncReopenedReminder(reminder, context: context)
    }

    @MainActor
    static func snoozeOneDay(_ reminder: Reminder, by humanId: String?, context: ModelContext, reschedule: Bool = true) {
        reminder.statusEnum = .pending
        reminder.completedAt = nil
        reminder.completedBy = humanId ?? ""
        reminder.scheduledAt = Calendar.current.date(byAdding: .day, value: 1, to: reminder.scheduledAt)
            ?? Date().addingTimeInterval(86_400)
        if reschedule {
            Task { @MainActor in
                await ReminderSchedulingService.cancelAndReschedule(reminder: reminder, context: context, source: .service)
            }
        }
        context.safeSave()
        CareLedgerService.recordReminderState(reminder: reminder, actionType: "snoozeOneDay", actorId: humanId, source: .service, context: context)
    }
}

enum QuickActionReminderCompletionSyncService {
    @discardableResult
    @MainActor
    static func completeNearestPetCareReminder(
        pet: Pet,
        type: CareType,
        context: ModelContext,
        executorId: String?,
        now: Date = Date()
    ) -> Reminder? {
        completeNearestPetReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: now
        ) { event in
            matchesCare(event, type: type)
        }
    }

    @discardableResult
    @MainActor
    static func completeNearestPetPottyReminder(
        pet: Pet,
        context: ModelContext,
        executorId: String?,
        now: Date = Date()
    ) -> Reminder? {
        completeNearestPetReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: now
        ) { event in
            matchesAny(normalizedText(for: event), [
                "便", "尿", "potty", "poop", "pee", "kot", "urin"
            ])
        }
    }

    @discardableResult
    @MainActor
    static func completeNearestPetHygieneReminder(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        now: Date = Date()
    ) -> Reminder? {
        completeNearestPetReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: now
        ) { event in
            matchesHygiene(event, type: type)
        }
    }

    @discardableResult
    @MainActor
    private static func completeNearestPetReminder(
        pet: Pet,
        context: ModelContext,
        executorId: String?,
        now: Date,
        matches: (Event) -> Bool
    ) -> Reminder? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let catchUpStart = calendar.date(byAdding: .day, value: -30, to: start) ?? start
        let pending = ReminderStatus.pending.rawValue
        let failed = ReminderStatus.failed.rawValue
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.scheduledAt >= catchUpStart &&
                reminder.scheduledAt < end &&
                (reminder.status == pending || reminder.status == failed)
            },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        descriptor.fetchLimit = 96

        let reminders = (try? context.fetch(descriptor)) ?? []
        let petId = pet.id.uuidString
        let matched = reminders.filter { reminder in
            guard let event = reminder.event,
                  isPetEvent(event, petId: petId) else { return false }
            return matches(event)
        }
        guard !matched.isEmpty else { return nil }

        let due = matched.filter { $0.scheduledAt <= now }
        let selected = due.max { $0.scheduledAt < $1.scheduledAt }
            ?? matched.min { $0.scheduledAt < $1.scheduledAt }
        guard let selected else { return nil }
        ReminderCompletionService.complete(selected, by: executorId, context: context)
        return selected
    }

    private static func isPetEvent(_ event: Event, petId: String) -> Bool {
        let type = event.relatedEntityType.lowercased()
        return (type == EntityKind.pet.rawValue.lowercased() || type == "pet" || type == WaterPlanWriter.entityType.lowercased()) &&
            event.relatedEntityId == petId
    }

    private static func matchesCare(_ event: Event, type: CareType) -> Bool {
        let text = normalizedText(for: event)
        switch type {
        case .feeding:
            return event.eventType == EventType.foodChange.rawValue ||
                matchesAny(text, ["喂食", "喂", "吃", "粮", "feed", "food", "meal", "futter", "fütter"])
        case .watering:
            return matchesAny(text, ["喂水", "喝水", "饮水", "water", "drink", "wasser"])
        case .litter:
            return event.eventType == EventType.litterBox.rawValue ||
                matchesAny(text, ["铲", "猫砂", "litter", "scoop", "toilet", "klo"])
        case .waterChange:
            return matchesAny(text, ["换水", "water change", "wasserwechsel"])
        case .filterClean:
            return matchesAny(text, ["滤", "filter"])
        case .cageCleaning:
            return matchesAny(text, ["清笼", "鸟笼", "cage", "käfig"])
        case .freeFlight:
            return matchesAny(text, ["放飞", "free flight", "freiflug"])
        case .misting:
            return matchesAny(text, ["保湿", "喷水", "mist", "spray", "befeuchten"])
        case .substrateChange:
            return matchesAny(text, ["垫材", "substrate", "substrat"])
        case .play:
            return matchesAny(text, ["陪玩", "逗", "play", "spielen"])
        }
    }

    private static func matchesHygiene(_ event: Event, type: HygieneType) -> Bool {
        let text = normalizedText(for: event)
        let isGrooming = event.eventType == EventType.grooming.rawValue ||
            matchesAny(text, ["护理", "groom", "pflege", "洗", "刷", "剪", "耳", "梳"])
        guard isGrooming else { return false }
        switch type {
        case .teeth:
            return matchesAny(text, ["刷牙", "teeth", "tooth", "zahn"])
        case .nails:
            return matchesAny(text, ["剪甲", "剪", "nail", "claw", "kralle"])
        case .ears:
            return matchesAny(text, ["清耳", "耳", "ear", "ohr"])
        case .brushing:
            return matchesAny(text, ["梳", "brush", "comb", "bürst"])
        case .bath:
            return matchesAny(text, ["洗", "澡", "bath", "shower", "bad"])
        }
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    private static func matchesAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }
}

enum CoconutEconomyService {
    @discardableResult
    @MainActor
    static func awardCareAction(
        type: QuestManager.OhanaActionType,
        pet: Pet?,
        context: ModelContext,
        quality: QuestManager.QualityBonus = .none
    ) -> (humanGot: Int, petGot: Int) {
        let reward = QuestManager.shared.awardAction(type: type, pet: pet, context: context, quality: quality)
        OasisUpgradeRewardService.rewardFeaturedCritterFromCare(type: type, context: context)
        return reward
    }

    @discardableResult
    @MainActor
    static func awardSharedCareAction(
        type: QuestManager.OhanaActionType,
        pets: [Pet],
        context: ModelContext,
        quality: QuestManager.QualityBonus = .none,
        title: String? = nil
    ) -> (humanGot: Int, petGot: Int) {
        QuestManager.shared.awardSharedCareAction(
            type: type,
            pets: pets,
            context: context,
            quality: quality,
            title: title
        )
    }
}

private extension CareEventService {
    @MainActor
    static func normalizedTargets(_ targets: [Pet], fallback: Pet) -> [Pet] {
        let candidates = targets.isEmpty ? [fallback] : targets
        var seen = Set<UUID>()
        return candidates.filter { pet in
            guard !pet.hasPassedAway, !seen.contains(pet.id) else { return false }
            seen.insert(pet.id)
            return true
        }
    }

    @MainActor
    static func stockOwnerPet(for targets: [Pet], preferred: Pet, foodKind: FeedFoodKind, context: ModelContext) -> Pet {
        let records = (try? context.fetch(FetchDescriptor<PetFoodRecord>())) ?? []
        if FeedStockCalculator.activeStockRecord(for: preferred, foodKind: foodKind, foodRecords: records) != nil {
            return preferred
        }
        return targets.first { FeedStockCalculator.activeStockRecord(for: $0, foodKind: foodKind, foodRecords: records) != nil } ?? preferred
    }

    @MainActor
    static func recordSharedCareLedger(
        logs: [(Pet, PetCareLog)],
        reward: (humanGot: Int, petGot: Int),
        context: ModelContext
    ) {
        for (index, pair) in logs.enumerated() {
            CareLedgerService.recordPetCare(
                log: pair.1,
                pet: pair.0,
                source: .quickAction,
                coconutDelta: index == 0 ? CareLedgerService.rewardDelta(reward) : 0,
                metadataJSON: index == 0 ? CareLedgerService.rewardMetadata(reward) : "",
                context: context
            )
        }
    }
}
