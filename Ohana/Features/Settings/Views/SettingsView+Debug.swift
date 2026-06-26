//
//  SettingsView+Debug.swift
//  Ohana
//
//  Developer-only settings tools.
//

#if DEBUG
import SwiftUI

extension SettingsView {
    var settingsDebugSection: some View {
        settingsSection(title: l.tr(zh: "调试", en: "Debug", de: "Debug")) {
            settingsRow(
                icon: "hammer.fill",
                title: l.tr(zh: "Debug 椰子", en: "Debug Coconuts", de: "Debug-Kokosnüsse"),
                subtitle: l.tr(zh: "植物/商店测试余额", en: "Plant/shop test balance", de: "Pflanzen-/Shop-Testwert"),
                iconColor: Color.goYellow
            ) {
                showingCoconutBalanceTest = true
            }
        }
    }
}
#endif
