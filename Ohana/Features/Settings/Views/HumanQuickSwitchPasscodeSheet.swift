import Foundation
import SwiftData
import SwiftUI

struct HumanQuickSwitchPasscodeSheet: View {
    let human: Human
    let onVerified: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage(MemberGateBiometricAuthStore.enabledKey) private var enableMemberGateBiometrics = MemberGateBiometricAuthStore.defaultEnabled

    @State private var pin = ""
    @State private var message = "输入 4 位密码后切换到此账户"
    @State private var isError = false
    @State private var biometricAvailability = MemberGateBiometricAuthenticator.availability()
    @State private var isAuthenticatingBiometrics = false

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
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text("切换到 \(displayName(human))")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text("此账户已开启 4 位密码")
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
                isAuthenticatingBiometrics ? "正在验证 \(biometricAvailability.label)" : "使用 \(biometricAvailability.label)",
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
            message = "密码不正确，还可尝试 \(remaining) 次"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case let .locked(until):
            pin = ""
            isError = true
            message = "尝试过多，请 \(max(1, Int(ceil(until.timeIntervalSince(now))))) 秒后再试"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .invalidFormat:
            pin = ""
            isError = true
            message = "请输入 4 位数字"
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
        message = "正在验证 \(biometricAvailability.label)"
        Task { @MainActor in
            let success = await MemberGateBiometricAuthenticator.authenticate(
                reason: "验证后切换到 \(displayName(human))"
            )
            isAuthenticatingBiometrics = false
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onVerified()
                dismiss()
            } else {
                isError = true
                message = "\(biometricAvailability.label) 未通过，可继续输入密码"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "成员" : name
    }
}
