import Foundation

extension DomainCommand {
    static func waterSettings(petID: UUID, action: String) -> DomainCommand {
        command("water", "settings", ["petID": petID.uuidString, "action": action])
    }

    static func waterLog(petID: UUID, source: String) -> DomainCommand {
        command("water", "log", ["petID": petID.uuidString, "source": source])
    }

    static func waterPlan(petID: UUID, action: String) -> DomainCommand {
        command("water", "plan", ["petID": petID.uuidString, "action": action])
    }

    static func waterMode(petID: UUID, mode: String) -> DomainCommand {
        command("water", "mode", ["petID": petID.uuidString, "mode": mode])
    }
}
