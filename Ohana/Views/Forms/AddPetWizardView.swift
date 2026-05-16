//
//  AddPetWizardView.swift
//  Ohana
//
//  全面重写：品种被动选择、拍照/相册取景框、生日年龄换算、到家天数、出生地、护照/chip、毛色/瞳色
//

import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import ImageIO
import Foundation

struct AddPetWizardView: View {
    let onComplete: () -> Void
    var onPetSaved: ((Pet) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

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
    @State private var usesAutomaticAvatarAsset = true
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var pendingCapturedAvatarImage: UIImage? = nil
    @State private var cropImageItem: IdentifiableCropImage? = nil
    @State private var hasBirthday = true
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var hasHomeDate = false
    @State private var homeDate = Date()
    @State private var gender = "unknown"
    @State private var isNeutered = false
    @State private var coatColor = ""
    @State private var eyeColor = ""
    @State private var themeColorHex = "FF5252" // 默认使用 Crimson
    @State private var showCoatColorPicker = false
    @State private var showEyeColorPicker = false
    @State private var customCoatUIColor: Color = .white
    @State private var customEyeUIColor: Color = .white
    @State private var showCoatColorSheet = false
    @State private var showEyeColorSheet = false
    @State private var showThemeColorSheet = false
    @State private var showSaveFailedAlert = false
    @State private var saveFailedMessage = ""
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

    private let speciesOptions = ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]
    @AppStorage("appLanguage") private var appLanguage = "zh"
    private var wizardL10n: L10n { L10n(appLanguage) }
    
    // MARK: - Computed helpers
    private var accentColor: Color { Color(hex: themeColorHex) }
    private var isCreatingFirstPet: Bool { existingPets.isEmpty }
    private var totalCards: Int { 5 }
    private var canUseAutomatic2DAvatar: Bool {
        Avatar2DAccess.usesFreeSlot(kind: .pet, existingCount: existingPets.count)
    }
    private var avatar2DStatusText: String {
        if Avatar2DAccess.usesFreeSlot(kind: .pet, existingCount: existingPets.count) {
            return wizardL10n.tr(zh: "推荐使用当前 2.5D 头像，可获得最佳卡片和首页体验。", en: "We recommend the current 2.5D avatar for the best card and Home experience.", de: "Wir empfehlen den aktuellen 2.5D-Avatar für die beste Karten- und Home-Erfahrung.")
        }
        return wizardL10n.tr(zh: "2.5D 头像需要后期在椰子商店购买，并指定给这个成员解锁。", en: "2.5D avatars can be unlocked later from the Coconut Shop for this member.", de: "2.5D-Avatare kannst du später im Kokosnuss-Shop für dieses Mitglied freischalten.")
    }
    private var petMeshBasicAndBio: String {
        wizardL10n.tr(zh: "基础与生物 · 1/5", en: "BASICS & BIO · 1/5", de: "BASIS & BIO · 1/5")
    }
    private var petMeshAppearance: String {
        isCreatingFirstPet
            ? wizardL10n.tr(zh: "外貌与主题色 · 2/5", en: "LOOK & THEME · 2/5", de: "AUSSEHEN & THEMA · 2/5")
            : wizardL10n.tr(zh: "外貌与主题色 · 3/5", en: "LOOK & THEME · 3/5", de: "AUSSEHEN & THEMA · 3/5")
    }
    private var petMeshAvatar: String {
        isCreatingFirstPet
            ? wizardL10n.tr(zh: "头像 · 3/5", en: "AVATAR · 3/5", de: "AVATAR · 3/5")
            : wizardL10n.tr(zh: "头像 · 2/5", en: "AVATAR · 2/5", de: "AVATAR · 2/5")
    }
    private var petMeshTags: String {
        wizardL10n.tr(zh: "性格 · 4/5", en: "VIBE TAGS · 4/5", de: "CHARAKTER · 4/5")
    }
    private var petMeshConfirm: String {
        wizardL10n.tr(zh: "确认 · 5/5", en: "FINAL CHECK · 5/5", de: "ABSCHLUSS · 5/5")
    }
    private var themeUIColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: themeColorHex) },
            set: { newColor in
                if let hex = newColor.toHex() {
                    themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
                        hex,
                        fallback: OhanaThemeColorPolicy.petFallbackHex
                    )
                }
            }
        )
    }
    private var avatarInitial: String { name.isEmpty ? "?" : String(name.prefix(1)) }
    /// 全岛名字冲突检查（忽略大小写和首尾空格）
    private var isNameDuplicate: Bool {
        let candidate = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty else { return false }
        let petNames = existingPets.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        let humanNames = existingHumans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        return petNames.contains(candidate) || humanNames.contains(candidate)
    }

    private var resolvedCoatColor: Color {
        if coatColor == "自定义" { return customCoatUIColor }
        let bi = selectedBreedInfo
        let coatItems = appearanceCoatColors(for: bi)
        if let found = coatItems.first(where: { $0.name == coatColor }) { return found.color }
        if let pattern = PetCoatPattern.patterns(forBreed: bi).first(where: { $0.displayName == coatColor }) {
            switch pattern {
            case .calico: return Color(hex: "D9A441")
            case .silverChinchilla: return Color(hex: "C8C8C8")
            case .tortoiseshell: return Color(hex: "6E2C00")
            case .cowPattern: return .white
            case .bicolor: return Color(hex: "95ADBE")
            }
        }
        return Color(hex: "E8C49A")
    }

    private var resolvedEyeColor: Color {
        if eyeColor == "自定义" { return customEyeUIColor }
        let eyeItems = appearanceEyeColors(for: selectedBreedInfo, coatColor: coatColor)
        if let found = eyeItems.first(where: { $0.name == eyeColor }) { return found.color }
        return Color(hex: "6B3A2A")
    }

    private var normalizedExistingMemberNames: Set<String> {
        Set(
            existingPets.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
            + existingHumans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }
        )
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

    private var effectiveBreedForAvatar: String {
        if isCustomBreed {
            return customBreedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return breed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appearanceCoatColors(for breedInfo: BreedInfo?) -> [CoatColor] {
        if let avatarCoats = PetAvatarAssetCatalog.coatColors(species: species, breed: effectiveBreedForAvatar) {
            return avatarCoats
        }
        return breedInfo?.coatColors ?? PetBreedDatabase.genericCoatColors
    }

    private func appearanceEyeColors(for breedInfo: BreedInfo?, coatColor: String) -> [EyeColor] {
        if let avatarEyes = PetAvatarAssetCatalog.eyeColors(species: species, breed: effectiveBreedForAvatar, coatColor: coatColor) {
            return avatarEyes
        }
        return PetBreedDatabase.refinedEyeColors(breed: breedInfo, coatColor: coatColor)
    }

    private func defaultAppearanceSelection(for breedInfo: BreedInfo) -> (coat: String, eye: String) {
        if let defaultAppearance = PetAvatarAssetCatalog.defaultAppearance(species: species, breed: breedInfo.name) {
            return (defaultAppearance.coatName, defaultAppearance.eyeName)
        }
        return (breedInfo.coatColors.first?.name ?? "", breedInfo.eyeColors.first?.name ?? "")
    }

    private func selectBreed(_ breedInfo: BreedInfo) {
        breed = breedInfo.name
        isCustomBreed = false
        customBreedText = ""
        themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            breedInfo.suggestedThemeHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        let defaultSelection = defaultAppearanceSelection(for: breedInfo)
        coatColor = defaultSelection.coat
        eyeColor = defaultSelection.eye
        refreshAutomaticAvatarAssetData()
    }

    private func refreshAutomaticAvatarAssetData() {
        guard usesAutomaticAvatarAsset else { return }
        guard canUseAutomatic2DAvatar else {
            avatarImageData = nil
            return
        }
        avatarImageData = automaticPetAvatarData()
    }

    private func automaticPetAvatarData() -> Data? {
        PetAvatarAssetCatalog.avatarData(
            species: effectiveSpeciesForData,
            breed: effectiveBreedForAvatar,
            gender: gender,
            coatColor: coatColor,
            eyeColor: eyeColor
        )
    }

    /// 品种或自定义品种名变化时，丢弃当前品种不允许的毛色 / 瞳色 / 渐变花纹（例如德牧不应保留「银渐层」）。
    private func clampAppearanceSelectionToBreed() {
        let bi = selectedBreedInfo
        let coatList = appearanceCoatColors(for: bi)
        let eyeList = appearanceEyeColors(for: bi, coatColor: coatColor)
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
        refreshAutomaticAvatarAssetData()
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
            let transparent = ImageCutoutService.isTransparentPNG(snapshot)
            let img = UIImage(data: snapshot).map { image -> UIImage in
                let downsampled = Self.downsample(image, maxDim: 900)
                if transparent, let trimmed = ImageCutoutService.trimmedTransparentSubjectImage(from: downsampled) {
                    return trimmed
                }
                return downsampled
            }
            await MainActor.run {
                guard avatarImageData == snapshot else { return }
                walletDecodedAvatar = img
                walletDecodedAvatarTransparent = transparent
            }
        }
    }

    /// 标准信用卡比例 1.586:1，左右各 7pt 边距（与首页 K.cardH / K.cardMargin 保持一致）
    private var walletDraftCardHeight: CGFloat { (ScreenCompat.width - 7 * 2) / 1.586 }
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
        .padding(.horizontal, 7)   // 与首页卡片堆 K.cardMargin 保持一致
        .padding(.top, 8)
        .padding(.bottom, 6)
        // 不在 `name` 上套弹簧动画：每个按键都会触发布局+动画，输入会明显卡顿
        .animation(GoMotion.feedback, value: breed)
        .animation(GoMotion.feedback, value: customBreedText)
        .animation(GoMotion.feedback, value: avatarImageData?.count)
        .animation(GoMotion.feedback, value: hasBirthday)
        .animation(GoMotion.feedback, value: birthday)
        .animation(GoMotion.feedback, value: hasHomeDate)
        .animation(GoMotion.feedback, value: homeDate)
        .animation(GoMotion.feedback, value: coatColor)
        .animation(GoMotion.feedback, value: eyeColor)
        .animation(GoMotion.feedback, value: themeColorHex)
    }

    /// 分页：`TabView` 恢复左右滑动；外貌卡内毛/瞳色块使用 `wrappingGrid`，避免横向 `ScrollView` 与分页手势冲突。
    private var wizardPagedContent: some View {
        TabView(selection: $wizardPageIndex) {
            if isCreatingFirstPet {
                pagedCard(index: 0, content: { wizardCard1BasicAndBio }).tag(0)
                pagedCard(index: 1, content: { wizardCard4Appearance }).tag(1)
                pagedCard(index: 2, content: { wizardCard2Avatar }).tag(2)
                pagedCard(index: 3, content: { wizardCard5Tags }).tag(3)
                pagedCard(index: 4, content: { wizardCard6Confirm }).tag(4)
            } else {
                pagedCard(index: 0, content: { wizardCard1BasicAndBio }).tag(0)
                pagedCard(index: 1, content: { wizardCard2Avatar }).tag(1)
                pagedCard(index: 2, content: { wizardCard4Appearance }).tag(2)
                pagedCard(index: 3, content: { wizardCard5Tags }).tag(3)
                pagedCard(index: 4, content: { wizardCard6Confirm }).tag(4)
            }
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
                .padding(.horizontal, 7) // Match the wallet preview card width above.
                .frame(maxHeight: .infinity)
                .background(.clear)

            wizardPageDotRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 阻止键盘弹出时压缩整列布局：TabView 相邻卡片的顶部内容
        // 否则会随键盘一起上移，收起时再滑落。键盘直接覆盖当前卡片下方区域。
        .ignoresSafeArea(.keyboard)
    }

    private var wizardPageDotRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCards, id: \.self) { i in
                wizardPageDotButton(index: i)
            }
        }
        .padding(.top, 8).padding(.bottom, 4)
    }

    private func wizardPageDotButton(index i: Int) -> some View {
        Button {
            GoKeyboard.dismiss()
            withAnimation(GoMotion.feedback) {
                wizardPageIndex = i
            }
        } label: {
            Capsule()
                .fill(i == wizardPageIndex ? Color.goPrimary : Color.primary.opacity(0.2))
                .frame(width: i == wizardPageIndex ? 20 : 6, height: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.feedback, value: wizardPageIndex)
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
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
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
        let clamped = min(max(new, 0), totalCards - 1)
        if clamped != new { wizardPageIndex = clamped }
    }

    private func handlePhotosPickerItemChanged(_ item: PhotosPickerItem?) {
        Task {
            guard let item else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            if let data = try? await item.loadTransferable(type: Data.self) {
                let resized = await Task.detached(priority: .userInitiated) {
                    Self.cropReadyImage(from: data, maxPixel: 1_600)
                }.value
                await MainActor.run {
                    if let img = resized {
                        cropImageItem = IdentifiableCropImage(image: img)
                        AppPerformanceMonitor.shared.record("相册到裁剪页", startedAt: startedAt)
                    }
                }
            }
        }
    }

    private func presentCamera() {
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {
            showCameraPermissionAlert = true
        }
    }

    private func prepareCapturedAvatarForCrop(_ image: UIImage) {
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                Self.preparedCropImage(image, maxPixel: 1_600)
            }.value
            try? await Task.sleep(nanoseconds: 120_000_000)
            cropImageItem = IdentifiableCropImage(image: prepared)
            AppPerformanceMonitor.shared.markEnd("avatar.camera.to.crop", name: "拍照到裁剪页")
        }
    }

    private var addPetWizardLifecyclePartA: some View {
        addPetWizardStackCore
            .onAppear {
                refreshAutomaticAvatarAssetData()
                scheduleWalletAvatarDecode()
            }
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
            .onChange(of: eyeColor) { _, _ in refreshAutomaticAvatarAssetData() }
            .onChange(of: gender) { _, _ in refreshAutomaticAvatarAssetData() }
    }

    var body: some View {
        addPetWizardLifecycleBase
        .fullScreenCover(isPresented: $showingCamera, onDismiss: {
            if let img = pendingCapturedAvatarImage {
                pendingCapturedAvatarImage = nil
                prepareCapturedAvatarForCrop(img)
            }
        }) {
            PetCameraPickerView(maxPixel: 1_600) { img in
                AppPerformanceMonitor.shared.markStart("avatar.camera.to.crop")
                pendingCapturedAvatarImage = img
                showingCamera = false
            } onCancel: {
                showingCamera = false
            }
        }
        .sheet(item: $cropImageItem) { item in
            NavigationStack {
                PetImageCropView(image: item.image, species: effectiveSpeciesForData) { cropped in
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        if let cropped {
                            // Preserve alpha: transparent cutout subjects (from "Copy Subject")
                            // must be saved as PNG so isTransparentPNG detection stays accurate.
                            let hasAlpha = ImageCutoutService.imageHasTransparentPixels(cropped)
                            let optimized = Self.optimizedAvatarAsset(cropped, preserveAlpha: hasAlpha)
                            usesAutomaticAvatarAsset = false
                            avatarImageData = hasAlpha
                                ? optimized.pngData()
                                : optimized.jpegData(compressionQuality: 0.88)
                        }
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
        .sheet(isPresented: $showThemeColorSheet) {
            GoColorPickerSheet(selectedColor: themeUIColorBinding) { chosen in
                if let hex = chosen.toHex() {
                    themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
                        hex,
                        fallback: OhanaThemeColorPolicy.petFallbackHex
                    )
                }
            }
            .presentationDetents([.medium])
        }
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
        .alert("无法打开相机", isPresented: $showCameraPermissionAlert) {
            Button(wizardL10n.done, role: .cancel) { }
        } message: {
            Text("请在系统设置中允许 Ohana 访问相机。")
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

    // MARK: - Reusable helpers
    private func themeCustomColorButton(size: CGFloat) -> some View {
        let selectedHex = themeColorHex.uppercased()
        let isCustom = !PetThemeColor.allCases.contains { $0.hexValue.uppercased() == selectedHex }
        return Button {
            showThemeColorSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: themeColorHex))
                    .frame(width: size, height: size)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: size, height: size)
                if isCustom {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: size, height: size)
                    Image(systemName: "checkmark")
                        .font(.system(size: max(10, size * 0.3), weight: .black))
                        .foregroundStyle(.black)
                } else {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: max(12, size * 0.42), weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("自定义主题色")
    }

    /// 将图片压缩到 maxDim 长边以内，在后台线程调用
    nonisolated static func downsample(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDim / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    /// Prepare camera/photo-library images before showing the crop UI.
    /// This avoids presenting a 12MP image to SwiftUI and keeps gestures smooth.
    nonisolated static func cropReadyImage(from data: Data, maxPixel: CGFloat = 1_600) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data).map { preparedCropImage($0, maxPixel: maxPixel) }
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel)
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }

        return UIImage(data: data).map { preparedCropImage($0, maxPixel: maxPixel) }
    }

    nonisolated static func preparedCropImage(_ image: UIImage, maxPixel: CGFloat = 1_600) -> UIImage {
        let resized = downsample(image, maxDim: maxPixel)
        guard resized.imageOrientation != .up else { return resized }
        let renderer = UIGraphicsImageRenderer(size: resized.size)
        return renderer.image { _ in
            resized.draw(in: CGRect(origin: .zero, size: resized.size))
        }
    }

    /// Store card avatars near their largest display size instead of keeping oversized camera/PNG textures.
    nonisolated static func optimizedAvatarAsset(_ image: UIImage, preserveAlpha: Bool, maxPixel: CGFloat = 900) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixel else { return image }

        let scale = maxPixel / longest
        let targetSize = CGSize(width: floor(pixelSize.width * scale), height: floor(pixelSize.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !preserveAlpha
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func speciesEmoji(_ sp: String) -> String {
        switch sp {
        case "狗": return "🐕"; case "猫": return "🐈"; case "兔子": return "🐇"
        case "鱼": return "🐟"; case "鸟": return "🦜"; case "爬宠": return "🦎"
        case "仓鼠": return "🐹"; default: return "🐾"
        }
    }

    private func savePet() {
        guard !isSaving else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !isNameDuplicate else { return }

        isSaving = true
        let finalBreed = isCustomBreed ? customBreedText : breed
        let shouldUseAutomaticAvatar = usesAutomaticAvatarAsset && canUseAutomatic2DAvatar
        let finalAvatarImageData = shouldUseAutomaticAvatar
            ? automaticPetAvatarData()
            : avatarImageData
        let pet = Pet(
            name: trimmedName, species: effectiveSpeciesForData, breed: finalBreed,
            birthday: hasBirthday ? birthday : nil,
            gender: gender, isNeutered: isNeutered,
            avatarEmoji: speciesEmoji(effectiveSpeciesForData),
            themeColorHex: OhanaThemeColorPolicy.normalizedMemberThemeHex(
                themeColorHex,
                fallback: OhanaThemeColorPolicy.petFallbackHex
            ),
            homeDate: hasHomeDate ? homeDate : nil
        )
        pet.avatarImageData = finalAvatarImageData
        pet.coatColor = coatColor
        pet.eyeColor = eyeColor
        pet.personalityTagsRaw = selectedPersonalityTagIds.joined(separator: ",")
        modelContext.insert(pet)
        if shouldUseAutomaticAvatar, finalAvatarImageData != nil {
            Avatar2DAccess.consumeIfNeeded(kind: .pet, existingCount: existingPets.count)
        }

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
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: modelContext)
        modelContext.safeSave()
        onPetSaved?(pet)

        // Q4: 欢呼算结 — 岛屿第一家人成就
        let isFirstPet = !QuestManager.shared.isPetWizardCompleted
        if isFirstPet {
            QuestManager.shared.isPetWizardCompleted = true
            QuestManager.shared.addCoconuts(50, emoji: "🎉", reason: "新家人入住欢迎奖励")
        }

        isSaving = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onComplete()
    }

    private func restoreAutomaticAvatarAsset() {
        guard canUseAutomatic2DAvatar else { return }
        usesAutomaticAvatarAsset = true
        refreshAutomaticAvatarAssetData()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 生日/纪念日/里程碑/家庭关系等非核心数据；失败时 safeSave 仅打日志，不影响已写入的 Pet
    private func insertPetRelatedRecords(pet: Pet, displayName: String) {
        if themeColorHex != OhanaThemeColorPolicy.petFallbackHex {
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
                PetWizardNameInputField(
                    name: $name,
                    placeholder: l.petWizNamePlaceholder,
                    duplicateMessage: l.humanWizDupNameInline,
                    takenNames: normalizedExistingMemberNames,
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text(l.petWizSpecies)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
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
                            .animation(GoMotion.feedback, value: species)
                        }.buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)

                if species == "其他" {
                    GoDraftTextField(
                        l.petWizSpeciesOtherPh,
                        text: $customSpeciesText,
                        commitDelayNanoseconds: 180_000_000,
                        submitLabel: .done,
                        capitalization: .words
                    )
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
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
                    Image(systemName: "list.bullet").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome).foregroundStyle(Color.ohanaSecondaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.petWizBentoBreed).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.primary.opacity(0.55))
                        Text(breedCollapseSummary).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome).foregroundStyle(Color.primary.opacity(0.45))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle()).padding(.horizontal, 20)

            Spacer()
        }
    }

    private var wizardCard1BasicAndBio: some View {
        let l = wizardL10n
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                meshCardLabel(petMeshBasicAndBio).padding(.top, 14).padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    PetWizardNameInputField(
                        name: $name,
                        placeholder: l.petWizNamePlaceholder,
                        duplicateMessage: l.humanWizDupNameInline,
                        takenNames: normalizedExistingMemberNames,
                        colorScheme: colorScheme
                    )
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text(l.petWizSpecies)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
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
                                .animation(GoMotion.feedback, value: species)
                            }.buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)

                    if species == "其他" {
                        GoDraftTextField(
                            l.petWizSpeciesOtherPh,
                            text: $customSpeciesText,
                            commitDelayNanoseconds: 180_000_000,
                            submitLabel: .done,
                            capitalization: .words
                        )
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
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
                        Image(systemName: "list.bullet").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome).foregroundStyle(Color.ohanaSecondaryText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.petWizBentoBreed).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.primary.opacity(0.55))
                            Text(breedCollapseSummary).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome).foregroundStyle(Color.primary.opacity(0.45))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle()).padding(.horizontal, 20)

                Divider().opacity(0.15).padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text(l.petWizGender).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                    HStack(spacing: 8) {
                        ForEach([("male", l.petWizGenderBoy), ("female", l.petWizGenderGirl), ("unknown", l.petWizGenderUnknown)], id: \.0) { val, label in
                            Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); gender = val } label: {
                                Text(label).font(.system(size: 13, weight: gender == val ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(gender == val ? Color.arkInk : Color.primary.opacity(0.85))
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(gender == val ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                            }.buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)

                HStack {
                    Text(l.petWizNeuter).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Toggle("", isOn: $isNeutered).tint(Color.goPrimary).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l.petWizBirthday).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                        Spacer()
                        Toggle("", isOn: $hasBirthday).tint(Color.goPrimary).labelsHidden()
                    }
                    if hasBirthday {
                        DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(Color.goPrimary)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .simultaneousGesture(TapGesture().onEnded { GoKeyboard.dismiss() })
                        if !humanAgeText.isEmpty {
                            Label(humanAgeText, systemImage: "person.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l.petWizHomeDate).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                        Spacer()
                        Toggle("", isOn: $hasHomeDate).tint(Color.goPrimary).labelsHidden()
                    }
                    if hasHomeDate {
                        DatePicker("", selection: $homeDate, in: (hasBirthday ? birthday : .distantPast)...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .tint(Color.goPrimary)
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .simultaneousGesture(TapGesture().onEnded { GoKeyboard.dismiss() })
                            .onChange(of: birthday) { _, newB in if homeDate < newB { homeDate = newB } }
                        if !daysTogetherText.isEmpty {
                            Label(daysTogetherText, systemImage: "heart.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Wizard Card 2
    private var wizardCard2Avatar: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            meshCardLabel(petMeshAvatar).padding(.top, 14).padding(.horizontal, 20)

            HStack(spacing: 8) {
                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome)
                        Text(l.humanWizPhotoLibrary).font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button { presentCamera() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill").font(.system(size: 13, weight: .semibold)).symbolRenderingMode(.monochrome)
                        Text(l.humanWizCamera).font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)

            Text(avatar2DStatusText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(canUseAutomatic2DAvatar ? Color.goPrimary.opacity(0.85) : Color.primary.opacity(0.48))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            if canUseAutomatic2DAvatar && !usesAutomaticAvatarAsset {
                Button {
                    restoreAutomaticAvatarAsset()
                } label: {
                    Label(
                        l.tr(zh: "恢复 2.5D 头像", en: "Restore 2.5D avatar", de: "2.5D-Avatar wiederherstellen"),
                        systemImage: "sparkles"
                    )
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)

            Spacer()
        }
    }

    // MARK: - Wizard Card 3
    private var wizardCard3Bio: some View {
        let l = wizardL10n
        return VStack(alignment: .leading, spacing: 14) {
            meshCardLabel(l.petWizMesh2).padding(.top, 14).padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(l.petWizGender).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                HStack(spacing: 8) {
                    ForEach([("male", l.petWizGenderBoy), ("female", l.petWizGenderGirl), ("unknown", l.petWizGenderUnknown)], id: \.0) { val, label in
                        Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); gender = val } label: {
                            Text(label).font(.system(size: 13, weight: gender == val ? .bold : .medium, design: .rounded))
                                .foregroundStyle(gender == val ? Color.arkInk : Color.primary.opacity(0.85))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(gender == val ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                        }.buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)

            HStack {
                Text(l.petWizNeuter).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Toggle("", isOn: $isNeutered).tint(Color.goPrimary).labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l.petWizBirthday).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Toggle("", isOn: $hasBirthday).tint(Color.goPrimary).labelsHidden()
                }
                if hasBirthday {
                    DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.goPrimary)
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .simultaneousGesture(TapGesture().onEnded { GoKeyboard.dismiss() })
                    if !humanAgeText.isEmpty {
                        Label(humanAgeText, systemImage: "person.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(l.petWizHomeDate).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                    Spacer()
                    Toggle("", isOn: $hasHomeDate).tint(Color.goPrimary).labelsHidden()
                }
                if hasHomeDate {
                    DatePicker("", selection: $homeDate, in: (hasBirthday ? birthday : .distantPast)...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.goPrimary)
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .simultaneousGesture(TapGesture().onEnded { GoKeyboard.dismiss() })
                        .onChange(of: birthday) { _, newB in if homeDate < newB { homeDate = newB } }
                    if !daysTogetherText.isEmpty {
                        Label(daysTogetherText, systemImage: "heart.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
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
        let bi = selectedBreedInfo
        let coatItems = appearanceCoatColors(for: bi).map { ($0.name, $0.hex) }
        let eyeItems = appearanceEyeColors(for: bi, coatColor: coatColor).map { ($0.name, $0.hex) }
        let coatPatterns = PetCoatPattern.patterns(forBreed: bi)

        return VStack(alignment: .leading, spacing: 0) {
            meshCardLabel(petMeshAppearance).padding(.top, 14).padding(.horizontal, 20).padding(.bottom, 14)

            // 可滚动区域：内容超出卡片高度时可上下滑，底部留白让圆角可见
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if bi == nil {
                        Text(l.petWizAppearanceNoBreedHint)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .padding(.horizontal, 20)
                    }

                    colorSectionOnMesh(title: l.petWizCoatSection, items: coatItems, patternItems: coatPatterns, selected: $coatColor, showCustomPicker: $showCoatColorSheet, customColor: $customCoatUIColor, swatchLayout: .wrappingGrid)
                    colorSectionOnMesh(title: l.petWizEyeSection, items: eyeItems, patternItems: [], selected: $eyeColor, showCustomPicker: $showEyeColorSheet, customColor: $customEyeUIColor, swatchLayout: .wrappingGrid)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(l.petWizThemeSection).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText).padding(.horizontal, 20)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                            ForEach(PetThemeColor.allCases, id: \.rawValue) { tc in
                                let tcHex = tc.hexValue
                                let isUsed = usedThemeColorHexes.contains(tcHex.uppercased())
                                Button { if !isUsed { withAnimation(GoMotion.feedback) { themeColorHex = tcHex } } } label: {
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
                            themeCustomColorButton(size: 36)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                // 底部留白，使卡片底部圆角清晰可见
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Wizard Card 5
    private var wizardCard5Tags: some View {
        let l = wizardL10n
        let topTags = PetPersonalityTag.allTags
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                meshCardLabel(petMeshTags)
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
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .padding(.horizontal, 10).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                    }.buttonStyle(ScaleButtonStyle())
                }
              }
              .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)

            if isComposingCustomPersonalityTag {
                HStack(spacing: 8) {
                    TextField(l.isEn ? "Tag name" : "标签名称", text: $newCustomPersonalityTagText)
                        .focused($customPersonalityTagFieldFocused)
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText)
                        .textFieldStyle(.plain).padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity)
                    Button { cancelCustomPersonalityTagComposer() } label: {
                        Text(l.cancel).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Color.primary.opacity(0.05), in: Capsule())
                    }.buttonStyle(ScaleButtonStyle())
                    Button { commitCustomPersonalityTag() } label: {
                        Text(l.confirm).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color.white)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(.secondary, in: Capsule())
                    }.buttonStyle(ScaleButtonStyle()).disabled(newCustomPersonalityTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        }.buttonStyle(ScaleButtonStyle())
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

    // MARK: - Wizard Card 6
    private var wizardCard6Confirm: some View {
        let l = wizardL10n
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                meshCardLabel(petMeshConfirm).padding(.top, 14)

                HStack(spacing: 14) {
                    if let data = avatarImageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(Circle())
                    } else {
                        Circle().fill(Color(hex: themeColorHex).opacity(0.3)).frame(width: 56, height: 56)
                            .overlay(Image(systemName: Pet.speciesSilhouetteSymbol(forSpecies: effectiveSpeciesForData)).font(.system(size: 22, weight: .bold)).symbolRenderingMode(.monochrome).foregroundStyle(Color.ohanaSecondaryText))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? l.petWizUnnamed : name).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText)
                        Text(
                            breed.isEmpty
                                ? l.petSpeciesLabel(effectiveSpeciesForData)
                                : "\(l.petSpeciesLabel(effectiveSpeciesForData)) · \(breed)"
                        )
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
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
                            Text(l.petWizThemeSection).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText)
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3).fill(Color(hex: themeColorHex)).frame(width: 36, height: 12)
                                Text("#\(themeColorHex.uppercased())").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(Color.ohanaSecondaryText)
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
                Text(value).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText).lineLimit(1)
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
            Text(title).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaSecondaryText).padding(.horizontal, 20)
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
        .sheet(isPresented: showCustomPicker) {
            GoColorPickerSheet(selectedColor: customColor) { chosen in
                customColor.wrappedValue = chosen
                selected.wrappedValue = "自定义"
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Wizard Bottom Nav Bar
    private var wizardBottomNavBar: some View {
        let l = wizardL10n
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let nameOk = !trimmed.isEmpty && !isNameDuplicate
        let isLastPage = wizardPageIndex == totalCards - 1
        return HStack(spacing: 12) {
            if wizardPageIndex > 0 {
                Button {
                    GoKeyboard.dismiss()
                    withAnimation(GoMotion.feedback) { wizardPageIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.ohanaPrimaryText).frame(width: 48, height: 48)
                        .background(Color.primary.opacity(0.1), in: Circle())
                }.buttonStyle(ScaleButtonStyle())
            } else {
                Color.clear.frame(width: 48, height: 48)
            }
            Spacer()
            if isLastPage {
                Button {
                    guard nameOk, !isSaving else { return }
                    GoKeyboard.dismiss()
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
                Button {
                    GoKeyboard.dismiss()
                    withAnimation(GoMotion.feedback) { wizardPageIndex += 1 }
                } label: {
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
        .background(Color.ohanaCardSurface)
    }

    // MARK: - Breed Picker Sheet
    private var breedPickerSheet: some View {
        let l = wizardL10n
        return NavigationStack {
            ScrollView {
                LazyVStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                        GoDraftTextField(
                            l.petWizBreedSearchPrompt,
                            text: $breedSearch,
                            commitDelayNanoseconds: 220_000_000,
                            submitLabel: .search,
                            capitalization: .never
                        )
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        if !breedSearch.isEmpty {
                            Button { breedSearch = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 6)

                    Button {
                        breed = ""; isCustomBreed = false; customBreedText = ""
                        showBreedPickerSheet = false
                    } label: {
                        HStack {
                            Text(l.petWizBreedNone)
                                .font(.system(size: 15, weight: breed.isEmpty && !isCustomBreed ? .bold : .medium, design: .rounded))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if breed.isEmpty && !isCustomBreed { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary) }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(breed.isEmpty && !isCustomBreed ? Color.goPrimary.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    ForEach(currentBreeds) { b in
                        let isOther = b.name == "其他"
                        let isSelected = (isOther && isCustomBreed) || (!isCustomBreed && breed == b.name)
                        Button {
                            if isOther { breed = "其他"; isCustomBreed = true }
                            else { selectBreed(b); showBreedPickerSheet = false }
                        } label: {
                            HStack {
                                Text(b.name)
                                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.goPrimary) }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(isSelected ? Color.goPrimary.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        if isOther && isCustomBreed {
                            GoDraftTextField(
                                l.petWizBreedFieldPh,
                                text: $customBreedText,
                                commitDelayNanoseconds: 180_000_000,
                                submitLabel: .done,
                                capitalization: .words
                            )
                                .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText)
                                .padding(12).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.goPrimary.opacity(0.5), lineWidth: 1))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(l.petWizBreedSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l.done) {
                        GoKeyboard.dismiss()
                        showBreedPickerSheet = false
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l.done) {
                        GoKeyboard.dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goLime)
                }
            }
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
@MainActor
func requestOhanaCameraAccess(
    onGranted: @escaping @MainActor () -> Void,
    onDenied: @escaping @MainActor () -> Void
) {
    guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil ||
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil ||
            AVCaptureDevice.default(for: .video) != nil else {
        onDenied()
        return
    }

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        onGranted()
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                granted ? onGranted() : onDenied()
            }
        }
    case .denied, .restricted:
        onDenied()
    @unknown default:
        onDenied()
    }
}

struct PetCameraPickerView: UIViewControllerRepresentable {
    let maxPixel: CGFloat
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    init(
        maxPixel: CGFloat = 2_200,
        onCapture: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.maxPixel = maxPixel
        self.onCapture = onCapture
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> OhanaCameraViewController {
        let vc = OhanaCameraViewController()
        vc.maxCapturePixel = maxPixel
        vc.onCapture = onCapture
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: OhanaCameraViewController, context: Context) {}
}

final class OhanaCameraViewController: UIViewController {
    var maxCapturePixel: CGFloat = 2_200
    var onCapture: (UIImage) -> Void = { _ in }
    var onCancel: () -> Void = {}

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "ohana.camera.session", qos: .userInitiated)
    private var didConfigureSession = false
    private var captureDelegate: PhotoCaptureDelegate?
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)
    private let closeButton = UIButton(type: .system)
    private let captureButton = UIButton(type: .system)
    private let unavailableLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configurePreview()
        configureControls()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    private func configurePreview() {
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
    }

    private func configureControls() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.36)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 34
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        view.addSubview(captureButton)

        unavailableLabel.translatesAutoresizingMaskIntoConstraints = false
        unavailableLabel.text = "无法打开相机"
        unavailableLabel.textColor = .white
        unavailableLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        unavailableLabel.textAlignment = .center
        unavailableLabel.isHidden = true
        view.addSubview(unavailableLabel)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 68),
            captureButton.heightAnchor.constraint(equalToConstant: 68),

            unavailableLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            unavailableLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            unavailableLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            unavailableLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func startCamera() {
        let session = session
        let output = photoOutput
        let queue = sessionQueue
        queue.async { [weak self] in
            guard let self else { return }
            if !self.didConfigureSession {
                guard self.configureSession(session: session, output: output) else {
                    DispatchQueue.main.async { [weak self] in self?.showUnavailableState() }
                    return
                }
                self.didConfigureSession = true
            }
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    private func stopCamera() {
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureSession(session: AVCaptureSession, output: AVCapturePhotoOutput) -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(output)
        else {
            return false
        }

        session.addInput(input)
        session.addOutput(output)
        return true
    }

    private func showUnavailableState() {
        unavailableLabel.isHidden = false
        captureButton.isEnabled = false
        captureButton.alpha = 0.35
    }

    @objc private func cancelTapped() {
        onCancel()
    }

    @objc private func captureTapped() {
        captureButton.isEnabled = false
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut]) {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        } completion: { _ in
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                self.captureButton.transform = .identity
            }
        }

        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate(maxPixel: maxCapturePixel) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                self.captureButton.isEnabled = true
                if let image {
                    self.onCapture(image)
                } else {
                    self.showUnavailableState()
                }
                self.captureDelegate = nil
            }
        }
        captureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        let maxPixel: CGFloat
        let completion: (UIImage?) -> Void

        init(maxPixel: CGFloat, completion: @escaping (UIImage?) -> Void) {
            self.maxPixel = maxPixel
            self.completion = completion
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            guard error == nil,
                  let data = photo.fileDataRepresentation(),
                  let image = AddPetWizardView.cropReadyImage(from: data, maxPixel: maxPixel) else {
                completion(nil)
                return
            }
            completion(image)
        }
    }
}

private struct PetWizardNameInputField: View {
    @Binding var name: String
    let placeholder: String
    let duplicateMessage: String
    let takenNames: Set<String>
    let colorScheme: ColorScheme

    @State private var draftName: String
    @State private var commitTask: Task<Void, Never>? = nil

    init(
        name: Binding<String>,
        placeholder: String,
        duplicateMessage: String,
        takenNames: Set<String>,
        colorScheme: ColorScheme
    ) {
        self._name = name
        self.placeholder = placeholder
        self.duplicateMessage = duplicateMessage
        self.takenNames = takenNames
        self.colorScheme = colorScheme
        self._draftName = State(initialValue: name.wrappedValue)
    }

    private var normalizedDraftName: String {
        draftName.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var isDuplicate: Bool {
        !normalizedDraftName.isEmpty && takenNames.contains(normalizedDraftName)
    }

    private var borderColor: Color {
        if draftName.isEmpty { return Color.red.opacity(0.5) }
        if isDuplicate { return Color.orange.opacity(0.7) }
        return Color.goPrimary.opacity(colorScheme == .dark ? 0.55 : 0.4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $draftName)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.ohanaPrimaryText)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .padding(.vertical, 14).padding(.horizontal, 16)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1.5)
                )
                .transaction { $0.animation = nil }

            if isDuplicate {
                Text(duplicateMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "FF6B00"))
                    .padding(.leading, 4)
            }
        }
        .onChange(of: draftName) { _, newValue in
            scheduleCommit(newValue)
        }
        .onChange(of: name) { _, newValue in
            guard newValue != draftName else { return }
            draftName = newValue
        }
        .onSubmit { commitImmediately() }
        .onDisappear { commitImmediately() }
    }

    private func scheduleCommit(_ value: String) {
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, name != value else { return }
            name = value
        }
    }

    private func commitImmediately() {
        commitTask?.cancel()
        if name != draftName { name = draftName }
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

    /// 与添加宠物顶部预览卡、Go Focus 首页小卡片保持同一信用卡比例。
    private let cardMargin: CGFloat = 7
    private let cardAspectRatio: CGFloat = 1.586
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
        let targetW = max(container.width - cardMargin * 2, 220)
        let targetH = targetW / cardAspectRatio
        let availableH = max(container.height - 170, 260)
        let cw: CGFloat
        let ch: CGFloat
        if targetH <= availableH {
            cw = targetW
            ch = targetH
        } else {
            ch = availableH
            cw = ch * cardAspectRatio
        }
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

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(scale, anchor: .center)
                    .offset(offset)
                    .allowsHitTesting(false)

                // 遮罩层不参与手势命中，确保暗色区域的双指操作能穿透到 ZStack
                CardCropOverlay(cropW: cropW, cropH: cropH, cornerRadius: cornerRadius)
                    .allowsHitTesting(false)

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
                    Label("卡片取景", systemImage: "crop")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.22), in: Capsule())
                        .padding(.bottom, 104)
                }
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            // 手势挂在 ZStack 顶层，整个屏幕（含暗色遮罩区）均可触发缩放与拖移
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
            .onAppear {
                containerSize = geo.size
                let img = image
                let iw = img.size.width, ih = img.size.height
                guard iw > 0, ih > 0 else { return }
                let aspectFit = min(geo.size.width / iw, geo.size.height / ih)
                fitDisplaySize = CGSize(width: iw * aspectFit, height: ih * aspectFit)
                let mn = minScale(cropW: cropW, cropH: cropH)
                // Cover scale: 图片恰好填满整个取景框（两方向中较大的那个）
                // 相当于 CSS `object-fit: cover` — 用户拖动选择要保留哪个区域
                let fw = fitDisplaySize.width  > 0 ? cropW / fitDisplaySize.width  : 1.0
                let fh = fitDisplaySize.height > 0 ? cropH / fitDisplaySize.height : 1.0
                let s = max(mn, max(fw, fh))
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
                .buttonStyle(ScaleButtonStyle())

                Button { performCrop() } label: {
                    Text("确认裁剪")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.8))
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
    }

    private func performCrop() {
        let viewSize: CGSize = (containerSize.width > 10 && containerSize.height > 10)
            ? containerSize
            : CGSize(width: ScreenCompat.width, height: max(ScreenCompat.height - 300, 420))
        let (cropW, cropH) = cropSize(for: viewSize)
        let src = image
        let iw = src.size.width, ih = src.size.height
        guard iw > 0, ih > 0, viewSize.width > 0, viewSize.height > 0 else {
            onCrop(src)
            return
        }

        // ──────────────────────────────────────────────────────────────────
        // WYSIWYG 渲染：输出画布与取景框同尺寸，图片按它在预览中相对取景框的
        // 位置 / 缩放直接绘制。越界部分由 UIKit 自动裁剪，不足部分保持黑底——
        // 与裁剪预览中用户看到的完全一致，消除因 clamp 导致的比例拉伸。
        // ──────────────────────────────────────────────────────────────────

        let fitScale = min(viewSize.width / iw, viewSize.height / ih)
        let totalScale = fitScale * scale
        let displayW = iw * totalScale
        let displayH = ih * totalScale

        // 图片左上角在视图坐标中的位置
        let imgOriginX = (viewSize.width  - displayW) / 2 + offset.width
        let imgOriginY = (viewSize.height - displayH) / 2 + offset.height

        // 取景框左上角在视图坐标中的位置
        let cropOriginX = (viewSize.width  - cropW) / 2
        let cropOriginY = (viewSize.height - cropH) / 2

        // 图片左上角相对于取景框左上角的偏移（视图点）
        // 正值 = 图片在取景框内向右/下偏移；负值 = 超出取景框左/上边缘
        let dx = imgOriginX - cropOriginX
        let dy = imgOriginY - cropOriginY

        // 输出画布中图片的绘制矩形（点坐标；renderer scale 负责像素倍率）
        let drawRect = CGRect(
            x: dx,
            y: dy,
            width: displayW,
            height: displayH
        )

        // Detect whether the source image has meaningful transparent pixels
        // (e.g. a "Copy Subject" cutout). Many Photos PNGs carry an alpha
        // channel while all pixels are opaque; those must be treated as normal
        // photos so they render as full-card images, not pasted subjects.
        let srcHasAlpha = ImageCutoutService.imageHasTransparentPixels(src)

        let screenScale = UIGraphicsImageRendererFormat.default().scale
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = screenScale
        fmt.opaque = !srcHasAlpha
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropW, height: cropH), format: fmt)
        let cropped = renderer.image { _ in
            if !srcHasAlpha {
                UIColor.black.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: cropW, height: cropH))
            }
            src.draw(in: drawRect)
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

    private let swatchHexes: [String] = [
        "FF3B30", "FF6B3D", "FF9500", "FFCC00", "F59E0B", "7ED957",
        "34C759", "00C7BE", "14B8A6", "64748B", "8B5CF6", "5856D6",
        "AF52DE", "BF5AF2", "FF2D55", "FF7AB6", "A2845E", "C7B299",
        "FFFFFF", "F2F2F7", "D1D1D6", "8E8E93", "3A3A3C", "1C1C1E"
    ]

    init(selectedColor: Binding<Color>, onSelect: @escaping (Color) -> Void) {
        self._selectedColor = selectedColor
        self.onSelect = onSelect
        self._pickerColor = State(initialValue: selectedColor.wrappedValue)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(spacing: 20) {
                // 顶部把手
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text("自定义颜色")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)

                // 预览色块
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(pickerColor)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                    ForEach(swatchHexes, id: \.self) { hex in
                        let color = Color(hex: hex)
                        let isSelected = pickerColor.toHex()?.uppercased() == hex
                        Button {
                            withAnimation(GoMotion.feedback) {
                                pickerColor = color
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(color)
                                    .frame(height: 42)
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(hex == "FFFFFF" ? 0.55 : 0.2), lineWidth: 1)
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(hex == "FFFFFF" || hex == "F2F2F7" || hex == "FFCC00" || hex == "C8FF00" ? .black : .white)
                                }
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)

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
            withAnimation(GoMotion.fab.delay(1.1)) {
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
