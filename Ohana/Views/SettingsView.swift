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
    @AppStorage("appLanguage") private var appLanguage = "zh"
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
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    
    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                
                ScrollView {
                    VStack(spacing: 16) {
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
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                Text("语言")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                Picker("", selection: $appLanguage) {
                                    Text("中文").tag("zh")
                                    Text("English").tag("en")
                                }
                                .pickerStyle(.menu)
                            }
                            .foregroundStyle(.primary)
                        }
                        
                        // 通知
                        settingsSection(title: "通知") {
                            settingsRow(icon: "bell.badge", title: "通知权限", subtitle: "管理通知设置") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        
                        // ── 备份与恢复
                        backupSection

                        // 关于
                        settingsSection(title: "关于") {
                            VStack(spacing: 0) {
                                settingsRow(icon: "info.circle", title: "版本", subtitle: "v4.5.0") {}
                                GoDashedDivider().padding(.leading, 44)
                                settingsRow(icon: "star.fill", title: "评价 App", subtitle: "") {
                                    if let url = URL(string: "https://apps.apple.com/app/id6742117937?action=write-review") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                GoDashedDivider().padding(.leading, 44)
                                settingsRow(icon: "lock.shield", title: "隐私政策", subtitle: "") {}
                                GoDashedDivider().padding(.leading, 44)
                                settingsRow(icon: "envelope", title: "联系开发者", subtitle: "") {}
                            }
                        }
                        
                        // 宠物管理
                        if !pets.isEmpty {
                            settingsSection(title: "宠物管理") {
                                VStack(spacing: 0) {
                                    ForEach(Array(pets.enumerated()), id: \.element.id) { i, pet in
                                        if i > 0 { GoDashedDivider().padding(.leading, 44) }
                                        HStack(spacing: 10) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.goLime.opacity(0.08))
                                                    .frame(width: 32, height: 32)
                                                Text(pet.avatarEmoji)
                                                    .font(.system(size: 16))
                                            }
                                            Text(pet.name)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
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
                                OhanaUIDemoView()
                                    .navigationBarBackButtonHidden()
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.goPrimary.opacity(0.12))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "paintpalette.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.goPrimary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("UI 规范测试")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("查看所有 UI 元素的 Light/Dark 表现")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.2))
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }

                        // 数据
                        settingsSection(title: "数据") {
                            VStack(spacing: 0) {
                                settingsRow(icon: "square.and.arrow.up", title: "导出数据", subtitle: "即将推出") {}
                                GoDashedDivider().padding(.leading, 44)
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
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 设备身份绑定卡
    private var deviceIdentitySection: some View {
        settingsSection(title: "设备身份") {
            VStack(alignment: .leading, spacing: 12) {
                Text("这台手机的主人是谁？")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // "未绑定" 选项
                        Button {
                            currentActiveHumanId = ""
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(currentActiveHumanId.isEmpty ? Color.goLime.opacity(0.2) : Color.white.opacity(0.08))
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().strokeBorder(currentActiveHumanId.isEmpty ? Color.goLime : Color.clear, lineWidth: 2))
                                    Text("👤").font(.system(size: 20))
                                }
                                Text("未绑定")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(currentActiveHumanId.isEmpty ? Color.goLime : .white.opacity(0.4))
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(humans) { human in
                            let isSelected = currentActiveHumanId == human.id.uuidString
                            Button {
                                currentActiveHumanId = human.id.uuidString
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(isSelected ? Color.goLime.opacity(0.2) : Color.white.opacity(0.08))
                                            .frame(width: 44, height: 44)
                                            .overlay(Circle().strokeBorder(isSelected ? Color.goLime : Color.clear, lineWidth: 2))
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
                                        .foregroundStyle(isSelected ? Color.goLime : .white.opacity(0.4))
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
                            .foregroundStyle(Color.goLime)
                            .font(.system(size: 12))
                        Text("打卡记录将关联到 \(selected.name)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
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
                            .foregroundStyle(.white)
                        Text("全量 JSON · 含所有宠物、日志、状态")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
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

                GoDashedDivider().padding(.leading, 44).padding(.vertical, 2)

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
                            .foregroundStyle(.white)
                        Text("选择 .json 备份文件导入")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
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

                GoDashedDivider().padding(.leading, 44).padding(.vertical, 2)

                // ── 说明行
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.goYellow.opacity(0.6))
                    Text("备份含全部宠物、家庭成员、日志、健康档案及应用状态。恢复时以 UUID 去重，不会清除现有数据。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
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
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.goLime.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().strokeBorder(Color.goLime.opacity(0.3), lineWidth: 1.5))
                Image(systemName: "person.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.goLime)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(userNickname.isEmpty ? "Ohana 岛民" : userNickname)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("本地模式")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(20)
        .goTranslucentCard(cornerRadius: 24)
    }
    
    // MARK: - Settings Section
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
                .padding(.leading, 4)
            content()
                .padding(14)
                .goTranslucentCard(cornerRadius: 18)
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.goLime.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.goLime)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
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
        for log in pet.weightLogs   { modelContext.delete(log) }
        for log in pet.expenseLogs  { modelContext.delete(log) }
        for log in pet.healthLogs   { modelContext.delete(log) }
        for log in pet.hygieneLogs  { modelContext.delete(log) }
        for log in pet.walkLogs     { modelContext.delete(log) }
        for log in pet.pottyLogs    { modelContext.delete(log) }
        for log in pet.foodRecords  { modelContext.delete(log) }
        for log in pet.careLogs     { modelContext.delete(log) }
        let petIdStr = pet.id.uuidString
        if let events = try? modelContext.fetch(FetchDescriptor<Event>()) {
            for event in events where event.relatedEntityId == petIdStr {
                modelContext.delete(event)
            }
        }
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: Pet.self)
            try modelContext.delete(model: Event.self)
            try modelContext.delete(model: Reminder.self)
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Clear data error: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}
