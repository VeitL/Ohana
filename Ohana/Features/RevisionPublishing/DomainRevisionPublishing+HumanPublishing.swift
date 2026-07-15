//
//  DomainRevisionPublishing+HumanPublishing.swift
//  Ohana
//
//  Revision publishing helpers for human health, medication, workout, notes, and wishlist flows.
//

import Foundation

extension DomainRevisionPublishing {
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
                wroteBusinessFact: result.didPersist,
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
                wroteBusinessFact: result.didPersist && result.didChange,
                note: note
            )
        )
    }

    func publishQuickHumanMedication(_ result: HumanMedicationCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .quickHumanMedication(humanID: result.subjectID),
                affectedEntityIDs: [result.subjectID, result.medicationID],
                wroteBusinessFact: result.didPersist,
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
                wroteBusinessFact: result.didPersist,
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
                wroteBusinessFact: result.didPersist && (result.didChange || !result.calendarEventIDs.isEmpty || !result.removedCalendarEventIDs.isEmpty),
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
                wroteBusinessFact: result.didPersist && result.didChange,
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
                affectedEntityIDs: Set([result.subjectID, result.medicationID, result.logID].compactMap(\.self)),
                wroteBusinessFact: result.didPersist && result.didChange,
                note: note
            )
        )
    }

    func publishHumanHealthMetric(_ result: HumanHealthMetricCommandResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanHealthMetric(humanID: result.subjectID, metricKey: result.metricKey),
                affectedEntityIDs: [result.subjectID, result.logID],
                wroteBusinessFact: result.didPersist,
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
                wroteBusinessFact: result.didChange,
                note: note
            )
        )
    }

    func publishHumanNote(_ result: HumanNoteCommandResult, note: String) {
        var affected: Set<UUID> = [result.subjectID]
        if let recordID = result.recordID {
            affected.insert(recordID)
        }
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
                wroteBusinessFact: result.didPersist,
                note: note
            )
        )
    }

    func publishHumanNoteDelete(_ result: HumanNoteDeleteResult, note: String) {
        publish(
            DomainMutationResult(
                command: .humanNote(humanID: result.subjectID),
                affectedEntityIDs: [result.subjectID],
                wroteBusinessFact: result.didPersist && result.didDelete,
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
                wroteBusinessFact: result.didChange,
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
}
