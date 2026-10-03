import Foundation

struct SettingsHumanSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let avatarEmoji: String
    let themeColorHex: String
    let appleUserIdentifier: String
    let hasPasscode: Bool
    let hasPassedAway: Bool

    nonisolated init(
        id: UUID,
        name: String,
        avatarEmoji: String,
        themeColorHex: String,
        appleUserIdentifier: String,
        hasPasscode: Bool,
        hasPassedAway: Bool
    ) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.themeColorHex = themeColorHex
        self.appleUserIdentifier = appleUserIdentifier
        self.hasPasscode = hasPasscode
        self.hasPassedAway = hasPassedAway
    }

    nonisolated init(human: Human) {
        self.init(
            id: human.id,
            name: human.name,
            avatarEmoji: human.avatarEmoji,
            themeColorHex: human.themeColor,
            appleUserIdentifier: human.appleUserIdentifier,
            hasPasscode: !human.pinHash.isEmpty && !human.pinSalt.isEmpty,
            hasPassedAway: human.hasPassedAway
        )
    }

    func displayName(fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

enum SettingsActiveHumanSelectionPolicy {
    static func selectableHumans(
        from humans: [SettingsHumanSnapshot]
    ) -> [SettingsHumanSnapshot] {
        humans.filter { !$0.hasPassedAway }
    }

    /// Keeps a valid local binding, repairs it when exactly one living Human
    /// remains, and otherwise leaves the device waiting for an explicit choice.
    static func resolvedHumanID(
        currentHumanID: UUID?,
        humans: [SettingsHumanSnapshot]
    ) -> UUID? {
        let selectable = selectableHumans(from: humans)
        if let currentHumanID,
           selectable.contains(where: { $0.id == currentHumanID }) {
            return currentHumanID
        }
        return selectable.count == 1 ? selectable[0].id : nil
    }
}

struct SettingsPetSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let avatarEmoji: String
    let canWriteWallet: Bool

    nonisolated init(id: UUID, name: String, avatarEmoji: String, canWriteWallet: Bool) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.canWriteWallet = canWriteWallet
    }

    nonisolated init(pet: Pet) {
        self.init(
            id: pet.id,
            name: pet.name,
            avatarEmoji: pet.avatarEmoji,
            canWriteWallet: EconomyWalletWritePolicy.canWrite(pet)
        )
    }

    func displayName(fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

struct SettingsHouseholdSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let ckShareRecordName: String

    nonisolated init(id: UUID, name: String, ckShareRecordName: String) {
        self.id = id
        self.name = name
        self.ckShareRecordName = ckShareRecordName
    }

    nonisolated init(household: Household) {
        self.init(
            id: household.id,
            name: household.name,
            ckShareRecordName: household.ckShareRecordName
        )
    }
}
