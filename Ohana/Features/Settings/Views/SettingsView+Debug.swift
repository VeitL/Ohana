//
//  SettingsView+Debug.swift
//  Ohana
//
//  Developer-only settings tools.
//

import SwiftData
import SwiftUI

enum SettingsDebugTools {
    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TESTS")
    }

    static var opensCoconutBalanceSheetInUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TEST_OPEN_COCONUT_BALANCE_SHEET")
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

            settingsRow(
                icon: "list.clipboard.fill",
                title: l.tr(zh: "提醒可观测面板", en: "Reminder Observability", de: "Erinnerungsbeobachtung"),
                subtitle: l.tr(zh: "查看权限、系统队列和调度账本", en: "Inspect permission, queue, and scheduling ledger", de: "Berechtigung, Warteschlange und Planungsprotokoll prüfen"),
                iconColor: Color.goPrimary
            ) {
                showingReminderObservability = true
            }
            .accessibilityIdentifier("settings-debug-reminder-observability")

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

                settingsRow(
                    icon: "leaf.fill",
                    title: l.tr(zh: "Debug 植物基线", en: "Debug Plant Baseline", de: "Debug-Pflanzenbasis"),
                    subtitle: l.tr(zh: "为植物 GUI 测试创建一株植物", en: "Create one plant for GUI tests", de: "Eine Pflanze für GUI-Tests erstellen"),
                    iconColor: Color.goTeal
                ) {
                    applyUITestPlantBaselineShortcut()
                }
                .accessibilityIdentifier("settings-debug-plant-baseline")
            }
        }
        .accessibilityIdentifier("settings-debug-section")
    }

    func openCoconutBalanceDebugTool() {
        if SettingsDebugTools.isRunningUITests,
           !SettingsDebugTools.opensCoconutBalanceSheetInUITests {
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

    func applyUITestPlantBaselineShortcut() {
        #if DEBUG
            let timestamp = Int(Date().timeIntervalSince1970)
            let plant = Plant(
                name: "Codex Pothos \(timestamp)",
                species: "Epipremnum aureum",
                location: "South window",
                avatarEmoji: "🪴",
                wateringIntervalDays: 7,
                fertilizingIntervalDays: 30,
                roomNameRaw: "Living room",
                potDiameterCm: 12,
                potMaterialRaw: "Ceramic",
                soilTypeRaw: "Well-draining potting mix",
                isIndoor: true,
                windowDirection: .south,
                lightLevel: .brightIndirect,
                currentHeightCm: 18,
                currentSpreadCm: 22,
                catalogSpeciesId: "epipremnum-aureum",
                remindersEnabled: true
            )
            plant.notes = "Seeded by UI tests"
            modelContext.insert(plant)
            PlantUnlockPolicy.noteExistingPlantData()
            modelContext.safeSave()
            appServices.domainRevisions.publishMemberCreation(
                entityID: plant.id,
                kind: EntityKind.plant.rawValue,
                note: "settings.plant.uiTestShortcut"
            )
        #endif
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
