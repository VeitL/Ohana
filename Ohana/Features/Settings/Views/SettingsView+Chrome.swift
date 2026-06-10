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
            Text("设置")
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

    func notificationToggleRow(icon: String, iconColor: Color, title: String, key: String) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            Text(title)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(primaryText)
            Spacer()
            Toggle("", isOn: Binding(
                get: { SettingsPreferenceStore.enabledByDefaultBool(forKey: key) },
                set: { SettingsPreferenceStore.set($0, forKey: key) }
            ))
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
