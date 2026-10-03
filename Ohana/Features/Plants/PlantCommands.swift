//
//  PlantCommands.swift
//  Ohana
//
//  Domain write boundaries for plant creation and plant care.
//

import Foundation
import SwiftData

struct PlantCareCommandResult: Equatable, Sendable {
    let plantID: UUID
    let logID: UUID
    let eventID: UUID
    let ledgerEventID: UUID
    let careType: PlantCareType
    let coconutDelta: Int
    let didWrite: Bool
    let wasReplay: Bool
    let rewardFinalizationPending: Bool
    let didPersist: Bool
    let persistenceError: String?

    var affectedEntityIDs: Set<UUID> {
        didPersist && didWrite ? [plantID, logID, eventID, ledgerEventID] : []
    }

    static func failed(
        plantID: UUID,
        careType: PlantCareType,
        error: String
    ) -> PlantCareCommandResult {
        PlantCareCommandResult(
            plantID: plantID,
            logID: UUID(),
            eventID: UUID(),
            ledgerEventID: UUID(),
            careType: careType,
            coconutDelta: 0,
            didWrite: false,
            wasReplay: false,
            rewardFinalizationPending: false,
            didPersist: false,
            persistenceError: error
        )
    }
}

enum PlantCareCommandService {
    @discardableResult
    @MainActor
    static func recordCare(
        _ request: PlantCareCommandRequest,
        context: ModelContext,
        options: PlantCareCommandOptions,
        careTransactionId: String? = nil
    ) -> PlantCareCommandResult {
        let plant = request.plant
        let resolvedTransactionID = careTransactionId ?? request.operationID.uuidString
        if careTransactionId == nil,
           let replay = replayResultIfPresent(
               request: request,
               transactionID: resolvedTransactionID,
               context: context,
               options: options
           ) {
            return replay
        }
        guard !plant.isArchived else {
            return .failed(
                plantID: plant.id,
                careType: request.careType,
                error: "plantArchived"
            )
        }
        guard let plan = authorizedScheduleWrite(for: request, context: context) else {
            return .failed(
                plantID: plant.id,
                careType: request.careType,
                error: "plantCareAuthorizationDenied"
            )
        }

        let authorizedExecutorID = plan.intent.assigneeId
        let wasRewardEligible: Bool
        do {
            wasRewardEligible = try isRewardEligible(
                request.careType,
                for: plant,
                context: context,
                now: request.now
            )
        } catch {
            return .failed(
                plantID: plant.id,
                careType: request.careType,
                error: "plantCareRewardEligibilityLookupFailed: \(error.localizedDescription)"
            )
        }
        let originalCareFact = PlantCareFactSnapshot(plant: plant)
        applyCareFact(request)
        let persistedPhotoData = sanitizedPhotoData(for: request)
        let log = makeCareLog(
            request,
            authorizedExecutorID: authorizedExecutorID,
            photoData: persistedPhotoData,
            careTransactionId: resolvedTransactionID
        )
        log.plant = plant
        context.insert(log)
        CloudSyncMutationRecorder.markModified(plant, context: context, modifiedAt: request.now)

        let event = DomainScheduleWriter.createEvent(plan: plan, context: context).event
        let ledgerEvent = recordLedgerEvent(
            for: request,
            log: log,
            event: event,
            authorizedExecutorID: authorizedExecutorID,
            rewardState: rewardState(
                for: request.careType,
                wasEligible: wasRewardEligible,
                options: options
            ),
            context: context,
            options: options
        )
        let carePlanResult = syncCarePlanIfNeeded(for: request, context: context, options: options)
        if let carePlanResult, !carePlanResult.didPersist {
            originalCareFact.restore(on: plant)
            context.rollback()
            return persistenceFailureResult(
                for: request,
                log: log,
                event: event,
                ledgerEvent: ledgerEvent,
                errorDescription: carePlanResult.persistenceErrorDescription
            )
        }
        if options.saveChanges {
            let saveResult = options.persistChanges(context)
            guard saveResult.didSave else {
                originalCareFact.restore(on: plant)
                context.rollback()
                return persistenceFailureResult(
                    for: request,
                    log: log,
                    event: event,
                    ledgerEvent: ledgerEvent,
                    errorDescription: saveResult.errorDescription
                )
            }
            if let carePlanResult {
                PlantCarePlanScheduleService.commitSideEffects(
                    for: carePlanResult,
                    context: context
                )
            }
        }

        let rewardFinalization = options.saveChanges
            ? finalizeRewardIfNeeded(
                request: request,
                log: log,
                ledgerEvent: ledgerEvent,
                authorizedExecutorID: authorizedExecutorID,
                wasEligible: wasRewardEligible,
                context: context,
                options: options
            )
            : RewardFinalization(coconutDelta: 0, isPending: false, errorDescription: nil)

        return successResult(
            for: request,
            log: log,
            event: event,
            ledgerEvent: ledgerEvent,
            rewardFinalization: rewardFinalization
        )
    }

    private static func successResult(
        for request: PlantCareCommandRequest,
        log: PlantCareLog,
        event: Event,
        ledgerEvent: CareLedgerEvent,
        rewardFinalization: RewardFinalization
    ) -> PlantCareCommandResult {
        PlantCareCommandResult(
            plantID: request.plant.id,
            logID: log.id,
            eventID: event.id,
            ledgerEventID: ledgerEvent.id,
            careType: request.careType,
            coconutDelta: rewardFinalization.coconutDelta,
            didWrite: true,
            wasReplay: false,
            rewardFinalizationPending: rewardFinalization.isPending,
            didPersist: true,
            persistenceError: rewardFinalization.errorDescription
        )
    }

    @MainActor
    private static func syncCarePlanIfNeeded(
        for request: PlantCareCommandRequest,
        context: ModelContext,
        options: PlantCareCommandOptions
    ) -> PlantCarePlanScheduleResult? {
        guard options.syncCarePlan else { return nil }
        return PlantCarePlanScheduleService.sync(
            plant: request.plant,
            context: context,
            now: request.now,
            scheduleNotifications: options.scheduleNotifications,
            reminderScheduling: options.reminderScheduling,
            saveChanges: false
        )
    }

    private struct RewardFinalization {
        let coconutDelta: Int
        let isPending: Bool
        let errorDescription: String?
    }

    private struct PlantCareFactSnapshot {
        let lastWateredDate: Date?
        let lastFertilizedDate: Date?
        let lastHealthCheckDate: Date?
        let healthStatus: PlantHealthStatus

        init(plant: Plant) {
            lastWateredDate = plant.lastWateredDate
            lastFertilizedDate = plant.lastFertilizedDate
            lastHealthCheckDate = plant.lastHealthCheckDate
            healthStatus = plant.healthStatus
        }

        @MainActor
        func restore(on plant: Plant) {
            plant.lastWateredDate = lastWateredDate
            plant.lastFertilizedDate = lastFertilizedDate
            plant.lastHealthCheckDate = lastHealthCheckDate
            plant.healthStatus = healthStatus
        }
    }

    static let rewardStateMetadataKey = "plantCareRewardState"
    static let rewardStatePending = "pending"
    static let rewardStateSettled = "settled"
    static let rewardStateNotEligible = "notEligible"
    static let rewardStateDisabled = "disabled"
    static let rewardStateInvalid = "invalid"
    static let rewardOperationDateMetadataKey = "plantCareRewardOperationDate"

    @MainActor
    private static func replayResultIfPresent(
        request: PlantCareCommandRequest,
        transactionID: String,
        context: ModelContext,
        options: PlantCareCommandOptions
    ) -> PlantCareCommandResult? {
        var descriptor = FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.careTransactionId == transactionID
            },
            sortBy: [SortDescriptor(\PlantCareLog.date)]
        )
        descriptor.fetchLimit = 2
        let logs: [PlantCareLog]
        do {
            logs = try context.fetch(descriptor)
        } catch {
            return .failed(
                plantID: request.plant.id,
                careType: request.careType,
                error: "plantCareOperationLookupFailed: \(error.localizedDescription)"
            )
        }
        guard !logs.isEmpty else { return nil }
        guard logs.count == 1, let log = logs.first else {
            return .failed(
                plantID: request.plant.id,
                careType: request.careType,
                error: "plantCareOperationConflict"
            )
        }

        let replayLinks: PlantCareReplayLinks
        do {
            replayLinks = try validatedReplayLinks(
                log: log,
                request: request,
                transactionID: transactionID,
                context: context
            )
        } catch let failure as PlantCareReplayValidationFailure {
            return .failed(
                plantID: request.plant.id,
                careType: request.careType,
                error: failure.description
            )
        } catch {
            return .failed(
                plantID: request.plant.id,
                careType: request.careType,
                error: "plantCareOperationLookupFailed: \(error.localizedDescription)"
            )
        }

        let rewardIsPending = CareLedgerMetadata.stringValue(
            named: rewardStateMetadataKey,
            in: replayLinks.ledgerEvent.metadataJSON
        ) == rewardStatePending
        let finalization = rewardIsPending && options.awardRewards
            ? finalizeRewardIfNeeded(
                request: request,
                log: log,
                ledgerEvent: replayLinks.ledgerEvent,
                authorizedExecutorID: replayLinks.canonicalExecutorID,
                wasEligible: true,
                context: context,
                options: options
            )
            : RewardFinalization(
                coconutDelta: replayLinks.ledgerEvent.coconutDelta,
                isPending: rewardIsPending,
                errorDescription: nil
            )
        return PlantCareCommandResult(
            plantID: request.plant.id,
            logID: log.id,
            eventID: replayLinks.event.id,
            ledgerEventID: replayLinks.ledgerEvent.id,
            careType: log.careType,
            coconutDelta: finalization.coconutDelta,
            didWrite: false,
            wasReplay: true,
            rewardFinalizationPending: finalization.isPending,
            didPersist: true,
            persistenceError: finalization.errorDescription
        )
    }

    private struct PlantCareReplayLinks {
        let ledgerEvent: CareLedgerEvent
        let event: Event
        let canonicalExecutorID: String?
    }

    private enum PlantCareReplayValidationFailure: Error {
        case incomplete
        case conflict

        var description: String {
            switch self {
            case .incomplete:
                "plantCareOperationIncomplete"
            case .conflict:
                "plantCareOperationConflict"
            }
        }
    }

    @MainActor
    private static func validatedReplayLinks(
        log: PlantCareLog,
        request: PlantCareCommandRequest,
        transactionID: String,
        context: ModelContext
    ) throws -> PlantCareReplayLinks {
        guard let plant = log.plant else {
            throw PlantCareReplayValidationFailure.incomplete
        }
        guard replayPayloadMatches(log, plant: plant, request: request) else {
            throw PlantCareReplayValidationFailure.conflict
        }

        let requestedExecutorID = try resolvedReplayExecutorID(
            request.executorID,
            context: context
        )
        let persistedExecutorID = try canonicalPersistedExecutorID(log.executorId)
        guard persistedExecutorID == requestedExecutorID else {
            throw PlantCareReplayValidationFailure.conflict
        }

        let ledgers = try replayLedgerEvents(for: log, context: context)
        guard ledgers.count == 1, let ledgerEvent = ledgers.first else {
            throw PlantCareReplayValidationFailure.incomplete
        }
        let ledgerActorID = try canonicalPersistedExecutorID(ledgerEvent.actorId)
        let expectedActorKind = persistedExecutorID == nil
            ? CareLedgerActorKind.unknown.rawValue
            : CareLedgerActorKind.human.rawValue
        guard ledgerEvent.actorKind == expectedActorKind,
              ledgerActorID == persistedExecutorID,
              ledgerEvent.subjectKind == CareLedgerSubjectKind.plant.rawValue,
              ledgerEvent.subjectId == plant.id.uuidString,
              ledgerEvent.eventKind == CareLedgerEventKind.plantCare.rawValue,
              ledgerEvent.actionType == log.careType.rawValue,
              ledgerEvent.occurredAt == log.date,
              ledgerEvent.amountValue == 0,
              ledgerEvent.amountUnit.isEmpty,
              ledgerEvent.note == log.note,
              ledgerEvent.source == CareLedgerSource.detail.rawValue,
              ledgerEvent.sourceReminderId == nil,
              ledgerEvent.legacyModelName == String(describing: PlantCareLog.self),
              ledgerEvent.legacyModelId == log.id.uuidString else {
            throw PlantCareReplayValidationFailure.conflict
        }

        guard let metadataTransactionID = CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.careTransactionId,
            in: ledgerEvent.metadataJSON
        ),
        let rawRewardOperationDate = CareLedgerMetadata.stringValue(
            named: rewardOperationDateMetadataKey,
            in: ledgerEvent.metadataJSON
        ),
        let rewardOperationTimestamp = TimeInterval(rawRewardOperationDate),
        rewardOperationTimestamp.isFinite,
        let rewardState = CareLedgerMetadata.stringValue(
            named: rewardStateMetadataKey,
            in: ledgerEvent.metadataJSON
        ),
        [
            rewardStatePending,
            rewardStateSettled,
            rewardStateNotEligible,
            rewardStateDisabled,
            rewardStateInvalid
        ].contains(rewardState) else {
            throw PlantCareReplayValidationFailure.incomplete
        }
        guard metadataTransactionID == transactionID,
              Date(timeIntervalSince1970: rewardOperationTimestamp)
              .timeIntervalSince(request.rewardOperationDate).magnitude < 0.001 else {
            throw PlantCareReplayValidationFailure.conflict
        }
        let metadata = CalendarTaskCompletionSyncService.metadataDictionary(
            from: ledgerEvent.metadataJSON
        )
        if let generatedBy = metadata["generatedBy"] as? String,
           generatedBy != "PlantCareCommandService" {
            throw PlantCareReplayValidationFailure.conflict
        }

        guard let sourceEventID = ledgerEvent.sourceEventId.flatMap(UUID.init(uuidString:)) else {
            throw PlantCareReplayValidationFailure.incomplete
        }
        let events = try replayEvents(id: sourceEventID, context: context)
        guard events.count == 1, let event = events.first else {
            throw PlantCareReplayValidationFailure.incomplete
        }
        let eventAssigneeID = try canonicalPersistedExecutorID(event.assigneeId)
        guard event.relatedEntityType == EntityKind.plant.rawValue,
              event.relatedEntityId == plant.id.uuidString,
              event.eventType == log.careType.eventType.rawValue,
              event.startDate == log.date,
              event.recurrenceDays == 0,
              !event.isAllDay,
              eventAssigneeID == persistedExecutorID else {
            throw PlantCareReplayValidationFailure.conflict
        }

        return PlantCareReplayLinks(
            ledgerEvent: ledgerEvent,
            event: event,
            canonicalExecutorID: persistedExecutorID
        )
    }

    @MainActor
    private static func replayPayloadMatches(
        _ log: PlantCareLog,
        plant: Plant,
        request: PlantCareCommandRequest
    ) -> Bool {
        guard plant.id == request.plant.id,
              log.careType == request.careType,
              log.date == request.now,
              log.note == request.careNote,
              log.healthStatusRaw == (request.healthStatus?.rawValue ?? "") else {
            return false
        }
        let sanitizedPhotoSignature = sanitizedPhotoData(for: request)
            .map(MediaPayloadSignature.signature(for:)) ?? ""
        let alreadySanitizedPhotoSignature = request.photoData
            .map(MediaPayloadSignature.signature(for:)) ?? ""
        return log.photoImageSignature == sanitizedPhotoSignature ||
            log.photoImageSignature == alreadySanitizedPhotoSignature
    }

    @MainActor
    private static func replayLedgerEvents(
        for log: PlantCareLog,
        context: ModelContext
    ) throws -> [CareLedgerEvent] {
        let modelName = String(describing: PlantCareLog.self)
        let modelID = log.id.uuidString
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { ledger in
                ledger.legacyModelName == modelName && ledger.legacyModelId == modelID
            }
        )
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor)
    }

    @MainActor
    private static func replayEvents(
        id: UUID,
        context: ModelContext
    ) throws -> [Event] {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in event.id == id }
        )
        descriptor.fetchLimit = 2
        return try context.fetch(descriptor)
    }

    @MainActor
    private static func resolvedReplayExecutorID(
        _ requestedExecutorID: String?,
        context: ModelContext
    ) throws -> String? {
        guard let raw = requestedExecutorID?.trimmingCharacters(in: .whitespacesAndNewlines),
              let humanID = UUID(uuidString: raw) else {
            return nil
        }
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in human.id == humanID }
        )
        descriptor.fetchLimit = 1
        guard let human = try context.fetch(descriptor).first,
              !human.hasPassedAway else {
            return nil
        }
        return human.id.uuidString
    }

    private static func canonicalPersistedExecutorID(_ rawExecutorID: String?) throws -> String? {
        guard let rawExecutorID else { return nil }
        guard let executorID = UUID(uuidString: rawExecutorID) else {
            throw PlantCareReplayValidationFailure.incomplete
        }
        return executorID.uuidString
    }

    private static func rewardState(
        for careType: PlantCareType,
        wasEligible: Bool,
        options: PlantCareCommandOptions
    ) -> String {
        guard options.saveChanges, options.awardRewards else { return rewardStateDisabled }
        guard wasEligible, rewardAction(for: careType) != nil else { return rewardStateNotEligible }
        return rewardStatePending
    }

    @MainActor
    private static func finalizeRewardIfNeeded(
        request: PlantCareCommandRequest,
        log: PlantCareLog,
        ledgerEvent: CareLedgerEvent,
        authorizedExecutorID: String?,
        wasEligible: Bool,
        context: ModelContext,
        options: PlantCareCommandOptions
    ) -> RewardFinalization {
        guard options.awardRewards,
              wasEligible,
              let action = rewardAction(for: log.careType) else {
            return RewardFinalization(coconutDelta: ledgerEvent.coconutDelta, isPending: false, errorDescription: nil)
        }
        let economy = options.economy ?? DomainServiceDependencyRegistry.careEventEconomy()
        let idempotencyKey = "plantCareReward:\(log.careTransactionId)"
        let reward = economy.awardIdempotentCareAction(
            type: action,
            pet: nil,
            context: context,
            quality: DomainCareRewardQuality.compose(
                precise: false,
                hasNote: !log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                hasPhoto: log.hasPhotoAttachment
            ),
            date: request.rewardOperationDate,
            executorId: authorizedExecutorID,
            careObjectKey: request.plant.id,
            idempotencyKey: idempotencyKey,
            idempotencyID: request.operationID
        )
        guard reward.didPersist else {
            return RewardFinalization(
                coconutDelta: 0,
                isPending: true,
                errorDescription: "plantCareRewardFinalizationPending"
            )
        }
        let rewardPair = (humanGot: reward.humanGot, petGot: reward.petGot)
        let coconutDelta = max(0, reward.humanGot) + max(0, reward.petGot)
        ledgerEvent.coconutDelta = coconutDelta
        ledgerEvent.metadataJSON = settledRewardMetadata(
            existingMetadata: ledgerEvent.metadataJSON,
            rewardMetadata: economy.rewardMetadata(for: rewardPair),
            transactionID: log.careTransactionId
        )
        CloudSyncMutationRecorder.markModified(ledgerEvent, context: context, modifiedAt: request.now)
        let saveResult = options.persistChanges(context)
        guard saveResult.didSave else {
            context.rollback()
            economy.refreshProjectionAfterRollback(context: context)
            return RewardFinalization(
                coconutDelta: coconutDelta,
                isPending: true,
                errorDescription: saveResult.errorDescription ?? "plantCareRewardLedgerPending"
            )
        }
        return RewardFinalization(coconutDelta: coconutDelta, isPending: false, errorDescription: nil)
    }

    private static func settledRewardMetadata(
        existingMetadata: String,
        rewardMetadata: String,
        transactionID: String
    ) -> String {
        var object = CalendarTaskCompletionSyncService.metadataDictionary(from: existingMetadata)
        object.merge(CalendarTaskCompletionSyncService.metadataDictionary(from: rewardMetadata)) { _, rewardValue in
            rewardValue
        }
        object[CareLedgerMetadata.careTransactionId] = transactionID
        object[rewardStateMetadataKey] = rewardStateSettled
        object["generatedBy"] = "PlantCareCommandService"
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return existingMetadata
        }
        return json
    }

    @MainActor
    private static func authorizedScheduleWrite(
        for request: PlantCareCommandRequest,
        context: ModelContext
    ) -> AuthorizedDomainScheduleWrite? {
        let l = L10n.current
        let careTypeName = request.careType.displayName(l: l)
        let eventIntent = DomainScheduleCreateIntent(
            title: "\(request.careType.emoji) \(l.tr(zh: "给 \(request.plant.name)\(careTypeName)", en: "\(careTypeName) for \(request.plant.name)", de: "\(careTypeName) für \(request.plant.name)"))\(safetyReminderSuffix(for: request.plant))",
            startDate: request.now,
            isAllDay: false,
            eventType: request.careType.eventType.rawValue,
            relatedEntityType: EntityKind.plant.rawValue,
            relatedEntityId: request.plant.id.uuidString,
            assigneeId: request.executorID,
            writeKind: .care,
            source: .userCommand
        )
        return DomainScheduleWriteAuthorizer.authorizeCreate(intent: eventIntent, context: context)
            ?? DomainScheduleWriteAuthorizer.authorizeCreate(
                intent: DomainScheduleCreateIntent(
                    title: eventIntent.title,
                    startDate: eventIntent.startDate,
                    isAllDay: eventIntent.isAllDay,
                    eventType: eventIntent.eventType,
                    relatedEntityType: eventIntent.relatedLink.rawType,
                    relatedEntityId: eventIntent.relatedLink.rawId,
                    writeKind: eventIntent.writeKind,
                    source: eventIntent.source
                ),
                context: context
            )
    }

    @MainActor
    private static func applyCareFact(_ request: PlantCareCommandRequest) {
        switch request.careType {
        case .watering:
            request.plant.lastWateredDate = request.now
        case .fertilizing:
            request.plant.lastFertilizedDate = request.now
        case .pestCheck, .pestFound, .yellowLeaf, .newLeaf, .photo, .customNote:
            request.plant.lastHealthCheckDate = request.now
        case .repotting, .pruning, .misting, .rotating, .leafCleaning:
            break
        }
        if let healthStatus = request.healthStatus {
            request.plant.healthStatus = healthStatus
        }
    }

    @MainActor
    private static func sanitizedPhotoData(for request: PlantCareCommandRequest) -> Data? {
        request.photoData.map {
            AttachmentPrivacySanitizer.sanitizedData(
                $0,
                filename: "plant-care-\(request.careType.rawValue).jpg",
                isImage: true
            )
        }
    }

    @MainActor
    private static func makeCareLog(
        _ request: PlantCareCommandRequest,
        authorizedExecutorID: String?,
        photoData: Data?,
        careTransactionId: String?
    ) -> PlantCareLog {
        PlantCareLog(
            date: request.now,
            careType: request.careType,
            note: request.careNote,
            executorId: authorizedExecutorID,
            careTransactionId: careTransactionId ?? UUID().uuidString,
            photoData: photoData,
            healthStatus: request.healthStatus
        )
    }

    @MainActor
    private static func recordLedgerEvent(
        for request: PlantCareCommandRequest,
        log: PlantCareLog,
        event: Event,
        authorizedExecutorID: String?,
        rewardState: String,
        context: ModelContext,
        options: PlantCareCommandOptions
    ) -> CareLedgerEvent {
        let careLedger = options.careLedger ?? CareLedgerService()
        let transactionMetadata = CareLedgerMetadata.addingString(
            CareLedgerMetadata.careTransactionId,
            value: log.careTransactionId,
            to: ""
        )
        let operationDateMetadata = CareLedgerMetadata.addingString(
            rewardOperationDateMetadataKey,
            value: String(request.rewardOperationDate.timeIntervalSince1970),
            to: transactionMetadata
        )
        let metadataJSON = CareLedgerMetadata.addingString(
            rewardStateMetadataKey,
            value: rewardState,
            to: operationDateMetadata
        )
        return careLedger.record(
            occurredAt: log.date,
            actorKind: authorizedExecutorID == nil ? .unknown : .human,
            actorId: authorizedExecutorID,
            subjectKind: .plant,
            subjectId: request.plant.id.uuidString,
            eventKind: .plantCare,
            actionType: request.careType.rawValue,
            amountValue: 0,
            amountUnit: "",
            note: log.note,
            source: .detail,
            sourceEventId: event.id.uuidString,
            sourceReminderId: nil,
            legacyModelName: "PlantCareLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: 0,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: metadataJSON,
            context: context,
            save: false
        )
    }

    private static func persistenceFailureResult(
        for request: PlantCareCommandRequest,
        log: PlantCareLog,
        event: Event,
        ledgerEvent: CareLedgerEvent,
        errorDescription: String?
    ) -> PlantCareCommandResult {
        PlantCareCommandResult(
            plantID: request.plant.id,
            logID: log.id,
            eventID: event.id,
            ledgerEventID: ledgerEvent.id,
            careType: request.careType,
            coconutDelta: 0,
            didWrite: false,
            wasReplay: false,
            rewardFinalizationPending: false,
            didPersist: false,
            persistenceError: errorDescription
        )
    }

    static func rewardOperationDate(
        in ledger: CareLedgerEvent,
        fallback: Date
    ) -> Date {
        guard let raw = CareLedgerMetadata.stringValue(
            named: rewardOperationDateMetadataKey,
            in: ledger.metadataJSON
        ),
        let timestamp = TimeInterval(raw),
        timestamp.isFinite else {
            return fallback
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func rewardAction(for type: PlantCareType) -> DomainCareRewardAction? {
        switch type {
        case .watering:
            .plantWatering
        case .fertilizing:
            .plantFertilizing
        default:
            nil
        }
    }

    private static func isRewardEligible(
        _ type: PlantCareType,
        for plant: Plant,
        context: ModelContext,
        now: Date
    ) throws -> Bool {
        switch type {
        case .watering, .fertilizing:
            let history = try PlantCarePlanningHistoryQuery.build(
                plantID: plant.id,
                context: context
            )
            return PlantCarePlanService.tasks(
                for: plant,
                history: history,
                now: now
            ).contains { task in
                task.careType == type && task.daysUntilDue <= 0
            }
        default:
            return false
        }
    }

    private static func safetyReminderSuffix(for plant: Plant, defaults: UserDefaults = .standard) -> String {
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
}

struct PlantCreationCommandInput: Equatable {
    let id: UUID
    let name: String
    let species: String
    let location: String
    let avatarEmoji: String
    let avatarImageData: Data?
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let roomNameRaw: String
    let potDiameterCm: Double
    let potMaterialRaw: String
    let soilTypeRaw: String
    let isIndoor: Bool
    let windowDirection: PlantWindowDirection
    let lightLevel: PlantLightLevel
    let lastLightMeasurementLux: Int
    let lastLightMeasurementDate: Date?
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let isNearClimateSource: Bool
    let potHasDrainage: Bool
    let acquiredDate: Date?
    let acquisitionSourceRaw: String
    let currentHeightCm: Double
    let currentSpreadCm: Double
    let isHydroponic: Bool
    let isSucculent: Bool
    let healthStatus: PlantHealthStatus
    let catalogSpeciesId: String
    let isToxicToCats: Bool
    let isToxicToDogs: Bool
    let isToxicToChildren: Bool
    let isIndoorSuitable: Bool
    let remindersEnabled: Bool
    let notes: String

    init(
        id: UUID = UUID(),
        name: String,
        species: String,
        location: String,
        avatarEmoji: String,
        avatarImageData: Data? = nil,
        wateringIntervalDays: Int,
        fertilizingIntervalDays: Int,
        roomNameRaw: String = "",
        potDiameterCm: Double = 0,
        potMaterialRaw: String = "",
        soilTypeRaw: String = "",
        isIndoor: Bool = true,
        windowDirection: PlantWindowDirection = .unknown,
        lightLevel: PlantLightLevel = .medium,
        lastLightMeasurementLux: Int = 0,
        lastLightMeasurementDate: Date? = nil,
        humidityPreference: PlantHumidityPreference = .standard,
        temperaturePreference: PlantTemperaturePreference = .standard,
        isNearClimateSource: Bool = false,
        potHasDrainage: Bool = true,
        acquiredDate: Date? = nil,
        acquisitionSourceRaw: String = "",
        currentHeightCm: Double = 0,
        currentSpreadCm: Double = 0,
        isHydroponic: Bool = false,
        isSucculent: Bool = false,
        healthStatus: PlantHealthStatus = .stable,
        catalogSpeciesId: String = "",
        isToxicToCats: Bool = false,
        isToxicToDogs: Bool = false,
        isToxicToChildren: Bool = false,
        isIndoorSuitable: Bool = true,
        remindersEnabled: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.location = location
        self.avatarEmoji = avatarEmoji
        self.avatarImageData = avatarImageData
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.roomNameRaw = roomNameRaw
        self.potDiameterCm = potDiameterCm
        self.potMaterialRaw = potMaterialRaw
        self.soilTypeRaw = soilTypeRaw
        self.isIndoor = isIndoor
        self.windowDirection = windowDirection
        self.lightLevel = lightLevel
        self.lastLightMeasurementLux = lastLightMeasurementLux
        self.lastLightMeasurementDate = lastLightMeasurementDate
        self.humidityPreference = humidityPreference
        self.temperaturePreference = temperaturePreference
        self.isNearClimateSource = isNearClimateSource
        self.potHasDrainage = potHasDrainage
        self.acquiredDate = acquiredDate
        self.acquisitionSourceRaw = acquisitionSourceRaw
        self.currentHeightCm = currentHeightCm
        self.currentSpreadCm = currentSpreadCm
        self.isHydroponic = isHydroponic
        self.isSucculent = isSucculent
        self.healthStatus = healthStatus
        self.catalogSpeciesId = catalogSpeciesId
        self.isToxicToCats = isToxicToCats
        self.isToxicToDogs = isToxicToDogs
        self.isToxicToChildren = isToxicToChildren
        self.isIndoorSuitable = isIndoorSuitable
        self.remindersEnabled = remindersEnabled
        self.notes = notes
    }
}

struct PlantCreationCommandResult: Equatable {
    let plantID: UUID
    let kind: String
    let didPersist: Bool
    let persistenceErrorDescription: String?
    let personalDenial: PersonalFreeLimitDenial?

    init(
        plantID: UUID,
        kind: String,
        didPersist: Bool = true,
        persistenceErrorDescription: String? = nil,
        personalDenial: PersonalFreeLimitDenial? = nil
    ) {
        self.plantID = plantID
        self.kind = kind
        self.didPersist = didPersist
        self.persistenceErrorDescription = persistenceErrorDescription
        self.personalDenial = personalDenial
    }
}

nonisolated struct PlantDuplicateScanDraft: Equatable, Sendable {
    let name: String
    let species: String
    let roomName: String
    let location: String
    let catalogSpeciesId: String
}

nonisolated struct PlantDuplicateScanSnapshot: Equatable, Sendable {
    let id: UUID
    let name: String
    let species: String
    let roomName: String
    let location: String
    let catalogSpeciesId: String
}

nonisolated struct PlantDuplicateCandidate: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let reason: String
}

nonisolated struct PlantCatalogProfileDefaults: Equatable, Sendable {
    let name: String
    let species: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let lightLevel: PlantLightLevel
    let soilTypeRaw: String
    let isIndoor: Bool
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let potHasDrainage: Bool
    let isHydroponic: Bool
    let isSucculent: Bool
}

nonisolated struct PlantCarePlanRecalculationSnapshot: Equatable, Sendable {
    let roomName: String
    let location: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let potDiameterCm: Double
    let potMaterialRaw: String
    let soilTypeRaw: String
    let isIndoor: Bool
    let windowDirection: PlantWindowDirection
    let lightLevel: PlantLightLevel
    let lastLightMeasurementLux: Int
    let humidityPreference: PlantHumidityPreference
    let temperaturePreference: PlantTemperaturePreference
    let isNearClimateSource: Bool
    let potHasDrainage: Bool
    let currentHeightCm: Double
    let currentSpreadCm: Double
    let isHydroponic: Bool
    let isSucculent: Bool
    let healthStatus: PlantHealthStatus
    let catalogSpeciesId: String
    let remindersEnabled: Bool
}

nonisolated enum PlantCarePlanRecalculationImpact: String, CaseIterable, Identifiable, Sendable {
    case remindersOff
    case remindersOn
    case watering
    case fertilizing
    case misting
    case rotation
    case repotting
    case location

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .remindersOff, .remindersOn: "bell.badge"
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .misting: "humidity.fill"
        case .rotation: "rotate.3d"
        case .repotting: "shippingbox.fill"
        case .location: "house.fill"
        }
    }

    var title: String {
        let l = L10n.current
        return switch self {
        case .remindersOff: l.tr(zh: "关闭植物提醒", en: "Turn off plant reminders", de: "Pflanzenerinnerungen ausschalten")
        case .remindersOn: l.tr(zh: "重新打开提醒", en: "Turn reminders back on", de: "Erinnerungen wieder einschalten")
        case .watering: l.tr(zh: "浇水日期会重算", en: "Watering date will recalculate", de: "Gießdatum wird neu berechnet")
        case .fertilizing: l.tr(zh: "施肥日期会重算", en: "Fertilizing date will recalculate", de: "Düngedatum wird neu berechnet")
        case .misting: l.tr(zh: "喷雾任务可能变化", en: "Misting tasks may change", de: "Sprühaufgaben können sich ändern")
        case .rotation: l.tr(zh: "转盆节奏可能变化", en: "Rotation cadence may change", de: "Drehrhythmus kann sich ändern")
        case .repotting: l.tr(zh: "换盆检查会重算", en: "Repotting check will recalculate", de: "Umtopfprüfung wird neu berechnet")
        case .location: l.tr(zh: "房间/位置筛选会更新", en: "Room/location filters will update", de: "Raum-/Standortfilter werden aktualisiert")
        }
    }

    var detail: String {
        let l = L10n.current
        return switch self {
        case .remindersOff: l.tr(zh: "保存后会清理这株植物未完成的本地植物计划提醒。", en: "After saving, unfinished local care reminders for this plant will be cleared.", de: "Nach dem Speichern werden offene lokale Pflegeerinnerungen für diese Pflanze bereinigt.")
        case .remindersOn: l.tr(zh: "保存后会重新生成这株植物后续的本地护理计划。", en: "After saving, future local care plans for this plant will be regenerated.", de: "Nach dem Speichern werden zukünftige lokale Pflegepläne für diese Pflanze neu erzeugt.")
        case .watering: l.tr(zh: "水培、多肉、光照、盆径、盆材质或排水信息会影响下一次浇水。", en: "Hydroponics, succulent type, light, pot size, pot material, or drainage can affect the next watering.", de: "Hydrokultur, Sukkulentenart, Licht, Topfgröße, Material oder Drainage können das nächste Gießen beeinflussen.")
        case .fertilizing: l.tr(zh: "施肥频率、健康状态、水培或多肉类型会影响下一次施肥。", en: "Fertilizing frequency, health status, hydroponics, or succulent type can affect the next fertilizing task.", de: "Düngefrequenz, Zustand, Hydrokultur oder Sukkulentenart können die nächste Düngung beeinflussen.")
        case .misting: l.tr(zh: "湿度偏好或空调/暖气位置会影响是否安排喷雾。", en: "Humidity preference or AC/heater placement can affect whether misting is scheduled.", de: "Luftfeuchte und Nähe zu Klimaanlage/Heizung können beeinflussen, ob Sprühen geplant wird.")
        case .rotation: l.tr(zh: "窗向、光照强度和实测 lux 会影响转盆提醒。", en: "Window direction, light level, and measured lux can affect rotation reminders.", de: "Fensterausrichtung, Lichtstärke und gemessene Lux können Dreherinnerungen beeinflussen.")
        case .repotting: l.tr(zh: "盆径、株高、水培和排水孔会影响换盆复查节奏。", en: "Pot diameter, plant height, hydroponics, and drainage holes can affect repotting checks.", de: "Topfdurchmesser, Pflanzenhöhe, Hydrokultur und Abzugslöcher können Umtopfkontrollen beeinflussen.")
        case .location: l.tr(zh: "房间和具体位置会影响植物列表、筛选和卡片展示。", en: "Room and exact spot affect plant lists, filters, and card display.", de: "Raum und genauer Standort beeinflussen Pflanzenlisten, Filter und Kartenanzeige.")
        }
    }
}

nonisolated enum PlantProfileUXPolicy {
    static func duplicateAcknowledgementKey(for draft: PlantDuplicateScanDraft) -> String {
        [
            normalized(draft.name),
            normalized(draft.species),
            normalized(draft.roomName),
            normalized(draft.location),
            normalized(draft.catalogSpeciesId)
        ].joined(separator: "|")
    }

    static func duplicateCandidates(
        draft: PlantDuplicateScanDraft,
        existingPlants: [PlantDuplicateScanSnapshot]
    ) -> [PlantDuplicateCandidate] {
        let draftName = normalized(draft.name)
        let draftSpecies = normalized(draft.species)
        let draftRoom = normalized(draft.roomName)
        let draftLocation = normalized(draft.location)
        let draftCatalog = normalized(draft.catalogSpeciesId)
        guard !draftName.isEmpty || !draftSpecies.isEmpty || !draftCatalog.isEmpty else { return [] }

        var candidates: [PlantDuplicateCandidate] = []
        var seenIds = Set<UUID>()
        for plant in existingPlants {
            let plantName = normalized(plant.name)
            let plantSpecies = normalized(plant.species)
            let plantRoom = normalized(plant.roomName)
            let plantLocation = normalized(plant.location)
            let plantCatalog = normalized(plant.catalogSpeciesId)
            let l = L10n.current
            let reason: String? = if !draftCatalog.isEmpty, draftCatalog == plantCatalog, !draftRoom.isEmpty, draftRoom == plantRoom {
                l.tr(zh: "资料库物种和房间相同", en: "Same catalog species and room", de: "Gleiche Katalogart und gleicher Raum")
            } else if !draftName.isEmpty, draftName == plantName {
                l.tr(zh: "昵称相同", en: "Same nickname", de: "Gleicher Spitzname")
            } else if !draftSpecies.isEmpty, draftSpecies == plantSpecies, !draftRoom.isEmpty, draftRoom == plantRoom {
                l.tr(zh: "物种和房间相同", en: "Same species and room", de: "Gleiche Art und gleicher Raum")
            } else if !draftSpecies.isEmpty, draftSpecies == plantSpecies, !draftLocation.isEmpty, draftLocation == plantLocation {
                l.tr(zh: "物种和具体位置相同", en: "Same species and exact spot", de: "Gleiche Art und gleicher Standort")
            } else {
                nil
            }
            guard let reason, !seenIds.contains(plant.id) else { continue }
            seenIds.insert(plant.id)
            let roomDetail = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
            let locationDetail = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = [roomDetail, locationDetail].filter { !$0.isEmpty }.joined(separator: " · ")
            candidates.append(PlantDuplicateCandidate(
                id: plant.id,
                title: plant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.current.tr(zh: "未命名植物", en: "Unnamed plant", de: "Unbenannte Pflanze") : plant.name,
                detail: detail.isEmpty ? L10n.current.tr(zh: "没有位置记录", en: "No location recorded", de: "Kein Standort erfasst") : detail,
                reason: reason
            ))
        }
        return Array(candidates.prefix(3))
    }

    static func catalogDefaults(for entry: PlantCatalogEntry) -> PlantCatalogProfileDefaults {
        PlantCatalogProfileDefaults(
            name: entry.localizedCommonName,
            species: entry.latinName,
            wateringIntervalDays: entry.defaultWateringDays,
            fertilizingIntervalDays: entry.defaultFertilizingDays,
            lightLevel: entry.lightRequirement,
            soilTypeRaw: entry.localizedSoil,
            isIndoor: entry.isIndoorSuitable,
            humidityPreference: humidityPreference(from: entry.humidity),
            temperaturePreference: temperaturePreference(from: entry.temperature),
            potHasDrainage: true,
            isHydroponic: false,
            isSucculent: isSucculentLike(entry)
        )
    }

    static func recalculationImpacts(
        old: PlantCarePlanRecalculationSnapshot,
        new: PlantCarePlanRecalculationSnapshot
    ) -> [PlantCarePlanRecalculationImpact] {
        var impacts: [PlantCarePlanRecalculationImpact] = []
        if old.remindersEnabled, !new.remindersEnabled {
            impacts.append(.remindersOff)
        } else if !old.remindersEnabled, new.remindersEnabled {
            impacts.append(.remindersOn)
        }
        if old.wateringIntervalDays != new.wateringIntervalDays ||
            old.potDiameterCm != new.potDiameterCm ||
            normalized(old.potMaterialRaw) != normalized(new.potMaterialRaw) ||
            old.isIndoor != new.isIndoor ||
            old.lightLevel != new.lightLevel ||
            old.windowDirection != new.windowDirection ||
            old.lastLightMeasurementLux != new.lastLightMeasurementLux ||
            old.isNearClimateSource != new.isNearClimateSource ||
            old.potHasDrainage != new.potHasDrainage ||
            old.isHydroponic != new.isHydroponic ||
            old.isSucculent != new.isSucculent ||
            old.catalogSpeciesId != new.catalogSpeciesId {
            impacts.append(.watering)
        }
        if old.fertilizingIntervalDays != new.fertilizingIntervalDays ||
            old.healthStatus != new.healthStatus ||
            old.isHydroponic != new.isHydroponic ||
            old.isSucculent != new.isSucculent ||
            old.catalogSpeciesId != new.catalogSpeciesId {
            impacts.append(.fertilizing)
        }
        if old.humidityPreference != new.humidityPreference ||
            old.isNearClimateSource != new.isNearClimateSource {
            impacts.append(.misting)
        }
        if old.windowDirection != new.windowDirection ||
            old.lightLevel != new.lightLevel ||
            old.lastLightMeasurementLux != new.lastLightMeasurementLux {
            impacts.append(.rotation)
        }
        if old.potDiameterCm != new.potDiameterCm ||
            old.currentHeightCm != new.currentHeightCm ||
            old.potHasDrainage != new.potHasDrainage ||
            old.isHydroponic != new.isHydroponic {
            impacts.append(.repotting)
        }
        if normalized(old.roomName) != normalized(new.roomName) ||
            normalized(old.location) != normalized(new.location) {
            impacts.append(.location)
        }
        return impacts
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    private static func humidityPreference(from text: String) -> PlantHumidityPreference {
        let value = normalized(text)
        if value.contains("高湿") || value.contains("偏高") || value.contains("中高") || value.contains("humid") {
            return .humid
        }
        if value.contains("偏干") || value.contains("耐干") || value.contains("dry") {
            return .dry
        }
        return .standard
    }

    private static func temperaturePreference(from text: String) -> PlantTemperaturePreference {
        let value = normalized(text)
        if value.contains("冷") || value.contains("凉") || value.contains("cool") {
            return .cool
        }
        if value.contains("暖") || value.contains("warm") {
            return .warm
        }
        return .standard
    }

    private static func isSucculentLike(_ entry: PlantCatalogEntry) -> Bool {
        let searchableText = ([entry.commonName, entry.latinName, entry.soil, entry.wateringPreference] + entry.aliases)
            .map(normalized)
            .joined(separator: " ")
        return searchableText.contains("多肉") ||
            searchableText.contains("仙人掌") ||
            searchableText.contains("succulent") ||
            searchableText.contains("cactus") ||
            searchableText.contains("snake plant")
    }
}

enum PlantCreationCommandService {
    @discardableResult
    @MainActor
    static func createPlant(
        input: PlantCreationCommandInput,
        context: ModelContext,
        personalAccessLevel: PersonalAccessLevel = .personal,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> PlantCreationCommandResult {
        do {
            let usage = try PersonalUsageSnapshotReader.snapshot(context: context)
            let disposition = PersonalAccessPolicy.disposition(
                level: personalAccessLevel,
                usage: usage,
                request: .addActivePlant()
            )
            if case let .deny(denial) = disposition,
               case let .wouldExceedFreeLimit(limitDenial) = denial.reason {
                return PlantCreationCommandResult(
                    plantID: input.id,
                    kind: EntityKind.plant.rawValue,
                    didPersist: false,
                    personalDenial: limitDenial
                )
            }
        } catch {
            return PlantCreationCommandResult(
                plantID: input.id,
                kind: EntityKind.plant.rawValue,
                didPersist: false,
                persistenceErrorDescription: "Could not verify the current Ohana Personal allowance: \(error.localizedDescription)"
            )
        }

        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let plant = Plant(
            name: trimmedName.isEmpty ? "Plant" : trimmedName,
            species: input.species.trimmingCharacters(in: .whitespacesAndNewlines),
            location: input.location.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarEmoji: input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "🌱"
                : input.avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines),
            wateringIntervalDays: input.wateringIntervalDays,
            fertilizingIntervalDays: input.fertilizingIntervalDays,
            roomNameRaw: input.roomNameRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            potDiameterCm: input.potDiameterCm,
            potMaterialRaw: input.potMaterialRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            soilTypeRaw: input.soilTypeRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            isIndoor: input.isIndoor,
            windowDirection: input.windowDirection,
            lightLevel: input.lightLevel,
            lastLightMeasurementLux: max(0, input.lastLightMeasurementLux),
            lastLightMeasurementDate: input.lastLightMeasurementDate,
            humidityPreference: input.humidityPreference,
            temperaturePreference: input.temperaturePreference,
            isNearClimateSource: input.isNearClimateSource,
            potHasDrainage: input.potHasDrainage,
            acquiredDate: input.acquiredDate,
            acquisitionSourceRaw: input.acquisitionSourceRaw.trimmingCharacters(in: .whitespacesAndNewlines),
            currentHeightCm: input.currentHeightCm,
            currentSpreadCm: input.currentSpreadCm,
            isHydroponic: input.isHydroponic,
            isSucculent: input.isSucculent,
            healthStatus: input.healthStatus,
            catalogSpeciesId: input.catalogSpeciesId,
            isToxicToCats: input.isToxicToCats,
            isToxicToDogs: input.isToxicToDogs,
            isToxicToChildren: input.isToxicToChildren,
            isIndoorSuitable: input.isIndoorSuitable,
            remindersEnabled: input.remindersEnabled
        )
        plant.id = input.id
        plant.updateAvatarImageData(MemberAvatarImageProcessor.persistableAvatarData(input.avatarImageData))
        plant.notes = input.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(plant)
        CloudSyncMutationRecorder.markModified(plant, context: context)
        let scheduleResult = PlantCarePlanScheduleService.sync(
            plant: plant,
            context: context,
            scheduleNotifications: scheduleNotifications,
            reminderScheduling: providedReminderScheduling,
            saveChanges: false
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return PlantCreationCommandResult(
                plantID: plant.id,
                kind: EntityKind.plant.rawValue,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        PlantUnlockPolicy.noteExistingPlantData()
        PlantCarePlanScheduleService.commitSideEffects(
            for: scheduleResult,
            context: context
        )

        return PlantCreationCommandResult(
            plantID: plant.id,
            kind: EntityKind.plant.rawValue
        )
    }
}
