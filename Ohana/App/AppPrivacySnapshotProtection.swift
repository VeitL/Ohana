//
//  AppPrivacySnapshotProtection.swift
//  Ohana
//
//  App switcher snapshot privacy cover.
//

import SwiftUI

nonisolated enum AppPrivacySnapshotProtectionStore {
    static let hideSnapshotKey = "privacy_hide_app_switcher_snapshot"
    static let defaultHideSnapshot = true

    static func shouldShowProtection(isEnabled: Bool, scenePhase: ScenePhase) -> Bool {
        guard isEnabled else { return false }
        return scenePhase != .active
    }
}

struct AppPrivacySnapshotCover: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")

            Image("LaunchMark")
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .frame(width: 180, height: 180)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
