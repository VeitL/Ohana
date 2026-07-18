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
    @State private var activeSheet: PresenceSafetySettingsSheet?
    @State private var notice: PresenceSafetySettingsNotice?
    @State private var didLoad = false
    @State private var isSaving = false

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
            messageSection
            contactsSection
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
        .sheet(item: $activeSheet, onDismiss: reloadContacts) { sheet in
            switch sheet {
            case .addContact:
                PresenceContactEditorView(contact: nil, capabilities: capabilities)
            case let .editContact(contact):
                PresenceContactEditorView(contact: contact, capabilities: capabilities)
            case let .compose(draft):
                PresenceMessageComposerView(draft: draft) { outcome in
                    activeSheet = nil
                    handleMessageOutcome(outcome)
                }
                .ignoresSafeArea()
            case let .copyFallback(contact, draft):
                PresenceMessageCopyFallbackView(contact: contact, draft: draft)
                    .presentationDetents([.medium, .large])
            }
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

    private var messageSection: some View {
        Section {
            if capabilities.contacts.allowsEditableMessageTemplate,
               !hasGrandfatheredAdvancedConfiguration {
                TextEditor(text: $configuration.messageTemplate)
                    .frame(minHeight: 92)
                    .accessibilityLabel(copy.messageSection)
                    .accessibilityIdentifier("presence-message-template")
            } else {
                Text(effectiveMessageTemplate)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text(copy.messageSection)
        } footer: {
            Text(copy.messageExplanation)
        }
    }

    private var contactsSection: some View {
        Section {
            ForEach(contacts) { contact in
                contactRow(contact)
            }

            Button {
                activeSheet = .addContact
            } label: {
                Label(copy.addContact, systemImage: "person.badge.plus")
            }
            .disabled(contacts.count >= capabilities.contacts.maximumLocalContacts)
            .accessibilityIdentifier("presence-contact-add")

            if contacts.count >= capabilities.contacts.maximumLocalContacts {
                Text(copy.contactLimit(limit: capabilities.contacts.maximumLocalContacts))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            HStack {
                Text(copy.contactsSection)
                Spacer()
                Text("\(contacts.count)/\(capabilities.contacts.maximumLocalContacts)")
                    .accessibilityLabel("\(contacts.count) / \(capabilities.contacts.maximumLocalContacts)")
            }
        } footer: {
            Text(copy.localOnlyContactsHint)
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

    private func contactRow(_ contact: SafetyContactSnapshot) -> some View {
        HStack(spacing: 12) {
            Button {
                activeSheet = .editContact(contact)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(contact.name)
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        if !contact.isEnabled {
                            Text(copy.text(
                                zh: "已停用",
                                en: "Off",
                                de: "Aus",
                                es: "Inactivo",
                                pt: "Inativo",
                                fr: "Désactivé",
                                ja: "オフ",
                                ko: "꺼짐",
                                it: "Disattivo"
                            ))
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                    Text(contact.phoneNumber)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(copy.editContact): \(contact.name), \(contact.phoneNumber)")

            Button {
                composeMessage(to: contact)
            } label: {
                Image(systemName: "message.fill")
                    .font(OhanaFont.body(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(contact.isEnabled ? Color.goPrimary : Color.ohanaTertiaryText)
            .disabled(!contact.isEnabled)
            .accessibilityLabel("\(copy.composeMessage): \(contact.name)")
            .accessibilityHint(copy.messageExplanation)
        }
    }

    private var effectiveMessageTemplate: String {
        let clean = configuration.messageTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty || clean == PresenceReminderConfiguration.fixedMessageTemplate {
            return copy.fixedMessageTemplate
        }
        return clean
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
        var presented = stored
        if capabilities.contacts.allowsEditableMessageTemplate,
           stored.messageTemplate == PresenceReminderConfiguration.fixedMessageTemplate {
            presented.messageTemplate = copy.fixedMessageTemplate
        }
        configuration = presented
        originalConfiguration = presented
        usesWeekdaySchedules = stored.schedules.contains { $0.weekday != nil }
        reloadContacts()
    }

    private func reloadContacts() {
        do {
            contacts = try SafetyContactCommandService.snapshots(context: modelContext)
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
        proposed.messageTemplate = !capabilities.contacts.allowsEditableMessageTemplate &&
            !hasGrandfatheredAdvancedConfiguration
            ? PresenceReminderConfiguration.fixedMessageTemplate
            : effectiveMessageTemplate
        let effectiveCapabilities = validationCapabilities(for: proposed)
        isSaving = true
        Task { @MainActor in
            let result = await PresenceReminderActivationCoordinator.applyAfterUserRequest(
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

    private func suppressTodayIfOwnerAlreadyCheckedIn() async {
        guard let ownerID = UserDefaultsPresenceOwnerSelection().ownerHumanId else { return }
        let now = Date()
        do {
            let snapshot = try PresenceCheckInReadService.homeSnapshot(
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

    private func composeMessage(to contact: SafetyContactSnapshot) {
        let draft = PresenceSafetyMessageDraft(
            recipients: [contact.phoneNumber],
            configuredTemplate: effectiveMessageTemplate
        )
        activeSheet = PresenceMessageComposerView.canSendText
            ? .compose(draft: draft)
            : .copyFallback(contact: contact, draft: draft)
    }

    private func handleMessageOutcome(_ outcome: PresenceMessageComposerOutcome) {
        switch outcome {
        case .sent:
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.messageSent)
        case .failed:
            notice = PresenceSafetySettingsNotice(title: copy.title, message: copy.messageFailed)
        case .cancelled:
            break
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
        PresenceReminderConfigurationPolicy.denial(
            for: configuration,
            capabilities: .make(for: .free)
        ) != nil
    }

    private static func paidFields(
        of configuration: PresenceReminderConfiguration
    ) -> PresenceReminderPaidFields {
        PresenceReminderPaidFields(
            schedules: configuration.schedules,
            gracePeriodMinutes: configuration.gracePeriodMinutes,
            sendsSecondLocalReminder: configuration.sendsSecondLocalReminder,
            messageTemplate: configuration.messageTemplate
        )
    }
}

private nonisolated struct PresenceReminderPaidFields: Equatable {
    let schedules: [PresenceReminderSchedule]
    let gracePeriodMinutes: Int?
    let sendsSecondLocalReminder: Bool
    let messageTemplate: String
}

private nonisolated enum PresenceSafetySettingsSheet: Identifiable {
    case addContact
    case editContact(SafetyContactSnapshot)
    case compose(draft: PresenceSafetyMessageDraft)
    case copyFallback(contact: SafetyContactSnapshot, draft: PresenceSafetyMessageDraft)

    var id: String {
        switch self {
        case .addContact:
            "add-contact"
        case let .editContact(contact):
            "edit-contact-\(contact.id.uuidString)"
        case .compose:
            "compose-message"
        case let .copyFallback(contact, _):
            "copy-fallback-\(contact.id.uuidString)"
        }
    }
}

private nonisolated struct PresenceSafetySettingsNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
private struct PresenceContactEditorView: View {
    let contact: SafetyContactSnapshot?
    let capabilities: OhanaPlanCapabilities

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var name: String
    @State private var phoneNumber: String
    @State private var isEnabled: Bool
    @State private var errorMessage: String?
    @State private var isShowingDeleteConfirmation = false

    init(contact: SafetyContactSnapshot?, capabilities: OhanaPlanCapabilities) {
        self.contact = contact
        self.capabilities = capabilities
        _name = State(initialValue: contact?.name ?? "")
        _phoneNumber = State(initialValue: contact?.phoneNumber ?? "")
        _isEnabled = State(initialValue: contact?.isEnabled ?? true)
    }

    private var copy: PresenceSafetySettingsCopy {
        PresenceSafetySettingsCopy(languageCode: appLanguage)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(copy.contactName, text: $name)
                        .textContentType(.name)
                        .accessibilityIdentifier("presence-contact-name")
                    TextField(copy.phoneNumber, text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .accessibilityIdentifier("presence-contact-phone")
                    Toggle(copy.contactEnabled, isOn: $isEnabled)
                        .tint(Color.goPrimary)
                }

                if contact != nil {
                    Section {
                        Button(copy.delete, role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(contact == nil ? copy.addContact : copy.editContact)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(copy.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy.save) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(copy.delete, isPresented: $isShowingDeleteConfirmation) {
                Button(copy.cancel, role: .cancel) {}
                Button(copy.delete, role: .destructive) { deleteContact() }
            } message: {
                Text(copy.text(
                    zh: "此操作只会从本机删除这位联系人。",
                    en: "This removes the contact from this device only.",
                    de: "Dadurch wird der Kontakt nur von diesem Gerät entfernt.",
                    es: "Esto elimina el contacto solo de este dispositivo.",
                    pt: "Isso remove o contato apenas deste dispositivo.",
                    fr: "Cette action supprime le contact de cet appareil uniquement.",
                    ja: "このデバイスからのみ連絡先を削除します。",
                    ko: "이 기기에서만 연락처를 삭제합니다.",
                    it: "Rimuove il contatto solo da questo dispositivo."
                ))
            }
            .alert(
                copy.title,
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(copy.text(
                    zh: "好",
                    en: "OK",
                    de: "OK",
                    es: "Aceptar",
                    pt: "OK",
                    fr: "OK",
                    ja: "OK",
                    ko: "확인",
                    it: "OK"
                )) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? copy.genericError)
            }
        }
    }

    private func save() {
        do {
            if let contact {
                try SafetyContactCommandService.update(
                    id: contact.id,
                    name: name,
                    phoneNumber: phoneNumber,
                    isEnabled: isEnabled,
                    context: modelContext
                )
            } else {
                try SafetyContactCommandService.create(
                    name: name,
                    phoneNumber: phoneNumber,
                    capabilities: capabilities,
                    context: modelContext
                )
            }
            dismiss()
        } catch let error as SafetyContactCommandError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = copy.genericError
        }
    }

    private func deleteContact() {
        guard let contact else { return }
        do {
            try SafetyContactCommandService.delete(id: contact.id, context: modelContext)
            dismiss()
        } catch {
            errorMessage = copy.genericError
        }
    }

    private func message(for error: SafetyContactCommandError) -> String {
        switch error {
        case .invalidName:
            copy.invalidName
        case .invalidPhoneNumber:
            copy.invalidPhone
        case let .contactLimitReached(limit):
            copy.contactLimit(limit: limit)
        case .contactNotFound, .persistenceFailed:
            copy.genericError
        }
    }
}
