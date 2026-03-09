//
//  AddPetWizardView.swift
//  Ohana
//
//  全面重写：品种被动选择、拍照/相册取景框、生日年龄换算、到家天数、出生地、护照/chip、毛色/瞳色
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Steps enum
private enum WizardStep: Int, CaseIterable {
    case basicInfo = 0
    case breed
    case avatar
    case dates
    case gender
    case birthplace
    case identity
    case appearance
    case familyRelation
    case confirm

    var title: String {
        switch self {
        case .basicInfo:      return "你的小怪兽叫什么？"
        case .breed:          return "选择品种"
        case .avatar:         return "设置头像"
        case .dates:          return "重要日期"
        case .gender:         return "性别与健康"
        case .birthplace:     return "出生地"
        case .identity:       return "证件信息"
        case .appearance:     return "外貌特征"
        case .familyRelation: return "家庭关系"
        case .confirm:        return "确认信息"
        }
    }
    var subtitle: String {
        switch self {
        case .basicInfo:      return "名字为必填项"
        case .breed:          return "按字母排序，可搜索"
        case .avatar:         return "拍照或从相册选择"
        case .dates:          return "生日和到家日"
        case .gender:         return "性别与绝育状态"
        case .birthplace:     return "出生国家和城市（选填）"
        case .identity:       return "护照号和芯片号（选填）"
        case .appearance:     return "毛色、瞳色和主题颜色"
        case .familyRelation: return "选择与现有宠物的关系（选填）"
        case .confirm:        return "一切准备就绪！"
        }
    }
}

struct AddPetWizardView: View {
    let onComplete: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    @State private var currentStep: WizardStep = .basicInfo
    @State private var isSaving = false
    @State private var name = ""
    @State private var species = "狗"
    @State private var breed = ""
    @State private var breedSearch = ""
    @State private var isCustomBreed = false
    @State private var customBreedText = ""
    @State private var avatarImageData: Data? = nil
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var cropImageItem: IdentifiableCropImage? = nil
    @State private var hasBirthday = true
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var hasHomeDate = false
    @State private var homeDate = Date()
    @State private var gender = "unknown"
    @State private var isNeutered = false
    @State private var birthCountry = ""
    @State private var birthCity = ""
    @State private var isCustomCity = false
    @State private var customCity = ""
    @State private var passportNumber = ""
    @State private var microchipID = ""
    @State private var coatColor = ""
    @State private var eyeColor = ""
    @State private var themeColorHex = "C8FF00"
    @State private var showCoatColorPicker = false
    @State private var showEyeColorPicker = false
    @State private var customCoatUIColor: Color = .white
    @State private var customEyeUIColor: Color = .white
    @State private var showCoatColorSheet = false
    @State private var showEyeColorSheet = false
    // 家庭关系选择
    @State private var selectedRelations: [(petId: UUID, type: PetRelationshipType)] = []
    // P2: 卡片风格
    @State private var cardStyle: String = "classic"
    // 抠像处理状态
    @State private var isProcessingCutout = false
    // 重名防护
    @State private var showDuplicateNameAlert = false
    // Q4: 椰子奖励动画状态
    @State private var showCoconutBurst = false
    @State private var coconutBurstScale: CGFloat = 0.3
    @State private var coconutBurstOpacity: Double = 0.0

    private let speciesOptions = ["狗", "猫", "兔子", "仓鼠", "鸟", "其他"]
    private let totalSteps = WizardStep.allCases.count
    
    // MARK: - Computed helpers
    private var accentColor: Color { Color(hex: themeColorHex) }
    private var avatarInitial: String { name.isEmpty ? "?" : String(name.prefix(1)) }
    private var canProceed: Bool {
        if currentStep == .basicInfo {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !isNameDuplicate
        }
        return true
    }

    /// 全岛名字冲突检查（忽略大小写和首尾空格）
    private var isNameDuplicate: Bool {
        let candidate = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty else { return false }
        let petNames = existingPets.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        let humanNames = existingHumans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        return petNames.contains(candidate) || humanNames.contains(candidate)
    }

    // 任务6：已被占用的主题色 hex 集合（排除当前正在编辑的实体）
    private var usedThemeColorHexes: Set<String> {
        Set(existingPets.map { $0.themeColorHex.uppercased() })
    }

    private var currentBreeds: [BreedInfo] {
        let all = PetBreedDatabase.breeds(for: species)
        guard !breedSearch.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(breedSearch) }
    }
    private var selectedBreedInfo: BreedInfo? {
        PetBreedDatabase.breeds(for: species).first { $0.name == breed }
    }
    private var humanAgeText: String {
        guard hasBirthday else { return "" }
        return PetAgeConverter.humanAge(birthday: birthday, species: species)
    }
    private var daysTogetherText: String {
        guard hasHomeDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: homeDate, to: Date()).day ?? 0
        if days < 0 { return "还有 \(-days) 天到家" }
        if days == 0 { return "今天到家 🎉" }
        return "已陪伴 \(days) 天"
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()

            // Q4: 椰子暑盗奖励覆盖层
            if showCoconutBurst {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("🥥")
                            .font(.system(size: 72))
                        Text("+50 🥥")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goYellow)
                        Text("岛屿欢迎新家人！")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .scaleEffect(coconutBurstScale)
                    .opacity(coconutBurstOpacity)
                }
                .zIndex(999)
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                // Progress bar
                VStack(spacing: 4) {
                    ProgressView(value: Double(currentStep.rawValue + 1), total: Double(totalSteps))
                        .tint(accentColor)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    Text("步骤 \(currentStep.rawValue + 1) / \(totalSteps)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }

                // Title
                VStack(spacing: 5) {
                    Text(currentStep.title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(currentStep.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)

                // Step content
                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        switch currentStep {
                        case .basicInfo:  stepBasicInfo
                        case .breed:      stepBreed
                        case .avatar:     stepAvatar
                        case .dates:      stepDates
                        case .gender:     stepGender
                        case .birthplace: stepBirthplace
                        case .identity:   stepIdentity
                        case .appearance:     stepAppearance
                        case .familyRelation: stepFamilyRelation
                        case .confirm:        stepConfirm
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)
            }

            // Nav buttons overlay
            VStack {
                Spacer()
                navButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .padding(.top, 12)
                    .background(.ultraThinMaterial)
            }
        }
        .onChange(of: photosPickerItem) { _, item in
            Task {
                guard let item else { return }
                // 在后台加载并降采样，避免原图（可能>10MB）直接传入裁剪页造成卡顿
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let resized = await Task.detached(priority: .userInitiated) {
                        UIImage(data: data).flatMap { Self.downsample($0, maxDim: 1200) }
                    }.value
                    await MainActor.run {
                        if let img = resized {
                            cropImageItem = IdentifiableCropImage(image: img)
                        }
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
            NavigationStack {
                PetImageCropView(image: item.image) { cropped in
                    avatarImageData = cropped.jpegData(compressionQuality: 0.92)
                    cropImageItem = nil
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { cropImageItem = nil }
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
        }
        .alert("名字已被占用 🏠", isPresented: $showDuplicateNameAlert) {
            Button("好的，我换一个", role: .cancel) { }
        } message: {
            Text("Ohana 里已经有一个叫「\(name.trimmingCharacters(in: .whitespaces))」的家人啦，换一个名字吧！")
        }
    }

    // MARK: - Nav Buttons
    private var navButtons: some View {
        HStack(spacing: 12) {
            if currentStep.rawValue > 0 {
                Button {
                    withAnimation(.spring(response: 0.36)) {
                        currentStep = WizardStep(rawValue: currentStep.rawValue - 1)!
                    }
                } label: {
                    Text("上一步")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.white.opacity(0.08), in: Capsule())
                }
            }
            if currentStep.rawValue < totalSteps - 1 {
                Button {
                    withAnimation(.spring(response: 0.36)) {
                        currentStep = WizardStep(rawValue: currentStep.rawValue + 1)!
                    }
                } label: {
                    Text("下一步")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.goLime, in: Capsule())
                }
                .disabled(!canProceed).opacity(canProceed ? 1 : 0.4)
            } else {
                Button {
                    guard !isSaving else { return }
                    if isNameDuplicate {
                        showDuplicateNameAlert = true
                        return
                    }
                    isSaving = true
                    savePet()
                } label: {
                    Text("完成 🎉")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.goLime, in: Capsule())
                }
                .disabled(!canProceed || isSaving)
            }
        }
    }

    // MARK: - Step 0: Basic Info
    private var stepBasicInfo: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("名字（必填）", systemImage: "pencil")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                TextField("给你的小怪兽起个名字", text: $name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(name.isEmpty ? Color.goRed.opacity(0.5) : Color.goLime.opacity(0.4), lineWidth: 1.5))
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("物种", systemImage: "pawprint.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(speciesOptions, id: \.self) { sp in
                        Button {
                            species = sp; breed = ""; coatColor = ""; eyeColor = ""
                        } label: {
                            VStack(spacing: 6) {
                                Text(speciesEmoji(sp)).font(.system(size: 28))
                                Text(sp)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(species == sp ? .black : .white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(species == sp ? Color.goLime : .white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Breed
    private var stepBreed: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.4))
                TextField("搜索品种", text: $breedSearch)
                    .foregroundStyle(.white)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                if !breedSearch.isEmpty {
                    Button { breedSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            ScrollViewReader { proxy in
                LazyVStack(spacing: 6) {
                    ForEach(currentBreeds) { b in
                        let isSelected = (b.name == "其他" && isCustomBreed) || (!isCustomBreed && breed == b.name)
                        Button {
                            if b.name == "其他" {
                                breed = "其他"; isCustomBreed = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation { proxy.scrollTo("customBreedField", anchor: .bottom) }
                                }
                            } else {
                                breed = b.name; isCustomBreed = false; customBreedText = ""
                                themeColorHex = b.suggestedThemeHex
                                coatColor = b.coatColors.first?.name ?? ""
                                eyeColor = b.eyeColors.first?.name ?? ""
                            }
                        } label: {
                            HStack {
                                Text(b.name)
                                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goLime) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(isSelected ? accentColor.opacity(0.15) : .white.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if isCustomBreed {
                        TextField("请输入品种名称", text: $customBreedText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.goLime.opacity(0.5), lineWidth: 1))
                            .id("customBreedField")
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Avatar
    @State private var showCutoutGuide = false
    @State private var pasteBreathing: Bool = false
    @State private var isPasting: Bool = false
    private var hasPasteboardImage: Bool { UIPasteboard.general.hasImages }

    private var stepAvatar: some View {
        VStack(spacing: 18) {

            // ── 头像预览（中心大图）
            avatarPreviewBadge

            // ── 相册 / 拍照
            secondaryPhotoRow

            // ── 清除（有头像时出现）
            if avatarImageData != nil {
                Button { avatarImageData = nil } label: {
                    Text("使用默认首字母头像")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - 头像预览 Badge
    private var avatarPreviewBadge: some View {
        ZStack {
            // 背景圆角卡
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(accentColor.opacity(0.22))
                .frame(width: 120, height: 120)

            if let data = avatarImageData, let ui = UIImage(data: data) {
                let isTransparent = ImageCutoutService.isTransparentPNG(data)
                if isTransparent {
                    // 透明抠图：scaledToFit 全展示
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipped()
                        // 小徽标：已抠图
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.goLime)
                                .padding(6)
                                .background(Color.black.opacity(0.55), in: Circle())
                                .offset(x: 6, y: -6)
                        }
                } else {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .clipped()
                }
            } else {
                Text(avatarInitial)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(accentColor)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 2)
        )
    }

    // MARK: - Pro Tip Banner（任务一）
    private var proTipBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.goLime.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.goLime)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("✨ 解锁 3D 悬浮卡片效果")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Group {
                    Text("强烈建议在系统相册中 ")
                    + Text("长按宠物主体并拷贝").bold().foregroundColor(Color.goLime)
                    + Text("，然后点击下方粘贴，即可获得最佳的杂志封面悬浮体验！")
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))
                .lineSpacing(2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.goLime.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.goLime.opacity(0.28), lineWidth: 1)
                )
        )
    }

    // MARK: - 主 CTA 粘贴按钮（任务二 + 任务三）
    private var pastePrimaryButton: some View {
        Button {
            pastePasteboardImage()
        } label: {
            ZStack {
                // 背景：有图时 goLime 实色渐变，无图时弱化
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        hasPasteboardImage
                            ? LinearGradient(
                                colors: [Color.goLime, Color(hex: "A8E44A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                    )
                    // 呼吸发光（仅有图时）
                    .shadow(
                        color: hasPasteboardImage ? Color.goLime.opacity(pasteBreathing ? 0.55 : 0.15) : .clear,
                        radius: pasteBreathing ? 18 : 6,
                        x: 0, y: 4
                    )

                if isPasting {
                    // 加载态
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(hasPasteboardImage ? .black : .white)
                            .scaleEffect(0.85)
                        Text("正在处理…")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(hasPasteboardImage ? .black : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                } else {
                    HStack(spacing: 10) {
                        // 左：图标区
                        ZStack {
                            Circle()
                                .fill(hasPasteboardImage ? Color.black.opacity(0.12) : Color.white.opacity(0.08))
                                .frame(width: 40, height: 40)
                            Image(systemName: hasPasteboardImage ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(hasPasteboardImage ? .black : .white.opacity(0.35))
                        }

                        // 中：文字
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hasPasteboardImage ? "立刻粘贴剪贴板图片" : "从剪贴板粘贴抠图")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(hasPasteboardImage ? .black : .white.opacity(0.4))
                            Text(hasPasteboardImage ? "检测到剪贴板有图 · 点击直达裁剪" : "先在相册长按宠物主体并拷贝")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(hasPasteboardImage ? .black.opacity(0.50) : .white.opacity(0.22))
                        }

                        Spacer()

                        // 右：箭头
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(hasPasteboardImage ? .black.opacity(0.45) : .white.opacity(0.1))
                            .scaleEffect(pasteBreathing && hasPasteboardImage ? 1.12 : 1.0)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPasting)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    hasPasteboardImage ? Color.clear : Color.white.opacity(0.10),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.25), value: hasPasteboardImage)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pasteBreathing)
    }

    // MARK: - 次级按钮行：相册 + 拍照（任务二）
    private var secondaryPhotoRow: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .semibold))
                    Text("从相册选择")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
            }
            Button { showingCamera = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("拍照")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func guideStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(Color.goLime, in: Circle())
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
    }

    /// 将图片压缩到 maxDim 长边以内，在后台线程调用
    static func downsample(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDim / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    /// 从剪贴板读取图片 → 触觉反馈 → 直达裁剪（任务三）
    private func pastePasteboardImage() {
        guard let img = UIPasteboard.general.image else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // 显示短暂加载态，让用户感知响应
        isPasting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            cropImageItem = IdentifiableCropImage(image: img)
            isPasting = false
        }
    }

    // MARK: - Step 3: Dates
    private var stepDates: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $hasBirthday) {
                    Label("设置生日", systemImage: "birthday.cake")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .tint(Color.goLime)
                if hasBirthday {
                    DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical).colorScheme(.dark).tint(accentColor)
                    if !humanAgeText.isEmpty {
                        Label(humanAgeText, systemImage: "person.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(10)
                            .background(accentColor.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $hasHomeDate) {
                    Label("设置到家日", systemImage: "house.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .tint(Color.goLime)
                if hasHomeDate {
                    let homeLower: Date = hasBirthday ? birthday : .distantPast
                    DatePicker("", selection: $homeDate, in: homeLower...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical).colorScheme(.dark).tint(accentColor)
                        .onChange(of: birthday) { _, newBirthday in
                            if homeDate < newBirthday { homeDate = newBirthday }
                        }
                    if !daysTogetherText.isEmpty {
                        Label(daysTogetherText, systemImage: "heart.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(10)
                            .background(Color.goLime.opacity(0.12), in: Capsule())
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Step 4: Gender
    private var stepGender: some View {
        VStack(spacing: 12) {
            ForEach([("male","♂ 男孩"), ("female","♀ 女孩"), ("unknown","未知")], id: \.0) { val, label in
                Button { gender = val } label: {
                    HStack {
                        Text(label).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Spacer()
                        if gender == val { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goLime) }
                    }
                    .padding(16)
                    .background(gender == val ? Color.goLime.opacity(0.12) : .white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 14))
                }
            }
            Toggle(isOn: $isNeutered) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已绝育 / 已结扎").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("对长期健康有益").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .tint(Color.goLime)
            .padding(16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Step 5: Birthplace
    private var stepBirthplace: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("出生国家").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PetBreedDatabase.countries, id: \.self) { country in
                            Button { birthCountry = country; birthCity = ""; isCustomCity = false } label: {
                                Text(country)
                                    .font(.system(size: 13, weight: birthCountry == country ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(birthCountry == country ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(birthCountry == country ? Color.goLime : .white.opacity(0.08), in: Capsule())
                            }
                        }
                    }
                }
            }
            if !birthCountry.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("出生城市").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                    let cities = PetBreedDatabase.cities(for: birthCountry)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(cities, id: \.self) { city in
                            Button {
                                if city == "其他" { isCustomCity = true; birthCity = "" }
                                else { isCustomCity = false; birthCity = city }
                            } label: {
                                Text(city)
                                    .font(.system(size: 13, weight: birthCity == city ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(birthCity == city ? .black : .white.opacity(0.7))
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(birthCity == city ? Color.goLime : .white.opacity(0.06),
                                                in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    if isCustomCity {
                        TextField("输入城市名称", text: $birthCity)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white).padding(12)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Step 6: Identity
    private var stepIdentity: some View {
        VStack(spacing: 16) {
            wizardField(label: "护照号码", placeholder: "选填", text: $passportNumber, icon: "doc.fill")
            wizardField(label: "芯片号 (Microchip ID)", placeholder: "15位数字（选填）", text: $microchipID, icon: "cpu")
        }
    }

    // MARK: - Step 7.5: Family Relations
    private var sameSpeciesPets: [Pet] {
        existingPets.filter { $0.species == species }
    }

    private var stepFamilyRelation: some View {
        VStack(spacing: 16) {
            if sameSpeciesPets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.2))
                    Text(species.isEmpty ? "请先选择宠物品种" : "岛上暂时没有同品种宠物")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("不同品种间没有亲属关系，直接跳过")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text("选择与每只宠物的关系（可多选，选填）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(sameSpeciesPets) { existPet in
                    let currentRelation = selectedRelations.first(where: { $0.petId == existPet.id })
                    VStack(spacing: 10) {
                        // 宠物信息行
                        HStack(spacing: 10) {
                            // 头像
                            ZStack {
                                Circle().fill(Color(hex: existPet.themeColorHex).opacity(0.3))
                                    .frame(width: 44, height: 44)
                                if let data = existPet.avatarImageData, let ui = UIImage(data: data) {
                                    Image(uiImage: ui).resizable().scaledToFill()
                                        .frame(width: 44, height: 44).clipShape(Circle())
                                } else {
                                    Text(existPet.speciesEmoji).font(.system(size: 22))
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(existPet.name)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(existPet.species) · \(existPet.ageText)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            if currentRelation != nil {
                                Button {
                                    selectedRelations.removeAll { $0.petId == existPet.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.4))
                                        .font(.system(size: 18))
                                }
                            }
                        }

                        // 关系类型选择
                        let availableTypes = PetRelationshipType.allCases
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableTypes, id: \.rawValue) { relType in
                                    let isSelected = currentRelation?.type == relType
                                    Button {
                                        selectedRelations.removeAll { $0.petId == existPet.id }
                                        if !isSelected {
                                            selectedRelations.append((petId: existPet.id, type: relType))
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: relType.icon)
                                                .font(.system(size: 11, weight: .bold))
                                            Text(relType.displayName(fromGender: existPet.gender, toGender: gender))
                                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                        }
                                        .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(isSelected ? Color.goLime : .white.opacity(0.08),
                                                    in: Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Step 8: Appearance
    private var stepAppearance: some View {
        VStack(spacing: 20) {
            let bi = selectedBreedInfo
            let coatItems = (bi?.coatColors.map { ($0.name, $0.hex) }) ?? PetBreedDatabase.genericCoatColors.map { ($0.name, $0.hex) }
            let eyeItems = (bi?.eyeColors.map { ($0.name, $0.hex) }) ?? PetBreedDatabase.genericEyeColors.map { ($0.name, $0.hex) }

            colorSection(
                title: "毛色",
                items: coatItems,
                patternItems: PetCoatPattern.allCases,
                selected: $coatColor,
                showCustomPicker: $showCoatColorPicker,
                customColor: $customCoatUIColor
            )
            .onChange(of: coatColor) { _, newColor in
                autoMapThemeFromCoat(newColor, items: coatItems)
            }

            GoDashedDivider()
            colorSection(
                title: "瞳色",
                items: eyeItems,
                patternItems: [],
                selected: $eyeColor,
                showCustomPicker: $showEyeColorPicker,
                customColor: $customEyeUIColor
            )

            GoDashedDivider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("主题色").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("卡片背景色").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.3))
                }
                // preset grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                    ForEach(PetThemeColor.allCases, id: \.rawValue) { tc in
                        let tcHex = tc.hexValue
                        let isUsed = usedThemeColorHexes.contains(tcHex.uppercased())
                        Button { themeColorHex = tcHex } label: {
                            ZStack {
                                Circle().fill(tc.color.opacity(isUsed ? 0.3 : 1.0)).frame(width: 40, height: 40)
                                if themeColorHex.uppercased() == tcHex.uppercased() {
                                    Circle().strokeBorder(.white, lineWidth: 2.5)
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                                }
                                if isUsed {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        .disabled(isUsed)
                    }
                    // Custom color swatch
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: themeColorHex) },
                        set: { newColor in
                            if let hex = newColor.toHex() { themeColorHex = hex }
                        }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 40, height: 40)
                    .scaleEffect(1.3)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    )
                }
                // Preview
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: themeColorHex))
                        .frame(width: 28, height: 28)
                    Text("卡片预览色 #\(themeColorHex.uppercased())")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private func autoMapThemeFromCoat(_ colorName: String, items: [(String, String)]) {
        guard let hex = items.first(where: { $0.0 == colorName })?.1 else { return }
        // Map coat color hex to closest Go UI theme color
        let mapping: [(String, String)] = [
            ("FFFFFF", "FFFFFF"), ("F5F5F5", "FFFFFF"), ("FFFDE7", "FFF44F"),
            ("FFF8DC", "FFF44F"), ("F5DEB3", "FF8C42"), ("DEB887", "FF8C42"),
            ("D2691E", "FF8C42"), ("A0522D", "FF8C42"), ("8B4513", "FF8C42"),
            ("808080", "5B6AFF"), ("A9A9A9", "5B6AFF"), ("696969", "5B6AFF"),
            ("000000", "0D0638"), ("1C1C1C", "0D0638"),
            ("FF4500", "FF4757"), ("B22222", "FF4757"),
            ("FFA500", "FF8C42"), ("FFD700", "FFF44F"),
            ("228B22", "B8FFD0"), ("006400", "B8FFD0"),
            ("00BFFF", "00D4AA"), ("4169E1", "4338FF"),
        ]
        let r = Int(hex.prefix(2), radix: 16) ?? 128
        let g = Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 128
        let b = Int(hex.dropFirst(4).prefix(2), radix: 16) ?? 128
        var bestDist = Int.max
        var bestHex = themeColorHex
        for (src, dst) in mapping {
            let sr = Int(src.prefix(2), radix: 16) ?? 0
            let sg = Int(src.dropFirst(2).prefix(2), radix: 16) ?? 0
            let sb = Int(src.dropFirst(4).prefix(2), radix: 16) ?? 0
            let dist = (r-sr)*(r-sr) + (g-sg)*(g-sg) + (b-sb)*(b-sb)
            if dist < bestDist { bestDist = dist; bestHex = dst }
        }
        themeColorHex = bestHex
    }

    // MARK: - Step 8: Confirm
    private var stepConfirm: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(accentColor.opacity(0.3)).frame(width: 96, height: 96)
                if let data = avatarImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    Text(avatarInitial).font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(accentColor)
                }
            }
            Text(name.isEmpty ? "未命名" : name)
                .font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                confirmCell(icon: "pawprint.fill", label: "物种", value: species)
                confirmCell(icon: "list.bullet", label: "品种", value: breed.isEmpty ? "未选择" : breed)
                confirmCell(icon: "person.fill", label: "性别", value: gender == "male" ? "♂ 男孩" : gender == "female" ? "♀ 女孩" : "未知")
                confirmCell(icon: "scissors", label: "绝育", value: isNeutered ? "✅ 已绝育" : "未绝育")
                if hasBirthday {
                    confirmCell(icon: "birthday.cake", label: "生日", value: birthday.formatted(.dateTime.year().month().day()))
                }
                if hasHomeDate {
                    confirmCell(icon: "house.fill", label: "到家日", value: homeDate.formatted(.dateTime.year().month().day()))
                }
                if !birthCountry.isEmpty {
                    confirmCell(icon: "globe", label: "出生地", value: "\(birthCountry)\(birthCity.isEmpty ? "" : " · \(birthCity)")")
                }
                if !coatColor.isEmpty { confirmCell(icon: "paintpalette.fill", label: "毛色", value: coatColor) }
                if !eyeColor.isEmpty { confirmCell(icon: "eye.fill", label: "瞳色", value: eyeColor) }
                if !microchipID.isEmpty { confirmCell(icon: "cpu", label: "芯片号", value: microchipID) }
                if !passportNumber.isEmpty { confirmCell(icon: "doc.fill", label: "护照号", value: passportNumber) }
            }

            if hasBirthday && !humanAgeText.isEmpty {
                Label(humanAgeText, systemImage: "person.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                    .padding(10).background(accentColor.opacity(0.12), in: Capsule())
            }
            if hasHomeDate && !daysTogetherText.isEmpty {
                Label(daysTogetherText, systemImage: "heart.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                    .padding(10).background(Color.goLime.opacity(0.12), in: Capsule())
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Reusable helpers
    private func wizardField(label: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.45))
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.white)
                .padding(12).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func colorSection(
        title: String,
        items: [(String, String)],
        patternItems: [PetCoatPattern],
        selected: Binding<String>,
        showCustomPicker: Binding<Bool>,
        customColor: Binding<Color>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Preset solid swatches
                    ForEach(items, id: \.0) { colorName, hex in
                        Button { selected.wrappedValue = colorName } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle().fill(Color(hex: hex)).frame(width: 38, height: 38)
                                    if selected.wrappedValue == colorName {
                                        Circle().strokeBorder(.white, lineWidth: 2.5)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                                    }
                                }
                                Text(colorName)
                                    .font(.system(size: 10, weight: selected.wrappedValue == colorName ? .bold : .medium))
                                    .foregroundStyle(selected.wrappedValue == colorName ? .white : .white.opacity(0.45))
                                    .lineLimit(1).frame(width: 50)
                            }
                        }
                    }
                    // Pattern swatches（渐变图案）
                    ForEach(patternItems, id: \.rawValue) { pattern in
                        Button { selected.wrappedValue = pattern.displayName } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(pattern.gradient)
                                        .frame(width: 38, height: 38)
                                    if selected.wrappedValue == pattern.displayName {
                                        Circle().strokeBorder(.white, lineWidth: 2.5)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                                    }
                                }
                                Text(pattern.displayName)
                                    .font(.system(size: 10, weight: selected.wrappedValue == pattern.displayName ? .bold : .medium))
                                    .foregroundStyle(selected.wrappedValue == pattern.displayName ? .white : .white.opacity(0.45))
                                    .lineLimit(1).frame(width: 50)
                            }
                        }
                    }
                    // Custom color picker - tap to open sheet
                    VStack(spacing: 4) {
                        Button {
                            showCustomPicker.wrappedValue = true
                        } label: {
                            ZStack {
                                if selected.wrappedValue == "自定义" {
                                    Circle().fill(customColor.wrappedValue).frame(width: 38, height: 38)
                                    Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 38, height: 38)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                                } else {
                                    Circle()
                                        .fill(LinearGradient(colors: [.red,.orange,.yellow,.green,.blue,.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                        }
                        Text("自定义")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(selected.wrappedValue == "自定义" ? .white : .white.opacity(0.45))
                            .frame(width: 50)
                    }
                    .sheet(isPresented: showCustomPicker) {
                        GoColorPickerSheet(selectedColor: customColor) { chosen in
                            customColor.wrappedValue = chosen
                            selected.wrappedValue = "自定义"
                        }
                        .presentationDetents([.medium])
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func confirmCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(accentColor).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
            }
            Spacer()
        }
        .padding(10).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func speciesEmoji(_ sp: String) -> String {
        switch sp {
        case "狗": return "🐕"; case "猫": return "🐈"; case "兔子": return "🐇"
        case "仓鼠": return "🐹"; case "鸟": return "🦜"; default: return "🐾"
        }
    }

    private func savePet() {
        let finalBreed = isCustomBreed ? customBreedText : breed
        let pet = Pet(
            name: name, species: species, breed: finalBreed,
            birthday: hasBirthday ? birthday : nil,
            gender: gender, isNeutered: isNeutered,
            avatarEmoji: speciesEmoji(species),
            themeColorHex: themeColorHex,
            homeDate: hasHomeDate ? homeDate : nil
        )
        pet.avatarImageData = avatarImageData
        pet.passportNumber = passportNumber
        pet.microchipID = microchipID
        pet.birthCountry = birthCountry
        pet.birthCity = isCustomCity ? birthCity : birthCity
        pet.coatColor = coatColor
        pet.eyeColor = eyeColor
        pet.cardStyleRaw = cardStyle
        modelContext.insert(pet)

        // Q4: 主题颜色任务判断
        if themeColorHex != "C8FF00" {
            QuestManager.shared.recordThemeColorSet()
        }
        
        // 创建生日事件
        if hasBirthday {
            let birthdayEvent = Event(
                title: "\(name) 的生日 🎂",
                startDate: birthday,
                isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: "Pet",
                relatedEntityId: pet.id.uuidString
            )
            birthdayEvent.recurrenceDays = 365
            modelContext.insert(birthdayEvent)
            
            let reminder = Reminder(event: birthdayEvent, scheduledAt: birthday)
            modelContext.insert(reminder)
        }
        
        // 创建到家纪念日事件
        if hasHomeDate {
            let anniversaryEvent = Event(
                title: "\(name) 的到家纪念日 🏠",
                startDate: homeDate,
                isAllDay: true,
                eventType: EventType.anniversary.rawValue,
                relatedEntityType: "Pet",
                relatedEntityId: pet.id.uuidString
            )
            anniversaryEvent.recurrenceDays = 365
            modelContext.insert(anniversaryEvent)
        }
        
        // 创建里程碑
        if hasHomeDate {
            let milestones = [100, 365, 500, 730, 1000, 1095]
            for days in milestones {
                if let date = Calendar.current.date(byAdding: .day, value: days, to: homeDate) {
                    let milestone = PetMilestone(
                        date: date,
                        title: "共度 \(days) 天",
                        emoji: days >= 1000 ? "🏆" : "🎉",
                        pet: pet
                    )
                    modelContext.insert(milestone)
                }
            }
        }
        
        // 保存家庭关系（双向各存一条）
        for rel in selectedRelations {
            let forward = PetRelationship(fromPetId: pet.id, toPetId: rel.petId, type: rel.type)
            modelContext.insert(forward)
        }

        modelContext.safeSave()

        // Q4: 欢呼算结 — 岛屿第一家人成就
        if !QuestManager.shared.isPetWizardCompleted {
            QuestManager.shared.isPetWizardCompleted = true
            QuestManager.shared.addCoconuts(50, emoji: "🎉", reason: "新家人入住欢迎奖励")
            // 震动反馈
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { gen.impactOccurred() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { gen.impactOccurred() }
            // 气球弹出动画
            showCoconutBurst = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                coconutBurstScale = 1.0
                coconutBurstOpacity = 1.0
            }
            // 1.6s 后淡出，然后关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.4)) {
                    coconutBurstOpacity = 0.0
                    coconutBurstScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showCoconutBurst = false
                    onComplete()
                }
            }
        } else {
            onComplete()
        }
    }
}

// MARK: - Coat Pattern Swatches（渐变图案毛色）
enum PetCoatPattern: String, CaseIterable {
    case calico         = "三花"
    case silverChinchilla = "银渐层"
    case tortoiseshell  = "玳瑁"
    case cowPattern     = "奶牛色"
    case bicolor        = "蓝白双色"

    var displayName: String { rawValue }

    var gradient: AnyShapeStyle {
        switch self {
        case .calico:
            return AnyShapeStyle(
                AngularGradient(
                    gradient: Gradient(colors: [.white, .black, Color(hex: "E87722"), .white]),
                    center: .center
                )
            )
        case .silverChinchilla:
            return AnyShapeStyle(
                RadialGradient(
                    colors: [.white, Color(hex: "C8C8C8"), Color(hex: "909090")],
                    center: .center,
                    startRadius: 2,
                    endRadius: 20
                )
            )
        case .tortoiseshell:
            return AnyShapeStyle(
                AngularGradient(
                    gradient: Gradient(colors: [Color(hex: "2C1A0E"), Color(hex: "C05A00"), Color(hex: "1A1A1A"), Color(hex: "D4820A"), Color(hex: "2C1A0E")]),
                    center: .center
                )
            )
        case .cowPattern:
            return AnyShapeStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.4),
                        .init(color: .black, location: 0.4),
                        .init(color: .black, location: 0.65),
                        .init(color: .white, location: 0.65),
                        .init(color: .white, location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .bicolor:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(hex: "95ADBE"), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

// MARK: - Pet Age Converter
enum PetAgeConverter {
    static func humanAge(birthday: Date, species: String) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: birthday, to: Date())
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        let totalMonths = years * 12 + months
        guard totalMonths >= 0 else { return "" }

        let humanYears: Int
        switch species {
        case "狗":
            // AVMA 科学换算（中型犬标准）
            if totalMonths <= 1 { humanYears = 4 }
            else if totalMonths <= 3 { humanYears = 8 }
            else if totalMonths <= 6 { humanYears = 12 }
            else if totalMonths <= 12 { humanYears = 15 }
            else if years == 2 { humanYears = 24 }
            else { humanYears = 24 + (years - 2) * 5 }
        case "猫":
            // AAFP 科学换算
            if totalMonths <= 1 { humanYears = 4 }
            else if totalMonths <= 3 { humanYears = 8 }
            else if totalMonths <= 6 { humanYears = 12 }
            else if totalMonths <= 12 { humanYears = 15 }
            else if years == 2 { humanYears = 24 }
            else { humanYears = 24 + (years - 2) * 4 }
        case "兔子":
            if years <= 0 { humanYears = 6 * totalMonths }
            else if years == 1 { humanYears = 18 }
            else { humanYears = 18 + (years - 1) * 8 }
        case "仓鼠":
            // 仓鼠寿命约2-3年，1年≈25人类年
            humanYears = max(1, totalMonths * 2)
        case "鸟":
            humanYears = years * 6
        default:
            humanYears = years
        }
        return "相当于人类约 \(humanYears) 岁"
    }
}

// MARK: - Camera Picker
struct PetCameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uvc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(onCapture: onCapture) }

    class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onCapture(img) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

// MARK: - Image Crop View（方形取景框，统一坐标空间）
struct PetImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void

    // 取景框边长
    private let cropSize: CGFloat = 280
    private let cornerRadius: CGFloat = 28

    // 图片变换：所有变换作用于同一 ZStack 内，坐标系完全一致
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // scaledToFit 后图片在 canvasSize 内的实际渲染尺寸（onAppear 时计算一次）
    @State private var canvasSize: CGSize = .zero      // ZStack 的可用区域
    @State private var fitDisplaySize: CGSize = .zero  // scaledToFit 结果尺寸

    /// 最小缩放：允许缩到 0.5，让用户可把大图整体缩进取景框
    private var minScale: CGFloat {
        guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return 0.5 }
        let fitMin = max(cropSize / fitDisplaySize.width, cropSize / fitDisplaySize.height)
        return min(fitMin, 0.5)
    }

    /// 最大缩放：让图片短边恰好等于取景框边长（即 1:1 像素级填满）
    private var maxScale: CGFloat {
        guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return 8.0 }
        let shortSide = min(fitDisplaySize.width, fitDisplaySize.height)
        return shortSide > 0 ? cropSize / shortSide : 8.0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // ── 图片层：scaledToFit 保证和遮罩/框线完全同一坐标系
                Image(uiImage: normalizedImage(image))
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale, anchor: .center)
                    .offset(offset)

                // ── 遮罩层（同一 ZStack 内，坐标系完全一致）
                PetCropOverlay(cropSize: cropSize, cornerRadius: cornerRadius)

                // ── 取景框描边（goLime 颜色）
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.goLime, lineWidth: 2)
                    .frame(width: cropSize, height: cropSize)

                // ── L 形角标
                PetCropCorners(size: cropSize, radius: cornerRadius)

                // ── 底部操作栏
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button("取消") { onCrop(normalizedImage(image)) }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 32).padding(.vertical, 14)
                            .background(.white.opacity(0.12), in: Capsule())
                        Button("确认裁剪") { performCrop(in: geo.size) }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32).padding(.vertical, 14)
                            .background(Color.goLime, in: Capsule())
                    }
                    .padding(.bottom, 48)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                canvasSize = geo.size
                // scaledToFit 在 geo.size 内的实际渲染尺寸
                let img = normalizedImage(image)
                let iw = img.size.width, ih = img.size.height
                guard iw > 0, ih > 0 else { return }
                let aspectFit = min(geo.size.width / iw, geo.size.height / ih)
                fitDisplaySize = CGSize(width: iw * aspectFit, height: ih * aspectFit)
                let s = minScale
                scale = s; lastScale = s
            }
        }
        .gesture(
            MagnificationGesture()
                .onChanged { v in
                    let proposed = lastScale * v
                    scale = min(maxScale, max(minScale, proposed))
                }
                .onEnded { _ in lastScale = scale }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { v in
                    offset = CGSize(
                        width:  lastOffset.width  + v.translation.width,
                        height: lastOffset.height + v.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
    }

    // MARK: - 方向修正

    private func normalizedImage(_ src: UIImage) -> UIImage {
        guard src.imageOrientation != .up else { return src }
        let renderer = UIGraphicsImageRenderer(size: src.size)
        return renderer.image { _ in src.draw(in: CGRect(origin: .zero, size: src.size)) }
    }

    // MARK: - 精准裁剪（基于 scaledToFit 坐标系）

    private func performCrop(in viewSize: CGSize) {
        let src = normalizedImage(image)
        let iw = src.size.width, ih = src.size.height
        guard iw > 0, ih > 0, viewSize.width > 0 else { onCrop(src); return }

        // scaledToFit 基础缩放
        let fitScale = min(viewSize.width / iw, viewSize.height / ih)
        // 用户额外缩放
        let totalScale = fitScale * scale

        // 图片渲染后的实际尺寸
        let displayW = iw * totalScale
        let displayH = ih * totalScale

        // 图片左上角在 ZStack 中的位置（ZStack 中心对齐）
        let imgOriginX = (viewSize.width  - displayW) / 2 + offset.width
        let imgOriginY = (viewSize.height - displayH) / 2 + offset.height

        // 取景框左上角（居中）
        let cropOriginX = (viewSize.width  - cropSize) / 2
        let cropOriginY = (viewSize.height - cropSize) / 2

        // 取景框相对图片左上角的偏移（视图点）
        let relX = cropOriginX - imgOriginX
        let relY = cropOriginY - imgOriginY

        // 映射回原始像素（注意 src.scale = UIScreen scale）
        let pixelScale = totalScale / src.scale   // 视图点 → 原图逻辑像素
        let srcX = max(0, relX / pixelScale)
        let srcY = max(0, relY / pixelScale)
        let srcLen = cropSize / pixelScale
        let clampedW = min(srcLen, iw - srcX)
        let clampedH = min(srcLen, ih - srcY)

        guard clampedW > 0, clampedH > 0,
              let cgCrop = src.cgImage?.cropping(to: CGRect(
                x: srcX * src.scale,
                y: srcY * src.scale,
                width:  clampedW * src.scale,
                height: clampedH * src.scale
              ))
        else { onCrop(src); return }

        // 输出为 cropSize pt × cropSize pt @screen scale
        let screenScale = UIScreen.main.scale
        let outputPx = cropSize * screenScale
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputPx, height: outputPx)
        )
        let cropped = renderer.image { _ in
            UIImage(cgImage: cgCrop)
                .draw(in: CGRect(x: 0, y: 0, width: outputPx, height: outputPx))
        }
        onCrop(cropped)
    }
}

// Dim overlay with transparent crop hole
private struct PetCropOverlay: View {
    let cropSize: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                let x = (geo.size.width - cropSize) / 2
                let y = (geo.size.height - cropSize) / 2
                path.addRoundedRect(
                    in: CGRect(x: x, y: y, width: cropSize, height: cropSize),
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )
            }
            .fill(style: FillStyle(eoFill: true))
            .foregroundStyle(.black.opacity(0.62))
        }
    }
}

// Corner L-shape indicators
private struct PetCropCorners: View {
    let size: CGFloat
    let radius: CGFloat
    private let len: CGFloat = 20
    private let thick: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let xSign: CGFloat = i < 2 ? -1 : 1
                let ySign: CGFloat = (i % 2 == 0) ? -1 : 1
                ZStack {
                    // Horizontal
                    RoundedRectangle(cornerRadius: thick / 2)
                        .fill(Color.goLime)
                        .frame(width: len, height: thick)
                        .offset(x: xSign * (size / 2 - len / 2), y: ySign * (size / 2))
                    // Vertical
                    RoundedRectangle(cornerRadius: thick / 2)
                        .fill(Color.goLime)
                        .frame(width: thick, height: len)
                        .offset(x: xSign * (size / 2), y: ySign * (size / 2 - len / 2))
                }
            }
        }
    }
}

// MARK: - Go Color Picker Sheet
struct GoColorPickerSheet: View {
    @Binding var selectedColor: Color
    let onSelect: (Color) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerColor: Color

    init(selectedColor: Binding<Color>, onSelect: @escaping (Color) -> Void) {
        self._selectedColor = selectedColor
        self.onSelect = onSelect
        self._pickerColor = State(initialValue: selectedColor.wrappedValue)
    }

    var body: some View {
        ZStack {
            Color(hex: "0A0F2C").ignoresSafeArea()
            VStack(spacing: 20) {
                // 顶部把手
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text("自定义颜色")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // 预览色块
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(pickerColor)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                // 系统 ColorPicker（使用整个色轮）
                ColorPicker("选择颜色", selection: $pickerColor, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(1.8)
                    .padding(.vertical, 8)

                // 确认按钮
                Button {
                    onSelect(pickerColor)
                    dismiss()
                } label: {
                    Text("确认")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.goLime, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Identifiable wrapper for crop image sheet
struct IdentifiableCropImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    AddPetWizardView(onComplete: {})
        .modelContainer(SharedModelContainer.make())
}
