import Foundation

@MainActor
protocol HumanPasscodeManaging {
    var maxFailedAttempts: Int { get }
    var lockoutDuration: TimeInterval { get }
    func isValidPin(_ pin: String) -> Bool
    func hasPasscode(_ human: Human) -> Bool
    func setPasscode(_ pin: String, for human: Human) throws
    func changePasscode(currentPin: String, newPin: String, for human: Human, now: Date) throws -> HumanPasscodeVerification
    func removePasscode(currentPin: String, for human: Human, now: Date) throws -> HumanPasscodeVerification
    func clearPasscode(for human: Human)
    @discardableResult
    func verify(_ pin: String, for human: Human, now: Date) -> HumanPasscodeVerification
    func remainingLockoutSeconds(for human: Human, now: Date) -> Int?
}

@MainActor
final class StaticHumanPasscodeManager: HumanPasscodeManaging {
    var maxFailedAttempts: Int { HumanPasscodeService.maxFailedAttempts }
    var lockoutDuration: TimeInterval { HumanPasscodeService.lockoutDuration }

    func isValidPin(_ pin: String) -> Bool {
        HumanPasscodeService.isValidPin(pin)
    }

    func hasPasscode(_ human: Human) -> Bool {
        HumanPasscodeService.hasPasscode(human)
    }

    func setPasscode(_ pin: String, for human: Human) throws {
        try HumanPasscodeService.setPasscode(pin, for: human)
    }

    func changePasscode(
        currentPin: String,
        newPin: String,
        for human: Human,
        now: Date = Date()
    ) throws -> HumanPasscodeVerification {
        try HumanPasscodeService.changePasscode(currentPin: currentPin, newPin: newPin, for: human, now: now)
    }

    func removePasscode(
        currentPin: String,
        for human: Human,
        now: Date = Date()
    ) throws -> HumanPasscodeVerification {
        try HumanPasscodeService.removePasscode(currentPin: currentPin, for: human, now: now)
    }

    func clearPasscode(for human: Human) {
        HumanPasscodeService.clearPasscode(for: human)
    }

    @discardableResult
    func verify(_ pin: String, for human: Human, now: Date = Date()) -> HumanPasscodeVerification {
        HumanPasscodeService.verify(pin, for: human, now: now)
    }

    func remainingLockoutSeconds(for human: Human, now: Date = Date()) -> Int? {
        HumanPasscodeService.remainingLockoutSeconds(for: human, now: now)
    }
}
