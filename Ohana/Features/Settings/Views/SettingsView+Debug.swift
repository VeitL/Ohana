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

            if SettingsDebugTools.isRunningUITests {
                settingsRow(
                    icon: "bag.fill",
                    title: l.tr(zh: "Debug 奖励层", en: "Debug Reward Tier", de: "Debug-Belohnungsstufe"),
                    subtitle: l.tr(zh: "解锁商店/奖励层 GUI 测试", en: "Unlock shop/reward GUI tests", de: "Shop-/Belohnungs-GUI-Tests freischalten"),
                    iconColor: Color.goPrimary
                ) {
                    applyUITestRewardTierShortcut()
                }
                .accessibilityIdentifier("settings-debug-reward-tier")

                settingsRow(
                    icon: "arrow.counterclockwise.circle.fill",
                    title: l.tr(zh: "Debug 重置奖励预算", en: "Debug Reset Reward Budget", de: "Debug-Belohnungsbudget zurücksetzen"),
                    subtitle: l.tr(zh: "隔离奖励正向路径 GUI 测试", en: "Isolate positive reward GUI tests", de: "Positive Belohnungs-GUI-Tests isolieren"),
                    iconColor: Color.goTeal
                ) {
                    applyUITestEconomyBudgetResetShortcut()
                }
                .accessibilityIdentifier("settings-debug-economy-budget-reset")
            }
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

    func applyUITestRewardTierShortcut() {
        #if DEBUG
            OasisTreeManagerRegistry.current.setEnergyForTesting(
                injectedEnergy: OasisTreeManager.levelStartThreshold(forRawLevel: 6)
            )
        #endif
        closeSettings()
    }

    func applyUITestEconomyBudgetResetShortcut() {
        #if DEBUG
            EconomyDailyBudgetStore.resetAllForTesting(context: modelContext)
        #endif
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
