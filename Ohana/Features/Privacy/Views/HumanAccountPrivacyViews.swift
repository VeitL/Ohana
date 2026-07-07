//
//  HumanAccountPrivacyViews.swift
//  Ohana
//
//  Local account switching, passcode management, and privacy test helpers.
//

import SwiftData
import SwiftUI

struct HumanAccountSwitcherSheet: View {
    let humans: [Human]
    var homePets: [Pet]?
    var homeHumans: [Human]?
    var homeElectronicPets: [OasisElectronicPet]?
    var onSwitched: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var pendingHuman: Human? = nil
    @State private var pin = ""
    @State private var statusMessage = ""
    @State private var isError = false
    @State private var now = Date()
    @State private var pendingPurpose: PendingPurpose = .switchAccount
    @State private var securityHuman: Human? = nil

    private enum PendingPurpose {
        case switchAccount
        case manageSecurity

        func prompt(_ l: L10n) -> String {
            switch self {
            case .switchAccount:
                l.tr(zh: "验证通过后会切换到该账户", en: "Verify to switch to this account", de: "Verifizieren, um zu diesem Konto zu wechseln")
            case .manageSecurity:
                l.tr(zh: "验证通过后打开成员保护设置", en: "Verify to open member protection settings", de: "Verifizieren, um Mitgliederschutz zu öffnen")
            }
        }
    }

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId && !$0.hasPassedAway }
    }

    private var switchableHumans: [Human] {
        humans.filter { !$0.hasPassedAway }
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    activeAccountCard
                    accountList
                    if let pendingHuman {
                        pinPanel(for: pendingHuman)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .accessibilityIdentifier("human-account-switcher-sheet")
        .animation(GoMotion.feedback, value: pendingHuman?.id)
        .sheet(item: $securityHuman) { human in
            HumanAccountSecuritySheet(human: human)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.2.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "切换记录成员", en: "Switch check-in member", de: "Eintragsmitglied wechseln"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "选择后续记录归属的成员", en: "Choose who future records belong to", de: "Wähle, wem künftige Einträge gehören"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-account-switcher-close-action")
        }
    }

    @ViewBuilder
    private var activeAccountCard: some View {
        if let activeHuman {
            HStack(spacing: 12) {
                accountAvatar(activeHuman, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "当前账户", en: "Current account", de: "Aktuelles Konto"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(displayName(activeHuman))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Spacer()
                if HumanLocalPrivacyPolicy.isEnabled {
                    lockButton(for: activeHuman, identifier: "human-account-security-active-action")
                }
            }
            .padding(14)
            .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
            .accessibilityIdentifier("human-account-active-card")
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "成员", en: "Members", de: "Mitglieder"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 2)

            ForEach(switchableHumans) { human in
                accountRow(for: human)
            }
        }
    }

    private func accountRow(for human: Human) -> some View {
        HStack(spacing: 10) {
            Button {
                choose(human)
            } label: {
                HStack(spacing: 12) {
                    accountAvatar(human, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName(human))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(localizedRoleText(for: human.role))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    statusBadge(for: human)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("human-account-switch-row-\(displayName(human))")

            if HumanLocalPrivacyPolicy.isEnabled {
                lockButton(for: human, identifier: "human-account-security-row-action-\(displayName(human))")
            }
        }
        .padding(13)
        .background(pendingHuman?.id == human.id ? Color.goPrimary.opacity(0.16) : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(pendingHuman?.id == human.id ? Color.goPrimary.opacity(0.44) : Color.clear, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func statusBadge(for human: Human) -> some View {
        if human.id.uuidString == activeHumanId {
            Text(l.tr(zh: "当前", en: "Current", de: "Aktuell"))
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.arkInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.goPrimary, in: Capsule())
        } else if HumanLocalPrivacyPolicy.isEnabled,
                  appServices.passcodes.hasPasscode(human) {
            Text(l.tr(zh: "需密码", en: "PIN needed", de: "PIN nötig"))
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.goYellow)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.goYellow.opacity(0.14), in: Capsule())
        } else {
            Text(l.tr(zh: "可切换", en: "Can switch", de: "Wechselbar"))
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.ohanaControlFill, in: Capsule())
        }
    }

    private func lockButton(for human: Human, identifier: String) -> some View {
        Button {
            openSecurity(for: human)
        } label: {
            Image(systemName: appServices.passcodes.hasPasscode(human) ? "lock.fill" : "lock.open.fill")
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(appServices.passcodes.hasPasscode(human) ? Color.goYellow : Color.ohanaTertiaryText)
                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "成员保护", en: "Member protection", de: "Mitgliederschutz"))
        .accessibilityIdentifier(identifier)
    }

    private func pinPanel(for human: Human) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                accountAvatar(human, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "输入 \(displayName(human)) 的 4 位密码", en: "Enter \(displayName(human))'s 4-digit PIN", de: "4-stellige PIN für \(displayName(human)) eingeben"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(statusMessage.isEmpty ? pendingPurpose.prompt(l) : statusMessage)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(isError ? Color.goRed : Color.ohanaSecondaryText)
                }
                Spacer()
            }

            HumanPasscodePad(pin: $pin, accent: Color(hex: human.themeColor)) {
                verifyPendingPasscode()
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func choose(_ human: Human) {
        UISelectionFeedbackGenerator().selectionChanged()
        pendingPurpose = .switchAccount
        guard human.id.uuidString != activeHumanId else {
            dismiss()
            return
        }
        guard HumanLocalPrivacyPolicy.isEnabled else {
            switchTo(human)
            return
        }
        guard appServices.passcodes.hasPasscode(human) else {
            switchTo(human)
            return
        }
        now = Date()
        if let seconds = appServices.passcodes.remainingLockoutSeconds(for: human, now: now) {
            pendingHuman = human
            pin = ""
            isError = true
            statusMessage = l.tr(zh: "请 \(seconds) 秒后再试", en: "Try again in \(seconds) seconds", de: "In \(seconds) Sekunden erneut versuchen")
            return
        }
        pendingHuman = human
        pin = ""
        isError = false
        statusMessage = ""
    }

    private func openSecurity(for human: Human) {
        guard HumanLocalPrivacyPolicy.isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        guard human.id.uuidString != activeHumanId else {
            pendingHuman = nil
            pin = ""
            securityHuman = human
            return
        }
        guard appServices.passcodes.hasPasscode(human) else {
            activateAndManageSecurity(human)
            return
        }
        now = Date()
        pendingPurpose = .manageSecurity
        pendingHuman = human
        pin = ""
        if let seconds = appServices.passcodes.remainingLockoutSeconds(for: human, now: now) {
            isError = true
            statusMessage = l.tr(zh: "请 \(seconds) 秒后再试", en: "Try again in \(seconds) seconds", de: "In \(seconds) Sekunden erneut versuchen")
        } else {
            isError = false
            statusMessage = ""
        }
    }

    private func verifyPendingPasscode() {
        guard let human = pendingHuman else { return }
        now = Date()
        switch HumanPrivacyCommandExecutor(context: modelContext, services: appServices).verifyPasscode(pin, for: human, now: now) {
        case .success:
            completePendingAccess(for: human)
        case let .incorrect(remaining):
            pin = ""
            isError = true
            statusMessage = l.tr(zh: "密码不正确，还可尝试 \(remaining) 次", en: "Incorrect PIN. \(remaining) attempts left.", de: "Falsche PIN. Noch \(remaining) Versuche.")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case let .locked(until):
            pin = ""
            isError = true
            let seconds = max(1, Int(ceil(until.timeIntervalSince(now))))
            statusMessage = l.tr(zh: "尝试过多，请 \(seconds) 秒后再试", en: "Too many attempts. Try again in \(seconds) seconds.", de: "Zu viele Versuche. In \(seconds) Sekunden erneut versuchen.")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .invalidFormat:
            pin = ""
            isError = true
            statusMessage = l.tr(zh: "请输入 4 位数字", en: "Enter a 4-digit PIN", de: "4-stellige PIN eingeben")
        case .noPasscode:
            completePendingAccess(for: human)
        case .memberInactive:
            pin = ""
            isError = true
            statusMessage = l.tr(zh: "纪念成员不能切换或修改安全设置", en: "Memorial members cannot switch accounts or change security settings", de: "Gedenkmitglieder können weder wechseln noch Sicherheit ändern")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func completePendingAccess(for human: Human) {
        switch pendingPurpose {
        case .switchAccount:
            switchTo(human)
        case .manageSecurity:
            activateAndManageSecurity(human)
        }
    }

    private func activateAndManageSecurity(_ human: Human) {
        let oldHumanIdRaw = activeHumanId
        activeHumanId = human.id.uuidString
        syncHomeCardStackAfterAccountSwitch(from: oldHumanIdRaw, to: human)
        pendingHuman = nil
        pin = ""
        statusMessage = ""
        isError = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSwitched?()
        securityHuman = human
    }

    private func switchTo(_ human: Human) {
        let oldHumanIdRaw = activeHumanId
        activeHumanId = human.id.uuidString
        syncHomeCardStackAfterAccountSwitch(from: oldHumanIdRaw, to: human)
        pendingHuman = nil
        pin = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSwitched?()
        dismiss()
    }

    private func syncHomeCardStackAfterAccountSwitch(from oldHumanIdRaw: String, to human: Human) {
        guard let homePets else { return }
        let sourceHumans = homeHumans ?? humans
        let result = SettingsCommandExecutor(context: modelContext, services: appServices).syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: homePets,
            humans: sourceHumans,
            electronicPets: homeElectronicPets ?? [],
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            note: "settings.activeHuman.switch"
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if result.updatedHomeCardOrderRaw != homeCardOrderRaw {
                homeCardOrderRaw = result.updatedHomeCardOrderRaw
            }
        }
    }

    @ViewBuilder
    private func accountAvatar(_ human: Human, size: CGFloat) -> some View {
        HumanAvatarPipelineView(
            human: human,
            size: size,
            fallbackScale: 0.45,
            backgroundOpacity: 0.18
        )
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied") : name
    }

    private func localizedRoleText(for raw: String) -> String {
        HumanProfileOptions.localizedRoleTitle(raw, l: l)
    }
}
