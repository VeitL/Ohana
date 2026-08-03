//
//  PlantCareScheduleSyncService.swift
//  Ohana
//
//  Bridges completed plant calendar events/reminders into durable plant care facts.
//

import Foundation
import SwiftData

struct PlantCareScheduleSyncResult: Equatable {
    enum Action: String, Equatable {
        case wroteCareFact
        case removedCareFact
        case wroteSkipFeedback
        case skippedExistingCare
        case skippedMissingCare
        case noPlantTarget
        case unsupportedCareType
        case notGeneratedPlantPlan
        case unauthorized
        case persistenceFailed
    }

    let action: Action
    let plantID: UUID?
    let logID: UUID?
    let ledgerEventID: UUID?
    let careType: PlantCareType?
    let persistenceErrorDescription: String?

    init(
        action: Action,
        plantID: UUID?,
        logID: UUID?,
        ledgerEventID: UUID?,
        careType: PlantCareType?,
        persistenceErrorDescription: String? = nil
    ) {
        self.action = action
        self.plantID = plantID
        self.logID = logID
        self.ledgerEventID = ledgerEventID
        self.careType = careType
        self.persistenceErrorDescription = persistenceErrorDescription
    }

    var didPersist: Bool {
        action != .persistenceFailed
    }

    /// Schedule state may advance only after a generated care plan has either
    /// produced its durable fact or found the same care fact already present.
    /// Non-generated events remain ordinary calendar/reminder items.
    var allowsScheduleCompletion: Bool {
        switch action {
        case .wroteCareFact, .removedCareFact, .skippedExistingCare, .skippedMissingCare,
             .notGeneratedPlantPlan:
            true
        case .wroteSkipFeedback, .noPlantTarget, .unsupportedCareType, .unauthorized, .persistenceFailed:
            false
        }
    }

    var didWriteCareFact: Bool {
        action == .wroteCareFact
    }

    var didRemoveCareFact: Bool {
        action == .removedCareFact
    }

    static func persistenceFailed(
        plantID: UUID?,
        careType: PlantCareType?,
        errorDescription: String?
    ) -> PlantCareScheduleSyncResult {
        PlantCareScheduleSyncResult(
            action: .persistenceFailed,
            plantID: plantID,
            logID: nil,
            ledgerEventID: nil,
            careType: careType,
            persistenceErrorDescription: errorDescription
        )
    }
}

@MainActor
enum PlantCareScheduleSyncService {
    private struct CompletedCarePersistenceContext {
        let event: Event
        let plant: Plant
        let careType: PlantCareType
        let careDate: Date
        let executorID: String?
        let source: CareLedgerSource
        let sourceReminderID: UUID?
        let now: Date
        let modelContext: ModelContext
        let careLedger: CareLedgerRecording
        let scheduleNotifications: Bool
        let syncPlanSchedule: Bool
    }

    static func careType(for event: Event) -> PlantCareType? {
        if !event.taskCareKindRaw.isEmpty {
            return TaskCareKind(rawValue: event.taskCareKindRaw)?.plantCareType
        }
        return switch EventType(rawValue: event.eventType) {
        case .watering:
            .watering
        case .fertilizing:
            .fertilizing
        case .plantRepotting:
            .repotting
        case .plantPruning:
            .pruning
        case .plantMisting:
            .misting
        case .plantRotation:
            .rotating
        case .plantLeafCleaning:
            .leafCleaning
        case .plantPestCheck:
            .pestCheck
        case .plantHealthCheck:
            .customNote
        case .birthday, .anniversary, .daily, .health, .task, .shoppingList, .chore,
             .vaccine, .externalDeworming, .internalDeworming, .grooming, .vetVisit,
             .foodChange, .litterBox, .medication, .petMedication, .petMedicationDose,
             .insurancePremium, .none:
            nil
        }
    }

    static func isPlantCareEvent(_ event: Event) -> Bool {
        if !event.taskCareKindRaw.isEmpty {
            return TaskCareKind(rawValue: event.taskCareKindRaw)?.plantCareType != nil
        }
        return PlantReminderPreferenceStore.isGeneratedPlantCareEvent(event)
    }

    static func hasCompletedCareFact(
        for event: Event,
        occurrenceDate: Date,
        context: ModelContext
    ) -> Bool {
        guard isPlantCareEvent(event),
              let type = careType(for: event),
              let plantID = DomainEntityLinkRegistry.plantId(for: event) else { return false }
        let eventID = event.id.uuidString
        let eventKind = CareLedgerEventKind.plantCare.rawValue
        let actionType = type.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.sourceEventId == eventID &&
                    ledger.eventKind == eventKind &&
                    ledger.actionType == actionType
            }
        )
        descriptor.fetchLimit = 20
        let calendar = Calendar.current
        return ((try? context.fetch(descriptor)) ?? []).contains { ledger in
            ledger.subjectId == plantID.uuidString &&
                calendar.isDate(ledger.occurredAt, inSameDayAs: occurrenceDate)
        }
    }

    @discardableResult
    static func syncCompletedEvent(
        _ event: Event,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext,
        source: CareLedgerSource = .calendar,
        sourceReminderId: UUID? = nil,
        now: Date = Date(),
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        scheduleNotifications: Bool = true,
        syncPlanSchedule: Bool = true
    ) -> PlantCareScheduleSyncResult {
        guard isPlantCareEvent(event) else {
            return PlantCareScheduleSyncResult(
                action: .notGeneratedPlantPlan,
                plantID: DomainEntityLinkRegistry.plantId(for: event),
                logID: nil,
                ledgerEventID: nil,
                careType: careType(for: event)
            )
        }
        guard let type = careType(for: event) else {
            return PlantCareScheduleSyncResult(
                action: .unsupportedCareType,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        guard let plantID = DomainEntityLinkRegistry.plantId(for: event),
              let plant = fetchPlant(id: plantID, context: context) else {
            return PlantCareScheduleSyncResult(
                action: .noPlantTarget,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }
        let careDate = Event.dateMergingTime(from: event.startDate, ontoOccurrenceDay: occurrenceDate)
        if hasCompletedCareFact(for: event, occurrenceDate: occurrenceDate, context: context) ||
            hasExistingCare(type, plantID: plant.id, on: careDate, context: context) {
            return PlantCareScheduleSyncResult(
                action: .skippedExistingCare,
                plantID: plant.id,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }
        guard let plan = DomainEffectWriteAuthorizer.authorizeSubjectEffect(
            subjectRequest: DomainSubjectResolutionRequest(event: event),
            occurredAt: now,
            writeKind: .care,
            source: .domainService,
            executorId: executorId,
            unresolvedAssigneePolicy: .drop,
            context: context,
            logPrefix: "PlantCareScheduleSync.complete"
        ) else {
            return PlantCareScheduleSyncResult(
                action: .unauthorized,
                plantID: plant.id,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }

        var result = PlantCareScheduleSyncResult(
            action: .unauthorized,
            plantID: plant.id,
            logID: nil,
            ledgerEventID: nil,
            careType: type
        )
        DomainEffectDispatcher.run(plan: plan) { actor in
            result = persistCompletedCare(
                CompletedCarePersistenceContext(
                    event: event,
                    plant: plant,
                    careType: type,
                    careDate: careDate,
                    executorID: actor.effectiveExecutorId,
                    source: source,
                    sourceReminderID: sourceReminderId,
                    now: now,
                    modelContext: context,
                    careLedger: providedCareLedger ?? CareLedgerService(),
                    scheduleNotifications: scheduleNotifications,
                    syncPlanSchedule: syncPlanSchedule
                )
            )
        }
        return result
    }

    private static func persistCompletedCare(
        _ persistence: CompletedCarePersistenceContext
    ) -> PlantCareScheduleSyncResult {
        let plant = persistence.plant
        let context = persistence.modelContext
        let previousCareDate = currentCareDate(type: persistence.careType, for: plant)
        applyCareDate(persistence.careDate, type: persistence.careType, to: plant)
        let log = PlantCareLog(
            date: persistence.careDate,
            careType: persistence.careType,
            note: scheduleCompletionNote(for: persistence.event),
            executorId: persistence.executorID
        )
        log.plant = plant
        context.insert(log)
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: persistence.now)
        let ledger = persistence.careLedger.record(
            occurredAt: persistence.careDate,
            actorKind: persistence.executorID == nil ? .unknown : .human,
            actorId: persistence.executorID,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: persistence.careType.rawValue,
            amountValue: 0,
            amountUnit: "",
            note: log.note,
            source: persistence.source,
            sourceEventId: persistence.event.id.uuidString,
            sourceReminderId: persistence.sourceReminderID?.uuidString,
            legacyModelName: "PlantCareLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: scheduleCompletionMetadata(previousCareDate: previousCareDate),
            context: context,
            save: false
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return .persistenceFailed(
                plantID: plant.id,
                careType: persistence.careType,
                errorDescription: saveResult.errorDescription
            )
        }
        if persistence.syncPlanSchedule {
            PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: persistence.now,
                scheduleNotifications: persistence.scheduleNotifications
            )
        }
        return PlantCareScheduleSyncResult(
            action: .wroteCareFact,
            plantID: plant.id,
            logID: log.id,
            ledgerEventID: ledger.id,
            careType: persistence.careType
        )
    }

    @discardableResult
    static func syncReopenedEvent(
        _ event: Event,
        occurrenceDate: Date,
        executorId: String?,
        context: ModelContext,
        now: Date = Date(),
        saveChanges: Bool = true
    ) -> PlantCareScheduleSyncResult {
        guard isPlantCareEvent(event) else {
            return PlantCareScheduleSyncResult(
                action: .notGeneratedPlantPlan,
                plantID: DomainEntityLinkRegistry.plantId(for: event),
                logID: nil,
                ledgerEventID: nil,
                careType: careType(for: event)
            )
        }
        guard let type = careType(for: event) else {
            return PlantCareScheduleSyncResult(
                action: .unsupportedCareType,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        guard let plantID = DomainEntityLinkRegistry.plantId(for: event),
              let plant = fetchPlant(id: plantID, context: context) else {
            return PlantCareScheduleSyncResult(
                action: .noPlantTarget,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }

        let ledgers = generatedCareLedgers(
            for: event,
            occurrenceDate: occurrenceDate,
            plantID: plantID,
            careType: type,
            context: context
        )
        guard !ledgers.isEmpty else {
            return PlantCareScheduleSyncResult(
                action: .skippedMissingCare,
                plantID: plantID,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }

        let generatedLogIDs = Set(ledgers.compactMap(\.legacyModelId).compactMap(UUID.init(uuidString:)))
        let recordedPreviousDate = ledgers.lazy.compactMap {
            recordedPreviousCareDate(in: $0.metadataJSON)
        }.first
        var removedLogID: UUID?
        for log in fetchPlantCareLogs(ids: generatedLogIDs, context: context) {
            removedLogID = removedLogID ?? log.id
            CloudSyncMutationRecorder.markDeleted(
                log,
                plant: plant,
                context: context,
                deletedAt: now,
                deletedByHumanId: executorId
            )
            context.delete(log)
        }
        for ledger in ledgers {
            CloudSyncMutationRecorder.markDeleted(
                ledger,
                context: context,
                deletedAt: now,
                deletedByHumanId: executorId
            )
            context.delete(ledger)
        }

        let fallbackDate = latestRemainingCareDate(
            type: type,
            plantID: plantID,
            excludingLogIDs: generatedLogIDs,
            context: context
        )
        applyCareDate(recordedPreviousDate ?? fallbackDate, type: type, to: plant)
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
        if saveChanges {
            let saveResult = context.safeSaveResult(publishFailureEvent: true)
            guard saveResult.didSave else {
                context.rollback()
                return .persistenceFailed(
                    plantID: plantID,
                    careType: type,
                    errorDescription: saveResult.errorDescription
                )
            }
        }

        return PlantCareScheduleSyncResult(
            action: .removedCareFact,
            plantID: plantID,
            logID: removedLogID,
            ledgerEventID: ledgers.first?.id,
            careType: type
        )
    }

    @discardableResult
    static func syncReopenedReminder(
        _ reminder: Reminder,
        executorId: String?,
        context: ModelContext,
        now: Date = Date(),
        saveChanges: Bool = true
    ) -> PlantCareScheduleSyncResult {
        guard let event = reminder.event else {
            return PlantCareScheduleSyncResult(
                action: .noPlantTarget,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        let reminderID = reminder.id.uuidString
        let sourceEventID = event.id.uuidString
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.sourceReminderId == reminderID &&
                    ledger.sourceEventId == sourceEventID
            }
        )
        descriptor.fetchLimit = 20
        let occurrenceDate = ((try? context.fetch(descriptor)) ?? [])
            .first { ledger in
                CalendarTaskCompletionSyncService.metadataDictionary(
                    from: ledger.metadataJSON
                )["scheduleCompletion"] as? Bool == true
            }?
            .occurredAt ?? reminder.scheduledAt
        return syncReopenedEvent(
            event,
            occurrenceDate: occurrenceDate,
            executorId: executorId,
            context: context,
            now: now,
            saveChanges: saveChanges
        )
    }

    @discardableResult
    static func syncCompletedReminder(
        _ reminder: Reminder,
        occurrenceDate: Date? = nil,
        executorId: String?,
        context: ModelContext,
        now: Date = Date(),
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        scheduleNotifications: Bool = true,
        syncPlanSchedule: Bool = true
    ) -> PlantCareScheduleSyncResult {
        guard let event = reminder.event else {
            return PlantCareScheduleSyncResult(
                action: .noPlantTarget,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        return syncCompletedEvent(
            event,
            occurrenceDate: occurrenceDate ?? reminder.scheduledAt,
            executorId: executorId,
            context: context,
            source: .reminder,
            sourceReminderId: reminder.id,
            now: now,
            careLedger: providedCareLedger,
            scheduleNotifications: scheduleNotifications,
            syncPlanSchedule: syncPlanSchedule
        )
    }

    static func syncPlanAfterCompletion(
        _ result: PlantCareScheduleSyncResult,
        context: ModelContext,
        now: Date,
        scheduleNotifications: Bool
    ) {
        guard result.allowsScheduleCompletion,
              let plantID = result.plantID,
              let plant = fetchPlant(id: plantID, context: context) else { return }
        PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            scheduleNotifications: scheduleNotifications
        )
    }

    @discardableResult
    static func syncSkippedReminder(
        _ reminder: Reminder,
        executorId: String?,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        scheduleNotifications: Bool = true,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> PlantCareScheduleSyncResult {
        guard let event = reminder.event else {
            return PlantCareScheduleSyncResult(
                action: .unsupportedCareType,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        guard isPlantCareEvent(event) else {
            return PlantCareScheduleSyncResult(
                action: .notGeneratedPlantPlan,
                plantID: DomainEntityLinkRegistry.plantId(for: event),
                logID: nil,
                ledgerEventID: nil,
                careType: careType(for: event)
            )
        }
        guard let type = careType(for: event) else {
            return PlantCareScheduleSyncResult(
                action: .unsupportedCareType,
                plantID: DomainEntityLinkRegistry.plantId(for: event),
                logID: nil,
                ledgerEventID: nil,
                careType: nil
            )
        }
        guard let plantID = DomainEntityLinkRegistry.plantId(for: event),
              let plant = fetchPlant(id: plantID, context: context) else {
            return PlantCareScheduleSyncResult(
                action: .noPlantTarget,
                plantID: nil,
                logID: nil,
                ledgerEventID: nil,
                careType: type
            )
        }

        let nextDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
        let log = PlantCareLog(
            date: now,
            careType: .customNote,
            note: skipFeedbackNote(type: type, nextDate: nextDate),
            executorId: executorId
        )
        log.plant = plant
        context.insert(log)
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: now)
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return .persistenceFailed(
                plantID: plant.id,
                careType: type,
                errorDescription: saveResult.errorDescription
            )
        }

        PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: now,
            calendar: calendar,
            scheduleNotifications: scheduleNotifications,
            notifications: notifications
        )

        return PlantCareScheduleSyncResult(
            action: .wroteSkipFeedback,
            plantID: plant.id,
            logID: log.id,
            ledgerEventID: nil,
            careType: type
        )
    }

    private static func fetchPlant(id: UUID, context: ModelContext) -> Plant? {
        var descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { plant in
                plant.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func hasExistingCare(
        _ type: PlantCareType,
        plantID: UUID,
        on date: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) -> Bool {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        let typeRaw = type.rawValue
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.careTypeRaw == typeRaw && log.date >= start && log.date < end
            }
        )
        descriptor.fetchLimit = 24
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.contains { $0.plant?.id == plantID }
    }

    private static func applyCareDate(_ date: Date?, type: PlantCareType, to plant: Plant) {
        switch type {
        case .watering:
            plant.lastWateredDate = date
        case .fertilizing:
            plant.lastFertilizedDate = date
        case .pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote:
            plant.lastHealthCheckDate = date
        case .repotting, .pruning, .misting, .rotating, .leafCleaning:
            break
        }
    }

    private static func currentCareDate(type: PlantCareType, for plant: Plant) -> Date? {
        switch type {
        case .watering:
            plant.lastWateredDate
        case .fertilizing:
            plant.lastFertilizedDate
        case .pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote:
            plant.lastHealthCheckDate
        case .repotting, .pruning, .misting, .rotating, .leafCleaning:
            nil
        }
    }

    private static func generatedCareLedgers(
        for event: Event,
        occurrenceDate: Date,
        plantID: UUID,
        careType: PlantCareType,
        context: ModelContext,
        calendar: Calendar = .current
    ) -> [CareLedgerEvent] {
        let eventID = event.id.uuidString
        let plantIDString = plantID.uuidString
        let actionType = careType.rawValue
        let eventKind = CareLedgerEventKind.plantCare.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.sourceEventId == eventID &&
                    ledger.subjectId == plantIDString &&
                    ledger.actionType == actionType &&
                    ledger.eventKind == eventKind
            }
        )
        descriptor.fetchLimit = 20
        return ((try? context.fetch(descriptor)) ?? []).filter { ledger in
            calendar.isDate(ledger.occurredAt, inSameDayAs: occurrenceDate) &&
                ledger.legacyModelName == String(describing: PlantCareLog.self) &&
                CalendarTaskCompletionSyncService.metadataDictionary(
                    from: ledger.metadataJSON
                )["scheduleCompletion"] as? Bool == true
        }
    }

    private static func fetchPlantCareLogs(
        ids: Set<UUID>,
        context: ModelContext
    ) -> [PlantCareLog] {
        guard !ids.isEmpty else { return [] }
        return ((try? context.fetch(FetchDescriptor<PlantCareLog>())) ?? []).filter {
            ids.contains($0.id)
        }
    }

    private static func latestRemainingCareDate(
        type: PlantCareType,
        plantID: UUID,
        excludingLogIDs: Set<UUID>,
        context: ModelContext
    ) -> Date? {
        ((try? context.fetch(FetchDescriptor<PlantCareLog>())) ?? [])
            .filter { log in
                log.plant?.id == plantID &&
                    !excludingLogIDs.contains(log.id) &&
                    careTypesSharingSummaryDate(with: type).contains(log.careType)
            }
            .map(\.date)
            .max()
    }

    private static func careTypesSharingSummaryDate(with type: PlantCareType) -> Set<PlantCareType> {
        switch type {
        case .watering:
            [.watering]
        case .fertilizing:
            [.fertilizing]
        case .pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote:
            [.pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote]
        case .repotting, .pruning, .misting, .rotating, .leafCleaning:
            []
        }
    }

    private static func scheduleCompletionMetadata(previousCareDate: Date?) -> String {
        var object: [String: Any] = [
            "scheduleCompletion": true,
            "hasPreviousCareDate": previousCareDate != nil
        ]
        if let previousCareDate {
            object["previousCareDate"] = previousCareDate.timeIntervalSince1970
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"scheduleCompletion\":true}"
        }
        return json
    }

    private static func recordedPreviousCareDate(in metadataJSON: String) -> Date? {
        let metadata = CalendarTaskCompletionSyncService.metadataDictionary(from: metadataJSON)
        guard metadata["hasPreviousCareDate"] as? Bool == true,
              let interval = metadata["previousCareDate"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    private static func scheduleCompletionNote(for event: Event) -> String {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "计划完成" : "计划完成：\(title)"
    }

    private static func skipFeedbackNote(type: PlantCareType, nextDate: Date) -> String {
        "skip:\(type.rawValue):\(ISO8601DateFormatter().string(from: nextDate))|notNeeded"
    }
}
