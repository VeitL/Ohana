//
//  SettingsView+MainSections.swift
//  Ohana
//

import SwiftUI

extension SettingsView {
    @ViewBuilder
    var settingsBodySections: some View {
        AnyView(settingsHeader)
        AnyView(settingsDataSections)
        AnyView(settingsDeferredHeavySections)
        AnyView(settingsPreferencesSection)
        if isLanguageCommitInFlight {
            AnyView(settingsLanguageCommitPlaceholderSection)
        } else {
            AnyView(privacySecuritySection)
            AnyView(settingsNotificationsSection)
            AnyView(backupSection)
            AnyView(settingsAboutSection)
            AnyView(settingsResetSection)
        }
        Spacer(minLength: 40)
    }

    @ViewBuilder
    var settingsDeferredHeavySections: some View {
        if !isLanguageCommitInFlight {
            if SettingsDebugTools.isVisible {
                settingsDebugSection
            }
            if OnlineFeatureGate.allows(.onlineCollaboration) {
                householdSyncSection
            }
        }
    }

    var settingsPreferencesSection: some View {
        settingsSection(title: l.preferences) {
            settingsCountryRegionRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            settingsLanguageRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            settingsMeasurementUnitsRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            settingsCurrencyRow
            settingsAppearanceRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            settingsBackgroundRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            performanceToggleRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            reducedVisualEffectsToggleRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            settingsReplayOnboardingRow
        }
    }

    var settingsCountryRegionRow: some View {
        HStack(spacing: 12) {
            settingsIcon("mappin.and.ellipse", color: Color.goPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.countryRegion)
                    .font(OhanaFont.body(.semibold))
                Text(l.countryDefaultsHint)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Menu {
                ForEach(AppCountry.supported) { country in
                    Button {
                        applyCountryDefaults(country)
                    } label: {
                        Label(
                            country.title(appLanguage),
                            systemImage: country.code == selectedCountry.code ? "checkmark" : "flag"
                        )
                    }
                }
            } label: {
                menuValueLabel(selectedCountry.title(appLanguage))
            }
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 44)
    }

    var settingsLanguageRow: some View {
        HStack {
            settingsIcon("globe", color: Color.goPrimary)
            Text(l.language)
                .font(OhanaFont.body(.semibold))
            Spacer()
            Picker("", selection: $languageSelectionCode) {
                ForEach(AppLanguage.supported) { language in
                    Text(language.displayName).tag(language.code)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings-language-picker")
            .disabled(isLanguageCommitInFlight)
            .opacity(isLanguageCommitInFlight ? 0.56 : 1)
            .onChange(of: languageSelectionCode) { _, newValue in
                scheduleLanguageCommit(newValue)
            }
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 44)
    }

    var settingsLanguageCommitPlaceholderSection: some View {
        settingsSection(title: l.tr(zh: "正在更新语言", en: "Updating Language", de: "Sprache wird aktualisiert")) {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(Color.goPrimary)
                    .scaleEffect(0.82)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(
                        zh: "正在更新界面文字",
                        en: "Updating interface text",
                        de: "Oberflächentexte werden aktualisiert"
                    ))
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                    Text(l.tr(
                        zh: "马上就好。",
                        en: "Almost done.",
                        de: "Fast fertig."
                    ))
                    .font(OhanaFont.footnote())
                    .foregroundStyle(tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 54)
            .accessibilityIdentifier("settings-language-commit-placeholder")
        }
    }

    var settingsMeasurementUnitsRow: some View {
        HStack(spacing: 12) {
            settingsIcon(selectedMeasurementSystem.systemIconName, color: Color.goTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.measurementUnits)
                    .font(OhanaFont.body(.semibold))
                Text(l.measurementUnitsHint)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Menu {
                ForEach(AppMeasurementSystem.supported) { unit in
                    Button {
                        appMeasurementSystem = unit.code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(
                            unit.title(appLanguage),
                            systemImage: unit.code == selectedMeasurementSystem.code ? "checkmark" : unit.systemIconName
                        )
                    }
                }
            } label: {
                menuValueLabel(selectedMeasurementSystem.shortLabel)
            }
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 44)
    }

    var settingsCurrencyRow: some View {
        HStack {
            settingsIcon(selectedCurrency.systemIconName, color: Color.goYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.currency)
                    .font(OhanaFont.body(.semibold))
                Text(l.currencyDisplayOnlyHint)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Menu {
                ForEach(AppCurrency.supported) { currency in
                    Button {
                        appCurrency = currency.code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(
                            currency.displayName,
                            systemImage: currency.code == selectedCurrency.code ? "checkmark" : currency.systemIconName
                        )
                    }
                }
            } label: {
                menuValueLabel(selectedCurrency.displayName)
            }
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 44)
    }

    var settingsAppearanceRow: some View {
        HStack {
            settingsIcon("circle.lefthalf.filled", color: accentColor)
            Text(l.appearance)
                .font(OhanaFont.body(.semibold))
            Spacer()
            Picker("", selection: $appThemePreference) {
                Text(l.themeSystem).tag("system")
                Text(l.themeLight).tag("light")
                Text(l.themeDark).tag("dark")
            }
            .pickerStyle(.menu)
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 44)
        .animation(GoMotion.feedback, value: appThemePreference)
    }

    var settingsBackgroundRow: some View {
        settingsRow(
            icon: "photo.on.rectangle.angled",
            title: l.tr(zh: "背景", en: "Background", de: "Hintergrund"),
            subtitle: currentBackgroundStyle.localizedName(appLanguage),
            iconColor: Color.goBlue
        ) {
            showingBackgroundPicker = true
        }
    }

    var settingsReplayOnboardingRow: some View {
        settingsRow(icon: "sparkles.tv", title: l.replayOnboarding, subtitle: l.replayOnboardingSubtitle) {
            showingOnboardingReplay = true
        }
    }

    var settingsNotificationsSection: some View {
        settingsSection(title: l.notifications) {
            settingsNotificationPermissionRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            routineNotificationsToggleRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            petMedicationNotificationPrivacyRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            advancedNotificationSettingsDisclosure
        }
    }

    var settingsNotificationPermissionRow: some View {
        settingsRow(icon: "bell.badge", title: l.notificationPermission, subtitle: l.manageNotification) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    var settingsAboutSection: some View {
        settingsSection(title: l.tr(zh: "关于", en: "About", de: "Über")) {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "info.circle",
                    title: l.tr(zh: "版本", en: "Version", de: "Version"),
                    subtitle: "v4.5.0"
                ) {}
                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                settingsRow(
                    icon: "star.fill",
                    title: l.tr(zh: "评价 App", en: "Rate App", de: "App bewerten"),
                    subtitle: ""
                ) {
                    if let url = URL(string: "https://apps.apple.com/app/id6742117937?action=write-review") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    var settingsResetSection: some View {
        settingsSection(title: l.tr(zh: "数据", en: "Data", de: "Daten")) {
            VStack(spacing: 0) {
                settingsRow(
                    icon: "arrow.counterclockwise.circle.fill",
                    title: l.tr(zh: "重置 App", en: "Reset App", de: "App zurucksetzen"),
                    subtitle: l.tr(
                        zh: "删除数据并回到引导页",
                        en: "Delete data and restart onboarding",
                        de: "Daten loschen und Onboarding starten"
                    ),
                    iconColor: Color.goRed
                ) {
                    showingAppResetAlert = true
                }
            }
        }
    }
}
