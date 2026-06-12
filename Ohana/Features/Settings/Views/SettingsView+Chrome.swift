//
//  SettingsView+Chrome.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension SettingsView {
    // MARK: - Header
    var settingsHeader: some View {
        HStack(spacing: 12) {
            Text(l.tr(zh: "设置", en: "Settings", de: "Einstellungen"))
                .font(OhanaFont.largeTitle(.black))
                .foregroundStyle(primaryText)
            Spacer()
            Button { closeSettings() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(primaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    func closeSettings() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    // MARK: - Settings Section
    func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        SettingsSectionCard(
            title: title,
            tertiaryText: tertiaryText,
            reduceTransparency: reduceTransparency,
            content: content
        )
    }

    func settingsRow(icon: String, title: String, subtitle: String, iconColor: Color = Color.goPrimary, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(GoMotion.feedback) {
                action()
            }
        } label: {
            HStack(spacing: 12) {
                settingsIcon(icon, color: iconColor)
                Text(title)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Spacer()
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(tertiaryText)
                }
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(tertiaryText.opacity(0.6))
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var performanceToggleRow: some View {
        HStack(spacing: 12) {
            settingsIcon("battery.75percent", color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "省电模式", en: "Power Saving", de: "Energiesparen"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(
                    zh: "减少后台刷新和装饰动效",
                    en: "Reduces background refresh and decorative motion",
                    de: "Reduziert Hintergrundaktualisierung und Deko-Bewegung"
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $powerSavingMode)
                .tint(Color.goPrimary)
                .labelsHidden()
        }
        .frame(minHeight: 44)
        .animation(GoMotion.feedback, value: powerSavingMode)
        .onChange(of: powerSavingMode) { _, _ in
            AppWorkloadPolicy.shared.refresh(reason: "settingsPowerSavingChanged")
        }
    }

    var privacySecuritySection: some View {
        settingsSection(title: l.tr(zh: "隐私与安全", en: "Privacy & Security", de: "Datenschutz & Sicherheit")) {
            appSwitcherSnapshotPrivacyRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            memberGateBiometricRow
        }
    }

    var appSwitcherSnapshotPrivacyRow: some View {
        HStack(spacing: 12) {
            settingsIcon("rectangle.on.rectangle.slash", color: Color.goYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "隐藏 App 切换器预览", en: "Hide app switcher preview", de: "App-Umschalter-Vorschau ausblenden"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(
                    zh: "离开 App 时用遮罩覆盖健康与用药页面",
                    en: "Covers health and medication screens when leaving the app",
                    de: "Deckt Gesundheits- und Medikamentenseiten beim Verlassen ab"
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $hideAppSwitcherSnapshot)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    var memberGateBiometricRow: some View {
        HStack(spacing: 12) {
            settingsIcon(biometricGateAvailability.symbolName, color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "成员门禁使用 \(biometricGateAvailability.label)", en: "Use \(biometricGateAvailability.label) for member gate", de: "\(biometricGateAvailability.label) für Mitgliederschutz nutzen"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(memberGateBiometricSubtitle)
                    .font(OhanaFont.footnote())
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $enableMemberGateBiometrics)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 44)
        .onAppear {
            refreshBiometricGateAvailability()
        }
    }

    var memberGateBiometricSubtitle: String {
        if biometricGateAvailability.isAvailable {
            return l.tr(
                zh: "切换受保护成员时可用生物识别代替输入密码",
                en: "Use biometrics instead of typing the PIN for protected members",
                de: "Biometrie statt PIN beim Wechsel geschützter Mitglieder"
            )
        }
        return l.tr(
            zh: "当前设备不可用时会继续使用 4 位密码",
            en: "Falls back to the 4-digit PIN when biometrics are unavailable",
            de: "Fällt auf die 4-stellige PIN zurück, wenn Biometrie nicht verfügbar ist"
        )
    }

    func refreshBiometricGateAvailability() {
        biometricGateAvailability = MemberGateBiometricAuthenticator.availability()
    }

    func notificationToggleRow(icon: String, iconColor: Color, title: String, group: NotificationPreferenceGroup) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            Text(title)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(primaryText)
            Spacer()
            Toggle("", isOn: Binding(
                get: { NotificationPreferenceStore.isEnabled(group) },
                set: { NotificationPreferenceStore.set($0, for: group) }
            ))
            .tint(accentColor)
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    var petMedicationNotificationPrivacyRow: some View {
        HStack(spacing: 12) {
            settingsIcon("eye.slash.fill", color: Color.goYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "隐藏用药通知细节", en: "Hide medication details", de: "Medikamentendetails ausblenden"))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text(l.tr(
                    zh: "锁屏只显示通用提醒",
                    en: "Lock screen shows a generic reminder",
                    de: "Sperrbildschirm zeigt nur eine allgemeine Erinnerung"
                ))
                .font(OhanaFont.footnote())
                .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $hidePetMedicationNotificationDetails)
                .tint(accentColor)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    func resetApp() {
        do {
            try appServices.appReset.reset(context: modelContext)
            currentActiveHumanId = ""
            withAnimation(GoMotion.page) {
                hasOnboarded = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            appResetErrorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func settingsIcon(_ icon: String, color _: Color) -> some View {
        Image(systemName: icon)
            .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaFunctionalIcon)
            .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
            .contentShape(Rectangle())
    }
}
