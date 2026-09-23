//
//  PlantCareHistoryCommands.swift
//  Ohana
//
//  Typed edit/delete boundary for a single durable plant-care history fact.
//

import Foundation
import SwiftData

@MainActor
enum PlantCareHistoryCommandService {
    enum SummaryGroup: CaseIterable, Hashable {
        case watering
        case fertilizing
        case health
    }

    private struct SourceResolution {
        let source: PlantCareHistorySource
        let linkedLedgers: [CareLedgerEvent]
        let canonicalLedger: CareLedgerEvent?
    }

    private enum LinkedEventLookupError: Error {
        case mismatch
        case persistence(String)
    }

    static func snapshot(
        recordID: PlantCareHistoryRecordID,
        context: ModelContext
    ) throws -> PlantCareHistoryRecordSnapshot {
        guard let log = try fetchLog(id: recordID.logID, context: context) else {
            throw PlantCareHistoryCommandFailure.missingRecord
        }
        guard log.plant?.id == recordID.plantID else {
            throw PlantCareHistoryCommandFailure.wrongPlant
        }
        let source = try resolveSource(for: log, context: context)
        guard source.source != .internalFeedback else {
            throw PlantCareHistoryCommandFailure.internalFeedback
        }
        return PlantCareHistoryRecordSnapshot(
            recordID: recordID,
            date: log.date,
            careType: log.careType,
            note: log.note,
            executorID: log.executorId,
            careTransactionID: log.careTransactionId,
            healthStatus: log.healthStatus,
            hasPhoto: log.hasPhotoAttachment,
            source: source.source
        )
    }

    private enum EditEventUpdateOutcome {
        case updated((event: Event, snapshot: EditEventSnapshot)?)
        case rejected(PlantCareHistoryCommandResult)
    }

    private static func updateLinkedManualEvent(
        _ linkedManualEvent: Event?,
        requiresUpdate: Bool,
        plant: Plant,
        intent: PlantCareHistoryEditIntent,
        context: ModelContext,
        options: PlantCareHistoryCommandOptions
    ) -> EditEventUpdateOutcome {
        guard requiresUpdate, let sourceEvent = linkedManualEvent else { return .updated(nil) }
        let eventIntent = manualSourceEventIntent(
            event: sourceEvent,
            plant: plant,
            date: intent.date,
            careType: intent.careType,
            defaults: options.defaults
        )
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
            event: sourceEvent,
            intent: eventIntent,
            writeKind: .care,
            source: .domainService,
            context: context
        ) else {
            return .rejected(.rejected(recordID: intent.recordID, operationID: intent.operationID, failure: .authorizationDenied))
        }
        let eventSnapshot = EditEventSnapshot(event: sourceEvent)
        guard DomainScheduleWriter.updateEvent(
            sourceEvent,
            intent: eventIntent,
            mutation: mutation
        ) else {
            return .rejected(.rejected(recordID: intent.recordID, operationID: intent.operationID, failure: .authorizationDenied))
        }
        CloudSyncMutationRecorder.markModified(sourceEvent, context: context, modifiedAt: intent.now)
        return .updated((sourceEvent, eventSnapshot))
    }

    private struct EditSource {
        let log: PlantCareLog
        let plant: Plant
        let resolution: SourceResolution
        let linkedManualEvent: Event?
        let sourceEventRequiresUpdate: Bool
    }

    private struct EditRejection: Error {
        let result: PlantCareHistoryCommandResult
    }

    private static func rejectEdit(
        _ intent: PlantCareHistoryEditIntent,
        failure: PlantCareHistoryCommandFailure
    ) -> EditRejection {
        EditRejection(result: .rejected(recordID: intent.recordID, operationID: intent.operationID, failure: failure))
    }

    private static func resolveEditableSource(
        _ intent: PlantCareHistoryEditIntent,
        context: ModelContext
    ) throws -> EditSource {
        guard let log = try fetchLog(id: intent.recordID.logID, context: context) else {
            throw rejectEdit(intent, failure: .missingRecord)
        }
        guard let plant = log.plant, plant.id == intent.recordID.plantID else {
            throw rejectEdit(intent, failure: .wrongPlant)
        }
        guard log.careTransactionId == intent.expectedCareTransactionID else {
            throw rejectEdit(intent, failure: .staleRecord)
        }
        guard intent.date <= intent.now.addingTimeInterval(60) else {
            throw rejectEdit(intent, failure: .futureDate)
        }
        let resolution = try resolveSource(for: log, context: context)
        guard resolution.source != .internalFeedback else {
            throw rejectEdit(intent, failure: .internalFeedback)
        }
        guard !hasPendingRewardSettlement(in: resolution.linkedLedgers) else {
            throw rejectEdit(intent, failure: .pendingRewardSettlement)
        }
        if resolution.source.locksSourceFields,
           log.date != intent.date || log.careType != intent.careType {
            throw rejectEdit(intent, failure: .sourceFieldsLocked)
        }
        let linkedManualEvent = try linkedManualSourceEvent(
            resolution: resolution,
            plant: plant,
            context: context
        )
        let sourceEventRequiresUpdate = linkedManualEvent.map { event in
            event.startDate != intent.date ||
                event.eventType != intent.careType.eventType.rawValue ||
                (!event.taskCareKindRaw.isEmpty &&
                    TaskCareKind(rawValue: event.taskCareKindRaw)?.plantCareType != intent.careType)
        } ?? false
        return EditSource(
            log: log,
            plant: plant,
            resolution: resolution,
            linkedManualEvent: linkedManualEvent,
            sourceEventRequiresUpdate: sourceEventRequiresUpdate
        )
    }

    @discardableResult
    static func edit(
        _ intent: PlantCareHistoryEditIntent,
        context: ModelContext
    ) -> PlantCareHistoryCommandResult {
        edit(intent, context: context, options: PlantCareHistoryCommandOptions())
    }

    @discardableResult
    static func edit(
        _ intent: PlantCareHistoryEditIntent,
        context: ModelContext,
        options: PlantCareHistoryCommandOptions
    ) -> PlantCareHistoryCommandResult {
        let recordID = intent.recordID
        let operationID = intent.operationID
        let source: EditSource
        do {
            source = try resolveEditableSource(intent, context: context)
        } catch let rejection as EditRejection {
            return rejection.result
        } catch let error as LinkedEventLookupError {
            return linkedEventLookupRejection(error, recordID: recordID, operationID: operationID)
        } catch {
            return .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        let log = source.log
        let plant = source.plant
        let resolution = source.resolution
        let linkedManualEvent = source.linkedManualEvent
        let sourceEventRequiresUpdate = source.sourceEventRequiresUpdate

        let normalizedNote: String
        let replacementPhoto: Data?
        switch prepareEditValues(
            intent,
            log: log,
            sourceEventRequiresUpdate: sourceEventRequiresUpdate,
            canonicalLedgerID: resolution.canonicalLedger?.id
        ) {
        case let .changed(note, photo):
            normalizedNote = note
            replacementPhoto = photo
        case let .unchanged(result), let .rejected(result):
            return result
        }

        let originalDate = log.date
        let originalType = log.careType
        let originalSummaryDates = summaryDates(for: plant)
        let originalGroup = summaryGroup(for: originalType)
        let newGroup = summaryGroup(for: intent.careType)
        let affectedGroups = Set([originalGroup, newGroup].compactMap(\.self))
        var remainingSummaryDates: [SummaryGroup: Date] = [:]
        do {
            for group in affectedGroups {
                if let remainingDate = try latestLogDate(
                    group: group,
                    plantID: plant.id,
                    excludingLogID: log.id,
                    context: context
                ) {
                    remainingSummaryDates[group] = remainingDate
                }
            }
        } catch {
            return .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        let originalLog = EditLogSnapshot(log: log)
        let editedSourceEvent: (event: Event, snapshot: EditEventSnapshot)?
        switch updateLinkedManualEvent(
            linkedManualEvent,
            requiresUpdate: sourceEventRequiresUpdate,
            plant: plant,
            intent: intent,
            context: context,
            options: options
        ) {
        case let .updated(value):
            editedSourceEvent = value
        case let .rejected(result):
            return result
        }
        log.date = intent.date
        log.careTypeRaw = intent.careType.rawValue
        log.note = normalizedNote
        log.healthStatus = intent.healthStatus
        if intent.photoMutation != .keep {
            log.updatePhotoData(replacementPhoto)
        }
        CloudSyncMutationRecorder.markModified(log, plant: plant, context: context, modifiedAt: intent.now)

        let correctionLedger = replaceLinkedLedgers(
            resolution.linkedLedgers,
            for: log,
            plant: plant,
            operationID: operationID,
            editedByHumanID: intent.editedByHumanID,
            now: intent.now,
            context: context
        )
        recomputeSummaryDatesAfterEdit(
            plant: plant,
            log: log,
            originalDate: originalDate,
            originalType: originalType,
            originalSummaryDates: originalSummaryDates,
            remainingSummaryDates: remainingSummaryDates
        )
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: intent.now)

        return commitHistoryEdit(
            intent,
            context: context,
            options: options,
            state: EditCommitState(
                log: log,
                plant: plant,
                correctionLedger: correctionLedger,
                originalLog: originalLog,
                editedSourceEvent: editedSourceEvent,
                originalSummaryDates: originalSummaryDates,
                originalDate: originalDate,
                originalType: originalType,
                linkedManualEvent: linkedManualEvent
            )
        )
    }

    @discardableResult
    static func delete(
        _ intent: PlantCareHistoryDeleteIntent,
        context: ModelContext
    ) -> PlantCareHistoryCommandResult {
        delete(intent, context: context, options: PlantCareHistoryCommandOptions())
    }

    @discardableResult
    static func delete(
        _ intent: PlantCareHistoryDeleteIntent,
        context: ModelContext,
        options: PlantCareHistoryCommandOptions
    ) -> PlantCareHistoryCommandResult {
        let recordID = intent.recordID
        let operationID = intent.operationID
        let log: PlantCareLog
        do {
            guard let fetched = try fetchLog(id: recordID.logID, context: context) else {
                return PlantCareHistoryCommandResult(
                    recordID: recordID,
                    operationID: operationID,
                    disposition: .alreadyDeleted,
                    failure: nil,
                    persistenceErrorDescription: nil,
                    ledgerEventID: nil,
                    affectedEntityIDs: []
                )
            }
            log = fetched
        } catch {
            return .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        guard let plant = log.plant, plant.id == recordID.plantID else {
            return .rejected(recordID: recordID, operationID: operationID, failure: .wrongPlant)
        }
        guard log.careTransactionId == intent.expectedCareTransactionID else {
            return .rejected(recordID: recordID, operationID: operationID, failure: .staleRecord)
        }

        let resolution: SourceResolution
        do {
            resolution = try resolveSource(for: log, context: context)
        } catch {
            return .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        guard resolution.source != .internalFeedback else {
            return .rejected(recordID: recordID, operationID: operationID, failure: .internalFeedback)
        }
        guard !hasPendingRewardSettlement(in: resolution.linkedLedgers) else {
            return .rejected(recordID: recordID, operationID: operationID, failure: .pendingRewardSettlement)
        }
        if resolution.source == .calendar || resolution.source == .reminder {
            return deleteScheduled(
                log: log,
                plant: plant,
                resolution: resolution,
                intent: intent,
                context: context,
                options: options
            )
        }
        return deleteManual(
            log: log,
            plant: plant,
            resolution: resolution,
            intent: intent,
            context: context,
            options: options
        )
    }

    struct ScheduledReopen {
        let syncResult: PlantCareScheduleSyncResult
        let reminder: Reminder?
        let financialAudit: CareLedgerEvent?
    }

    enum ScheduledReopenOutcome {
        case completed(ScheduledReopen)
        case rejected(PlantCareHistoryCommandResult)
    }

    private static func reopenReminderSource(
        event: Event,
        ledger: CareLedgerEvent,
        linkedLedgers: [CareLedgerEvent],
        log: PlantCareLog,
        plant: Plant,
        intent: PlantCareHistoryDeleteIntent,
        context: ModelContext
    ) -> ScheduledReopenOutcome {
        guard let reminderIDRaw = ledger.sourceReminderId,
              let reminderID = UUID(uuidString: reminderIDRaw) else {
            return .rejected(.rejected(recordID: intent.recordID, operationID: intent.operationID, failure: .missingScheduleSource))
        }
        let reminder: Reminder
        do {
            guard let fetchedReminder = try fetchReminder(id: reminderID, context: context),
                  fetchedReminder.event?.id == event.id else {
                return .rejected(.rejected(recordID: intent.recordID, operationID: intent.operationID, failure: .missingScheduleSource))
            }
            reminder = fetchedReminder
        } catch {
            return .rejected(.rejected(
                recordID: intent.recordID,
                operationID: intent.operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: error.localizedDescription
            ))
        }
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .domainService,
            context: context
        ) else {
            return .rejected(.rejected(recordID: intent.recordID, operationID: intent.operationID, failure: .authorizationDenied))
        }
        normalizeLegacyScheduleSource(event: event, log: log, ledgers: linkedLedgers, context: context, now: intent.now)
        let financialAudit = recordPreservedFinancialEffectsAuditIfNeeded(
            linkedLedgers,
            log: log,
            plant: plant,
            operationID: intent.operationID,
            actorID: intent.deletedByHumanID,
            now: intent.now,
            context: context
        )
        guard DomainScheduleWriter.reopenReminder(
            reminder,
            mutation: mutation,
            reopenedBy: intent.deletedByHumanID,
            reopenedAt: intent.now,
            context: context
        ) else {
            context.rollback()
            return .rejected(.rejected(recordID: intent.recordID, operationID: intent.operationID, failure: .authorizationDenied))
        }
        let syncResult = PlantCareScheduleSyncService.syncReopenedReminder(
            reminder,
            executorId: intent.deletedByHumanID,
            context: context,
            now: intent.now,
            saveChanges: false
        )
        let careLedger: CareLedgerRecording = CareLedgerService()
        careLedger.recordReminderState(
            reminder: reminder,
            actionType: "reopen",
            actorId: intent.deletedByHumanID,
            source: .service,
            context: context,
            save: false
        )
        return .completed(ScheduledReopen(syncResult: syncResult, reminder: reminder, financialAudit: financialAudit))
    }

    private static func deleteScheduled(
        log: PlantCareLog,
        plant: Plant,
        resolution: SourceResolution,
        intent: PlantCareHistoryDeleteIntent,
        context: ModelContext,
        options: PlantCareHistoryCommandOptions
    ) -> PlantCareHistoryCommandResult {
        let recordID = intent.recordID
        guard let ledger = resolution.canonicalLedger else {
            return .rejected(recordID: recordID, operationID: intent.operationID, failure: .missingScheduleSource)
        }
        guard let eventIDRaw = ledger.sourceEventId,
              let eventID = UUID(uuidString: eventIDRaw) else {
            return .rejected(recordID: recordID, operationID: intent.operationID, failure: .scheduleSourceMismatch)
        }
        let event: Event
        do {
            guard let fetchedEvent = try fetchEvent(id: eventID, context: context) else {
                return .rejected(
                    recordID: recordID,
                    operationID: intent.operationID,
                    failure: .missingScheduleSource
                )
            }
            event = fetchedEvent
        } catch {
            return .rejected(
                recordID: recordID,
                operationID: intent.operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        guard isStructuredScheduleEvent(event, log: log, plant: plant) else {
            return .rejected(recordID: recordID, operationID: intent.operationID, failure: .scheduleSourceMismatch)
        }

        let reopened: ScheduledReopen
        let outcome = resolution.source == .reminder
            ? reopenReminderSource(
                event: event,
                ledger: ledger,
                linkedLedgers: resolution.linkedLedgers,
                log: log,
                plant: plant,
                intent: intent,
                context: context
            )
            : reopenCalendarSource(
                event: event,
                linkedLedgers: resolution.linkedLedgers,
                log: log,
                plant: plant,
                intent: intent,
                context: context
            )
        switch outcome {
        case let .completed(value):
            reopened = value
        case let .rejected(result):
            return result
        }
        guard reopened.syncResult.action == .removedCareFact else {
            context.rollback()
            return .rejected(recordID: recordID, operationID: intent.operationID, failure: .scheduleReopenFailed)
        }

        let planResult = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: intent.now,
            scheduleNotifications: options.scheduleNotifications,
            reminderScheduling: options.reminderScheduling,
            notifications: options.notifications,
            defaults: options.defaults,
            saveChanges: false
        )
        guard planResult.didPersist else {
            context.rollback()
            return .rejected(
                recordID: recordID,
                operationID: intent.operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: planResult.persistenceErrorDescription
            )
        }
        let saveResult = options.persistChanges(context)
        guard saveResult.didSave else {
            context.rollback()
            return .rejected(
                recordID: recordID,
                operationID: intent.operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        PlantCarePlanScheduleService.commitSideEffects(
            for: planResult,
            context: context,
            notifications: options.notifications,
            defaults: options.defaults
        )
        if options.scheduleNotifications, let reopenedReminder = reopened.reminder, reopenedReminder.scheduledAt > intent.now {
            let structuredScheduling = options.reminderScheduling ??
                DomainServiceDependencyRegistry.registeredReminderScheduling(
                    careLedger: CareLedgerService()
                )
            if let structuredScheduling {
                _ = PlantPlanPostCommitDispatcher.shared.dispatch(
                    reminderIDs: [reopenedReminder.id],
                    context: context,
                    reminderScheduling: structuredScheduling,
                    source: .service
                )
            } else {
                options.notifications.schedule(reminder: reopenedReminder)
            }
        }
        var affectedEntityIDs: Set<UUID> = [plant.id, log.id, event.id]
        affectedEntityIDs.formUnion(resolution.linkedLedgers.map(\.id))
        if let reopenedReminder = reopened.reminder { affectedEntityIDs.insert(reopenedReminder.id) }
        if let preservedFinancialAudit = reopened.financialAudit { affectedEntityIDs.insert(preservedFinancialAudit.id) }
        return deletedScheduledResult(
            intent: intent,
            ledgerEventID: reopened.financialAudit?.id ?? reopened.syncResult.ledgerEventID,
            affectedIDs: affectedEntityIDs
        )
    }
}

@MainActor
extension PlantCareHistoryCommandService {
    private struct ManualDeletePreparation {
        let originalSummaryDates: [SummaryGroup: Date]
        let remainingSummaryDate: Date?
        let linkedManualEvent: Event?
    }

    private static func prepareManualDelete(
        log: PlantCareLog,
        plant: Plant,
        resolution: SourceResolution,
        context: ModelContext
    ) throws -> ManualDeletePreparation {
        let originalSummaryDates = summaryDates(for: plant)
        let deletedGroup = summaryGroup(for: log.careType)
        let remainingSummaryDate: Date? = if let deletedGroup {
            try latestLogDate(
                group: deletedGroup,
                plantID: plant.id,
                excludingLogID: log.id,
                context: context
            )
        } else {
            nil
        }
        return ManualDeletePreparation(
            originalSummaryDates: originalSummaryDates,
            remainingSummaryDate: remainingSummaryDate,
            linkedManualEvent: try linkedManualSourceEvent(
                resolution: resolution,
                plant: plant,
                context: context
            )
        )
    }

    private static func manualDeletePreparationRejection(
        _ error: Error,
        intent: PlantCareHistoryDeleteIntent
    ) -> PlantCareHistoryCommandResult {
        if let lookupError = error as? LinkedEventLookupError {
            return linkedEventLookupRejection(
                lookupError,
                recordID: intent.recordID,
                operationID: intent.operationID
            )
        }
        return .rejected(
            recordID: intent.recordID,
            operationID: intent.operationID,
            failure: .persistenceFailed,
            persistenceErrorDescription: error.localizedDescription
        )
    }

    private static func deleteManual(
        log: PlantCareLog,
        plant: Plant,
        resolution: SourceResolution,
        intent: PlantCareHistoryDeleteIntent,
        context: ModelContext,
        options: PlantCareHistoryCommandOptions
    ) -> PlantCareHistoryCommandResult {
        let preparation: ManualDeletePreparation
        do {
            preparation = try prepareManualDelete(log: log, plant: plant, resolution: resolution, context: context)
        } catch {
            return manualDeletePreparationRejection(error, intent: intent)
        }
        let originalSummaryDates = preparation.originalSummaryDates
        let remainingSummaryDate = preparation.remainingSummaryDate
        let linkedManualEvent = preparation.linkedManualEvent
        var scheduleEffects = DomainSchedulePendingEffects.none
        var affectedIDs: Set<UUID> = [plant.id, log.id]
        if let event = linkedManualEvent {
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
                event: event,
                writeKind: .care,
                source: .domainService,
                context: context
            ) else {
                return .rejected(
                    recordID: intent.recordID,
                    operationID: intent.operationID,
                    failure: .authorizationDenied
                )
            }
            let deleted = DomainScheduleWriter.deleteEvent(
                event,
                mutation: mutation,
                context: context,
                deletedAt: intent.now,
                deletedByHumanId: intent.deletedByHumanID
            )
            guard deleted.didDelete else {
                context.rollback()
                return .rejected(
                    recordID: intent.recordID,
                    operationID: intent.operationID,
                    failure: .authorizationDenied
                )
            }
            scheduleEffects.stage(delete: deleted)
            if let eventID = deleted.eventID { affectedIDs.insert(eventID) }
            affectedIDs.formUnion(deleted.reminderIDs)
        }
        let auditLedger = recordPreservedFinancialEffectsAuditIfNeeded(
            resolution.linkedLedgers,
            log: log,
            plant: plant,
            operationID: intent.operationID,
            actorID: intent.deletedByHumanID,
            now: intent.now,
            context: context
        )
        for ledger in resolution.linkedLedgers {
            affectedIDs.insert(ledger.id)
            CloudSyncMutationRecorder.markDeleted(
                ledger,
                context: context,
                deletedAt: intent.now,
                deletedByHumanId: intent.deletedByHumanID
            )
            context.delete(ledger)
        }
        CloudSyncMutationRecorder.markDeleted(
            log,
            plant: plant,
            context: context,
            deletedAt: intent.now,
            deletedByHumanId: intent.deletedByHumanID
        )
        context.delete(log)
        recomputeSummaryDatesAfterDelete(
            plant: plant,
            deletedLogID: log.id,
            deletedDate: log.date,
            deletedType: log.careType,
            originalSummaryDates: originalSummaryDates,
            remainingSummaryDate: remainingSummaryDate
        )
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: intent.now)
        let planResult = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            now: intent.now,
            scheduleNotifications: options.scheduleNotifications,
            reminderScheduling: options.reminderScheduling,
            notifications: options.notifications,
            defaults: options.defaults,
            saveChanges: false
        )
        guard planResult.didPersist else {
            restoreSummaryDates(originalSummaryDates, on: plant)
            context.rollback()
            return .rejected(
                recordID: intent.recordID,
                operationID: intent.operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: planResult.persistenceErrorDescription
            )
        }
        let saveResult = options.persistChanges(context)
        guard saveResult.didSave else {
            restoreSummaryDates(originalSummaryDates, on: plant)
            context.rollback()
            return .rejected(
                recordID: intent.recordID,
                operationID: intent.operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        scheduleEffects.commit(notifications: options.notifications)
        PlantCarePlanScheduleService.commitSideEffects(
            for: planResult,
            context: context,
            notifications: options.notifications,
            defaults: options.defaults
        )
        if let auditLedger { affectedIDs.insert(auditLedger.id) }
        return deletedManualResult(intent: intent, auditLedgerID: auditLedger?.id, affectedIDs: affectedIDs)
    }

    private static func resolveSource(
        for log: PlantCareLog,
        context: ModelContext
    ) throws -> SourceResolution {
        let ledgers = try fetchLinkedLedgers(logID: log.id, context: context)
        if PlantCareHistoryPolicy.isInternalFeedback(log) {
            return SourceResolution(source: .internalFeedback, linkedLedgers: ledgers, canonicalLedger: canonicalLedger(in: ledgers))
        }
        var scheduleSourceByLedgerID: [UUID: PlantCareHistorySource] = [:]
        for ledger in ledgers {
            if let source = try scheduleSource(for: ledger, log: log, context: context) {
                scheduleSourceByLedgerID[ledger.id] = source
            }
        }
        let scheduleLedgers = ledgers.filter { scheduleSourceByLedgerID[$0.id] != nil }
        if let canonical = canonicalLedger(in: scheduleLedgers),
           let source = scheduleSourceByLedgerID[canonical.id] {
            return SourceResolution(source: source, linkedLedgers: ledgers, canonicalLedger: canonical)
        }
        return SourceResolution(
            source: ledgers.isEmpty ? .legacy : .manual,
            linkedLedgers: ledgers,
            canonicalLedger: canonicalLedger(in: ledgers)
        )
    }

    private static func scheduleSource(
        for ledger: CareLedgerEvent,
        log: PlantCareLog,
        context: ModelContext
    ) throws -> PlantCareHistorySource? {
        let hasReminderReference = !(ledger.sourceReminderId ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        if isScheduleCompletionLedger(ledger) {
            return hasReminderReference ? .reminder : .calendar
        }

        let declaredSource = CareLedgerSource(rawValue: ledger.source)
        let declaredScheduleSource: PlantCareHistorySource? = switch declaredSource {
        case .some(.reminder), .some(.notification):
            .reminder
        case .some(.calendar):
            .calendar
        case .some(.quickAction), .some(.detail), .some(.economy), .some(.backfill),
             .some(.service), .some(.importData), .none:
            nil
        }
        guard let sourceEventIDRaw = ledger.sourceEventId,
              let sourceEventID = UUID(uuidString: sourceEventIDRaw) else {
            return hasReminderReference ? .reminder : declaredScheduleSource
        }
        guard let event = try fetchEvent(id: sourceEventID, context: context) else {
            return hasReminderReference ? .reminder : declaredScheduleSource
        }
        guard let plant = log.plant,
              isStructuredScheduleEvent(event, log: log, plant: plant) else {
            return declaredScheduleSource
        }
        return hasReminderReference || declaredScheduleSource == .reminder ? .reminder : .calendar
    }

    private static func isStructuredScheduleEvent(
        _ event: Event,
        log: PlantCareLog,
        plant: Plant
    ) -> Bool {
        guard DomainEntityLinkRegistry.plantId(for: event) == plant.id,
              let expectedCareKind = TaskCareKind(plantCareType: log.careType) else {
            return false
        }
        if !event.taskCareKindRaw.isEmpty {
            return event.taskCareKindRaw == expectedCareKind.rawValue
        }
        return event.recurrenceDays > 0 &&
            event.isAllDay &&
            PlantCareScheduleSyncService.careType(for: event) == log.careType
    }

    static func normalizeLegacyScheduleSource(
        event: Event,
        log: PlantCareLog,
        ledgers: [CareLedgerEvent],
        context: ModelContext,
        now: Date
    ) {
        if event.taskCareKindRaw.isEmpty,
           let careKind = TaskCareKind(plantCareType: log.careType) {
            event.taskCareKindRaw = careKind.rawValue
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: now)
        }
        let sourceEventID = event.id.uuidString
        for ledger in ledgers where ledger.sourceEventId == sourceEventID && !isScheduleCompletionLedger(ledger) {
            ledger.metadataJSON = jsonAdding(true, forKey: "scheduleCompletion", to: ledger.metadataJSON)
            CloudSyncMutationRecorder.markModified(ledger, context: context, modifiedAt: now)
        }
    }

    private static func linkedManualSourceEvent(
        resolution: SourceResolution,
        plant: Plant,
        context: ModelContext
    ) throws -> Event? {
        guard resolution.source == .manual,
              let sourceEventIDRaw = resolution.canonicalLedger?.sourceEventId else {
            return nil
        }
        guard let sourceEventID = UUID(uuidString: sourceEventIDRaw) else {
            throw LinkedEventLookupError.mismatch
        }
        let event: Event?
        do {
            event = try fetchEvent(id: sourceEventID, context: context)
        } catch {
            throw LinkedEventLookupError.persistence(error.localizedDescription)
        }
        guard let event else { return nil }
        guard event.recurrenceDays <= 0,
              !PlantCarePlanScheduleService.isGeneratedCalendarPlan(event),
              DomainEntityLinkRegistry.plantId(for: event) == plant.id else {
            throw LinkedEventLookupError.mismatch
        }
        return event
    }

    private static func linkedEventLookupRejection(
        _ error: LinkedEventLookupError,
        recordID: PlantCareHistoryRecordID,
        operationID: UUID
    ) -> PlantCareHistoryCommandResult {
        switch error {
        case .mismatch:
            .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .scheduleSourceMismatch
            )
        case let .persistence(description):
            .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: description
            )
        }
    }

    private static func manualSourceEventIntent(
        event: Event,
        plant: Plant,
        date: Date,
        careType: PlantCareType,
        defaults: UserDefaults
    ) -> DomainScheduleCreateIntent {
        let duration = event.endDate.map { max(0, $0.timeIntervalSince(event.startDate)) }
        let taskCareKindRaw = event.taskCareKindRaw.isEmpty
            ? ""
            : TaskCareKind(plantCareType: careType)?.rawValue ?? ""
        return DomainScheduleCreateIntent(
            title: manualSourceEventTitle(
                careType: careType,
                plant: plant,
                defaults: defaults
            ),
            startDate: date,
            endDate: duration.map { date.addingTimeInterval($0) },
            isAllDay: event.isAllDay,
            eventType: careType.eventType.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: plant.id.uuidString,
            recurrenceDays: event.recurrenceDays,
            recurrenceEndDate: event.recurrenceEndDate,
            assigneeId: event.assigneeId,
            taskCareKindRaw: taskCareKindRaw,
            familyTaskPlanId: event.familyTaskPlanId,
            familyTaskOccurrenceKey: event.familyTaskOccurrenceKey,
            writeKind: .care,
            source: .domainService
        )
    }

    private static func manualSourceEventTitle(
        careType: PlantCareType,
        plant: Plant,
        defaults: UserDefaults
    ) -> String {
        let l = L10n.current
        let careTypeName = careType.displayName(l: l)
        let title = l.tr(
            zh: "给 \(plant.name)\(careTypeName)",
            en: "\(careTypeName) for \(plant.name)",
            de: "\(careTypeName) für \(plant.name)"
        )
        return "\(careType.emoji) \(title)\(manualSafetyReminderSuffix(for: plant, defaults: defaults))"
    }

    private static func manualSafetyReminderSuffix(
        for plant: Plant,
        defaults: UserDefaults
    ) -> String {
        let hasPets = defaults.object(forKey: "ohana_onboarding_has_pets") == nil
            ? true
            : defaults.bool(forKey: "ohana_onboarding_has_pets")
        let hasChildren = defaults.bool(forKey: "ohana_onboarding_has_children")
        if hasPets, plant.isToxicToCats || plant.isToxicToDogs {
            return " · \(L10n.current.tr(zh: "放到宠物够不到处", en: "Keep out of pets' reach", de: "Außer Reichweite von Haustieren"))"
        }
        if hasChildren, plant.isToxicToChildren {
            return " · \(L10n.current.tr(zh: "注意儿童误食", en: "Watch for child ingestion", de: "Auf Verschlucken durch Kinder achten"))"
        }
        return ""
    }

    private static func fetchLog(id: UUID, context: ModelContext) throws -> PlantCareLog? {
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in log.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchEvent(id: UUID, context: ModelContext) throws -> Event? {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in event.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchReminder(id: UUID, context: ModelContext) throws -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in reminder.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchLinkedLedgers(
        logID: UUID,
        context: ModelContext
    ) throws -> [CareLedgerEvent] {
        let modelName = String(describing: PlantCareLog.self)
        let modelID = logID.uuidString
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.legacyModelName == modelName && ledger.legacyModelId == modelID
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 32
        return try context.fetch(descriptor)
    }

    private static func isScheduleCompletionLedger(_ ledger: CareLedgerEvent) -> Bool {
        CalendarTaskCompletionSyncService.metadataDictionary(
            from: ledger.metadataJSON
        )["scheduleCompletion"] as? Bool == true
    }

    private static func hasPendingRewardSettlement(in ledgers: [CareLedgerEvent]) -> Bool {
        ledgers.contains { ledger in
            CareLedgerMetadata.stringValue(
                named: PlantCareCommandService.rewardStateMetadataKey,
                in: ledger.metadataJSON
            ) == PlantCareCommandService.rewardStatePending
        }
    }

    private static func canonicalLedger(in ledgers: [CareLedgerEvent]) -> CareLedgerEvent? {
        ledgers.sorted { lhs, rhs in
            let lhsSchedule = isScheduleCompletionLedger(lhs)
            let rhsSchedule = isScheduleCompletionLedger(rhs)
            if lhsSchedule != rhsSchedule { return lhsSchedule }
            let lhsReward = lhs.coconutDelta != 0 || lhs.rewardLogId != nil
            let rhsReward = rhs.coconutDelta != 0 || rhs.rewardLogId != nil
            if lhsReward != rhsReward { return lhsReward }
            return lhs.createdAt > rhs.createdAt
        }.first
    }
}

@MainActor
extension PlantCareHistoryCommandService {
    private static func replaceLinkedLedgers(
        _ linkedLedgers: [CareLedgerEvent],
        for log: PlantCareLog,
        plant: Plant,
        operationID: UUID,
        editedByHumanID: String?,
        now: Date,
        context: ModelContext
    ) -> CareLedgerEvent {
        let source = canonicalLedger(in: linkedLedgers)
        for ledger in linkedLedgers {
            CloudSyncMutationRecorder.markDeleted(
                ledger,
                context: context,
                deletedAt: now,
                deletedByHumanId: editedByHumanID
            )
            context.delete(ledger)
        }
        let metadata = correctionMetadata(
            source?.metadataJSON ?? "",
            operationID: operationID,
            transactionID: log.careTransactionId,
            kind: "edit",
            preservedCoconutDelta: source?.coconutDelta ?? 0
        )
        let careLedger: CareLedgerRecording = CareLedgerService()
        return careLedger.record(
            occurredAt: log.date,
            actorKind: CareLedgerActorKind(rawValue: source?.actorKind ?? "") ?? (log.executorId == nil ? .unknown : .human),
            actorId: source?.actorId ?? log.executorId,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: log.careType.rawValue,
            amountValue: source?.amountValue ?? 0,
            amountUnit: source?.amountUnit ?? "",
            note: log.note,
            source: CareLedgerSource(rawValue: source?.source ?? "") ?? .backfill,
            sourceEventId: source?.sourceEventId,
            sourceReminderId: source?.sourceReminderId,
            legacyModelName: String(describing: PlantCareLog.self),
            legacyModelId: log.id.uuidString,
            coconutDelta: source?.coconutDelta ?? 0,
            rewardLogId: source?.rewardLogId,
            privacyFieldRaw: source?.privacyFieldRaw,
            metadataJSON: metadata,
            context: context,
            save: false
        )
    }

    static func recordPreservedFinancialEffectsAuditIfNeeded(
        _ linkedLedgers: [CareLedgerEvent],
        log: PlantCareLog,
        plant: Plant,
        operationID: UUID,
        actorID: String?,
        now: Date,
        context: ModelContext
    ) -> CareLedgerEvent? {
        let preservedCoconutDelta = linkedLedgers.reduce(0) { $0 + $1.coconutDelta }
        let rewardIDs = linkedLedgers.compactMap(\.rewardLogId).filter { !$0.isEmpty }
        let hasSettledRewardReceipt = linkedLedgers.contains { ledger in
            CareLedgerMetadata.stringValue(
                named: PlantCareCommandService.rewardStateMetadataKey,
                in: ledger.metadataJSON
            ) == PlantCareCommandService.rewardStateSettled
        }
        guard preservedCoconutDelta != 0 || !rewardIDs.isEmpty || hasSettledRewardReceipt else { return nil }
        var metadata = correctionMetadata(
            "",
            operationID: operationID,
            transactionID: log.careTransactionId,
            kind: "delete",
            preservedCoconutDelta: preservedCoconutDelta
        )
        if !rewardIDs.isEmpty {
            metadata = jsonAdding(rewardIDs, forKey: "preservedRewardLogIds", to: metadata)
        }
        let careLedger: CareLedgerRecording = CareLedgerService()
        return careLedger.record(
            occurredAt: now,
            actorKind: actorID == nil ? .unknown : .human,
            actorId: actorID,
            subjectKind: .plant,
            subjectId: plant.id.uuidString,
            eventKind: .plantCare,
            actionType: "historyDeleted",
            amountValue: 0,
            amountUnit: "",
            note: "Plant care history deleted; prior reward and budget effects remain unchanged.",
            source: .service,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: nil,
            legacyModelId: nil,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadata,
            context: context,
            save: false
        )
    }

    private static func summaryGroup(for type: PlantCareType) -> SummaryGroup? {
        switch type {
        case .watering:
            .watering
        case .fertilizing:
            .fertilizing
        case .pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote:
            .health
        case .repotting, .pruning, .misting, .rotating, .leafCleaning:
            nil
        }
    }

    private static func summaryDates(for plant: Plant) -> [SummaryGroup: Date] {
        var values: [SummaryGroup: Date] = [:]
        if let date = plant.lastWateredDate { values[.watering] = date }
        if let date = plant.lastFertilizedDate { values[.fertilizing] = date }
        if let date = plant.lastHealthCheckDate { values[.health] = date }
        return values
    }

    static func restoreSummaryDates(_ dates: [SummaryGroup: Date], on plant: Plant) {
        for group in SummaryGroup.allCases {
            setSummaryDate(dates[group], group: group, plant: plant)
        }
    }

    private static func setSummaryDate(_ date: Date?, group: SummaryGroup, plant: Plant) {
        switch group {
        case .watering:
            plant.lastWateredDate = date
        case .fertilizing:
            plant.lastFertilizedDate = date
        case .health:
            plant.lastHealthCheckDate = date
        }
    }

    private static func latestLogDate(
        group: SummaryGroup,
        plantID: UUID,
        excludingLogID: UUID,
        context: ModelContext
    ) throws -> Date? {
        let careTypes: [PlantCareType] = switch group {
        case .watering:
            [.watering]
        case .fertilizing:
            [.fertilizing]
        case .health:
            [.pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote]
        }

        var latestDate: Date?
        for careType in careTypes {
            var descriptor = visibleSummaryLogDescriptor(
                plantID: plantID,
                careType: careType,
                excludingLogID: excludingLogID
            )
            descriptor.fetchLimit = 1
            if let date = try context.fetch(descriptor).first?.date,
               latestDate == nil || date > latestDate! {
                latestDate = date
            }
        }
        return latestDate
    }

    private static func visibleSummaryLogDescriptor(
        plantID: UUID,
        careType: PlantCareType,
        excludingLogID: UUID
    ) -> FetchDescriptor<PlantCareLog> {
        let typeRaw = careType.rawValue
        let sortBy = [SortDescriptor(\PlantCareLog.date, order: .reverse)]
        guard careType == .customNote else {
            return FetchDescriptor<PlantCareLog>(
                predicate: #Predicate<PlantCareLog> { log in
                    log.plant?.id == plantID &&
                        log.careTypeRaw == typeRaw &&
                        log.id != excludingLogID
                },
                sortBy: sortBy
            )
        }

        let deferPrefix = PlantCareHistoryPolicy.internalDeferPrefix
        let skipPrefix = PlantCareHistoryPolicy.internalSkipPrefix
        return FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.plant?.id == plantID &&
                    log.careTypeRaw == typeRaw &&
                    log.id != excludingLogID &&
                    !log.note.starts(with: deferPrefix) &&
                    !log.note.starts(with: skipPrefix)
            },
            sortBy: sortBy
        )
    }

    private static func recomputeSummaryDatesAfterEdit(
        plant: Plant,
        log: PlantCareLog,
        originalDate: Date,
        originalType: PlantCareType,
        originalSummaryDates: [SummaryGroup: Date],
        remainingSummaryDates: [SummaryGroup: Date]
    ) {
        let originalGroup = summaryGroup(for: originalType)
        let newGroup = summaryGroup(for: log.careType)
        let affectedGroups = Set([originalGroup, newGroup].compactMap(\.self))
        for group in affectedGroups {
            let remainingDate = remainingSummaryDates[group]
            var projection: Date? = if group == originalGroup, originalSummaryDates[group] == originalDate {
                remainingDate
            } else {
                maxDate(originalSummaryDates[group], remainingDate)
            }
            if group == newGroup {
                projection = maxDate(projection, log.date)
            }
            setSummaryDate(projection, group: group, plant: plant)
        }
    }

    private static func recomputeSummaryDatesAfterDelete(
        plant: Plant,
        deletedLogID: UUID,
        deletedDate: Date,
        deletedType: PlantCareType,
        originalSummaryDates: [SummaryGroup: Date],
        remainingSummaryDate: Date?
    ) {
        guard let group = summaryGroup(for: deletedType),
              originalSummaryDates[group] == deletedDate else { return }
        setSummaryDate(
            remainingSummaryDate,
            group: group,
            plant: plant
        )
    }
}
