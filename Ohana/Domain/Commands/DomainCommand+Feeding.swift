import Foundation

extension DomainCommand {
    static func feedSettings(petID: UUID) -> DomainCommand {
        command("feeding", "settings", ["petID": petID.uuidString])
    }

    static func feedLog(petID: UUID, source: String) -> DomainCommand {
        command("feeding", "log", ["petID": petID.uuidString, "source": source])
    }

    static func feedPlan(petID: UUID, action: String) -> DomainCommand {
        command("feeding", "plan", ["petID": petID.uuidString, "action": action])
    }

    static func feedStock(petID: UUID, action: String) -> DomainCommand {
        command("feeding", "stock", ["petID": petID.uuidString, "action": action])
    }

    static func feedMode(petID: UUID, mode: String) -> DomainCommand {
        command("feeding", "mode", ["petID": petID.uuidString, "mode": mode])
    }

    static func feedMaintenance(petID: UUID, action: String) -> DomainCommand {
        command("feeding", "maintenance", ["petID": petID.uuidString, "action": action])
    }
}
