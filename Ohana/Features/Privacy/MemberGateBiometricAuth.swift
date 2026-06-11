//
//  MemberGateBiometricAuth.swift
//  Ohana
//
//  Optional biometric shortcut for local member passcode gates.
//

import Foundation
import LocalAuthentication

nonisolated enum MemberGateBiometricAuthStore {
    static let enabledKey = "privacy_member_gate_biometrics_enabled"
    static let defaultEnabled = false

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }
}

nonisolated struct MemberGateBiometricAvailability: Equatable {
    let isAvailable: Bool
    let label: String
    let symbolName: String

    static let unavailable = MemberGateBiometricAvailability(
        isAvailable: false,
        label: "Face ID",
        symbolName: "faceid"
    )
}

nonisolated enum MemberGateBiometricAuthenticator {
    static func availability() -> MemberGateBiometricAvailability {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        guard canEvaluate else { return .unavailable }

        switch context.biometryType {
        case .touchID:
            return MemberGateBiometricAvailability(isAvailable: true, label: "Touch ID", symbolName: "touchid")
        case .faceID:
            return MemberGateBiometricAvailability(isAvailable: true, label: "Face ID", symbolName: "faceid")
        case .opticID:
            return MemberGateBiometricAvailability(isAvailable: true, label: "Optic ID", symbolName: "opticid")
        case .none:
            return .unavailable
        @unknown default:
            return MemberGateBiometricAvailability(isAvailable: true, label: "Biometrics", symbolName: "lock.shield")
        }
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
