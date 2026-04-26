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
}

struct AddPetWizardView: View {
    let onComplete: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    @State private var currentStep: WizardStep = .basicInfo
    @State private var isSaving = false
    @State private var name = ""
    @State private var species = "狗"
    /// 选择「其他」物种时，用户手填的展示名（存入 Pet.species）
    @State private var customSpeciesText = ""
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
    @State private var themeColorHex = "FF5252" // 默认使用 Crimson
    @State private var showCoatColorPicker = false
    @State private var showEyeColorPicker = false
    @State private var customCoatUIColor: Color = .white
    @State private var customEyeUIColor: Color = .white
    @State private var showCoatColorSheet = false
    @State private var showEyeColorSheet = false
    @State private var showSaveFailedAlert = false
    @State private var saveFailedMessage = ""
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
    // P0 留存：首日承诺 + AHA 破壳动画
    @State private var pendingDay0Promise: (name: String, species: String, emoji: String)? = nil
    @State private var showAhaOverlay: Bool = false
    @State private var ahaPetName: String = ""
    @State private var ahaPetEmoji: String = "🐣"
    /// 品种列表默认收起，点按展开后再搜索与选择
    @State private var isBreedPickerExpanded = false
    @State private var wizardPageIndex: Int = 0
    /// 裁剪 Sheet 关闭后递增，用于 `.id` 强制重建 `TabView`，避免与顶栏头像动画叠用时停在两页之间。
    @State private var wizardTabViewRemountID: Int = 0
    @State private var showBreedPickerSheet = false
    /// 性格标签（最多 3 个，顺序与存储一致）
    @State private var selectedPersonalityTagIds: [String] = []
    @AppStorage("ohana_custom_personality_tags_v1") private var customPersonalityTagsJSON: String = "[]"
    @State private var isComposingCustomPersonalityTag = false
    @State private var newCustomPersonalityTagText = ""
    @FocusState private var customPersonalityTagFieldFocused: Bool

    private var decodedCustomPersonalityTags: [CustomPersonalityTagRecord] {
        guard let d = customPersonalityTagsJSON.data(using: .utf8),
              let arr = try? JSONDecoder().decode([CustomPersonalityTagRecord].self, from: d) else { return [] }
        return arr
    }
    /// 顶卡头像异步解码缓存，避免每次按键重复解码 Data / 检测透明
    @State private var walletDecodedAvatar: UIImage? = nil
    @State private var walletDecodedAvatarTransparent: Bool = false

    private let speciesOptions = ["狗", "猫", "兔子", "仓鼠", "鸟", "其他"]
    @AppStorage("appLanguage") private var appLanguage = "zh"
    private var wizardL10n: L10n { L10n(appLanguage) }
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
        let list = PetBreedDatabase.breeds(for: species)
        if isCustomBreed {
            let t = customBreedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if let exact = list.first(where: { $0.name == t }) { return exact }
            return list.first { $0.name == "其他" }
        }
        guard !breed.isEmpty else { return nil }
        return list.first { $0.name == breed }
    }

    /// 品种或自定义品种名变化时，丢弃当前品种不允许的毛色 / 瞳色 / 渐变花纹（例如德牧不应保留「银渐层」）。
    private func clampAppearanceSelectionToBreed() {
        let bi = selectedBreedInfo
        let coatList = bi?.coatColors ?? PetBreedDatabase.genericCoatColors
        let eyeList = PetBreedDatabase.refinedEyeColors(breed: bi, coatColor: coatColor)
        let coatNames = Set(coatList.map(\.name))
        let eyeNames = Set(eyeList.map(\.name))
        let allowedPatterns = Set(PetCoatPattern.patterns(forBreed: bi).map(\.displayName))

        if coatColor != "自定义" && !coatColor.isEmpty {
            let okSolid = coatNames.contains(coatColor)
            let okPattern = allowedPatterns.contains(coatColor)
            if !okSolid && !okPattern {
                coatColor = coatList.first?.name ?? ""
            }
        }
        if eyeColor != "自定义" && !eyeColor.isEmpty, !eyeNames.contains(eyeColor) {
            eyeColor = eyeList.first?.name ?? ""
        }
    }

    /// 写入模型与年龄换算用的物种文案（「其他」时用自定义输入）
    private var effectiveSpeciesForData: String {
        if species == "其他" {
            let t = customSpeciesText.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "其他" : t
        }
        return species
    }

    private var humanAgeText: String {
        guard hasBirthday else { return "" }
        return PetAgeConverter.humanAge(birthday: birthday, species: effectiveSpeciesForData, isEnglish: wizardL10n.isEn)
    }
    private var daysTogetherText: String {
        guard hasHomeDate else { return "" }
        let l = wizardL10n
        let days = Calendar.current.dateComponents([.day], from: homeDate, to: Date()).day ?? 0
        if days < 0 { return l.petWizDaysUntilHome(-days) }
        if days == 0 { return l.petWizHomeToday }
        return l.petWizTogetherDays(days)
    }

    /// 与首页 `Pet.ageText` 一致，用于钱包卡脚注
    private var ageTextForWalletCard: String {
        guard hasBirthday else { return "" }
        let l = wizardL10n
        let components = Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        return l.petWizAgeWallet(years: years, months: months)
    }

    private var wizardDaysTogether: Int {
        guard hasHomeDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: homeDate, to: Date()).day ?? 0
    }

    private var breedFootnoteForCard: String {
        if isCustomBreed {
            return customBreedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return breed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 折叠行展示的当前品种摘要
    private var breedCollapseSummary: String {
        wizardL10n.petWizBreedCollapseSummary(isCustomBreed: isCustomBreed, customBreedText: customBreedText, breed: breed)
    }

    /// 顶卡头像在后台解码，避免 `name` 每次变化时主线程重复 `UIImage(data:)` / `isTransparentPNG`
    private func scheduleWalletAvatarDecode() {
        guard let data = avatarImageData, !data.isEmpty else {
            walletDecodedAvatar = nil
            walletDecodedAvatarTransparent = false
            return
        }
        let snapshot = data
        Task.detached(priority: .utility) {
            let img = UIImage(data: snapshot)
            let transparent = ImageCutoutService.isTransparentPNG(snapshot)
            await MainActor.run {
                guard avatarImageData == snapshot else { return }
                walletDecodedAvatar = img
                walletDecodedAvatarTransparent = transparent
            }
        }
    }

    private var walletDraftCardHeight: CGFloat { (ScreenCompat.width - 48) / 1.586 }
    private let walletCardCorner: CGFloat = 24

    private var stickyWalletPreview: some View {
        WalletPetCardDraftFront(
            name: name,
            species: effectiveSpeciesForData,
            breedFootnote: breedFootnoteForCard,
            avatarImageData: avatarImageData,
            decodedAvatar: walletDecodedAvatar,
            decodedAvatarIsTransparent: walletDecodedAvatarTransparent,
            coatColor: resolvedCoatColor,
            eyeColor: resolvedEyeColor,
            coatPatternName: PetCoatPattern.patterns(forBreed: selectedBreedInfo).first(where: { $0.displayName == coatColor })?.displayName,
            hasBirthday: hasBirthday,
            ageFootnote: ageTextForWalletCard,
            hasHomeDate: hasHomeDate,
            daysTogether: wizardDaysTogether,
            themeColorHex: themeColorHex,
            cornerRadius: walletCardCorner
        )
        .frame(height: walletDraftCardHeight)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 6)
        // 不在 `name` 上套弹簧动画：每个按键都会触发布局+动画，输入会明显卡顿
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: breed)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: customBreedText)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: avatarImageData?.count)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: hasBirthday)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: birthday)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: hasHomeDate)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: homeDate)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: coatColor)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: eyeColor)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: themeColorHex)
    }

    /// 分页：`TabView` 恢复左右滑动；外貌卡内毛/瞳色块使用 `wrappingGrid`，避免横向 `ScrollView` 与分页手势冲突。
    private var wizardPagedContent: some View {
        TabView(selection: $wizardPageIndex) {
            pagedCard(index: 0, content: { wizardCard1BasicInfo }).tag(0)
            pagedCard(index: 1, content: { wizardCard2Avatar }).tag(1)
            pagedCard(index: 2, content: { wizardCard3Bio }).tag(2)
            pagedCard(index: 3, content: { wizardCard4Appearance }).tag(3)
            pagedCard(index: 4, content: { wizardCard5Tags }).tag(4)
            pagedCard(index: 5, content: { wizardCard6Confirm }).tag(5)
        }
        .id(wizardTabViewRemountID)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 拆出主列以减轻 `body` 类型推断压力（避免编译器超时）
    private var addPetWizardMainColumn: some View {
        VStack(spacing: 0) {
            stickyWalletPreview

            wizardPagedContent
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)
                .background(.clear)

            wizardPageDotRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wizardPageDotRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { i in
                wizardPageDotButton(index: i)
            }
        }
        .padding(.top, 8).padding(.bottom, 4)
    }

    private func wizardPageDotButton(index i: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                wizardPageIndex = i
            }
        } label: {
            Capsule()
                .fill(i == wizardPageIndex ? Color.goPrimary : Color.primary.opacity(0.2))
                .frame(width: i == wizardPageIndex ? 20 : 6, height: 6)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: wizardPageIndex)
    }

    @ViewBuilder
    private var coconutBurstOverlay: some View {
        if showCoconutBurst {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("🥥").font(.system(size: 72))
                    Text("+50 🥥")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                    Text(wizardL10n.petWizIslandWelcome)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .scaleEffect(coconutBurstScale).opacity(coconutBurstOpacity)
            }
            .zIndex(999).allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var ahaHatchOverlayLayer: some View {
        if showAhaOverlay {
            AhaHatchOverlay(petName: ahaPetName, petEmoji: ahaPetEmoji)
                .zIndex(998)
                .transition(.opacity)
        }
    }

    /// 仅 ZStack 层，避免与一长串 onChange 一起参与单次类型推断
    private var addPetWizardStackCore: some View {
        ZStack {
            coconutBurstOverlay
            ahaHatchOverlayLayer
            addPetWizardMainColumn
        }
    }

    private func remountWizardPagerIfCropDismissed(_ newItem: IdentifiableCropImage?) {
        guard newItem == nil else { return }
        DispatchQueue.main.async { wizardTabViewRemountID += 1 }
    }

    private func clampWizardPageIndex(_ new: Int) {
        let clamped = min(max(new, 0), 5)
        if clamped != new { wizardPageIndex = clamped }
    }

    private func handlePhotosPickerItemChanged(_ item: PhotosPickerItem?) {
        Task {
            guard let item else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                let resized = await Task.detached(priority: .userInitiated) {
                    UIImage(data: data).flatMap { Self.downsample($0, maxDim: 1200) }
                }.value
                await MainActor.run {
                    if let img = resized { cropImageItem = IdentifiableCropImage(image: img) }
                }
            }
        }
    }

    private var addPetWizardLifecyclePartA: some View {
        addPetWizardStackCore
            .onAppear { scheduleWalletAvatarDecode() }
            .onChange(of: cropImageItem) { _, new in remountWizardPagerIfCropDismissed(new) }
            .onChange(of: wizardPageIndex) { _, new in clampWizardPageIndex(new) }
            .onChange(of: avatarImageData) { _, _ in scheduleWalletAvatarDecode() }
            .onChange(of: photosPickerItem) { _, item in handlePhotosPickerItemChanged(item) }
    }

    private var addPetWizardLifecycleBase: some View {
        addPetWizardLifecyclePartA
            .onChange(of: species) { _, _ in clampAppearanceSelectionToBreed() }
            .onChange(of: breed) { _, _ in clampAppearanceSelectionToBreed() }
            .onChange(of: isCustomBreed) { _, _ in clampAppearanceSelectionToBreed() }
            .onChange(of: customBreedText) { _, _ in clampAppearanceSelectionToBreed() }
            .onChange(of: coatColor) { _, _ in clampAppearanceSelectionToBreed() }
    }

    var body: some View {
        addPetWizardLifecycleBase
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
                PetImageCropView(image: item.image, species: effectiveSpeciesForData) { cropped in
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        if let cropped { avatarImageData = cropped.jpegData(compressionQuality: 0.92) }
                        cropImageItem = nil
                        photosPickerItem = nil
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(wizardL10n.cancel) {
                            var tx = Transaction()
                            tx.disablesAnimations = true
                            withTransaction(tx) {
                                cropImageItem = nil
                                photosPickerItem = nil
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showBreedPickerSheet) { breedPickerSheet }
        .alert(wizardL10n.humanWizDupAlertTitle, isPresented: $showDuplicateNameAlert) {
            Button(wizardL10n.humanWizDupAlertOk, role: .cancel) { }
        } message: {
            Text(wizardL10n.humanWizDupAlertMsg(name.trimmingCharacters(in: .whitespaces)))
        }
        .alert(wizardL10n.petWizSaveFailedTitle, isPresented: $showSaveFailedAlert) {
            Button(wizardL10n.done, role: .cancel) { }
        } message: {
            Text(saveFailedMessage.isEmpty ? wizardL10n.petWizSaveFailedDefault : saveFailedMessage)
        }
        // P0 留存：首日承诺 Sheet
        .sheet(item: day0PromiseBinding) { info in
            Day0PromiseSheet(
                petName: info.name,
                species: info.species,
                petEmoji: info.emoji
            ) {
                pendingDay0Promise = nil
                onComplete()
            }
            .interactiveDismissDisabled()
        }
    }

    /// 把 pending(name, species, emoji) 适配为 Identifiable 以用于 `.sheet(item:)`
    private var day0PromiseBinding: Binding<Day0PromiseInfo?> {
        Binding(
            get: {
                guard let p = pendingDay0Promise else { return nil }
                return Day0PromiseInfo(name: p.name, species: p.species, emoji: p.emoji)
            },
            set: { newValue in
                if newValue == nil { pendingDay0Promise = nil }
            }
        )
    }

    // MARK: - Bento Sections

    // MARK: - Name Card（名字 + 物种）
    private var nameCard: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 16) {
            bentoLabel(l.petWizBentoBasic)

            // 大字名字输入框
            VStack(spacing: 6) {
                TextField(l.petWizNamePlaceholder, text: $name)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 16).padding(.horizontal, 16)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                name.isEmpty ? Color.red.opacity(0.35) :
                                isNameDuplicate ? Color.orange.opacity(0.7) : Color.goPrimary.opacity(0.5),
                                lineWidth: 1.5
                            )
                    )
                if isNameDuplicate {
                    Text(l.humanWizDupNameInline)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "FF9500"))
                }
            }

            // 物种选择横向胶囊
            Text(l.petWizSpecies).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(speciesOptions, id: \.self) { sp in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            species = sp
                            breed = ""
                            isCustomBreed = false
                            customBreedText = ""
                            isBreedPickerExpanded = false
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: sp))
                                    .font(.system(size: 22, weight: .bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(species == sp ? Color.arkInk : Color.primary)
                                Text(l.petSpeciesLabel(sp))
                                    .font(.system(size: 11, weight: species == sp ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(species == sp ? Color.arkInk : Color.primary)
                            }
                            .frame(width: 60, height: 60)
                            .background(species == sp ? Color.goPrimary : Color.primary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .scaleEffect(species == sp ? 0.95 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: species)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 2)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Breed Card（默认收起；点按展开后再搜索与列表；选「其他」后出现自定义输入）
    private var breedCard: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(l.petWizBentoBreed)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
                Spacer()
                if !breedFootnoteForCard.isEmpty {
                    Text(breedFootnoteForCard)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(accentColor.opacity(0.12), in: Capsule())
                } else if isCustomBreed {
                    Text(l.petSpeciesLabel("其他"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isBreedPickerExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isBreedPickerExpanded ? l.petWizBreedCollapse : l.petWizBreedExpand)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                        Text(breedCollapseSummary)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary.opacity(0.45))
                        .rotationEffect(.degrees(isBreedPickerExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14).padding(.vertical, 14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.22), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isBreedPickerExpanded {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary.opacity(0.4))
                    TextField(l.petWizBreedSearchPh, text: $breedSearch)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                    if !breedSearch.isEmpty {
                        Button { breedSearch = "" } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(.primary.opacity(0.45))
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.08), in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                let breeds = currentBreeds
                if breeds.isEmpty {
                    Text(l.petWizBreedNoMatch)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.35))
                } else {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 6) {
                            let noneSelected = breed.isEmpty && !isCustomBreed
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                breed = ""
                                breedSearch = ""
                                isCustomBreed = false
                                customBreedText = ""
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    isBreedPickerExpanded = false
                                }
                            } label: {
                                HStack {
                                    Text(l.petWizBreedNone)
                                        .font(.system(size: 15, weight: noneSelected ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if noneSelected {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(noneSelected ? accentColor.opacity(0.15) : Color.white.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            ForEach(breeds) { info in
                                let isOther = info.name == "其他"
                                let isSelected = (isOther && isCustomBreed) || (!isCustomBreed && breed == info.name)
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if isOther {
                                        breed = "其他"
                                        isCustomBreed = true
                                        breedSearch = ""
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                            withAnimation(.easeOut(duration: 0.25)) {
                                                proxy.scrollTo("wizardCustomBreedField", anchor: .bottom)
                                            }
                                        }
                                    } else {
                                        breed = info.name
                                        isCustomBreed = false
                                        customBreedText = ""
                                        breedSearch = ""
                                        themeColorHex = info.suggestedThemeHex
                                        coatColor = info.coatColors.first?.name ?? ""
                                        eyeColor = info.eyeColors.first?.name ?? ""
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                            isBreedPickerExpanded = false
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(info.name)
                                            .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .background(isSelected ? accentColor.opacity(0.15) : Color.white.opacity(0.05),
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }

                            if isCustomBreed {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(l.petWizCustomBreed)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.45))
                                    TextField(l.petWizCustomBreedFieldPh, text: $customBreedText)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .padding(12)
                                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.goPrimary.opacity(0.45), lineWidth: 1)
                                        )
                                }
                                .padding(.top, 4)
                                .id("wizardCustomBreedField")
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Avatar Card（头像设置）
    private var avatarCard: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            bentoLabel(l.petWizBentoAvatar)

            // 居中大预览
            ZStack {
                if let data = avatarImageData, let ui = UIImage(data: data) {
                    let isTransparent = ImageCutoutService.isTransparentPNG(data)
                    if isTransparent {
                        Image(uiImage: ui).resizable().scaledToFit()
                            .frame(maxWidth: .infinity).frame(height: 150)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(Color.goPrimary)
                                    .padding(6)
                                    .background(Color.black.opacity(0.55), in: Circle())
                                    .offset(x: 6, y: -6)
                            }
                    } else {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: species))
                            .font(.system(size: 48, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.primary.opacity(0.35))
                        Text(l.petWizAvatarHint)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity).frame(height: 150)
                }
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        avatarImageData != nil ? Color(hex: "FF5A00").opacity(0.4) : Color.white.opacity(0.1),
                        lineWidth: 1.5
                    )
            )
            .onTapGesture { pastePasteboardImage() }
            .animation(.spring(response: 0.4), value: avatarImageData != nil)

            // 三个操作按钮
            HStack(spacing: 10) {
                Button { pastePasteboardImage() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: hasPasteboardImage ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                            .font(.system(size: 13, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                        Text(hasPasteboardImage ? l.humanWizPasteSubject : l.petWizClipboardEmpty)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(hasPasteboardImage ? .black : .primary.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(
                        hasPasteboardImage ? Color(hex: "FF5A00") : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }.buttonStyle(.plain)

                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 13, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                        Text(l.humanWizPhotoLibrary).font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button { showingCamera = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                        Text(l.humanWizCamera).font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }.buttonStyle(.plain)
            }

            if avatarImageData != nil {
                Button { avatarImageData = nil } label: {
                    Text(l.petWizRemoveAvatar)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }

            ProTipSection()
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Bio Section（生物特征：性别/绝育/生日/到家日）
    private var bioSection: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 16) {
            bentoLabel(l.petWizBentoBio)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                // 性别
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.petWizGender).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary.opacity(0.6))
                    ZStack {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 44)
                        HStack(spacing: 0) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred(); gender = "male"
                            } label: {
                                Text("♂").font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(gender == "male" ? .white : .primary.opacity(0.6))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(gender == "male" ? Color(hex: "FF5A00") : Color.clear, in: Capsule())
                            }.buttonStyle(.plain)
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred(); gender = "female"
                            } label: {
                                Text("♀").font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(gender == "female" ? .white : .primary.opacity(0.6))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(gender == "female" ? Color(hex: "FF5A00") : Color.clear, in: Capsule())
                            }.buttonStyle(.plain)
                        }.frame(height: 44)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gender)
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // 绝育
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.petWizNeuter).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary.opacity(0.6))
                    Toggle(l.petWizNeuteredOn, isOn: $isNeutered)
                        .tint(Color(hex: "FF5A00"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // 生日
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.petWizBirthday).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary.opacity(0.6))
                    Toggle(l.petWizToggleOn, isOn: $hasBirthday).tint(Color(hex: "FF5A00"))
                        .font(.system(size: 13, weight: .medium))
                    if hasBirthday {
                        DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                            .labelsHidden().tint(Color(hex: "FF5A00"))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // 到家日
                VStack(alignment: .leading, spacing: 8) {
                    Text(l.petWizHomeDate).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary.opacity(0.6))
                    Toggle(l.petWizToggleOn, isOn: $hasHomeDate).tint(Color.goPrimary)
                        .font(.system(size: 13, weight: .medium))
                    if hasHomeDate {
                        DatePicker("", selection: $homeDate,
                                   in: (hasBirthday ? birthday : .distantPast)...Date(),
                                   displayedComponents: .date)
                            .labelsHidden().tint(Color.goPrimary)
                            .onChange(of: birthday) { _, newBirthday in
                                if homeDate < newBirthday { homeDate = newBirthday }
                            }
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            // 年龄 / 陪伴天数 胶囊
            if hasBirthday && !humanAgeText.isEmpty {
                Label(humanAgeText, systemImage: "person.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .padding(10).background(Color(hex: "FF5A00").opacity(0.12), in: Capsule())
            }
            if hasHomeDate && !daysTogetherText.isEmpty {
                Label(daysTogetherText, systemImage: "heart.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                    .padding(10).background(Color.goPrimary.opacity(0.12), in: Capsule())
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Digital Twin（外貌特征：仅下方毛色/瞳色选色条 + 自定义 sheet；剪影在顶部预览卡）
    private var digitalTwinSection: some View {
        let l = wizardL10n
        let bi = selectedBreedInfo
        let coatItems = (bi?.coatColors.map { ($0.name, $0.hex) }) ?? [
            ("白色", "FFFFFF"), ("黑色", "1C1C1E"), ("棕色", "8B4513"), ("金色", "FFD700"), ("灰色", "8E8E93"),
        ]
        let eyeItems = PetBreedDatabase.refinedEyeColors(breed: bi, coatColor: coatColor).map { ($0.name, $0.hex) }
        let patternItems = PetCoatPattern.patterns(forBreed: bi)
        return VStack(alignment: .leading, spacing: 16) {
            bentoLabel(l.petWizBentoAppearance)

            // ── 颜色快速选色条（去掉顶部两行「毛色/瞳色」入口卡片，减少重复）
            colorSection(
                title: l.petWizCoatSection,
                items: coatItems,
                patternItems: patternItems,
                selected: $coatColor,
                showCustomPicker: $showCoatColorSheet,
                customColor: $customCoatUIColor
            )
            colorSection(
                title: l.petWizEyeSection,
                items: eyeItems,
                patternItems: [],
                selected: $eyeColor,
                showCustomPicker: $showEyeColorSheet,
                customColor: $customEyeUIColor
            )
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Theme Color Section（主题色，置于末尾）
    private var themeColorSection: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 16) {
            bentoLabel(l.petWizBentoTheme)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: themeColorHex))
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    )
                    .animation(.spring(response: 0.3), value: themeColorHex)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l.petWizCardThemeCaption).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.7))
                    Text("#\(themeColorHex.uppercased())").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.primary.opacity(0.4))
                }
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                ForEach(PetThemeColor.allCases, id: \.rawValue) { tc in
                    let tcHex = tc.hexValue
                    let isUsed = usedThemeColorHexes.contains(tcHex.uppercased())
                    Button { if !isUsed { withAnimation(.spring(response: 0.3)) { themeColorHex = tcHex } } } label: {
                        ZStack {
                            Circle().fill(tc.color.opacity(isUsed ? 0.3 : 1.0)).frame(width: 40, height: 40)
                            if themeColorHex.uppercased() == tcHex.uppercased() {
                                Circle().strokeBorder(.white, lineWidth: 2.5)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .black))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.primary)
                            }
                            if isUsed {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.primary.opacity(0.5))
                            }
                        }
                    }.disabled(isUsed)
                }
                ColorPicker("", selection: Binding(
                    get: { Color(hex: themeColorHex) },
                    set: { newColor in if let hex = newColor.toHex() { themeColorHex = hex } }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 40, height: 40)
                .scaleEffect(1.3)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - 性格标签（可选，最多 3）
    private var petTagsSection: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(l.petWizBentoTagsTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
                Text(l.petWizOptionalParen)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                Spacer()
                Text(l.petWizTagPicked(selectedPersonalityTagIds.count))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.38))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(PetPersonalityTag.allTags) { tag in
                    let isOn = selectedPersonalityTagIds.contains(tag.id)
                    personalityTagChip(
                        symbol: tag.sfSymbol,
                        title: tag.title(isEnglish: l.isEn),
                        isOn: isOn
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        togglePersonalityTag(tag.id)
                    }
                }
                ForEach(decodedCustomPersonalityTags) { rec in
                    let isOn = selectedPersonalityTagIds.contains(rec.id)
                    personalityTagChip(
                        symbol: "tag.fill",
                        title: rec.title(isEnglish: l.isEn),
                        isOn: isOn
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        togglePersonalityTag(rec.id)
                    }
                }
            }

            if isComposingCustomPersonalityTag {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(
                        l.isEn ? "Tag name" : "标签名称",
                        text: $newCustomPersonalityTagText
                    )
                    .focused($customPersonalityTagFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                    HStack(spacing: 10) {
                        Button {
                            cancelCustomPersonalityTagComposer()
                        } label: {
                            Text(l.isEn ? "Cancel" : "取消")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            commitCustomPersonalityTag()
                        } label: {
                            Text(l.isEn ? "OK" : "确认")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.arkInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(newCustomPersonalityTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.goPrimary.opacity(0.28), lineWidth: 1)
                )
                .onAppear { customPersonalityTagFieldFocused = true }
            } else {
                Button {
                    newCustomPersonalityTagText = ""
                    isComposingCustomPersonalityTag = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                        Text(l.isEn ? "Add custom tag" : "添加自定义标签")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.goPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func personalityTagChip(symbol: String, title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .symbolRenderingMode(.monochrome)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
            .foregroundStyle(isOn ? Color.black : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isOn ? Color.goPrimary : Color.primary.opacity(0.06),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(isOn ? 0 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func togglePersonalityTag(_ id: String) {
        if let idx = selectedPersonalityTagIds.firstIndex(of: id) {
            selectedPersonalityTagIds.remove(at: idx)
        } else if selectedPersonalityTagIds.count < 3 {
            selectedPersonalityTagIds.append(id)
        }
    }

    private func cancelCustomPersonalityTagComposer() {
        isComposingCustomPersonalityTag = false
        newCustomPersonalityTagText = ""
        customPersonalityTagFieldFocused = false
    }

    private func commitCustomPersonalityTag() {
        let zh = newCustomPersonalityTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !zh.isEmpty else { return }
        var list = decodedCustomPersonalityTags
        guard list.count < 40 else { return }
        list.append(CustomPersonalityTagRecord(id: "u.\(UUID().uuidString)", titleZh: zh, titleEn: zh))
        guard let data = try? JSONEncoder().encode(list),
              let s = String(data: data, encoding: .utf8) else { return }
        customPersonalityTagsJSON = s
        cancelCustomPersonalityTagComposer()
    }

    // MARK: - Confirm Bar（居中荧光绿胶囊，无底部磨砂条）
    private var confirmBar: some View {
        let l = wizardL10n
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let nameOk = !trimmed.isEmpty && !isNameDuplicate
        let highlight = nameOk || isSaving
        return HStack {
            Spacer(minLength: 28)
            Button {
                guard nameOk, !isSaving else { return }
                if isNameDuplicate { showDuplicateNameAlert = true; return }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                savePet()
            } label: {
                HStack(spacing: 10) {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(
                        trimmed.isEmpty ? l.humanWizNeedName :
                            isNameDuplicate ? l.humanWizNameTakenBtn :
                            isSaving ? l.petWizSaving : l.humanWizJoinIsland
                    )
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    if !isSaving {
                        Image(systemName: nameOk ? "checkmark.circle.fill" : "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                    }
                }
                .foregroundStyle(highlight ? Color.black : Color.primary.opacity(0.42))
                .padding(.horizontal, 22)
                .padding(.vertical, 13)
                .background(
                    highlight ? Color.goPrimary : Color.primary.opacity(0.08),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(highlight ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
                )
                .animation(.spring(response: 0.3), value: nameOk)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(trimmed.isEmpty || isNameDuplicate || isSaving)
            Spacer(minLength: 28)
        }
        .padding(.vertical, 6)
    }

    private func bentoLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.7))
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Step 0: Basic Info
    private var stepBasicInfo: some View {
        let l = wizardL10n
        return VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label(l.petWizNameLabelRequired, systemImage: "pencil")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
                TextField(l.petWizNamePlaceholder, text: $name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(name.isEmpty ? Color.goRed.opacity(0.5) : Color.goPrimary.opacity(0.4), lineWidth: 1.5))
            }
            VStack(alignment: .leading, spacing: 8) {
                Label(l.petWizSpecies, systemImage: "pawprint.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(speciesOptions, id: \.self) { sp in
                        Button {
                            species = sp
                            breed = ""
                            isCustomBreed = false
                            customBreedText = ""
                            coatColor = ""
                            eyeColor = ""
                            isBreedPickerExpanded = false
                        } label: {
                            VStack(spacing: 6) {
                                Text(speciesEmoji(sp)).font(.system(size: 28))
                                Text(l.petSpeciesLabel(sp))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(species == sp ? .black : .white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(species == sp ? Color.goPrimary : .white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 1: Breed
    private var stepBreed: some View {
        let l = wizardL10n
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.primary.opacity(0.6))
                TextField(l.petWizBreedSearchPrompt, text: $breedSearch)
                    .foregroundStyle(.primary)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                if !breedSearch.isEmpty {
                    Button { breedSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.primary.opacity(0.6))
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
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary) }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(isSelected ? accentColor.opacity(0.15) : .white.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if isCustomBreed {
                        TextField(l.petWizBreedFieldPh, text: $customBreedText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(12)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.goPrimary.opacity(0.5), lineWidth: 1))
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
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - 头像预览 Badge
    private var avatarPreviewBadge: some View {
        ZStack {
            // 有图时强调主题色底板；未选图时仅保留极淡占位，避免像「默认头像」
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(avatarImageData != nil ? accentColor.opacity(0.22) : Color.primary.opacity(0.06))
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
                                .foregroundStyle(Color.goPrimary)
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
                Color.clear
                    .frame(width: 120, height: 120)
                    .contentShape(Rectangle())
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 2)
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
                                colors: [Color.goPrimary, Color(hex: "A8E44A")],
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
                        color: hasPasteboardImage ? Color.goPrimary.opacity(pasteBreathing ? 0.55 : 0.15) : .clear,
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
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(hasPasteboardImage ? .black : .white.opacity(0.6))
                            Text(hasPasteboardImage ? "检测到剪贴板有图 · 点击直达裁剪" : "先在相册长按宠物主体并拷贝")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(hasPasteboardImage ? .black.opacity(0.65) : .white.opacity(0.35))
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
                .foregroundStyle(.primary.opacity(0.75))
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
                .foregroundStyle(.primary.opacity(0.75))
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
                .background(Color.goPrimary, in: Circle())
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.7))
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
                        .foregroundStyle(.primary)
                }
                .tint(Color.goPrimary)
                if hasBirthday {
                    DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical).tint(accentColor)
                    if !humanAgeText.isEmpty {
                        Label(humanAgeText, systemImage: "person.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
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
                        .foregroundStyle(.primary)
                }
                .tint(Color.goPrimary)
                if hasHomeDate {
                    let homeLower: Date = hasBirthday ? birthday : .distantPast
                    DatePicker("", selection: $homeDate, in: homeLower...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical).tint(accentColor)
                        .onChange(of: birthday) { _, newBirthday in
                            if homeDate < newBirthday { homeDate = newBirthday }
                        }
                    if !daysTogetherText.isEmpty {
                        Label(daysTogetherText, systemImage: "heart.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                            .padding(10)
                            .background(Color.goPrimary.opacity(0.12), in: Capsule())
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
                        Text(label).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                        Spacer()
                        if gender == val { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary) }
                    }
                    .padding(16)
                    .background(gender == val ? Color.goPrimary.opacity(0.12) : .white.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 14))
                }
            }
            Toggle(isOn: $isNeutered) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已绝育 / 已结扎").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                    Text("对长期健康有益").font(.system(size: 12)).foregroundStyle(.primary.opacity(0.4))
                }
            }
            .tint(Color.goPrimary)
            .padding(16)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Step 5: Birthplace
    private var stepBirthplace: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("出生国家").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.45))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PetBreedDatabase.countries, id: \.self) { country in
                            Button { birthCountry = country; birthCity = ""; isCustomCity = false } label: {
                                Text(country)
                                    .font(.system(size: 13, weight: birthCountry == country ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(birthCountry == country ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(birthCountry == country ? Color.goPrimary : .white.opacity(0.08), in: Capsule())
                            }
                        }
                    }
                }
            }
            if !birthCountry.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("出生城市").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.45))
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
                                    .background(birthCity == city ? Color.goPrimary : .white.opacity(0.06),
                                                in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    if isCustomCity {
                        TextField("输入城市名称", text: $birthCity)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary).padding(12)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Step 6: Identity
    private var stepIdentity: some View {
        let l = wizardL10n
        return VStack(spacing: 16) {
            wizardField(label: l.petWizPassportLabel, placeholder: l.petWizOptionalShort, text: $passportNumber, icon: "doc.fill")
            wizardField(label: l.petWizMicrochipLabel, placeholder: l.petWizMicrochipPlaceholder, text: $microchipID, icon: "cpu")
        }
    }

    // MARK: - Step 7.5: Family Relations
    private var sameSpeciesPets: [Pet] {
        existingPets.filter { $0.species == species }
    }

    private var stepFamilyRelation: some View {
        let l = wizardL10n
        return VStack(spacing: 16) {
            if sameSpeciesPets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.primary.opacity(0.2))
                    Text(species.isEmpty ? l.petWizPickSpeciesFirst : l.petWizNoSameSpeciesPets)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                    Text(l.petWizCrossBreedHint)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.25))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text(l.petWizPickRelationIntro)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
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
                                    .foregroundStyle(.primary)
                                Text("\(existPet.species) · \(existPet.ageText)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.4))
                            }
                            Spacer()
                            if currentRelation != nil {
                                Button {
                                    selectedRelations.removeAll { $0.petId == existPet.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.primary.opacity(0.4))
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
                                        .background(isSelected ? Color.goPrimary : .white.opacity(0.08),
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

    // MARK: - Resolved colors for silhouette preview
    private var resolvedCoatColor: Color {
        if coatColor == "自定义" { return customCoatUIColor }
        let bi = selectedBreedInfo
        let coatItems = bi?.coatColors ?? PetBreedDatabase.genericCoatColors
        if let found = coatItems.first(where: { $0.name == coatColor }) { return found.color }
        // 检查图案（须为当前品种允许的花色）
        if let pattern = PetCoatPattern.patterns(forBreed: bi).first(where: { $0.displayName == coatColor }) {
            // 图案没法直接变成 Color，用默认暖色
            switch pattern {
            case .calico: return Color(hex: "D4B896")
            case .silverChinchilla: return Color(hex: "C8C8C8")
            case .tortoiseshell: return Color(hex: "6E2C00")
            case .cowPattern: return .white
            case .bicolor: return Color(hex: "95ADBE")
            }
        }
        return Color(hex: "E8C49A") // fallback 杏色
    }
    private var resolvedEyeColor: Color {
        if eyeColor == "自定义" { return customEyeUIColor }
        let eyeItems = PetBreedDatabase.refinedEyeColors(breed: selectedBreedInfo, coatColor: coatColor)
        if let found = eyeItems.first(where: { $0.name == eyeColor }) { return found.color }
        return Color(hex: "6B3A2A") // fallback 棕色
    }

    // MARK: - Step 8: Appearance
    @State private var showCoatSheet = false
    @State private var showEyeSheet = false

    private var stepAppearance: some View {
        let l = wizardL10n
        let bi = selectedBreedInfo
        let coatItems = (bi?.coatColors.map { ($0.name, $0.hex) }) ?? PetBreedDatabase.genericCoatColors.map { ($0.name, $0.hex) }
        let eyeItems = PetBreedDatabase.refinedEyeColors(breed: bi, coatColor: coatColor).map { ($0.name, $0.hex) }
        let coatPatterns = PetCoatPattern.patterns(forBreed: bi)
        let breedSubtitle = breed.isEmpty ? l.petSpeciesLabel(species) : breed

        return VStack(spacing: 24) {

            // ── 互动宠物剪影（点击不同部位触发选色）
            VStack(spacing: 6) {
                PetSilhouetteView(
                    species: species,
                    coatColor: resolvedCoatColor,
                    eyeColor: resolvedEyeColor,
                    patternName: coatPatterns.first(where: { $0.displayName == coatColor })?.displayName,
                    onTapCoat: { showCoatSheet = true },
                    onTapEye:  { showEyeSheet  = true }
                )
                .animation(.easeInOut(duration: 0.3), value: resolvedCoatColor.description)
                .animation(.easeInOut(duration: 0.3), value: resolvedEyeColor.description)

                // 操作提示
                HStack(spacing: 16) {
                    Label {
                        Text(l.petWizTapBodyCoat)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Circle()
                            .fill(resolvedCoatColor)
                            .frame(width: 10, height: 10)
                    }
                    Label {
                        Text(l.petWizTapEyeColor)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Circle()
                            .fill(resolvedEyeColor)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 4)
            }

            GoDashedDivider()

            // ── 主题色选择
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(l.petWizThemeSection).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.6))
                    Spacer()
                    Text(l.petWizCardBgCaption).font(.system(size: 11, weight: .medium)).foregroundStyle(.primary.opacity(0.3))
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                    ForEach(PetThemeColor.allCases, id: \.rawValue) { tc in
                        let tcHex = tc.hexValue
                        let isUsed = usedThemeColorHexes.contains(tcHex.uppercased())
                        Button { themeColorHex = tcHex } label: {
                            ZStack {
                                Circle().fill(tc.color.opacity(isUsed ? 0.3 : 1.0)).frame(width: 40, height: 40)
                                if themeColorHex.uppercased() == tcHex.uppercased() {
                                    Circle().strokeBorder(.white, lineWidth: 2.5)
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                                }
                                if isUsed {
                                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.primary.opacity(0.5))
                                }
                            }
                        }
                        .disabled(isUsed)
                    }
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: themeColorHex) },
                        set: { newColor in if let hex = newColor.toHex() { themeColorHex = hex } }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 40, height: 40)
                    .scaleEffect(1.3)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: themeColorHex))
                        .frame(width: 28, height: 28)
                    Text("\(l.petWizCardPreviewHex)\(themeColorHex.uppercased())")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.45))
                }
            }
        }
        // ── 毛色选择 Sheet
        .sheet(isPresented: $showCoatSheet) {
            ColorPickerSheet(
                title: l.petWizPickCoatTitle,
                subtitle: breedSubtitle,
                items: coatItems,
                patternItems: coatPatterns,
                selected: $coatColor,
                customColor: $customCoatUIColor,
                showCustomPicker: $showCoatColorPicker
            )
            .onChange(of: coatColor) { _, newColor in
                autoMapThemeFromCoat(newColor, items: coatItems)
            }
        }
        // ── 瞳色选择 Sheet
        .sheet(isPresented: $showEyeSheet) {
            ColorPickerSheet(
                title: l.petWizPickEyeTitle,
                subtitle: breedSubtitle,
                items: eyeItems,
                patternItems: [],
                selected: $eyeColor,
                customColor: $customEyeUIColor,
                showCustomPicker: $showEyeColorPicker
            )
        }
    }

    // MARK: - Color Picker Sheet（弹出选色面板）
    private struct ColorPickerSheet: View {
        let title: String
        let subtitle: String
        let items: [(String, String)]
        let patternItems: [PetCoatPattern]
        @Binding var selected: String
        @Binding var customColor: Color
        @Binding var showCustomPicker: Bool
        @Environment(\.dismiss) private var dismiss
        @AppStorage("appLanguage") private var appLanguage = "zh"
        private var l: L10n { L10n(appLanguage) }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 颜色网格
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                            spacing: 12
                        ) {
                            ForEach(items, id: \.0) { name, hex in
                                colorCell(name: name, hex: hex, isPattern: false)
                            }
                            ForEach(patternItems, id: \.rawValue) { pattern in
                                colorCell(name: pattern.displayName, hex: patternPreviewHex(pattern), isPattern: true)
                            }
                            // 自定义
                            customCell
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 40)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(l.done) { dismiss() }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .sheet(isPresented: $showCustomPicker) {
                ColorPicker(l.petWizCustomColorPickerTitle, selection: $customColor, supportsOpacity: false)
                    .padding(32)
                    .presentationDetents([.height(320)])
            }
        }

        @ViewBuilder
        private func colorCell(name: String, hex: String, isPattern: Bool) -> some View {
            let isSelected = selected == name
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    selected = name
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: hex).opacity(0.4), radius: 6, x: 0, y: 3)
                        if isSelected {
                            Circle().strokeBorder(.white, lineWidth: 2.5)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    Text(l.petCoatOrEyeDisplay(name))
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Color(hex: hex).opacity(0.12)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }

        private var customCell: some View {
            let isSelected = selected == "自定义"
            return Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selected = "自定义" }
                showCustomPicker = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? customColor : Color.secondary.opacity(0.2))
                            .frame(width: 44, height: 44)
                        if !isSelected {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        if isSelected {
                            Circle().strokeBorder(.white, lineWidth: 2.5)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                    Text(l.petCustomSwatch)
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isSelected ? customColor.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }

        private func patternPreviewHex(_ pattern: PetCoatPattern) -> String {
            switch pattern {
            case .calico: return "D4B896"
            case .silverChinchilla: return "C8C8C8"
            case .tortoiseshell: return "6E2C00"
            case .cowPattern: return "F5F5F0"
            case .bicolor: return "95ADBE"
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
                .font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.primary)

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
                confirmCell(icon: "paintpalette.fill", label: "主题色", value: "#\(themeColorHex.uppercased())")
            }

            if hasBirthday && !humanAgeText.isEmpty {
                Label(humanAgeText, systemImage: "person.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.8))
                    .padding(10).background(accentColor.opacity(0.12), in: Capsule())
            }
            if hasHomeDate && !daysTogetherText.isEmpty {
                Label(daysTogetherText, systemImage: "heart.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.8))
                    .padding(10).background(Color.goPrimary.opacity(0.12), in: Capsule())
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Reusable helpers
    private func wizardField(label: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.45))
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.primary)
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
                .foregroundStyle(.primary.opacity(0.6))
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
                                            .font(.system(size: 11, weight: .black)).foregroundStyle(.primary)
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
                                            .font(.system(size: 11, weight: .black)).foregroundStyle(.primary)
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
                                        .font(.system(size: 11, weight: .black)).foregroundStyle(.primary)
                                } else {
                                    Circle()
                                        .fill(LinearGradient(colors: [.red,.orange,.yellow,.green,.blue,.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.primary)
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
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.primary.opacity(0.4))
                Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.primary).lineLimit(1)
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
        guard !isSaving else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !isNameDuplicate else { return }

        isSaving = true
        let finalBreed = isCustomBreed ? customBreedText : breed
        let pet = Pet(
            name: trimmedName, species: effectiveSpeciesForData, breed: finalBreed,
            birthday: hasBirthday ? birthday : nil,
            gender: gender, isNeutered: isNeutered,
            avatarEmoji: speciesEmoji(effectiveSpeciesForData),
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
        pet.personalityTagsRaw = selectedPersonalityTagIds.joined(separator: ",")
        modelContext.insert(pet)

        // 先单独持久化 Pet：若后续事件/里程碑等写入失败，用户仍能在首页看到新宠物
        do {
            try modelContext.save()
        } catch {
            isSaving = false
            saveFailedMessage = error.localizedDescription
            showSaveFailedAlert = true
            modelContext.delete(pet)
            try? modelContext.save()
            return
        }

        insertPetRelatedRecords(pet: pet, displayName: trimmedName)
        modelContext.safeSave()

        // P0 留存：AHA 破壳动画 — 保存成功后播放 3s，并在之后弹出首日承诺 Sheet
        ahaPetName = trimmedName
        ahaPetEmoji = speciesEmoji(effectiveSpeciesForData)
        withAnimation(.easeOut(duration: 0.3)) { showAhaOverlay = true }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Q4: 欢呼算结 — 岛屿第一家人成就
        let isFirstPet = !QuestManager.shared.isPetWizardCompleted
        if isFirstPet {
            QuestManager.shared.isPetWizardCompleted = true
            QuestManager.shared.addCoconuts(50, emoji: "🎉", reason: "新家人入住欢迎奖励")
        }

        // AHA 动画 3s 后自动收起并推出首日承诺 Sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.35)) { showAhaOverlay = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isSaving = false
                pendingDay0Promise = (
                    name: trimmedName,
                    species: effectiveSpeciesForData,
                    emoji: speciesEmoji(effectiveSpeciesForData)
                )
            }
        }
    }

    /// 生日/纪念日/里程碑/家庭关系等非核心数据；失败时 safeSave 仅打日志，不影响已写入的 Pet
    private func insertPetRelatedRecords(pet: Pet, displayName: String) {
        if themeColorHex != "C8FF00" {
            QuestManager.shared.recordThemeColorSet()
        }

        if hasBirthday {
            let birthdayEvent = Event(
                title: "\(displayName) 的生日 🎂",
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

        if hasHomeDate {
            let anniversaryEvent = Event(
                title: "\(displayName) 的到家纪念日 🏠",
                startDate: homeDate,
                isAllDay: true,
                eventType: EventType.anniversary.rawValue,
                relatedEntityType: "Pet",
                relatedEntityId: pet.id.uuidString
            )
            anniversaryEvent.recurrenceDays = 365
            modelContext.insert(anniversaryEvent)
        }

        if hasHomeDate {
            let milestones = [100, 365, 500, 730, 1000, 1095]
            for days in milestones {
                if let date = Calendar.current.date(byAdding: .day, value: days, to: homeDate) {
                    let milestone = PetMilestone(
                        date: date,
                        title: wizardL10n.petWizMilestoneTogether(days),
                        emoji: days >= 1000 ? "🏆" : "🎉",
                        pet: pet
                    )
                    modelContext.insert(milestone)
                }
            }
        }

        for rel in selectedRelations {
            let forward = PetRelationship(fromPetId: pet.id, toPetId: rel.petId, type: rel.type)
            modelContext.insert(forward)
        }
    }

    // MARK: - Wizard Pager Helpers

    private func pagedCard<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .goTranslucentCard(cornerRadius: 24)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var wizardCardMesh: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                SIMD2(0.0, 0.5), SIMD2(0.55, 0.40), SIMD2(1.0, 0.5),
                SIMD2(0.0, 1.0), SIMD2(0.5,  1.0), SIMD2(1.0, 1.0)
            ],
            colors: [
                Color(hex: "C8FF00"), Color(hex: "C2F20A"), Color(hex: "9ADB00"),
                Color(hex: "DEFF8A"), Color(hex: "C8FF00"), Color(hex: "76B000"),
                Color(hex: "AADC00"), Color(hex: "7CB800"), Color(hex: "3B5F00")
            ]
        )
    }

    private func meshCardLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.6))
            .tracking(0.8)
            .textCase(.uppercase)
    }

    // MARK: - Wizard Card 1
    private var wizardCard1BasicInfo: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            meshCardLabel(l.petWizMesh1).padding(.top, 14).padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                TextField(l.petWizNamePlaceholder, text: $name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 14).padding(.horizontal, 16)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                name.isEmpty ? Color.red.opacity(0.5) :
                                isNameDuplicate ? Color.orange.opacity(0.7) : Color.goPrimary.opacity(colorScheme == .dark ? 0.55 : 0.4),
                                lineWidth: 1.5
                            )
                    )
                if isNameDuplicate {
                    Text(l.humanWizDupNameInline)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "FF6B00")).padding(.leading, 4)
                }
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text(l.petWizSpecies)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(speciesOptions, id: \.self) { sp in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            species = sp
                            if sp != "其他" { customSpeciesText = "" }
                            breed = ""; isCustomBreed = false; customBreedText = ""; isBreedPickerExpanded = false
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: sp))
                                    .font(.system(size: 20, weight: .bold)).symbolRenderingMode(.monochrome)
                                    .foregroundStyle(species == sp ? Color.arkInk : Color.primary.opacity(0.85))
                                Text(l.petSpeciesLabel(sp))
                                    .font(.system(size: 11, weight: species == sp ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(species == sp ? Color.arkInk : .secondary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(
                                species == sp ? Color.goPrimary : Color.primary.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .scaleEffect(species == sp ? 0.96 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: species)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                if species == "其他" {
                    TextField(l.petWizSpeciesOtherPh, text: $customSpeciesText)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(customSpeciesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.goRed.opacity(0.35) : Color.goPrimary.opacity(0.35), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                }
            }

            Button { showBreedPickerSheet = true } label: {
                HStack {
                    Image(systemName: "list.bullet").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.petWizBentoBreed).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.primary.opacity(0.55))
                        Text(breedCollapseSummary).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome).foregroundStyle(Color.primary.opacity(0.45))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain).padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Wizard Card 2
    private var wizardCard2Avatar: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            meshCardLabel(l.petWizMesh2).padding(.top, 14).padding(.horizontal, 20)

            ZStack {
                if let data = avatarImageData, let ui = UIImage(data: data) {
                    let isTransparent = ImageCutoutService.isTransparentPNG(data)
                    if isTransparent {
                        Image(uiImage: ui).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 130)
                    } else {
                        Image(uiImage: ui).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                } else {
                    // 未选图 / 未拍照 / 未粘贴：预览区保持空白，仅保留底板与描边
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 130)
                        .contentShape(Rectangle())
                }
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        Color.goPrimary.opacity(avatarImageData != nil ? (colorScheme == .dark ? 0.55 : 0.45) : (colorScheme == .dark ? 0.35 : 0.22)),
                        lineWidth: 1.5
                    )
            )
            .onTapGesture { pastePasteboardImage() }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                Button { pastePasteboardImage() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: hasPasteboardImage ? "doc.on.clipboard.fill" : "doc.on.clipboard").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome)
                        Text(hasPasteboardImage ? l.humanWizPasteSubject : l.petWizClipboardEmpty).font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(hasPasteboardImage ? Color.arkInk : Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(hasPasteboardImage ? Color.goPrimary : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)

                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome)
                        Text(l.humanWizPhotoLibrary).font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button { showingCamera = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome)
                        Text(l.humanWizCamera).font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            if avatarImageData != nil {
                Button { avatarImageData = nil } label: {
                    Text(l.petWizRemoveAvatarShort).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color.primary.opacity(0.55)).frame(maxWidth: .infinity)
                }.padding(.horizontal, 20)
            }

            ProTipSection()
                .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Wizard Card 3
    private var wizardCard3Bio: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            meshCardLabel(l.petWizMesh3).padding(.top, 14).padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(l.petWizGender).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach([("male", l.petWizGenderBoy), ("female", l.petWizGenderGirl), ("unknown", l.petWizGenderUnknown)], id: \.0) { val, label in
                        Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); gender = val } label: {
                            Text(label).font(.system(size: 13, weight: gender == val ? .bold : .medium, design: .rounded))
                                .foregroundStyle(gender == val ? Color.arkInk : Color.primary.opacity(0.85))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(gender == val ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)

            HStack {
                Text(l.petWizNeuter).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $isNeutered).tint(Color.goPrimary).labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l.petWizBirthday).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $hasBirthday).tint(Color.goPrimary).labelsHidden()
                }
                if hasBirthday {
                    DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.goPrimary)
                        .foregroundStyle(.primary)
                    if !humanAgeText.isEmpty {
                        Label(humanAgeText, systemImage: "person.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l.petWizHomeDate).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $hasHomeDate).tint(Color.goPrimary).labelsHidden()
                }
                if hasHomeDate {
                    DatePicker("", selection: $homeDate, in: (hasBirthday ? birthday : .distantPast)...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.goPrimary)
                        .foregroundStyle(.primary)
                        .onChange(of: birthday) { _, newB in if homeDate < newB { homeDate = newB } }
                    if !daysTogetherText.isEmpty {
                        Label(daysTogetherText, systemImage: "heart.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Wizard Card 4
    private var wizardCard4Appearance: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            meshCardLabel(l.petWizMesh4).padding(.top, 14).padding(.horizontal, 20)

            let bi = selectedBreedInfo
            let coatItems = (bi?.coatColors.map { ($0.name, $0.hex) }) ?? PetBreedDatabase.genericCoatColors.map { ($0.name, $0.hex) }
            let eyeItems = PetBreedDatabase.refinedEyeColors(breed: bi, coatColor: coatColor).map { ($0.name, $0.hex) }
            let coatPatterns = PetCoatPattern.patterns(forBreed: bi)

            if bi == nil {
                Text(l.petWizAppearanceNoBreedHint)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            colorSectionOnMesh(title: l.petWizCoatSection, items: coatItems, patternItems: coatPatterns, selected: $coatColor, showCustomPicker: $showCoatColorSheet, customColor: $customCoatUIColor, swatchLayout: .wrappingGrid)
            colorSectionOnMesh(title: l.petWizEyeSection, items: eyeItems, patternItems: [], selected: $eyeColor, showCustomPicker: $showEyeColorSheet, customColor: $customEyeUIColor, swatchLayout: .wrappingGrid)

            VStack(alignment: .leading, spacing: 8) {
                Text(l.petWizThemeSection).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary).padding(.horizontal, 20)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                    ForEach(PetThemeColor.allCases, id: \.rawValue) { tc in
                        let tcHex = tc.hexValue
                        let isUsed = usedThemeColorHexes.contains(tcHex.uppercased())
                        Button { if !isUsed { withAnimation(.spring(response: 0.3)) { themeColorHex = tcHex } } } label: {
                            ZStack {
                                Circle().fill(tc.color.opacity(isUsed ? 0.3 : 1.0)).frame(width: 36, height: 36)
                                if themeColorHex.uppercased() == tcHex.uppercased() {
                                    Circle().strokeBorder(.white, lineWidth: 2)
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.black)
                                }
                                if isUsed { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.primary.opacity(0.55)) }
                            }
                        }.disabled(isUsed)
                    }
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: themeColorHex) },
                        set: { newColor in if let hex = newColor.toHex() { themeColorHex = hex } }
                    ), supportsOpacity: false)
                    .labelsHidden().frame(width: 36, height: 36).scaleEffect(1.2).clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    // MARK: - Wizard Card 5
    private var wizardCard5Tags: some View {
        let l = wizardL10n
        let topTags = PetPersonalityTag.allTags
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                meshCardLabel(l.petWizMesh5)
                Spacer()
                Text(l.petWizTagPicked(selectedPersonalityTagIds.count))
                    .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.primary.opacity(0.55))
            }
            .padding(.top, 14).padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                ForEach(topTags) { tag in
                    let isOn = selectedPersonalityTagIds.contains(tag.id)
                    meshTagChip(symbol: tag.sfSymbol, title: tag.title(isEnglish: l.isEn), isOn: isOn) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(); togglePersonalityTag(tag.id)
                    }
                }
                ForEach(decodedCustomPersonalityTags) { rec in
                    let isOn = selectedPersonalityTagIds.contains(rec.id)
                    meshTagChip(symbol: "tag.fill", title: rec.title(isEnglish: l.isEn), isOn: isOn) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(); togglePersonalityTag(rec.id)
                    }
                }
                if !isComposingCustomPersonalityTag {
                    Button {
                        newCustomPersonalityTagText = ""
                        isComposingCustomPersonalityTag = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold)).symbolRenderingMode(.monochrome)
                            Text(l.petCustomSwatch).font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
              }
              .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)

            if isComposingCustomPersonalityTag {
                HStack(spacing: 8) {
                    TextField(l.isEn ? "Tag name" : "标签名称", text: $newCustomPersonalityTagText)
                        .focused($customPersonalityTagFieldFocused)
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
                        .textFieldStyle(.plain).padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity)
                    Button { cancelCustomPersonalityTagComposer() } label: {
                        Text(l.cancel).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Color.primary.opacity(0.05), in: Capsule())
                    }.buttonStyle(.plain)
                    Button { commitCustomPersonalityTag() } label: {
                        Text(l.confirm).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.white)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(.secondary, in: Capsule())
                    }.buttonStyle(.plain).disabled(newCustomPersonalityTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 20)
                .onAppear { customPersonalityTagFieldFocused = true }
            }

            Spacer()
        }
    }

    private func meshTagChip(symbol: String, title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 12, weight: .bold)).symbolRenderingMode(.monochrome)
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(isOn ? Color.arkInk : Color.primary.opacity(0.85))
            .padding(.horizontal, 10).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isOn ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.black.opacity(isOn ? 0 : 0.12), lineWidth: 1))
        }.buttonStyle(.plain)
    }

    // MARK: - Wizard Card 6
    private var wizardCard6Confirm: some View {
        let l = wizardL10n
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                meshCardLabel(l.petWizMesh6).padding(.top, 14)

                HStack(spacing: 14) {
                    if let data = avatarImageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(Circle())
                    } else {
                        Circle().fill(Color(hex: themeColorHex).opacity(0.3)).frame(width: 56, height: 56)
                            .overlay(Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: effectiveSpeciesForData)).font(.system(size: 22, weight: .bold)).symbolRenderingMode(.monochrome).foregroundStyle(.secondary))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? l.petWizUnnamed : name).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.primary)
                        Text(
                            breed.isEmpty
                                ? l.petSpeciesLabel(effectiveSpeciesForData)
                                : "\(l.petSpeciesLabel(effectiveSpeciesForData)) · \(breed)"
                        )
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    confirmMeshCell(icon: "person.fill", label: l.petWizGender, value: gender == "male" ? l.petWizGenderBoy : gender == "female" ? l.petWizGenderGirl : l.petWizGenderUnknown)
                    confirmMeshCell(icon: "scissors", label: l.petWizNeuter, value: isNeutered ? l.petWizNeuteredOn : l.petWizNeuteredOff)
                    if hasBirthday { confirmMeshCell(icon: "gift.fill", label: l.petWizBirthday, value: birthday.formatted(.dateTime.year().month().day())) }
                    if hasHomeDate { confirmMeshCell(icon: "house.fill", label: l.petWizHomeDate, value: homeDate.formatted(.dateTime.year().month().day())) }
                    if !coatColor.isEmpty { confirmMeshCell(icon: "paintpalette.fill", label: l.petWizCoatSection, value: l.petCoatOrEyeDisplay(coatColor)) }
                    if !eyeColor.isEmpty  { confirmMeshCell(icon: "eye.fill",  label: l.petWizEyeSection, value: l.petCoatOrEyeDisplay(eyeColor)) }
                    // Theme color swatch
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: themeColorHex)).frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 0.5))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l.petWizThemeSection).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3).fill(Color(hex: themeColorHex)).frame(width: 36, height: 12)
                                Text("#\(themeColorHex.uppercased())").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if !selectedPersonalityTagIds.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(selectedPersonalityTagIds, id: \.self) { tid in
                            Text(PetPersonalityTag.displayTitle(for: tid, isEnglish: wizardL10n.isEn))
                                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.primary.opacity(0.85))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                    }
                }

            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let confirmNameOk = !trimmedName.isEmpty && !isNameDuplicate
            Button {
                guard confirmNameOk, !isSaving else { return }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                savePet()
            } label: {
                HStack(spacing: 8) {
                    if isSaving { ProgressView().tint(Color.arkInk) }
                    Text(trimmedName.isEmpty ? l.humanWizNeedName : isNameDuplicate ? l.humanWizNameTakenBtn : isSaving ? l.petWizSavingShort : l.humanWizJoinIsland)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    if !isSaving {
                        Image(systemName: confirmNameOk ? "checkmark.circle.fill" : "lock.fill")
                            .font(.system(size: 15, weight: .bold)).symbolRenderingMode(.monochrome)
                    }
                }
                .foregroundStyle(confirmNameOk ? Color.arkInk : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(confirmNameOk ? Color.goPrimary : Color.primary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!confirmNameOk || isSaving)
            .padding(.top, 4)
        }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private func confirmMeshCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.primary.opacity(0.6)).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Color.primary.opacity(0.55))
                Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.primary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private enum WizardColorSwatchLayout {
        /// 与横向分页手势易冲突，仅用于非分页上下文。
        case horizontalScroll
        /// 自适应换行，用于外貌步骤与 `TabView` 分页并存时。
        case wrappingGrid
    }

    @ViewBuilder
    private func wizardMeshSwatchButtons(
        items: [(String, String)],
        patternItems: [PetCoatPattern],
        selected: Binding<String>,
        showCustomPicker: Binding<Bool>,
        customColor: Binding<Color>
    ) -> some View {
        let l = wizardL10n
        ForEach(items, id: \.0) { colorName, hex in
            Button { selected.wrappedValue = colorName } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                        if selected.wrappedValue == colorName {
                            Circle().strokeBorder(Color.primary.opacity(0.45), lineWidth: 2)
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Color.primary)
                        }
                    }
                    .frame(width: 34, height: 34)
                    Text(l.petCoatOrEyeDisplay(colorName))
                        .font(.system(size: 9, weight: selected.wrappedValue == colorName ? .bold : .medium))
                        .foregroundStyle(selected.wrappedValue == colorName ? Color.primary : Color.primary.opacity(0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 48, height: 28, alignment: .top)
                }
                .frame(width: 50)
            }
        }
        ForEach(patternItems, id: \.rawValue) { pattern in
            Button { selected.wrappedValue = pattern.displayName } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(pattern.gradient).frame(width: 34, height: 34)
                        if selected.wrappedValue == pattern.displayName {
                            Circle().strokeBorder(Color.primary.opacity(0.45), lineWidth: 2)
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Color.primary)
                        }
                    }
                    .frame(width: 34, height: 34)
                    Text(l.petCoatPatternDisplay(pattern.displayName))
                        .font(.system(size: 9, weight: selected.wrappedValue == pattern.displayName ? .bold : .medium))
                        .foregroundStyle(selected.wrappedValue == pattern.displayName ? Color.primary : Color.primary.opacity(0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 48, height: 28, alignment: .top)
                }
                .frame(width: 50)
            }
        }
        Button { showCustomPicker.wrappedValue = true } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selected.wrappedValue == "自定义" {
                        Circle().fill(customColor.wrappedValue).frame(width: 34, height: 34)
                        Circle().strokeBorder(Color.primary.opacity(0.45), lineWidth: 2).frame(width: 34, height: 34)
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Color.primary)
                    } else {
                        Circle().fill(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 34, height: 34)
                    }
                }
                .frame(width: 34, height: 34)
                Text(l.petCustomSwatch)
                    .font(.system(size: 9, weight: selected.wrappedValue == "自定义" ? .bold : .medium))
                    .foregroundStyle(selected.wrappedValue == "自定义" ? Color.primary : Color.primary.opacity(0.55))
                    .lineLimit(1)
                    .frame(width: 48, height: 28, alignment: .top)
            }
            .frame(width: 50)
        }
    }

    // MARK: - Color section for mesh cards
    private func colorSectionOnMesh(
        title: String,
        items: [(String, String)],
        patternItems: [PetCoatPattern],
        selected: Binding<String>,
        showCustomPicker: Binding<Bool>,
        customColor: Binding<Color>,
        swatchLayout: WizardColorSwatchLayout = .horizontalScroll
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary).padding(.horizontal, 20)
            Group {
                switch swatchLayout {
                case .horizontalScroll:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 8) {
                            wizardMeshSwatchButtons(items: items, patternItems: patternItems, selected: selected, showCustomPicker: showCustomPicker, customColor: customColor)
                        }
                        .padding(.horizontal, 20)
                    }
                case .wrappingGrid:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], alignment: .leading, spacing: 10) {
                        wizardMeshSwatchButtons(items: items, patternItems: patternItems, selected: selected, showCustomPicker: showCustomPicker, customColor: customColor)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Wizard Bottom Nav Bar
    private var wizardBottomNavBar: some View {
        let l = wizardL10n
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let nameOk = !trimmed.isEmpty && !isNameDuplicate
        let isLastPage = wizardPageIndex == 5
        return HStack(spacing: 12) {
            if wizardPageIndex > 0 {
                Button { withAnimation(.spring(response: 0.38)) { wizardPageIndex -= 1 } } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary).frame(width: 48, height: 48)
                        .background(Color.primary.opacity(0.1), in: Circle())
                }.buttonStyle(ScaleButtonStyle())
            } else {
                Color.clear.frame(width: 48, height: 48)
            }
            Spacer()
            if isLastPage {
                Button {
                    guard nameOk, !isSaving else { return }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    savePet()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().tint(.black) }
                        Text(trimmed.isEmpty ? l.humanWizNeedName : isNameDuplicate ? l.humanWizNameTakenBtn : isSaving ? l.petWizSaving : l.humanWizJoinIsland)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                        if !isSaving { Image(systemName: nameOk ? "checkmark.circle.fill" : "lock.fill").font(.system(size: 16, weight: .bold)).symbolRenderingMode(.monochrome) }
                    }
                    .foregroundStyle(nameOk ? Color.black : Color.primary.opacity(0.4))
                    .padding(.horizontal, 24).padding(.vertical, 13)
                    .background(nameOk ? Color.goPrimary : Color.primary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle()).disabled(trimmed.isEmpty || isNameDuplicate || isSaving)
            } else {
                Button { withAnimation(.spring(response: 0.38)) { wizardPageIndex += 1 } } label: {
                    HStack(spacing: 6) {
                        Text(l.petWizNext).font(.system(size: 15, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).symbolRenderingMode(.monochrome)
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 24).padding(.vertical, 13)
                    .background(Color.goPrimary, in: Capsule())
                }.buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Breed Picker Sheet
    private var breedPickerSheet: some View {
        let l = wizardL10n
        return NavigationStack {
            ScrollView {
                LazyVStack(spacing: 6) {
                    Button {
                        breed = ""; isCustomBreed = false; customBreedText = ""
                        showBreedPickerSheet = false
                    } label: {
                        HStack {
                            Text(l.petWizBreedNone).font(.system(size: 15, weight: breed.isEmpty && !isCustomBreed ? .bold : .medium, design: .rounded)).foregroundStyle(.primary)
                            Spacer()
                            if breed.isEmpty && !isCustomBreed { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary) }
                        }.padding(.horizontal, 16).padding(.vertical, 12)
                        .background(breed.isEmpty && !isCustomBreed ? Color.goPrimary.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                    ForEach(currentBreeds) { b in
                        let isOther = b.name == "其他"
                        let isSelected = (isOther && isCustomBreed) || (!isCustomBreed && breed == b.name)
                        Button {
                            if isOther { breed = "其他"; isCustomBreed = true }
                            else { breed = b.name; isCustomBreed = false; customBreedText = ""; themeColorHex = b.suggestedThemeHex; coatColor = b.coatColors.first?.name ?? ""; eyeColor = b.eyeColors.first?.name ?? ""; showBreedPickerSheet = false }
                        } label: {
                            HStack {
                                Text(b.name).font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded)).foregroundStyle(.primary)
                                Spacer()
                                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary) }
                            }.padding(.horizontal, 16).padding(.vertical, 12)
                            .background(isSelected ? Color.goPrimary.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if isOther && isCustomBreed {
                            TextField(l.petWizBreedFieldPh, text: $customBreedText).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.primary)
                                .padding(12).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.goPrimary.opacity(0.5), lineWidth: 1))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .searchable(text: $breedSearch, prompt: l.petWizBreedSearchPrompt)
            .navigationTitle(l.petWizBreedSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(l.done) { showBreedPickerSheet = false } } }
        }
        .presentationDetents([.large])
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

extension PetCoatPattern {
    /// 猫向花纹（三花/银渐层/玳瑁/蓝白双色等）仅对猫品种展示；犬等仅保留「奶牛色」等与物种相符的项。
    private static func breedAllowsCatTypicalPatterns(_ breed: BreedInfo) -> Bool {
        let n = breed.name
        if n.hasSuffix("猫") { return true }
        if n.contains("田园猫") { return true }
        if n == "银渐层" || n == "金渐层" { return true }
        return false
    }

    /// 仅展示与当前品种 `coatColors` 名称相匹配的渐变花色；非猫品种过滤掉猫向花纹，避免边牧「蓝白」误配蓝白双色渐变。
    static func patterns(forBreed breed: BreedInfo?) -> [PetCoatPattern] {
        guard let breed else { return [] }
        let names = breed.coatColors.map(\.name)
        let matched = PetCoatPattern.allCases.filter { $0.matchesCoatColorNames(names) }
        guard Self.breedAllowsCatTypicalPatterns(breed) else {
            return matched.filter { $0 == .cowPattern }
        }
        return matched
    }

    fileprivate func matchesCoatColorNames(_ names: [String]) -> Bool {
        if names.contains(displayName) { return true }
        switch self {
        case .calico:
            return names.contains { $0.contains("三花") }
        case .silverChinchilla:
            return names.contains { $0.contains("银渐层") || $0.contains("银底") || $0.contains("浅银") }
        case .tortoiseshell:
            return names.contains { $0.contains("玳瑁") }
        case .cowPattern:
            return names.contains { $0.contains("奶牛") || $0.contains("白底黑斑") || $0.contains("白底肝斑") }
        case .bicolor:
            return names.contains { name in
                name == "蓝白" || name.contains("蓝白双色") || (name.contains("蓝白") && !name.contains("重点"))
            }
        }
    }
}

// MARK: - Pet Age Converter
enum PetAgeConverter {
    static func humanAge(birthday: Date, species: String, isEnglish: Bool) -> String {
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
        if isEnglish {
            return "~ human age \(humanYears) ✨"
        }
        return "相当于人类约 \(humanYears) 岁"
    }
}

// MARK: - Camera Picker
struct PetCameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        // 模拟器等环境无相机，直接 .camera 会抛 NSInvalidArgumentException（source type 1 not available）
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            vc.sourceType = .camera
        } else {
            vc.sourceType = .photoLibrary
        }
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

// MARK: - Image Crop View（取景框与钱包卡同比例，裁剪坐标与屏幕布局一致）
struct PetImageCropView: View {
    let image: UIImage
    /// 用于左半区大轮廓引导
    var species: String = "狗"
    /// 非空时覆盖 `Pet.speciesSilhouetteSymbol(forSpecies:)`（例如人类头像用 `person.fill`）
    var silhouetteSystemName: String? = nil
    let onCrop: (UIImage?) -> Void

    private let cardAspect: CGFloat = 1.586
    private let cornerRadius: CGFloat = 24

    @Environment(\.colorScheme) private var colorScheme

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var fitDisplaySize: CGSize = .zero
    /// 与 performCrop 使用同一容器尺寸（禁止再用 UIScreen 与布局脱节）
    @State private var containerSize: CGSize = .zero

    private func cropSize(for container: CGSize) -> (w: CGFloat, h: CGFloat) {
        let maxW = max(container.width - 24, 220)
        let cw = min(maxW, max(ScreenCompat.width - 48, 220))
        let ch = cw / cardAspect
        return (cw, ch)
    }

    private func minScale(cropW: CGFloat, cropH: CGFloat) -> CGFloat {
        guard fitDisplaySize.width > 0, fitDisplaySize.height > 0 else { return 0.3 }
        let fw = cropW / fitDisplaySize.width
        let fh = cropH / fitDisplaySize.height
        return max(min(fw, fh), 0.3)
    }

    private let maxScale: CGFloat = 6.0

    var body: some View {
        GeometryReader { geo in
            let (cropW, cropH) = cropSize(for: geo.size)
            ZStack {
                Color.black

                Image(uiImage: normalizedImage(image))
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale, anchor: .center)
                    .offset(offset)
                    .simultaneousGesture(
                        SimultaneousGesture(
                            MagnifyGesture()
                                .onChanged { v in
                                    let proposed = lastScale * v.magnification
                                    let mn = minScale(cropW: cropW, cropH: cropH)
                                    scale = min(maxScale, max(mn, proposed))
                                }
                                .onEnded { _ in lastScale = scale },
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    offset = CGSize(
                                        width: lastOffset.width + v.translation.width,
                                        height: lastOffset.height + v.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )

                CardCropOverlay(cropW: cropW, cropH: cropH, cornerRadius: cornerRadius)

                // 左半区大轮廓引导（居中于取景框左半）
                HStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: max(4, cornerRadius - 4), style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.07))
                            .frame(width: cropW / 2, height: cropH)
                        Image(systemName: silhouetteSystemName ?? Pet.speciesSilhouetteSymbol(forSpecies: species))
                            .font(.system(size: min(cropH * 0.52, 128), weight: .bold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.38 : 0.26))
                    }
                    .frame(width: cropW / 2, height: cropH)
                    Color.clear.frame(width: cropW / 2, height: cropH)
                }
                .frame(width: cropW, height: cropH)
                .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.goPrimary, lineWidth: 2)
                    .frame(width: cropW, height: cropH)
                    .allowsHitTesting(false)

                CardCropCorners(width: cropW, height: cropH, radius: cornerRadius)
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Text("双指缩放 · 拖动调整位置")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.bottom, 104)
                }
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                containerSize = geo.size
                let img = normalizedImage(image)
                let iw = img.size.width, ih = img.size.height
                guard iw > 0, ih > 0 else { return }
                let aspectFit = min(geo.size.width / iw, geo.size.height / ih)
                fitDisplaySize = CGSize(width: iw * aspectFit, height: ih * aspectFit)
                let mn = minScale(cropW: cropW, cropH: cropH)
                let s = max(mn, 1.0)
                scale = s
                lastScale = s
            }
            .onChange(of: geo.size) { _, new in
                containerSize = new
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { onCrop(nil) } label: {
                    Text("取消")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button { performCrop() } label: {
                    Text("确认裁剪")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.8))
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
    }

    private func normalizedImage(_ src: UIImage) -> UIImage {
        guard src.imageOrientation != .up else { return src }
        let renderer = UIGraphicsImageRenderer(size: src.size)
        return renderer.image { _ in src.draw(in: CGRect(origin: .zero, size: src.size)) }
    }

    private func performCrop() {
        let viewSize: CGSize = (containerSize.width > 10 && containerSize.height > 10)
            ? containerSize
            : CGSize(width: ScreenCompat.width, height: max(ScreenCompat.height - 300, 420))
        let (cropW, cropH) = cropSize(for: viewSize)
        let src = normalizedImage(image)
        let iw = src.size.width, ih = src.size.height
        guard iw > 0, ih > 0, viewSize.width > 0, viewSize.height > 0 else {
            onCrop(src)
            return
        }

        let fitScale = min(viewSize.width / iw, viewSize.height / ih)
        let totalScale = fitScale * scale
        let displayW = iw * totalScale
        let displayH = ih * totalScale

        let imgOriginX = (viewSize.width - displayW) / 2 + offset.width
        let imgOriginY = (viewSize.height - displayH) / 2 + offset.height

        let cropOriginX = (viewSize.width - cropW) / 2
        let cropOriginY = (viewSize.height - cropH) / 2

        let relX = cropOriginX - imgOriginX
        let relY = cropOriginY - imgOriginY

        let pixelScale = totalScale / src.scale
        let srcX = max(0, relX / pixelScale)
        let srcY = max(0, relY / pixelScale)
        let srcW = cropW / pixelScale
        let srcH = cropH / pixelScale
        let clampedW = min(srcW, iw - srcX)
        let clampedH = min(srcH, ih - srcY)

        guard clampedW > 0, clampedH > 0,
              let cgCrop = src.cgImage?.cropping(to: CGRect(
                x: srcX * src.scale, y: srcY * src.scale,
                width: clampedW * src.scale, height: clampedH * src.scale
              ))
        else {
            onCrop(src)
            return
        }

        let screenScale = UIGraphicsImageRendererFormat.default().scale
        let outW = cropW * screenScale
        let outH = cropH * screenScale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH))
        let cropped = renderer.image { _ in
            UIImage(cgImage: cgCrop).draw(in: CGRect(x: 0, y: 0, width: outW, height: outH))
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
                        .fill(Color.goPrimary)
                        .frame(width: len, height: thick)
                        .offset(x: xSign * (size / 2 - len / 2), y: ySign * (size / 2))
                    // Vertical
                    RoundedRectangle(cornerRadius: thick / 2)
                        .fill(Color.goPrimary)
                        .frame(width: thick, height: len)
                        .offset(x: xSign * (size / 2), y: ySign * (size / 2 - len / 2))
                }
            }
        }
    }
}

// Dim overlay with transparent rectangular crop hole
private struct CardCropOverlay: View {
    let cropW: CGFloat
    let cropH: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                let x = (geo.size.width  - cropW) / 2
                let y = (geo.size.height - cropH) / 2
                path.addRoundedRect(
                    in: CGRect(x: x, y: y, width: cropW, height: cropH),
                    cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
                )
            }
            .fill(style: FillStyle(eoFill: true))
            .foregroundStyle(.black.opacity(0.62))
        }
    }
}

// Corner L-shape indicators for rectangular crop frame
private struct CardCropCorners: View {
    let width: CGFloat
    let height: CGFloat
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
                        .fill(Color.goPrimary)
                        .frame(width: len, height: thick)
                        .offset(x: xSign * (width / 2 - len / 2), y: ySign * (height / 2))
                    // Vertical
                    RoundedRectangle(cornerRadius: thick / 2)
                        .fill(Color.goPrimary)
                        .frame(width: thick, height: len)
                        .offset(x: xSign * (width / 2), y: ySign * (height / 2 - len / 2))
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
                    .foregroundStyle(.primary)

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
                        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Identifiable wrapper for crop image sheet
struct IdentifiableCropImage: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
    static func == (lhs: IdentifiableCropImage, rhs: IdentifiableCropImage) -> Bool { lhs.id == rhs.id }
}

#Preview {
    AddPetWizardView(onComplete: {})
        .modelContainer(SharedModelContainer.make())
}

// MARK: - Day 0 Promise helper types
struct Day0PromiseInfo: Identifiable {
    let id = UUID()
    let name: String
    let species: String
    let emoji: String
}

// MARK: - AHA Hatch Overlay（P0 留存：新宠物"破壳"动画）
private struct AhaHatchOverlay: View {
    let petName: String
    let petEmoji: String

    @State private var crackPhase: CGFloat = 0      // 0 = 整蛋，1 = 完全破壳
    @State private var petScale: CGFloat = 0.4
    @State private var petOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.6
    @State private var glowOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var sparkleRotation: CGFloat = 0

    var body: some View {
        ZStack {
            // 背景渐暗
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // 辐射光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.goPrimary.opacity(0.85),
                            Color.goYellow.opacity(0.4),
                            .clear
                        ],
                        center: .center, startRadius: 20, endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            // 星芒旋转
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * (360.0 / 8.0)
                    Image(systemName: "sparkle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.goYellow)
                        .offset(y: -130)
                        .rotationEffect(.degrees(angle))
                }
            }
            .rotationEffect(.degrees(sparkleRotation))
            .opacity(glowOpacity * 0.8)

            // 蛋壳 / 宠物
            ZStack {
                // 蛋壳裂纹（crackPhase 0→1：逐渐消失，emoji 出现）
                Text("🥚")
                    .font(.system(size: 92))
                    .opacity(1 - crackPhase)
                    .scaleEffect(1 + crackPhase * 0.3)

                // 宠物 emoji 弹出
                Text(petEmoji)
                    .font(.system(size: 110))
                    .scaleEffect(petScale)
                    .opacity(petOpacity)
            }

            // 标题
            VStack(spacing: 6) {
                Spacer().frame(height: 180)
                Text("\(petName) 加入 Ohana")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("一起开启你们的故事")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .opacity(titleOpacity)
        }
        .allowsHitTesting(false)
        .onAppear {
            // 阶段 1：光晕出现（0 ~ 0.4s）
            withAnimation(.easeOut(duration: 0.4)) {
                glowOpacity = 1.0
                glowScale = 1.0
            }
            // 阶段 2：破壳（0.6 ~ 1.4s）
            withAnimation(.easeInOut(duration: 0.7).delay(0.6)) {
                crackPhase = 1.0
            }
            // 阶段 3：宠物弹出（1.1 ~ 1.7s）
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(1.1)) {
                petScale = 1.0
                petOpacity = 1.0
            }
            // 阶段 4：标题显现（1.6 ~ 2.2s）
            withAnimation(.easeOut(duration: 0.45).delay(1.6)) {
                titleOpacity = 1.0
            }
            // 星芒持续旋转
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                sparkleRotation = 360
            }
        }
    }
}

