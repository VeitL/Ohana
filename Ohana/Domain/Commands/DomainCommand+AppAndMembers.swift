import Foundation

extension DomainCommand {
    static func quickCare(entityID: UUID, action: String) -> DomainCommand {
        command("quickCare", action, ["entityID": entityID.uuidString])
    }

    static func todayFocus(entityID: UUID, action: String) -> DomainCommand {
        command("todayFocus", action, ["entityID": entityID.uuidString])
    }

    static func plantCare(plantID: UUID, action: String) -> DomainCommand {
        command("plants", action, ["plantID": plantID.uuidString])
    }

    static func plantBatchCare(batchID: UUID, action: String, count: Int) -> DomainCommand {
        command("plants", action, ["batchID": batchID.uuidString, "count": String(count)])
    }

    static func quickMoment(petID: UUID?) -> DomainCommand {
        command("moments", "quickMoment", ["petID": petID?.uuidString ?? "none"])
    }

    static func memberCreation(entityID: UUID, kind: String) -> DomainCommand {
        command("members", "creation", ["entityID": entityID.uuidString, "kind": kind])
    }

    static func memberProfile(entityID: UUID, kind: String) -> DomainCommand {
        command("members", "profile", ["entityID": entityID.uuidString, "kind": kind])
    }

    static func memberLifecycle(entityID: UUID, kind: String, action: String) -> DomainCommand {
        command("members", "lifecycle", ["entityID": entityID.uuidString, "kind": kind, "action": action])
    }

    static func memberHomeVisibility(entityID: UUID, kind: String, visible: Bool) -> DomainCommand {
        command("members", "homeVisibility", [
            "entityID": entityID.uuidString,
            "kind": kind,
            "visible": String(visible)
        ])
    }

    static func memberDeletion(entityID: UUID, kind: String) -> DomainCommand {
        command("members", "deletion", ["entityID": entityID.uuidString, "kind": kind])
    }

    static func settingsActiveHumanSwitch(humanID: UUID) -> DomainCommand {
        command("settings", "activeHumanSwitch", ["humanID": humanID.uuidString])
    }

    static func settingsCoconutBalance(humanID: UUID?, amount: Int) -> DomainCommand {
        command("settings", "coconutBalance", [
            "humanID": humanID?.uuidString ?? "legacy",
            "amount": String(amount)
        ])
    }

    static func calendarEventPlan(eventID: UUID?) -> DomainCommand {
        command("calendar", "eventPlan", ["eventID": eventID?.uuidString ?? "new"])
    }

    static func calendarEventCompletion(eventID: UUID, isCompleted: Bool) -> DomainCommand {
        command("calendar", "eventCompletion", [
            "eventID": eventID.uuidString,
            "isCompleted": String(isCompleted)
        ])
    }

    static func calendarEventDeletion(eventID: UUID, scope: String) -> DomainCommand {
        command("calendar", "eventDeletion", ["eventID": eventID.uuidString, "scope": scope])
    }

    static func reminderCompletion(reminderID: UUID) -> DomainCommand {
        command("reminders", "completion", ["reminderID": reminderID.uuidString])
    }

    static func unknown(action: String) -> DomainCommand {
        command("unknown", action)
    }
}
