//
//  PlantCareCommandExecutor.swift
//  Ohana
//
//  Plant-domain command facade and compact request values.
//

import Foundation
import SwiftData

@MainActor
struct PlantCareCommandRequest {
    let careType: PlantCareType
    let plant: Plant
    let executorID: String?
    var now: Date
    /// Economy uses the day on which the user submitted the command. This is
    /// intentionally independent from `now`, which may be a historical care
    /// fact date during backfill.
    var rewardOperationDate: Date
    var careNote: String
    var photoData: Data?
    var healthStatus: PlantHealthStatus?
    /// Stable identifier for one user intent. Reuse the same request when a
    /// command is retried; a new tap should create a new operation identifier.
    var operationID: UUID

    init(
        careType: PlantCareType,
        plant: Plant,
        executorID: String?,
        now: Date = Date(),
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil,
        operationID: UUID = UUID(),
        rewardOperationDate: Date = Date()
    ) {
        self.careType = careType
        self.plant = plant
        self.executorID = executorID
        self.now = now
        self.rewardOperationDate = rewardOperationDate
        self.careNote = careNote
        self.photoData = photoData
        self.healthStatus = healthStatus
        self.operationID = operationID
    }
}

@MainActor
struct PlantCareCommandOptions {
    var careLedger: CareLedgerRecording?
    var economy: CareEventEconomyAwarding?
    var syncCarePlan = true
    var scheduleNotifications = true
    var reminderScheduling: ReminderSchedulingManaging?
    var saveChanges = true
    var awardRewards = true
    var persistChanges: (ModelContext) -> ModelContextSaveResult = { context in
        context.safeSaveResult(publishFailureEvent: true)
    }
}

@MainActor
struct PlantCareCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
    }

    @discardableResult
    func recordCare(
        _ request: PlantCareCommandRequest,
        note: String,
        options: PlantCareCommandOptions
    ) -> PlantCareCommandResult {
        let result = PlantCareCommandService.recordCare(
            request,
            context: context,
            options: options
        )
        if result.didWrite {
            revisions.publishPlantCare(result, note: note)
        }
        return result
    }

    @discardableResult
    func completeBatchCare(
        selections: [PlantBatchCareSelection],
        executorId: String?,
        note: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        operationID: UUID = UUID(),
        clock: () -> Date = Date.init
    ) -> PlantBatchCareCommandResult {
        let result = PlantBatchCareCommandService.completeDueCare(
            selections: selections,
            context: context,
            executorId: executorId,
            now: now,
            calendar: calendar,
            operationID: operationID,
            clock: clock
        )
        revisions.publishPlantBatchCare(result, note: note)
        return result
    }

    @discardableResult
    func recordBatchQuickCare(
        selections: [PlantBatchCareSelection],
        executorId: String?,
        note: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        operationID: UUID = UUID(),
        clock: () -> Date = Date.init
    ) -> PlantBatchCareCommandResult {
        let result = PlantBatchCareCommandService.recordQuickCare(
            selections: selections,
            context: context,
            executorId: executorId,
            now: now,
            calendar: calendar,
            operationID: operationID,
            clock: clock
        )
        revisions.publishPlantBatchQuickRecord(result, note: note)
        return result
    }

    @discardableResult
    func undoBatchCare(
        _ token: PlantBatchCareUndoToken,
        note: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantBatchCareUndoResult {
        let result = PlantBatchCareCommandService.undo(
            token,
            context: context,
            now: now,
            calendar: calendar
        )
        revisions.publishPlantBatchCareUndo(result, note: note)
        return result
    }

    @discardableResult
    func commitBatchCareRewards(
        for token: PlantBatchCareUndoToken,
        note: String,
        now: Date = Date()
    ) -> PlantBatchCareRewardCommitResult {
        let result = PlantBatchCareCommandService.commitRewards(
            for: token,
            context: context,
            now: now
        )
        revisions.publishPlantBatchCareRewardCommit(result, note: note)
        return result
    }
}
