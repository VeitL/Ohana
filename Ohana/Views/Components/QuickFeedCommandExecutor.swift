//
//  QuickFeedCommandExecutor.swift
//  Ohana
//
//  Write-side and route-scoped data operations for the QuickFeed flow.
//

import Foundation
import SwiftData

@MainActor
struct QuickFeedCommandExecutor {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fullCareLogs(petID: UUID, feedingType: String, fallback: [PetCareLog]) -> [PetCareLog] {
        let descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.type == feedingType && log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? fallback
    }

    func fullFoodRecords(petID: UUID, fallback: [PetFoodRecord]) -> [PetFoodRecord] {
        let descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { record in
                record.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? fallback
    }

    func latestAllEvents(fallback: [Event]) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        return (try? context.fetch(descriptor)) ?? fallback
    }

    func stockExpense(id: UUID) -> PetExpenseLog? {
        FeedStockExpenseLink.fetchExpense(id: id, context: context)
    }

    func saveManualSettings(pet: Pet, foodKind: FeedFoodKind, grams: Double) {
        ManualFeedCommand.saveSettings(
            pet: pet,
            foodKind: foodKind,
            grams: grams,
            context: context
        )
    }

    func recordManual(
        pet: Pet,
        targets: [Pet],
        grams: Double,
        foodKind: FeedFoodKind,
        saveAsDefault: Bool,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        executorId: String?
    ) -> ManualFeedCommandResult {
        ManualFeedCommand.recordManual(
            pet: pet,
            targets: targets,
            grams: grams,
            foodKind: foodKind,
            saveAsDefault: saveAsDefault,
            foodRecords: foodRecords,
            allEvents: allEvents,
            context: context,
            executorId: executorId
        )
    }

    func completePlanned(
        pet: Pet,
        reminder: Reminder,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        executorId: String?
    ) -> ManualFeedCommandResult {
        ManualFeedCommand.completePlanned(
            pet: pet,
            reminder: reminder,
            foodRecords: foodRecords,
            allEvents: allEvents,
            context: context,
            executorId: executorId
        )
    }

    func recordTreat(
        pet: Pet,
        grams: Double,
        treatKind: FeedTreatKind,
        executorId: String?
    ) -> TreatFeedCommandResult {
        TreatFeedCommand.record(
            pet: pet,
            grams: grams,
            treatKind: treatKind,
            context: context,
            executorId: executorId
        )
    }

    func savePlan(
        pet: Pet,
        targets: [Pet],
        kind: FeedRuleKind,
        draft: FeedPlanDraft,
        allEvents: [Event]
    ) -> SaveFeedPlanCommandResult {
        SaveFeedPlanCommand.run(
            pet: pet,
            targets: targets,
            kind: kind,
            draft: draft,
            allEvents: allEvents,
            context: context
        )
    }

    func switchToManual(pet: Pet, allEvents: [Event]) {
        SwitchFeedModeCommand.switchToManual(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
    }

    func activateExistingRule(
        pet: Pet,
        kind: FeedRuleKind,
        allEvents: [Event]
    ) -> SwitchFeedModeCommandResult {
        SwitchFeedModeCommand.activateExistingRule(
            pet: pet,
            kind: kind,
            allEvents: allEvents,
            context: context
        )
    }

    func setFeedMode(_ mode: FeedOperatingMode, pet: Pet) {
        SetFeedModeCommand.run(mode, pet: pet)
    }

    func deletePlan(
        pet: Pet,
        kind: FeedRuleKind,
        activeMode: FeedOperatingMode,
        allEvents: [Event]
    ) -> DeleteFeedPlanCommandResult {
        DeleteFeedPlanCommand.run(
            pet: pet,
            kind: kind,
            activeMode: activeMode,
            allEvents: allEvents,
            context: context
        )
    }

    func saveStock(
        pet: Pet,
        brand: String,
        totalGrams: Double,
        purchaseDate: Date?,
        openDate: Date?,
        foodKind: FeedFoodKind,
        reminderEnabled: Bool,
        reminderAdvanceDays: Int,
        executorId: String?,
        allEvents: [Event],
        recordToUpdate: PetFoodRecord?,
        previousExpenseId: UUID?,
        expenseAmount: Double?,
        expensePayerId: String?,
        expenseDate: Date,
        expenseNote: String
    ) -> SaveFoodStockCommandResult {
        SaveFoodStockCommand.run(
            pet: pet,
            brand: brand,
            totalGrams: totalGrams,
            purchaseDate: purchaseDate,
            openDate: openDate,
            dailyGrams: nil,
            foodKind: foodKind,
            reminderEnabled: reminderEnabled,
            reminderAdvanceDays: reminderAdvanceDays,
            executorId: executorId,
            allEvents: allEvents,
            context: context,
            recordToUpdate: recordToUpdate,
            previousExpenseId: previousExpenseId,
            expenseAmount: expenseAmount,
            expensePayerId: expensePayerId,
            expenseDate: expenseDate,
            expenseNote: expenseNote
        )
    }

    func saveStockReminderSettings(
        pet: Pet,
        enabled: Bool,
        advanceDays: Int,
        allEvents: [Event]
    ) -> FeedStockCommandResult {
        StockReminderSettingsCommand.run(
            pet: pet,
            enabled: enabled,
            advanceDays: advanceDays,
            allEvents: allEvents,
            context: context
        )
    }

    func correctStock(
        pet: Pet,
        record: PetFoodRecord,
        remainingGrams: Double,
        allEvents: [Event]
    ) -> FeedStockCommandResult {
        CorrectStockCommand.run(
            pet: pet,
            record: record,
            remainingGrams: remainingGrams,
            allEvents: allEvents,
            context: context
        )
    }

    func updateLog(
        _ log: PetCareLog,
        grams: Double,
        date: Date,
        pet: Pet,
        allEvents: [Event]
    ) -> FeedStockCommandResult {
        FeedRecordCommand.updateLog(
            log,
            grams: grams,
            date: date,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
    }

    func deleteLog(_ log: PetCareLog, pet: Pet, allEvents: [Event]) -> FeedStockCommandResult {
        FeedRecordCommand.deleteLog(
            log,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
    }

    func deleteFoodRecord(_ record: PetFoodRecord, pet: Pet, allEvents: [Event]) -> FeedStockCommandResult {
        FeedRecordCommand.deleteFoodRecord(
            record,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
    }

    func materializeDueAutoLogs(pet: Pet, allEvents: [Event]) -> FeedAutoMaterializeCommandResult {
        FeedMaintenanceCommand.materializeDueAutoLogs(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
    }

    func ensureUpcomingPlanReminders(pet: Pet, allEvents: [Event], now: Date = Date(), calendar: Calendar = .current) -> [Reminder] {
        FeedMaintenanceCommand.ensureUpcomingPlanReminders(
            pet: pet,
            allEvents: allEvents,
            context: context,
            now: now,
            calendar: calendar
        )
    }

    func reminder(for event: Event, scheduledAt: Date, existing: Reminder?) -> Reminder {
        FeedMaintenanceCommand.reminder(
            for: event,
            scheduledAt: scheduledAt,
            existing: existing,
            context: context
        )
    }

    func setMainFoodKind(pet: Pet, foodKind: FeedFoodKind) {
        SetMainFoodKindCommand.run(pet: pet, foodKind: foodKind, context: context)
    }

    func schedulePlanReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        Task { @MainActor in
            guard await NotificationManager.shared.requestPermission() else { return }
            await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: context, source: .detail)
        }
    }

    func scheduleStockReminders(_ reminders: [Reminder]) {
        guard !reminders.isEmpty else { return }
        Task { @MainActor in
            await ReminderSchedulingService.scheduleManyIfNeeded(reminders: reminders, context: context, source: .detail)
        }
    }
}
