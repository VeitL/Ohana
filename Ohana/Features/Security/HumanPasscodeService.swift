//
//  HumanPasscodeService.swift
//  Ohana
//
//  Local soft privacy gate for switching between human profiles.
//

import CryptoKit
import Foundation
import Security

enum HumanPasscodeError: Error, Equatable {
    case invalidFormat
    case passcodeNotSet
    case currentPasscodeIncorrect
    case confirmationMismatch
    case memberInactive
}

enum HumanPasscodeVerification: Equatable {
    case success
    case noPasscode
    case invalidFormat
    case incorrect(remainingAttempts: Int)
    case locked(until: Date)
    case memberInactive
}

enum HumanPasscodeService {
    static let maxFailedAttempts = 5
    static let lockoutDuration: TimeInterval = 30

    static func isValidPin(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    static func hasPasscode(_ human: Human) -> Bool {
        !human.pinHash.isEmpty && !human.pinSalt.isEmpty
    }

    static func setPasscode(_ pin: String, for human: Human) throws {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .accountSecurity).writesContent else {
            throw HumanPasscodeError.memberInactive
        }
        guard isValidPin(pin) else { throw HumanPasscodeError.invalidFormat }
        let salt = makeSalt()
        human.pinSalt = salt
        human.pinHash = hash(pin: pin, salt: salt)
        human.pinFailedAttempts = 0
        human.pinLockedUntil = nil
    }

    static func changePasscode(currentPin: String, newPin: String, for human: Human, now: Date = Date()) throws -> HumanPasscodeVerification {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .accountSecurity).writesContent else {
            return .memberInactive
        }
        guard hasPasscode(human) else { throw HumanPasscodeError.passcodeNotSet }
        guard isValidPin(newPin) else { throw HumanPasscodeError.invalidFormat }

        let result = verify(currentPin, for: human, now: now)
        guard result == .success else { return result }
        try setPasscode(newPin, for: human)
        return .success
    }

    static func removePasscode(currentPin: String, for human: Human, now: Date = Date()) throws -> HumanPasscodeVerification {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .accountSecurity).writesContent else {
            return .memberInactive
        }
        guard hasPasscode(human) else { throw HumanPasscodeError.passcodeNotSet }
        let result = verify(currentPin, for: human, now: now)
        guard result == .success else { return result }
        clearPasscode(for: human)
        return .success
    }

    static func clearPasscode(for human: Human) {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .accountSecurity).writesContent else { return }
        human.pinHash = ""
        human.pinSalt = ""
        human.pinFailedAttempts = 0
        human.pinLockedUntil = nil
    }

    @discardableResult
    static func verify(_ pin: String, for human: Human, now: Date = Date()) -> HumanPasscodeVerification {
        guard MemberLifecycleGate.disposition(human: human, writeKind: .accountSecurity).writesContent else {
            return .memberInactive
        }
        guard hasPasscode(human) else { return .noPasscode }
        guard isValidPin(pin) else { return .invalidFormat }

        if let lockedUntil = human.pinLockedUntil, lockedUntil > now {
            return .locked(until: lockedUntil)
        }

        if hash(pin: pin, salt: human.pinSalt) == human.pinHash {
            human.pinFailedAttempts = 0
            human.pinLockedUntil = nil
            return .success
        }

        human.pinFailedAttempts += 1
        if human.pinFailedAttempts >= maxFailedAttempts {
            let lockedUntil = now.addingTimeInterval(lockoutDuration)
            human.pinFailedAttempts = maxFailedAttempts
            human.pinLockedUntil = lockedUntil
            return .locked(until: lockedUntil)
        }

        return .incorrect(remainingAttempts: max(0, maxFailedAttempts - human.pinFailedAttempts))
    }

    static func remainingLockoutSeconds(for human: Human, now: Date = Date()) -> Int? {
        guard let lockedUntil = human.pinLockedUntil, lockedUntil > now else { return nil }
        return max(1, Int(ceil(lockedUntil.timeIntervalSince(now))))
    }

    static func hashForTesting(pin: String, salt: String) -> String {
        hash(pin: pin, salt: salt)
    }

    private static func hash(pin: String, salt: String) -> String {
        let payload = "\(salt):\(pin)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func makeSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}
