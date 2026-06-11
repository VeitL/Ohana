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
            OhanaStaticAppBackground()

            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(OhanaFont.adaptive(size: 44, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 86, height: 86)
                    .background(Color.ohanaCardSurface.opacity(0.88), in: Circle())

                Text("Ohana")
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
