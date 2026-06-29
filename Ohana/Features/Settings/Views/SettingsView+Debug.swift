//
//  SettingsView+Debug.swift
//  Ohana
//
//  Developer-only settings tools.
//

import SwiftUI

enum SettingsDebugTools {
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TESTS")
    }

    static var isVisible: Bool {
        #if DEBUG
            return true
        #else
            return isRunningUITests
        #endif
    }
}

extension SettingsView {
    var settingsDebugSection: some View {
        settingsSection(title: l.tr(zh: "调试", en: "Debug", de: "Debug")) {
            settingsRow(
                icon: "hammer.fill",
                title: l.tr(zh: "Debug 椰子", en: "Debug Coconuts", de: "Debug-Kokosnüsse"),
                subtitle: l.tr(zh: "植物/商店测试余额", en: "Plant/shop test balance", de: "Pflanzen-/Shop-Testwert"),
                iconColor: Color.goYellow
            ) {
                openCoconutBalanceDebugTool()
            }
            .accessibilityIdentifier("settings-debug-coconuts")
        }
        .accessibilityIdentifier("settings-debug-section")
    }

    func openCoconutBalanceDebugTool() {
        if SettingsDebugTools.isRunningUITests {
            applyUITestCoconutBalanceShortcut(amount: 1000)
        } else {
            showingCoconutBalanceTest = true
        }
    }

    func applyUITestCoconutBalanceShortcut(amount: Int) {
        let human = homeHumans?.first { $0.id.uuidString == currentActiveHumanId } ?? homeHumans?.first
        let executor = SettingsCommandExecutor(context: modelContext, services: appServices)
        let result = executor.applyCoconutBalanceTest(
            amount: amount,
            human: human,
            title: l.tr(zh: "测试调整椰子数量", en: "Test coconut balance adjustment", de: "Testanpassung Kokosnüsse"),
            actorName: human.map { displayNameForDebugCoconut($0) },
            note: "settings.coconut.uiTestShortcut",
            updatesProjection: false,
            publishesRevision: false
        )
        if let pet = homePets?.first(where: { EconomyWalletWritePolicy.canWrite($0) }) {
            executor.applyPetCoconutBalanceTest(
                amount: amount,
                pet: pet,
                actorName: displayNameForDebugCoconut(pet),
                note: "settings.coconut.uiTestShortcut.pet"
            )
        }
        currentActiveHumanId = result.humanID?.uuidString ?? currentActiveHumanId
        closeSettings()
    }

    private func displayNameForDebugCoconut(_ human: Human) -> String {
        let trimmed = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? l.tr(zh: "成员", en: "Member", de: "Mitglied") : trimmed
    }

    private func displayNameForDebugCoconut(_ pet: Pet) -> String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? l.tr(zh: "宠物", en: "Pet", de: "Haustier") : trimmed
    }
}
