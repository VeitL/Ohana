//
//  HumanExecutorSwitchSheet.swift
//  Ohana
//
//  Executor account switch sheet.
//

import SwiftData
import SwiftUI

struct HumanExecutorSwitchSheet: View {
    let humans: [Human]
    var onSwitched: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""
    @AppStorage(MemberGateBiometricAuthStore.enabledKey) private var enableMemberGateBiometrics = MemberGateBiometricAuthStore.defaultEnabled

    @State private var pendingHuman: Human? = nil
    @State private var pin = ""
    @State private var statusMessage = ""
    @State private var isError = false
    @State private var now = Date()
    @State private var biometricAvailability = MemberGateBiometricAuthenticator.availability()
    @State private var isAuthenticatingBiometrics = false

    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId && !$0.hasPassedAway }
    }

    private var switchableHumans: [Human] {
        humans.filter { !$0.hasPassedAway }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            VStack(alignment: .leading, spacing: 14) {
                header
                if pendingHuman == nil {
                    accountRows
                }
                if let pendingHuman {
                    pinPanel(for: pendingHuman)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(pendingHuman == nil ? 330 : (canUseBiometricMemberGate ? 500 : 430))])
        .presentationDragIndicator(.hidden)
        .animation(GoMotion.feedback, value: pendingHuman?.id)
        .onAppear {
            biometricAvailability = MemberGateBiometricAuthenticator.availability()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPrimary.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("切换执行人")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("后续打卡会记录到当前账户")
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

    private var accountRows: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 9) {
                ForEach(switchableHumans) { human in
                    accountRow(for: human)
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxHeight: 190)
    }

    private func accountRow(for human: Human) -> some View {
        let isActive = human.id.uuidString == activeHumanId
        return Button {
            choose(human)
        } label: {
            HStack(spacing: 12) {
                accountAvatar(human, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName(human))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isActive ? "当前执行人" : (appServices.passcodes.hasPasscode(human) ? "需要 4 位密码" : "可直接切换"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                } else if appServices.passcodes.hasPasscode(human) {
                    Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goYellow)
                        .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goYellow.opacity(0.14), in: Circle())
                } else {
                    Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(12)
            .background(
                Color.primary.opacity(pendingHuman?.id == human.id ? 0.11 : (isActive ? 0.09 : 0.055)),
                in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(pendingHuman?.id == human.id ? Color.goPrimary.opacity(0.52) : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func pinPanel(for human: Human) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                accountAvatar(human, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("输入 \(displayName(human)) 的 4 位密码")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(statusMessage.isEmpty ? "验证后切换执行人" : statusMessage)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(isError ? Color.goRed : .secondary)
                }
                Spacer()
                Button {
                    pendingHuman = nil
                    pin = ""
                    statusMessage = ""
                    isError = false
                } label: {
                    Text("换人")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary.opacity(0.14), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            HumanPasscodePad(pin: $pin, accent: Color(hex: human.themeColor)) {
                verifyPendingPasscode()
            }

            if canUseBiometricMemberGate {
                Button {
                    authenticatePendingHumanWithBiometrics(human)
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
        }
        .padding(14)
        .background(Color.primary.opacity(0.075), in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
    }

    private func choose(_ human: Human) {
        UISelectionFeedbackGenerator().selectionChanged()
        guard human.id.uuidString != activeHumanId else {
            dismiss()
            return
        }
        guard appServices.passcodes.hasPasscode(human) else {
            switchTo(human)
            return
        }
        now = Date()
        pendingHuman = human
        pin = ""
        if let seconds = appServices.passcodes.remainingLockoutSeconds(for: human, now: now) {
            isError = true
            statusMessage = "请 \(seconds) 秒后再试"
        } else {
            isError = false
            statusMessage = ""
        }
    }

    private func verifyPendingPasscode() {
        guard let human = pendingHuman else { return }
        now = Date()
        switch HumanPrivacyCommandExecutor(context: modelContext, services: appServices).verifyPasscode(pin, for: human, now: now) {
        case .success, .noPasscode:
            switchTo(human)
        case let .incorrect(remaining):
            pin = ""
            isError = true
            statusMessage = "密码不正确，还可尝试 \(remaining) 次"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case let .locked(until):
            pin = ""
            isError = true
            statusMessage = "尝试过多，请 \(max(1, Int(ceil(until.timeIntervalSince(now))))) 秒后再试"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .invalidFormat:
            pin = ""
            isError = true
            statusMessage = "请输入 4 位数字"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func switchTo(_ human: Human) {
        activeHumanId = human.id.uuidString
        pendingHuman = nil
        pin = ""
        statusMessage = ""
        isError = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSwitched?()
        dismiss()
    }

    private var canUseBiometricMemberGate: Bool {
        enableMemberGateBiometrics && biometricAvailability.isAvailable
    }

    private func authenticatePendingHumanWithBiometrics(_ human: Human) {
        guard !isAuthenticatingBiometrics else { return }
        isAuthenticatingBiometrics = true
        isError = false
        statusMessage = "正在验证 \(biometricAvailability.label)"
        Task { @MainActor in
            let success = await MemberGateBiometricAuthenticator.authenticate(
                reason: "验证后切换到 \(displayName(human))"
            )
            isAuthenticatingBiometrics = false
            if success {
                switchTo(human)
            } else {
                isError = true
                statusMessage = "\(biometricAvailability.label) 未通过，可继续输入密码"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
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
        return name.isEmpty ? "未命名成员" : name
    }
}
