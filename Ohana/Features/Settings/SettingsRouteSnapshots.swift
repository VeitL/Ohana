import Foundation

struct SettingsHumanSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let avatarEmoji: String
    let themeColorHex: String
    let appleUserIdentifier: String
    let hasPasscode: Bool
    let hasPassedAway: Bool

    init(
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

    init(human: Human) {
        self.init(
            id: human.id,
            name: human.name,
            avatarEmoji: human.avatarEmoji,
            themeColorHex: human.themeColor,
            appleUserIdentifier: human.appleUserIdentifier,
            hasPasscode: HumanPasscodeService.hasPasscode(human),
            hasPassedAway: human.hasPassedAway
        )
    }

    func displayName(fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

struct SettingsPetSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let avatarEmoji: String
    let canWriteWallet: Bool

    init(id: UUID, name: String, avatarEmoji: String, canWriteWallet: Bool) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.canWriteWallet = canWriteWallet
    }

    init(pet: Pet) {
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

    init(id: UUID, name: String, ckShareRecordName: String) {
        self.id = id
        self.name = name
        self.ckShareRecordName = ckShareRecordName
    }

    init(household: Household) {
        self.init(
            id: household.id,
            name: household.name,
            ckShareRecordName: household.ckShareRecordName
        )
    }
}
