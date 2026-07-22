//
//  PresenceSafetySettingsView.swift
//  Ohana
//

import SwiftData
import SwiftUI

@MainActor
struct PresenceSafetySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var configuration = PresenceReminderConfiguration.initial
    @State private var originalConfiguration = PresenceReminderConfiguration.initial
    @State private var contacts: [SafetyContactSnapshot] = []
    @State private var usesWeekdaySchedules = false
    @State private var notice: PresenceSafetySettingsNotice?
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var isShowingLegacyCleanupConfirmation = false

    private let configurationStore = PresenceReminderConfigurationStore()
    private let scheduler = SystemPresenceReminderScheduler()

    private var capabilities: OhanaPlanCapabilities {
        appServices.commerce.ohanaPlanCapabilities
    }

    private var copy: PresenceSafetySettingsCopy {
        PresenceSafetySettingsCopy(languageCode: appLanguage)
    }

    private var hasGrandfatheredAdvancedConfiguration: Bool {
        !capabilities.plan.hasPersonal && Self.requiresPersonal(originalConfiguration)
    }

    private var weekdayOrder: [PresenceReminderWeekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    var body: some View {
        Form {
            reminderSection
            guardianSection
            if !contacts.isEmpty {
                legacyContactsSection
            }
        }
        .formStyle(.grouped)
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(OhanaStaticAppBackground())
        .navigationTitle(copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(copy.save) {
                    saveReminderConfiguration()
                }
                .disabled(isSaving)
                .accessibilityIdentifier("presence-safety-save")
            }
        }
        .task {
            loadIfNeeded()
        }
        .confirmationDialog(
            copy.text(
                zh: "清除旧联系人？",
                en: "Clear legacy contacts?",
                de: "Alte Kontakte löschen?",
                es: "¿Borrar contactos anteriores?",
                pt: "Limpar contatos antigos?",
                fr: "Effacer les anciens contacts ?",
                ja: "以前の連絡先を削除しますか？",
                ko: "이전 연락처를 지울까요?",
                it: "Eliminare i vecchi contatti?"
            ),
            isPresented: $isShowingLegacyCleanupConfirmation,
            titleVisibility: .visible
        ) {
            Button(copy.delete, role: .destructive) {
                clearLegacyContacts()
            }
            Button(copy.cancel, role: .cancel) {}
        } message: {
            Text(copy.text(
                zh: "这会永久删除仅保存在本机的旧姓名和电话号码。不会影响 App 内守护关系。",
                en: "This permanently removes legacy names and phone numbers stored only on this device. App guardian relationships are unaffected.",
                de: "Dabei werden nur auf diesem Gerät gespeicherte alte Namen und Telefonnummern dauerhaft gelöscht. App-Schutzbeziehungen bleiben erhalten.",
                es: "Esto elimina de forma permanente los nombres y teléfonos antiguos guardados solo en este dispositivo. No afecta a los guardianes de la app.",
                pt: "Isso remove permanentemente nomes e telefones antigos salvos apenas neste aparelho. As relações de proteção no app não mudam.",
                fr: "Cette action supprime définitivement les anciens noms et numéros stockés uniquement sur cet appareil. Les relations de garde dans l’app restent intactes.",
                ja: "このデバイスだけに保存された以前の名前と電話番号を完全に削除します。App内の見守り関係には影響しません。",
                ko: "이 기기에만 저장된 이전 이름과 전화번호를 영구 삭제합니다. 앱 내 보호 관계에는 영향이 없습니다.",
                it: "Rimuove definitivamente nomi e numeri precedenti salvati solo su questo dispositivo. Le relazioni di protezione nell’app non cambiano."
            ))
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(copy.text(
                    zh: "好",
                    en: "OK",
                    de: "OK",
                    es: "Aceptar",
                    pt: "OK",
                    fr: "OK",
                    ja: "OK",
                    ko: "확인",
                    it: "OK"
                )))
            )
        }
        .accessibilityIdentifier("presence-safety-settings")
    }

    private var reminderSection: some View {
        Section {
            Toggle(copy.enableReminder, isOn: $configuration.isEnabled)
                .tint(Color.goPrimary)
                .accessibilityIdentifier("presence-reminder-enabled")

            if hasGrandfatheredAdvancedConfiguration {
                Text(copy.downgradePreservedHint)
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if capabilities.reminders.allowsWeekdaySchedules {
                    Toggle(copy.byWeekday, isOn: weekdayScheduleBinding)
                        .tint(Color.goPrimary)
                }

                if usesWeekdaySchedules, capabilities.reminders.allowsWeekdaySchedules {
                    ForEach(weekdayOrder, id: \.self) { weekday in
                        weekdayScheduleRow(weekday)
                    }
                } else {
                    DatePicker(
                        copy.reminderTime,
                        selection: dailyTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                if capabilities.reminders.allowsSecondLocalReminder {
                    Toggle(copy.secondReminder, isOn: secondReminderBinding)
                        .tint(Color.goPrimary)
                    if configuration.sendsSecondLocalReminder {
                        Stepper(
                            copy.gracePeriod(minutes: configuration.gracePeriodMinutes ?? 30),
                            value: gracePeriodBinding,
                            in: PresenceReminderCapabilities.gracePeriodMinutes,
                            step: 15
                        )
                    }
                } else {
                    Text(copy.personalReminderHint)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            Text(copy.reminderSection)
        } footer: {
            Text(reminderFooter)
        }
    }

    private var guardianSection: some View {
        Section {
            NavigationLink {
                GuardianSafetyDashboardView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copy.text(
                            zh: "App 内亲友守护",
                            en: "In-app guardian circle",
                            de: "Schutzkreis in der App",
                            es: "Círculo de guardianes en la app",
                            pt: "Círculo de proteção no app",
                            fr: "Cercle de proches dans l’app",
                            ja: "App内の見守りサークル",
                            ko: "앱 내 보호자 모임",
                            it: "Cerchia di protezione nell’app"
                        ))
                        Text(guardianSummary)
                            .font(OhanaFont.footnote())
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "person.2.badge.shield.checkmark.fill").accessibilityHidden(true)
                        .foregroundStyle(Color.goPrimary)
                }
            }
            .accessibilityIdentifier("guardian-safety-entry")
        } header: {
            Text(copy.text(
                zh: "Ohana Family",
                en: "Ohana Family",
                de: "Ohana Family",
                es: "Ohana Family",
                pt: "Ohana Family",
                fr: "Ohana Family",
                ja: "Ohana Family",
                ko: "Ohana Family",
                it: "Ohana Family"
            ))
        } footer: {
            Text(copy.text(
                zh: "只有安装 Ohana、使用 Apple 登录、接受邀请并允许通知的人才能收到守护推送。不使用短信、电话或邮箱。",
                en: "Only people who install Ohana, sign in with Apple, accept the invitation, and allow notifications can receive guardian alerts. No text messages, phone calls, or email are used.",
                de: "Nur Personen, die Ohana installieren, sich mit Apple anmelden, die Einladung annehmen und Mitteilungen erlauben, können Schutzmeldungen erhalten. Keine SMS, Anrufe oder E-Mails.",
                es: "Solo quienes instalen Ohana, inicien sesión con Apple, acepten la invitación y permitan notificaciones pueden recibir avisos. No se usan SMS, llamadas ni correo.",
                pt: "Só quem instalar o Ohana, iniciar sessão com a Apple, aceitar o convite e permitir notificações poderá receber avisos. Não usamos SMS, chamadas ou e-mail.",
                fr: "Seules les personnes ayant installé Ohana, utilisé Connexion avec Apple, accepté l’invitation et autorisé les notifications peuvent recevoir les alertes. Aucun SMS, appel ou e-mail.",
                ja: "Ohanaをインストールし、Appleでサインインして招待を承認し、通知を許可した人だけが見守り通知を受け取れます。SMS・電話・メールは使いません。",
                ko: "Ohana를 설치하고 Apple로 로그인한 뒤 초대를 수락하고 알림을 허용한 사람만 보호 알림을 받을 수 있습니다. 문자, 전화, 이메일은 사용하지 않습니다.",
                it: "Solo chi installa Ohana, accede con Apple, accetta l’invito e consente le notifiche può ricevere avvisi. Non vengono usati SMS, chiamate o email."
            ))
        }
    }

    private var legacyContactsSection: some View {
        Section {
            LabeledContent(
                copy.text(
                    zh: "仅存于本机",
                    en: "Stored on this device",
                    de: "Auf diesem Gerät gespeichert",
                    es: "Guardados en este dispositivo",
                    pt: "Salvos neste aparelho",
                    fr: "Stockés sur cet appareil",
                    ja: "このデバイス内に保存",
                    ko: "이 기기에 저장됨",
                    it: "Salvati su questo dispositivo"
                ),
                value: "\(contacts.count)"
            )
            Button(role: .destructive) {
                isShowingLegacyCleanupConfirmation = true
            } label: {
                Label(
                    copy.text(
                        zh: "清除旧联系人数据",
                        en: "Clear legacy contact data",
                        de: "Alte Kontaktdaten löschen",
                        es: "Borrar datos de contactos anteriores",
                        pt: "Limpar dados de contatos antigos",
                        fr: "Effacer les anciennes coordonnées",
                        ja: "以前の連絡先データを削除",
                        ko: "이전 연락처 데이터 지우기",
                        it: "Elimina i vecchi dati di contatto"
                    ),
                    systemImage: "trash"
                )
            }
            .accessibilityIdentifier("presence-legacy-contacts-clear")
        } header: {
            Text(copy.text(
                zh: "旧版联系人",
                en: "Legacy contacts",
                de: "Alte Kontakte",
                es: "Contactos anteriores",
                pt: "Contatos antigos",
                fr: "Anciens contacts",
                ja: "以前の連絡先",
                ko: "이전 연락처",
                it: "Vecchi contatti"
            ))
        } footer: {
            Text(copy.text(
                zh: "旧版号码不会上传，也不再用于发送消息。",
                en: "Legacy numbers are never uploaded and are no longer used to send messages.",
                de: "Alte Nummern werden nie hochgeladen und nicht mehr zum Senden von Nachrichten verwendet.",
                es: "Los números anteriores nunca se suben ni se usan para enviar mensajes.",
                pt: "Os números antigos nunca são enviados e não são mais usados para mensagens.",
                fr: "Les anciens numéros ne sont jamais téléversés et ne servent plus à envoyer des messages.",
                ja: "以前の電話番号はアップロードされず、メッセージ送信にも使われません。",
                ko: "이전 번호는 업로드되지 않으며 메시지 전송에도 더 이상 사용되지 않습니다.",
                it: "I vecchi numeri non vengono mai caricati e non sono più usati per inviare messaggi."
            ))
        }
    }

    private var guardianSummary: String {
        switch appServices.guardianSafety.dashboardState {
        case .unavailable:
            copy.text(
                zh: "云端服务尚未通过上线门禁，本机提醒不受影响",
                en: "Cloud service is still behind its release gate; local reminders are unaffected",
                de: "Der Clouddienst ist noch durch die Freigabe gesperrt; lokale Erinnerungen bleiben verfügbar",
                es: "El servicio en la nube sigue bloqueado hasta su lanzamiento; los recordatorios locales no cambian",
                pt: "O serviço em nuvem ainda está bloqueado para lançamento; lembretes locais não mudam",
                fr: "Le service cloud reste bloqué jusqu’à sa validation ; les rappels locaux restent disponibles",
                ja: "クラウド機能は公開前のため停止中です。デバイス内通知には影響しません",
                ko: "클라우드 서비스는 출시 검증 전까지 닫혀 있으며 기기 내 알림에는 영향이 없습니다",
                it: "Il servizio cloud resta dietro il gate di rilascio; i promemoria locali non cambiano"
            )
        case .signedOut:
            copy.text(
                zh: "登录后邀请最多 3 位已安装 App 的守护人",
                en: "Sign in to invite up to three guardians who use the app",
                de: "Anmelden und bis zu drei App-Nutzer als Vertrauenspersonen einladen",
                es: "Inicia sesión para invitar hasta tres guardianes que usen la app",
                pt: "Entre para convidar até três pessoas que usam o app",
                fr: "Connectez-vous pour inviter jusqu’à trois proches utilisant l’app",
                ja: "サインインしてApp利用者を最大3人まで招待できます",
                ko: "로그인하고 앱 사용자 보호자를 최대 3명 초대하세요",
                it: "Accedi per invitare fino a tre persone che usano l’app"
            )
        case .loading:
            copy.text(
                zh: "正在同步守护状态…",
                en: "Syncing guardian status…",
                de: "Schutzstatus wird synchronisiert…",
                es: "Sincronizando el estado…",
                pt: "Sincronizando o estado…",
                fr: "Synchronisation de l’état…",
                ja: "見守り状態を同期中…",
                ko: "보호 상태 동기화 중…",
                it: "Sincronizzazione dello stato…"
            )
        case .loaded:
            copy.text(
                zh: "查看守护人、邀请、暂停与漏签事件",
                en: "View guardians, invitations, pauses, and missed check-in incidents",
                de: "Vertrauenspersonen, Einladungen, Pausen und Ereignisse ansehen",
                es: "Consulta guardianes, invitaciones, pausas e incidencias",
                pt: "Veja pessoas, convites, pausas e ocorrências",
                fr: "Voir les proches, invitations, pauses et incidents",
                ja: "見守り相手・招待・一時停止・未着イベントを確認",
                ko: "보호자, 초대, 일시 중지, 미수신 사건 보기",
                it: "Visualizza persone, inviti, pause ed eventi"
            )
        case .failed:
            copy.text(
                zh: "守护服务需要处理",
                en: "Guardian service needs attention",
                de: "Schutzdienst benötigt Aufmerksamkeit",
                es: "El servicio requiere atención",
                pt: "O serviço precisa de atenção",
                fr: "Le service nécessite votre attention",
                ja: "見守りサービスを確認してください",
                ko: "보호 서비스를 확인해 주세요",
                it: "Il servizio richiede attenzione"
            )
        }
    }

    private func weekdayScheduleRow(_ weekday: PresenceReminderWeekday) -> some View {
        HStack(spacing: 12) {
            Toggle(copy.weekday(weekday), isOn: weekdayEnabledBinding(weekday))
                .tint(Color.goPrimary)
            if schedule(for: weekday) != nil {
                DatePicker(
                    copy.reminderTime,
                    selection: weekdayTimeBinding(weekday),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .accessibilityLabel("\(copy.weekday(weekday)) · \(copy.reminderTime)")
            }
        }
    }

    private var reminderFooter: String {
        copy.text(
            zh: "只有你明确保存并启用时，Ohana 才会请求通知权限。通知中的“我没事”会完成本人当天打卡。",
            en: "Ohana asks for notification permission only when you explicitly save an enabled reminder. “I’m okay” in the notification checks in the owner for today.",
            de: "Ohana fragt nur nach der Mitteilungsberechtigung, wenn du eine aktivierte Erinnerung ausdrücklich speicherst. „Mir geht’s gut“ checkt die eigene Person für heute ein.",
            es: "Ohana solo pide permiso al guardar explícitamente un recordatorio activo. “Estoy bien” registra hoy a la persona propietaria.",
            pt: "O Ohana só pede permissão ao salvar explicitamente um lembrete ativo. “Estou bem” registra hoje a pessoa proprietária.",
            fr: "Ohana ne demande l’autorisation qu’après l’enregistrement explicite d’un rappel actif. « Je vais bien » valide le pointage du propriétaire pour aujourd’hui.",
            ja: "有効な通知を明示的に保存したときだけ通知許可を求めます。通知の「大丈夫」で本人の今日のチェックインが完了します。",
            ko: "활성화된 알림을 직접 저장할 때만 알림 권한을 요청합니다. 알림의 ‘괜찮아요’를 누르면 본인이 오늘 체크인됩니다.",
            it: "Ohana chiede il permesso solo quando salvi esplicitamente un promemoria attivo. “Sto bene” nella notifica registra il check-in odierno del titolare."
        )
    }

    private var weekdayScheduleBinding: Binding<Bool> {
        Binding(
            get: { usesWeekdaySchedules },
            set: { isEnabled in
                usesWeekdaySchedules = isEnabled
                if isEnabled {
                    let base = configuration.schedules.first ?? .suggestedDailyDeadline
                    configuration.schedules = weekdayOrder.map {
                        PresenceReminderSchedule(weekday: $0, hour: base.hour, minute: base.minute)
                    }
                } else {
                    let base = configuration.schedules.first ?? .suggestedDailyDeadline
                    configuration.schedules = [PresenceReminderSchedule(hour: base.hour, minute: base.minute)]
                }
            }
        )
    }

    private var dailyTimeBinding: Binding<Date> {
        Binding(
            get: {
                date(for: configuration.schedules.first ?? .suggestedDailyDeadline)
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                configuration.schedules = [PresenceReminderSchedule(
                    hour: components.hour ?? 20,
                    minute: components.minute ?? 0
                )]
            }
        )
    }

    private var secondReminderBinding: Binding<Bool> {
        Binding(
            get: { configuration.sendsSecondLocalReminder },
            set: { isEnabled in
                configuration.sendsSecondLocalReminder = isEnabled
                configuration.gracePeriodMinutes = isEnabled
                    ? min(max(configuration.gracePeriodMinutes ?? 30, 15), 180)
                    : nil
            }
        )
    }

    private var gracePeriodBinding: Binding<Int> {
        Binding(
            get: { configuration.gracePeriodMinutes ?? 30 },
            set: { configuration.gracePeriodMinutes = min(max($0, 15), 180) }
        )
    }

    private func weekdayEnabledBinding(_ weekday: PresenceReminderWeekday) -> Binding<Bool> {
        Binding(
            get: { schedule(for: weekday) != nil },
            set: { isEnabled in
                if isEnabled, schedule(for: weekday) == nil {
                    let base = configuration.schedules.first ?? .suggestedDailyDeadline
                    configuration.schedules.append(PresenceReminderSchedule(
                        weekday: weekday,
                        hour: base.hour,
                        minute: base.minute
                    ))
                } else if !isEnabled {
                    configuration.schedules.removeAll { $0.weekday == weekday }
                }
                sortWeekdaySchedules()
            }
        )
    }

    private func weekdayTimeBinding(_ weekday: PresenceReminderWeekday) -> Binding<Date> {
        Binding(
            get: {
                date(for: schedule(for: weekday) ?? .suggestedDailyDeadline)
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let index = configuration.schedules.firstIndex(where: { $0.weekday == weekday }) else { return }
                configuration.schedules[index] = PresenceReminderSchedule(
                    weekday: weekday,
                    hour: components.hour ?? 20,
                    minute: components.minute ?? 0
                )
            }
        )
    }

    private func schedule(for weekday: PresenceReminderWeekday) -> PresenceReminderSchedule? {
        configuration.schedules.first { $0.weekday == weekday }
    }

    private func date(for schedule: PresenceReminderSchedule) -> Date {
        Calendar.current.date(
            bySettingHour: schedule.hour,
            minute: schedule.minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func sortWeekdaySchedules() {
        let order = Dictionary(uniqueKeysWithValues: weekdayOrder.enumerated().map { ($1, $0) })
        configuration.schedules.sort {
            order[$0.weekday ?? .sunday, default: .max] < order[$1.weekday ?? .sunday, default: .max]
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        let stored = configurationStore.load()
        configuration = stored
        originalConfiguration = stored
        usesWeekdaySchedules = stored.schedules.contains { $0.weekday != nil }
        reloadContacts()
    }

    private func reloadContacts() {
        do {
            contacts = try appServices.presenceSafety.contacts(context: modelContext)
        } catch {
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.genericError)
        }
    }

    private func saveReminderConfiguration() {
        guard !configuration.isEnabled || !configuration.schedules.isEmpty else {
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.atLeastOneSchedule)
            return
        }

        var proposed = configuration
        // The field remains decodable for old device settings, but all new
        // saves use the fixed local-reminder contract. Cross-device guarding
        // never uploads or sends this text through SMS.
        proposed.messageTemplate = PresenceReminderConfiguration.fixedMessageTemplate
        let effectiveCapabilities = validationCapabilities(for: proposed)
        isSaving = true
        Task { @MainActor in
            let result = await appServices.presenceSafety.activateReminder(
                proposed,
                capabilities: effectiveCapabilities,
                title: notificationTitle,
                body: notificationBody,
                notifications: appServices.userNotifications,
                scheduler: scheduler,
                store: configurationStore
            )
            if result == .scheduled {
                await suppressTodayIfOwnerAlreadyCheckedIn()
            }
            isSaving = false
            handleActivationResult(result, proposed: proposed)
        }
    }

    private func clearLegacyContacts() {
        do {
            let removedCount = try appServices.guardianSafety.deleteLegacySafetyContacts()
            reloadContacts()
            notice = PresenceSafetySettingsNotice(
                title: copy.title,
                message: copy.text(
                    zh: "已从本机清除 \(removedCount) 位旧联系人。",
                    en: "Cleared \(removedCount) legacy contacts from this device.",
                    de: "\(removedCount) alte Kontakte wurden von diesem Gerät gelöscht.",
                    es: "Se borraron \(removedCount) contactos anteriores de este dispositivo.",
                    pt: "\(removedCount) contatos antigos foram removidos deste aparelho.",
                    fr: "\(removedCount) anciens contacts ont été supprimés de cet appareil.",
                    ja: "このデバイスから以前の連絡先を\(removedCount)件削除しました。",
                    ko: "이 기기에서 이전 연락처 \(removedCount)명을 지웠습니다.",
                    it: "Eliminati \(removedCount) vecchi contatti da questo dispositivo."
                )
            )
        } catch {
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.genericError)
        }
    }

    private func suppressTodayIfOwnerAlreadyCheckedIn() async {
        guard let ownerID = UserDefaultsPresenceOwnerSelection().ownerHumanId else { return }
        let now = Date()
        do {
            let snapshot = try appServices.presenceSafety.homeSnapshot(
                context: modelContext,
                ownerHumanId: ownerID,
                now: now
            )
            guard snapshot.subjects.first(where: \.isOwner)?.isCheckedInToday == true else { return }
            await scheduler.cancelToday(now: now)
        } catch {
            OhanaLog.warning(
                "Presence safety settings could not suppress today's reminder: \(error.localizedDescription)",
                category: "Notifications"
            )
        }
    }

    private func validationCapabilities(for proposed: PresenceReminderConfiguration) -> OhanaPlanCapabilities {
        guard hasGrandfatheredAdvancedConfiguration,
              Self.paidFields(of: proposed) == Self.paidFields(of: originalConfiguration) else {
            return capabilities
        }
        // Only the enabled flag may change after downgrade. Validating the
        // untouched paid fields at their former level preserves the existing
        // reminder without opening a path to add or edit paid configuration.
        return .make(for: .personal)
    }

    private func handleActivationResult(
        _ result: PresenceReminderActivationResult,
        proposed: PresenceReminderConfiguration
    ) {
        switch result {
        case .scheduled:
            configuration = proposed
            originalConfiguration = proposed
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.saved)
        case .disabled:
            configuration = proposed
            originalConfiguration = proposed
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.reminderDisabled)
        case .notificationsNotAuthorized:
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.permissionNeeded)
        case .denied:
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.personalReminderHint)
        case .schedulingFailed:
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.genericError)
        }
    }

    private var notificationTitle: String {
        copy.text(
            zh: "今天打卡了吗？",
            en: "Checked in today?",
            de: "Heute eingecheckt?",
            es: "¿Has registrado hoy?",
            pt: "Fez check-in hoje?",
            fr: "Pointage fait aujourd’hui ?",
            ja: "今日チェックインしましたか？",
            ko: "오늘 체크인했나요?",
            it: "Check-in fatto oggi?"
        )
    }

    private var notificationBody: String {
        copy.text(
            zh: "打开 Ohana 确认今天的状态。",
            en: "Open Ohana to confirm today’s status.",
            de: "Öffne Ohana und bestätige den heutigen Status.",
            es: "Abre Ohana para confirmar el estado de hoy.",
            pt: "Abra o Ohana para confirmar o estado de hoje.",
            fr: "Ouvrez Ohana pour confirmer l’état du jour.",
            ja: "Ohanaを開いて今日の状態を確認してください。",
            ko: "Ohana를 열어 오늘 상태를 확인하세요.",
            it: "Apri Ohana per confermare lo stato di oggi."
        )
    }

    private static func requiresPersonal(_ configuration: PresenceReminderConfiguration) -> Bool {
        var normalized = configuration
        normalized.messageTemplate = PresenceReminderConfiguration.fixedMessageTemplate
        return PresenceReminderConfigurationPolicy.denial(
            for: normalized,
            capabilities: .make(for: .free)
        ) != nil
    }

    private static func paidFields(
        of configuration: PresenceReminderConfiguration
    ) -> PresenceReminderPaidFields {
        PresenceReminderPaidFields(
            schedules: configuration.schedules,
            gracePeriodMinutes: configuration.gracePeriodMinutes,
            sendsSecondLocalReminder: configuration.sendsSecondLocalReminder
        )
    }
}

private nonisolated struct PresenceReminderPaidFields: Equatable {
    let schedules: [PresenceReminderSchedule]
    let gracePeriodMinutes: Int?
    let sendsSecondLocalReminder: Bool
}

private nonisolated struct PresenceSafetySettingsNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
