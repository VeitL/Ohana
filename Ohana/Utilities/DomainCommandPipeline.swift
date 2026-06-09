//
//  DomainCommandPipeline.swift
//  Ohana
//
//  Shared write-command contract and read-model revision publishing.
//

import Combine
import Foundation

enum DomainCommand: Hashable {
    case quickCare(entityID: UUID, action: String)
    case todayFocus(entityID: UUID, action: String)
    case medicationDose(petID: UUID, medicationID: UUID)
    case petMedicationPlan(petID: UUID, medicationID: UUID?)
    case petMedicationPlanActivation(petID: UUID, medicationID: UUID, isActive: Bool)
    case petMedicationPlanDelete(petID: UUID, medicationID: UUID)
    case humanMedicationDose(humanID: UUID, medicationID: UUID, scheduledMinute: Int, status: String)
    case plantCare(plantID: UUID, action: String)
    case quickMoment(petID: UUID?)
    case quickWeight(petID: UUID)
    case weightEntry(entityID: UUID, entityKind: String)
    case weightDelete(entityID: UUID, entityKind: String, recordID: UUID)
    case quickHumanExpense(humanID: UUID)
    case expenseEntry(entityID: UUID, entityKind: String)
    case expenseDelete(entityID: UUID, entityKind: String, recordID: UUID)
    case quickHumanWorkout(humanID: UUID)
    case humanWorkoutEntry(humanID: UUID)
    case humanWorkoutDelete(humanID: UUID, recordID: UUID)
    case quickHumanMedication(humanID: UUID)
    case humanMedicationPlan(humanID: UUID, medicationID: UUID?)
    case humanMedicationPlanActivation(humanID: UUID, medicationID: UUID, isActive: Bool)
    case humanMedicationPlanDelete(humanID: UUID, medicationID: UUID)
    case humanHealthMetric(humanID: UUID, metricKey: String)
    case humanHealthMetricDelete(humanID: UUID, metricKey: String, logID: UUID)
    case humanHealthReport(humanID: UUID, reportID: UUID?, action: String)
    case avatar2DUpgrade(entityID: UUID, kind: String)
    case humanNote(humanID: UUID)
    case humanPrivacy(humanID: UUID, action: String)
    case feedSettings(petID: UUID)
    case feedLog(petID: UUID, source: String)
    case feedPlan(petID: UUID, action: String)
    case feedStock(petID: UUID, action: String)
    case feedMode(petID: UUID, mode: String)
    case feedMaintenance(petID: UUID, action: String)
    case memberCreation(entityID: UUID, kind: String)
    case petHealthRecord(petID: UUID, type: String)
    case petHealthDelete(petID: UUID, kind: String, recordID: UUID)
    case insurancePolicy(petID: UUID, policyID: UUID, action: String)
    case insuranceClaim(petID: UUID, policyID: UUID, claimID: UUID?, action: String)
    case petPhotoCreate(petID: UUID)
    case petPhotoUpdate(petID: UUID, photoID: UUID)
    case petPhotoDelete(petID: UUID, photoID: UUID)
    case petCareRecord(petID: UUID, type: String)
    case petCareDelete(petID: UUID, logID: UUID)
    case petPottyDelete(petID: UUID, logID: UUID)
    case petWalkGoal(petID: UUID)
    case petWalkSummary(petID: UUID, walkID: UUID)
    case petBondVaultUnlock(petID: UUID, itemID: String)
    case petCardAppearance(petID: UUID, action: String)
    case catCareRecord(petID: UUID, action: String)
    case catCareUndo(petID: UUID, eventID: UUID)
    case petHygieneRecord(petID: UUID, type: String)
    case petHygieneDelete(petID: UUID, recordID: UUID)
    case petHygienePlan(petID: UUID, type: String)
    case petMilestoneSeed(petID: UUID)
    case petMilestoneRecord(petID: UUID)
    case petMilestoneDelete(petID: UUID, milestoneID: UUID)
    case petDocumentCreate(petID: UUID, category: String)
    case petDocumentUpdate(petID: UUID, documentID: UUID)
    case petDocumentDelete(petID: UUID, documentID: UUID)
    case humanWishlistCreate(humanID: UUID)
    case humanWishlistRedeem(humanID: UUID, itemID: UUID)
    case humanWishlistDelete(humanID: UUID, itemID: UUID)
    case memberProfile(entityID: UUID, kind: String)
    case memberLifecycle(entityID: UUID, kind: String, action: String)
    case memberHomeVisibility(entityID: UUID, kind: String, visible: Bool)
    case settingsActiveHumanSwitch(humanID: UUID)
    case settingsCoconutBalance(humanID: UUID?, amount: Int)
    case calendarEventPlan(eventID: UUID?)
    case calendarEventCompletion(eventID: UUID, isCompleted: Bool)
    case calendarEventDeletion(eventID: UUID, scope: String)
    case memberDeletion(entityID: UUID, kind: String)
    case reminderCompletion(reminderID: UUID)
    case legacyBounty(taskID: UUID, action: String)
    case coconutExchange(requestID: UUID)
    case shopPurchase(humanID: UUID?, itemID: String)
    case achievementReward(entityID: UUID, kind: String, badgeIDs: [String])
    case backdateCheckIn(petID: UUID, action: String)
    case dailyCheckIn(humanID: String)
    case unknown(action: String)
}

struct DomainMutationResult: Identifiable, Hashable {
    let id = UUID()
    let command: DomainCommand
    let affectedEntityIDs: Set<UUID>
    let wroteBusinessFact: Bool
    let occurredAt: Date
    let note: String?

    init(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID> = [],
        wroteBusinessFact: Bool = true,
        occurredAt: Date = Date(),
        note: String? = nil
    ) {
        self.command = command
        self.affectedEntityIDs = affectedEntityIDs
        self.wroteBusinessFact = wroteBusinessFact
        self.occurredAt = occurredAt
        self.note = note
    }
}

struct HomeRevision: Equatable, Hashable {
    var value: Int = 0
    var changedAt: Date = .distantPast
    var lastCommand: DomainCommand?

    mutating func advance(for command: DomainCommand) {
        value &+= 1
        changedAt = Date()
        lastCommand = command
    }
}

@MainActor
final class ReadModelRevisionCenter: ObservableObject {
    static let shared = ReadModelRevisionCenter()

    @Published private(set) var homeRevision = HomeRevision()
    @Published private(set) var lastMutation: DomainMutationResult?

    private init() {}

    func publish(_ result: DomainMutationResult) {
        lastMutation = result
        homeRevision.advance(for: result.command)
        AppPerformanceMonitor.shared.record(
            result.wroteBusinessFact ? "domain_command_success" : "domain_command_noop",
            valueMS: 0,
            note: result.note ?? "\(result.command)"
        )
    }

    func publishDomainMutation(
        command: DomainCommand,
        affectedEntityIDs: Set<UUID>,
        wroteBusinessFact: Bool,
        note: String
    ) {
        publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affectedEntityIDs,
                wroteBusinessFact: wroteBusinessFact,
                note: note
            )
        )
    }

    func publishFailure(command: DomainCommand, error: Error) {
        AppPerformanceMonitor.shared.record(
            "domain_command_failure",
            valueMS: 0,
            note: "\(command): \(error.localizedDescription)"
        )
    }

    func publishMemberDeletion(_ result: MemberDeletionCommandResult, note: String) {
        var affected = Set(result.removedRelatedEventIDs)
        affected.insert(result.entityID)
        publish(
            DomainMutationResult(
                command: .memberDeletion(entityID: result.entityID, kind: result.kind),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberProfile(_ result: MemberProfileCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberProfile(entityID: result.entityID, kind: result.kind),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberHomeVisibility(_ result: MemberHomeVisibilityCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberHomeVisibility(
                    entityID: result.entityID,
                    kind: result.kind,
                    visible: result.visible
                ),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberLifecycle(_ result: MemberLifecycleCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberLifecycle(
                    entityID: result.entityID,
                    kind: result.kind,
                    action: result.action
                ),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishSettingsActiveHumanSwitch(_ result: SettingsActiveHumanSwitchCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .settingsActiveHumanSwitch(humanID: result.humanID),
                affectedEntityIDs: [result.humanID],
                wroteBusinessFact: result.didSyncHomeStack,
                note: note
            )
        )
    }

    func publishSettingsCoconutBalance(_ result: SettingsCoconutBalanceCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .settingsCoconutBalance(humanID: result.humanID, amount: result.amount),
                affectedEntityIDs: Set(result.humanID.map { [$0] } ?? []),
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanPrivacy(_ result: HumanPrivacyCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanPrivacy(humanID: result.humanID, action: result.action),
                affectedEntityIDs: [result.humanID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishMemberCreation(_ result: PlantCreationCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .memberCreation(entityID: result.plantID, kind: result.kind),
                affectedEntityIDs: [result.plantID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishQuickMoment(_ result: MomentCommandResult, petID: UUID?, note: String) {
        var affected = Set(result.savedLogIDs)
        if let petID {
            affected.insert(petID)
        }
        publish(
            DomainMutationResult(
                command: .quickMoment(petID: petID),
                affectedEntityIDs: affected,
                wroteBusinessFact: !result.savedLogIDs.isEmpty,
                note: note
            )
        )
    }

    func publishPetCareRecord(_ result: PetCareTrackingCommandResult, note: String) {
        var affected: Set<UUID> = [result.petID, result.careLogID]
        if let linkedPottyLogID = result.linkedPottyLogID {
            affected.insert(linkedPottyLogID)
        }
        publish(
            DomainMutationResult(
                command: .petCareRecord(petID: result.petID, type: result.careType.rawValue),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetCareDelete(_ result: PetCareTrackingDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.petID)
        affected.insert(result.careLogID)
        if let linkedPottyLogID = result.linkedPottyLogID {
            affected.insert(linkedPottyLogID)
        }
        publish(
            DomainMutationResult(
                command: .petCareDelete(petID: result.petID, logID: result.careLogID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetPottyDelete(_ result: PetPottyDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.petID)
        affected.insert(result.logID)
        publish(
            DomainMutationResult(
                command: .petPottyDelete(petID: result.petID, logID: result.logID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishCatCareRecord(_ result: CatCareCommandResult, note: String) {
        var affected: Set<UUID> = [result.petID, result.eventID]
        if let hygieneLogID = result.hygieneLogID {
            affected.insert(hygieneLogID)
        }
        publish(
            DomainMutationResult(
                command: .catCareRecord(petID: result.petID, action: result.actionRaw),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishCatCareUndo(_ result: CatCareUndoCommandResult, note: String) {
        var affected: Set<UUID> = [result.petID, result.eventID]
        if let hygieneLogID = result.hygieneLogID {
            affected.insert(hygieneLogID)
        }
        publish(
            DomainMutationResult(
                command: .catCareUndo(petID: result.petID, eventID: result.eventID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetWalkGoal(_ result: PetWalkGoalCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petWalkGoal(petID: result.petID),
                affectedEntityIDs: [result.petID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetWalkSummary(_ result: PetWalkSummaryCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petWalkSummary(petID: result.petID, walkID: result.walkID),
                affectedEntityIDs: [result.petID, result.walkID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPlantCare(_ result: PlantCareCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .plantCare(plantID: result.plantID, action: result.careType.rawValue),
                affectedEntityIDs: [result.plantID, result.logID, result.eventID, result.ledgerEventID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishCalendarEventPlan(
        _ result: CalendarEventPlanCommandResult,
        relatedEntityId: String,
        note: String
    ) {
        var affected = Set(result.reminderIDs)
        affected.insert(result.eventID)
        if let relatedID = UUID(uuidString: relatedEntityId) {
            affected.insert(relatedID)
        }
        publish(
            DomainMutationResult(
                command: .calendarEventPlan(eventID: result.eventID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishCalendarEventCompletion(_ result: CalendarEventCompletionResult, note: String) {
        publish(
            DomainMutationResult(
                command: .calendarEventCompletion(eventID: result.eventID, isCompleted: result.isCompleted),
                affectedEntityIDs: [result.eventID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishEventCompletionReward(
        _ result: EventCompletionRewardResult,
        eventID: UUID,
        note: String
    ) {
        publish(
            DomainMutationResult(
                command: .todayFocus(entityID: eventID, action: "eventCompleteReward"),
                affectedEntityIDs: [eventID],
                wroteBusinessFact: result.awarded,
                note: note
            )
        )
    }

    func publishCalendarEventDeletion(
        _ outcome: CalendarEventDeletionOutcome,
        scope: CalendarEventDeletionScope,
        note: String
    ) {
        let affected = outcome.affectedEventIDs
        publish(
            DomainMutationResult(
                command: .calendarEventDeletion(
                    eventID: outcome.primaryEventID,
                    scope: scope.revisionActionKey
                ),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanWorkout(_ result: WorkoutCommandResult, command: DomainCommand, note: String) {
        var affected: Set<UUID> = [result.logID]
        if let subjectID = result.subjectID {
            affected.insert(subjectID)
        }
        if let ledgerEventID = result.ledgerEventID {
            affected.insert(ledgerEventID)
        }
        publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanWorkoutDelete(_ result: WorkoutDeleteCommandResult, command: DomainCommand, note: String) {
        var affected: Set<UUID> = [result.subjectID, result.logID]
        affected.formUnion(result.removedLedgerEventIDs)
        publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishQuickHumanMedication(_ result: HumanMedicationCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .quickHumanMedication(humanID: result.subjectID),
                affectedEntityIDs: [result.subjectID, result.medicationID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanMedicationPlan(
        _ result: HumanMedicationPlanCommandResult,
        commandMedicationID: UUID?,
        note: String
    ) {
        var affected: Set<UUID> = [result.subjectID, result.medicationID]
        affected.formUnion(result.calendarEventIDs)
        affected.formUnion(result.removedCalendarEventIDs)
        publish(
            DomainMutationResult(
                command: .humanMedicationPlan(humanID: result.subjectID, medicationID: commandMedicationID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanMedicationPlanActivation(_ result: HumanMedicationPlanActivationCommandResult, note: String) {
        var affected: Set<UUID> = [result.subjectID, result.medicationID]
        affected.formUnion(result.calendarEventIDs)
        affected.formUnion(result.removedCalendarEventIDs)
        publish(
            DomainMutationResult(
                command: .humanMedicationPlanActivation(
                    humanID: result.subjectID,
                    medicationID: result.medicationID,
                    isActive: result.isActive
                ),
                affectedEntityIDs: affected,
                wroteBusinessFact: result.didChange || !result.calendarEventIDs.isEmpty || !result.removedCalendarEventIDs.isEmpty,
                note: note
            )
        )
    }

    func publishHumanMedicationPlanDelete(_ result: HumanMedicationPlanDeleteCommandResult, note: String) {
        var affected: Set<UUID> = [result.subjectID, result.medicationID]
        affected.formUnion(result.removedCalendarEventIDs)
        publish(
            DomainMutationResult(
                command: .humanMedicationPlanDelete(humanID: result.subjectID, medicationID: result.medicationID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanMedicationDose(
        _ result: HumanMedicationDoseCommandResult,
        scheduledMinute: Int,
        note: String
    ) {
        publish(
            DomainMutationResult(
                command: .humanMedicationDose(
                    humanID: result.subjectID,
                    medicationID: result.medicationID,
                    scheduledMinute: scheduledMinute,
                    status: result.status.rawValue
                ),
                affectedEntityIDs: Set([result.subjectID, result.medicationID, result.logID].compactMap { $0 }),
                wroteBusinessFact: result.didChange,
                note: note
            )
        )
    }

    func publishHumanHealthMetric(_ result: HumanHealthMetricCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanHealthMetric(humanID: result.subjectID, metricKey: result.metricKey),
                affectedEntityIDs: [result.subjectID, result.logID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanHealthMetricDelete(_ result: HumanHealthMetricDeleteCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanHealthMetricDelete(
                    humanID: result.humanID,
                    metricKey: result.metricKey,
                    logID: result.logID
                ),
                affectedEntityIDs: [result.humanID, result.logID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanNote(_ result: HumanNoteCommandResult, note: String) {
        var affected: Set<UUID> = [result.subjectID]
        if let eventID = result.eventID {
            affected.insert(eventID)
        }
        if let reminderID = result.reminderID {
            affected.insert(reminderID)
        }
        publish(
            DomainMutationResult(
                command: .humanNote(humanID: result.subjectID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanNoteDelete(_ result: HumanNoteDeleteResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanNote(humanID: result.subjectID),
                affectedEntityIDs: [result.subjectID],
                wroteBusinessFact: result.didDelete,
                note: note
            )
        )
    }

    func publishHumanHealthReport(_ result: HumanHealthReportCommandResult, action: String, note: String) {
        publish(
            DomainMutationResult(
                command: .humanHealthReport(
                    humanID: result.humanID,
                    reportID: result.reportID,
                    action: action
                ),
                affectedEntityIDs: [result.humanID, result.reportID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishWeightEntry(
        command: DomainCommand,
        subjectID: UUID,
        result: WeightCommandResult,
        note: String
    ) {
        var affected: Set<UUID> = [subjectID, result.logID]
        if let ledgerEventID = result.ledgerEventID {
            affected.insert(ledgerEventID)
        }
        publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishWeightDelete(_ result: DashboardRecordDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.subjectID)
        affected.insert(result.recordID)
        publish(
            DomainMutationResult(
                command: .weightDelete(
                    entityID: result.subjectID,
                    entityKind: result.subjectKind,
                    recordID: result.recordID
                ),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishExpenseEntry(
        command: DomainCommand,
        subjectID: UUID,
        result: ExpenseCommandResult,
        note: String
    ) {
        var affected: Set<UUID> = [subjectID, result.logID]
        if let ledgerEventID = result.ledgerEventID {
            affected.insert(ledgerEventID)
        }
        if let documentID = result.documentID {
            affected.insert(documentID)
        }
        publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishExpenseDelete(_ result: DashboardRecordDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.subjectID)
        affected.insert(result.recordID)
        publish(
            DomainMutationResult(
                command: .expenseDelete(
                    entityID: result.subjectID,
                    entityKind: result.subjectKind,
                    recordID: result.recordID
                ),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishReminderAction(_ result: ReminderCommandResult, note: String) {
        var affected: Set<UUID> = [result.reminderID]
        if let eventID = result.eventID {
            affected.insert(eventID)
        }
        publish(
            DomainMutationResult(
                command: .reminderCompletion(reminderID: result.reminderID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetDocumentCreate(_ result: PetDocumentCommandResult, category: DocumentCategory, note: String) {
        var affected = Set(result.expenseLogIDs)
        affected.formUnion(result.ledgerEventIDs)
        affected.insert(result.petID)
        affected.insert(result.documentID)
        publish(
            DomainMutationResult(
                command: .petDocumentCreate(petID: result.petID, category: category.rawValue),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetDocumentUpdate(_ result: PetDocumentCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petDocumentUpdate(petID: result.petID, documentID: result.documentID),
                affectedEntityIDs: [result.petID, result.documentID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetDocumentDelete(_ result: PetDocumentDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.petID)
        affected.insert(result.documentID)
        publish(
            DomainMutationResult(
                command: .petDocumentDelete(petID: result.petID, documentID: result.documentID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetPhotoCreate(_ result: PetPhotoAlbumCreateResult, note: String) {
        guard !result.photoIDs.isEmpty else { return }
        publish(
            DomainMutationResult(
                command: .petPhotoCreate(petID: result.petID),
                affectedEntityIDs: Set([result.petID] + result.photoIDs),
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetPhotoUpdate(_ result: PetPhotoAlbumUpdateResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petPhotoUpdate(petID: result.petID, photoID: result.photoID),
                affectedEntityIDs: [result.petID, result.photoID],
                wroteBusinessFact: result.didChange,
                note: note
            )
        )
    }

    func publishPetPhotoDelete(_ result: PetPhotoAlbumDeleteResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petPhotoDelete(petID: result.petID, photoID: result.photoID),
                affectedEntityIDs: [result.petID, result.photoID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetMilestoneSeed(_ result: PetMilestoneCommandResult, note: String) {
        guard !result.milestoneIDs.isEmpty else { return }
        publish(
            DomainMutationResult(
                command: .petMilestoneSeed(petID: result.petID),
                affectedEntityIDs: Set([result.petID] + result.milestoneIDs),
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetMilestoneRecord(_ result: PetMilestoneCommandResult, note: String) {
        guard let milestoneID = result.milestoneIDs.first else { return }
        publish(
            DomainMutationResult(
                command: .petMilestoneRecord(petID: result.petID),
                affectedEntityIDs: [result.petID, milestoneID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetMilestoneDelete(_ result: PetMilestoneDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.petID)
        affected.insert(result.milestoneID)
        publish(
            DomainMutationResult(
                command: .petMilestoneDelete(petID: result.petID, milestoneID: result.milestoneID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanWishlistCreate(_ result: HumanWishlistCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanWishlistCreate(humanID: result.humanID),
                affectedEntityIDs: [result.humanID, result.itemID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanWishlistRedeem(_ result: HumanWishlistCommandResult, note: String) {
        var affected: Set<UUID> = [result.humanID, result.itemID]
        if let ledgerEventID = result.ledgerEventID {
            affected.insert(ledgerEventID)
        }
        publish(
            DomainMutationResult(
                command: .humanWishlistRedeem(humanID: result.humanID, itemID: result.itemID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishHumanWishlistDelete(_ result: HumanWishlistDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.humanID)
        affected.insert(result.itemID)
        publish(
            DomainMutationResult(
                command: .humanWishlistDelete(humanID: result.humanID, itemID: result.itemID),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetMedicationPlan(_ result: PetMedicationPlanCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petMedicationPlan(petID: result.subjectID, medicationID: result.medicationID),
                affectedEntityIDs: [result.subjectID, result.medicationID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetMedicationPlanDelete(_ result: PetMedicationPlanDeleteCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petMedicationPlanDelete(petID: result.subjectID, medicationID: result.medicationID),
                affectedEntityIDs: [result.subjectID, result.medicationID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetMedicationPlanActivation(
        _ result: PetMedicationPlanActivationCommandResult,
        note: String
    ) {
        publish(
            DomainMutationResult(
                command: .petMedicationPlanActivation(
                    petID: result.subjectID,
                    medicationID: result.medicationID,
                    isActive: result.isActive
                ),
                affectedEntityIDs: [result.subjectID, result.medicationID],
                wroteBusinessFact: result.didChange,
                note: note
            )
        )
    }

    func publishPetHealthRecord(_ result: PetHealthCommandResult, type: String, note: String) {
        var affected: Set<UUID> = [result.subjectID, result.logID]
        if let expenseLogID = result.expenseLogID {
            affected.insert(expenseLogID)
        }
        if let eventID = result.eventID {
            affected.insert(eventID)
        }
        if let reminderID = result.reminderID {
            affected.insert(reminderID)
        }
        publish(
            DomainMutationResult(
                command: .petHealthRecord(petID: result.subjectID, type: type),
                affectedEntityIDs: affected,
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetSymptom(_ result: PetSymptomCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petHealthRecord(petID: result.subjectID, type: "symptom"),
                affectedEntityIDs: [result.subjectID, result.logID, result.ledgerEventID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetHeatCycle(_ result: PetHeatCycleCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petHealthRecord(petID: result.subjectID, type: "heat"),
                affectedEntityIDs: [result.subjectID, result.logID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetHealthDelete(_ result: PetHealthDeleteResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petHealthDelete(petID: result.subjectID, kind: result.kind, recordID: result.recordID),
                affectedEntityIDs: [result.subjectID, result.recordID],
                wroteBusinessFact: result.didDelete,
                note: note
            )
        )
    }

    func publishPetHygieneRecord(_ result: PetHygieneCheckInCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petHygieneRecord(petID: result.subjectID, type: result.hygieneType.rawValue),
                affectedEntityIDs: [result.subjectID, result.logID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishPetHygieneDelete(_ result: PetHygieneDeleteCommandResult, note: String) {
        var affected = Set(result.removedLedgerEventIDs)
        affected.insert(result.subjectID)
        affected.insert(result.logID)
        publish(
            DomainMutationResult(
                command: .petHygieneDelete(petID: result.subjectID, recordID: result.logID),
                affectedEntityIDs: affected,
                wroteBusinessFact: result.didDelete,
                note: note
            )
        )
    }

    func publishPetHygienePlan(_ result: PetHygienePlanCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petHygienePlan(petID: result.subjectID, type: result.hygieneType.rawValue),
                affectedEntityIDs: [result.subjectID, result.eventID, result.reminderID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishInsurancePolicy(_ result: InsurancePolicyCommandResult, action: String, note: String) {
        var affected: Set<UUID> = [result.petID, result.policyID]
        affected.formUnion(result.expenseLogIDs)
        affected.formUnion(result.eventIDs)
        publish(
            DomainMutationResult(
                command: .insurancePolicy(petID: result.petID, policyID: result.policyID, action: action),
                affectedEntityIDs: affected,
                wroteBusinessFact: result.didChange,
                note: note
            )
        )
    }

    func publishInsuranceClaim(_ result: InsuranceClaimCommandResult, action: String, note: String) {
        var affected: Set<UUID> = [result.petID, result.policyID, result.claimID]
        if let expenseLogID = result.expenseLogID {
            affected.insert(expenseLogID)
        }
        publish(
            DomainMutationResult(
                command: .insuranceClaim(
                    petID: result.petID,
                    policyID: result.policyID,
                    claimID: result.claimID,
                    action: action
                ),
                affectedEntityIDs: affected,
                wroteBusinessFact: result.didChange,
                note: note
            )
        )
    }

    func publishPetBondVaultUnlock(_ result: PetBondVaultUnlockCommandResult, note: String) {
        var affected: Set<UUID> = []
        if let ledgerEventID = result.ledgerEventID {
            affected.insert(ledgerEventID)
        }
        affected.insert(result.petID)
        publish(
            DomainMutationResult(
                command: .petBondVaultUnlock(petID: result.petID, itemID: result.itemID),
                affectedEntityIDs: affected,
                wroteBusinessFact: result.didUnlock,
                note: note
            )
        )
    }

    func publishShopPurchase(_ result: ShopPurchaseCommandResult, note: String) {
        var affected: Set<UUID> = []
        if let humanID = result.humanID {
            affected.insert(humanID)
        }
        if let ledgerEventID = result.ledgerEventID {
            affected.insert(ledgerEventID)
        }
        publish(
            DomainMutationResult(
                command: .shopPurchase(humanID: result.humanID, itemID: result.itemID),
                affectedEntityIDs: affected,
                wroteBusinessFact: result.didPurchase,
                note: note
            )
        )
    }

    func publishAchievementReward(_ result: AchievementRewardCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .achievementReward(
                    entityID: result.entityID,
                    kind: result.entityKind,
                    badgeIDs: result.badgeIDs
                ),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: result.didClaim,
                note: note
            )
        )
    }

    func publishBackdateCheckIn(_ result: BackdateCheckInCommandResult, note: String) {
        var affected: Set<UUID> = [result.petID]
        if let humanID = result.humanID {
            affected.insert(humanID)
        }
        publish(
            DomainMutationResult(
                command: .backdateCheckIn(petID: result.petID, action: result.actionKey),
                affectedEntityIDs: affected,
                wroteBusinessFact: result.didAward,
                note: note
            )
        )
    }

    func publishPetCardAppearance(_ result: PetCardAppearanceCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .petCardAppearance(petID: result.petID, action: result.action),
                affectedEntityIDs: [result.petID],
                wroteBusinessFact: true,
                note: note
            )
        )
    }

    func publishAvatar2DUpgrade(_ result: Avatar2DUpgradeCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .avatar2DUpgrade(entityID: result.entityID, kind: result.kind),
                affectedEntityIDs: [result.entityID],
                wroteBusinessFact: result.didUpgrade,
                note: note
            )
        )
    }
}

@MainActor
final class DeferredDomainCommandQueue: ObservableObject {
    @Published private(set) var pendingCount = 0

    private var tasks: [UUID: Task<Void, Never>] = [:]

    @discardableResult
    func enqueue(
        _ command: DomainCommand,
        delayMilliseconds: UInt64 = 0,
        operation: @escaping @MainActor () -> Void
    ) -> UUID {
        let id = UUID()
        AppPerformanceMonitor.shared.record(
            "domain_command_deferred",
            valueMS: 0,
            note: "\(command)"
        )
        tasks[id]?.cancel()
        tasks[id] = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled else {
                self.finish(id)
                return
            }
            operation()
            self.finish(id)
        }
        pendingCount = tasks.count
        return id
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        pendingCount = 0
    }

    private func finish(_ id: UUID) {
        tasks[id] = nil
        pendingCount = tasks.count
    }
}
