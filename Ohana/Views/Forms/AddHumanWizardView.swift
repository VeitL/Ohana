//
//  AddHumanWizardView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddHumanWizardView: View {
    let onComplete: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    @State private var currentStep = 0
    @State private var name = ""
    @State private var avatarEmoji = "�"
    @State private var avatarImageData: Data? = nil
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var cropImageItem: IdentifiableCropImage? = nil
    @State private var showDuplicateNameAlert = false
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var bloodType = ""
    @State private var role = "owner"
    // N12: 新增字段
    @State private var gender = ""         // "男"/"女"/"其他"/""
    @State private var familyRole = ""     // 妈妈/妈妈/爷爷 等
    @State private var nationality = ""    // 国籍/城市
    @State private var notes = ""          // 备注
    // FIX 1: 身体数据
    @State private var heightText = ""
    @State private var weightText = ""
    // FIX 1: 隐私设置
    @State private var privateWeight = false
    @State private var privateWorkout = false
    @State private var privateWishlist = false
    @State private var privateExpense = false
    // 主题色
    @State private var themeColorHex: String = "667eea"
    private let themeColorOptions: [(String, String)] = [
        ("667eea", "靛蓝"), ("FF6B6B", "珊瑚"), ("4ECDC4", "海洋"),
        ("C8FF00", "青柠"), ("FFD3B6", "蜜桃"), ("AA96DA", "薰衣草"),
        ("95E1D3", "薄荷"), ("F38181", "晚霞")
    ]

    private let emojiOptions = ["👤", "👨", "👩", "🧑", "👦", "👧", "👴", "👵", "🧔", "👱‍♀️", "👩‍🦰", "🧑‍🦱",
                                "🧒", "👨‍🦳", "👩‍🦳", "🧓", "👨‍🦲", "👩‍🦲", "🧑‍🦱", "👱", "🥷", "🧑‍🍳", "🧑‍💻", "🧑‍🎨"]
    private let bloodTypes = ["", "A", "B", "AB", "O"]
    private let genderOptions = [("男", "♂️"), ("女", "♀️"), ("其他", "⚧️")]
    private let familyRoleOptions = ["爸爸", "妈妈", "爷爷", "奶奶", "外公", "外婆",
                                     "哥哥", "姐姐", "弟弟", "妹妹", "朋友", "自定义"]
    private let totalSteps = 9

    private var isNameDuplicate: Bool {
        let candidate = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty else { return false }
        let petNames = existingPets.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        let humanNames = existingHumans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        return petNames.contains(candidate) || humanNames.contains(candidate)
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .tint(Color(hex: "667eea"))
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            Text("步骤 \(currentStep + 1)/\(totalSteps)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
                .padding(.top, 4)
            
            TabView(selection: $currentStep) {
                // Step 1: 姓名 + 头像
                wizardStep(title: "姓名", subtitle: "输入家庭成员的名字") {
                    VStack(spacing: 20) {
                        TextField("姓名", text: $name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.primary)
                            .padding()
                            .ohanaGlassStyle(cornerRadius: 16)

                        // 重名提示
                        if isNameDuplicate {
                            Label("Ohana 里已有同名家人，换个名字吧", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.goRed)
                                .transition(.opacity.combined(with: .scale))
                        }

                        // 头像区域
                        ZStack {
                            Circle()
                                .fill(Color(hex: "667eea").opacity(0.2))
                                .frame(width: 90, height: 90)
                            if let data = avatarImageData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            } else {
                                Text(avatarEmoji)
                                    .font(.system(size: 48))
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Menu {
                                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                                    Label("从相册选择", systemImage: "photo.on.rectangle")
                                }
                                Button { showingCamera = true } label: {
                                    Label("拍照", systemImage: "camera")
                                }
                            } label: {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color(hex: "667eea"))
                                    .background(Circle().fill(.white).frame(width: 22, height: 22))
                            }
                        }

                        // ── 剪贴板抠图捷径
                        Button { pastePasteboardImage() } label: {
                            Label("粘贴已抠主体", systemImage: "clipboard.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.goYellow)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color.goYellow.opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.goYellow.opacity(0.35), lineWidth: 1.5))
                        }
                        Text("相册长按人物 → 拷贝主体 → 回来粘贴")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.25))
                            .multilineTextAlignment(.center)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button {
                                    avatarEmoji = emoji
                                    avatarImageData = nil
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 44, height: 44)
                                        .background(
                                            avatarEmoji == emoji && avatarImageData == nil ? Color(hex: "667eea").opacity(0.3) : .clear,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                            }
                        }
                    }
                }
                .tag(0)
                
                // Step 2: 生日
                wizardStep(title: "生日", subtitle: "可选") {
                    VStack(spacing: 20) {
                        Toggle("设置生日", isOn: $hasBirthday)
                            .tint(Color(hex: "667eea"))
                            .foregroundStyle(.primary)
                        
                        if hasBirthday {
                            DatePicker("生日", selection: $birthday, displayedComponents: .date)
                                .datePickerStyle(.wheel)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .tag(1)
                
                // Step 3: 血型
                wizardStep(title: "血型", subtitle: "可选") {
                    HStack(spacing: 12) {
                        ForEach(bloodTypes, id: \.self) { bt in
                            Button {
                                bloodType = bt
                            } label: {
                                Text(bt.isEmpty ? "跳过" : bt)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(bloodType == bt ? .white : .white.opacity(0.5))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        bloodType == bt ? Color(hex: "667eea").opacity(0.4) : .white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(bloodType == bt ? .white.opacity(0.3) : .clear, lineWidth: 1)
                                    }
                            }
                        }
                    }
                }
                .tag(2)
                
                // Step 4: 性别
                wizardStep(title: "性别", subtitle: "可选") {
                    HStack(spacing: 14) {
                        ForEach(genderOptions, id: \.0) { option in
                            Button { gender = (gender == option.0 ? "" : option.0) } label: {
                                VStack(spacing: 8) {
                                    Text(option.1).font(.system(size: 28))
                                    Text(option.0)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(gender == option.0 ? .white : .white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 18)
                                .background(
                                    gender == option.0
                                        ? Color(hex: "667eea").opacity(0.4)
                                        : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 16)
                                )
                            }
                        }
                    }
                    Button { gender = "" } label: {
                        Text("跳过")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                    .padding(.top, 4)
                }
                .tag(3)

                // Step 5: 家庭关系
                wizardStep(title: "家庭关系", subtitle: "在家庭中是什么角色？（可选）") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(familyRoleOptions, id: \.self) { opt in
                            Button {
                                familyRole = (familyRole == opt ? "" : opt)
                            } label: {
                                Text(opt)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(familyRole == opt ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(
                                        familyRole == opt
                                            ? Color(hex: "667eea").opacity(0.45)
                                            : Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                        }
                    }
                    if familyRole == "自定义" {
                        TextField("输入自定义关系", text: $familyRole)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(12)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 4)
                    }
                }
                .tag(4)

                // Step 6: 国籍 + 备注
                wizardStep(title: "更多信息", subtitle: "国籍与备注（可选）") {
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(Color(hex: "667eea")).frame(width: 24)
                            TextField("国籍 / 城市（可选）", text: $nationality)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                        HStack(alignment: .top) {
                            Image(systemName: "note.text")
                                .foregroundStyle(.secondary).frame(width: 24).padding(.top, 2)
                            TextField("备注（可选）", text: $notes, axis: .vertical)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(3...5)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .tag(5)

                // Step 7: 身体数据
                wizardStep(title: "身体数据", subtitle: "可选，用于记录体重唱化") {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "ruler")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.goTeal)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("身高")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                TextField("如 170", text: $heightText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            Text("cm")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                        HStack(spacing: 12) {
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.goPrimary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("体重")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                TextField("如 65.0", text: $weightText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            Text("kg")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                        Text("填写体重将自动创建一条初始体重记录")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .tag(6)

                // Step 8: 隐私设置
                wizardStep(title: "隐私设置", subtitle: "哪些信息只有你自己可见？") {
                    VStack(spacing: 12) {
                        Text("同一设备上的其他家庭成员无法查看被隐藏的内容")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.35))
                            .multilineTextAlignment(.center)

                        privacyToggleRow("体重记录与图表", emoji: "⚖️", binding: $privateWeight)
                        privacyToggleRow("运动记录", emoji: "🏋️", binding: $privateWorkout)
                        privacyToggleRow("心愿单", emoji: "🎁", binding: $privateWishlist)
                        privacyToggleRow("花费记录", emoji: "💸", binding: $privateExpense)
                    }
                }
                .tag(7)

                // Step 9: 角色 + 确认
                wizardStep(title: "确认信息", subtitle: "一切就绪！") {
                    VStack(spacing: 16) {
                        // 头像 + 主题色圆圈
                        ZStack(alignment: .bottomTrailing) {
                            Text(avatarEmoji)
                                .font(.system(size: 60))
                            Circle()
                                .fill(Color(hex: themeColorHex))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                                .offset(x: 4, y: 4)
                        }

                        Text(name.isEmpty ? "未命名" : name)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)

                        // 主题色选择器
                        VStack(alignment: .leading, spacing: 8) {
                            Text("主题颜色")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                                .padding(.horizontal, 4)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(themeColorOptions, id: \.0) { hex, label in
                                        Button { themeColorHex = hex } label: {
                                            VStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color(hex: hex))
                                                    .frame(width: 34, height: 34)
                                                    .overlay(Circle().strokeBorder(
                                                        themeColorHex == hex ? Color.white : Color.clear,
                                                        lineWidth: 2.5))
                                                    .shadow(color: Color(hex: hex).opacity(0.6), radius: themeColorHex == hex ? 8 : 0)
                                                    .scaleEffect(themeColorHex == hex ? 1.15 : 1.0)
                                                    .animation(.spring(response: 0.2), value: themeColorHex)
                                                Text(label)
                                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                                    .foregroundStyle(.primary.opacity(themeColorHex == hex ? 1 : 0.4))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        // 角色选择
                        VStack(spacing: 8) {
                            roleOption(role: "owner", title: "主人", description: "家庭管理者，拥有所有权限")
                            roleOption(role: "editor", title: "编辑", description: "可以添加和编辑记录")
                            roleOption(role: "viewer", title: "查看", description: "只能查看信息")
                        }

                        FlowTagRow(tags: [
                            gender.isEmpty ? nil : gender,
                            familyRole.isEmpty ? nil : familyRole,
                            bloodType.isEmpty ? nil : "血型\(bloodType)",
                            nationality.isEmpty ? nil : nationality,
                        ].compactMap { $0 })
                    }
                }
                .tag(8)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.4), value: currentStep)
            
            // Navigation
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button {
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Text("上一步")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                
                if currentStep < totalSteps - 1 {
                    Button {
                        if currentStep == 0 && isNameDuplicate {
                            showDuplicateNameAlert = true
                            return
                        }
                        withAnimation { currentStep += 1 }
                    } label: {
                        Text("下一步")
                            .capsuleButton()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(currentStep == 0 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button {
                        if isNameDuplicate { showDuplicateNameAlert = true; return }
                        saveHuman()
                    } label: {
                        Text("完成 🎉")
                            .neonCapsuleButton()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(name.isEmpty)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onChange(of: photosPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run {
                        cropImageItem = IdentifiableCropImage(image: ui)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            PetCameraPickerView { img in
                showingCamera = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    cropImageItem = IdentifiableCropImage(image: img)
                }
            }
        }
        .sheet(item: $cropImageItem) { item in
            ImageCutoutPreviewSheet(image: item.image) { finalData, _ in
                avatarImageData = finalData
                cropImageItem = nil
            }
        }
        .alert("名字已被占用 🏠", isPresented: $showDuplicateNameAlert) {
            Button("好的，我换一个", role: .cancel) { }
        } message: {
            Text("Ohana 里已经有一个叫「\(name.trimmingCharacters(in: .whitespaces))」的家人啊，换个名字吧！")
        }
    }
    
    private var roleText: String {
        switch role {
        case "owner": return "主人"
        case "editor": return "编辑"
        case "viewer": return "查看"
        default: return role
        }
    }
    
    private func roleOption(role: String, title: String, description: String) -> some View {
        Button {
            self.role = role
        } label: {
            HStack(spacing: 12) {
                Image(systemName: self.role == role ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(self.role == role ? Color(hex: "667eea") : .white.opacity(0.3))
                    .font(.system(size: 22))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
            }
            .padding(14)
            .ohanaGlassStyle(cornerRadius: 16)
        }
    }
    
    @ViewBuilder
    private func wizardStep<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.6))
            }
            content()
                .padding(.horizontal, 24)
            Spacer()
        }
    }
    
    /// 从剪贴板读取图片（支持透明通道 PNG，即系统相册「拷贝主体」）
    private func pastePasteboardImage() {
        guard let image = UIPasteboard.general.image else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let pngData = image.pngData() {
            avatarImageData = pngData
        } else if let jpgData = image.jpegData(compressionQuality: 0.92) {
            avatarImageData = jpgData
        }
    }

    private func saveHuman() {
        let human = Human(
            name: name.trimmingCharacters(in: .whitespaces),
            birthday: hasBirthday ? birthday : nil,
            bloodType: bloodType,
            avatarEmoji: avatarEmoji,
            role: role
        )
        // N12: 保存扩展字段到 notes（格式化存储）
        var noteParts: [String] = []
        if !gender.isEmpty { noteParts.append("性别:\(gender)") }
        if !familyRole.isEmpty { noteParts.append("关系:\(familyRole)") }
        if !nationality.isEmpty { noteParts.append("国籍:\(nationality)") }
        if !notes.isEmpty { noteParts.append(notes) }
        human.notes = noteParts.joined(separator: "｜")
        human.avatarImageData = avatarImageData
        human.themeColorHex = themeColorHex
        // FIX 1: 身体数据
        if let h = Double(heightText), h > 0 { human.heightCm = h }
        // FIX 1: 隐私字段
        var privFields: Set<String> = []
        if privateWeight   { privFields.insert("weight") }
        if privateWorkout  { privFields.insert("workout") }
        if privateWishlist { privFields.insert("wishlist") }
        if privateExpense  { privFields.insert("expense") }
        human.privateFields = privFields
        modelContext.insert(human)

        // FIX 1: 若填写了体重，自动创建初始 HumanWeightLog
        if let w = Double(weightText), w > 0 {
            let log = HumanWeightLog(date: Date(), weight: w, human: human)
            modelContext.insert(log)
        }

        if hasBirthday {
            let event = Event(
                title: "\(name) 的生日 🎂",
                startDate: birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: "Human",
                relatedEntityId: human.id.uuidString
            )
            event.recurrenceDays = 365
            modelContext.insert(event)
        }

        modelContext.safeSave()
        onComplete()
    }

    // FIX 1: 隐私 Toggle 行
    private func privacyToggleRow(_ title: String, emoji: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 22)).frame(width: 32)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: binding)
                .tint(Color.goPrimary)
                .labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Flow Tag Row
private struct FlowTagRow: View {
    let tags: [String]
    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Color(hex: "667eea").opacity(0.3), in: Capsule())
                    }
                }
            }
        }
    }
}
