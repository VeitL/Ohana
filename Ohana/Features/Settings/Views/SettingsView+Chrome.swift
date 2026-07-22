//
//  SettingsView+Chrome.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension SettingsView {
    // MARK: - Toolbar
    @ToolbarContentBuilder
    var settingsToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel) {
                closeSettings()
            } label: {
                Label(l.tr(zh: "关闭", en: "Close", de: "Schließen"), systemImage: "xmark")
            }
            .accessibilityIdentifier("settings-close-action")
        }

        ToolbarItem(placement: .primaryAction) {
            if SettingsDebugTools.isVisible {
                Menu {
                    Button {
                        openCoconutBalanceDebugTool()
                    } label: {
                        Label(l.tr(zh: "Debug 椰子", en: "Debug Coconuts", de: "Debug-Kokosnüsse"), systemImage: "hammer.fill")
                    }
                    .accessibilityIdentifier("settings-debug-coconuts-shortcut")

                    Button {
                        showingReminderObservability = true
                    } label: {
                        Label(
                            l.tr(zh: "提醒可观测面板", en: "Reminder Observability", de: "Erinnerungsbeobachtung"),
                            systemImage: "list.clipboard.fill"
                        )
                    }
                    .accessibilityIdentifier("settings-debug-reminder-observability-shortcut")
                } label: {
                    Label(l.tr(zh: "调试工具", en: "Debug Tools", de: "Debug-Werkzeuge"), systemImage: "ellipsis.circle")
                }
            }
        }
    }

    var settingsUITestShortcutSection: some View {
        Section(l.tr(zh: "UI 测试快捷方式", en: "UI Test Shortcuts", de: "UI-Test-Kurzbefehle")) {
            Button {
                openCoconutBalanceDebugTool()
            } label: {
                Label(l.tr(zh: "Debug 椰子", en: "Debug Coconuts", de: "Debug-Kokosnüsse"), systemImage: "hammer.fill")
            }
            .accessibilityIdentifier("settings-debug-coconuts-shortcut")

            Button {
                showingReminderObservability = true
            } label: {
                Label(l.tr(zh: "提醒可观测面板", en: "Reminder Observability", de: "Erinnerungsbeobachtung"), systemImage: "list.clipboard.fill")
            }
            .accessibilityIdentifier("settings-debug-reminder-observability-shortcut")

            Button {
                showingFamilyWeeklyReportDebug = true
            } label: {
                Label(l.tr(zh: "Debug 家庭周报", en: "Debug Weekly Report", de: "Debug-Wochenbericht"), systemImage: "chart.bar.doc.horizontal")
            }
            .accessibilityIdentifier("settings-debug-family-weekly-report-shortcut")

            Button {
                applyUITestRewardTierShortcut()
            } label: {
                Label(l.tr(zh: "Debug 奖励层", en: "Debug Reward Tier", de: "Debug-Belohnungsstufe"), systemImage: "bag.fill")
            }
            .accessibilityIdentifier("settings-debug-reward-tier-shortcut")

            Button {
                applyUITestEconomyBudgetResetShortcut()
            } label: {
                Label(l.tr(zh: "Debug 重置奖励预算", en: "Debug Reset Reward Budget", de: "Debug-Belohnungsbudget zurücksetzen"), systemImage: "arrow.counterclockwise.circle.fill")
            }
            .accessibilityIdentifier("settings-debug-economy-budget-reset-shortcut")

            Button {
                applyUITestPlantBaselineShortcut()
            } label: {
                Label(l.tr(zh: "Debug 植物基线", en: "Debug Plant Baseline", de: "Debug-Pflanzenbasis"), systemImage: "leaf.fill")
            }
            .accessibilityIdentifier("settings-debug-plant-baseline-shortcut")
        }
    }

    func closeSettings() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    // MARK: - Settings Section
    func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        Section {
            content()
        } header: {
            Text(title)
        }
    }

    func settingsRow(icon: String, title: String, subtitle: String, iconColor: Color = Color.goPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                settingsIcon(icon, color: iconColor)
                Text(title)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                }
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(tertiaryText.opacity(0.6))
            }
            .frame(minHeight: 44)
        }
    }

    func settingsIcon(_ icon: String, color _: Color) -> some View {
        Image(systemName: icon)
            .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaFunctionalIcon)
            .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
            .contentShape(Rectangle())
    }
}
