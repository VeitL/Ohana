//
//  FeedPlanAndStockCommands.swift
//  Ohana
//

import Foundation
import SwiftData

struct TreatFeedCommandResult {
    let grams: Double
    let didRecord: Bool
    let allowsDerivedEffects: Bool
}

enum TreatFeedCommand {
    @MainActor
    static func record(
        pet: Pet,
        grams: Double,
        treatKind: FeedTreatKind,
        context: ModelContext,
        executorId: String?,
        careEvents: CareEventRecording? = nil
    ) -> TreatFeedCommandResult {
        let careEvents = careEvents ?? CareEventService()
        let recorded = careEvents.recordTreatFeedFact(
            pet: pet,
            amountGrams: grams,
            context: context,
            executorId: executorId,
            date: Date(),
            treatKind: treatKind
        )
        return TreatFeedCommandResult(
            grams: grams,
            didRecord: recorded.result.didWriteFact,
            allowsDerivedEffects: recorded.result.allowsDerivedEffects
        )
    }
}

struct SaveFeedPlanCommandResult {
    let mode: FeedOperatingMode
    let targetCount: Int
    let planReminders: [Reminder]
    let stockReminders: [Reminder]
    let didChange: Bool
}

enum SaveFeedPlanCommand {
    @MainActor
    static func run(
        pet: Pet,
        targets: [Pet],
        kind: FeedRuleKind,
        draft: FeedPlanDraft,
        allEvents: [Event],
        context: ModelContext
    ) -> SaveFeedPlanCommandResult {
        let normalizedTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !normalizedTargets.isEmpty else {
            return SaveFeedPlanCommandResult(
                mode: FeedOperatingMode.resolved(pet: pet, allEvents: allEvents),
                targetCount: 0,
                planReminders: [],
                stockReminders: [],
                didChange: false
            )
        }
        let feedPlanGroupId = normalizedTargets.count > 1 ? UUID().uuidString : ""
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        var latestEvents = allEvents
        var planReminders: [Reminder] = []
        var stockReminders: [Reminder] = []

        for target in normalizedTargets {
            let result = FeedingPlanWriter.replacePlan(
                pet: target,
                draft: draft,
                allEvents: latestEvents,
                context: context,
                feedPlanGroupId: feedPlanGroupId
            )
            latestEvents = latestEvents
                .filter { existing in
                    switch kind {
                    case .manualReminder:
                        !FeedRuleMetadata.isManualReminderEvent(existing, pet: target)
                    case .autoFeeder:
                        !FeedRuleMetadata.isAutoFeederEvent(existing, pet: target)
                    }
                } + result.events

            if kind == .manualReminder {
                FeedingPlanWriter.deletePlan(
                    pet: target,
                    kind: .autoFeeder,
                    allEvents: latestEvents,
                    context: context
                )
                latestEvents = FeedCommandFetch.latestEvents(context: context, fallback: latestEvents)
            }

            SetFeedModeCommand.run(targetMode, pet: target)

            if kind == .manualReminder {
                planReminders.append(contentsOf: result.reminders)
            } else {
                FeedingPlanWriter.deactivateManualReminderOperations(
                    pet: target,
                    allEvents: latestEvents,
                    context: context
                )
                _ = FeedAutoLogMaterializer.materializeDueLogs(
                    pet: target,
                    allEvents: latestEvents,
                    context: context
                )
            }
            stockReminders.append(contentsOf: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: target,
                allEvents: latestEvents,
                context: context
            ))
        }

        return SaveFeedPlanCommandResult(
            mode: targetMode,
            targetCount: normalizedTargets.count,
            planReminders: planReminders,
            stockReminders: stockReminders,
            didChange: true
        )
    }
}

struct FeedStockCommandResult {
    let stockReminders: [Reminder]
    let didChange: Bool
    let allowsDerivedEffects: Bool

    init(
        stockReminders: [Reminder] = [],
        didChange: Bool = true,
        allowsDerivedEffects: Bool? = nil
    ) {
        self.stockReminders = stockReminders
        self.didChange = didChange
        self.allowsDerivedEffects = allowsDerivedEffects ?? didChange
    }

    static let noOp = FeedStockCommandResult(didChange: false, allowsDerivedEffects: false)
}

struct SaveFoodStockCommandResult {
    let record: PetFoodRecord?
    let stockReminders: [Reminder]
    let didChange: Bool
    let allowsDerivedEffects: Bool

    init(
        record: PetFoodRecord?,
        stockReminders: [Reminder] = [],
        didChange: Bool = true,
        allowsDerivedEffects: Bool? = nil
    ) {
        self.record = record
        self.stockReminders = stockReminders
        self.didChange = didChange
        self.allowsDerivedEffects = allowsDerivedEffects ?? didChange
    }

    static let noOp = SaveFoodStockCommandResult(record: nil, didChange: false, allowsDerivedEffects: false)
}

enum SaveFoodStockCommand {
    @MainActor
    static func run(
        pet: Pet,
        brand: String,
        totalGrams: Double,
        purchaseDate: Date?,
        openDate: Date?,
        dailyGrams: Double?,
        foodKind: FeedFoodKind,
        calculationMode: FeedStockCalculationMode = .manualOrPlan,
        reminderEnabled: Bool,
        reminderAdvanceDays: Int,
        executorId: String?,
        allEvents: [Event],
        context: ModelContext,
        recordToUpdate: PetFoodRecord?,
        previousExpenseId: UUID?,
        expenseAmount: Double?,
        expensePayerId: String?,
        expenseDate: Date,
        expenseNote: String,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> SaveFoodStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        let careLedger = providedCareLedger ?? CareLedgerService()
        let savedRecord = FeedingPlanWriter.saveFoodPurchase(
            pet: pet,
            brand: brand,
            totalGrams: totalGrams,
            purchaseDate: purchaseDate,
            openDate: openDate,
            dailyGrams: dailyGrams,
            foodKind: foodKind,
            calculationMode: calculationMode,
            reminderEnabled: reminderEnabled,
            reminderAdvanceDays: reminderAdvanceDays,
            executorId: executorId,
            allEvents: allEvents,
            context: context,
            recordToUpdate: recordToUpdate,
            rebuildReminder: false
        )
        let actor = EconomyRewardOwnerResolver.executorResolution(
            executorId: expensePayerId,
            activeHumanSelection: FeedStockExpenseActiveHumanSelection(currentHumanId: executorId),
            context: context,
            logPrefix: "SaveFoodStockCommand"
        )
        syncExpenseIfNeeded(
            pet: pet,
            record: savedRecord,
            previousExpenseId: previousExpenseId,
            amount: expenseAmount,
            payerId: actor.effectiveExecutorId,
            date: expenseDate,
            note: expenseNote,
            context: context,
            careLedger: careLedger
        )
        return SaveFoodStockCommandResult(
            record: savedRecord,
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            ),
            didChange: true,
            allowsDerivedEffects: true
        )
    }

    @MainActor
    private static func syncExpenseIfNeeded(
        pet: Pet,
        record: PetFoodRecord,
        previousExpenseId: UUID?,
        amount: Double?,
        payerId: String?,
        date: Date,
        note: String,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        if let amount, amount > 0 {
            let existingExpense = previousExpenseId.flatMap { FeedStockExpenseLink.fetchExpense(id: $0, context: context) }
            let createdExpense = existingExpense == nil
            let expense = existingExpense ?? PetExpenseLog(
                date: date,
                amount: amount,
                category: .food,
                note: note,
                pet: pet,
                executorId: payerId
            )
            if createdExpense {
                context.insert(expense)
            }
            expense.date = date
            expense.amount = amount
            expense.category = ExpenseCategory.food.rawValue
            expense.note = note
            expense.executorId = payerId
            expense.pet = pet
            FeedStockExpenseLink.applyExpenseLink(to: record, expenseId: expense.id)
            CloudSyncMutationRecorder.markModified(expense, context: context, modifiedAt: date)
            CloudSyncMutationRecorder.markModified(record, context: context, modifiedAt: date)
            context.safeSave()
            syncExpenseLedger(
                expense: expense,
                pet: pet,
                payerId: payerId,
                note: note,
                context: context,
                careLedger: careLedger
            )
        } else if let previousExpenseId {
            FeedStockExpenseLink.applyExpenseLink(to: record, expenseId: previousExpenseId)
            CloudSyncMutationRecorder.markModified(record, context: context)
            context.safeSave()
        }
    }

    @MainActor
    private static func syncExpenseLedger(
        expense: PetExpenseLog,
        pet: Pet,
        payerId: String?,
        note: String,
        context: ModelContext,
        careLedger: CareLedgerRecording
    ) {
        if let ledger = existingExpenseLedger(expenseID: expense.id, context: context) {
            ledger.occurredAt = expense.date
            ledger.actorKind = payerId == nil ? CareLedgerActorKind.unknown.rawValue : CareLedgerActorKind.human.rawValue
            ledger.actorId = payerId
            ledger.subjectKind = CareLedgerSubjectKind.pet.rawValue
            ledger.subjectId = pet.id.uuidString
            ledger.eventKind = CareLedgerEventKind.expense.rawValue
            ledger.actionType = ExpenseCategory.food.rawValue
            ledger.amountValue = expense.amount
            ledger.amountUnit = "currency"
            ledger.note = note
            ledger.source = CareLedgerSource.detail.rawValue
            ledger.sourceEventId = nil
            ledger.sourceReminderId = nil
            ledger.legacyModelName = "PetExpenseLog"
            ledger.legacyModelId = expense.id.uuidString
            ledger.coconutDelta = 0
            ledger.rewardLogId = nil
            ledger.privacyFieldRaw = nil
            ledger.metadataJSON = ""
            CloudSyncMutationRecorder.markModified(ledger, context: context, modifiedAt: expense.date)
            context.safeSave()
            return
        }

        careLedger.record(
            occurredAt: expense.date,
            actorKind: payerId == nil ? .unknown : .human,
            actorId: payerId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .expense,
            actionType: ExpenseCategory.food.rawValue,
            amountValue: expense.amount,
            amountUnit: "currency",
            note: note,
            source: .detail,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "PetExpenseLog",
            legacyModelId: expense.id.uuidString,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "",
            context: context,
            save: true
        )
    }

    @MainActor
    private static func existingExpenseLedger(expenseID: UUID, context: ModelContext) -> CareLedgerEvent? {
        let expenseIDString = expenseID.uuidString
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.legacyModelName == "PetExpenseLog" && ledger.legacyModelId == expenseIDString
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "SaveFoodStockCommand failed to fetch stock expense ledger: \(error.localizedDescription)",
                category: "Care"
            )
            return nil
        }
    }
}

private struct FeedStockExpenseActiveHumanSelection: ActiveHumanSelecting {
    let currentHumanId: String?

    var currentHumanIdRaw: String {
        currentHumanId ?? ""
    }
}

enum FeedStockExpenseLink {
    private static let expensePrefix = "stockExpense:"

    static func expenseId(from notes: String) -> UUID? {
        notes
            .components(separatedBy: "\n")
            .compactMap { line -> UUID? in
                guard line.hasPrefix(expensePrefix) else { return nil }
                return UUID(uuidString: String(line.dropFirst(expensePrefix.count)))
            }
            .first
    }

    static func expenseId(for record: PetFoodRecord?) -> UUID? {
        guard let record else { return nil }
        return record.expenseId ?? expenseId(from: record.notes)
    }

    static func applyExpenseLink(to record: PetFoodRecord, expenseId: UUID) {
        record.expenseId = expenseId
        record.notes = notesScrubbingLegacyExpenseLink(record.notes)
    }

    static func notesScrubbingLegacyExpenseLink(_ notes: String) -> String {
        notes
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix(expensePrefix) }
            .joined(separator: "\n")
    }

    @MainActor
    static func fetchExpense(id: UUID, context: ModelContext) -> PetExpenseLog? {
        var descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { expense in
                expense.id == id
            }
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            OhanaLog.warning(
                "FeedStockExpenseLink failed to fetch expense: \(error.localizedDescription)",
                category: "Care"
            )
            return nil
        }
    }
}

enum StockReminderSettingsCommand {
    @MainActor
    static func run(
        pet: Pet,
        enabled: Bool,
        advanceDays: Int,
        allEvents: [Event],
        context: ModelContext
    ) -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        guard pet.foodReminderEnabled != enabled || pet.foodReminderAdvanceDays != advanceDays else {
            return FeedStockCommandResult(didChange: false)
        }
        pet.foodReminderEnabled = enabled
        pet.foodReminderAdvanceDays = advanceDays
        CloudSyncMutationRecorder.markModified(pet, context: context)
        context.safeSave()
        return FeedStockCommandResult(
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
        )
    }
}

enum CorrectStockCommand {
    @MainActor
    static func run(
        pet: Pet,
        record: PetFoodRecord,
        remainingGrams: Double,
        allEvents: [Event],
        context: ModelContext
    ) -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        _ = FeedingPlanWriter.correctFoodStock(
            record: record,
            remainingGrams: remainingGrams,
            allEvents: allEvents,
            context: context,
            rebuildReminder: false
        )
        return FeedStockCommandResult(
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
        )
    }
}

enum FeedRecordCommand {
    @MainActor
    static func updateLog(
        _ log: PetCareLog,
        grams: Double,
        date: Date,
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        let sharedSessionId = log.sharedSessionId
        log.amountGrams = grams
        log.date = date
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        SharedCareSessionMaintenance.reconcileAfterDeletingChild(
            sharedSessionId: sharedSessionId,
            context: context,
            reconciledAt: date
        )
        context.safeSave()
        return FeedStockCommandResult(
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
        )
    }

    @MainActor
    static func deleteLog(
        _ log: PetCareLog,
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        _ = PetCareTrackingCommandService.deleteCareLog(log, pet: pet, context: context)
        return FeedStockCommandResult(
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
        )
    }

    @MainActor
    static func deleteFoodRecord(
        _ record: PetFoodRecord,
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context)
        context.delete(record)
        context.safeSave()
        return FeedStockCommandResult(
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
        )
    }
}

struct DeleteFeedPlanCommandResult {
    let shouldSwitchToManual: Bool
    let stockReminders: [Reminder]
    let didChange: Bool

    init(
        shouldSwitchToManual: Bool,
        stockReminders: [Reminder] = [],
        didChange: Bool = true
    ) {
        self.shouldSwitchToManual = shouldSwitchToManual
        self.stockReminders = stockReminders
        self.didChange = didChange
    }

    static let noOp = DeleteFeedPlanCommandResult(shouldSwitchToManual: false, didChange: false)
}

enum DeleteFeedPlanCommand {
    @MainActor
    static func run(
        pet: Pet,
        kind: FeedRuleKind,
        activeMode: FeedOperatingMode,
        allEvents: [Event],
        context: ModelContext
    ) -> DeleteFeedPlanCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        FeedingPlanWriter.deletePlan(pet: pet, kind: kind, allEvents: allEvents, context: context)
        let refreshedEvents = FeedCommandFetch.latestEvents(context: context, fallback: allEvents)
        return DeleteFeedPlanCommandResult(
            shouldSwitchToManual: (kind == .manualReminder && activeMode == .manualReminder) ||
                (kind == .autoFeeder && activeMode == .autoFeeder),
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: refreshedEvents,
                context: context
            ),
            didChange: true
        )
    }
}

enum SetMainFoodKindCommand {
    @discardableResult
    @MainActor
    static func run(pet: Pet, foodKind: FeedFoodKind, context: ModelContext) -> Bool {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return false
        }
        guard pet.mainFoodKind != foodKind else { return false }
        pet.mainFoodKind = foodKind
        CloudSyncMutationRecorder.markModified(pet, context: context)
        context.safeSave()
        return true
    }
}

struct FeedAutoMaterializeCommandResult {
    let insertedCount: Int
    let stockReminders: [Reminder]
}

enum FeedMaintenanceCommand {
    @MainActor
    static func materializeDueAutoLogs(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) -> FeedAutoMaterializeCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return FeedAutoMaterializeCommandResult(insertedCount: 0, stockReminders: [])
        }
        guard FeedOperatingMode.resolved(pet: pet, allEvents: allEvents) == .autoFeeder else {
            return FeedAutoMaterializeCommandResult(insertedCount: 0, stockReminders: [])
        }
        let inserted = FeedAutoLogMaterializer.materializeDueLogs(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        guard inserted > 0 else {
            return FeedAutoMaterializeCommandResult(insertedCount: 0, stockReminders: [])
        }
        return FeedAutoMaterializeCommandResult(
            insertedCount: inserted,
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: FeedCommandFetch.latestEvents(context: context, fallback: allEvents),
                context: context
            )
        )
    }

    @MainActor
    static func ensureUpcomingPlanReminders(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return []
        }
        guard FeedOperatingMode.resolved(pet: pet, allEvents: allEvents) == .manualReminder else {
            FeedingPlanWriter.deactivateManualReminderOperations(
                pet: pet,
                allEvents: allEvents,
                context: context,
                now: now
            )
            return []
        }
        return FeedingPlanWriter.ensureUpcomingManualReminders(
            pet: pet,
            allEvents: allEvents,
            context: context,
            now: now,
            calendar: calendar
        )
    }

    @MainActor
    static func reminder(for event: Event, scheduledAt: Date, existing: Reminder?, context: ModelContext) -> Reminder {
        if let existing { return existing }
        let created = Reminder(event: event, scheduledAt: scheduledAt)
        context.insert(created)
        context.safeSave()
        return created
    }
}

enum SwitchFeedModeCommandResult {
    case switched(remindersToSchedule: [Reminder])
    case missingPlan
    case noOp
}

enum SwitchFeedModeCommand {
    @discardableResult
    @MainActor
    static func switchToManual(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) -> Bool {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return false
        }
        SetFeedModeCommand.run(.manual, pet: pet)
        FeedingPlanWriter.deactivateManualReminderOperations(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        FeedingPlanWriter.deletePlan(
            pet: pet,
            kind: .autoFeeder,
            allEvents: allEvents,
            context: context
        )
        return true
    }

    @MainActor
    static func activateExistingRule(
        pet: Pet,
        kind: FeedRuleKind,
        allEvents: [Event],
        context: ModelContext
    ) -> SwitchFeedModeCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        let targetEvents = FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents)
        guard !targetEvents.isEmpty else { return .missingPlan }

        SetFeedModeCommand.run(targetMode, pet: pet)
        switch kind {
        case .manualReminder:
            FeedingPlanWriter.deletePlan(
                pet: pet,
                kind: .autoFeeder,
                allEvents: allEvents,
                context: context
            )
            let reminders = FeedingPlanWriter.ensureUpcomingManualReminders(
                pet: pet,
                allEvents: targetEvents,
                context: context
            )
            return .switched(remindersToSchedule: reminders)
        case .autoFeeder:
            FeedingPlanWriter.deactivateManualReminderOperations(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
            _ = FeedAutoLogMaterializer.materializeDueLogs(
                pet: pet,
                allEvents: targetEvents,
                context: context
            )
            return .switched(remindersToSchedule: [])
        }
    }
}

enum SetFeedModeCommand {
    @discardableResult
    @MainActor
    static func run(_ mode: FeedOperatingMode, pet: Pet) -> Bool {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return false
        }

        let currentMode = FeedOperatingMode.stored(for: pet.id)
        let targetHomeMode: HomeFeedRecordMode = mode == .manual ? .manual : .planned
        let currentHomeMode = HomeFeedRecordMode(rawValue: HomeFeedRecordMode.storedRaw(for: pet.id)) ?? .manual
        guard currentMode != mode || currentHomeMode != targetHomeMode else {
            return false
        }

        FeedOperatingMode.set(pet.id, mode: mode)
        HomeFeedRecordMode.set(pet.id, mode: targetHomeMode)
        return true
    }
}
