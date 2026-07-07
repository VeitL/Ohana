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
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

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

    private var l: L10n { L10n(appLanguage) }

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
                Text(l.tr(zh: "切换执行人", en: "Switch executor", de: "Ausführende Person wechseln"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "后续打卡会记录到当前账户", en: "Future check-ins will use this account", de: "Künftige Check-ins laufen über dieses Konto"))
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
                    Text(executorSwitchSubtitle(for: human, isActive: isActive))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                } else if HumanLocalPrivacyPolicy.isEnabled,
                          appServices.passcodes.hasPasscode(human) {
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
                    Text(l.tr(zh: "输入 \(displayName(human)) 的 4 位密码", en: "Enter \(displayName(human))'s 4-digit PIN", de: "4-stellige PIN für \(displayName(human)) eingeben"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(statusMessage.isEmpty ? l.tr(zh: "验证后切换执行人", en: "Verify to switch executor", de: "Zum Wechseln verifizieren") : statusMessage)
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
                    Text(l.tr(zh: "换人", en: "Choose another", de: "Andere wählen"))
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
                        isAuthenticatingBiometrics
                            ? l.tr(zh: "正在验证 \(biometricAvailability.label)", en: "Verifying with \(biometricAvailability.label)", de: "Verifizierung mit \(biometricAvailability.label)")
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
        guard HumanLocalPrivacyPolicy.isEnabled else {
            switchTo(human)
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
        case .success, .noPasscode:
            switchTo(human)
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
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .memberInactive:
            pin = ""
            isError = true
            statusMessage = l.tr(zh: "纪念成员不能切换为执行人", en: "Memorial members cannot become executors", de: "Gedenkmitglieder können nicht ausführend sein")
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
        HumanLocalPrivacyPolicy.isEnabled && enableMemberGateBiometrics && biometricAvailability.isAvailable
    }

    private func authenticatePendingHumanWithBiometrics(_ human: Human) {
        guard !isAuthenticatingBiometrics else { return }
        isAuthenticatingBiometrics = true
        isError = false
        statusMessage = l.tr(zh: "正在验证 \(biometricAvailability.label)", en: "Verifying with \(biometricAvailability.label)", de: "Verifizierung mit \(biometricAvailability.label)")
        Task { @MainActor in
            let success = await MemberGateBiometricAuthenticator.authenticate(
                reason: l.tr(zh: "验证后切换到 \(displayName(human))", en: "Verify to switch to \(displayName(human))", de: "Verifizieren, um zu \(displayName(human)) zu wechseln")
            )
            isAuthenticatingBiometrics = false
            if success {
                switchTo(human)
            } else {
                isError = true
                statusMessage = l.tr(zh: "\(biometricAvailability.label) 未通过，可继续输入密码", en: "\(biometricAvailability.label) did not pass. You can still enter the PIN.", de: "\(biometricAvailability.label) nicht bestätigt. Du kannst die PIN eingeben.")
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
        return name.isEmpty ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied") : name
    }

    private func executorSwitchSubtitle(for human: Human, isActive: Bool) -> String {
        if isActive {
            return l.tr(zh: "当前执行人", en: "Current executor", de: "Aktuell ausführend")
        }
        guard HumanLocalPrivacyPolicy.isEnabled,
              appServices.passcodes.hasPasscode(human) else {
            return l.tr(zh: "可直接切换", en: "Can switch directly", de: "Direkt wechselbar")
        }
        return l.tr(zh: "需要 4 位密码", en: "4-digit PIN required", de: "4-stellige PIN nötig")
    }
}
