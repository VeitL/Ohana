//
//  ReadModelRevisionCenter+FeaturePublishing.swift
//  Ohana
//
//  Feature-specific revision publishing helpers.
//

import Foundation

extension ReadModelRevisionCenter {
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

    func publishPetMedicationDose(_ result: PetMedicationDoseCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .medicationDose(petID: result.subjectID, medicationID: result.medicationID),
                affectedEntityIDs: [result.subjectID, result.medicationID, result.eventID],
                wroteBusinessFact: true,
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

}
