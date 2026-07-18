import SwiftUI

struct SettingsNotificationsPage: View {
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(MedicationNotificationPrivacyStore.hidePetDetailsKey) private var hidePetMedicationNotificationDetails = false
    @State private var showAdvancedNotificationSettings = false
    @State private var notificationPreferenceRevision = 0

    let experienceMode: AppExperienceMode
    let onClose: () -> Void

    private var l: L10n { L10n(appLanguage) }
    private var preferenceGroups: [NotificationPreferenceGroup] { NotificationPreferenceGroup.allCases }

    var body: some View {
        Form {
            Section {
                if experienceMode == .zen {
                    NavigationLink {
                        PresenceSafetySettingsView()
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button(role: .cancel, action: onClose) {
                                        Label(l.tr(zh: "关闭", en: "Close", de: "Schließen"), systemImage: "xmark")
                                    }
                                    .labelStyle(.iconOnly)
                                    .accessibilityIdentifier("settings-close-action")
                                }
                            }
                    } label: {
                        SettingsNavigationLabel(
                            icon: "checkmark.shield.fill",
                            title: l.tr(
                                zh: "佛系守护",
                                en: "Zen check-in safety",
                                de: "Zen-Check-in-Schutz",
                                es: "Seguridad del registro zen",
                                pt: "Segurança do check-in zen",
                                fr: "Sécurité du pointage zen",
                                ja: "佛系チェックインの見守り",
                                ko: "마음 편한 체크인 보호",
                                it: "Sicurezza check-in zen"
                            ),
                            subtitle: l.tr(
                                zh: "本机提醒、联系人和确认短信",
                                en: "On-device reminders, contacts, and confirmed texts",
                                de: "Lokale Erinnerungen, Kontakte und bestätigte SMS",
                                es: "Recordatorios, contactos y SMS confirmados",
                                pt: "Lembretes, contatos e SMS confirmados",
                                fr: "Rappels, contacts et SMS confirmés",
                                ja: "デバイス内通知、連絡先、確認付きSMS",
                                ko: "기기 내 알림, 연락처, 확인 문자",
                                it: "Promemoria, contatti e SMS confermati"
                            )
                        )
                    }
                    .accessibilityIdentifier("settings-presence-safety")
                }

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    SettingsNavigationLabel(icon: "bell.badge", title: l.notificationPermission, subtitle: l.manageNotification)
                }

                routineNotificationsToggleRow
                medicationPrivacyRow

                DisclosureGroup(isExpanded: $showAdvancedNotificationSettings) {
                    advancedNotificationSettingsRows
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "高级提醒设置", en: "Advanced reminder settings", de: "Erweiterte Erinnerungen"))
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(routineNotificationSummary)
                            .font(OhanaFont.footnote())
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings-advanced-notifications-disclosure")
                    .accessibilityValue(showAdvancedNotificationSettings
                        ? l.tr(zh: "已展开", en: "Expanded", de: "Erweitert")
                        : l.tr(zh: "已收起", en: "Collapsed", de: "Reduziert"))
                }
            }
        }
        .settingsNotificationsChrome(
            title: SettingsDestination.notifications.title(l),
            closeLabel: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
            onClose: onClose
        )
    }

    private var routineNotificationSummary: String {
        _ = notificationPreferenceRevision
        let enabledCount = preferenceGroups.count(where: { NotificationPreferenceStore.isEnabled($0) })
        if enabledCount == preferenceGroups.count {
            return l.tr(zh: "全部开启", en: "All on", de: "Alle an")
        }
        if enabledCount == 0 {
            return l.tr(zh: "全部关闭", en: "All off", de: "Alle aus")
        }
        return l.tr(zh: "\(enabledCount)/\(preferenceGroups.count) 已开启", en: "\(enabledCount)/\(preferenceGroups.count) on", de: "\(enabledCount)/\(preferenceGroups.count) an")
    }

    private var routineNotificationsBinding: Binding<Bool> {
        Binding(
            get: {
                _ = notificationPreferenceRevision
                return preferenceGroups.allSatisfy { NotificationPreferenceStore.isEnabled($0) }
            },
            set: { value in
                preferenceGroups.forEach { NotificationPreferenceStore.set(value, for: $0) }
                notificationPreferenceRevision += 1
            }
        )
    }

    private func notificationPreferenceBinding(for group: NotificationPreferenceGroup) -> Binding<Bool> {
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

    private var routineNotificationsToggleRow: some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: "bell.badge.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "常规提醒", en: "Routine reminders", de: "Reguläre Erinnerungen"))
                    .font(OhanaFont.body(.semibold))
                Text(routineNotificationSummary)
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Spacer()
            Toggle("", isOn: routineNotificationsBinding)
                .labelsHidden()
                .tint(Color.goPrimary)
        }
        .accessibilityIdentifier("settings-routine-notifications-toggle")
    }

    private var medicationPrivacyRow: some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: "eye.slash.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "隐藏用药通知细节", en: "Hide medication details", de: "Medikamentendetails ausblenden"))
                    .font(OhanaFont.body(.semibold))
                Text(l.tr(zh: "锁屏只显示通用提醒", en: "Lock screen shows a generic reminder", de: "Sperrbildschirm zeigt nur eine allgemeine Erinnerung"))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Spacer()
            Toggle("", isOn: $hidePetMedicationNotificationDetails)
                .labelsHidden()
                .tint(Color.goPrimary)
        }
    }

    private var advancedNotificationSettingsRows: some View {
        VStack(spacing: 0) {
            notificationToggleRow(
                icon: "pills.fill",
                title: l.tr(zh: "用药提醒", en: "Medication reminders", de: "Medikamentenerinnerungen"),
                group: .medication
            )
            notificationToggleRow(
                icon: "calendar.badge.clock",
                title: l.tr(zh: "日历事项提醒", en: "Calendar event reminders", de: "Kalendererinnerungen"),
                group: .calendar
            )
            notificationToggleRow(
                icon: "fork.knife",
                title: l.tr(zh: "喂食提醒", en: "Feeding reminders", de: "Fütterungserinnerungen"),
                group: .feeding
            )
            notificationToggleRow(
                icon: "bubbles.and.sparkles.fill",
                title: l.tr(zh: "护理提醒", en: "Care reminders", de: "Pflegeerinnerungen"),
                group: .hygiene
            )
            SettingsPlantReminderDataContainer()
            notificationToggleRow(
                icon: "checkmark.seal.fill",
                title: l.tr(zh: "打卡提醒", en: "Check-in reminders", de: "Check-in-Erinnerungen"),
                group: .checkIn
            )
        }
    }

    private func notificationToggleRow(icon: String, title: String, group: NotificationPreferenceGroup) -> some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: icon)
            Text(title)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Toggle("", isOn: notificationPreferenceBinding(for: group))
                .labelsHidden()
                .tint(Color.goPrimary)
                .accessibilityLabel(title)
                .accessibilityIdentifier("settings-notification-\(group.rawValue)-toggle")
        }
        .frame(minHeight: 44)
    }
}

private extension View {
    func settingsNotificationsChrome(title: String, closeLabel: String, onClose: @escaping () -> Void) -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(OhanaStaticAppBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .cancel, action: onClose) {
                        Label(closeLabel, systemImage: "xmark")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(closeLabel)
                    .accessibilityIdentifier("settings-close-action")
                }
            }
            .accessibilityIdentifier("settings-notifications-screen")
    }
}
