import Foundation

extension DomainCommand {
    static func quickWeight(petID: UUID) -> DomainCommand {
        command("weight", "quickPet", ["petID": petID.uuidString])
    }

    static func weightEntry(entityID: UUID, entityKind: String) -> DomainCommand {
        command("weight", "entry", ["entityID": entityID.uuidString, "entityKind": entityKind])
    }

    static func weightDelete(entityID: UUID, entityKind: String, recordID: UUID) -> DomainCommand {
        command("weight", "delete", [
            "entityID": entityID.uuidString,
            "entityKind": entityKind,
            "recordID": recordID.uuidString,
        ])
    }

    static func quickHumanExpense(humanID: UUID) -> DomainCommand {
        command("expenses", "quickHuman", ["humanID": humanID.uuidString])
    }

    static func expenseEntry(entityID: UUID, entityKind: String) -> DomainCommand {
        command("expenses", "entry", ["entityID": entityID.uuidString, "entityKind": entityKind])
    }

    static func expenseDelete(entityID: UUID, entityKind: String, recordID: UUID) -> DomainCommand {
        command("expenses", "delete", [
            "entityID": entityID.uuidString,
            "entityKind": entityKind,
            "recordID": recordID.uuidString,
        ])
    }

    static func quickHumanWorkout(humanID: UUID) -> DomainCommand {
        command("workouts", "quickHuman", ["humanID": humanID.uuidString])
    }

    static func humanWorkoutEntry(humanID: UUID) -> DomainCommand {
        command("workouts", "entry", ["humanID": humanID.uuidString])
    }

    static func humanWorkoutDelete(humanID: UUID, recordID: UUID) -> DomainCommand {
        command("workouts", "delete", ["humanID": humanID.uuidString, "recordID": recordID.uuidString])
    }

    static func quickHumanMedication(humanID: UUID) -> DomainCommand {
        command("humanMedication", "quick", ["humanID": humanID.uuidString])
    }

    static func humanMedicationPlan(humanID: UUID, medicationID: UUID?) -> DomainCommand {
        command("humanMedication", "plan", [
            "humanID": humanID.uuidString,
            "medicationID": medicationID?.uuidString ?? "new",
        ])
    }

    static func humanMedicationPlanActivation(humanID: UUID, medicationID: UUID, isActive: Bool) -> DomainCommand {
        command("humanMedication", "planActivation", [
            "humanID": humanID.uuidString,
            "medicationID": medicationID.uuidString,
            "isActive": String(isActive),
        ])
    }

    static func humanMedicationPlanDelete(humanID: UUID, medicationID: UUID) -> DomainCommand {
        command("humanMedication", "planDelete", [
            "humanID": humanID.uuidString,
            "medicationID": medicationID.uuidString,
        ])
    }

    static func humanMedicationDose(
        humanID: UUID,
        medicationID: UUID,
        scheduledMinute: Int,
        status: String
    ) -> DomainCommand {
        command("humanMedication", "dose", [
            "humanID": humanID.uuidString,
            "medicationID": medicationID.uuidString,
            "scheduledMinute": String(scheduledMinute),
            "status": status,
        ])
    }

    static func humanHealthMetric(humanID: UUID, metricKey: String) -> DomainCommand {
        command("humanHealth", "metric", ["humanID": humanID.uuidString, "metricKey": metricKey])
    }

    static func humanHealthMetricDelete(humanID: UUID, metricKey: String, logID: UUID) -> DomainCommand {
        command("humanHealth", "metricDelete", [
            "humanID": humanID.uuidString,
            "metricKey": metricKey,
            "logID": logID.uuidString,
        ])
    }

    static func humanHealthReport(humanID: UUID, reportID: UUID?, action: String) -> DomainCommand {
        command("humanHealth", "report", [
            "humanID": humanID.uuidString,
            "reportID": reportID?.uuidString ?? "new",
            "action": action,
        ])
    }

    static func avatar2DUpgrade(entityID: UUID, kind: String) -> DomainCommand {
        command("avatar", "2DUpgrade", ["entityID": entityID.uuidString, "kind": kind])
    }

    static func humanNote(humanID: UUID) -> DomainCommand {
        command("humanNotes", "write", ["humanID": humanID.uuidString])
    }

    static func humanPrivacy(humanID: UUID, action: String) -> DomainCommand {
        command("privacy", action, ["humanID": humanID.uuidString])
    }

    static func humanWishlistCreate(humanID: UUID) -> DomainCommand {
        command("wishlist", "create", ["humanID": humanID.uuidString])
    }

    static func humanWishlistRedeem(humanID: UUID, itemID: UUID) -> DomainCommand {
        command("wishlist", "redeem", ["humanID": humanID.uuidString, "itemID": itemID.uuidString])
    }

    static func humanWishlistDelete(humanID: UUID, itemID: UUID) -> DomainCommand {
        command("wishlist", "delete", ["humanID": humanID.uuidString, "itemID": itemID.uuidString])
    }
}
