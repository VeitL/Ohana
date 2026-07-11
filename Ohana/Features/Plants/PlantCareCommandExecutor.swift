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
    var now = Date()
    var careNote = ""
    var photoData: Data?
    var healthStatus: PlantHealthStatus?
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
        revisions.publishPlantCare(result, note: note)
        return result
    }

    @discardableResult
    func completeBatchCare(
        selections: [PlantBatchCareSelection],
        executorId: String?,
        note: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PlantBatchCareCommandResult {
        let result = PlantBatchCareCommandService.completeDueCare(
            selections: selections,
            context: context,
            executorId: executorId,
            now: now,
            calendar: calendar
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
        calendar: Calendar = .current
    ) -> PlantBatchCareCommandResult {
        let result = PlantBatchCareCommandService.recordQuickCare(
            selections: selections,
            context: context,
            executorId: executorId,
            now: now,
            calendar: calendar
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
