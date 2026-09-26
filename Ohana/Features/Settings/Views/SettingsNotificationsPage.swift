import SwiftData
import SwiftUI
import UIKit

struct SettingsNotificationsPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(MedicationNotificationPrivacyStore.hideDetailsKey) private var hideMedicationNotificationDetails = false
    @State private var showAdvancedNotificationSettings = false
    @State private var notificationPreferenceRevision = 0
    @State private var isMedicationPrivacyRefreshPending = false
    @State private var medicationPrivacyRefreshError: String?

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
                            subtitle: presenceSafetySubtitle
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

    private var presenceSafetySubtitle: String {
        if OnlineFeatureGate.allows(.guardianSafety) {
            return l.tr(
                zh: "本机提醒与 App 内亲友守护",
                en: "On-device reminders and in-app guardians",
                de: "Lokale Erinnerungen und App-Schutzkreis",
                es: "Recordatorios y guardianes en la app",
                pt: "Lembretes e proteção dentro do app",
                fr: "Rappels et proches dans l’app",
                ja: "デバイス内通知とApp内の見守り",
                ko: "기기 내 알림과 앱 내 보호자",
                it: "Promemoria e protezione nell’app"
            )
        }
        return l.tr(
            zh: "本机提醒与平安确认动作",
            en: "On-device reminders and check-in actions",
            de: "Lokale Erinnerungen und Bestätigungsaktionen",
            es: "Recordatorios y confirmaciones en el dispositivo",
            pt: "Lembretes e confirmações no aparelho",
            fr: "Rappels et confirmations sur l’appareil",
            ja: "デバイス内通知と確認操作",
            ko: "기기 내 알림과 확인 동작",
            it: "Promemoria e conferme sul dispositivo"
        )
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                SettingsDestinationIcon(systemName: "eye.slash.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "隐藏用药通知细节", en: "Hide medication details", de: "Medikamentendetails ausblenden"))
                        .font(OhanaFont.body(.semibold))
                    Text(l.tr(zh: "所有成员的锁屏通知只显示通用提醒", en: "Lock screen notifications for everyone show only a generic reminder", de: "Sperrbildschirm-Mitteilungen zeigen für alle nur einen allgemeinen Hinweis"))
                        .font(OhanaFont.footnote())
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
                Spacer()
                Toggle("", isOn: medicationPrivacyBinding)
                    .labelsHidden()
                    .tint(Color.goPrimary)
                    .disabled(isMedicationPrivacyRefreshPending)
                    .accessibilityLabel(l.tr(
                        zh: "隐藏所有用药通知细节",
                        en: "Hide all medication notification details",
                        de: "Alle Medikamentendetails in Mitteilungen ausblenden"
                    ))
                    .accessibilityIdentifier("settings-medication-notification-privacy-toggle")
            }

            if isMedicationPrivacyRefreshPending {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(l.tr(
                        zh: "正在安全刷新用药提醒…",
                        en: "Safely refreshing medication reminders…",
                        de: "Medikamentenerinnerungen werden sicher aktualisiert…"
                    ))
                }
                .font(OhanaFont.footnote())
                .foregroundStyle(Color.ohanaTertiaryText)
                .accessibilityIdentifier("settings-medication-notification-privacy-progress")
            }

            if let medicationPrivacyRefreshError {
                Label(medicationPrivacyRefreshError, systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.red)
                    .accessibilityIdentifier("settings-medication-notification-privacy-error")
            }
        }
    }

    private var medicationPrivacyBinding: Binding<Bool> {
        Binding(
            get: { hideMedicationNotificationDetails },
            set: { newValue in
                guard newValue != hideMedicationNotificationDetails,
                      !isMedicationPrivacyRefreshPending else { return }

                // Supersede any background plan built with the old privacy
                // state before the persisted preference changes.
                appServices.medicationReminders.invalidateNotificationMutations()
                // Commit the finger-visible state first. Notification replacement
                // starts on the next cooperative turn.
                hideMedicationNotificationDetails = newValue
                medicationPrivacyRefreshError = nil
                isMedicationPrivacyRefreshPending = true
                Task { @MainActor in
                    await Task.yield()
                    let result = await appServices.medicationReminders.refreshScheduledMedicationReminders(
                        context: modelContext,
                        hidingDetails: newValue
                    )
                    isMedicationPrivacyRefreshPending = false
                    guard !result.didSucceed else { return }

                    let message = medicationPrivacyRefreshFailureMessage(hidingDetails: newValue)
                    medicationPrivacyRefreshError = message
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
            }
        )
    }

    private func medicationPrivacyRefreshFailureMessage(hidingDetails: Bool) -> String {
        if hidingDetails {
            return l.tr(
                zh: "隐私设置已保存，但用药提醒无法安全刷新。旧提醒已移除，请稍后切换此设置重试。",
                en: "The privacy setting was saved, but medication reminders could not be safely refreshed. Existing reminders were removed; toggle this setting later to retry.",
                de: "Die Datenschutzeinstellung wurde gespeichert, aber die Medikamentenerinnerungen konnten nicht sicher aktualisiert werden. Vorhandene Erinnerungen wurden entfernt. Schalte diese Einstellung später erneut um.",
                es: "Se guardó el ajuste de privacidad, pero no se pudieron actualizar los recordatorios de medicación de forma segura. Se eliminaron los recordatorios existentes; vuelve a cambiar este ajuste más tarde.",
                pt: "A definição de privacidade foi guardada, mas não foi possível atualizar os lembretes de medicação em segurança. Os lembretes existentes foram removidos; altere esta definição novamente mais tarde.",
                fr: "Le réglage de confidentialité a été enregistré, mais les rappels de médicaments n’ont pas pu être actualisés en toute sécurité. Les rappels existants ont été supprimés ; réessayez plus tard avec ce réglage.",
                ja: "プライバシー設定は保存されましたが、服薬リマインダーを安全に更新できませんでした。既存のリマインダーは削除されました。後でもう一度この設定を切り替えてください。",
                ko: "개인정보 설정은 저장되었지만 복약 알림을 안전하게 새로 고치지 못했습니다. 기존 알림은 삭제되었습니다. 나중에 이 설정을 다시 전환해 주세요.",
                it: "L’impostazione della privacy è stata salvata, ma non è stato possibile aggiornare in sicurezza i promemoria dei farmaci. I promemoria esistenti sono stati rimossi; riprova più tardi modificando questa impostazione."
            )
        }
        return l.tr(
            zh: "部分用药提醒无法刷新，请稍后再次切换此设置重试。",
            en: "Some medication reminders could not be refreshed. Toggle this setting again later to retry.",
            de: "Einige Medikamentenerinnerungen konnten nicht aktualisiert werden. Schalte diese Einstellung später erneut um.",
            es: "No se pudieron actualizar algunos recordatorios de medicación. Vuelve a cambiar este ajuste más tarde.",
            pt: "Não foi possível atualizar alguns lembretes de medicação. Altere esta definição novamente mais tarde.",
            fr: "Certains rappels de médicaments n’ont pas pu être actualisés. Réessayez plus tard avec ce réglage.",
            ja: "一部の服薬リマインダーを更新できませんでした。後でもう一度この設定を切り替えてください。",
            ko: "일부 복약 알림을 새로 고치지 못했습니다. 나중에 이 설정을 다시 전환해 주세요.",
            it: "Non è stato possibile aggiornare alcuni promemoria dei farmaci. Riprova più tardi modificando questa impostazione."
        )
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
