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
    @AppStorage("appThemePreference") private var appThemePreference: String = "system"
    @AppStorage("appBackgroundStyle") private var appBackgroundStyle: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage("appUIStyle") private var appUIStyle: String = "go"
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
    @State private var showingFocusStackTest = false
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
    
    private var isMaterial: Bool { false }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var matAccent: Color { Color(hex: "FF7600") }

    private var accentColor: Color { Color.goPrimary }

    var body: some View {
        NavigationStack {
            ZStack {
                if isMaterial {
                    matBg.ignoresSafeArea()
                } else {
                    ArkBackgroundView()
                }
                
                ScrollView {
                    VStack(spacing: 18) {
                        // Profile Card
                        profileCard

                        // 设备身份绑定
                        if !humans.isEmpty {
                            deviceIdentitySection
                        }
                        
                        // 昵称
                        settingsSection(title: "个人信息") {
                            settingsRow(icon: "person.fill", title: "昵称", subtitle: userNickname.isEmpty ? "未设置" : userNickname) {
                                editingNickname = userNickname
                                showingNicknameEdit = true
                            }
                        }
                        .alert("修改昵称", isPresented: $showingNicknameEdit) {
                            TextField("输入昵称", text: $editingNickname)
                            Button("保存") { userNickname = editingNickname }
                            Button("取消", role: .cancel) {}
                        }
                        
                        // 语言
                        settingsSection(title: "偏好设置") {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundStyle(Color.goPrimary)
                                    .frame(width: 28)
                                Text("语言")
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
                            
                            // 外观主题
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundStyle(accentColor)
                                    .frame(width: 28)
                                Text("外观主题")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Picker("", selection: $appThemePreference) {
                                    Text("跟随系统").tag("system")
                                    Text("浅色模式").tag("light")
                                    Text("深色模式").tag("dark")
                                }
                                .pickerStyle(.menu)
                            }
                            .foregroundStyle(primaryText)
                            .padding(.top, 8)

                            // UI 风格
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "paintbrush.pointed.fill")
                                        .foregroundStyle(Color.goPrimary)
                                        .frame(width: 28)
                                    Text("UI 风格")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(primaryText)
                                    Spacer()
                                }

                                HStack(spacing: 10) {
                                    UIStyleCard(
                                        title: "经典",
                                        subtitle: "iOS 26 液态玻璃",
                                        icon: "sparkles",
                                        accentColor: Color.goPrimary,
                                        bgColors: [Color(hex: "0A0A0C"), Color(hex: "141FAE")],
                                        isSelected: appUIStyle == "classic",
                                        onTap: { appUIStyle = "classic" }
                                    )
                                    UIStyleCard(
                                        title: "GO UI",
                                        subtitle: "蓝色步数运动风",
                                        icon: "figure.walk",
                                        accentColor: Color(hex: "22D3EE"),
                                        bgColors: [Color(hex: "3B5BDB"), Color(hex: "0F1640")],
                                        isSelected: appUIStyle == "go",
                                        onTap: { appUIStyle = "go" }
                                    )
                                }
                            }
                            .padding(.top, 8)

                        // 背景风格
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.goPrimary)
                                        .frame(width: 28)
                                    Text("背景风格")
                                        .font(.system(size: 15, weight: .medium))
                                    Spacer()
                                }
                                .foregroundStyle(primaryText)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(AppBackgroundStyle.allCases) { style in
                                            BackgroundStyleCard(
                                                style: style,
                                                isSelected: appBackgroundStyle == style.rawValue,
                                                onTap: { appBackgroundStyle = style.rawValue }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                            .padding(.top, 8)

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)
                            settingsRow(icon: "sparkles.tv", title: "查看引导页", subtitle: "重新播放首次启动引导，方便测试") {
                                showingOnboardingReplay = true
                            }
                        }
                        
                        // 通知
                        settingsSection(title: "通知") {
                            settingsRow(icon: "bell.badge", title: "通知权限", subtitle: "管理系统级通知授权") {
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
                                PetThemeUIUXMergedView()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.goPrimary.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "pawprint.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.goPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("宠物主题 UI/UX 规范页")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text("已合并 Material UI + 主题规范")
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

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            NavigationLink {
                                iOS26UITestView()
                                    .navigationBarBackButtonHidden()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.goPrimary.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "wand.and.sparkles")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.goPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("iOS 26 UI 测试页")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text("Liquid Glass 原生 .glassEffect() API 展示")
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

                            OhanaDashedDivider(color: dividerLine).padding(.leading, 44)

                            Button {
                                showingFocusStackTest = true
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.goPrimary.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "rectangle.stack.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.goPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("GO Focus 堆叠测试页")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(primaryText)
                                        Text("截图风格堆叠 · 单体页 · 快捷打卡")
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
            .navigationTitle(isMaterial ? "" : "设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        if isMaterial {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(tertiaryText)
                                .frame(width: 32, height: 32)
                                .background(matSurface, in: Circle())
                                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if isMaterial {
                        Text("Settings")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                }
            }
        }
        .preferredColorScheme(preferredScheme)
        .fullScreenCover(isPresented: $showingFocusStackTest) {
            FocusStackHomeTestViewPreviewWrapper()
                .preferredColorScheme(preferredScheme)
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tertiaryText.opacity(0.6))
            }
            .padding(20)
        }
    }
    
    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if isMaterial {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(tertiaryText)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(matSurface, in: Capsule())
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.leading, 4)
            } else {
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
            }

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
        .buttonStyle(.plain)
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
        if isMaterial {
            content()
                .background(matSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        } else if reduceTransparency {
            content()
                .background(Color(.systemBackground).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            content()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

// MARK: - Background Style Card（背景风格预览卡）
private struct BackgroundStyleCard: View {
    let style: AppBackgroundStyle
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(style.previewColors[0])
                        .frame(width: 64, height: 48)
                    // 两个小光球预览
                    Circle()
                        .fill(style.previewColors.count > 1 ? style.previewColors[1] : .clear)
                        .frame(width: 20)
                        .blur(radius: 6)
                        .offset(x: -10, y: -6)
                    Circle()
                        .fill(style.previewColors.count > 2 ? style.previewColors[2] : .clear)
                        .frame(width: 16)
                        .blur(radius: 5)
                        .offset(x: 10, y: 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Color.goPrimary : .white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                )

                Text(style.displayName)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.goPrimary : .primary.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UI Style Card（UI 风格预览卡）
private struct UIStyleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let bgColors: [Color]
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Preview thumbnail
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: bgColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    // Mock card strips
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.15))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.10))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor.opacity(0.5))
                            .frame(height: 6)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                        .padding(6)
                }
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? accentColor : .white.opacity(0.15),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? accentColor : .primary)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
