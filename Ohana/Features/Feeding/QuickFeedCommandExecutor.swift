//
//  QuickFeedCommandExecutor.swift
//  Ohana
//
//  Write-side and route-scoped data operations for the QuickFeed flow.
//

import Foundation
import SwiftData

@MainActor
private func fetchQuickFeedModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String,
    fallback: [T] = []
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "QuickFeedCommandExecutor failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return fallback
    }
}

@MainActor
struct QuickFeedCommandExecutor {
    private let context: ModelContext
    private let careEvents: CareEventRecording
    private let revisions: DomainRevisionPublishing
    private let reminderScheduling: ReminderSchedulingManaging

    init(context: ModelContext) {
        self.context = context
        careEvents = CareEventService()
        revisions = SharedDomainRevisionPublisher()
        reminderScheduling = ReminderSchedulingManager()
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        careEvents = CareEventService()
        revisions = SharedDomainRevisionPublisher(center: revisionCenter)
        reminderScheduling = ReminderSchedulingManager()
    }

    init(
        context: ModelContext,
        careEvents: CareEventRecording,
        revisions: DomainRevisionPublishing,
        reminderScheduling: ReminderSchedulingManaging
    ) {
        self.context = context
        self.careEvents = careEvents
        self.revisions = revisions
        self.reminderScheduling = reminderScheduling
    }

    /// Newest-first feeding history for the lazily-loaded history/overview
    /// sheets. The fetch is capped so a multi-year account never materializes an
    /// unbounded number of rows; the cap is generous enough to cover normal
    /// history (≈1 year at 3 feeds/day) while bounding worst-case memory/CPU.
    static let fullCareLogsFetchCap = 1000
    static let fullFoodRecordsFetchCap = 500

    func fullCareLogs(petID: UUID, feedingType: String, fallback: [PetCareLog]) -> [PetCareLog] {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.type == feedingType && log.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = Self.fullCareLogsFetchCap
        return fetchQuickFeedModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch full care logs",
            fallback: fallback
        )
    }

    func fullFeedingLedgerEvents(petID: UUID, fallback: [CareLedgerEvent]) -> [CareLedgerEvent] {
        let petKey = petID.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let feedingType = CareType.feeding.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petKey &&
                    event.eventKind == careKind &&
                    event.actionType == feedingType
            },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.fullCareLogsFetchCap
        return fetchQuickFeedModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch full feeding ledger events",
            fallback: fallback
        )
    }

    func fullFoodRecords(petID: UUID, fallback: [PetFoodRecord]) -> [PetFoodRecord] {
        var descriptor = FetchDescriptor<PetFoodRecord>(
            predicate: #Predicate<PetFoodRecord> { record in
                record.pet?.id == petID
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = Self.fullFoodRecordsFetchCap
        return fetchQuickFeedModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch full food records",
            fallback: fallback
        )
    }

    func latestAllEvents(fallback: [Event]) -> [Event] {
        let descriptor = FetchDescriptor<Event>(
            sortBy: [SortDescriptor(\Event.startDate)]
        )
        return fetchQuickFeedModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch latest events",
            fallback: fallback
        )
    }

    func stockExpense(id: UUID) -> PetExpenseLog? {
        FeedStockExpenseLink.fetchExpense(id: id, context: context)
    }

    func saveManualSettings(pet: Pet, foodKind: FeedFoodKind, grams: Double, defaultEnabled: Bool = true) {
        ManualFeedCommand.saveSettings(
            pet: pet,
            foodKind: foodKind,
            grams: grams,
            defaultEnabled: defaultEnabled,
            context: context
        )
        publishFeedMutation(.feedSettings(petID: pet.id), affectedEntityIDs: [pet.id])
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
        let result = ManualFeedCommand.recordManual(
            pet: pet,
            targets: targets,
            grams: grams,
            foodKind: foodKind,
            saveAsDefault: saveAsDefault,
            foodRecords: foodRecords,
            allEvents: allEvents,
            context: context,
            executorId: executorId,
            careEvents: careEvents
        )
        publishFeedMutation(
            .feedLog(petID: pet.id, source: "manual"),
            affectedEntityIDs: targetIDs(pet: pet, targets: targets),
            note: result.targetCount > 1 ? "shared_manual_feed" : "manual_feed"
        )
        return result
    }

    func completePlanned(
        pet: Pet,
        reminder: Reminder,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        executorId: String?
    ) -> ManualFeedCommandResult {
        let result = ManualFeedCommand.completePlanned(
            pet: pet,
            reminder: reminder,
            foodRecords: foodRecords,
            allEvents: allEvents,
            context: context,
            executorId: executorId,
            careEvents: careEvents
        )
        publishFeedMutation(
            .feedLog(petID: pet.id, source: "planned"),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: result.didRecord,
            note: result.didRecord ? "planned_feed_completed" : "planned_feed_noop"
        )
        return result
    }

    func recordTreat(
        pet: Pet,
        grams: Double,
        treatKind: FeedTreatKind,
        executorId: String?
    ) -> TreatFeedCommandResult {
        let result = TreatFeedCommand.record(
            pet: pet,
            grams: grams,
            treatKind: treatKind,
            context: context,
            executorId: executorId,
            careEvents: careEvents
        )
        publishFeedMutation(
            .feedLog(petID: pet.id, source: "treat"),
            affectedEntityIDs: [pet.id],
            note: treatKind.rawValue
        )
        return result
    }

    func savePlan(
        pet: Pet,
        targets: [Pet],
        kind: FeedRuleKind,
        draft: FeedPlanDraft,
        allEvents: [Event]
    ) -> SaveFeedPlanCommandResult {
        let result = SaveFeedPlanCommand.run(
            pet: pet,
            targets: targets,
            kind: kind,
            draft: draft,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(
            .feedPlan(petID: pet.id, action: "save_\(kind.rawValue)"),
            affectedEntityIDs: targetIDs(pet: pet, targets: targets),
            note: "targets:\(result.targetCount)"
        )
        return result
    }

    func switchToManual(pet: Pet, allEvents: [Event]) {
        SwitchFeedModeCommand.switchToManual(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(.feedMode(petID: pet.id, mode: FeedOperatingMode.manual.rawValue), affectedEntityIDs: [pet.id])
    }

    func activateExistingRule(
        pet: Pet,
        kind: FeedRuleKind,
        allEvents: [Event]
    ) -> SwitchFeedModeCommandResult {
        let result = SwitchFeedModeCommand.activateExistingRule(
            pet: pet,
            kind: kind,
            allEvents: allEvents,
            context: context
        )
        let targetMode: FeedOperatingMode = kind == .manualReminder ? .manualReminder : .autoFeeder
        publishFeedMutation(
            .feedMode(petID: pet.id, mode: targetMode.rawValue),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: result.didSwitch,
            note: kind.rawValue
        )
        return result
    }

    func setFeedMode(_ mode: FeedOperatingMode, pet: Pet) {
        let previousMode = FeedOperatingMode.stored(for: pet.id)
        SetFeedModeCommand.run(mode, pet: pet)
        publishFeedMutation(
            .feedMode(petID: pet.id, mode: mode.rawValue),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: previousMode != mode,
            note: "optimistic_mode"
        )
    }

    func deletePlan(
        pet: Pet,
        kind: FeedRuleKind,
        activeMode: FeedOperatingMode,
        allEvents: [Event]
    ) -> DeleteFeedPlanCommandResult {
        let result = DeleteFeedPlanCommand.run(
            pet: pet,
            kind: kind,
            activeMode: activeMode,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(
            .feedPlan(petID: pet.id, action: "delete_\(kind.rawValue)"),
            affectedEntityIDs: [pet.id],
            note: result.shouldSwitchToManual ? "switch_to_manual" : nil
        )
        return result
    }

    func saveStock(
        pet: Pet,
        brand: String,
        totalGrams: Double,
        purchaseDate: Date?,
        openDate: Date?,
        foodKind: FeedFoodKind,
        calculationMode: FeedStockCalculationMode,
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
        let result = SaveFoodStockCommand.run(
            pet: pet,
            brand: brand,
            totalGrams: totalGrams,
            purchaseDate: purchaseDate,
            openDate: openDate,
            dailyGrams: nil,
            foodKind: foodKind,
            calculationMode: calculationMode,
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
        publishFeedMutation(
            .feedStock(petID: pet.id, action: recordToUpdate == nil ? "create" : "update"),
            affectedEntityIDs: [pet.id],
            note: foodKind.rawValue
        )
        return result
    }

    func saveStockReminderSettings(
        pet: Pet,
        enabled: Bool,
        advanceDays: Int,
        allEvents: [Event]
    ) -> FeedStockCommandResult {
        let result = StockReminderSettingsCommand.run(
            pet: pet,
            enabled: enabled,
            advanceDays: advanceDays,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(
            .feedStock(petID: pet.id, action: "reminder_settings"),
            affectedEntityIDs: [pet.id],
            note: enabled ? "enabled" : "disabled"
        )
        return result
    }

    func correctStock(
        pet: Pet,
        record: PetFoodRecord,
        remainingGrams: Double,
        allEvents: [Event]
    ) -> FeedStockCommandResult {
        let result = CorrectStockCommand.run(
            pet: pet,
            record: record,
            remainingGrams: remainingGrams,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(
            .feedStock(petID: pet.id, action: "correct"),
            affectedEntityIDs: [pet.id],
            note: record.foodKind.rawValue
        )
        return result
    }

    func updateLog(
        _ log: PetCareLog,
        grams: Double,
        date: Date,
        pet: Pet,
        allEvents: [Event]
    ) -> FeedStockCommandResult {
        let result = FeedRecordCommand.updateLog(
            log,
            grams: grams,
            date: date,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(.feedLog(petID: pet.id, source: "update"), affectedEntityIDs: [pet.id])
        return result
    }

    func deleteLog(_ log: PetCareLog, pet: Pet, allEvents: [Event]) -> FeedStockCommandResult {
        let result = FeedRecordCommand.deleteLog(
            log,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(.feedLog(petID: pet.id, source: "delete"), affectedEntityIDs: [pet.id])
        return result
    }

    func deleteFoodRecord(_ record: PetFoodRecord, pet: Pet, allEvents: [Event]) -> FeedStockCommandResult {
        let result = FeedRecordCommand.deleteFoodRecord(
            record,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(
            .feedStock(petID: pet.id, action: "delete_record"),
            affectedEntityIDs: [pet.id],
            note: record.foodKind.rawValue
        )
        return result
    }

    func materializeDueAutoLogs(pet: Pet, allEvents: [Event]) -> FeedAutoMaterializeCommandResult {
        let result = FeedMaintenanceCommand.materializeDueAutoLogs(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        publishFeedMutation(
            .feedMaintenance(petID: pet.id, action: "materialize_auto_logs"),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: result.insertedCount > 0,
            note: "inserted:\(result.insertedCount)"
        )
        return result
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
        let reminder = FeedMaintenanceCommand.reminder(
            for: event,
            scheduledAt: scheduledAt,
            existing: existing,
            context: context
        )
        if existing == nil, let petID = UUID(uuidString: event.relatedEntityId) {
            publishFeedMutation(
                .feedMaintenance(petID: petID, action: "create_plan_reminder"),
                affectedEntityIDs: [petID],
                note: event.id.uuidString
            )
        }
        return reminder
    }

    func setMainFoodKind(pet: Pet, foodKind: FeedFoodKind) {
        let previousKind = pet.mainFoodKind
        SetMainFoodKindCommand.run(pet: pet, foodKind: foodKind, context: context)
        publishFeedMutation(
            .feedSettings(petID: pet.id),
            affectedEntityIDs: [pet.id],
            wroteBusinessFact: previousKind != foodKind,
            note: "main_food_kind:\(foodKind.rawValue)"
        )
    }

    func schedulePlanReminders(_ reminders: [Reminder]) async {
        guard !reminders.isEmpty, !Task.isCancelled else { return }
        await reminderScheduling.scheduleManyIfNeeded(reminders: reminders, context: context, source: .detail)
    }

    func scheduleStockReminders(_ reminders: [Reminder]) async {
        guard !reminders.isEmpty, !Task.isCancelled else { return }
        await reminderScheduling.scheduleManyIfNeeded(reminders: reminders, context: context, source: .detail)
    }

    private func publishFeedMutation(
        _ command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool = true,
        note: String? = nil
    ) {
        guard wroteBusinessFact else {
            AppPerformanceMonitor.shared.record("domain_command_noop", valueMS: 0, note: note ?? "\(command)")
            return
        }
        revisions.publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affectedEntityIDs,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    private func targetIDs(pet: Pet, targets: [Pet]) -> Set<UUID> {
        let ids = targets.isEmpty ? [pet.id] : targets.map(\.id)
        return Set(ids)
    }
}

private extension SwitchFeedModeCommandResult {
    var didSwitch: Bool {
        if case .switched = self { return true }
        return false
    }
}
