import Foundation

extension DomainCommand {
    static func medicationDose(petID: UUID, medicationID: UUID) -> DomainCommand {
        command("petMedication", "dose", ["petID": petID.uuidString, "medicationID": medicationID.uuidString])
    }

    static func petMedicationPlan(petID: UUID, medicationID: UUID?) -> DomainCommand {
        command("petMedication", "plan", [
            "petID": petID.uuidString,
            "medicationID": medicationID?.uuidString ?? "new"
        ])
    }

    static func petMedicationPlanActivation(petID: UUID, medicationID: UUID, isActive: Bool) -> DomainCommand {
        command("petMedication", "planActivation", [
            "petID": petID.uuidString,
            "medicationID": medicationID.uuidString,
            "isActive": String(isActive)
        ])
    }

    static func petMedicationPlanDelete(petID: UUID, medicationID: UUID) -> DomainCommand {
        command("petMedication", "planDelete", ["petID": petID.uuidString, "medicationID": medicationID.uuidString])
    }

    static func petHealthRecord(petID: UUID, type: String) -> DomainCommand {
        command("petHealth", "record", ["petID": petID.uuidString, "type": type])
    }

    static func petHealthDelete(petID: UUID, kind: String, recordID: UUID) -> DomainCommand {
        command("petHealth", "delete", [
            "petID": petID.uuidString,
            "kind": kind,
            "recordID": recordID.uuidString
        ])
    }

    static func petCareRecord(petID: UUID, type: String) -> DomainCommand {
        command("petCare", "record", ["petID": petID.uuidString, "type": type])
    }

    static func petCareDelete(petID: UUID, logID: UUID) -> DomainCommand {
        command("petCare", "delete", ["petID": petID.uuidString, "logID": logID.uuidString])
    }

    static func petPottyDelete(petID: UUID, logID: UUID) -> DomainCommand {
        command("petPotty", "delete", ["petID": petID.uuidString, "logID": logID.uuidString])
    }

    static func petWalkGoal(petID: UUID) -> DomainCommand {
        command("walks", "goal", ["petID": petID.uuidString])
    }

    static func petWalkSummary(petID: UUID, walkID: UUID) -> DomainCommand {
        command("walks", "summary", ["petID": petID.uuidString, "walkID": walkID.uuidString])
    }

    static func petBondVaultUnlock(petID: UUID, itemID: String) -> DomainCommand {
        command("bondVault", "unlock", ["petID": petID.uuidString, "itemID": itemID])
    }

    static func petCardAppearance(petID: UUID, action: String) -> DomainCommand {
        command("petCard", action, ["petID": petID.uuidString])
    }

    static func catCareRecord(petID: UUID, action: String) -> DomainCommand {
        command("catCare", "record", ["petID": petID.uuidString, "action": action])
    }

    static func catCareUndo(petID: UUID, eventID: UUID) -> DomainCommand {
        command("catCare", "undo", ["petID": petID.uuidString, "eventID": eventID.uuidString])
    }

    static func petHygieneRecord(petID: UUID, type: String) -> DomainCommand {
        command("hygiene", "record", ["petID": petID.uuidString, "type": type])
    }

    static func petHygieneDelete(petID: UUID, recordID: UUID) -> DomainCommand {
        command("hygiene", "delete", ["petID": petID.uuidString, "recordID": recordID.uuidString])
    }

    static func petHygienePlan(petID: UUID, type: String) -> DomainCommand {
        command("hygiene", "plan", ["petID": petID.uuidString, "type": type])
    }

    static func petMilestoneSeed(petID: UUID) -> DomainCommand {
        command("milestones", "seed", ["petID": petID.uuidString])
    }

    static func petMilestoneRecord(petID: UUID) -> DomainCommand {
        command("milestones", "record", ["petID": petID.uuidString])
    }

    static func petMilestoneDelete(petID: UUID, milestoneID: UUID) -> DomainCommand {
        command("milestones", "delete", ["petID": petID.uuidString, "milestoneID": milestoneID.uuidString])
    }

    static func petPhotoCreate(petID: UUID) -> DomainCommand {
        command("photos", "create", ["petID": petID.uuidString])
    }

    static func petPhotoUpdate(petID: UUID, photoID: UUID) -> DomainCommand {
        command("photos", "update", ["petID": petID.uuidString, "photoID": photoID.uuidString])
    }

    static func petPhotoDelete(petID: UUID, photoID: UUID) -> DomainCommand {
        command("photos", "delete", ["petID": petID.uuidString, "photoID": photoID.uuidString])
    }

    static func petDocumentCreate(petID: UUID, category: String) -> DomainCommand {
        command("documents", "create", ["petID": petID.uuidString, "category": category])
    }

    static func petDocumentUpdate(petID: UUID, documentID: UUID) -> DomainCommand {
        command("documents", "update", ["petID": petID.uuidString, "documentID": documentID.uuidString])
    }

    static func petDocumentDelete(petID: UUID, documentID: UUID) -> DomainCommand {
        command("documents", "delete", ["petID": petID.uuidString, "documentID": documentID.uuidString])
    }

    static func insurancePolicy(petID: UUID, policyID: UUID, action: String) -> DomainCommand {
        command("insurance", "policy", [
            "petID": petID.uuidString,
            "policyID": policyID.uuidString,
            "action": action
        ])
    }

    static func insuranceClaim(petID: UUID, policyID: UUID, claimID: UUID?, action: String) -> DomainCommand {
        command("insurance", "claim", [
            "petID": petID.uuidString,
            "policyID": policyID.uuidString,
            "claimID": claimID?.uuidString ?? "new",
            "action": action
        ])
    }
}
