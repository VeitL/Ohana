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
        #if DEBUG
            OhanaUITestLaunchOptions.isRunningUITests
        #else
            ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TESTS")
        #endif
    }

    static var opensCoconutBalanceSheetInUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-OHANA_UI_TEST_OPEN_COCONUT_BALANCE_SHEET")
    }

    static var plantBaselineSeedCount: Int {
        #if DEBUG
            OhanaUITestLaunchOptions.plantBaselineSeedCount(defaultCount: 1)
        #else
            1
        #endif
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

            #if DEBUG
                NavigationLink {
                    PrimaryAccentLabView()
                } label: {
                    SettingsNavigationLabel(
                        icon: "paintpalette.fill",
                        title: l.tr(
                            zh: "主色实验室",
                            en: "Primary accent lab",
                            de: "Primärfarben-Labor",
                            es: "Laboratorio de color",
                            pt: "Laboratório de cor",
                            fr: "Laboratoire de couleur",
                            ja: "メインカラー実験室",
                            ko: "주 색상 실험실",
                            it: "Laboratorio colore"
                        ),
                        subtitle: l.tr(
                            zh: "分别比较浅色与深色模式的主色",
                            en: "Compare light and dark appearance accents",
                            de: "Akzentfarben für Hell und Dunkel vergleichen",
                            es: "Compara colores para modo claro y oscuro",
                            pt: "Compare cores nos modos claro e escuro",
                            fr: "Comparer les couleurs claire et sombre",
                            ja: "ライトとダークの主色を比較",
                            ko: "라이트와 다크 모드 주 색상 비교",
                            it: "Confronta i colori chiaro e scuro"
                        )
                    )
                }
                .accessibilityIdentifier("settings-debug-primary-accent")

                NavigationLink {
                    PerformanceDiagnosticsView()
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button(role: .cancel) { closeSettings() } label: {
                                    Label(l.tr(zh: "关闭", en: "Close", de: "Schließen"), systemImage: "xmark")
                                }
                                .labelStyle(.iconOnly)
                                .accessibilityIdentifier("settings-close-action")
                            }
                        }
                } label: {
                    SettingsNavigationLabel(
                        icon: "speedometer",
                        title: l.tr(zh: "性能诊断", en: "Performance diagnostics", de: "Leistungsdiagnose"),
                        subtitle: l.tr(zh: "设置打开阶段与轻量视觉实验", en: "Settings-open phases and visual experiment", de: "Einstellungsphasen und Darstellungstest")
                    )
                }
                .accessibilityIdentifier("settings-debug-performance-diagnostics")

                settingsRow(
                    icon: "paintpalette.fill",
                    title: l.tr(zh: "UI 规范展示", en: "UI Specification Showcase"),
                    subtitle: l.tr(zh: "查看 token、组件和页面契约", en: "Review tokens, components, and page contracts"),
                    iconColor: Color.goTeal
                ) {
                    showingUISpecShowcase = true
                }
                .accessibilityIdentifier("settings-debug-ui-spec-showcase")
            #endif

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
                    subtitle: l.tr(zh: "为植物 GUI 测试创建样本植物", en: "Create sample plants for GUI tests", de: "Beispielpflanzen für GUI-Tests erstellen"),
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
        let humanSnapshot = homeHumans?.first { $0.id.uuidString == currentActiveHumanId } ?? homeHumans?.first
        let human = humanSnapshot.flatMap { fetchSettingsHuman(id: $0.id) }
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
        if let petSnapshot = homePets?.first(where: { $0.canWriteWallet }),
           let pet = fetchSettingsPet(id: petSnapshot.id) {
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
                injectedEnergy: appServices.oasisTree.levelStartThreshold(forRawLevel: 6)
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
            UITestPlantBaselineSeeder.seed(
                modelContext: modelContext,
                services: appServices,
                desiredCount: SettingsDebugTools.plantBaselineSeedCount,
                revisionNote: "settings.plant.uiTestShortcut"
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
