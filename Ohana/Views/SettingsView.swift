//
//  SettingsView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

struct SettingsView: View {
    var onClose: (() -> Void)? = nil
    private let homePets: [Pet]?
    private let homeHumans: [Human]?
    private let homeElectronicPets: [OasisElectronicPet]?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.ohanaInlinePageSafeAreaInsets) private var inlinePageSafeAreaInsets
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency = AppCurrency.fallbackCode
    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @AppStorage("appBackgroundStyle") private var appBackgroundStyle: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") private var homeCardOrderRaw = ""
    @State private var showingAppResetAlert = false
    @State private var appResetErrorMessage: String? = nil
    // TASK 1：JSON 备份
    @State private var exportedJSONURL: URL? = nil
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingImportPicker = false
    @State private var importError: String? = nil
    @State private var showingImportSuccess = false
    @State private var showingImportErrorAlert = false
    @State private var showingOnboardingReplay = false
    @State private var showingAccountSwitcher = false
    @State private var showingBackgroundPicker = false
    @State private var showingPetManagement = false
    @State private var quickSwitchHuman: Human? = nil
    @State private var areDataSectionsMounted = false
    @State private var dataSectionsMountTask: Task<Void, Never>?

    init(
        homePets: [Pet]? = nil,
        homeHumans: [Human]? = nil,
        homeElectronicPets: [OasisElectronicPet]? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.homePets = homePets
        self.homeHumans = homeHumans
        self.homeElectronicPets = homeElectronicPets
        self.onClose = onClose
    }

    private var preferredScheme: ColorScheme? {
        switch appThemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private var primaryText: Color {
        Color.ohanaPrimaryText
    }
    
    private var secondaryText: Color {
        Color.ohanaSecondaryText
    }
    
    private var tertiaryText: Color {
        Color.ohanaTertiaryText
    }

    private var dividerLine: Color {
        Color.ohanaDivider
    }
    
    private var accentColor: Color { Color.goPrimary }
    private var l: L10n { L10n(appLanguage) }
    private var selectedCountry: AppCountry.Option {
        AppCountry.option(for: appCountry)
    }
    private var selectedMeasurementSystem: AppMeasurementSystem.Option {
        AppMeasurementSystem.option(for: appMeasurementSystem)
    }
    private var selectedCurrency: AppCurrency.Option {
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
                                title: "用药提醒", key: "notif_medication_enabled"
                            )
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            notificationToggleRow(
                                icon: "fork.knife", iconColor: Color.goPrimary,
                                title: "喂食提醒", key: "notif_feeding_enabled"
                            )
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            notificationToggleRow(
                                icon: "bubbles.and.sparkles.fill", iconColor: Color.goTeal,
                                title: "护理提醒", key: "notif_hygiene_enabled"
                            )
                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            notificationToggleRow(
                                icon: "checkmark.seal.fill", iconColor: Color.goYellow,
                                title: "打卡提醒", key: "notif_checkin_enabled"
                            )
                        }
                        
                        // ── 备份与恢复
                        backupSection

                        // 关于
                        settingsSection(title: "关于") {
                            VStack(spacing: 0) {
                                settingsRow(icon: "info.circle", title: "版本", subtitle: "v4.5.0") {}
                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                                settingsRow(icon: "star.fill", title: "评价 App", subtitle: "") {
                                    if let url = URL(string: "https://apps.apple.com/app/id6742117937?action=write-review") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                                settingsRow(icon: "lock.shield", title: "隐私政策", subtitle: "") {}
                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                                settingsRow(icon: "envelope", title: "联系开发者", subtitle: "") {}
                            }
                        }
                        
                        // 开发者工具
                        settingsSection(title: "开发者工具") {
                            NavigationLink {
                                UIGuidelinesView()
                            } label: {
                                HStack(spacing: 12) {
                                    settingsIcon("rectangle.3.group.bubble.left.fill", color: Color.goTeal)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("UI/UX 规范查看")
                                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(primaryText)
                                        Text("组件、页面、流程与验收")
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
                                        Text("性能诊断面板")
                                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(primaryText)
                                        Text("性能记录")
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
                                        Text("隐私测试面板")
                                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                            .foregroundStyle(primaryText)
                                        Text("可见性检查")
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

                        // 数据
                        settingsSection(title: l.tr(zh: "数据", en: "Data", de: "Daten")) {
                            VStack(spacing: 0) {
                                settingsRow(
                                    icon: "square.and.arrow.up",
                                    title: l.tr(zh: "导出数据", en: "Export Data", de: "Daten exportieren"),
                                    subtitle: l.tr(zh: "即将推出", en: "Coming soon", de: "Demnachst")
                                ) {}
                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
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
            scheduleDataSectionsMount()
        }
        .onDisappear {
            dataSectionsMountTask?.cancel()
        }
        .fullScreenCover(isPresented: $showingOnboardingReplay) {
            ZStack(alignment: .topTrailing) {
                OnboardingView(isReplay: true) {
                    showingOnboardingReplay = false
                }
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
            .ohanaCompactSheetPresentation(detents: [.height(420)])
        }
    }

    @ViewBuilder
    private var settingsDataSections: some View {
        if areDataSectionsMounted {
            if let homeHumans, !homeHumans.isEmpty {
                deviceIdentitySection(homeHumans)
            }
            if let homePets, !homePets.isEmpty {
                petManagementEntrySection(homePets)
            }
        }
    }
    
    // MARK: - 设备身份绑定卡
    private func deviceIdentitySection(_ humans: [Human]) -> some View {
        settingsSection(title: "设备身份") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(GoMotion.page) {
                        showingAccountSwitcher = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        settingsIcon("person.2.badge.key.fill", color: Color.goPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("切换人类账户")
                                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(primaryText)
                            Text("账户与密码")
                                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(tertiaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    .padding(12)
                    .frame(minHeight: 44)
                    .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        /* Removing "Unbind" option to enforce mandatory identity */

                        ForEach(humans) { human in
                            let isSelected = currentActiveHumanId == human.id.uuidString
                            Button {
                                quickSwitch(to: human)
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        SettingsHumanIdentityAvatar(
                                            human: human,
                                            isSelected: isSelected
                                        )
                                        if HumanPasscodeService.hasPasscode(human) {
                                            Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                                                .font(OhanaFont.adaptive(size: 8, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                                .foregroundStyle(Color.arkInk)
                                                .frame(width: 16, height: 16) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                                .background(Color.goYellow, in: Circle())
                                                .offset(x: 15, y: 15)
                                        }
                                    }
                                    Text(human.name.isEmpty ? "成员" : human.name)
                                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(isSelected ? Color.goPrimary : tertiaryText)
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 56, minHeight: 72)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                if !currentActiveHumanId.isEmpty,
                   let selected = humans.first(where: { $0.id.uuidString == currentActiveHumanId }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                            .foregroundStyle(Color.goPrimary)
                            .font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        Text("打卡记录将关联到 \(selected.name)")
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                }
            }
        }
    }

    private func petManagementEntrySection(_ pets: [Pet]) -> some View {
        settingsSection(title: "宠物管理") {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(GoMotion.page) {
                    showingPetManagement = true
                }
            } label: {
                HStack(spacing: 12) {
                    settingsIcon("pawprint.fill", color: Color.goPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("管理宠物")
                            .font(OhanaFont.body(.semibold))
                            .foregroundStyle(primaryText)
                        Text("\(pets.count) 位成员，可重置或删除")
                            .font(OhanaFont.footnote())
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
    }

    private var currentBackgroundStyle: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: appBackgroundStyle) ?? .goIsland
    }

    private func quickSwitch(to human: Human) {
        UISelectionFeedbackGenerator().selectionChanged()
        guard currentActiveHumanId != human.id.uuidString else { return }
        if HumanPasscodeService.hasPasscode(human) {
            quickSwitchHuman = human
        } else {
            switchActiveHuman(to: human)
        }
    }

    private func switchActiveHuman(to human: Human, emitSuccessFeedback: Bool = true) {
        let oldHumanIdRaw = currentActiveHumanId
        guard oldHumanIdRaw != human.id.uuidString else { return }
        currentActiveHumanId = human.id.uuidString
        syncHomeCardStackAfterAccountSwitch(from: oldHumanIdRaw, to: human)
        if emitSuccessFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func syncHomeCardStackAfterAccountSwitch(from oldHumanIdRaw: String, to human: Human) {
        guard let homePets, let homeHumans else { return }
        let result = SettingsCommandExecutor(context: modelContext).syncHomeCardStackAfterActiveHumanSwitch(
            from: oldHumanIdRaw,
            to: human,
            pets: homePets,
            humans: homeHumans,
            electronicPets: homeElectronicPets ?? [],
            hiddenPetIDsRaw: hiddenHomePetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            note: "settings.activeHuman.switch"
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if result.updatedHomeCardOrderRaw != homeCardOrderRaw {
                homeCardOrderRaw = result.updatedHomeCardOrderRaw
            }
        }
        guard result.didSyncHomeStack else { return }
        NotificationCenter.default.post(
            name: .ohanaMemberProfileDidChange,
            object: nil,
            userInfo: ["id": result.humanID.uuidString, "kind": "human", "reason": "activeHumanSwitch"]
        )
    }

    private struct SettingsHumanIdentityAvatar: View {
        let human: Human
        let isSelected: Bool
        @State private var avatarImage: UIImage?

        var body: some View {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.goPrimary.opacity(0.20) : Color.ohanaControlFill)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2))

                if let image = avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                        .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
            }
            .task(id: avatarSignature) {
                await loadAvatarImage()
            }
        }

        private var avatarSignature: String {
            human.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
        }

        @MainActor
        private func loadAvatarImage() async {
            guard !avatarSignature.isEmpty else {
                avatarImage = nil
                return
            }
            if let image = FocusWalletAvatarCache.cachedEntry(for: human.id, signature: avatarSignature)?.image {
                avatarImage = image
                return
            }
            await FocusWalletAvatarCache.preload(payloads: [
                FocusWalletAvatarCache.Payload(id: human.id, data: human.avatarImageData)
            ])
            guard !Task.isCancelled else { return }
            avatarImage = FocusWalletAvatarCache.cachedEntry(for: human.id, signature: avatarSignature)?.image
        }
    }

    // MARK: - Backup Section（TASK 1）
    @ViewBuilder
    private var backupSection: some View {
        settingsSection(title: "数据备份") {
            VStack(spacing: 0) {
                // ── 导出行
                HStack(spacing: 10) {
                    settingsIcon("arrow.down.doc.fill", color: Color.goTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("导出备份")
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(primaryText)
                        Text("全量 JSON")
                            .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    if isExporting {
                        ProgressView().tint(Color.goTeal).scaleEffect(0.8)
                    } else if let url = exportedJSONURL {
                        ShareLink(item: url,
                                  subject: Text("Ohana 数据备份"),
                                  message: Text("由 Ohana App 导出的全量备份文件")) {
                            backupPill("分享", icon: "square.and.arrow.up", color: Color.goTeal)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    } else {
                        Button {
                            isExporting = true
                            exportedJSONURL = nil
                            Task {
                                do {
                                    exportedJSONURL = try await DataBackupManager.shared
                                        .exportJSON(container: modelContext.container)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } catch {
                                    importError = error.localizedDescription
                                    showingImportErrorAlert = true
                                }
                                isExporting = false
                            }
                        } label: {
                            backupPill("生成备份", icon: "archivebox", color: Color.goTeal)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .frame(minHeight: 44)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                // ── 导入行
                HStack(spacing: 10) {
                    settingsIcon("square.and.arrow.down.fill", color: Color.goOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("从备份恢复")
                            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(primaryText)
                        Text("选择 .json")
                            .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(tertiaryText)
                    }
                    Spacer()
                    if isImporting {
                        ProgressView().tint(Color.goOrange).scaleEffect(0.8)
                    } else {
                        Button {
                            showingImportPicker = true
                        } label: {
                            backupPill("选择文件", icon: "folder", color: Color.goOrange)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .frame(minHeight: 44)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                // ── 说明行
                HStack(spacing: 8) {
                    Image(systemName: "info.circle") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 12)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goYellow.opacity(0.6))
                    Text("恢复会自动去重。")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tertiaryText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                isImporting = true
                Task {
                    do {
                        _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        try await DataBackupManager.shared.importJSON(from: url, context: modelContext)
                        showingImportSuccess = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch {
                        importError = error.localizedDescription
                        showingImportErrorAlert = true
                    }
                    isImporting = false
                }
            case .failure(let error):
                importError = error.localizedDescription
                showingImportErrorAlert = true
            }
        }
        .alert("恢复成功", isPresented: $showingImportSuccess) {
            Button("好的") {}
        } message: {
            Text("数据已成功导入，请重新进入 App 主页查看。")
        }
        .alert("操作失败", isPresented: $showingImportErrorAlert) {
            Button("好的") {}
        } message: {
            Text(importError ?? "未知错误")
        }
    }

    private func backupPill(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(OhanaFont.adaptive(size: 11, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(label).font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(color)
        .frame(minHeight: 34)
        .padding(.horizontal, 12)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.clear, lineWidth: 1))
    }

    private func menuValueLabel(_ text: String) -> some View {
        HStack(spacing: 5) {
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Image(systemName: "chevron.down") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 9, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 34)
        .padding(.horizontal, 10)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    private func applyCountryDefaults(_ country: AppCountry.Option) {
        AppCountry.applyDefaults(for: country.code)
        appCountry = country.code
        appLanguage = AppLanguage.normalize(country.defaultLanguageCode)
        appMeasurementSystem = AppMeasurementSystem.normalize(country.defaultMeasurementSystemCode)
        appCurrency = AppCurrency.normalize(country.defaultCurrencyCode)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func syncStoredRegionalDefaultsIfNeeded() {
        AppCountry.ensureInitialized()
        if appCountry != AppCountry.code {
            appCountry = AppCountry.code
        }
        if appMeasurementSystem != AppMeasurementSystem.code {
            appMeasurementSystem = AppMeasurementSystem.code
        }
        if appCurrency != AppCurrency.code {
            appCurrency = AppCurrency.code
        }
        if appLanguage != AppLanguage.code {
            appLanguage = AppLanguage.code
        }
    }

    private func scheduleDataSectionsMount() {
        guard !areDataSectionsMounted else { return }
        dataSectionsMountTask?.cancel()
        dataSectionsMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
            withAnimation(GoMotion.quick) {
                areDataSectionsMounted = true
            }
            dataSectionsMountTask = nil
        }
    }

    // MARK: - Header
    private var settingsHeader: some View {
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

    private func closeSettings() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        SettingsSectionCard(
            title: title,
            tertiaryText: tertiaryText,
            reduceTransparency: reduceTransparency,
            content: content
        )
    }

    private func settingsRow(icon: String, title: String, subtitle: String, iconColor: Color = Color.goPrimary, action: @escaping () -> Void) -> some View {
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

    private var performanceToggleRow: some View {
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

    private func notificationToggleRow(icon: String, iconColor: Color, title: String, key: String) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon, color: iconColor)
            Text(title)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(primaryText)
            Spacer()
            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key) },
                set: { UserDefaults.standard.set($0, forKey: key) }
            ))
            .tint(accentColor)
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    private func resetApp() {
        do {
            try AppResetService.reset(context: modelContext)
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
    
    private func settingsIcon(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaFunctionalIcon)
            .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
            .contentShape(Rectangle())
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let tertiaryText: Color
    let reduceTransparency: Bool
    private let content: Content

    init(
        title: String,
        tertiaryText: Color,
        reduceTransparency: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.tertiaryText = tertiaryText
        self.reduceTransparency = reduceTransparency
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.goPrimary)
                    .frame(width: 3, height: 14) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text(title.uppercased())
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(tertiaryText)
                    .tracking(1.2)
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .background(
                reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
    }
}

private struct SettingsPetManagementSheet: View {
    let pets: [Pet]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var showingDeletePetAlert = false
    @State private var petToDelete: Pet? = nil
    @State private var deleteConfirmName = ""
    @State private var showingResetPetData = false
    @State private var petToReset: Pet? = nil

    private var primaryText: Color { Color.ohanaPrimaryText }
    private var secondaryText: Color { Color.ohanaSecondaryText }
    private var tertiaryText: Color { Color.ohanaTertiaryText }
    private var dividerLine: Color { Color.ohanaDivider }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaStaticAppBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        header
                        petList
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 26)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("删除 \(petToDelete?.name ?? "")", isPresented: $showingDeletePetAlert) {
            TextField("输入宠物名字确认", text: $deleteConfirmName)
            Button("取消", role: .cancel) {
                petToDelete = nil
                deleteConfirmName = ""
            }
            Button("删除", role: .destructive) {
                deleteSelectedPetIfConfirmed()
            }
        } message: {
            let name = petToDelete?.name ?? ""
            Text("请输入「\(name)」确认删除。此操作不可撤销。")
        }
        .alert("重置 \(petToReset?.name ?? "") 的数据", isPresented: $showingResetPetData) {
            Button("取消", role: .cancel) { petToReset = nil }
            Button("重置记录", role: .destructive) {
                if let pet = petToReset {
                    resetPetLogs(pet)
                }
                petToReset = nil
            }
        } message: {
            Text("将清除该宠物所有日志记录（体重、花费、健康、护理、遛狗、噗噗等），基础信息保留。此操作不可撤销。")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("宠物管理")
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(primaryText)
                Text("重置记录或删除成员")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(primaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var petList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.goPrimary)
                    .frame(width: 3, height: 14) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text("成员")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(tertiaryText)
                    .tracking(1.2)
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                    if index > 0 {
                        OhanaDashedDivider(color: dividerLine)
                            .padding(.leading, 44)
                    }
                    petRow(pet)
                }
            }
            .padding(14)
            .background(
                reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
        }
    }

    private func petRow(_ pet: Pet) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.ohanaControlFill)
                    .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                Text(pet.avatarEmoji)
                    .font(OhanaFont.adaptive(size: 16)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            Text(pet.name)
                .font(OhanaFont.body(.semibold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
            Spacer()
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                petToReset = pet
                showingResetPetData = true
            } label: {
                petActionPill("重置", color: Color.goYellow)
            }
            .buttonStyle(ScaleButtonStyle())
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                petToDelete = pet
                deleteConfirmName = ""
                showingDeletePetAlert = true
            } label: {
                petActionPill("删除", color: Color.goRed)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(minHeight: 48)
    }

    private func petActionPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(color.opacity(0.86))
            .frame(minHeight: 34)
            .padding(.horizontal, 10)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func deleteSelectedPetIfConfirmed() {
        guard let pet = petToDelete,
              ConfirmationNameMatcher.matches(deleteConfirmName, expectedName: pet.name) else {
            deleteConfirmName = ""
            return
        }

        MemberCommandExecutor(context: modelContext).deletePet(
            pet,
            note: "settings.pet.deleted"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        petToDelete = nil
        deleteConfirmName = ""
    }

    private func resetPetLogs(_ pet: Pet) {
        MemberCommandExecutor(context: modelContext).clearPetActivityRecords(
            pet,
            note: "settings.pet.lifecycle.records.clear"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct AppBackgroundPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("appBackgroundStyle") private var styleRaw: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage("appCustomBackgroundVersion") private var customBackgroundVersion = 0

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var isSavingPhoto = false
    @State private var errorMessage: String? = nil

    private var l: L10n { L10n(appLanguage) }
    private var selectedStyle: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: styleRaw) ?? .goIsland
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        officialBackgrounds
                        customBackgroundSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: photoItem) { _, item in
            handlePhotoItem(item)
        }
        .alert(l.tr(zh: "背景保存失败", en: "Could not save background", de: "Hintergrund konnte nicht gespeichert werden"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "背景", en: "Background", de: "Hintergrund"))
                    .font(OhanaFont.title2(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "选择一组背景，同时决定浅色和深色模式。",
                    en: "Choose one background pair for both light and dark mode.",
                    de: "Wähle ein Hintergrundpaar für Hell- und Dunkelmodus."
                ))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var officialBackgrounds: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "官方背景对", en: "Official background pairs", de: "Offizielle Hintergrundpaare"))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(AppBackgroundStyle.officialPairOptions) { style in
                    backgroundOptionCard(style)
                }
            }
        }
    }

    private var customBackgroundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "自定义", en: "Custom", de: "Eigenes Bild"))
            backgroundOptionCard(.customPhoto)

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 6) {
                        if isSavingPhoto {
                            ProgressView()
                                .tint(Color.goPrimary)
                                .scaleEffect(0.72)
                        } else {
                            Image(systemName: CustomAppBackgroundStore.exists ? "photo.on.rectangle.angled" : "plus")
                        }
                        Text(CustomAppBackgroundStore.exists
                             ? l.tr(zh: "更换图片", en: "Change photo", de: "Bild ändern")
                             : l.tr(zh: "上传图片", en: "Upload photo", de: "Bild hochladen"))
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.goPrimary, in: Capsule())
                }
                .disabled(isSavingPhoto)
                .buttonStyle(ScaleButtonStyle())

                if CustomAppBackgroundStore.exists {
                    Button {
                        withAnimation(GoMotion.page) {
                            CustomAppBackgroundStore.deleteImage()
                            customBackgroundVersion += 1
                            if selectedStyle == .customPhoto {
                                styleRaw = AppBackgroundStyle.goIsland.rawValue
                            }
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } label: {
                        Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goRed)
                            .frame(width: 48, height: 46)
                            .background(Color.goRed.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .tracking(1.1)
    }

    private func backgroundOptionCard(_ style: AppBackgroundStyle) -> some View {
        let selected = selectedStyle == style
        return Button {
            guard style != .customPhoto || CustomAppBackgroundStore.exists else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            withAnimation(GoMotion.page) {
                styleRaw = style.rawValue
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                backgroundPairPreview(style)
                    .frame(height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.goPrimary)
                                .padding(8)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.localizedName(appLanguage))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(style.localizedSubtitle(appLanguage))
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? Color.goPrimary.opacity(0.75) : Color.ohanaGlassStroke.opacity(0.36), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.feedback, value: selected)
    }

    @ViewBuilder
    private func backgroundPairPreview(_ style: AppBackgroundStyle) -> some View {
        if style == .customPhoto, let image = CustomAppBackgroundStore.image {
            HStack(spacing: 0) {
                customPhotoPairHalf(image: image, isDarkPreview: false)
                customPhotoPairHalf(image: image, isDarkPreview: true)
            }
        } else {
            HStack(spacing: 0) {
                officialPairHalf(style, scheme: .light, label: l.tr(zh: "浅", en: "Light", de: "Hell"))
                officialPairHalf(style, scheme: .dark, label: l.tr(zh: "深", en: "Dark", de: "Dunkel"))
            }
        }
    }

    private func officialPairHalf(_ style: AppBackgroundStyle, scheme: ColorScheme, label: String) -> some View {
        LinearGradient(
            colors: style.gradientColors(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottomLeading) {
            Text(label)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(scheme == .dark ? Color(hex: "F8FAFC").opacity(0.82) : Color(hex: "26364D").opacity(0.72))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((scheme == .dark ? Color(hex: "0B1020") : Color(hex: "F8FAFC")).opacity(0.18), in: Capsule())
                .padding(7)
        }
    }

    private func customPhotoPairHalf(image: UIImage, isDarkPreview: Bool) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(
                    colors: isDarkPreview
                        ? [Color(hex: "0B1020").opacity(0.58), Color(hex: "0F172A").opacity(0.48)]
                        : [Color(hex: "DDE8F6").opacity(0.54), Color(hex: "AEBFD4").opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                    Text(isDarkPreview ? l.tr(zh: "深", en: "Dark", de: "Dunkel") : l.tr(zh: "浅", en: "Light", de: "Hell"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(isDarkPreview ? Color(hex: "F8FAFC").opacity(0.82) : Color(hex: "26364D").opacity(0.72))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isDarkPreview ? Color(hex: "0B1020") : Color(hex: "F8FAFC")).opacity(0.18), in: Capsule())
                        .padding(7)
                }
    }

    private func handlePhotoItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isSavingPhoto = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                try CustomAppBackgroundStore.saveImageData(data)
                await MainActor.run {
                    withAnimation(GoMotion.page) {
                        customBackgroundVersion += 1
                        styleRaw = AppBackgroundStyle.customPhoto.rawValue
                    }
                    photoItem = nil
                    isSavingPhoto = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    photoItem = nil
                    isSavingPhoto = false
                    errorMessage = error.localizedDescription
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

private struct HumanQuickSwitchPasscodeSheet: View {
    let human: Human
    let onVerified: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pin = ""
    @State private var message = "输入 4 位密码后切换到此账户"
    @State private var isError = false

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
                    statusText
                }
                .padding(22)
                .padding(.bottom, 28)
            }
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
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .animation(GoMotion.feedback, value: isError)
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
        switch HumanPrivacyCommandExecutor(context: modelContext).verifyPasscode(pin, for: human, now: now) {
        case .success, .noPasscode:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onVerified()
            dismiss()
        case .incorrect(let remaining):
            pin = ""
            isError = true
            message = "密码不正确，还可尝试 \(remaining) 次"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .locked(let until):
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

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "成员" : name
    }
}

#Preview {
    SettingsView()
}
