//
//  MemberInteractionCommands.swift
//  Ohana
//
//  Domain write boundaries for member lifecycle, visibility, walks, and member-scoped executors.
//

import Foundation
import SwiftData

enum MemberLifecycleCommandService {
    @discardableResult
    @MainActor
    static func markPetPassedAway(
        _ pet: Pet,
        date: Date,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .lifecycle(.markPassedAway)).isAllowed else {
            return MemberLifecycleCommandResult(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "no-op")
        }
        RainbowBridgeService().markPassedAway(pet: pet, date: date, context: context)
        CloudSyncMutationRecorder.markModified(pet, context: context, modifiedAt: date)
        context.safeSave()
        return MemberLifecycleCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.mark"
        )
    }

    @discardableResult
    @MainActor
    static func undoPetPassedAway(
        _ pet: Pet,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        guard MemberLifecycleGate.disposition(pet: pet, writeKind: .lifecycle(.undoPassedAway)).isAllowed else {
            return MemberLifecycleCommandResult(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "no-op")
        }
        RainbowBridgeService().undoPassedAway(pet: pet, context: context)
        CloudSyncMutationRecorder.markModified(pet, context: context)
        context.safeSave()
        return MemberLifecycleCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "passed.undo"
        )
    }

    @discardableResult
    @MainActor
    static func clearPetActivityRecords(
        _ pet: Pet,
        context: ModelContext,
        questManager: QuestManager? = nil,
        cleanupService: PetActivityRecordCleanupService? = nil
    ) -> MemberLifecycleCommandResult {
        guard MemberLifecycleGate.disposition(
            pet: pet,
            writeKind: .lifecycle(.clearActivityRecords)
        ).isAllowed else {
            return MemberLifecycleCommandResult(entityID: pet.id, kind: EntityKind.pet.rawValue, action: "no-op")
        }
        let cleanupService = cleanupService ?? PetActivityRecordCleanupService()
        cleanupService.clearActivityRecords(for: pet, context: context)
        let manager = questManager ?? QuestManager()
        manager.clearPerPetAuxiliaryState(forPetId: pet.id)
        CloudSyncMutationRecorder.markModified(pet, context: context)
        context.safeSave()
        return MemberLifecycleCommandResult(
            entityID: pet.id,
            kind: EntityKind.pet.rawValue,
            action: "records.clear"
        )
    }

    @discardableResult
    @MainActor
    static func markHumanPassedAway(
        _ human: Human,
        date: Date,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .lifecycle(.markPassedAway)).isAllowed else {
            return MemberLifecycleCommandResult(entityID: human.id, kind: EntityKind.human.rawValue, action: "no-op")
        }
        human.passedAwayDate = date
        MemberLifecycleActiveScheduleCleanup.removeFutureSchedules(for: human, passedAwayAt: date, context: context)
        CloudSyncMutationRecorder.markModified(human, context: context, modifiedAt: date)
        context.safeSave()
        return MemberLifecycleCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.mark"
        )
    }

    @discardableResult
    @MainActor
    static func undoHumanPassedAway(
        _ human: Human,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .lifecycle(.undoPassedAway)).isAllowed else {
            return MemberLifecycleCommandResult(entityID: human.id, kind: EntityKind.human.rawValue, action: "no-op")
        }
        human.passedAwayDate = nil
        CloudSyncMutationRecorder.markModified(human, context: context)
        context.safeSave()
        return MemberLifecycleCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.undo"
        )
    }

    @discardableResult
    @MainActor
    static func archivePlant(
        _ plant: Plant,
        date: Date,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        let result = PlantLifecycleService.archive(plant, archivedAt: date, context: context)
        return MemberLifecycleCommandResult(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            action: result.didWrite ? result.action : "no-op"
        )
    }

    @discardableResult
    @MainActor
    static func restorePlant(
        _ plant: Plant,
        context: ModelContext
    ) -> MemberLifecycleCommandResult {
        let result = PlantLifecycleService.restore(plant, context: context)
        return MemberLifecycleCommandResult(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            action: result.didWrite ? result.action : "no-op"
        )
    }
}

enum MemberHomeVisibilityCommandService {
    @discardableResult
    @MainActor
    static func setHumanHomeVisibility(
        _ human: Human,
        visible: Bool,
        context: ModelContext
    ) -> MemberHomeVisibilityCommandResult {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .profileEdit).writesContent else {
            return MemberHomeVisibilityCommandResult(
                entityID: human.id,
                kind: EntityKind.human.rawValue,
                visible: human.shouldShowOnHome,
                didWrite: false
            )
        }
        human.shouldShowOnHome = visible
        CloudSyncMutationRecorder.markModified(human, context: context)
        context.safeSave()
        return MemberHomeVisibilityCommandResult(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            visible: visible,
            didWrite: true
        )
    }
}

enum PetWalkCommandService {
    @discardableResult
    @MainActor
    static func saveWeeklyGoal(
        _ goalKm: Double,
        for pet: Pet,
        context: ModelContext
    ) -> PetWalkGoalCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsCareFactWrite else {
            return PetWalkGoalCommandResult(petID: pet.id, goalKm: pet.weeklyWalkGoalKm, didWrite: false)
        }
        pet.weeklyWalkGoalKm = max(0, goalKm)
        CloudSyncMutationRecorder.markModified(pet, context: context)
        context.safeSave()
        return PetWalkGoalCommandResult(petID: pet.id, goalKm: pet.weeklyWalkGoalKm, didWrite: true)
    }

    @discardableResult
    @MainActor
    static func saveSummary(
        for walk: PetWalkLog,
        pet: Pet,
        moodRating: Int,
        notes: String,
        context: ModelContext
    ) -> PetWalkSummaryCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsCareFactWrite else {
            return PetWalkSummaryCommandResult(
                petID: pet.id,
                walkID: walk.id,
                moodRating: walk.moodRating,
                hasNotes: !(walk.behaviorNotes ?? "").isEmpty,
                didWrite: false
            )
        }
        let normalizedRating = min(5, max(0, moodRating))
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        walk.moodRating = normalizedRating
        walk.behaviorNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        CloudSyncMutationRecorder.markModified(walk, context: context)
        context.safeSave()
        return PetWalkSummaryCommandResult(
            petID: pet.id,
            walkID: walk.id,
            moodRating: normalizedRating,
            hasNotes: !trimmedNotes.isEmpty,
            didWrite: true
        )
    }
}

@MainActor
struct PetWalkCommandExecutor {
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
    func saveWeeklyGoal(
        _ goalKm: Double,
        for pet: Pet,
        note: String
    ) -> PetWalkGoalCommandResult {
        let result = PetWalkCommandService.saveWeeklyGoal(goalKm, for: pet, context: context)
        if result.didWrite {
            revisions.publishPetWalkGoal(result, note: note)
        }
        return result
    }

    @discardableResult
    func saveSummary(
        for walk: PetWalkLog,
        pet: Pet,
        moodRating: Int,
        notes: String,
        note: String
    ) -> PetWalkSummaryCommandResult {
        let result = PetWalkCommandService.saveSummary(
            for: walk,
            pet: pet,
            moodRating: moodRating,
            notes: notes,
            context: context
        )
        if result.didWrite {
            revisions.publishPetWalkSummary(result, note: note)
        }
        return result
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
        _ type: PlantCareType,
        plant: Plant,
        executorId: String?,
        note: String,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil,
        syncCarePlan: Bool = true,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> PlantCareCommandResult {
        let result = PlantCareCommandService.recordCare(
            type,
            plant: plant,
            executorId: executorId,
            context: context,
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus,
            syncCarePlan: syncCarePlan,
            scheduleNotifications: scheduleNotifications,
            reminderScheduling: providedReminderScheduling
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

@MainActor
struct MemberCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(), questManager: QuestManager())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions, questManager: services.questManager)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing, questManager: QuestManager) {
        self.context = context
        self.revisions = revisions
        self.questManager = questManager
    }

    @discardableResult
    func updatePetProfile(_ pet: Pet, input: PetProfileCommandInput, note: String) -> MemberProfileCommandResult {
        let result = MemberProfileCommandService.updatePet(pet, input: input, context: context)
        revisions.publishMemberProfile(result, note: note)
        return result
    }

    @discardableResult
    func updateHumanProfile(_ human: Human, input: HumanProfileCommandInput, note: String) -> MemberProfileCommandResult {
        let result = MemberProfileCommandService.updateHuman(human, input: input, context: context)
        revisions.publishMemberProfile(result, note: note)
        return result
    }

    @discardableResult
    func updatePlantProfile(_ plant: Plant, input: PlantProfileCommandInput, note: String) -> MemberProfileCommandResult {
        let result = MemberProfileCommandService.updatePlant(plant, input: input, context: context)
        revisions.publishMemberProfile(result, note: note)
        return result
    }

    @discardableResult
    func setHumanHomeVisibility(
        _ human: Human,
        visible: Bool,
        note: String
    ) -> MemberHomeVisibilityCommandResult {
        let result = MemberHomeVisibilityCommandService.setHumanHomeVisibility(human, visible: visible, context: context)
        revisions.publishMemberHomeVisibility(result, note: note)
        return result
    }

    @discardableResult
    func publishPetHomeVisibility(
        petID: UUID,
        visible: Bool,
        note: String
    ) -> MemberHomeVisibilityCommandResult {
        let result = MemberHomeVisibilityCommandResult(
            entityID: petID,
            kind: EntityKind.pet.rawValue,
            visible: visible,
            didWrite: true
        )
        revisions.publishMemberHomeVisibility(result, note: note)
        return result
    }

    @discardableResult
    func markPetPassedAway(_ pet: Pet, date: Date, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.markPetPassedAway(pet, date: date, context: context)
        revisions.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func undoPetPassedAway(_ pet: Pet, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.undoPetPassedAway(pet, context: context)
        revisions.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func clearPetActivityRecords(_ pet: Pet, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.clearPetActivityRecords(
            pet,
            context: context,
            questManager: questManager
        )
        revisions.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func markHumanPassedAway(_ human: Human, date: Date, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.markHumanPassedAway(human, date: date, context: context)
        revisions.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func undoHumanPassedAway(_ human: Human, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.undoHumanPassedAway(human, context: context)
        revisions.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func archivePlant(_ plant: Plant, date: Date, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.archivePlant(plant, date: date, context: context)
        revisions.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func restorePlant(_ plant: Plant, note: String) -> MemberLifecycleCommandResult {
        let result = MemberLifecycleCommandService.restorePlant(plant, context: context)
        revisions.publishMemberLifecycle(result, note: note)
        return result
    }

    @discardableResult
    func deletePet(_ pet: Pet, note: String) -> MemberDeletionCommandResult {
        let result = MemberDeletionCommandService.deletePet(pet, context: context)
        revisions.publishMemberDeletion(result, note: note)
        return result
    }

    @discardableResult
    func deleteHuman(
        _ human: Human,
        activeHumanID: String,
        note: String
    ) -> MemberDeletionCommandResult {
        let result = MemberDeletionCommandService.deleteHuman(human, activeHumanID: activeHumanID, context: context)
        revisions.publishMemberDeletion(result, note: note)
        return result
    }

    @discardableResult
    func deletePlant(_ plant: Plant, note: String) -> MemberDeletionCommandResult {
        let result = MemberDeletionCommandService.deletePlant(plant, context: context)
        revisions.publishMemberDeletion(result, note: note)
        return result
    }
}
