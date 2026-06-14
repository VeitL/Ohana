//
//  SettingsView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var onClose: (() -> Void)?
    let homeHouseholds: [Household]?
    let homePets: [Pet]?
    let homeHumans: [Human]?
    let homeElectronicPets: [OasisElectronicPet]?

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaInlinePageSafeAreaInsets) var inlinePageSafeAreaInsets
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @AppStorage("appLanguage") var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) var appCountry = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) var appMeasurementSystem = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) var appCurrency = AppCurrency.fallbackCode
    @AppStorage("appThemePreference") var appThemePreference: String = "dark"
    @AppStorage("appBackgroundStyle") var appBackgroundStyle: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage(AppPerformanceMode.powerSavingKey) var powerSavingMode = false
    @AppStorage(AppPrivacySnapshotProtectionStore.hideSnapshotKey) var hideAppSwitcherSnapshot = AppPrivacySnapshotProtectionStore.defaultHideSnapshot
    @AppStorage(MemberGateBiometricAuthStore.enabledKey) var enableMemberGateBiometrics = MemberGateBiometricAuthStore.defaultEnabled
    @AppStorage(MedicationNotificationPrivacyStore.hidePetDetailsKey) var hidePetMedicationNotificationDetails = false
    @AppStorage("ohana_has_onboarded") var hasOnboarded = false
    @AppStorage("currentActiveHumanId") var currentActiveHumanId = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") var homeCardOrderRaw = ""
    @AppStorage(CloudSyncEngineRuntime.sharedZoneAccessRevokedDefaultsKey) var hasCloudSyncSharedZoneAccessRevokedNotice = false
    @AppStorage(CloudSyncEngineRuntime.retryAttemptDefaultsKey) var cloudSyncRetryAttempt = 0
    @AppStorage(CloudSyncEngineRuntime.nextRetryAtDefaultsKey) var cloudSyncNextRetryAtReferenceDate: Double = 0
    @State var showingAppResetAlert = false
    @State var appResetErrorMessage: String? = nil
    // TASK 1：JSON 备份
    @State var exportedJSONURL: URL? = nil
    @State var isExporting = false
    @State var isImporting = false
    @State var automaticBackupStatus = AutomaticBackupStatusStore().snapshot()
    @State var isRunningAutomaticBackup = false
    @State var backupEncryptionEnabled = false
    @State var backupPassword = ""
    @State var backupPasswordConfirmation = ""
    @State var showingImportPicker = false
    @State var importError: String? = nil
    @State var showingImportSuccess = false
    @State var showingImportErrorAlert = false
    @State var showingOnboardingReplay = false
    @State var showingAccountSwitcher = false
    @State var showingBackgroundPicker = false
    @State var showingPetManagement = false
    @State var quickSwitchHuman: Human? = nil
    @State var householdSharePresentation: CloudSyncHouseholdSharePresentation? = nil
    @State var isPreparingHouseholdShare = false
    @State var isBindingCloudIdentity = false
    @State var isRetryingCloudSyncNow = false
    @State var householdSyncStatusMessage: String? = nil
    @State var householdSyncErrorMessage: String? = nil
    @State var areDataSectionsMounted = false
    @State var dataSectionsMountTask: Task<Void, Never>?
    @State var biometricGateAvailability = MemberGateBiometricAuthenticator.availability()

    init(
        homeHouseholds: [Household]? = nil,
        homePets: [Pet]? = nil,
        homeHumans: [Human]? = nil,
        homeElectronicPets: [OasisElectronicPet]? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.homeHouseholds = homeHouseholds
        self.homePets = homePets
        self.homeHumans = homeHumans
        self.homeElectronicPets = homeElectronicPets
        self.onClose = onClose
    }

    var preferredScheme: ColorScheme? {
        switch appThemePreference {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var primaryText: Color {
        Color.ohanaPrimaryText
    }

    var secondaryText: Color {
        Color.ohanaSecondaryText
    }

    var tertiaryText: Color {
        Color.ohanaTertiaryText
    }

    var dividerLine: Color {
        Color.ohanaDivider
    }

    var accentColor: Color { Color.goPrimary }
    var l: L10n { L10n(appLanguage) }
    var selectedCountry: AppCountry.Option {
        AppCountry.option(for: appCountry)
    }

    var selectedMeasurementSystem: AppMeasurementSystem.Option {
        AppMeasurementSystem.option(for: appMeasurementSystem)
    }

    var selectedCurrency: AppCurrency.Option {
        AppCurrency.supported.first { $0.code == AppCurrency.normalize(appCurrency) } ?? AppCurrency.supported[0]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaStaticAppBackground()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        settingsHeader

                        settingsDataSections
                        if OnlineFeatureGate.allows(.onlineCollaboration) {
                            householdSyncSection
                        }

                        // 国家 / 语言 / 单位 / 货币
                        settingsSection(title: l.preferences) {
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

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

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

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

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

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

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

                            // 外观主题
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

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            settingsRow(
                                icon: "photo.on.rectangle.angled",
                                title: l.tr(zh: "背景", en: "Background", de: "Hintergrund"),
                                subtitle: currentBackgroundStyle.localizedName(appLanguage),
                                iconColor: Color.goBlue
                            ) {
                                showingBackgroundPicker = true
                            }

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            performanceToggleRow

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            settingsRow(icon: "sparkles.tv", title: l.replayOnboarding, subtitle: l.replayOnboardingSubtitle) {
                                showingOnboardingReplay = true
                            }
                        }

                        privacySecuritySection

                        // 通知
                        settingsSection(title: l.notifications) {
                            settingsRow(icon: "bell.badge", title: l.notificationPermission, subtitle: l.manageNotification) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            notificationToggleRow(
                                icon: "pills.fill", iconColor: Color(hex: "FF5A00"),
                                title: l.tr(zh: "用药提醒", en: "Medication reminders", de: "Medikamentenerinnerungen"),
                                group: .medication
                            )
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            petMedicationNotificationPrivacyRow
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            notificationToggleRow(
                                icon: "fork.knife", iconColor: Color.goPrimary,
                                title: l.tr(zh: "喂食提醒", en: "Feeding reminders", de: "Fütterungserinnerungen"),
                                group: .feeding
                            )
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            notificationToggleRow(
                                icon: "bubbles.and.sparkles.fill", iconColor: Color.goTeal,
                                title: l.tr(zh: "护理提醒", en: "Care reminders", de: "Pflegeerinnerungen"),
                                group: .hygiene
                            )
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            notificationToggleRow(
                                icon: "checkmark.seal.fill", iconColor: Color.goYellow,
                                title: l.tr(zh: "打卡提醒", en: "Check-in reminders", de: "Check-in-Erinnerungen"),
                                group: .checkIn
                            )
                        }

                        // ── 备份与恢复
                        backupSection

                        // 关于
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

                        #if DEBUG
                            // 开发者工具
                            settingsSection(title: l.tr(zh: "开发者工具", en: "Developer Tools", de: "Entwicklertools")) {
                                NavigationLink {
                                    UIGuidelinesView()
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("rectangle.3.group.bubble.left.fill", color: Color.goTeal)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "UI/UX 规范查看", en: "UI/UX guideline viewer", de: "UI/UX-Richtlinien"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "组件、页面、流程与验收", en: "Components, pages, flows, and checks", de: "Komponenten, Seiten, Flows und Checks"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                                NavigationLink {
                                    NavigationBarStyleLabView()
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("rectangle.bottomthird.inset.filled", color: Color.goPrimary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "导航栏样式测试", en: "Navigation bar style lab", de: "Navigationsleisten-Labor"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "3-tab、4-tab 与主题按钮候选", en: "3-tab, 4-tab, and theme button candidates", de: "3-Tab, 4-Tab und Designfarben-Taste"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                                if OnlineFeatureGate.allows(.onlineCollaboration) {
                                    NavigationLink {
                                        FamilyCollaborationPlaygroundView()
                                    } label: {
                                        HStack(spacing: 12) {
                                            settingsIcon("person.3.sequence.fill", color: Color.goPurple)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(l.tr(zh: "家庭协作体验测试", en: "Family collab playground", de: "Familien-Testbereich"))
                                                    .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                    .foregroundStyle(primaryText)
                                                Text(l.tr(zh: "任务盘、宠物地图、家人竞赛", en: "Board, pet map, family race", de: "Brett, Tierkarte, Familienrennen"))
                                                    .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                    .foregroundStyle(tertiaryText)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                                .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText.opacity(0.6))
                                        }
                                        .frame(minHeight: 44)
                                    }
                                    .buttonStyle(ScaleButtonStyle())

                                    OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                                }

                                NavigationLink {
                                    WalletMotionLabView()
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("creditcard.fill", color: Color.goPrimary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "Apple Wallet 动效实验室", en: "Apple Wallet motion lab", de: "Apple-Wallet-Bewegungslabor"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "卡片堆、抽出、收回与调试", en: "Stack, hero, collapse, and debug", de: "Stapel, Hero, Zurück und Debug"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                                NavigationLink {
                                    MotionPreviewLabView()
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("sparkles", color: Color.goPrimary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "全局动效预览", en: "Global motion preview", de: "Globale Bewegungs-Vorschau"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "Capsule 默认、Chart Flow、5 个原色", en: "Capsule default, Flow charts, 5 colors", de: "Capsule als Standard, Flow-Charts, 5 Farben"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                                NavigationLink {
                                    VerticalGlassHomeLabView()
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("rectangle.portrait.on.rectangle.portrait", color: Color.goPrimary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "竖版实色首页实验室", en: "Solid portrait home lab", de: "Solides Hochformat-Home-Labor"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "底部导航、竖卡片、内嵌快捷操作", en: "Bottom nav, portrait cards, embedded actions", de: "Untere Navigation, Hochformatkarten, Aktionen"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                                NavigationLink {
                                    CoconutBalanceTestView()
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("circle.hexagongrid.fill", color: Color.goYellow)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "椰子数量测试", en: "Coconut balance test", de: "Kokosnuss-Teststand"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "手动设置当前用户余额", en: "Manually set current member balance", de: "Kontostand manuell setzen"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                                NavigationLink {
                                    PerformanceDiagnosticsView()
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("speedometer", color: Color.goPrimary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "性能诊断面板", en: "Performance diagnostics", de: "Leistungsdiagnose"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "性能记录", en: "Performance samples", de: "Leistungsproben"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                                NavigationLink {
                                    HumanPrivacyTestView(humans: homeHumans ?? [])
                                } label: {
                                    HStack(spacing: 12) {
                                        settingsIcon("lock.shield.fill", color: Color.goYellow)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(l.tr(zh: "隐私测试面板", en: "Privacy test panel", de: "Datenschutz-Testbereich"))
                                                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(primaryText)
                                            Text(l.tr(zh: "可见性检查", en: "Visibility checks", de: "Sichtbarkeitschecks"))
                                                .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(tertiaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                                            .font(OhanaFont.adaptive(size: 11, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(tertiaryText.opacity(0.6))
                                    }
                                    .frame(minHeight: 44)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        #endif

                        // 数据
                        settingsSection(title: l.tr(zh: "数据", en: "Data", de: "Daten")) {
                            VStack(spacing: 0) {
                                settingsRow(
                                    icon: "arrow.counterclockwise.circle.fill",
                                    title: l.tr(zh: "重置 App", en: "Reset App", de: "App zurucksetzen"),
                                    subtitle: l.tr(zh: "删除数据并回到引导页", en: "Delete data and restart onboarding", de: "Daten loschen und Onboarding starten"),
                                    iconColor: Color.goRed
                                ) {
                                    showingAppResetAlert = true
                                }
                            }
                        }
                        .alert(l.tr(zh: "重置 App", en: "Reset App", de: "App zurucksetzen"), isPresented: $showingAppResetAlert) {
                            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
                            Button(l.tr(zh: "重置", en: "Reset", de: "Zurucksetzen"), role: .destructive) {
                                resetApp()
                            }
                        } message: {
                            Text(l.tr(
                                zh: "此操作将删除 App 内的成员、记录、提醒、任务、奖励和本地自定义内容，无法恢复。重置后会从引导页面重新开始。",
                                en: "This deletes members, logs, reminders, tasks, rewards, and local custom content. It cannot be undone. After reset, Ohana starts from onboarding.",
                                de: "Dies loscht Mitglieder, Eintrage, Erinnerungen, Aufgaben, Belohnungen und lokale Anpassungen. Das kann nicht ruckgangig gemacht werden. Danach startet Ohana im Onboarding."
                            ))
                        }
                        .alert(l.tr(zh: "重置失败", en: "Reset Failed", de: "Zurucksetzen fehlgeschlagen"), isPresented: Binding(
                            get: { appResetErrorMessage != nil },
                            set: { if !$0 { appResetErrorMessage = nil } }
                        )) {
                            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {
                                appResetErrorMessage = nil
                            }
                        } message: {
                            Text(appResetErrorMessage ?? l.tr(zh: "未知错误", en: "Unknown error", de: "Unbekannter Fehler"))
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(10, inlinePageSafeAreaInsets.top + 10))
                    .padding(.bottom, inlinePageSafeAreaInsets.bottom)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(preferredScheme)
        .onAppear {
            syncStoredRegionalDefaultsIfNeeded()
            refreshBiometricGateAvailability()
            scheduleDataSectionsMount()
        }
        .onDisappear {
            dataSectionsMountTask?.cancel()
        }
        .fullScreenCover(isPresented: $showingOnboardingReplay) {
            ZStack(alignment: .topTrailing) {
                OnboardingView(isReplay: true, onReplayFinished: {
                    showingOnboardingReplay = false
                })
                .preferredColorScheme(.dark)

                Button {
                    showingOnboardingReplay = false
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.ohanaControlFill, in: Capsule())
                        .padding(20)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .sheet(isPresented: $showingAccountSwitcher) {
            HumanAccountSwitcherSheet(
                humans: homeHumans ?? [],
                homePets: homePets,
                homeHumans: homeHumans,
                homeElectronicPets: homeElectronicPets
            )
            .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        .sheet(isPresented: $showingBackgroundPicker) {
            AppBackgroundPickerSheet()
                .ohanaSheetPagePresentation() // ui-v4: allow background picker is a long visual chooser
        }
        .sheet(isPresented: $showingPetManagement) {
            SettingsPetManagementSheet(pets: homePets ?? [])
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        .sheet(item: $quickSwitchHuman) { human in
            HumanQuickSwitchPasscodeSheet(human: human) {
                switchActiveHuman(to: human, emitSuccessFeedback: false)
                quickSwitchHuman = nil
            }
            .ohanaCompactSheetPresentation(detents: [.height(500)])
        }
        .sheet(item: $householdSharePresentation) { presentation in
            CloudSyncHouseholdSharingController(
                presentation: presentation,
                onSaved: { share in handleHouseholdShareSaved(share) },
                onStoppedSharing: { handleHouseholdShareStopped(presentation) },
                onError: { error in householdSyncErrorMessage = error.localizedDescription }
            )
            .ignoresSafeArea()
        }
        .alert(l.tr(zh: "家庭同步失败", en: "Family Sync Failed", de: "Familiensynchronisierung fehlgeschlagen"), isPresented: Binding(
            get: { householdSyncErrorMessage != nil },
            set: { if !$0 { householdSyncErrorMessage = nil } }
        )) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {
                householdSyncErrorMessage = nil
            }
        } message: {
            Text(householdSyncErrorMessage ?? l.tr(zh: "未知错误", en: "Unknown error", de: "Unbekannter Fehler"))
        }
    }
}

#Preview {
    SettingsView()
}
