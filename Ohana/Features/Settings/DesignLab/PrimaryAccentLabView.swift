//
//  PrimaryAccentLabView.swift
//  Ohana
//
//  Developer-only comparison surface for the adaptive brand accent.
//

import SwiftUI

#if DEBUG
struct PrimaryAccentLabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(OhanaPrimaryAccentPreferences.lightStorageKey)
    private var lightRawValue = OhanaPrimaryAccentPreferences.defaultLight.rawValue
    @AppStorage(OhanaPrimaryAccentPreferences.darkStorageKey)
    private var darkRawValue = OhanaPrimaryAccentPreferences.defaultDark.rawValue
    @State private var previewAppearance: OhanaPrimaryAccentAppearance = .light

    private var l: L10n { L10n(appLanguage) }
    private var selectedAccent: OhanaResolvedPrimaryAccent {
        accent(for: previewAppearance)
    }

    private var selectedRawValue: String {
        get {
            switch previewAppearance {
            case .light: lightRawValue
            case .dark: darkRawValue
            }
        }
        nonmutating set {
            switch previewAppearance {
            case .light: lightRawValue = newValue
            case .dark: darkRawValue = newValue
            }
        }
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { selectedAccent.color },
            set: { color in
                guard let hex = color.toHex(),
                      let rawValue = OhanaPrimaryAccentPreferences.customStorageRawValue(hex: hex)
                else { return }
                selectedRawValue = rawValue
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                intro
                appearancePicker
                currentCombination
                livePreview
                customColorPicker
                candidateGrid
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(OhanaStaticAppBackground().ignoresSafeArea())
        .navigationTitle(l.tr(
            zh: "主色实验室",
            en: "Primary Accent Lab",
            de: "Primärfarben-Labor",
            es: "Laboratorio de color",
            pt: "Laboratório de cor",
            fr: "Laboratoire de couleur",
            ja: "メインカラー実験室",
            ko: "주 색상 실험실",
            it: "Laboratorio colore"
        ))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: resetDefaults) {
                    Label(
                        l.tr(zh: "恢复默认", en: "Reset", de: "Zurücksetzen", es: "Restablecer", pt: "Redefinir", fr: "Réinitialiser", ja: "リセット", ko: "초기화", it: "Ripristina"),
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .accessibilityIdentifier("primary-accent-reset-action")
            }
        }
        .tint(selectedAccent.color)
        .accessibilityIdentifier("primary-accent-lab-screen")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(l.tr(
                zh: "一屏比较浅色与深色效果",
                en: "Compare light and dark at a glance",
                de: "Hell und Dunkel direkt vergleichen"
            ))
            .font(OhanaFont.title3(.black))
            .foregroundStyle(Color.ohanaPrimaryText)

            Text(l.tr(
                zh: "先选择要编辑的外观，再用预设色或苹果原生取色器调整。两个预览会始终同时显示，选择也会立即应用到本机 Debug 版；Release 构建不会读取这里的选择。",
                en: "Choose which appearance to edit, then use a preset or Apple’s system color picker. Both previews stay visible, and selections apply immediately to this Debug build. Release builds ignore them.",
                de: "Wähle zuerst die zu bearbeitende Darstellung und dann eine Vorlage oder Apples System-Farbwähler. Beide Vorschauen bleiben sichtbar; Release-Builds ignorieren die Auswahl."
            ))
            .font(OhanaFont.footnote())
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appearancePicker: some View {
        Picker(
            l.tr(zh: "正在编辑", en: "Editing", de: "Bearbeiten"),
            selection: $previewAppearance
        ) {
            ForEach(OhanaPrimaryAccentAppearance.allCases) { appearance in
                Text(appearance.title(l)).tag(appearance)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("primary-accent-appearance-picker")
    }

    private var currentCombination: some View {
        HStack(spacing: 10) {
            ForEach(OhanaPrimaryAccentAppearance.allCases) { appearance in
                combinationButton(appearance: appearance, accent: accent(for: appearance))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("primary-accent-current-combination")
    }

    private func combinationButton(
        appearance: OhanaPrimaryAccentAppearance,
        accent: OhanaResolvedPrimaryAccent
    ) -> some View {
        let isEditing = appearance == previewAppearance

        return Button {
            withAnimation(GoMotion.selection) {
                previewAppearance = appearance
            }
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(accent.color)
                    .frame(width: 20, height: 20) // a11y: allow non-interactive swatch inside a 52pt labeled button
                    .overlay {
                        Circle().strokeBorder(Color.ohanaDivider, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(appearance.title(l))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                    Text("#\(accent.primaryHex)")
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Spacer(minLength: 0)

                if isEditing {
                    Image(systemName: "slider.horizontal.3") // a11y: allow decorative icon covered by surrounding labeled control
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(accent.color)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                isEditing ? accent.color.opacity(0.12) : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(isEditing ? accent.color : Color.ohanaDivider, lineWidth: isEditing ? 2 : 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(
            zh: "编辑\(appearance.title(l))模式，当前为\(accent.title(l))，#\(accent.primaryHex)",
            en: "Edit \(appearance.title(l)) appearance, currently \(accent.title(l)), #\(accent.primaryHex)",
            de: "\(appearance.title(l)) bearbeiten, aktuell \(accent.title(l)), #\(accent.primaryHex)"
        ))
        .accessibilityValue(isEditing
            ? l.tr(zh: "正在编辑", en: "Editing", de: "Wird bearbeitet")
            : l.tr(zh: "未编辑", en: "Not editing", de: "Nicht ausgewählt"))
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(zh: "双模式实时预览", en: "Live dual-appearance preview", de: "Live-Vorschau für beide Modi"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "按钮、图标、开关、进度、标签与图表会随各自模式的主色更新。",
                    en: "Buttons, icons, toggles, progress, tags, and charts use each appearance’s accent.",
                    de: "Tasten, Symbole, Schalter, Fortschritt, Tags und Diagramme verwenden den jeweiligen Akzent."
                ))
                .font(OhanaFont.caption())
                .foregroundStyle(Color.ohanaSecondaryText)
            }

            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 12) {
                    appearancePreview(for: .light)
                    appearancePreview(for: .dark)
                }
            } else {
                VStack(spacing: 12) {
                    appearancePreview(for: .light)
                    appearancePreview(for: .dark)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("primary-accent-live-preview")
    }

    private func appearancePreview(for appearance: OhanaPrimaryAccentAppearance) -> some View {
        PrimaryAccentAppearancePreview(
            appearance: appearance,
            accent: accent(for: appearance)
        )
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if appearance == previewAppearance {
                Text(l.tr(zh: "正在编辑", en: "EDITING", de: "AKTIV"))
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(accent(for: appearance).actionTextColor)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(accent(for: appearance).color, in: Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityIdentifier("primary-accent-\(appearance.rawValue)-preview")
    }

    private var customColorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(
                zh: "任意颜色",
                en: "Any color",
                de: "Beliebige Farbe"
            ))
            .font(OhanaFont.headline(.black))
            .foregroundStyle(Color.ohanaPrimaryText)

            ColorPicker(selection: customColor, supportsOpacity: false) {
                HStack(spacing: 11) {
                    Image(systemName: "eyedropper.halffull") // a11y: allow decorative icon covered by the labeled ColorPicker
                        .font(OhanaFont.adaptive(size: 17, weight: .bold))
                        .foregroundStyle(selectedAccent.color)
                        .frame(width: 36, height: 36) // a11y: allow glyph inside the full-width native ColorPicker target
                        .background(selectedAccent.color.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(
                            zh: "苹果原生取色器",
                            en: "Apple system color picker",
                            de: "Apple System-Farbwähler"
                        ))
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)

                        Text("\(previewAppearance.title(l)) · #\(selectedAccent.primaryHex)")
                            .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 58)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(selectedAccent.isCustom ? selectedAccent.color : Color.ohanaDivider, lineWidth: selectedAccent.isCustom ? 2 : 1)
            }
            .accessibilityLabel(l.tr(
                zh: "为\(previewAppearance.title(l))模式选择任意主色",
                en: "Choose any accent for \(previewAppearance.title(l)) appearance",
                de: "Beliebigen Akzent für \(previewAppearance.title(l)) wählen"
            ))
            .accessibilityValue("#\(selectedAccent.primaryHex)")
            .accessibilityIdentifier("primary-accent-system-color-picker")

            Text(l.tr(
                zh: "不保存透明度；浅阶、深阶和按钮文字颜色会自动生成。",
                en: "Opacity isn’t stored; lighter, darker, and button-text colors are generated automatically.",
                de: "Deckkraft wird nicht gespeichert; helle, dunkle und Textfarben werden automatisch erzeugt."
            ))
            .font(OhanaFont.caption())
            .foregroundStyle(Color.ohanaTertiaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var candidateGrid: some View {
        let appearanceTitle = previewAppearance.title(l)

        return VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text(l.tr(
                    zh: "\(appearanceTitle)模式推荐色",
                    en: "Presets for \(appearanceTitle) appearance",
                    de: "Vorlagen für \(appearanceTitle)"
                ))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

                Text(l.tr(
                    zh: "每个色块都同时展示在浅色与深色表面上的观感。",
                    en: "Each swatch is shown on both light and dark surfaces.",
                    de: "Jede Farbe wird auf einer hellen und dunklen Fläche gezeigt."
                ))
                .font(OhanaFont.caption())
                .foregroundStyle(Color.ohanaSecondaryText)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                ForEach(OhanaPrimaryAccentCandidate.allCases) { candidate in
                    candidateButton(candidate)
                }
            }
        }
    }

    private func candidateButton(_ candidate: OhanaPrimaryAccentCandidate) -> some View {
        let isSelected = selectedAccent.preset == candidate

        return Button {
            withAnimation(GoMotion.selection) {
                selectedRawValue = candidate.rawValue
            }
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    candidateSurfacePreview(candidate, appearance: .light)
                    candidateSurfacePreview(candidate, appearance: .dark)
                }
                .frame(width: 58, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .strokeBorder(Color.ohanaDivider, lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title(l))
                        .font(OhanaFont.subheadline(.bold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("#\(candidate.primaryHex)")
                        .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by button accessibilityValue
                        .font(OhanaFont.adaptive(size: 17, weight: .bold))
                        .foregroundStyle(candidate.color)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                isSelected ? candidate.color.opacity(0.12) : Color.ohanaControlFill.opacity(0.72),
                in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(isSelected ? candidate.color : Color.ohanaDivider, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(candidate.title(l)), #\(candidate.primaryHex)")
        .accessibilityHint(l.tr(
            zh: "包含浅色和深色表面预览",
            en: "Includes light and dark surface previews",
            de: "Enthält helle und dunkle Vorschauen"
        ))
        .accessibilityValue(isSelected
            ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
            : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt"))
        .accessibilityIdentifier("primary-accent-candidate-\(candidate.rawValue)")
    }

    private func candidateSurfacePreview(
        _ candidate: OhanaPrimaryAccentCandidate,
        appearance: OhanaPrimaryAccentAppearance
    ) -> some View {
        ZStack {
            Color(uiColor: .systemBackground)
            Circle()
                .fill(candidate.color)
                .frame(width: 22, height: 22) // a11y: allow non-interactive swatch inside a 62pt labeled button
                .overlay {
                    Image(systemName: appearance == .light ? "sun.max.fill" : "moon.fill")
                        .font(OhanaFont.adaptive(size: 8, weight: .black))
                        .foregroundStyle(candidate.actionTextColor)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, appearance.colorScheme)
        .accessibilityHidden(true)
    }

    private func accent(for appearance: OhanaPrimaryAccentAppearance) -> OhanaResolvedPrimaryAccent {
        OhanaPrimaryAccentPreferences.resolvedAccent(
            for: appearance,
            lightRawValue: lightRawValue,
            darkRawValue: darkRawValue,
            allowsDeveloperOverride: true
        )
    }

    private func resetDefaults() {
        withAnimation(GoMotion.selection) {
            lightRawValue = OhanaPrimaryAccentPreferences.defaultLight.rawValue
            darkRawValue = OhanaPrimaryAccentPreferences.defaultDark.rawValue
        }
    }
}

private struct PrimaryAccentAppearancePreview: View {
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var isReminderEnabled = true

    let appearance: OhanaPrimaryAccentAppearance
    let accent: OhanaResolvedPrimaryAccent

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            toneScale
            primaryAction
            controls
            progress
            chartAndStatus
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaDivider, lineWidth: 1)
        }
        .environment(\.colorScheme, appearance.colorScheme)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "leaf.fill") // a11y: allow decorative icon next to the preview title
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(accent.actionTextColor)
                .frame(width: 44, height: 44)
                .background(accent.color, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "家庭今日", en: "Family today", de: "Familie heute"))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(appearance.title(l)) · \(accent.title(l)) · #\(accent.primaryHex)")
                    .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)

            Image(systemName: "bell.badge.fill") // a11y: allow meaningful icon with accessibilityLabel below
                .font(OhanaFont.adaptive(size: 18, weight: .bold))
                .foregroundStyle(accent.color)
                .accessibilityLabel(l.tr(zh: "提醒", en: "Reminders", de: "Erinnerungen"))
        }
    }

    private var toneScale: some View {
        HStack(spacing: 7) {
            toneSwatch(color: accent.lighterColor, label: l.tr(zh: "浅阶", en: "Light", de: "Hell"))
            toneSwatch(color: accent.color, label: l.tr(zh: "主色", en: "Main", de: "Primär"))
            toneSwatch(color: accent.darkerColor, label: l.tr(zh: "深阶", en: "Dark", de: "Dunkel"))
        }
    }

    private func toneSwatch(color: Color, label: String) -> some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                .fill(color)
                .frame(height: 26)
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryAction: some View {
        Button {} label: {
            HStack {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by button label
                    .accessibilityHidden(true)
                Text(l.tr(
                    zh: "完成今日打卡",
                    en: "Complete today’s check-in",
                    de: "Heutigen Check-in abschließen"
                ))
                Spacer(minLength: 4)
                Image(systemName: "arrow.right") // a11y: allow decorative icon covered by button label
                    .accessibilityHidden(true)
            }
            .font(OhanaFont.body(.bold))
            .foregroundStyle(accent.actionTextColor)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(accent.color, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {} label: {
                Label(l.tr(zh: "查看记录", en: "View log", de: "Protokoll"), systemImage: "list.bullet")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(accent.color)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                            .strokeBorder(accent.color.opacity(0.42), lineWidth: 1)
                    }
            }
            .buttonStyle(ScaleButtonStyle())

            Toggle(isOn: $isReminderEnabled) {
                Text(l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .toggleStyle(.switch)
            .tint(accent.color)
            .fixedSize()
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(l.tr(zh: "本周照护进度", en: "Weekly care progress", de: "Wöchentliche Pflege"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("68%")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(accent.color)
            }
            ProgressView(value: 0.68)
                .tint(accent.color)
                .accessibilityValue("68%")
        }
    }

    private var chartAndStatus: some View {
        HStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array([0.38, 0.72, 0.54, 0.92, 0.66].enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                        .fill(index == 3 ? accent.color : accent.color.opacity(0.28))
                        .frame(width: 10, height: 34 * CGFloat(value))
                }
            }
            .frame(height: 34, alignment: .bottom)
            .accessibilityElement()
            .accessibilityLabel(l.tr(zh: "五日照护趋势", en: "Five-day care trend", de: "Fünf-Tage-Pflegetrend"))

            VStack(alignment: .leading, spacing: 5) {
                Label(l.tr(zh: "状态良好", en: "Doing well", de: "Alles gut"), systemImage: "sparkles")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(accent.color)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 26)
                    .background(accent.color.opacity(0.12), in: Capsule())

                Text(l.tr(zh: "主色也用于数据高亮", en: "Accent highlights data", de: "Akzent hebt Daten hervor"))
                    .font(OhanaFont.caption2(.medium))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }
}
#endif
