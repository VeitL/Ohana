import Foundation
import SwiftData
import SwiftUI

struct HumanQuickSwitchPasscodeSheet: View {
    let human: Human
    let onVerified: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(MemberGateBiometricAuthStore.enabledKey) private var enableMemberGateBiometrics = MemberGateBiometricAuthStore.defaultEnabled

    @State private var pin = ""
    @State private var message = ""
    @State private var isError = false
    @State private var biometricAvailability = MemberGateBiometricAuthenticator.availability()
    @State private var isAuthenticatingBiometrics = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    HumanPasscodePad(pin: $pin, accent: Color(hex: human.themeColor)) {
                        verify()
                    }
                    .padding(.top, 8)
                    if canUseBiometricMemberGate {
                        biometricButton
                    }
                    statusText
                }
                .padding(22)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            biometricAvailability = MemberGateBiometricAuthenticator.availability()
            if message.isEmpty {
                message = l.tr(
                    zh: "输入 4 位密码后切换到此账户",
                    en: "Enter the 4-digit PIN to switch to this account",
                    de: "Gib die 4-stellige PIN ein, um zu diesem Konto zu wechseln"
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(
                    zh: "切换到 \(displayName(human))",
                    en: "Switch to \(displayName(human))",
                    de: "Zu \(displayName(human)) wechseln"
                ))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                Text(l.tr(
                    zh: "此账户已开启 4 位密码",
                    en: "This account uses a 4-digit PIN",
                    de: "Dieses Konto nutzt eine 4-stellige PIN"
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var statusText: some View {
        Text(message)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(isError ? Color.goRed : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .animation(GoMotion.feedback, value: isError)
    }

    private var biometricButton: some View {
        Button {
            authenticateWithBiometrics()
        } label: {
            Label(
                isAuthenticatingBiometrics
                    ? l.tr(zh: "正在验证 \(biometricAvailability.label)", en: "Verifying \(biometricAvailability.label)", de: "\(biometricAvailability.label) wird geprüft")
                    : l.tr(zh: "使用 \(biometricAvailability.label)", en: "Use \(biometricAvailability.label)", de: "\(biometricAvailability.label) verwenden"),
                systemImage: biometricAvailability.symbolName
            )
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.arkInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isAuthenticatingBiometrics)
    }

    private var avatar: some View {
        HumanAvatarPipelineView(
            human: human,
            size: 48,
            fallbackScale: 0.46,
            backgroundOpacity: 0.18
        )
    }

    private func verify() {
        let now = Date()
        switch HumanPrivacyCommandExecutor(context: modelContext, services: appServices).verifyPasscode(pin, for: human, now: now) {
        case .success, .noPasscode:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onVerified()
            dismiss()
        case let .incorrect(remaining):
            pin = ""
            isError = true
            message = l.tr(
                zh: "密码不正确，还可尝试 \(remaining) 次",
                en: "Incorrect PIN. \(remaining) attempts remaining.",
                de: "Falsche PIN. Noch \(remaining) Versuche."
            )
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case let .locked(until):
            pin = ""
            isError = true
            let seconds = max(1, Int(ceil(until.timeIntervalSince(now))))
            message = l.tr(
                zh: "尝试过多，请 \(seconds) 秒后再试",
                en: "Too many attempts. Try again in \(seconds) seconds.",
                de: "Zu viele Versuche. In \(seconds) Sekunden erneut versuchen."
            )
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .invalidFormat:
            pin = ""
            isError = true
            message = l.tr(
                zh: "请输入 4 位数字",
                en: "Enter 4 digits",
                de: "Gib 4 Ziffern ein"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .memberInactive:
            pin = ""
            isError = true
            message = l.tr(
                zh: "纪念成员不能切换为当前账户",
                en: "Memorial members cannot become the current account",
                de: "Gedenkmitglieder können nicht zum aktuellen Konto werden"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private var canUseBiometricMemberGate: Bool {
        enableMemberGateBiometrics && biometricAvailability.isAvailable
    }

    private func authenticateWithBiometrics() {
        guard !isAuthenticatingBiometrics else { return }
        isAuthenticatingBiometrics = true
        isError = false
        message = l.tr(
            zh: "正在验证 \(biometricAvailability.label)",
            en: "Verifying \(biometricAvailability.label)",
            de: "\(biometricAvailability.label) wird geprüft"
        )
        Task { @MainActor in
            let success = await MemberGateBiometricAuthenticator.authenticate(
                reason: l.tr(
                    zh: "验证后切换到 \(displayName(human))",
                    en: "Authenticate to switch to \(displayName(human))",
                    de: "Authentifizieren, um zu \(displayName(human)) zu wechseln"
                )
            )
            isAuthenticatingBiometrics = false
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onVerified()
                dismiss()
            } else {
                isError = true
                message = l.tr(
                    zh: "\(biometricAvailability.label) 未通过，可继续输入密码",
                    en: "\(biometricAvailability.label) failed. You can still enter the PIN.",
                    de: "\(biometricAvailability.label) fehlgeschlagen. Du kannst weiter die PIN eingeben."
                )
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? l.tr(zh: "成员", en: "Member", de: "Mitglied") : name
    }
}
