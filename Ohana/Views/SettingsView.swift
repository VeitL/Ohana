//
//  SettingsView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = true
    @AppStorage("userNickname") private var userNickname = ""
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @State private var showingNicknameEdit = false
    @State private var editingNickname = ""
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
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    
    private var preferredScheme: ColorScheme? {
        switch appThemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
    
    // 自适应文字颜色
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4)
    }

    /// 列表分隔虚线（浅/深对比）
    private var dividerLine: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
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
                    VStack(spacing: 18) {
                        // Profile Card
                        profileCard

                        // 设备身份绑定
                        if !humans.isEmpty {
                            deviceIdentitySection
                        }
                        
                        // 昵称
                        settingsSection(title: l.personalInfo) {
                            settingsRow(icon: "person.fill", title: l.nickname, subtitle: userNickname.isEmpty ? l.notSet : userNickname) {
                                editingNickname = userNickname
                                showingNicknameEdit = true
                            }
                        }
                        .alert(l.editNickname, isPresented: $showingNicknameEdit) {
                            TextField(l.enterNickname, text: $editingNickname)
                            Button(l.save) { userNickname = editingNickname }
                            Button(l.cancel, role: .cancel) {}
                        }
                        
                        // 国家 / 语言 / 单位 / 货币
                        settingsSection(title: l.preferences) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(Color.goPrimary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.countryRegion)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(l.countryDefaultsHint)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
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

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            HStack {
                                Image(systemName: "globe")
                                    .foregroundStyle(Color.goPrimary)
                                    .frame(width: 28)
                                Text(l.language)
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Picker("", selection: $appLanguage) {
                                    ForEach(AppLanguage.supported) { language in
                                        Text(language.displayName).tag(language.code)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .foregroundStyle(primaryText)

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            HStack(spacing: 12) {
                                Image(systemName: selectedMeasurementSystem.systemIconName)
                                    .foregroundStyle(Color.goTeal)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.measurementUnits)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(l.measurementUnitsHint)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
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
                            .padding(.top, 8)

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            HStack {
                                Image(systemName: selectedCurrency.systemIconName)
                                    .foregroundStyle(Color.goYellow)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.currency)
                                        .font(.system(size: 15, weight: .medium))
                                    Text(l.currencyDisplayOnlyHint)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
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
                                    HStack(spacing: 5) {
                                        Text(selectedCurrency.displayName)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 9, weight: .black))
                                    }
                                    .foregroundStyle(primaryText)
                                }
                            }
                            .foregroundStyle(primaryText)
                            .padding(.top, 8)
                            
                            // 外观主题
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundStyle(accentColor)
                                    .frame(width: 28)
                                Text(l.appearance)
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Picker("", selection: $appThemePreference) {
                                    Text(l.themeSystem).tag("system")
                                    Text(l.themeLight).tag("light")
                                    Text(l.themeDark).tag("dark")
                                }
                                .pickerStyle(.menu)
                            }
                            .foregroundStyle(primaryText)
                            .padding(.top, 8)

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
                                                    .fill(Color.goPrimary.opacity(0.1))
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
                                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                                    .background(Color.goYellow.opacity(0.1), in: Capsule())
                                            }
                                            .buttonStyle(.plain)
                                            // 删除宠物
                                            Button {
                                                petToDelete = pet
                                                deleteConfirmName = ""
                                                showingDeletePetSheet = true
                                            } label: {
                                                Text("删除")
                                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                                    .foregroundStyle(Color.goRed.opacity(0.8))
                                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                                    .background(Color.goRed.opacity(0.1), in: Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            .alert("删除 \(petToDelete?.name ?? "")", isPresented: $showingDeletePetSheet) {
                                TextField("输入宠物名字确认", text: $deleteConfirmName)
                                Button("取消", role: .cancel) { deleteConfirmName = "" }
                                Button("删除", role: .destructive) {
                                    if let p = petToDelete, deleteConfirmName == p.name {
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
                                PerformanceDiagnosticsView()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.goPrimary.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "speedometer")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.goPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("性能诊断面板")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text("启动 · 首页首帧 · 头像 · 点击 · 相机链路")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(tertiaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(tertiaryText.opacity(0.6))
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }

                        // 数据
                        settingsSection(title: "数据") {
                            VStack(spacing: 0) {
                                settingsRow(icon: "square.and.arrow.up", title: "导出数据", subtitle: "即将推出") {}
                                OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                                settingsRow(icon: "exclamationmark.triangle", title: "清除所有数据", subtitle: "") {
                                    showingClearDataAlert = true
                                }
                                .foregroundStyle(.red)
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
                    .padding(.top, 8)
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
                .preferredColorScheme(preferredScheme)

                Button {
                    showingOnboardingReplay = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(20)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - 设备身份绑定卡
    private var deviceIdentitySection: some View {
        settingsSection(title: "设备身份") {
            VStack(alignment: .leading, spacing: 12) {
                Text("这台手机的主人是谁？")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        /* Removing "Unbind" option to enforce mandatory identity */

                        ForEach(humans) { human in
                            let isSelected = currentActiveHumanId == human.id.uuidString
                            Button {
                                currentActiveHumanId = human.id.uuidString
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(isSelected ? Color.goPrimary.opacity(0.2) : Color.white.opacity(0.08))
                                            .frame(width: 44, height: 44)
                                            .overlay(Circle().strokeBorder(isSelected ? Color.goPrimary : Color.clear, lineWidth: 2))
                                        if let data = human.avatarImageData, let img = UIImage(data: data) {
                                            Image(uiImage: img)
                                                .resizable().scaledToFill()
                                                .frame(width: 44, height: 44).clipShape(Circle())
                                        } else {
                                            Text(human.avatarEmoji).font(.system(size: 20))
                                        }
                                    }
                                    Text(human.name.isEmpty ? "成员" : human.name)
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSelected ? Color.goPrimary : .white.opacity(0.4))
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
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

    // MARK: - Backup Section（TASK 1）
    @ViewBuilder
    private var backupSection: some View {
        settingsSection(title: "数据备份") {
            VStack(spacing: 0) {
                // ── 导出行
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.goTeal.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.goTeal)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("导出备份")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryText)
                        Text("全量 JSON · 含所有宠物、日志、状态")
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
                        .buttonStyle(.plain)
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                // ── 导入行
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.goOrange.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.goOrange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("从备份恢复")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryText)
                        Text("选择 .json 备份文件导入")
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)

                OhanaDashedDivider(color: dividerLine).padding(.leading, 44).padding(.vertical, 2)

                // ── 说明行
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.goYellow.opacity(0.6))
                    Text("备份含全部宠物、家庭成员、日志、健康档案及应用状态。恢复时以 UUID 去重，不会清除现有数据。")
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
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
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
    }

    private func applyCountryDefaults(_ country: AppCountry.Option) {
        AppCountry.applyDefaults(for: country.code)
        appCountry = country.code
        appLanguage = AppLanguage.normalize(country.defaultLanguageCode)
        appMeasurementSystem = AppMeasurementSystem.normalize(country.defaultMeasurementSystemCode)
        appCurrency = AppCurrency.normalize(country.defaultCurrencyCode)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Profile Card
    private var profileCard: some View {
        glassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.14))
                        .frame(width: 64, height: 64)
                        .overlay(Circle().strokeBorder(Color.goPrimary.opacity(0.35), lineWidth: 1.5))
                    Image(systemName: "person.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(userNickname.isEmpty ? "Ohana 岛民" : userNickname)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(primaryText)
                    Text("本地模式")
                        .font(OhanaFont.caption(.medium))
                        .foregroundStyle(tertiaryText)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(secondaryText)
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(20)
        }
    }
    
    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                .padding(16)
            }
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.goPrimary.opacity(colorScheme == .dark ? 0.16 : 0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
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
            .padding(.vertical, 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var performanceToggleRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.goLime.opacity(colorScheme == .dark ? 0.16 : 0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: "battery.75percent")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goLime)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("省电模式")
                    .font(OhanaFont.body(.semibold))
                    .foregroundStyle(primaryText)
                Text("减少背景动效和首页持续渲染")
                    .font(OhanaFont.footnote())
                    .foregroundStyle(tertiaryText)
            }
            Spacer()
            Toggle("", isOn: $powerSavingMode)
                .tint(Color.goLime)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    private func notificationToggleRow(icon: String, iconColor: Color, title: String, key: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(colorScheme == .dark ? 0.16 : 0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
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
        .padding(.vertical, 4)
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
        if reduceTransparency {
            content()
                .background(Color(.systemBackground).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            content()
                .background(
                    (colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.76)),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 12, x: 0, y: 6)
        }
    }
}

private struct PerformanceDiagnosticsView: View {
    @ObservedObject private var monitor = AppPerformanceMonitor.shared
    @Environment(\.colorScheme) private var colorScheme

    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1026")
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.68) : Color(hex: "3B4266").opacity(0.72)
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
                                    OhanaDashedDivider(color: .white.opacity(0.12))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )

                    Button {
                        monitor.clear()
                    } label: {
                        Label("清空样本", systemImage: "trash")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
        .background(.white.opacity(colorScheme == .dark ? 0.08 : 0.18),
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
