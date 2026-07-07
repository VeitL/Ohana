//
//  HumanAccountSecuritySheet.swift
//  Ohana
//
//  Human account security and privacy sheet.
//

import SwiftData
import SwiftUI

struct HumanAccountSecuritySheet: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var showingPasscodeSheet = false
    @State private var optimisticPrivateFields: Set<String>? = nil
    @State private var privacyErrorMessage: String?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }

    private var hasPasscode: Bool {
        appServices.passcodes.hasPasscode(human)
    }

    private var displayedPrivateFields: Set<String> {
        optimisticPrivateFields ?? human.privateFields
    }

    private var privateCount: Int {
        HumanPrivateField.allCases.count(where: { displayedPrivateFields.contains($0.rawValue) })
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    passcodeCard
                    privacyCard
                }
                .padding(20)
                .padding(.bottom, 10)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .accessibilityIdentifier("human-account-security-sheet")
        .sheet(isPresented: $showingPasscodeSheet) {
            HumanPasscodeManagementSheet(human: human)
        }
        .onDisappear {
            commandQueue.cancelAll()
            optimisticPrivateFields = nil
            privacyErrorMessage = nil
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            accountAvatar(size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "密码与隐私", en: "PIN & Privacy", de: "PIN & Datenschutz"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(displayName(human))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-account-security-close-action")
        }
    }

    private var passcodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: hasPasscode ? "lock.shield.fill" : "lock.open.fill")
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(hasPasscode ? Color.goYellow : Color.goPrimary)
                    .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background((hasPasscode ? Color.goYellow : Color.goPrimary).opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "账户密码", en: "Account PIN", de: "Konto-PIN"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(hasPasscode ? l.tr(zh: "切换到此账户时需要 4 位密码", en: "Switching to this account requires a 4-digit PIN", de: "Für dieses Konto ist eine 4-stellige PIN nötig") : l.tr(zh: "当前为公开切换，可直接进入", en: "This account can be opened directly", de: "Dieses Konto kann direkt geöffnet werden"))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(hasPasscode ? l.tr(zh: "隐私", en: "Private", de: "Privat") : l.tr(zh: "公开", en: "Open", de: "Offen"))
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(hasPasscode ? Color.goYellow : Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(hasPasscode ? Color.goYellow.opacity(0.14) : Color.goPrimary, in: Capsule())
            }

            Button {
                showingPasscodeSheet = true
            } label: {
                Label(hasPasscode ? l.tr(zh: "修改或关闭密码", en: "Change or turn off PIN", de: "PIN ändern oder deaktivieren") : l.tr(zh: "设置 4 位密码", en: "Set 4-digit PIN", de: "4-stellige PIN festlegen"), systemImage: "key.fill")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-passcode-manage-action")
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "资料可见性", en: "Data Visibility", de: "Datensichtbarkeit"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(privateCount == 0 ? l.tr(zh: "所有敏感资料对家庭成员公开", en: "All sensitive data is visible to family members", de: "Alle sensiblen Daten sind für Familienmitglieder sichtbar") : l.tr(zh: "\(privateCount) 项设为仅本人可见", en: "\(privateCount) fields are private", de: "\(privateCount) Felder sind privat"))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .accessibilityIdentifier("human-account-privacy-status")
                }
                Spacer()
                Button {
                    setAllPrivate(false)
                } label: {
                    Text(l.tr(zh: "全公开", en: "All open", de: "Alles offen"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("human-account-privacy-all-open-action")
                Button {
                    setAllPrivate(true)
                } label: {
                    Text(l.tr(zh: "全隐私", en: "All private", de: "Alles privat"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goYellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goYellow.opacity(0.14), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityIdentifier("human-account-privacy-all-private-action")
            }

            if let privacyErrorMessage {
                Text(privacyErrorMessage)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.goRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("human-account-privacy-save-error")
            }

            ForEach(HumanPrivateField.allCases) { field in
                privacyToggleRow(field)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    private func privacyToggleRow(_ field: HumanPrivateField) -> some View {
        Toggle(isOn: Binding(
            get: { displayedPrivateFields.contains(field.rawValue) },
            set: { isPrivate in
                setPrivateField(field, isPrivate: isPrivate)
                UISelectionFeedbackGenerator().selectionChanged()
            }
        )) {
            HStack(spacing: 10) {
                Image(systemName: icon(for: field))
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedFieldTitle(field))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(displayedPrivateFields.contains(field.rawValue) ? l.tr(zh: "仅本人可见", en: "Private to owner", de: "Nur selbst sichtbar") : l.tr(zh: "家庭成员可见", en: "Visible to family", de: "Für Familie sichtbar"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .tint(Color.goYellow)
        .padding(.vertical, 4)
        .accessibilityIdentifier("human-account-privacy-toggle-\(field.rawValue)")
    }

    private func setPrivateField(_ field: HumanPrivateField, isPrivate: Bool) {
        var nextFields = displayedPrivateFields
        if isPrivate {
            nextFields.insert(field.rawValue)
        } else {
            nextFields.remove(field.rawValue)
        }
        setOptimisticPrivateFields(nextFields)

        let action = "field.\(field.rawValue).\(isPrivate ? "private" : "public")"
        let command = DomainCommand.humanPrivacy(humanID: human.id, action: action)
        commandQueue.enqueue(command, delayMilliseconds: 160) {
            do {
                try HumanPrivacyCommandExecutor(context: modelContext, services: appServices).setPrivateField(
                    field,
                    isPrivate: isPrivate,
                    for: human,
                    note: "human.privacy.field"
                )
                privacyErrorMessage = nil
                clearOptimisticPrivateFieldsIfCommitted()
            } catch {
                optimisticPrivateFields = nil
                showPrivacyError(error)
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
    }

    private func setAllPrivate(_ isPrivate: Bool) {
        let nextFields: Set<String> = isPrivate ? Set(HumanPrivateField.allCases.map(\.rawValue)) : []
        setOptimisticPrivateFields(nextFields)

        let action = isPrivate ? "allPrivate" : "allPublic"
        let command = DomainCommand.humanPrivacy(humanID: human.id, action: action)
        commandQueue.cancelAll()
        commandQueue.enqueue(command, delayMilliseconds: 160) {
            do {
                try HumanPrivacyCommandExecutor(context: modelContext, services: appServices).setAllPrivateFields(
                    isPrivate: isPrivate,
                    for: human,
                    note: isPrivate ? "human.privacy.allPrivate" : "human.privacy.allPublic"
                )
                privacyErrorMessage = nil
                clearOptimisticPrivateFieldsIfCommitted()
            } catch {
                optimisticPrivateFields = nil
                showPrivacyError(error)
                appServices.domainRevisions.publishFailure(command: command, error: error)
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func setOptimisticPrivateFields(_ fields: Set<String>) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            optimisticPrivateFields = fields
        }
    }

    private func clearOptimisticPrivateFieldsIfCommitted() {
        guard optimisticPrivateFields == human.privateFields else { return }
        optimisticPrivateFields = nil
    }

    private func showPrivacyError(_ error: Error) {
        privacyErrorMessage = localizedErrorMessage(
            error,
            fallback: l.tr(
                zh: "隐私设置保存失败，请稍后重试。",
                en: "Could not save privacy settings. Try again.",
                de: "Datenschutzeinstellungen konnten nicht gespeichert werden. Versuche es erneut."
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func localizedErrorMessage(_ error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let message = localizedError.errorDescription,
           !message.isEmpty {
            return message
        }
        return fallback
    }

    @ViewBuilder
    private func accountAvatar(size: CGFloat) -> some View {
        HumanAvatarPipelineView(
            human: human,
            size: size,
            fallbackScale: 0.45,
            backgroundOpacity: 0.18
        )
    }

    private func icon(for field: HumanPrivateField) -> String {
        switch field {
        case .weight: "scalemass.fill"
        case .workout: "figure.run"
        case .medication: "pills.fill"
        case .wishlist: "gift.fill"
        case .expense: "creditcard.fill"
        case .note: "note.text"
        }
    }

    private func localizedFieldTitle(_ field: HumanPrivateField) -> String {
        switch field {
        case .weight:
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .workout:
            l.tr(zh: "运动", en: "Workouts", de: "Training")
        case .medication:
            l.tr(zh: "吃药提醒", en: "Medication reminders", de: "Medikamentenerinnerungen")
        case .wishlist:
            l.tr(zh: "椰子资产与心愿", en: "Coconuts & wishes", de: "Kokosnüsse & Wünsche")
        case .expense:
            l.tr(zh: "花费", en: "Expenses", de: "Ausgaben")
        case .note:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied") : name
    }
}
