import Foundation

@MainActor
protocol HumanPrivacyManaging {
    func field(forHumanAction actionType: String) -> HumanPrivateField?
    func isLocked(_ field: HumanPrivateField, for human: Human, viewedBy viewerId: UUID?) -> Bool
    func unlockedHumans(for field: HumanPrivateField, from humans: [Human], viewedBy viewerId: UUID?) -> [Human]
    func publicHumans(for field: HumanPrivateField, from humans: [Human]) -> [Human]
    func isPubliclyHidden(_ field: HumanPrivateField, for human: Human) -> Bool
    func isPubliclyHidden(_ field: HumanPrivateField, humanId: String?, in humans: [Human]) -> Bool
    func isLocked(_ field: HumanPrivateField, humanId: String?, in humans: [Human], viewedBy viewerId: UUID?) -> Bool
    func isHumanQuickActionLocked(_ item: QuickActionItem, human: Human?, viewedBy viewerId: UUID?) -> Bool
    func badgeText(for field: HumanPrivateField, human: Human, viewedBy viewerId: UUID?) -> String
    func lockedMessage(for field: HumanPrivateField) -> String
}

@MainActor
final class StaticHumanPrivacyManager: HumanPrivacyManaging {
    func field(forHumanAction actionType: String) -> HumanPrivateField? {
        PrivacyService.field(forHumanAction: actionType)
    }

    func isLocked(_ field: HumanPrivateField, for human: Human, viewedBy viewerId: UUID?) -> Bool {
        PrivacyService.isLocked(field, for: human, viewedBy: viewerId)
    }

    func unlockedHumans(for field: HumanPrivateField, from humans: [Human], viewedBy viewerId: UUID?) -> [Human] {
        PrivacyService.unlockedHumans(for: field, from: humans, viewedBy: viewerId)
    }

    func publicHumans(for field: HumanPrivateField, from humans: [Human]) -> [Human] {
        PrivacyService.publicHumans(for: field, from: humans)
    }

    func isPubliclyHidden(_ field: HumanPrivateField, for human: Human) -> Bool {
        PrivacyService.isPubliclyHidden(field, for: human)
    }

    func isPubliclyHidden(_ field: HumanPrivateField, humanId: String?, in humans: [Human]) -> Bool {
        PrivacyService.isPubliclyHidden(field, humanId: humanId, in: humans)
    }

    func isLocked(_ field: HumanPrivateField, humanId: String?, in humans: [Human], viewedBy viewerId: UUID?) -> Bool {
        PrivacyService.isLocked(field, humanId: humanId, in: humans, viewedBy: viewerId)
    }

    func isHumanQuickActionLocked(_ item: QuickActionItem, human: Human?, viewedBy viewerId: UUID?) -> Bool {
        PrivacyService.isHumanQuickActionLocked(item, human: human, viewedBy: viewerId)
    }

    func badgeText(for field: HumanPrivateField, human: Human, viewedBy viewerId: UUID?) -> String {
        PrivacyService.badgeText(for: field, human: human, viewedBy: viewerId)
    }

    func lockedMessage(for field: HumanPrivateField) -> String {
        PrivacyService.lockedMessage(for: field)
    }
}
