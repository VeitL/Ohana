//
//  FeedCommands.swift
//  Ohana
//
//  Write-side commands for feeding flows.
//

import Foundation
import SwiftData

struct ManualFeedCommandResult {
    let foodKind: FeedFoodKind
    let grams: Double
    let targetCount: Int
    let affectsStock: Bool
    let stockReminders: [Reminder]
    let didRecord: Bool
}

enum ManualFeedCommand {
    @MainActor
    static func saveSettings(
        pet: Pet,
        foodKind: FeedFoodKind,
        grams: Double,
        defaultEnabled: Bool = true,
        context: ModelContext
    ) {
        pet.mainFoodKind = foodKind
        pet.dailyPortionGrams = defaultEnabled ? grams : 0
        context.safeSave()
    }

    @MainActor
    static func recordManual(
        pet: Pet,
        targets: [Pet],
        grams: Double,
        foodKind: FeedFoodKind,
        saveAsDefault: Bool,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        context: ModelContext,
        executorId: String?
    ) -> ManualFeedCommandResult {
        pet.mainFoodKind = foodKind
        if saveAsDefault {
            pet.dailyPortionGrams = grams
        }

        let quality = QuestManager.QualityBonus.compose(precise: true, hasNote: false, hasPhoto: false)
        let normalizedTargets = targets.isEmpty ? [pet] : targets
        if normalizedTargets.count > 1 {
            _ = CareEventService.recordSharedManualFeed(
                sourcePet: pet,
                targets: normalizedTargets,
                totalGrams: grams,
                foodKind: foodKind,
                context: context,
                executorId: executorId,
                quality: quality
            )
        } else {
            _ = CareEventService.recordManualFeed(
                pet: pet,
                amountGrams: grams,
                context: context,
                executorId: executorId,
                quality: quality,
                foodKind: foodKind
            )
        }

        return ManualFeedCommandResult(
            foodKind: foodKind,
            grams: grams,
            targetCount: normalizedTargets.count,
            affectsStock: FeedStockCalculator.activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords) != nil,
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            ),
            didRecord: true
        )
    }

    @MainActor
    static func completePlanned(
        pet: Pet,
        reminder: Reminder,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        context: ModelContext,
        executorId: String?
    ) -> ManualFeedCommandResult {
        let event = reminder.event
        let foodKind = event?.foodKind ?? pet.mainFoodKind
        let grams = event.map { FeedRuleMetadata.amountGrams(from: $0, fallback: pet.dailyPortionGrams) } ?? pet.dailyPortionGrams
        let reward = CareEventService.completePlannedFeed(
            pet: pet,
            reminder: reminder,
            context: context,
            quality: .precise,
            executorId: executorId
        )
        return ManualFeedCommandResult(
            foodKind: foodKind,
            grams: grams,
            targetCount: 1,
            affectsStock: FeedStockCalculator.activeStockRecord(for: pet, foodKind: foodKind, foodRecords: foodRecords) != nil,
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            ),
            didRecord: reward != nil
        )
    }
}

struct OverviewQuickCareCommandResult: Equatable {
    let petID: UUID
    let action: String
    let coconutDelta: Int
}

@MainActor
struct OverviewQuickCareCommandExecutor {
    private let context: ModelContext
    private let revisionCenter: ReadModelRevisionCenter

    init(context: ModelContext) {
        self.init(context: context, revisionCenter: .shared)
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        self.revisionCenter = revisionCenter
    }

    @discardableResult
    func record(
        pet: Pet,
        actionType: String,
        amount: Double,
        saveAsDefault: Bool,
        executorId: String?
    ) -> OverviewQuickCareCommandResult {
        if actionType == "water" {
            let waterAmount = amount > 0 ? amount : 200
            let result = QuickWaterCommandExecutor(context: context).recordWater(
                pet: pet,
                targets: [pet],
                amountMl: waterAmount,
                executorId: executorId
            )
            publish(petID: pet.id, action: "water", note: "overview.quick.water")
            return OverviewQuickCareCommandResult(
                petID: pet.id,
                action: "water",
                coconutDelta: result.coconutDelta
            )
        }

        let grams = amount
        _ = ManualFeedCommand.recordManual(
            pet: pet,
            targets: [pet],
            grams: grams,
            foodKind: pet.mainFoodKind,
            saveAsDefault: saveAsDefault,
            foodRecords: [],
            allEvents: [],
            context: context,
            executorId: executorId
        )
        publish(petID: pet.id, action: "feed", note: "overview.quick.feed")
        return OverviewQuickCareCommandResult(
            petID: pet.id,
            action: "feed",
            coconutDelta: 0
        )
    }

    private func publish(petID: UUID, action: String, note: String) {
        revisionCenter.publish(
            DomainMutationResult(
                command: .quickCare(entityID: petID, action: action),
                affectedEntityIDs: [petID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }
}

struct TreatFeedCommandResult {
    let grams: Double
}

enum TreatFeedCommand {
    @MainActor
    static func record(
        pet: Pet,
        grams: Double,
        treatKind: FeedTreatKind,
        context: ModelContext,
        executorId: String?
    ) -> TreatFeedCommandResult {
        _ = CareEventService.recordTreatFeed(
            pet: pet,
            amountGrams: grams,
            context: context,
            executorId: executorId,
            treatKind: treatKind
        )
        return TreatFeedCommandResult(grams: grams)
    }
}

struct SaveFeedPlanCommandResult {
    let mode: FeedOperatingMode
    let targetCount: Int
    let planReminders: [Reminder]
    let stockReminders: [Reminder]
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
        let normalizedTargets = targets.isEmpty ? [pet] : targets
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        var latestEvents = allEvents
        var planReminders: [Reminder] = []
        var stockReminders: [Reminder] = []

        for target in normalizedTargets {
            let result = FeedingPlanWriter.replacePlan(
                pet: target,
                draft: draft,
                allEvents: latestEvents,
                context: context
            )
            latestEvents = latestEvents
                .filter { existing in
                    switch kind {
                    case .manualReminder:
                        return !FeedRuleMetadata.isManualReminderEvent(existing, pet: target)
                    case .autoFeeder:
                        return !FeedRuleMetadata.isAutoFeederEvent(existing, pet: target)
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
            stockReminders: stockReminders
        )
    }
}

struct FeedStockCommandResult {
    let stockReminders: [Reminder]
}

struct SaveFoodStockCommandResult {
    let record: PetFoodRecord
    let stockReminders: [Reminder]
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
        expenseNote: String
    ) -> SaveFoodStockCommandResult {
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
        syncExpenseIfNeeded(
            pet: pet,
            record: savedRecord,
            previousExpenseId: previousExpenseId,
            amount: expenseAmount,
            payerId: expensePayerId,
            date: expenseDate,
            note: expenseNote,
            context: context
        )
        return SaveFoodStockCommandResult(
            record: savedRecord,
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: allEvents,
                context: context
            )
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
        context: ModelContext
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
            record.notes = FeedStockExpenseLink.notesWithExpenseLink(record.notes, expenseId: expense.id)
            context.safeSave()
            if createdExpense {
                CareLedgerService.record(
                    occurredAt: expense.date,
                    actorKind: payerId == nil ? .unknown : .human,
                    actorId: payerId,
                    subjectKind: .pet,
                    subjectId: pet.id.uuidString,
                    eventKind: .expense,
                    actionType: ExpenseCategory.food.rawValue,
                    amountValue: amount,
                    amountUnit: "currency",
                    note: note,
                    source: .detail,
                    legacyModelName: "PetExpenseLog",
                    legacyModelId: expense.id.uuidString,
                    context: context,
                    save: true
                )
            }
        } else if let previousExpenseId {
            record.notes = FeedStockExpenseLink.notesWithExpenseLink(record.notes, expenseId: previousExpenseId)
            context.safeSave()
        }
    }
}

enum FeedStockExpenseLink {
    static func expenseId(from notes: String) -> UUID? {
        let prefix = "stockExpense:"
        return notes
            .components(separatedBy: "\n")
            .compactMap { line -> UUID? in
                guard line.hasPrefix(prefix) else { return nil }
                return UUID(uuidString: String(line.dropFirst(prefix.count)))
            }
            .first
    }

    static func notesWithExpenseLink(_ notes: String, expenseId: UUID) -> String {
        let visible = notes
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("stockExpense:") }
            .joined(separator: "\n")
        return [visible, "stockExpense:\(expenseId.uuidString)"]
            .filter { !$0.isEmpty }
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
        return try? context.fetch(descriptor).first
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
        pet.foodReminderEnabled = enabled
        pet.foodReminderAdvanceDays = advanceDays
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
        log.amountGrams = grams
        log.date = date
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
        context.delete(log)
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
    static func deleteFoodRecord(
        _ record: PetFoodRecord,
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) -> FeedStockCommandResult {
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
        FeedingPlanWriter.deletePlan(pet: pet, kind: kind, allEvents: allEvents, context: context)
        let refreshedEvents = FeedCommandFetch.latestEvents(context: context, fallback: allEvents)
        return DeleteFeedPlanCommandResult(
            shouldSwitchToManual: (kind == .manualReminder && activeMode == .manualReminder) ||
                (kind == .autoFeeder && activeMode == .autoFeeder),
            stockReminders: FeedingPlanWriter.rebuildFoodStockReminders(
                pet: pet,
                allEvents: refreshedEvents,
                context: context
            )
        )
    }
}

enum SetMainFoodKindCommand {
    @MainActor
    static func run(pet: Pet, foodKind: FeedFoodKind, context: ModelContext) {
        guard pet.mainFoodKind != foodKind else { return }
        pet.mainFoodKind = foodKind
        context.safeSave()
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
}

enum SwitchFeedModeCommand {
    @MainActor
    static func switchToManual(
        pet: Pet,
        allEvents: [Event],
        context: ModelContext
    ) {
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
    }

    @MainActor
    static func activateExistingRule(
        pet: Pet,
        kind: FeedRuleKind,
        allEvents: [Event],
        context: ModelContext
    ) -> SwitchFeedModeCommandResult {
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
    @MainActor
    static func run(_ mode: FeedOperatingMode, pet: Pet) {
        FeedOperatingMode.set(pet.id, mode: mode)
        switch mode {
        case .manual:
            HomeFeedRecordMode.set(pet.id, mode: .manual)
        case .manualReminder, .autoFeeder:
            HomeFeedRecordMode.set(pet.id, mode: .planned)
        }
    }
}

private enum FeedCommandFetch {
    @MainActor
    static func latestEvents(context: ModelContext, fallback: [Event]) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        return (try? context.fetch(descriptor)) ?? fallback
    }
}
