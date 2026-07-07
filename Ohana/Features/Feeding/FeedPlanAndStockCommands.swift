//
//  FeedPlanAndStockCommands.swift
//  Ohana
//

import Foundation
import SwiftData

enum FeedCommandPersistenceError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                return L10n().tr(
                    zh: "保存喂食数据失败：\(reason)",
                    en: "Failed to save feeding data: \(reason)",
                    de: "Fütterungsdaten konnten nicht gespeichert werden: \(reason)"
                )
            }
            return L10n().tr(
                zh: "保存喂食数据失败，请重试。",
                en: "Failed to save feeding data. Please try again.",
                de: "Fütterungsdaten konnten nicht gespeichert werden. Bitte erneut versuchen."
            )
        }
    }
}

enum FeedCommandPersistence {
    @discardableResult
    nonisolated static func save(
        context: ModelContext,
        rollbackOnFailure: Bool = true
    ) throws -> ModelContextSaveResult {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            if rollbackOnFailure {
                context.rollback()
            }
            throw FeedCommandPersistenceError.persistenceFailed(saveResult.errorDescription)
        }
        return saveResult
    }

    @discardableResult
    nonisolated static func saveDerived(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }
}

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
    let events: [Event]
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
    ) throws -> SaveFeedPlanCommandResult {
        let normalizedTargets = SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
        guard !normalizedTargets.isEmpty else {
            return SaveFeedPlanCommandResult(
                mode: FeedOperatingMode.resolved(pet: pet, allEvents: allEvents),
                targetCount: 0,
                events: allEvents,
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
            let result = try FeedingPlanWriter.replacePlan(
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
                try FeedingPlanWriter.deletePlan(
                    pet: target,
                    kind: .autoFeeder,
                    allEvents: latestEvents,
                    context: context
                )
                latestEvents = FeedCommandFetch.latestEvents(context: context, fallback: latestEvents)
            }

            if kind == .manualReminder {
                planReminders.append(contentsOf: result.reminders)
            } else {
                try FeedingPlanWriter.deactivateManualReminderOperations(
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
            SetFeedModeCommand.run(targetMode, pet: target)
            stockReminders.append(contentsOf: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: target,
                allEvents: latestEvents,
                context: context
            ))
        }

        latestEvents = FeedCommandFetch.latestEvents(context: context, fallback: latestEvents)
        return SaveFeedPlanCommandResult(
            mode: targetMode,
            targetCount: normalizedTargets.count,
            events: latestEvents,
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
    ) throws -> SaveFoodStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        let careLedger = providedCareLedger ?? CareLedgerService()
        let savedRecord = try FeedingPlanWriter.saveFoodPurchase(
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
        try syncExpenseIfNeeded(
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
    ) throws {
        if let amount, amount > 0 {
            let existingExpense = previousExpenseId.flatMap { FeedStockExpenseLink.fetchExpense(id: $0, context: context) }
            let actor = CareFactWritePolicy.executorResolution(
                requestedExecutorId: payerId,
                context: context,
                logPrefix: "SaveFoodStockCommand.syncExpenseIfNeeded"
            )
            let intent = DomainCareFactCreateIntent(
                kind: .expense(
                    amount: amount,
                    category: .food,
                    note: note,
                    sharedSessionId: ""
                ),
                occurredAt: date,
                executorId: payerId,
                source: .userCommand
            )
            guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                pet: pet,
                intent: intent,
                context: context,
                logPrefix: "SaveFoodStockCommand.syncExpenseIfNeeded",
                actorOverride: actor
            ) else { return }
            let expense = DomainCareFactWriter.upsertExpenseLog(
                plan: write,
                existing: existingExpense,
                context: context
            )
            FeedStockExpenseLink.applyExpenseLink(to: record, expenseId: expense.id)
            CloudSyncMutationRecorder.markModified(record, context: context, modifiedAt: date)
            try FeedCommandPersistence.save(context: context)
            try syncExpenseLedger(
                expense: expense,
                pet: pet,
                note: note,
                context: context,
                careLedger: careLedger,
                write: write
            )
        } else if let previousExpenseId {
            FeedStockExpenseLink.applyExpenseLink(to: record, expenseId: previousExpenseId)
            CloudSyncMutationRecorder.markModified(record, context: context)
            try FeedCommandPersistence.save(context: context)
        }
    }

    @MainActor
    private static func syncExpenseLedger(
        expense: PetExpenseLog,
        pet: Pet,
        note: String,
        context: ModelContext,
        careLedger: CareLedgerRecording,
        write: AuthorizedDomainCareFactWrite
    ) throws {
        var saveFailure: Error?
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            if let ledger = existingExpenseLedger(expenseID: expense.id, context: context) {
                ledger.occurredAt = expense.date
                ledger.actorKind = actor.effectiveExecutorId == nil ? CareLedgerActorKind.unknown.rawValue : CareLedgerActorKind.human.rawValue
                ledger.actorId = actor.effectiveExecutorId
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
                do {
                    try FeedCommandPersistence.save(context: context)
                } catch {
                    saveFailure = error
                }
                return
            }

            careLedger.record(
                occurredAt: expense.date,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
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
        if let saveFailure {
            throw saveFailure
        }
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
    ) throws -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        guard pet.foodReminderEnabled != enabled || pet.foodReminderAdvanceDays != advanceDays else {
            return FeedStockCommandResult(didChange: false)
        }
        pet.foodReminderEnabled = enabled
        pet.foodReminderAdvanceDays = advanceDays
        CloudSyncMutationRecorder.markModified(pet, context: context)
        try FeedCommandPersistence.save(context: context)
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
    ) throws -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        _ = try FeedingPlanWriter.correctFoodStock(
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
    ) throws -> FeedStockCommandResult {
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
        try FeedCommandPersistence.save(context: context)
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
    ) throws -> FeedStockCommandResult {
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
    ) throws -> FeedStockCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        CloudSyncMutationRecorder.markDeleted(record, pet: pet, context: context)
        context.delete(record)
        try FeedCommandPersistence.save(context: context)
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
    ) throws -> DeleteFeedPlanCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        try FeedingPlanWriter.deletePlan(pet: pet, kind: kind, allEvents: allEvents, context: context)
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
    static func run(pet: Pet, foodKind: FeedFoodKind, context: ModelContext) throws -> Bool {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return false
        }
        guard pet.mainFoodKind != foodKind else { return false }
        pet.mainFoodKind = foodKind
        CloudSyncMutationRecorder.markModified(pet, context: context)
        try FeedCommandPersistence.save(context: context)
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
    ) throws -> [Reminder] {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return []
        }
        guard FeedOperatingMode.resolved(pet: pet, allEvents: allEvents) == .manualReminder else {
            try FeedingPlanWriter.deactivateManualReminderOperations(
                pet: pet,
                allEvents: allEvents,
                context: context,
                now: now
            )
            return []
        }
        return try FeedingPlanWriter.ensureUpcomingManualReminders(
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
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .care,
            context: context
        ),
            let created = DomainScheduleWriter.createReminder(
                for: event,
                scheduledAt: scheduledAt,
                mutation: mutation,
                context: context
            )
        else {
            return DomainScheduleWriter.makeUnpersistedReminder(event: event, scheduledAt: scheduledAt)
        }
        guard FeedCommandPersistence.saveDerived(context: context) else {
            return DomainScheduleWriter.makeUnpersistedReminder(event: event, scheduledAt: scheduledAt)
        }
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
    ) throws -> Bool {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return false
        }
        try FeedingPlanWriter.deactivateManualReminderOperations(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        try FeedingPlanWriter.deletePlan(
            pet: pet,
            kind: .autoFeeder,
            allEvents: allEvents,
            context: context
        )
        SetFeedModeCommand.run(.manual, pet: pet)
        return true
    }

    @MainActor
    static func activateExistingRule(
        pet: Pet,
        kind: FeedRuleKind,
        allEvents: [Event],
        context: ModelContext
    ) throws -> SwitchFeedModeCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return .noOp
        }
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        let targetEvents = FeedingPlanWriter.planEvents(pet: pet, kind: kind, allEvents: allEvents)
        guard !targetEvents.isEmpty else { return .missingPlan }

        switch kind {
        case .manualReminder:
            try FeedingPlanWriter.deletePlan(
                pet: pet,
                kind: .autoFeeder,
                allEvents: allEvents,
                context: context
            )
            let reminders = try FeedingPlanWriter.ensureUpcomingManualReminders(
                pet: pet,
                allEvents: targetEvents,
                context: context
            )
            SetFeedModeCommand.run(targetMode, pet: pet)
            return .switched(remindersToSchedule: reminders)
        case .autoFeeder:
            try FeedingPlanWriter.deactivateManualReminderOperations(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
            _ = FeedAutoLogMaterializer.materializeDueLogs(
                pet: pet,
                allEvents: targetEvents,
                context: context
            )
            SetFeedModeCommand.run(targetMode, pet: pet)
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
