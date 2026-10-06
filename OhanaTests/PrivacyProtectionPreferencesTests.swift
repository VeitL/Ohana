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

    @Test func appSwitcherSnapshotCoverUsesTheConfiguredLaunchScreenAssets() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let cover = try String(
            contentsOf: root.appending(path: "Ohana/App/AppPrivacySnapshotProtection.swift"),
            encoding: .utf8
        )
        let info = try String(
            contentsOf: root.appending(path: "Ohana/Info.plist"),
            encoding: .utf8
        )

        #expect(cover.contains("Color(\"LaunchBackground\")"))
        #expect(cover.contains("Image(\"LaunchMark\")"))
        #expect(!cover.contains("lock.shield.fill"))
        #expect(!cover.contains("Text(\"Ohana\")"))
        #expect(info.contains("<string>LaunchBackground</string>"))
        #expect(info.contains("<string>LaunchMark</string>"))
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
