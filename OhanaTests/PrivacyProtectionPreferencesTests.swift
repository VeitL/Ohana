import Foundation
import SwiftUI
import Testing
@testable import Ohana

struct PrivacyProtectionPreferencesTests {
    @Test func appSwitcherSnapshotProtectionOnlyShowsOutsideActivePhaseWhenEnabled() {
        #expect(AppPrivacySnapshotProtectionStore.defaultHideSnapshot)
        #expect(!AppPrivacySnapshotProtectionStore.shouldShowProtection(isEnabled: true, scenePhase: .active))
        #expect(AppPrivacySnapshotProtectionStore.shouldShowProtection(isEnabled: true, scenePhase: .inactive))
        #expect(AppPrivacySnapshotProtectionStore.shouldShowProtection(isEnabled: true, scenePhase: .background))
        #expect(!AppPrivacySnapshotProtectionStore.shouldShowProtection(isEnabled: false, scenePhase: .background))
    }

    @Test func memberGateBiometricPreferenceDefaultsOffAndCanBeEnabled() throws {
        let suiteName = "MemberGateBiometricAuthStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(!MemberGateBiometricAuthStore.isEnabled(defaults: defaults))
        defaults.set(true, forKey: MemberGateBiometricAuthStore.enabledKey)
        #expect(MemberGateBiometricAuthStore.isEnabled(defaults: defaults))
    }
}
