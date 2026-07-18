import SwiftUI

enum SettingsDestination: String, CaseIterable, Hashable {
    case regionAndLanguage
    case appearanceAndPerformance
    case notifications
    case privacyAndSecurity
    case dataAndBackup
    case about

    func title(_ l: L10n) -> String {
        switch self {
        case .regionAndLanguage:
            l.tr(zh: "地区与语言", en: "Region & Language", de: "Region & Sprache")
        case .appearanceAndPerformance:
            l.tr(zh: "外观与性能", en: "Appearance & Performance", de: "Darstellung & Leistung")
        case .notifications:
            l.notifications
        case .privacyAndSecurity:
            l.tr(zh: "隐私与安全", en: "Privacy & Security", de: "Datenschutz & Sicherheit")
        case .dataAndBackup:
            l.tr(zh: "数据与备份", en: "Data & Backup", de: "Daten & Backup")
        case .about:
            l.tr(zh: "关于", en: "About", de: "Über")
        }
    }

    func subtitle(_ l: L10n) -> String {
        switch self {
        case .regionAndLanguage:
            l.tr(zh: "国家、语言、单位与货币", en: "Country, language, units, and currency", de: "Land, Sprache, Einheiten und Währung")
        case .appearanceAndPerformance:
            l.tr(zh: "主题、背景与省电模式", en: "Theme, background, and power saving", de: "Design, Hintergrund und Energiesparen")
        case .notifications:
            l.tr(zh: "系统权限、常规与分类提醒", en: "System access, routine, and category reminders", de: "Systemzugriff und Erinnerungen")
        case .privacyAndSecurity:
            l.tr(zh: "切换器遮罩与成员生物识别", en: "Switcher masking and member biometrics", de: "Vorschau-Schutz und Biometrie")
        case .dataAndBackup:
            l.tr(zh: "导出、恢复、自动备份与重置", en: "Export, restore, automatic backup, and reset", de: "Export, Wiederherstellung und Zurücksetzen")
        case .about:
            l.tr(zh: "版本、评价、隐私政策与支持", en: "Version, rating, privacy policy, and support", de: "Version, Bewertung, Datenschutz und Support")
        }
    }

    var icon: String {
        switch self {
        case .regionAndLanguage: "globe.americas.fill"
        case .appearanceAndPerformance: "circle.lefthalf.filled"
        case .notifications: "bell.badge.fill"
        case .privacyAndSecurity: "hand.raised.fill"
        case .dataAndBackup: "externaldrive.fill.badge.icloud"
        case .about: "info.circle.fill"
        }
    }

    var accessibilityIdentifier: String {
        "settings-destination-\(rawValue)"
    }
}

struct SettingsRegionLanguagePage: View {
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency = AppCurrency.fallbackCode
    @State private var languageSelectionCode = AppLanguage.code
    @State private var languageCommitTask: Task<Void, Never>?
    @State private var isLanguageCommitInFlight = false

    let appLanguage: String
    let onCommitLanguage: (String) -> Void
    let onClose: () -> Void

    private var l: L10n { L10n(appLanguage) }
    private var selectedCountry: AppCountry.Option { AppCountry.option(for: appCountry) }
    private var selectedMeasurementSystem: AppMeasurementSystem.Option {
        AppMeasurementSystem.option(for: appMeasurementSystem)
    }
    private var selectedCurrency: AppCurrency.Option {
        AppCurrency.supported.first { $0.code == AppCurrency.normalize(appCurrency) } ?? AppCurrency.supported[0]
    }

    var body: some View {
        Form {
            Section {
                countryRow
                languageRow
                measurementRow
                currencyRow
            }

            if isLanguageCommitInFlight {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(l.tr(zh: "正在更新界面文字", en: "Updating interface text", de: "Oberflächentexte werden aktualisiert"))
                            .font(OhanaFont.body(.semibold))
                    }
                    .accessibilityIdentifier("settings-language-commit-placeholder")
                }
            }
        }
        .settingsDestinationChrome(title: SettingsDestination.regionAndLanguage.title(l), closeLabel: l.tr(zh: "关闭", en: "Close", de: "Schließen"), onClose: onClose)
        .onAppear {
            syncStoredDefaultsIfNeeded()
            languageSelectionCode = AppLanguage.normalize(appLanguage)
        }
        .onDisappear { commitPendingLanguageChangeBeforeDismissal() }
        .onChange(of: appLanguage) { _, newValue in
            let normalized = AppLanguage.normalize(newValue)
            if languageSelectionCode != normalized { languageSelectionCode = normalized }
        }
    }

    private var countryRow: some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: "mappin.and.ellipse")
            VStack(alignment: .leading, spacing: 2) {
                Text(l.countryRegion).font(OhanaFont.body(.semibold))
                Text(l.countryDefaultsHint)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Menu {
                ForEach(AppCountry.supported) { country in
                    Button {
                        applyCountryDefaults(country)
                    } label: {
                        Label(country.title(appLanguage), systemImage: country.code == selectedCountry.code ? "checkmark" : "flag")
                    }
                }
            } label: {
                SettingsMenuValueLabel(text: selectedCountry.title(appLanguage))
            }
        }
        .frame(minHeight: 44)
    }

    private var languageRow: some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: "globe")
            Text(l.language).font(OhanaFont.body(.semibold))
            Spacer()
            Picker("", selection: $languageSelectionCode) {
                ForEach(AppLanguage.supported) { language in
                    Text(language.displayName).tag(language.code)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings-language-picker")
            .disabled(isLanguageCommitInFlight)
            .onChange(of: languageSelectionCode) { _, newValue in
                scheduleLanguageCommit(newValue)
            }
        }
        .frame(minHeight: 44)
    }

    private var measurementRow: some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: selectedMeasurementSystem.systemIconName)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.measurementUnits).font(OhanaFont.body(.semibold))
                Text(l.measurementUnitsHint)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Spacer()
            Menu {
                ForEach(AppMeasurementSystem.supported) { unit in
                    Button {
                        appMeasurementSystem = unit.code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(unit.title(appLanguage), systemImage: unit.code == selectedMeasurementSystem.code ? "checkmark" : unit.systemIconName)
                    }
                }
            } label: {
                SettingsMenuValueLabel(text: selectedMeasurementSystem.shortLabel)
            }
        }
        .frame(minHeight: 44)
    }

    private var currencyRow: some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: selectedCurrency.systemIconName)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.currency).font(OhanaFont.body(.semibold))
                Text(l.currencyDisplayOnlyHint)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Spacer()
            Menu {
                ForEach(AppCurrency.supported) { currency in
                    Button {
                        appCurrency = currency.code
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(currency.displayName, systemImage: currency.code == selectedCurrency.code ? "checkmark" : currency.systemIconName)
                    }
                }
            } label: {
                SettingsMenuValueLabel(text: selectedCurrency.displayName)
            }
        }
        .frame(minHeight: 44)
    }

    private func applyCountryDefaults(_ country: AppCountry.Option) {
        appCountry = country.code
        appMeasurementSystem = AppMeasurementSystem.normalize(country.defaultMeasurementSystemCode)
        appCurrency = AppCurrency.normalize(country.defaultCurrencyCode)
        languageSelectionCode = AppLanguage.normalize(country.defaultLanguageCode)
        scheduleLanguageCommit(languageSelectionCode, emitFeedback: false)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func syncStoredDefaultsIfNeeded() {
        AppCountry.ensureInitialized()
        appCountry = AppCountry.code
        appMeasurementSystem = AppMeasurementSystem.code
        appCurrency = AppCurrency.code
        let normalizedLanguage = AppLanguage.code
        if AppLanguage.normalize(appLanguage) != normalizedLanguage {
            languageSelectionCode = normalizedLanguage
            scheduleLanguageCommit(normalizedLanguage, emitFeedback: false)
        }
    }

    private func scheduleLanguageCommit(_ rawLanguageCode: String, emitFeedback: Bool = true) {
        let normalized = AppLanguage.normalize(rawLanguageCode)
        guard normalized != AppLanguage.normalize(appLanguage) else {
            languageCommitTask?.cancel()
            languageCommitTask = nil
            isLanguageCommitInFlight = false
            return
        }
        isLanguageCommitInFlight = true
        languageCommitTask?.cancel()
        languageCommitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 96) {
            commitLanguageChange(normalized, emitFeedback: emitFeedback)
        }
    }

    private func commitLanguageChange(_ languageCode: String, emitFeedback: Bool) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { onCommitLanguage(AppLanguage.normalize(languageCode)) }
        languageCommitTask = nil
        isLanguageCommitInFlight = false
        if emitFeedback { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func commitPendingLanguageChangeBeforeDismissal() {
        languageCommitTask?.cancel()
        languageCommitTask = nil
        let normalized = AppLanguage.normalize(languageSelectionCode)
        guard AppLanguage.normalize(appLanguage) != normalized else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { onCommitLanguage(normalized) }
    }
}

struct SettingsAppearancePerformancePage: View {
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("appThemePreference") private var appThemePreference = "dark"
    @AppStorage("appBackgroundStyle") private var appBackgroundStyle = AppBackgroundStyle.goIsland.rawValue
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @Environment(\.hasSupporterPackEntitlement) private var hasSupporterPack
    @State private var showingBackgroundPicker = false

    let onClose: () -> Void

    private var l: L10n { L10n(appLanguage) }
    private var backgroundStyle: AppBackgroundStyle {
        SupporterPackAccessPolicy.resolvedBackgroundStyle(
            requested: AppBackgroundStyle(rawValue: appBackgroundStyle) ?? .goIsland,
            hasSupporterPack: hasSupporterPack
        )
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    SettingsDestinationIcon(systemName: "circle.lefthalf.filled")
                    Text(l.appearance).font(OhanaFont.body(.semibold))
                    Spacer()
                    Picker("", selection: $appThemePreference) {
                        Text(l.themeSystem).tag("system")
                        Text(l.themeLight).tag("light")
                        Text(l.themeDark).tag("dark")
                    }
                    .pickerStyle(.menu)
                }

                Button {
                    showingBackgroundPicker = true
                } label: {
                    SettingsNavigationLabel(
                        icon: "photo.on.rectangle.angled",
                        title: l.tr(zh: "背景", en: "Background", de: "Hintergrund"),
                        subtitle: backgroundStyle.localizedName(appLanguage)
                    )
                }

                HStack(spacing: 12) {
                    SettingsDestinationIcon(systemName: "battery.75percent")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "省电模式", en: "Power Saving", de: "Energiesparen"))
                            .font(OhanaFont.body(.semibold))
                        Text(l.tr(zh: "减少后台刷新和装饰动效", en: "Reduces background refresh and decorative motion", de: "Reduziert Hintergrundaktualisierung und Deko-Bewegung"))
                            .font(OhanaFont.footnote())
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $powerSavingMode).labelsHidden().tint(Color.goPrimary)
                }
                .onChange(of: powerSavingMode) { _, _ in
                    AppWorkloadPolicy.shared.refresh(reason: "settingsPowerSavingChanged")
                }
            }
        }
        .settingsDestinationChrome(title: SettingsDestination.appearanceAndPerformance.title(l), closeLabel: l.tr(zh: "关闭", en: "Close", de: "Schließen"), onClose: onClose)
        .sheet(isPresented: $showingBackgroundPicker) {
            AppBackgroundPickerSheet().ohanaSheetPagePresentation()
        }
    }
}

struct SettingsPrivacySecurityPage: View {
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage(AppPrivacySnapshotProtectionStore.hideSnapshotKey) private var hideAppSwitcherSnapshot = AppPrivacySnapshotProtectionStore.defaultHideSnapshot
    @AppStorage(MemberGateBiometricAuthStore.enabledKey) private var enableMemberGateBiometrics = MemberGateBiometricAuthStore.defaultEnabled
    @State private var biometricGateAvailability = MemberGateBiometricAvailability.unavailable

    let onClose: () -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    SettingsDestinationIcon(systemName: "rectangle.on.rectangle.slash")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "隐藏 App 切换器预览", en: "Hide app switcher preview", de: "App-Umschalter-Vorschau ausblenden"))
                            .font(OhanaFont.body(.semibold))
                        Text(l.tr(zh: "离开 App 时用遮罩覆盖健康与用药页面", en: "Covers health and medication screens when leaving the app", de: "Deckt Gesundheits- und Medikamentenseiten beim Verlassen ab"))
                            .font(OhanaFont.footnote())
                            .foregroundStyle(Color.ohanaTertiaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $hideAppSwitcherSnapshot).labelsHidden().tint(Color.goPrimary)
                }

                if HumanLocalPrivacyPolicy.isEnabled {
                    HStack(spacing: 12) {
                        SettingsDestinationIcon(systemName: biometricGateAvailability.symbolName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.tr(zh: "成员门禁使用 \(biometricGateAvailability.label)", en: "Use \(biometricGateAvailability.label) for member gate", de: "\(biometricGateAvailability.label) für Mitgliederschutz nutzen"))
                                .font(OhanaFont.body(.semibold))
                            Text(biometricSubtitle)
                                .font(OhanaFont.footnote())
                                .foregroundStyle(Color.ohanaTertiaryText)
                        }
                        Spacer()
                        Toggle("", isOn: $enableMemberGateBiometrics).labelsHidden().tint(Color.goPrimary)
                    }
                }
            }
        }
        .settingsDestinationChrome(title: SettingsDestination.privacyAndSecurity.title(l), closeLabel: l.tr(zh: "关闭", en: "Close", de: "Schließen"), onClose: onClose)
        .onAppear { biometricGateAvailability = MemberGateBiometricAuthenticator.availability() }
    }

    private var biometricSubtitle: String {
        biometricGateAvailability.isAvailable
            ? l.tr(zh: "切换受保护成员时可用生物识别代替输入密码", en: "Use biometrics instead of typing the PIN for protected members", de: "Biometrie statt PIN beim Wechsel geschützter Mitglieder")
            : l.tr(zh: "当前设备不可用时会继续使用 4 位密码", en: "Falls back to the 4-digit PIN when biometrics are unavailable", de: "Fällt auf die 4-stellige PIN zurück, wenn Biometrie nicht verfügbar ist")
    }
}

struct SettingsAboutPage: View {
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    let onClose: () -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    SettingsDestinationIcon(systemName: "info.circle")
                    Text(l.tr(zh: "版本", en: "Version", de: "Version"))
                        .font(OhanaFont.body(.semibold))
                    Spacer()
                    Text(OhanaReleaseIdentity.currentVersionDisplay)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .accessibilityIdentifier("settings-version-value")
                }
                .frame(minHeight: 44)

                if let reviewURL = OhanaPublicLinks.appStoreReview {
                    SettingsExternalLinkRow(icon: "star.fill", title: l.tr(zh: "评价 App", en: "Rate App", de: "App bewerten"), url: reviewURL)
                }
                SettingsExternalLinkRow(icon: "hand.raised.fill", title: l.tr(zh: "隐私政策", en: "Privacy Policy", de: "Datenschutzrichtlinie"), subtitle: l.tr(zh: "公开说明", en: "Public policy", de: "Öffentliche Richtlinie"), url: OhanaPublicLinks.privacyPolicy)
                    .accessibilityIdentifier("settings-privacy-policy-action")
                SettingsExternalLinkRow(icon: "questionmark.bubble.fill", title: l.tr(zh: "获取支持", en: "Get Support", de: "Support erhalten"), subtitle: "guanchen.li.119@gmail.com", url: OhanaPublicLinks.support)
                    .accessibilityIdentifier("settings-support-action")
            }
        }
        .settingsDestinationChrome(title: SettingsDestination.about.title(l), closeLabel: l.tr(zh: "关闭", en: "Close", de: "Schließen"), onClose: onClose)
    }
}

private struct SettingsExternalLinkRow: View {
    let icon: String
    let title: String
    var subtitle = ""
    let url: URL

    var body: some View {
        Button { UIApplication.shared.open(url) } label: {
            SettingsNavigationLabel(icon: icon, title: title, subtitle: subtitle)
        }
    }
}

struct SettingsDestinationIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(OhanaFont.adaptive(size: 14, weight: .semibold))
            .foregroundStyle(Color.ohanaFunctionalIcon)
            .frame(width: 32, height: 32) // a11y: allow decorative glyph inside a 44pt semantic row
            .accessibilityHidden(true)
    }
}

struct SettingsNavigationLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    init(icon: String, title: String, subtitle: String = "") {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsDestinationIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(OhanaFont.footnote())
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
        }
        .frame(minHeight: 44)
    }
}

private struct SettingsMenuValueLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Image(systemName: "chevron.down").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
        }
        .foregroundStyle(Color.ohanaPrimaryText)
        .frame(minHeight: 34)
        .padding(.horizontal, 10)
        .background(Color.ohanaControlFill, in: Capsule())
    }
}

private extension View {
    func settingsDestinationChrome(title: String, closeLabel: String, onClose: @escaping () -> Void) -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(OhanaStaticAppBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .cancel, action: onClose) {
                        Label(closeLabel, systemImage: "xmark")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(closeLabel)
                    .accessibilityIdentifier("settings-close-action")
                }
            }
            .accessibilityIdentifier("settings-destination-screen")
    }
}
