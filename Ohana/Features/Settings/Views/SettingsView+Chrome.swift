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

    var performanceToggleRow: some View {
        HStack(spacing: 12) {
            settingsIcon("battery.75percent", color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "省电模式", en: "Power Saving", de: "Energiesparen"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(
                    zh: "减少后台刷新和装饰动效",
                    en: "Reduces background refresh and decorative motion",
                    de: "Reduziert Hintergrundaktualisierung und Deko-Bewegung"
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $powerSavingMode)
                .tint(Color.goPrimary)
                .labelsHidden()
        }
        .frame(minHeight: 44)
        .animation(GoMotion.feedback, value: powerSavingMode)
        .onChange(of: powerSavingMode) { _, _ in
            AppWorkloadPolicy.shared.refresh(reason: "settingsPowerSavingChanged")
        }
    }

    var reducedVisualEffectsToggleRow: some View {
        HStack(spacing: 12) {
            settingsIcon("speedometer", color: Color.goTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "轻量视觉 A/B", en: "Reduced visual effects A/B", de: "Reduzierte Effekte A/B"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(
                    zh: "关闭常驻玻璃、噪点和文字投影，用于真机丝滑度对比",
                    en: "Disables persistent glass, noise, and text shadows for device smoothness comparison",
                    de: "Deaktiviert dauerhaftes Glas, Rauschen und Textschatten fuer Geraetevergleiche"
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $reducedVisualEffectsMode)
                .tint(Color.goTeal)
                .labelsHidden()
                .accessibilityLabel(l.tr(
                    zh: "轻量视觉 A/B",
                    en: "Reduced visual effects A/B",
                    de: "Reduzierte Effekte A/B"
                ))
        }
        .frame(minHeight: 44)
        .animation(GoMotion.feedback, value: reducedVisualEffectsMode)
        .onChange(of: reducedVisualEffectsMode) { _, enabled in
            AppWorkloadPolicy.shared.refresh(reason: "settingsReducedVisualEffectsChanged")
            AppPerformanceMonitor.shared.record(
                "visual_effects_ab_mode",
                valueMS: 0,
                note: enabled ? "efficient" : "full"
            )
        }
    }

    var privacySecuritySection: some View {
        settingsSection(title: l.tr(zh: "隐私与安全", en: "Privacy & Security", de: "Datenschutz & Sicherheit")) {
            appSwitcherSnapshotPrivacyRow
            if HumanLocalPrivacyPolicy.isEnabled {
                memberGateBiometricRow
            }
        }
    }

    var appSwitcherSnapshotPrivacyRow: some View {
        HStack(spacing: 12) {
            settingsIcon("rectangle.on.rectangle.slash", color: Color.goYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "隐藏 App 切换器预览", en: "Hide app switcher preview", de: "App-Umschalter-Vorschau ausblenden"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(
                    zh: "离开 App 时用遮罩覆盖健康与用药页面",
                    en: "Covers health and medication screens when leaving the app",
                    de: "Deckt Gesundheits- und Medikamentenseiten beim Verlassen ab"
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $hideAppSwitcherSnapshot)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    var memberGateBiometricRow: some View {
        HStack(spacing: 12) {
            settingsIcon(biometricGateAvailability.symbolName, color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "成员门禁使用 \(biometricGateAvailability.label)", en: "Use \(biometricGateAvailability.label) for member gate", de: "\(biometricGateAvailability.label) für Mitgliederschutz nutzen"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(memberGateBiometricSubtitle)
                    .font(OhanaFont.footnote())
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $enableMemberGateBiometrics)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 44)
        .onAppear {
            refreshBiometricGateAvailability()
        }
    }

    var memberGateBiometricSubtitle: String {
        if biometricGateAvailability.isAvailable {
            return l.tr(
                zh: "切换受保护成员时可用生物识别代替输入密码",
                en: "Use biometrics instead of typing the PIN for protected members",
                de: "Biometrie statt PIN beim Wechsel geschützter Mitglieder"
            )
        }
        return l.tr(
            zh: "当前设备不可用时会继续使用 4 位密码",
            en: "Falls back to the 4-digit PIN when biometrics are unavailable",
            de: "Fällt auf die 4-stellige PIN zurück, wenn Biometrie nicht verfügbar ist"
        )
    }

    func refreshBiometricGateAvailability() {
        biometricGateAvailability = MemberGateBiometricAuthenticator.availability()
    }

    var notificationPreferenceGroups: [NotificationPreferenceGroup] {
        NotificationPreferenceGroup.allCases
    }

    var enabledNotificationPreferenceCount: Int {
        _ = notificationPreferenceRevision
        return notificationPreferenceGroups.count(where: { NotificationPreferenceStore.isEnabled($0) })
    }

    var routineNotificationSummary: String {
        let enabledCount = enabledNotificationPreferenceCount
        let totalCount = notificationPreferenceGroups.count
        if enabledCount == totalCount {
            return l.tr(zh: "全部开启", en: "All on", de: "Alle an")
        }
        if enabledCount == 0 {
            return l.tr(zh: "全部关闭", en: "All off", de: "Alle aus")
        }
        return l.tr(
            zh: "\(enabledCount)/\(totalCount) 已开启",
            en: "\(enabledCount)/\(totalCount) on",
            de: "\(enabledCount)/\(totalCount) an"
        )
    }

    var routineNotificationsBinding: Binding<Bool> {
        Binding(
            get: {
                _ = notificationPreferenceRevision
                return notificationPreferenceGroups.allSatisfy { NotificationPreferenceStore.isEnabled($0) }
            },
            set: { value in
                notificationPreferenceGroups.forEach { NotificationPreferenceStore.set(value, for: $0) }
                notificationPreferenceRevision += 1
            }
        )
    }

    func notificationPreferenceBinding(for group: NotificationPreferenceGroup) -> Binding<Bool> {
        Binding(
            get: {
                _ = notificationPreferenceRevision
                return NotificationPreferenceStore.isEnabled(group)
            },
            set: { value in
                NotificationPreferenceStore.set(value, for: group)
                notificationPreferenceRevision += 1
            }
        )
    }

    var routineNotificationsToggleRow: some View {
        HStack(spacing: 12) {
            settingsIcon("bell.badge.fill", color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "常规提醒", en: "Routine reminders", de: "Reguläre Erinnerungen"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(routineNotificationSummary)
                    .font(OhanaFont.footnote())
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: routineNotificationsBinding)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 44)
        .animation(GoMotion.feedback, value: notificationPreferenceRevision)
        .accessibilityIdentifier("settings-routine-notifications-toggle")
    }

    var advancedNotificationSettingsDisclosure: some View {
        DisclosureGroup(isExpanded: $showAdvancedNotificationSettings) {
            advancedNotificationSettingsRows
        } label: {
            HStack(spacing: 12) {
                settingsIcon("slider.horizontal.3", color: Color.goTeal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "高级提醒设置", en: "Advanced reminder settings", de: "Erweiterte Erinnerungen"))
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(primaryText)
                    Text(routineNotificationSummary)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                }
            }
        }
        .accessibilityIdentifier("settings-advanced-notifications-disclosure")
    }

    var advancedNotificationSettingsRows: some View {
        VStack(spacing: 0) {
            notificationToggleRow(
                icon: "pills.fill",
                iconColor: Color(hex: "FF5A00"),
                title: l.tr(zh: "用药提醒", en: "Medication reminders", de: "Medikamentenerinnerungen"),
                group: .medication
            )
            notificationToggleRow(
                icon: "calendar.badge.clock",
                iconColor: Color.goBlue,
                title: l.tr(zh: "日历事项提醒", en: "Calendar event reminders", de: "Kalendererinnerungen"),
                group: .calendar
            )
            notificationToggleRow(
                icon: "fork.knife",
                iconColor: Color.goPrimary,
                title: l.tr(zh: "喂食提醒", en: "Feeding reminders", de: "Fütterungserinnerungen"),
                group: .feeding
            )
            notificationToggleRow(
                icon: "bubbles.and.sparkles.fill",
                iconColor: Color.goTeal,
                title: l.tr(zh: "护理提醒", en: "Care reminders", de: "Pflegeerinnerungen"),
                group: .hygiene
            )
            plantReminderSettingsPanel
            notificationToggleRow(
                icon: "checkmark.seal.fill",
                iconColor: Color.goYellow,
                title: l.tr(zh: "打卡提醒", en: "Check-in reminders", de: "Check-in-Erinnerungen"),
                group: .checkIn
            )
        }
    }

    func notificationToggleRow(icon: String, iconColor: Color, title: String, group: NotificationPreferenceGroup) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            Text(title)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(primaryText)
            Spacer()
            Toggle("", isOn: notificationPreferenceBinding(for: group))
            .tint(accentColor)
            .labelsHidden()
            .accessibilityIdentifier("settings-notification-\(group.rawValue)-toggle")
        }
        .frame(minHeight: 44)
    }

    var petMedicationNotificationPrivacyRow: some View {
        HStack(spacing: 12) {
            settingsIcon("eye.slash.fill", color: Color.goYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "隐藏用药通知细节", en: "Hide medication details", de: "Medikamentendetails ausblenden"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(
                    zh: "锁屏只显示通用提醒",
                    en: "Lock screen shows a generic reminder",
                    de: "Sperrbildschirm zeigt nur eine allgemeine Erinnerung"
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $hidePetMedicationNotificationDetails)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    func resetApp() {
        Task { @MainActor in
            do {
                let resetResult = try await appServices.appReset.reset(context: modelContext)
                currentActiveHumanId = ""
                withAnimation(GoMotion.page) {
                    hasOnboarded = false
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if case .pending = resetResult.humanNoteAttachmentCleanup {
                    appServices.islandToasts.show(l.tr(
                        zh: "App 数据已删除，但部分本地备注附件未能清理。请联系支持。",
                        en: "App data was deleted, but some local note attachments could not be removed. Contact support.",
                        de: "Die App-Daten wurden gelöscht, aber einige lokale Notizanhänge konnten nicht entfernt werden. Kontaktiere den Support."
                    ))
                }
                if case let .pending(message) = resetResult.automaticBackupCleanup {
                    automaticBackupCleanupError = l.tr(
                        zh: "App 内的数据已删除，但 iCloud Drive 中的旧自动备份尚未删除。请恢复网络后在“数据备份”中重试。\n\n\(message)",
                        en: "App data was deleted, but the previous automatic backup in iCloud Drive was not removed. Restore connectivity and retry from Data Backup.\n\n\(message)",
                        de: "Die App-Daten wurden gelöscht, aber das vorherige automatische Backup in iCloud Drive wurde nicht entfernt. Stelle die Verbindung wieder her und versuche es in Datensicherung erneut.\n\n\(message)"
                    )
                }
            } catch {
                appResetErrorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
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
