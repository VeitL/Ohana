import SwiftData
import SwiftUI
import UIKit

struct SettingsNotificationsPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(MedicationNotificationPrivacyStore.hideDetailsKey) private var hideMedicationNotificationDetails = false
    @AppStorage("notif_medication_enabled") private var medicationRemindersEnabled = true
    @AppStorage("notif_calendar_enabled") private var calendarRemindersEnabled = true
    @AppStorage("notif_feeding_enabled") private var feedingRemindersEnabled = true
    @AppStorage("notif_hygiene_enabled") private var hygieneRemindersEnabled = true
    @AppStorage("notif_plant_care_enabled") private var plantRemindersEnabled = true
    @AppStorage("notif_checkin_enabled") private var checkInRemindersEnabled = true
    @State private var isMedicationPrivacyRefreshPending = false
    @State private var medicationPrivacyRefreshError: String?

    let experienceMode: AppExperienceMode
    let onClose: () -> Void

    private var l: L10n { L10n(appLanguage) }
    private var preferenceGroups: [NotificationPreferenceGroup] { NotificationPreferenceGroup.allCases }

    var body: some View {
        Form {
            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    SettingsNavigationLabel(icon: "bell.badge", title: l.notificationPermission, subtitle: l.manageNotification)
                }
                .accessibilityIdentifier("settings-notification-system-permission")
            } header: {
                Text(l.tr(zh: "系统权限", en: "System permission", de: "Systemberechtigung", es: "Permiso del sistema",
                          pt: "Permissão do sistema", fr: "Autorisation système", ja: "システム権限", ko: "시스템 권한", it: "Autorizzazione di sistema"))
            } footer: {
                Text(l.tr(zh: "系统通知权限在 iOS 设置中管理；下方可分别选择提醒类别。", en: "Manage notification permission in iOS Settings. Choose reminder categories below.",
                          de: "Verwalte die Mitteilungsberechtigung in den iOS-Einstellungen. Wähle unten die Erinnerungskategorien.",
                          es: "Gestiona el permiso de notificaciones en los ajustes de iOS. Elige las categorías de recordatorios a continuación.",
                          pt: "Gerencie a permissão de notificações nos Ajustes do iOS. Escolha as categorias de lembretes abaixo.",
                          fr: "Gérez l’autorisation des notifications dans les réglages iOS. Choisissez les catégories de rappels ci-dessous.",
                          ja: "通知の許可はiOSの設定で管理します。以下でリマインダーの種類を選べます。", ko: "알림 권한은 iOS 설정에서 관리합니다. 아래에서 알림 종류를 선택하세요.",
                          it: "Gestisci l’autorizzazione delle notifiche nelle impostazioni iOS. Scegli le categorie di promemoria qui sotto."))
            }

            Section {
                allCategoriesActions
                notificationCategoryRows
            } header: {
                Text(l.tr(zh: "提醒类别", en: "Reminder categories", de: "Erinnerungskategorien", es: "Categorías de recordatorios",
                          pt: "Categorias de lembretes", fr: "Catégories de rappels", ja: "リマインダーの種類", ko: "알림 종류", it: "Categorie di promemoria"))
            }

            Section {
                NavigationLink {
                    plantReminderSettingsPage
                } label: {
                    SettingsNavigationLabel(
                        icon: "leaf.fill",
                        title: plantReminderSettingsTitle,
                        subtitle: l.tr(zh: "时段、养护类型和单株设置", en: "Time window, care types and individual plants", de: "Zeitfenster, Pflegearten und einzelne Pflanzen",
                                       es: "Horario, tipos de cuidado y plantas individuales", pt: "Horário, tipos de cuidado e plantas individuais",
                                       fr: "Plage horaire, types de soins et plantes individuelles", ja: "時間帯・お手入れの種類・植物ごとの設定", ko: "시간대, 관리 종류 및 개별 식물", it: "Orari, tipi di cura e singole piante")
                    )
                }
                .accessibilityIdentifier("settings-plant-reminders-details")
            }

            if experienceMode == .zen {
                Section {
                    presenceSafetyRow
                }
            }

            Section {
                medicationPrivacyRow
            } header: {
                Text(l.tr(zh: "锁屏隐私", en: "Lock screen privacy", de: "Sperrbildschirm-Privatsphäre", es: "Privacidad de la pantalla de bloqueo",
                          pt: "Privacidade na tela bloqueada", fr: "Confidentialité de l’écran verrouillé", ja: "ロック画面のプライバシー", ko: "잠금 화면 개인정보", it: "Privacy della schermata di blocco"))
            }
        }
        .settingsNotificationsChrome(
            title: SettingsDestination.notifications.title(l),
            closeLabel: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
            onClose: onClose
        )
    }

    private var presenceSafetyRow: some View {
        NavigationLink {
            PresenceSafetySettingsView()

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

    private var plantReminderSettingsTitle: String {
        l.tr(zh: "植物详细设置", en: "Plant reminder settings", de: "Pflanzenerinnerungen", es: "Ajustes de recordatorios de plantas",
             pt: "Ajustes de lembretes de plantas", fr: "Réglages des rappels de plantes", ja: "植物リマインダーの設定", ko: "식물 알림 설정", it: "Impostazioni dei promemoria per le piante")
    }

    private var plantReminderSettingsPage: some View {
        Form {
            Section {
                SettingsPlantReminderDataContainer()
            }
        }
        .settingsNotificationsChrome(
            title: plantReminderSettingsTitle,
            closeLabel: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
            screenIdentifier: "settings-plant-reminders-screen",
            onClose: onClose
        )
    }

    private var routineNotificationSummary: String {
        let enabledCount = preferenceGroups.count { notificationPreferenceBinding(for: $0).wrappedValue }
        if enabledCount == preferenceGroups.count {
            return l.tr(zh: "全部开启", en: "All on", de: "Alle an", es: "Todas activadas", pt: "Todas ativadas", fr: "Toutes activées", ja: "すべてオン", ko: "모두 켜짐", it: "Tutte attive")
        }
        if enabledCount == 0 {
            return l.tr(zh: "全部关闭", en: "All off", de: "Alle aus", es: "Todas desactivadas", pt: "Todas desativadas", fr: "Toutes désactivées", ja: "すべてオフ", ko: "모두 꺼짐", it: "Tutte disattivate")
        }
        return l.tr(zh: "\(enabledCount)/\(preferenceGroups.count) 已开启", en: "\(enabledCount)/\(preferenceGroups.count) on", de: "\(enabledCount)/\(preferenceGroups.count) an", es: "\(enabledCount)/\(preferenceGroups.count) activadas", pt: "\(enabledCount)/\(preferenceGroups.count) ativadas", fr: "\(enabledCount)/\(preferenceGroups.count) activées", ja: "\(enabledCount)/\(preferenceGroups.count) オン", ko: "\(enabledCount)/\(preferenceGroups.count) 켜짐", it: "\(enabledCount)/\(preferenceGroups.count) attive")
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

    private func notificationPreferenceBinding(for group: NotificationPreferenceGroup) -> Binding<Bool> {
        let binding: Binding<Bool> = switch group {
        case .medication: $medicationRemindersEnabled
        case .calendar: $calendarRemindersEnabled
        case .feeding: $feedingRemindersEnabled
        case .hygiene: $hygieneRemindersEnabled
        case .plantCare: $plantRemindersEnabled
        case .checkIn: $checkInRemindersEnabled
        }
        #if DEBUG
        return OhanaUITestTouchTrace.observingToggle(binding, identifier: "notification-category-\(group.rawValue)")
        #else
        return binding
        #endif
    }

    private var allCategoriesActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(routineNotificationSummary)
                .font(OhanaFont.footnote())
                .foregroundStyle(Color.ohanaSecondaryText)
                .accessibilityIdentifier("settings-notification-category-summary")

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Button {
                    setAllCategoriesEnabled(true)
                } label: {
                    Label(l.tr(zh: "全部开启", en: "Turn all on", de: "Alle einschalten", es: "Activar todas", pt: "Ativar todas",
                               fr: "Tout activer", ja: "すべてオンにする", ko: "모두 켜기", it: "Attiva tutte"), systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("settings-notification-enable-all")
                Button {
                    setAllCategoriesEnabled(false)
                } label: {
                    Label(l.tr(zh: "全部关闭", en: "Turn all off", de: "Alle ausschalten", es: "Desactivar todas", pt: "Desativar todas",
                               fr: "Tout désactiver", ja: "すべてオフにする", ko: "모두 끄기", it: "Disattiva tutte"), systemImage: "bell.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("settings-notification-disable-all")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func setAllCategoriesEnabled(_ enabled: Bool) {
        for group in preferenceGroups {
            notificationPreferenceBinding(for: group).wrappedValue = enabled
        }
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

    private var notificationCategoryRows: some View {
        Group {
            notificationToggleRow(
                icon: "pills.fill",
                title: l.tr(zh: "用药提醒", en: "Medication reminders", de: "Medikamentenerinnerungen", es: "Recordatorios de medicación", pt: "Lembretes de medicação",
                            fr: "Rappels de médicaments", ja: "服薬リマインダー", ko: "복약 알림", it: "Promemoria dei farmaci"),
                group: .medication
            )
            notificationToggleRow(
                icon: "calendar.badge.clock",
                title: l.tr(zh: "日历事项提醒", en: "Calendar event reminders", de: "Kalendererinnerungen", es: "Recordatorios del calendario", pt: "Lembretes do calendário",
                            fr: "Rappels du calendrier", ja: "カレンダーのリマインダー", ko: "일정 알림", it: "Promemoria del calendario"),
                group: .calendar
            )
            notificationToggleRow(
                icon: "fork.knife",
                title: l.tr(zh: "喂食提醒", en: "Feeding reminders", de: "Fütterungserinnerungen", es: "Recordatorios de alimentación", pt: "Lembretes de alimentação",
                            fr: "Rappels de repas", ja: "ごはんのリマインダー", ko: "급식 알림", it: "Promemoria dei pasti"),
                group: .feeding
            )
            notificationToggleRow(
                icon: "bubbles.and.sparkles.fill",
                title: l.tr(zh: "护理提醒", en: "Care reminders", de: "Pflegeerinnerungen", es: "Recordatorios de cuidados", pt: "Lembretes de cuidados",
                            fr: "Rappels de soins", ja: "お手入れのリマインダー", ko: "관리 알림", it: "Promemoria di cura"),
                group: .hygiene
            )
            notificationToggleRow(
                icon: "leaf.fill",
                title: l.tr(zh: "植物养护提醒", en: "Plant care reminders", de: "Pflanzenpflege-Erinnerungen", es: "Recordatorios de cuidado de plantas", pt: "Lembretes de cuidados com plantas",
                            fr: "Rappels de soins des plantes", ja: "植物のお手入れリマインダー", ko: "식물 관리 알림", it: "Promemoria di cura delle piante"),
                group: .plantCare
            )
            notificationToggleRow(
                icon: "checkmark.seal.fill",
                title: l.tr(zh: "打卡与周报", en: "Check-ins & weekly report", de: "Check-ins und Wochenbericht", es: "Registros e informe semanal", pt: "Check-ins e relatório semanal",
                            fr: "Pointages et rapport hebdomadaire", ja: "チェックインと週間レポート", ko: "체크인 및 주간 보고서", it: "Check-in e resoconto settimanale"),
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
    func settingsNotificationsChrome(title: String, closeLabel: String, screenIdentifier: String = "settings-notifications-screen", onClose: @escaping () -> Void) -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(OhanaStaticAppBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)

            .accessibilityIdentifier(screenIdentifier)
    }
}
