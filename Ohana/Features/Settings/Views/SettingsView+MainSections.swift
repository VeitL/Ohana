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
        if OnlineFeatureGate.allows(.onlineCollaboration) {
            AnyView(householdSyncSection)
        }
        AnyView(settingsPreferencesSection)
        AnyView(privacySecuritySection)
        AnyView(settingsNotificationsSection)
        AnyView(backupSection)
        AnyView(settingsAboutSection)
        AnyView(settingsResetSection)
        Spacer(minLength: 40)
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
            Picker("", selection: $appLanguage) {
                ForEach(AppLanguage.supported) { language in
                    Text(language.displayName).tag(language.code)
                }
            }
            .pickerStyle(.menu)
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 44)
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
            notificationToggleRow(
                icon: "pills.fill",
                iconColor: Color(hex: "FF5A00"),
                title: l.tr(zh: "用药提醒", en: "Medication reminders", de: "Medikamentenerinnerungen"),
                group: .medication
            )
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            petMedicationNotificationPrivacyRow
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            notificationToggleRow(
                icon: "fork.knife",
                iconColor: Color.goPrimary,
                title: l.tr(zh: "喂食提醒", en: "Feeding reminders", de: "Fütterungserinnerungen"),
                group: .feeding
            )
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            notificationToggleRow(
                icon: "bubbles.and.sparkles.fill",
                iconColor: Color.goTeal,
                title: l.tr(zh: "护理提醒", en: "Care reminders", de: "Pflegeerinnerungen"),
                group: .hygiene
            )
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            notificationToggleRow(
                icon: "leaf.fill",
                iconColor: Color(hex: "4CAF50"),
                title: l.tr(zh: "植物护理提醒", en: "Plant care reminders", de: "Pflanzenpflege-Erinnerungen"),
                group: .plantCare
            )
            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
            notificationToggleRow(
                icon: "checkmark.seal.fill",
                iconColor: Color.goYellow,
                title: l.tr(zh: "打卡提醒", en: "Check-in reminders", de: "Check-in-Erinnerungen"),
                group: .checkIn
            )
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
