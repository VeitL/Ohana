//
//  HumanPasscodeManagementSheet.swift
//  Ohana
//
//  Passcode setup, change, and removal sheet.
//

import SwiftData
import SwiftUI

struct HumanPasscodeManagementSheet: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var mode: Mode = .set
    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var message = ""
    @State private var isError = false

    private enum Mode {
        case set
        case overview
        case change
        case remove
    }

    private enum PinInputTarget: Hashable {
        case current
        case new
        case confirm
    }

    @State private var activePinTarget: PinInputTarget?

    init(human: Human) {
        self.human = human
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            VStack(alignment: .leading, spacing: 18) {
                header
                content
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .presentationDetents(OhanaSheetDetents.overview)
        .presentationDragIndicator(.hidden)
        .onChange(of: currentPin) { _, value in currentPin = sanitized(value) }
        .onChange(of: newPin) { _, value in newPin = sanitized(value) }
        .onChange(of: confirmPin) { _, value in confirmPin = sanitized(value) }
        .task(id: human.id) {
            mode = appServices.passcodes.hasPasscode(human) ? .overview : .set
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: appServices.passcodes.hasPasscode(human) ? "lock.shield.fill" : "lock.open.fill")
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goYellow.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "账户 4 位密码", en: "Account 4-digit PIN", de: "4-stellige Konto-PIN"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "用于在同一设备上切换到 \(displayName(human)) 时验证", en: "Used to verify switches to \(displayName(human)) on this device", de: "Wird beim Wechsel zu \(displayName(human)) auf diesem Gerät geprüft"))
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
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .overview:
            VStack(spacing: 12) {
                statusCard(
                    title: l.tr(zh: "已开启", en: "Enabled", de: "Aktiviert"),
                    subtitle: l.tr(zh: "其他成员切换到此账户时需要输入 4 位密码", en: "Other members need the 4-digit PIN to switch to this account", de: "Andere Mitglieder brauchen die 4-stellige PIN für dieses Konto"),
                    icon: "checkmark.shield.fill",
                    tint: Color.goPrimary
                )
                Button { resetInputs()
                    mode = .change
                } label: {
                    actionRow(title: l.tr(zh: "修改密码", en: "Change PIN", de: "PIN ändern"), icon: "key.fill", tint: Color.goPrimary)
                }
                .buttonStyle(ScaleButtonStyle())
                Button { resetInputs()
                    mode = .remove
                } label: {
                    actionRow(title: l.tr(zh: "关闭密码", en: "Turn off PIN", de: "PIN deaktivieren"), icon: "lock.open.fill", tint: Color.goRed)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        case .set:
            formContent(
                title: l.tr(zh: "设置 4 位密码", en: "Set 4-digit PIN", de: "4-stellige PIN festlegen"),
                needsCurrent: false,
                primaryTitle: l.tr(zh: "开启密码", en: "Enable PIN", de: "PIN aktivieren"),
                primaryAction: setPasscode
            )
        case .change:
            formContent(
                title: l.tr(zh: "修改 4 位密码", en: "Change 4-digit PIN", de: "4-stellige PIN ändern"),
                needsCurrent: true,
                primaryTitle: l.tr(zh: "保存新密码", en: "Save new PIN", de: "Neue PIN speichern"),
                primaryAction: changePasscode
            )
        case .remove:
            VStack(spacing: 14) {
                statusCard(
                    title: l.tr(zh: "关闭后可直接切换", en: "Direct switching after turning off", de: "Direkter Wechsel nach dem Deaktivieren"),
                    subtitle: l.tr(zh: "请输入当前密码确认关闭", en: "Enter the current PIN to confirm", de: "Aktuelle PIN zur Bestätigung eingeben"),
                    icon: "exclamationmark.lock.fill",
                    tint: Color.goRed
                )
                pinField(l.tr(zh: "当前密码", en: "Current PIN", de: "Aktuelle PIN"), text: $currentPin, target: .current)
                messageView
                HStack(spacing: 10) {
                    secondaryButton(l.tr(zh: "返回", en: "Back", de: "Zurück")) { resetInputs()
                        mode = .overview
                    }
                    primaryButton(l.tr(zh: "关闭密码", en: "Turn off PIN", de: "PIN deaktivieren"), tint: Color.goRed, foreground: .white, action: removePasscode)
                }
            }
        }
    }

    private func formContent(title: String, needsCurrent: Bool, primaryTitle: String, primaryAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if needsCurrent {
                pinField(l.tr(zh: "当前密码", en: "Current PIN", de: "Aktuelle PIN"), text: $currentPin, target: .current)
            }
            pinField(l.tr(zh: "新密码", en: "New PIN", de: "Neue PIN"), text: $newPin, target: .new)
            pinField(l.tr(zh: "确认新密码", en: "Confirm new PIN", de: "Neue PIN bestätigen"), text: $confirmPin, target: .confirm)
            messageView
            HStack(spacing: 10) {
                if appServices.passcodes.hasPasscode(human) {
                    secondaryButton(l.tr(zh: "返回", en: "Back", de: "Zurück")) { resetInputs()
                        mode = .overview
                    }
                }
                primaryButton(primaryTitle, tint: Color.goPrimary, action: primaryAction)
            }
        }
    }

    private func statusCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func actionRow(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText.opacity(0.5))
        }
        .padding(14)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func pinField(_ title: String, text: Binding<String>, target: PinInputTarget) -> some View {
        VStack(spacing: 8) {
            Button {
                GoKeyboard.dismiss()
                withAnimation(GoMotion.feedback) {
                    activePinTarget = activePinTarget == target ? nil : target
                }
            } label: {
                HStack {
                    Text(title)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    HStack(spacing: 7) {
                        ForEach(0 ..< 4, id: \.self) { index in
                            Circle()
                                .fill(index < text.wrappedValue.count ? Color.goPrimary : Color.ohanaControlFill)
                                .frame(width: 10, height: 10) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .strokeBorder(activePinTarget == target ? Color.goPrimary.opacity(0.42) : Color.primary.opacity(0.10), lineWidth: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            if activePinTarget == target {
                HumanPasscodePad(pin: text, accent: Color.goPrimary) {
                    withAnimation(GoMotion.feedback) {
                        activePinTarget = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    @ViewBuilder
    private var messageView: some View {
        if !message.isEmpty {
            Text(message)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(isError ? Color.goRed : Color.goPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func primaryButton(_ title: String, tint: Color, foreground: Color = Color.arkInk, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func setPasscode() {
        guard validateNewPins() else { return }
        do {
            _ = try HumanPrivacyCommandExecutor(context: modelContext, services: appServices).setPasscode(
                newPin,
                for: human,
                note: "human.privacy.passcode.set"
            )
            successAndDismiss(l.tr(zh: "密码已开启", en: "PIN enabled", de: "PIN aktiviert"))
        } catch {
            showError(passcodeErrorMessage(
                error,
                fallback: l.tr(zh: "请输入 4 位数字", en: "Enter a 4-digit PIN", de: "4-stellige PIN eingeben")
            ))
        }
    }

    private func changePasscode() {
        guard validateNewPins() else { return }
        do {
            let result = try HumanPrivacyCommandExecutor(context: modelContext, services: appServices).changePasscode(
                currentPin: currentPin,
                newPin: newPin,
                for: human,
                note: "human.privacy.passcode.change"
            )
            handleManagementResult(result, success: l.tr(zh: "密码已修改", en: "PIN changed", de: "PIN geändert"))
        } catch {
            showError(passcodeErrorMessage(
                error,
                fallback: l.tr(zh: "请输入 4 位数字", en: "Enter a 4-digit PIN", de: "4-stellige PIN eingeben")
            ))
        }
    }

    private func removePasscode() {
        do {
            let result = try HumanPrivacyCommandExecutor(context: modelContext, services: appServices).removePasscode(
                currentPin: currentPin,
                for: human,
                note: "human.privacy.passcode.remove"
            )
            handleManagementResult(result, success: l.tr(zh: "密码已关闭", en: "PIN turned off", de: "PIN deaktiviert"))
        } catch {
            showError(passcodeErrorMessage(
                error,
                fallback: l.tr(zh: "请输入当前 4 位密码", en: "Enter the current 4-digit PIN", de: "Aktuelle 4-stellige PIN eingeben")
            ))
        }
    }

    private func passcodeErrorMessage(_ error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let message = localizedError.errorDescription,
           !message.isEmpty {
            return message
        }
        return fallback
    }

    private func handleManagementResult(_ result: HumanPasscodeVerification, success: String) {
        switch result {
        case .success:
            successAndDismiss(success)
        case let .incorrect(remaining):
            showError(l.tr(zh: "当前密码不正确，还可尝试 \(remaining) 次", en: "Current PIN is incorrect. \(remaining) attempts left.", de: "Aktuelle PIN ist falsch. Noch \(remaining) Versuche."))
        case let .locked(until):
            let seconds = max(1, Int(ceil(until.timeIntervalSince(Date()))))
            showError(l.tr(zh: "尝试过多，请 \(seconds) 秒后再试", en: "Too many attempts. Try again in \(seconds) seconds.", de: "Zu viele Versuche. In \(seconds) Sekunden erneut versuchen."))
        case .invalidFormat:
            showError(l.tr(zh: "请输入 4 位数字", en: "Enter a 4-digit PIN", de: "4-stellige PIN eingeben"))
        case .noPasscode:
            showError(l.tr(zh: "此账户还没有密码", en: "This account does not have a PIN yet", de: "Dieses Konto hat noch keine PIN"))
        case .memberInactive:
            showError(l.tr(zh: "纪念成员不能修改密码", en: "Memorial members cannot change PINs", de: "Gedenkmitglieder können keine PIN ändern"))
        }
    }

    private func validateNewPins() -> Bool {
        guard appServices.passcodes.isValidPin(newPin) else {
            showError(l.tr(zh: "新密码需要是 4 位数字", en: "The new PIN must be 4 digits", de: "Die neue PIN muss 4-stellig sein"))
            return false
        }
        guard newPin == confirmPin else {
            showError(l.tr(zh: "两次输入不一致", en: "The two PIN entries do not match", de: "Die beiden PINs stimmen nicht überein"))
            return false
        }
        return true
    }

    private func successAndDismiss(_ text: String) {
        isError = false
        message = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func showError(_ text: String) {
        isError = true
        message = text
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func resetInputs() {
        currentPin = ""
        newPin = ""
        confirmPin = ""
        message = ""
        isError = false
        activePinTarget = nil
    }

    private func sanitized(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(4))
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied") : name
    }
}
