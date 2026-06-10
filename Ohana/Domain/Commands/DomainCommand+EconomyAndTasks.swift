import Foundation

extension DomainCommand {
    static func legacyBounty(taskID: UUID, action: String) -> DomainCommand {
        command("familyTasks", action, ["taskID": taskID.uuidString])
    }

    static func coconutExchange(requestID: UUID) -> DomainCommand {
        command("economy", "coconutExchange", ["requestID": requestID.uuidString])
    }

    static func shopPurchase(humanID: UUID?, itemID: String) -> DomainCommand {
        command("shop", "purchase", [
            "humanID": humanID?.uuidString ?? "none",
            "itemID": itemID
        ])
    }

    static func achievementReward(entityID: UUID, kind: String, badgeIDs: [String]) -> DomainCommand {
        command("achievements", "reward", [
            "entityID": entityID.uuidString,
            "kind": kind,
            "badgeIDs": badgeIDs.sorted().joined(separator: "|")
        ])
    }

    static func backdateCheckIn(petID: UUID, action: String) -> DomainCommand {
        command("todayFocus", "backdateCheckIn", ["petID": petID.uuidString, "action": action])
    }

    static func dailyCheckIn(humanID: String) -> DomainCommand {
        command("todayFocus", "dailyCheckIn", ["humanID": humanID])
    }
}
