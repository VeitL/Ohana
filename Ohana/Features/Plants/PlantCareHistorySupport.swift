//
//  PlantCareHistorySupport.swift
//  Ohana
//

import Foundation
import SwiftData

nonisolated struct PlantCareHistoryRecordID: Hashable, Sendable {
    let plantID: UUID
    let logID: UUID
}

nonisolated enum PlantCareHistorySource: String, Equatable, Sendable {
    case manual
    case legacy
    case calendar
    case reminder
    case internalFeedback

    var locksSourceFields: Bool {
        self == .calendar || self == .reminder
    }
}

nonisolated enum PlantCareHistoryPhotoMutation: Equatable, Sendable {
    case keep
    case remove
    case replace(Data)
}

nonisolated struct PlantCareHistoryEditIntent: Equatable, Sendable {
    let recordID: PlantCareHistoryRecordID
    let operationID: UUID
    let expectedCareTransactionID: String
    let date: Date
    let careType: PlantCareType
    let note: String
    let healthStatus: PlantHealthStatus?
    let photoMutation: PlantCareHistoryPhotoMutation
    let editedByHumanID: String?
    let now: Date

    init(
        recordID: PlantCareHistoryRecordID,
        operationID: UUID = UUID(),
        expectedCareTransactionID: String,
        date: Date,
        careType: PlantCareType,
        note: String,
        healthStatus: PlantHealthStatus?,
        photoMutation: PlantCareHistoryPhotoMutation = .keep,
        editedByHumanID: String?,
        now: Date = Date()
    ) {
        self.recordID = recordID
        self.operationID = operationID
        self.expectedCareTransactionID = expectedCareTransactionID
        self.date = date
        self.careType = careType
        self.note = note
        self.healthStatus = healthStatus
        self.photoMutation = photoMutation
        self.editedByHumanID = editedByHumanID
        self.now = now
    }
}

nonisolated struct PlantCareHistoryDeleteIntent: Equatable, Sendable {
    let recordID: PlantCareHistoryRecordID
    let operationID: UUID
    let expectedCareTransactionID: String
    let deletedByHumanID: String?
    let now: Date

    init(
        recordID: PlantCareHistoryRecordID,
        operationID: UUID = UUID(),
        expectedCareTransactionID: String,
        deletedByHumanID: String?,
        now: Date = Date()
    ) {
        self.recordID = recordID
        self.operationID = operationID
        self.expectedCareTransactionID = expectedCareTransactionID
        self.deletedByHumanID = deletedByHumanID
        self.now = now
    }
}

nonisolated struct PlantCareHistoryRecordSnapshot: Identifiable, Equatable, Sendable {
    var id: PlantCareHistoryRecordID { recordID }

    let recordID: PlantCareHistoryRecordID
    let date: Date
    let careType: PlantCareType
    let note: String
    let executorID: String?
    let careTransactionID: String
    let healthStatus: PlantHealthStatus?
    let hasPhoto: Bool
    let source: PlantCareHistorySource

    var sourceFieldsAreLocked: Bool { source.locksSourceFields }
}

nonisolated enum PlantCareHistoryCommandDisposition: String, Equatable, Sendable {
    case updated
    case unchanged
    case deleted
    case alreadyDeleted
    case rejected
}

nonisolated enum PlantCareHistoryCommandFailure: String, Error, Equatable, Sendable {
    case missingRecord
    case wrongPlant
    case staleRecord
    case internalFeedback
    case reservedFeedbackNote
    case futureDate
    case sourceFieldsLocked
    case pendingRewardSettlement
    case missingScheduleSource
    case scheduleSourceMismatch
    case scheduleReopenFailed
    case rewardedScheduleUnsupported
    case authorizationDenied
    case persistenceFailed
}

extension PlantCareHistoryCommandFailure: LocalizedError {
    nonisolated var errorDescription: String? { rawValue }
}

nonisolated struct PlantCareHistoryCommandResult: Equatable, Sendable {
    let recordID: PlantCareHistoryRecordID
    let operationID: UUID
    let disposition: PlantCareHistoryCommandDisposition
    let failure: PlantCareHistoryCommandFailure?
    let persistenceErrorDescription: String?
    let ledgerEventID: UUID?
    let affectedEntityIDs: Set<UUID>

    var didPersist: Bool {
        failure == nil
    }

    var didWrite: Bool {
        didPersist && (disposition == .updated || disposition == .deleted)
    }

    static func rejected(
        recordID: PlantCareHistoryRecordID,
        operationID: UUID,
        failure: PlantCareHistoryCommandFailure,
        persistenceErrorDescription: String? = nil
    ) -> PlantCareHistoryCommandResult {
        PlantCareHistoryCommandResult(
            recordID: recordID,
            operationID: operationID,
            disposition: .rejected,
            failure: failure,
            persistenceErrorDescription: persistenceErrorDescription,
            ledgerEventID: nil,
            affectedEntityIDs: []
        )
    }
}

@MainActor
struct PlantCareHistoryCommandOptions {
    var scheduleNotifications = true
    var reminderScheduling: ReminderSchedulingManaging?
    var notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    var defaults: UserDefaults = .standard
    var persistChanges: (ModelContext) -> ModelContextSaveResult = { context in
        context.safeSaveResult(publishFailureEvent: true)
    }
}

nonisolated enum PlantCareHistoryPolicy {
    static let internalDeferPrefix = "defer:"
    static let internalSkipPrefix = "skip:"

    static func isInternalFeedback(careType: PlantCareType, note: String) -> Bool {
        guard careType == .customNote else { return false }
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix(internalDeferPrefix) || normalized.hasPrefix(internalSkipPrefix)
    }

    static func isInternalFeedback(_ log: PlantCareLog) -> Bool {
        isInternalFeedback(careType: log.careType, note: log.note)
    }
}

@MainActor
extension PlantCareHistoryCommandService {
    enum EditValuesOutcome {
        case changed(note: String, photo: Data?)
        case unchanged(PlantCareHistoryCommandResult)
        case rejected(PlantCareHistoryCommandResult)
    }

    static func prepareEditValues(
        _ intent: PlantCareHistoryEditIntent,
        log: PlantCareLog,
        sourceEventRequiresUpdate: Bool,
        canonicalLedgerID: UUID?
    ) -> EditValuesOutcome {
        let replacementPhoto: Data? = switch intent.photoMutation {
        case .keep, .remove:
            nil
        case let .replace(data):
            AttachmentPrivacySanitizer.sanitizedData(
                data,
                filename: "plant-care-history.jpg",
                isImage: true
            )
        }
        let normalizedNote = intent.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !PlantCareHistoryPolicy.isInternalFeedback(
            careType: intent.careType,
            note: normalizedNote
        ) else {
            return .rejected(.rejected(
                recordID: intent.recordID,
                operationID: intent.operationID,
                failure: .reservedFeedbackNote
            ))
        }
        let photoIsUnchanged: Bool = switch intent.photoMutation {
        case .keep:
            true
        case .remove:
            !log.hasPhotoAttachment
        case .replace:
            log.photoData == replacementPhoto
        }
        guard log.date != intent.date ||
                log.careType != intent.careType ||
                log.note != normalizedNote ||
                log.healthStatus != intent.healthStatus ||
                !photoIsUnchanged ||
                sourceEventRequiresUpdate else {
            return .unchanged(PlantCareHistoryCommandResult(
                recordID: intent.recordID,
                operationID: intent.operationID,
                disposition: .unchanged,
                failure: nil,
                persistenceErrorDescription: nil,
                ledgerEventID: canonicalLedgerID,
                affectedEntityIDs: []
            ))
        }
        return .changed(note: normalizedNote, photo: replacementPhoto)
    }

    struct EditCommitState {
        let log: PlantCareLog
        let plant: Plant
        let correctionLedger: CareLedgerEvent
        let originalLog: EditLogSnapshot
        let editedSourceEvent: (event: Event, snapshot: EditEventSnapshot)?
        let originalSummaryDates: [SummaryGroup: Date]
        let originalDate: Date
        let originalType: PlantCareType
        let linkedManualEvent: Event?
    }

    static func commitHistoryEdit(
        _ intent: PlantCareHistoryEditIntent,
        context: ModelContext,
        options: PlantCareHistoryCommandOptions,
        state: EditCommitState
    ) -> PlantCareHistoryCommandResult {
        let recordID = intent.recordID
        let operationID = intent.operationID
        let log = state.log
        let plant = state.plant
        let correctionLedger = state.correctionLedger
        let originalLog = state.originalLog
        let editedSourceEvent = state.editedSourceEvent
        let originalSummaryDates = state.originalSummaryDates
        let originalDate = state.originalDate
        let originalType = state.originalType
        let linkedManualEvent = state.linkedManualEvent
        let shouldSyncPlan = originalDate != intent.date || originalType != intent.careType
        let planResult = shouldSyncPlan
            ? PlantCarePlanScheduleService.sync(
                plant: plant,
                context: context,
                now: intent.now,
                scheduleNotifications: options.scheduleNotifications,
                reminderScheduling: options.reminderScheduling,
                notifications: options.notifications,
                defaults: options.defaults,
                saveChanges: false
            )
            : .empty(plantID: plant.id)
        guard planResult.didPersist else {
            originalLog.restore(on: log)
            if let editedSourceEvent {
                editedSourceEvent.snapshot.restore(on: editedSourceEvent.event)
            }
            restoreSummaryDates(originalSummaryDates, on: plant)
            context.rollback()
            return .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: planResult.persistenceErrorDescription
            )
        }

        let saveResult = options.persistChanges(context)
        guard saveResult.didSave else {
            originalLog.restore(on: log)
            if let editedSourceEvent {
                editedSourceEvent.snapshot.restore(on: editedSourceEvent.event)
            }
            restoreSummaryDates(originalSummaryDates, on: plant)
            context.rollback()
            return .rejected(
                recordID: recordID,
                operationID: operationID,
                failure: .persistenceFailed,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        if shouldSyncPlan {
            PlantCarePlanScheduleService.commitSideEffects(
                for: planResult,
                context: context,
                notifications: options.notifications,
                defaults: options.defaults
            )
        }
        var affectedEntityIDs: Set<UUID> = [plant.id, log.id, correctionLedger.id]
        if let linkedManualEvent { affectedEntityIDs.insert(linkedManualEvent.id) }
        return PlantCareHistoryCommandResult(
            recordID: recordID,
            operationID: operationID,
            disposition: .updated,
            failure: nil,
            persistenceErrorDescription: nil,
            ledgerEventID: correctionLedger.id,
            affectedEntityIDs: affectedEntityIDs
        )
    }

    static func deletedScheduledResult(
        intent: PlantCareHistoryDeleteIntent,
        ledgerEventID: UUID?,
        affectedIDs: Set<UUID>
    ) -> PlantCareHistoryCommandResult {
        PlantCareHistoryCommandResult(
            recordID: intent.recordID,
            operationID: intent.operationID,
            disposition: .deleted,
            failure: nil,
            persistenceErrorDescription: nil,
            ledgerEventID: ledgerEventID,
            affectedEntityIDs: affectedIDs
        )
    }

    static func reopenCalendarSource(
        event: Event,
        linkedLedgers: [CareLedgerEvent],
        log: PlantCareLog,
        plant: Plant,
        intent: PlantCareHistoryDeleteIntent,
        context: ModelContext
    ) -> ScheduledReopenOutcome {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
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
        guard DomainScheduleWriter.setEventOccurrenceCompletion(
            event,
            occurrenceDate: log.date,
            isCompleted: false,
            mutation: mutation,
            context: context,
            modifiedAt: intent.now
        ) else {
            context.rollback()
            return .rejected(.rejected(recordID: intent.recordID, operationID: intent.operationID, failure: .authorizationDenied))
        }
        let syncResult = PlantCareScheduleSyncService.syncReopenedEvent(
            event,
            occurrenceDate: log.date,
            executorId: intent.deletedByHumanID,
            context: context,
            now: intent.now,
            saveChanges: false
        )
        return .completed(ScheduledReopen(syncResult: syncResult, reminder: nil, financialAudit: financialAudit))
    }

    static func deletedManualResult(
        intent: PlantCareHistoryDeleteIntent,
        auditLedgerID: UUID?,
        affectedIDs: Set<UUID>
    ) -> PlantCareHistoryCommandResult {
        PlantCareHistoryCommandResult(
            recordID: intent.recordID,
            operationID: intent.operationID,
            disposition: .deleted,
            failure: nil,
            persistenceErrorDescription: nil,
            ledgerEventID: auditLedgerID,
            affectedEntityIDs: affectedIDs
        )
    }

    static func correctionMetadata(
        _ existing: String,
        operationID: UUID,
        transactionID: String,
        kind: String,
        preservedCoconutDelta: Int
    ) -> String {
        var object = metadataObject(from: existing)
        object["historyCorrection"] = true
        object["historyCorrectionKind"] = kind
        object["historyCorrectionOperationId"] = operationID.uuidString
        object["historyFinancialEffectsPreserved"] = true
        object["preservedCoconutDelta"] = preservedCoconutDelta
        if !transactionID.isEmpty {
            object[CareLedgerMetadata.careTransactionId] = transactionID
        }
        return encodedMetadata(object, fallback: existing)
    }

    static func metadataObject(from metadataJSON: String) -> [String: Any] {
        let trimmed = metadataJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["legacyMetadata": metadataJSON]
        }
        return object
    }

    static func jsonAdding(_ value: Any, forKey key: String, to metadataJSON: String) -> String {
        var object = metadataObject(from: metadataJSON)
        object[key] = value
        return encodedMetadata(object, fallback: metadataJSON)
    }

    static func encodedMetadata(_ object: [String: Any], fallback: String) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return fallback }
        return json
    }

    static func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): max(lhs, rhs)
        case let (lhs?, nil): lhs
        case let (nil, rhs?): rhs
        case (nil, nil): nil
        }
    }

    struct EditEventSnapshot {
        let title: String
        let startDate: Date
        let endDate: Date?
        let isAllDay: Bool
        let eventType: String
        let taskCareKindRaw: String
        let relatedEntityType: String
        let relatedEntityId: String
        let recurrenceDays: Int
        let recurrenceEndDate: Date?
        let assigneeId: String?
        let familyTaskPlanId: String?
        let familyTaskOccurrenceKey: String?

        init(event: Event) {
            title = event.title
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
            eventType = event.eventType
            taskCareKindRaw = event.taskCareKindRaw
            relatedEntityType = event.relatedEntityType
            relatedEntityId = event.relatedEntityId
            recurrenceDays = event.recurrenceDays
            recurrenceEndDate = event.recurrenceEndDate
            assigneeId = event.assigneeId
            familyTaskPlanId = event.familyTaskPlanId
            familyTaskOccurrenceKey = event.familyTaskOccurrenceKey
        }

        func restore(on event: Event) {
            event.title = title
            event.startDate = startDate
            event.endDate = endDate
            event.isAllDay = isAllDay
            event.eventType = eventType
            event.taskCareKindRaw = taskCareKindRaw
            event.relatedEntityType = relatedEntityType
            event.relatedEntityId = relatedEntityId
            event.recurrenceDays = recurrenceDays
            event.recurrenceEndDate = recurrenceEndDate
            event.assigneeId = assigneeId
            event.familyTaskPlanId = familyTaskPlanId
            event.familyTaskOccurrenceKey = familyTaskOccurrenceKey
        }
    }

    struct EditLogSnapshot {
        let date: Date
        let careTypeRaw: String
        let note: String
        let healthStatusRaw: String
        let photoData: Data?
        let photoAttachmentStateRaw: String
        let photoImageSignature: String

        init(log: PlantCareLog) {
            date = log.date
            careTypeRaw = log.careTypeRaw
            note = log.note
            healthStatusRaw = log.healthStatusRaw
            photoData = log.photoData
            photoAttachmentStateRaw = log.photoAttachmentStateRaw
            photoImageSignature = log.photoImageSignature
        }

        func restore(on log: PlantCareLog) {
            log.date = date
            log.careTypeRaw = careTypeRaw
            log.note = note
            log.healthStatusRaw = healthStatusRaw
            log.photoData = photoData
            log.photoAttachmentStateRaw = photoAttachmentStateRaw
            log.photoImageSignature = photoImageSignature
        }
    }
}

@MainActor
extension PlantCareCommandExecutor {
    @discardableResult
    func editHistory(
        _ intent: PlantCareHistoryEditIntent,
        note: String
    ) -> PlantCareHistoryCommandResult {
        editHistory(intent, note: note, options: PlantCareHistoryCommandOptions())
    }

    @discardableResult
    func editHistory(
        _ intent: PlantCareHistoryEditIntent,
        note: String,
        options: PlantCareHistoryCommandOptions
    ) -> PlantCareHistoryCommandResult {
        let result = PlantCareHistoryCommandService.edit(intent, context: context, options: options)
        if result.didWrite {
            revisions.publish(
                DomainMutationResult(
                    command: .plantCare(plantID: intent.recordID.plantID, action: "historyEdit"),
                    affectedEntityIDs: result.affectedEntityIDs,
                    wroteBusinessFact: true,
                    note: note
                )
            )
        }
        return result
    }

    @discardableResult
    func deleteHistory(
        _ intent: PlantCareHistoryDeleteIntent,
        note: String
    ) -> PlantCareHistoryCommandResult {
        deleteHistory(intent, note: note, options: PlantCareHistoryCommandOptions())
    }

    @discardableResult
    func deleteHistory(
        _ intent: PlantCareHistoryDeleteIntent,
        note: String,
        options: PlantCareHistoryCommandOptions
    ) -> PlantCareHistoryCommandResult {
        let result = PlantCareHistoryCommandService.delete(intent, context: context, options: options)
        if result.didWrite {
            revisions.publish(
                DomainMutationResult(
                    command: .plantCare(plantID: intent.recordID.plantID, action: "historyDelete"),
                    affectedEntityIDs: result.affectedEntityIDs,
                    wroteBusinessFact: true,
                    note: note
                )
            )
        }
        return result
    }
}
