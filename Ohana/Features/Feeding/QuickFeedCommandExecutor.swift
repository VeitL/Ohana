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
    private let derivations: CareDerivationExecutor
    private let reminderScheduling: ReminderSchedulingManaging

    init(context: ModelContext) {
        self.context = context
        careEvents = CareEventService()
        derivations = CareDerivationExecutor()
        reminderScheduling = ReminderSchedulingManager()
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.context = context
        careEvents = CareEventService()
        derivations = CareDerivationExecutor(revisions: SharedDomainRevisionPublisher(center: revisionCenter))
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
        derivations = CareDerivationExecutor(revisions: revisions)
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
                log.type == feedingType &&
                    log.pet?.id == petID
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

    func feedLog(id: UUID) -> PetCareLog? {
        var descriptor = FetchDescriptor<PetCareLog>(
            predicate: #Predicate<PetCareLog> { log in
                log.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchQuickFeedModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch feed log by id"
        ).first
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

    func fullFeedingLedgerEntries(
        pet: Pet,
        legacyCareLogs: [PetCareLog],
        manualPlanEvents: [Event],
        autoFeederEvents: [Event],
        fallback: [QuickFeedLedgerEntry]
    ) -> [QuickFeedLedgerEntry] {
        let petKey = pet.id.uuidString
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
        do {
            let events = try context.fetch(descriptor)
            return QuickFeedLedgerEntry.entries(
                pet: pet,
                feedingLedgerEvents: events,
                legacyCareLogs: legacyCareLogs,
                manualPlanEvents: manualPlanEvents,
                autoFeederEvents: autoFeederEvents
            )
        } catch {
            OhanaLog.warning(
                "QuickFeedCommandExecutor failed to fetch full feeding ledger entries: \(error.localizedDescription)",
                category: "Care"
            )
            return fallback
        }
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
        let didChange = ManualFeedCommand.saveSettings(
            pet: pet,
            foodKind: foodKind,
            grams: grams,
            defaultEnabled: defaultEnabled,
            context: context
        )
        deriveFeedMutation(.feedSettings(petID: pet.id), pets: [pet], wroteBusinessFact: didChange)
    }

    func recordManual(
        pet: Pet,
        targets: [Pet],
        grams: Double,
        foodKind: FeedFoodKind,
        saveAsDefault: Bool,
        foodRecords: [PetFoodRecord],
        allEvents: [Event],
        executorId: String?,
        date: Date = Date()
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
            careEvents: careEvents,
            date: date
        )
        deriveFeedMutation(
            .feedLog(petID: pet.id, source: "manual"),
            pets: mutationPets(pet: pet, targets: targets),
            wroteBusinessFact: result.didRecord && result.allowsDerivedEffects,
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
        deriveFeedMutation(
            .feedLog(petID: pet.id, source: "planned"),
            pets: [pet],
            wroteBusinessFact: result.didRecord && result.allowsDerivedEffects,
            note: result.didRecord && result.allowsDerivedEffects ? "planned_feed_completed" : "planned_feed_noop"
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
        deriveFeedMutation(
            .feedLog(petID: pet.id, source: "treat"),
            pets: [pet],
            wroteBusinessFact: result.didRecord && result.allowsDerivedEffects,
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
        deriveFeedMutation(
            .feedPlan(petID: pet.id, action: "save_\(kind.rawValue)"),
            pets: mutationPets(pet: pet, targets: targets),
            wroteBusinessFact: result.didChange,
            note: "targets:\(result.targetCount)"
        )
        return result
    }

    func switchToManual(pet: Pet, allEvents: [Event]) {
        let didChange = SwitchFeedModeCommand.switchToManual(
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        deriveFeedMutation(
            .feedMode(petID: pet.id, mode: FeedOperatingMode.manual.rawValue),
            pets: [pet],
            wroteBusinessFact: didChange
        )
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
        deriveFeedMutation(
            .feedMode(petID: pet.id, mode: targetMode.rawValue),
            pets: [pet],
            wroteBusinessFact: result.didSwitch,
            note: kind.rawValue
        )
        return result
    }

    func setFeedMode(_ mode: FeedOperatingMode, pet: Pet) {
        let previousMode = FeedOperatingMode.stored(for: pet.id)
        let didChange = SetFeedModeCommand.run(mode, pet: pet)
        deriveFeedMutation(
            .feedMode(petID: pet.id, mode: mode.rawValue),
            pets: [pet],
            wroteBusinessFact: didChange && previousMode != mode,
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
        deriveFeedMutation(
            .feedPlan(petID: pet.id, action: "delete_\(kind.rawValue)"),
            pets: [pet],
            wroteBusinessFact: result.didChange,
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
        deriveFeedMutation(
            .feedStock(petID: pet.id, action: recordToUpdate == nil ? "create" : "update"),
            pets: [pet],
            wroteBusinessFact: result.didChange && result.allowsDerivedEffects,
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
        deriveFeedMutation(
            .feedStock(petID: pet.id, action: "reminder_settings"),
            pets: [pet],
            wroteBusinessFact: result.didChange && result.allowsDerivedEffects,
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
        deriveFeedMutation(
            .feedStock(petID: pet.id, action: "correct"),
            pets: [pet],
            wroteBusinessFact: result.didChange && result.allowsDerivedEffects,
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
        deriveFeedMutation(
            .feedLog(petID: pet.id, source: "update"),
            pets: [pet],
            wroteBusinessFact: result.didChange && result.allowsDerivedEffects
        )
        return result
    }

    func deleteLog(_ log: PetCareLog, pet: Pet, allEvents: [Event]) -> FeedStockCommandResult {
        let result = FeedRecordCommand.deleteLog(
            log,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        deriveFeedMutation(
            .feedLog(petID: pet.id, source: "delete"),
            pets: [pet],
            wroteBusinessFact: result.didChange && result.allowsDerivedEffects
        )
        return result
    }

    func deleteFoodRecord(_ record: PetFoodRecord, pet: Pet, allEvents: [Event]) -> FeedStockCommandResult {
        let result = FeedRecordCommand.deleteFoodRecord(
            record,
            pet: pet,
            allEvents: allEvents,
            context: context
        )
        deriveFeedMutation(
            .feedStock(petID: pet.id, action: "delete_record"),
            pets: [pet],
            wroteBusinessFact: result.didChange && result.allowsDerivedEffects,
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
        deriveFeedMutation(
            .feedMaintenance(petID: pet.id, action: "materialize_auto_logs"),
            pets: [pet],
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
        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            catalog: DomainSubjectResolutionCatalog()
        )
        if existing == nil, case let .pet(petID) = resolution.owner, let pet = fetchPet(id: petID) {
            deriveFeedMutation(
                .feedMaintenance(petID: petID, action: "create_plan_reminder"),
                pets: [pet],
                note: event.id.uuidString
            )
        }
        return reminder
    }

    func setMainFoodKind(pet: Pet, foodKind: FeedFoodKind) {
        let previousKind = pet.mainFoodKind
        let didChange = SetMainFoodKindCommand.run(pet: pet, foodKind: foodKind, context: context)
        deriveFeedMutation(
            .feedSettings(petID: pet.id),
            pets: [pet],
            wroteBusinessFact: didChange && previousKind != foodKind,
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

    private func deriveFeedMutation(
        _ command: DomainCommand,
        pets: [Pet],
        wroteBusinessFact: Bool = true,
        note: String? = nil
    ) {
        let affectedEntityIDs = Set(pets.map(\.id))
        guard wroteBusinessFact else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: affectedEntityIDs,
                    note: note ?? "\(command)"
                )
            )
            return
        }
        let effectPlans = DomainEffectWriteAuthorizer.authorizePetEffects(
            pets: pets,
            writeKind: .care,
            context: context,
            logPrefix: "QuickFeedCommandExecutor.derive"
        )
        guard !effectPlans.isEmpty else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: affectedEntityIDs,
                    note: note ?? "\(command).unauthorized"
                )
            )
            return
        }
        derivations.derive(
            .derivedMutation(
                command: command,
                effectPlans: effectPlans,
                note: note
            )
        )
    }

    private func mutationPets(pet: Pet, targets: [Pet]) -> [Pet] {
        SharedPetTargetResolver.normalizedTargets(targets, fallback: pet)
    }

    private func fetchPet(id: UUID) -> Pet? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.id == id
            }
        )
        descriptor.fetchLimit = 1
        return fetchQuickFeedModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch mutation pet"
        ).first
    }
}

private extension SwitchFeedModeCommandResult {
    var didSwitch: Bool {
        if case .switched = self { return true }
        return false
    }
}
