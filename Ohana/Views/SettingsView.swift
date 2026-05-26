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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency = AppCurrency.fallbackCode
    @AppStorage("appThemePreference") private var appThemePreference: String = "dark"
    @AppStorage("appBackgroundStyle") private var appBackgroundStyle: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @State private var showingClearDataAlert = false
    @State private var showingDeletePetSheet = false
    @State private var petToDelete: Pet? = nil
    @State private var deleteConfirmName = ""
    @State private var showingResetPetData = false
    @State private var petToReset: Pet? = nil
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
    @State private var quickSwitchHuman: Human? = nil
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    
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
                OhanaAppBackground()
                
                ScrollView {
                    VStack(spacing: 14) {
                        settingsHeader

                        // 设备身份绑定
                        if !humans.isEmpty {
                            deviceIdentitySection
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
                        
                        // 宠物管理
                        if !pets.isEmpty {
                            settingsSection(title: "宠物管理") {
                                VStack(spacing: 0) {
                                    ForEach(Array(pets.enumerated()), id: \.element.id) { i, pet in
                                        if i > 0 { OhanaDashedDivider(color: dividerLine).padding(.leading, 44) }
                                        HStack(spacing: 10) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.ohanaControlFill)
                                                    .frame(width: 32, height: 32)
                                                Text(pet.avatarEmoji)
                                                    .font(.system(size: 16))
                                            }
                                            Text(pet.name)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(primaryText)
                                            Spacer()
                                            // 重置数据（保留基础信息）
                                            Button {
                                                petToReset = pet
                                                showingResetPetData = true
                                            } label: {
                                                Text("重置")
                                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                                    .foregroundStyle(Color.goYellow.opacity(0.8))
                                                    .frame(minHeight: 32)
                                                    .padding(.horizontal, 10)
                                                    .background(Color.goYellow.opacity(0.1), in: Capsule())
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                            // 删除宠物
                                            Button {
                                                petToDelete = pet
                                                deleteConfirmName = ""
                                                showingDeletePetSheet = true
                                            } label: {
                                                Text("删除")
                                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                                    .foregroundStyle(Color.goRed.opacity(0.8))
                                                    .frame(minHeight: 32)
                                                    .padding(.horizontal, 10)
                                                    .background(Color.goRed.opacity(0.1), in: Capsule())
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                        .frame(minHeight: 44)
                                    }
                                }
                            }
                            .alert("删除 \(petToDelete?.name ?? "")", isPresented: $showingDeletePetSheet) {
                                TextField("输入宠物名字确认", text: $deleteConfirmName)
                                Button("取消", role: .cancel) { deleteConfirmName = "" }
                                Button("删除", role: .destructive) {
                                    if let p = petToDelete, ConfirmationNameMatcher.matches(deleteConfirmName, expectedName: p.name) {
                                        let petIdStr = p.id.uuidString
                                        if let allEvents = try? modelContext.fetch(FetchDescriptor<Event>()) {
                                            for event in allEvents where event.relatedEntityId == petIdStr {
                                                modelContext.delete(event)
                                            }
                                        }
                                        removeQuickAccessItems(for: p.id)
                                        modelContext.delete(p)
                                        modelContext.safeSave()
                                    }
                                    deleteConfirmName = ""
                                }
                            } message: {
                                let n = petToDelete?.name ?? ""
                                Text("请输入「\(n)」确认删除。此操作不可撤销。")
                            }
                            .alert("重置 \(petToReset?.name ?? "") 的数据", isPresented: $showingResetPetData) {
                                Button("取消", role: .cancel) { petToReset = nil }
                                Button("重置记录", role: .destructive) {
                                    if let p = petToReset { resetPetLogs(p) }
                                    petToReset = nil
                                }
                            } message: {
                                Text("将清除该宠物所有日志记录（体重、花费、健康、护理、遛狗、噗噗等），基础信息保留。此操作不可撤销。")
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
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text("组件、页面、流程与验收")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
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
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text(l.tr(zh: "任务盘、宠物地图、家人竞赛", en: "Board, pet map, family race", de: "Brett, Tierkarte, Familienrennen"))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
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
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text(l.tr(zh: "卡片堆、抽出、收回与调试", en: "Stack, hero, collapse, and debug", de: "Stapel, Hero, Zurück und Debug"))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
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
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text(l.tr(zh: "底部导航、竖卡片、内嵌快捷操作", en: "Bottom nav, portrait cards, embedded actions", de: "Untere Navigation, Hochformatkarten, Aktionen"))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
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
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text(l.tr(zh: "手动设置当前用户余额", en: "Manually set current member balance", de: "Kontostand manuell setzen"))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
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
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text("性能记录")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(tertiaryText.opacity(0.6))
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(ScaleButtonStyle())

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            NavigationLink {
                                HumanPrivacyTestView()
                            } label: {
                                HStack(spacing: 12) {
                                    settingsIcon("lock.shield.fill", color: Color.goYellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("隐私测试面板")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text("可见性检查")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(tertiaryText.opacity(0.6))
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }

                        // 数据
                        settingsSection(title: "数据") {
                            VStack(spacing: 0) {
                                settingsRow(icon: "square.and.arrow.up", title: "导出数据", subtitle: "即将推出") {}
                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                                settingsRow(icon: "exclamationmark.triangle", title: "清除所有数据", subtitle: "", iconColor: Color.goRed) {
                                    showingClearDataAlert = true
                                }
                            }
                        }
                        .alert("清除所有数据", isPresented: $showingClearDataAlert) {
                            Button("取消", role: .cancel) {}
                            Button("清除", role: .destructive) {
                                clearAllData()
                            }
                        } message: {
                            Text("此操作将删除 App 内所有宠物、记录、日历数据，无法恢复。确定继续？")
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(preferredScheme)
        .onAppear {
            AppCountry.ensureInitialized()
            appCountry = AppCountry.code
            appMeasurementSystem = AppMeasurementSystem.code
            appCurrency = AppCurrency.code
            appLanguage = AppLanguage.code
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
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 38, height: 34)
                        .background(Color.ohanaControlFill, in: Capsule())
                        .padding(20)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .sheet(isPresented: $showingAccountSwitcher) {
            HumanAccountSwitcherSheet()
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        .sheet(isPresented: $showingBackgroundPicker) {
            AppBackgroundPickerSheet()
                .ohanaSheetPagePresentation() // ui-v4: allow background picker is a long visual chooser
        }
        .sheet(item: $quickSwitchHuman) { human in
            HumanQuickSwitchPasscodeSheet(human: human) {
                currentActiveHumanId = human.id.uuidString
                quickSwitchHuman = nil
            }
            .ohanaCompactSheetPresentation(detents: [.height(420)])
        }
    }
    
    // MARK: - 设备身份绑定卡
    private var deviceIdentitySection: some View {
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
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(primaryText)
                            Text("账户与密码")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(tertiaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .black))
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
                                        Circle()
                                            .fill(isSelected ? Color.goPrimary.opacity(0.20) : Color.ohanaControlFill)
                                            .frame(width: 44, height: 44)
                                            .overlay(Circle().strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2))
                                        if let data = human.avatarImageData, let img = UIImage(data: data) {
                                            Image(uiImage: img)
                                                .resizable().scaledToFill()
                                                .frame(width: 44, height: 44).clipShape(Circle())
                                        } else {
                                            Text(human.avatarEmoji).font(.system(size: 20))
                                        }
                                        if HumanPasscodeService.hasPasscode(human) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 8, weight: .black))
                                                .foregroundStyle(Color.arkInk)
                                                .frame(width: 16, height: 16)
                                                .background(Color.goYellow, in: Circle())
                                                .offset(x: 15, y: 15)
                                        }
                                    }
                                    Text(human.name.isEmpty ? "成员" : human.name)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
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
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.goPrimary)
                            .font(.system(size: 12))
                        Text("打卡记录将关联到 \(selected.name)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(tertiaryText)
                    }
                }
            }
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
            currentActiveHumanId = human.id.uuidString
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryText)
                        Text("全量 JSON")
                            .font(.system(size: 11, weight: .medium))
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
                                        .exportJSON(context: modelContext)
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
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryText)
                        Text("选择 .json")
                            .font(.system(size: 11, weight: .medium))
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
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.goYellow.opacity(0.6))
                    Text("恢复会自动去重。")
                        .font(.system(size: 11, weight: .medium))
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
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(label).font(.system(size: 12, weight: .bold, design: .rounded))
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .black))
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

    // MARK: - Header
    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Text("设置")
                .font(OhanaFont.largeTitle(.black))
                .foregroundStyle(primaryText)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(primaryText)
                    .frame(width: 38, height: 34)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }
    
    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.goPrimary)
                    .frame(width: 3, height: 14)
                Text(title.uppercased())
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(tertiaryText)
                    .tracking(1.2)
            }
            .padding(.leading, 2)

            glassCard {
                VStack(spacing: 0) {
                    content()
                }
                .padding(14)
            }
        }
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
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

    private func removeQuickAccessItems(for petId: UUID) {
        let key = "quickActionItems_v2"
        guard let json = UserDefaults.standard.string(forKey: key),
              let data = json.data(using: .utf8),
              var items = try? JSONDecoder().decode([QuickActionItem].self, from: data) else { return }
        items.removeAll { $0.petId == petId }
        if let newData = try? JSONEncoder().encode(items),
           let newJSON = String(data: newData, encoding: .utf8) {
            UserDefaults.standard.set(newJSON, forKey: key)
        }
    }

    private func resetPetLogs(_ pet: Pet) {
        pet.clearAllActivityRecords(in: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: Pet.self)
            try modelContext.delete(model: Event.self)
            try modelContext.delete(model: Reminder.self)
            try modelContext.delete(model: Human.self)
            try modelContext.save()
            // Reset onboarding and binding to force fresh setup
            UserDefaults.standard.set(false, forKey: "ohana_has_onboarded")
            UserDefaults.standard.set("", forKey: "currentActiveHumanId")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Clear data error: \(error)")
        }
    }
    
    // MARK: - Glass Card Helper
    @ViewBuilder
    private func glassCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .background(
                reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            }
    }

    private func settingsIcon(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.ohanaFunctionalIcon)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
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
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34)
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
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .black))
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
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .black))
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
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34)
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
        ZStack {
            Circle()
                .fill(Color(hex: human.themeColor).opacity(0.18))
                .frame(width: 48, height: 48)
            if let data = human.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: 22))
            }
        }
    }

    private func verify() {
        let now = Date()
        switch HumanPasscodeService.verify(pin, for: human, now: now) {
        case .success, .noPasscode:
            modelContext.safeSave()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onVerified()
            dismiss()
        case .incorrect(let remaining):
            modelContext.safeSave()
            pin = ""
            isError = true
            message = "密码不正确，还可尝试 \(remaining) 次"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .locked(let until):
            modelContext.safeSave()
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

private struct CoconutBalanceTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @State private var questManager = QuestManager.shared
    @State private var selectedHumanId = ""
    @State private var amountText = ""
    @State private var message = ""

    private var l: L10n { L10n(appLanguage) }
    private var selectedHuman: Human? {
        humans.first { $0.id.uuidString == selectedHumanId }
    }
    private var currentDisplayAmount: Int {
        selectedHuman?.coconutBalance ?? questManager.coconutCount
    }
    private var parsedAmount: Int {
        max(0, Int(amountText.filter(\.isNumber)) ?? 0)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    currentBalancePanel
                    memberPicker
                    amountPanel
                    quickPresets
                    applyButton

                    if !message.isEmpty {
                        Text(message)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Text(l.tr(
                        zh: "测试工具会把所选成员余额和旧版全岛兼容总数同步到同一个值，便于验证商店、悬赏、财富页和首页椰子显示。",
                        en: "This test tool syncs the selected member balance and legacy island total to the same value so shop, bounty, wealth, and home displays are easy to verify.",
                        de: "Dieses Testwerkzeug setzt Mitgliedskonto und alten Insel-Gesamtwert auf denselben Wert, damit Shop, Aufgaben, Vermögen und Startseite leicht prüfbar sind."
                    ))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 42)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: configureInitialSelection)
        .onChange(of: selectedHumanId) { _, _ in
            amountText = "\(currentDisplayAmount)"
            message = ""
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(l.tr(zh: "椰子数量测试", en: "Coconut balance test", de: "Kokosnuss-Teststand"))
                    .font(OhanaFont.largeTitle(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "开发者工具", en: "Developer tool", de: "Entwicklerwerkzeug"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 38, height: 34)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var currentBalancePanel: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.goYellow)
                .frame(width: 48, height: 48)
                .background(Color.goYellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(selectedHuman))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "当前余额", en: "Current balance", de: "Aktueller Stand"))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text("\(currentDisplayAmount)🥥")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Color.goYellow)
                .contentTransition(.numericText())
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
        .animation(GoMotion.feedback, value: currentDisplayAmount)
    }

    @ViewBuilder
    private var memberPicker: some View {
        if humans.isEmpty {
            emptyStateRow(
                icon: "person.crop.circle.badge.exclamationmark",
                title: l.tr(zh: "还没有人类成员", en: "No human members yet", de: "Noch keine Menschen"),
                subtitle: l.tr(zh: "现在只会修改旧版全岛兼容总数。", en: "Only the legacy island total will be changed.", de: "Nur der alte Insel-Gesamtwert wird geändert.")
            )
        } else {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(l.tr(zh: "选择成员", en: "Choose member", de: "Mitglied wählen"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(humans) { human in
                            memberChip(human)
                        }
                    }
                }
            }
        }
    }

    private var amountPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "目标数量", en: "Target amount", de: "Zielbetrag"))
            InlineNumericInput(
                text: $amountText,
                placeholder: "0",
                unit: "🥥",
                maxFractionDigits: 0,
                accent: Color.goYellow,
                step: 50,
                valueFont: .system(size: 44, weight: .black, design: .rounded),
                unitFont: .system(size: 28, weight: .black),
                fill: Color.ohanaControlFill,
                cornerRadius: 22,
                horizontalPadding: 16,
                verticalPadding: 12
            )
        }
    }

    private var quickPresets: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(l.tr(zh: "快速设置", en: "Quick presets", de: "Schnellwerte"))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach([0, 100, 500, 1_000, 5_000, 10_000], id: \.self) { value in
                    Button {
                        withAnimation(GoMotion.feedback) {
                            amountText = "\(value)"
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text("\(value)🥥")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var applyButton: some View {
        Button {
            applyAmount()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(l.tr(zh: "应用测试数量", en: "Apply test balance", de: "Testwert anwenden"))
            }
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func memberChip(_ human: Human) -> some View {
        let selected = human.id.uuidString == selectedHumanId
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedHumanId = human.id.uuidString
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 8) {
                avatar(for: human)
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName(human))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text("\(human.coconutBalance)🥥")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(selected ? Color.ohanaPrimaryActionText.opacity(0.72) : Color.ohanaSecondaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func avatar(for human: Human) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: human.safeThemeColorHex).opacity(0.18))
            if let data = human.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                    .font(.system(size: 16))
            }
        }
        .frame(width: 30, height: 30)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(Color.ohanaTertiaryText)
            .tracking(1.1)
    }

    private func emptyStateRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.goYellow)
                .frame(width: 40, height: 40)
                .background(Color.goYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func configureInitialSelection() {
        if selectedHumanId.isEmpty {
            selectedHumanId = humans.first(where: { $0.id.uuidString == currentActiveHumanId })?.id.uuidString
                ?? humans.first?.id.uuidString
                ?? ""
        }
        amountText = "\(currentDisplayAmount)"
    }

    private func applyAmount() {
        let amount = parsedAmount
        let human = selectedHuman
        human?.coconutBalance = amount
        modelContext.safeSave()

        let delta = amount - questManager.coconutCount
        questManager.recordCoconutDelta(
            delta,
            emoji: "🧪",
            title: l.tr(zh: "测试调整椰子数量", en: "Test coconut balance adjustment", de: "Testanpassung Kokosnüsse"),
            actorId: human?.id.uuidString,
            actorName: human.map { displayName($0) }
        )

        withAnimation(GoMotion.feedback) {
            amountText = "\(amount)"
            message = l.tr(
                zh: "已设置为 \(amount)🥥",
                en: "Set to \(amount)🥥",
                de: "Auf \(amount)🥥 gesetzt"
            )
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func displayName(_ human: Human?) -> String {
        guard let human else {
            return l.tr(zh: "全岛兼容总数", en: "Legacy island total", de: "Alter Insel-Gesamtwert")
        }
        let trimmed = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? l.tr(zh: "成员", en: "Member", de: "Mitglied") : trimmed
    }
}

private struct PerformanceDiagnosticsView: View {
    @ObservedObject private var monitor = AppPerformanceMonitor.shared

    private var primaryText: Color {
        Color.ohanaPrimaryText
    }

    private var secondaryText: Color {
        Color.ohanaSecondaryText
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("性能诊断")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(primaryText)
                        Text("用于验收启动、首页、头像、点击和相机链路。数值越低越好。")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(secondaryText)
                    }

                    HStack(spacing: 10) {
                        metricSummaryCard(title: "样本", value: "\(monitor.samples.count)", icon: "chart.bar.fill")
                        metricSummaryCard(title: "最近", value: latestMetricText, icon: "timer")
                    }

                    VStack(spacing: 0) {
                        if monitor.samples.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Color.goPrimary)
                                Text("还没有性能样本")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(primaryText)
                                Text("回到首页、点击卡片或进入头像裁剪后，这里会记录链路耗时。")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            ForEach(monitor.samples) { sample in
                                performanceSampleRow(sample)
                                if sample.id != monitor.samples.last?.id {
                                    OhanaDashedDivider(color: Color.ohanaDivider)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.ohanaCardSurface,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                    )

                    Button {
                        monitor.clear()
                    } label: {
                        Label("清空样本", systemImage: "trash")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(monitor.samples.isEmpty)
                    .opacity(monitor.samples.isEmpty ? 0.45 : 1)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 42)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var latestMetricText: String {
        guard let sample = monitor.samples.first else { return "—" }
        return formatMS(sample.valueMS)
    }

    private func metricSummaryCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 28, height: 28)
                .background(Color.goPrimary.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryText)
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaCardSurface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func performanceSampleRow(_ sample: AppPerformanceMonitor.Sample) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sample.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                if let note = sample.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondaryText)
                }
                Text(sample.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(secondaryText.opacity(0.7))
            }
            Spacer(minLength: 8)
            Text(formatMS(sample.valueMS))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(sample.valueMS > 1_000 ? Color.goRed : Color.goPrimary)
        }
        .padding(.vertical, 10)
    }

    private func formatMS(_ value: Double) -> String {
        if value >= 1_000 {
            return String(format: "%.2fs", value / 1_000)
        }
        return String(format: "%.0fms", value)
    }
}

#Preview {
    SettingsView()
}
