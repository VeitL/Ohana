//
//  AddHumanWizardView.swift
//  Ohana
//
//  参照 AddPetWizardView：GO 岛景底 + 钱包比例顶卡 + 玻璃分页卡 + 分页点（翻页与保存与宠物向导同构）
//  - 国籍：`PetBreedDatabase.countries` 横向列表
//  - 现居地：国家列表 + `PetBreedDatabase.cities(for:)` 城市网格（含「其他」手填）
//

import SwiftUI
import SwiftData
import PhotosUI
import Foundation

// MARK: - Human wizard steps

private enum HumanWizardStep: Int, CaseIterable {
    case identity = 0   // 名字
    case profile  = 1   // 性别/身份 + 生日 + 血型
    case avatar   = 2   // 头像确认
    case family   = 3   // 权限 + 国籍
    case body     = 4   // 身高体重 + 隐私
    case confirm  = 5   // 主题色 + 确认
}

// MARK: - AddHumanWizardView

struct AddHumanWizardView: View {
    let onComplete: () -> Void
    var onHumanSaved: ((Human) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency = AppCurrency.fallbackCode
    @Query(sort: \Pet.createdAt)   private var existingPets:   [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    private var l: L10n { L10n(appLanguage) }

    // ── Identity
    @State private var name            = ""
    @State private var avatarImageData: Data? = nil
    @State private var usesAutomaticAvatarAsset = true
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera   = false
    @State private var showCameraPermissionAlert = false
    @State private var pendingCapturedAvatarImage: UIImage? = nil
    @State private var cropImageItem: IdentifiableCropImage? = nil

    // ── Profile
    @State private var gender      = ""
    @State private var hasBirthday = false
    @State private var birthday    = Date()
    @State private var bloodType   = ""
    @State private var mbti        = ""
    @State private var showBirthdayPickerSheet = false
    @State private var birthdayPickerDraft     = Date()

    // ── Family（权限 / 性别身份 / 国籍 / 现居地：写入 role / notes / Human.nationality / Human.city）
    @State private var nationalityCountry   = ""
    @State private var residenceCountry     = ""
    @State private var residenceCity        = ""
    @State private var isCustomResidenceCity = false
    @State private var notes                = ""

    // ── Body data
    @State private var heightText      = ""
    @State private var weightText      = ""
    @State private var privateWeight   = false
    @State private var privateWorkout  = false
    @State private var privateMedication = false
    @State private var privateWishlist = false
    @State private var privateExpense  = false

    // ── Theme + Role
    @State private var themeColorHex = OhanaThemeColorPolicy.humanFallbackHex
    @State private var role          = "owner"

    // ── Wizard navigation
    @State private var wizardPageIndex      = 0
    @State private var wizardTabViewRemountID = 0

    // ── Alerts
    @State private var showDuplicateNameAlert = false

    // ── Avatar decoded cache (avoid re-decoding on each keystroke)
    @State private var decodedAvatar:           UIImage? = nil
    @State private var decodedAvatarTransparent = false

    private var totalCards: Int { isCreatingFirstHuman ? HumanWizardStep.allCases.count : 5 }

    private let bloodTypes     = ["A", "B", "AB", "O"]
    private let mbtiOptions: [String] = [
        "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"
    ]
    private let genderOptions = HumanProfileOptions.genderOptions
    private let themeColorOptions: [(hex: String, label: String)] = [
        ("FF7600","橙色"), ("EC4899","粉色"), ("A855F7","紫色"),
        ("FF4757","红色"), ("F59E0B","金色"), ("14B8A6","青色"),
        ("8B5CF6","靛蓝"), ("64748B","灰色")
    ]

    // MARK: - Computed

    private var accentColor: Color { Color(hex: themeColorHex) }
    private var isCreatingFirstHuman: Bool { existingHumans.isEmpty }
    private var selectedMeasurementSystem: AppMeasurementSystem.Option {
        AppMeasurementSystem.option(for: appMeasurementSystem)
    }
    private var selectedCurrency: AppCurrency.Option {
        AppCurrency.supported.first { $0.code == AppCurrency.normalize(appCurrency) } ?? AppCurrency.supported[0]
    }

    /// 标准信用卡比例 1.586:1，左右各 7pt 边距（与首页 K.cardH / K.cardMargin 保持一致）
    private var walletDraftCardHeight: CGFloat { (ScreenCompat.width - 7 * 2) / 1.586 }
    private let walletCardCorner: CGFloat = 24

    private func fallbackAvatarEmoji(for gender: String) -> String {
        HumanGenderIdentity.fallbackAvatarEmoji(for: gender)
    }

    /// 顶卡脚注：身份 · 国籍 · 现居 · 年龄（仅「岁」，不含月；星座单独显示在卡上）
    private var draftWalletSubtitle: String {
        var parts: [String] = []
        if !gender.isEmpty { parts.append(l.humanGenderDisplay(gender)) }
        if !nationalityCountry.isEmpty {
            parts.append(l.isEn ? "From \(nationalityCountry)" : "国籍 \(nationalityCountry)")
        }
        if !residenceCountry.isEmpty || !residenceCity.isEmpty {
            if residenceCountry.isEmpty {
                parts.append(l.isEn ? "Nest: \(residenceCity)" : "现居 \(residenceCity)")
            } else if residenceCity.isEmpty {
                parts.append(l.isEn ? "Nest: \(residenceCountry)" : "现居 \(residenceCountry)")
            } else {
                parts.append(l.isEn ? "Nest: \(residenceCountry) · \(residenceCity)" : "现居 \(residenceCountry)·\(residenceCity)")
            }
        }
        if hasBirthday {
            let cal = Calendar.current
            let y = cal.dateComponents([.year], from: birthday, to: Date()).year ?? 0
            if l.isEn {
                if y >= 1 { parts.append("\(y) yrs young") } else { parts.append("Under 1 ✨") }
            } else if y >= 1 {
                parts.append("\(y)岁")
            } else {
                parts.append("不满1岁")
            }
        }
        return parts.joined(separator: " · ")
    }

    private var birthdaySelectableRange: ClosedRange<Date> {
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .year, value: -120, to: end) else { return end...end }
        return start...end
    }

    private var residenceTagText: String? {
        if residenceCountry.isEmpty && residenceCity.isEmpty { return nil }
        if l.isEn {
            if residenceCity.isEmpty { return "Nest: \(residenceCountry)" }
            if residenceCountry.isEmpty { return "Nest: \(residenceCity)" }
            return "Nest: \(residenceCountry) · \(residenceCity)"
        }
        if residenceCity.isEmpty { return "现居 \(residenceCountry)" }
        if residenceCountry.isEmpty { return "现居 \(residenceCity)" }
        return "现居 \(residenceCountry)·\(residenceCity)"
    }

    private var isNameDuplicate: Bool {
        let c = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !c.isEmpty else { return false }
        return existingPets.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }.contains(c)
            || existingHumans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() }.contains(c)
    }

    private var isGenderReady: Bool {
        HumanProfileOptions.genderOptions.contains { $0.key == gender }
    }

    private var canUseAutomatic2DAvatar: Bool {
        Avatar2DAccess.usesFreeSlot(kind: .human, existingCount: existingHumans.count)
    }

    private var avatar2DStatusText: String {
        if Avatar2DAccess.usesFreeSlot(kind: .human, existingCount: existingHumans.count) {
            return l.tr(zh: "推荐使用当前 2.5D 头像，可获得最佳卡片和首页体验。", en: "We recommend the current 2.5D avatar for the best card and Home experience.", de: "Wir empfehlen den aktuellen 2.5D-Avatar für die beste Karten- und Home-Erfahrung.")
        }
        return l.tr(zh: "2.5D 头像需要后期在椰子商店购买，并指定给这个成员解锁。", en: "2.5D avatars can be unlocked later from the Coconut Shop for this member.", de: "2.5D-Avatare kannst du später im Kokosnuss-Shop für dieses Mitglied freischalten.")
    }

    // MARK: - Body

    var body: some View {
        wizardMainColumn
            .onAppear {
                refreshAutomaticAvatarAssetData()
                scheduleAvatarDecode()
            }
            .onChange(of: avatarImageData)    { _, _ in scheduleAvatarDecode() }
            .onChange(of: photosPickerItem)   { _, item in handlePhotosPicker(item) }
            .onChange(of: gender)             { _, _ in refreshAutomaticAvatarAssetData() }
            .onChange(of: birthday)           { _, _ in refreshAutomaticAvatarAssetData() }
            .onChange(of: hasBirthday)        { _, _ in refreshAutomaticAvatarAssetData() }
            .onChange(of: cropImageItem)      { _, new in
                guard new == nil else { return }
                DispatchQueue.main.async { wizardTabViewRemountID += 1 }
            }
            .onChange(of: wizardPageIndex) { _, new in
                let clamped = min(max(new, 0), totalCards - 1)
                if clamped != new { wizardPageIndex = clamped }
            }
            .onChange(of: residenceCountry) { _, newCountry in
                let cities = PetBreedDatabase.cities(for: newCountry)
                if !residenceCity.isEmpty, !cities.contains(residenceCity) {
                    residenceCity = ""
                    isCustomResidenceCity = false
                }
            }
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
                    PetImageCropView(
                        image: item.image,
                        species: "",
                        silhouetteSystemName: "person.fill"
                    ) { cropped in
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) {
                            if let cropped {
                                let hasAlpha = ImageCutoutService.imageHasTransparentPixels(cropped)
                                let optimized = AddPetWizardView.optimizedAvatarAsset(cropped, preserveAlpha: hasAlpha)
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
                            Button(l.cancel) {
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
            .alert(l.humanWizDupAlertTitle, isPresented: $showDuplicateNameAlert) {
                Button(l.humanWizDupAlertOk, role: .cancel) { }
            } message: {
                Text(l.humanWizDupAlertMsg(name.trimmingCharacters(in: .whitespaces)))
            }
            .alert("无法打开相机", isPresented: $showCameraPermissionAlert) {
                Button(l.done, role: .cancel) { }
            } message: {
                Text("请在系统设置中允许 Ohana 访问相机。")
            }
            .sheet(isPresented: $showBirthdayPickerSheet) { birthdayPickerSheet }
            .onChange(of: hasBirthday) { _, on in
                if !on { showBirthdayPickerSheet = false }
            }
    }

    // MARK: - Layout

    private var wizardMainColumn: some View {
        VStack(spacing: 0) {
            stickyWalletHumanPreview

            pagedCards
                .padding(.horizontal, 7) // Match the wallet preview card width above.
                .frame(maxHeight: .infinity)

            wizardPageDotRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 与添加宠物向导同比例钱包顶卡
    private var stickyWalletHumanPreview: some View {
        WalletHumanCardDraftFront(
            name: name,
            gender: gender,
            avatarImageData: avatarImageData,
            decodedAvatar: decodedAvatar,
            decodedAvatarTransparent: decodedAvatarTransparent,
            themeColorHex: themeColorHex,
            zodiacText: hasBirthday ? Human.westernZodiacDisplay(for: birthday, isEnglish: l.isEn) : nil,
            mbtiText: mbti.trimmingCharacters(in: .whitespaces).isEmpty ? nil : mbti.uppercased(),
            subtitle: draftWalletSubtitle,
            cornerRadius: walletCardCorner
        )
        .frame(height: walletDraftCardHeight)
        .padding(.horizontal, 7)   // 与首页卡片堆 K.cardMargin 保持一致
        .padding(.top, 8)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: name)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: gender)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: avatarImageData?.count)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: themeColorHex)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: nationalityCountry)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: residenceCountry)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: hasBirthday)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: birthday)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: mbti)
    }

    // MARK: - Paged cards

    private var pagedCards: some View {
        TabView(selection: $wizardPageIndex) {
            if isCreatingFirstHuman {
                pagedCard { card1Identity }.tag(0)
                pagedCard { card2Profile }.tag(1)
                pagedCard { card3Avatar }.tag(2)
                pagedCard { card4Family }.tag(3)
                pagedCard { card5Body }.tag(4)
                pagedCard { card6Confirm }.tag(5)
            } else {
                pagedCard { card1IdentityAndProfile }.tag(0)
                pagedCard { card3Avatar }.tag(1)
                pagedCard { card4Family }.tag(2)
                pagedCard { card5Body }.tag(3)
                pagedCard { card6Confirm }.tag(4)
            }
        }
        .id(wizardTabViewRemountID)
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Dot row（与 AddPetWizardView.wizardPageDotRow 一致）

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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                wizardPageIndex = i
            }
        } label: {
            Capsule()
                .fill(i == wizardPageIndex ? Color.goPrimary : Color.primary.opacity(0.2))
                .frame(width: i == wizardPageIndex ? 20 : 6, height: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.3), value: wizardPageIndex)
    }

    /// 与 `AddPetWizardView.pagedCard` 同构
    private func pagedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .goTranslucentCard(cornerRadius: 24)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func meshCardLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.6))
            .tracking(0.8)
            .textCase(.uppercase)
    }

    // MARK: - Card 1: Identity (Name)

    private var card1Identity: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                meshCardLabel(l.humanWizMesh1).padding(.top, 14).padding(.horizontal, 20)

                humanNameSection

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    private var card1IdentityAndProfile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                meshCardLabel(l.humanWizMesh1).padding(.top, 14).padding(.horizontal, 20)
                humanNameSection
                Divider().opacity(0.15)
                VStack(spacing: 22) {
                    humanProfileFields
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    private var humanNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            cardSectionLabel(l.humanWizNameLabel)
            GoDraftTextField(
                l.humanWizNamePlaceholder,
                text: $name,
                commitDelayNanoseconds: 160_000_000,
                submitLabel: .done,
                capitalization: .words
            )
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.vertical, 14).padding(.horizontal, 16)
                .background(Color.primary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            name.isEmpty         ? Color.red.opacity(0.4) :
                            isNameDuplicate      ? Color.orange.opacity(0.7)
                                                 : Color.goPrimary.opacity(colorScheme == .dark ? 0.55 : 0.4),
                            lineWidth: 1.5
                        )
                )
                .transaction { $0.animation = nil }
            if isNameDuplicate {
                Text(l.humanWizDupNameInline)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "FF6B00"))
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Card 2: Profile (Gender + Birthday + Blood type)

    private var card2Profile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh2).padding(.top, 14).padding(.horizontal, 20)
                humanProfileFields

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var humanProfileFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardSectionLabel(l.humanWizGenderLabel)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(genderOptions, id: \.key) { opt in
                    Button {
                        gender = opt.key
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 8) {
                            HumanSilhouetteView(gender: opt.key, accent: gender == opt.key ? .arkInk : accentColor)
                                .frame(width: 42, height: 48)
                            Text(l.humanGenderDisplay(opt.key))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(gender == opt.key ? Color.arkInk : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            gender == opt.key ? Color.goPrimary : Color.primary.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(gender == opt.key ? Color.goPrimary : .clear, lineWidth: 1.5)
                        )
                        .scaleEffect(gender == opt.key ? 0.97 : 1.0)
                        .animation(.spring(response: 0.25), value: gender)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }

        Divider().opacity(0.15)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                cardSectionLabel(l.humanWizBirthdayLabel)
                Spacer()
                Toggle("", isOn: $hasBirthday)
                    .tint(Color.goPrimary)
                    .labelsHidden()
            }
            if hasBirthday {
                Button {
                    GoKeyboard.dismiss()
                    birthdayPickerDraft = birthday
                    showBirthdayPickerSheet = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(birthday.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text(Human.westernZodiacDisplay(for: birthday, isEnglish: l.isEn))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.goPrimary)
                        }
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.45))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                Text(l.humanWizBirthdayHint)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.55))
            }
        }
        .animation(.spring(response: 0.35), value: hasBirthday)

        Divider().opacity(0.15)

        VStack(alignment: .leading, spacing: 10) {
            cardSectionLabel(l.humanWizBloodLabel)
            HStack(spacing: 10) {
                ForEach(bloodTypes, id: \.self) { bt in
                    Button {
                        bloodType = bloodType == bt ? "" : bt
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(bt)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(bloodType == bt ? Color.arkInk : .primary)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(
                                bloodType == bt ? Color.goPrimary : Color.primary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .scaleEffect(bloodType == bt ? 0.96 : 1.0)
                            .animation(.spring(response: 0.25), value: bloodType)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }

        Divider().opacity(0.15)

        VStack(alignment: .leading, spacing: 10) {
            cardSectionLabel(l.humanWizMbtiLabel)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        mbti = ""
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(l.humanWizSkipChip)
                            .font(.system(size: 13, weight: mbti.isEmpty ? .bold : .medium, design: .rounded))
                            .foregroundStyle(mbti.isEmpty ? Color.arkInk : .primary.opacity(0.75))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(mbti.isEmpty ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    ForEach(mbtiOptions, id: \.self) { code in
                        Button {
                            mbti = (mbti == code) ? "" : code
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(code)
                                .font(.system(size: 12, weight: mbti == code ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(mbti == code ? Color.arkInk : .primary.opacity(0.75))
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .background(mbti == code ? Color.goPrimary : Color.primary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Card 3: Avatar

    private var card3Avatar: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                meshCardLabel(l.humanWizMesh3).padding(.top, 14).padding(.horizontal, 20)

                VStack(spacing: 10) {
                    cardSectionLabel(l.humanWizAvatarPhoto)
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            avatarActionButton(icon: "photo.on.rectangle", label: l.humanWizPhotoLibrary)
                        }
                        Button { presentCamera() } label: {
                            avatarActionButton(icon: "camera.fill", label: l.humanWizCamera)
                        }
                    }
                    Text(avatar2DStatusText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(canUseAutomatic2DAvatar ? Color.goPrimary.opacity(0.85) : .secondary.opacity(0.65))
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
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    // MARK: - Card 4: Family (Role + Nationality + Notes)

    private var card4Family: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh4).padding(.top, 14).padding(.horizontal, 20)

                // Permission
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizRolePermsLabel)
                    roleOption("owner", title: l.humanWizRoleOwnerTitle, desc: l.humanWizRoleOwnerDesc, icon: "crown.fill")
                    roleOption("member", title: l.humanWizRoleMemberTitle, desc: l.humanWizRoleMemberDesc, icon: "person.fill")
                }

                Divider().opacity(0.15)

                // 国籍（列表）
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizNationalityLabel)
                    Text(l.humanWizNationalityHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.65))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                nationalityCountry = ""
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(l.humanWizSkipChip)
                                    .font(.system(size: 13, weight: nationalityCountry.isEmpty ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(nationalityCountry.isEmpty ? Color.arkInk : .primary.opacity(0.75))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(
                                        nationalityCountry.isEmpty ? Color.goPrimary : Color.primary.opacity(0.08),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            ForEach(PetBreedDatabase.countries, id: \.self) { country in
                                Button {
                                    nationalityCountry = nationalityCountry == country ? "" : country
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(country)
                                        .font(.system(size: 13, weight: nationalityCountry == country ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(nationalityCountry == country ? Color.arkInk : .primary.opacity(0.75))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(
                                            nationalityCountry == country ? Color.goPrimary : Color.primary.opacity(0.08),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }

                Divider().opacity(0.15)

                // 现居地：国家 + 城市（列表，与宠物出生地同源数据）
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizResidenceLabel)
                    Text(l.humanWizResidenceHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.65))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                residenceCountry = ""
                                residenceCity = ""
                                isCustomResidenceCity = false
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(l.humanWizSkipChip)
                                    .font(.system(size: 13, weight: residenceCountry.isEmpty && residenceCity.isEmpty ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(residenceCountry.isEmpty && residenceCity.isEmpty ? Color.arkInk : .primary.opacity(0.75))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(
                                        residenceCountry.isEmpty && residenceCity.isEmpty ? Color.goPrimary : Color.primary.opacity(0.08),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            ForEach(PetBreedDatabase.countries, id: \.self) { country in
                                Button {
                                    if residenceCountry == country {
                                        residenceCountry = ""
                                        residenceCity = ""
                                        isCustomResidenceCity = false
                                    } else {
                                        residenceCountry = country
                                        residenceCity = ""
                                        isCustomResidenceCity = false
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(country)
                                        .font(.system(size: 13, weight: residenceCountry == country ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(residenceCountry == country ? Color.arkInk : .primary.opacity(0.75))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(
                                            residenceCountry == country ? Color.goPrimary : Color.primary.opacity(0.08),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                    if !residenceCountry.isEmpty {
                        let cities = PetBreedDatabase.cities(for: residenceCountry)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(cities, id: \.self) { city in
                                Button {
                                    if city == "其他" {
                                        isCustomResidenceCity = true
                                        residenceCity = ""
                                    } else {
                                        isCustomResidenceCity = false
                                        residenceCity = residenceCity == city ? "" : city
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(l.humanResidenceCityOther(city))
                                        .font(.system(size: 13, weight: residenceCity == city && !isCustomResidenceCity ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(
                                            (residenceCity == city && !isCustomResidenceCity) || (city == "其他" && isCustomResidenceCity)
                                                ? Color.arkInk : .primary.opacity(0.75)
                                        )
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(
                                            (residenceCity == city && !isCustomResidenceCity) || (city == "其他" && isCustomResidenceCity)
                                                ? Color.goPrimary : Color.primary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        if isCustomResidenceCity {
                            GoDraftTextField(
                                l.humanWizResidenceCityPlaceholder,
                                text: $residenceCity,
                                commitDelayNanoseconds: 180_000_000,
                                submitLabel: .done,
                                capitalization: .words
                            )
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .padding(12)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .transaction { $0.animation = nil }
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizNotesLabel)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "note.text")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .padding(.top, 2)
                        GoDraftTextField(
                            l.humanWizNotesPlaceholder,
                            text: $notes,
                            axis: .vertical,
                            commitDelayNanoseconds: 220_000_000,
                            submitLabel: .done
                        )
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(3...5)
                            .transaction { $0.animation = nil }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    // MARK: - Card 5: Body data + Privacy

    private var card5Body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh5).padding(.top, 14).padding(.horizontal, 20)

                // Height
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizBodyLabel)
                    HStack(spacing: 12) {
                        bodyDataField(
                            icon: "ruler", iconColor: Color(hex: "00E5C8"),
                            label: l.humanWizHeightLabel, placeholder: l.humanWizHeightPh, unit: "cm", text: $heightText
                        )
                        bodyDataField(
                            icon: "scalemass.fill", iconColor: Color.goPrimary,
                            label: l.humanWizWeightLabel, placeholder: l.humanWizWeightPh, unit: "kg", text: $weightText
                        )
                    }
                    Text(l.humanWizWeightFootnote)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.5))
                }

                Divider().opacity(0.15)

                // Privacy
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizPrivacyLabel)
                    Text(l.humanWizPrivacyHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.6))
                    VStack(spacing: 8) {
                        privacyRow(l.humanWizPrivacyWeight, emoji: "⚖️", binding: $privateWeight)
                        privacyRow(l.humanWizPrivacyWorkout, emoji: "🏋️", binding: $privateWorkout)
                        privacyRow(l.medication, emoji: "💊", binding: $privateMedication)
                        privacyRow(l.humanWizPrivacyWishlist, emoji: "🎁", binding: $privateWishlist)
                        privacyRow(l.humanWizPrivacyExpense, emoji: "💸", binding: $privateExpense)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    // MARK: - Card 6: Theme + Role + Confirm

    private var card6Confirm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh6).padding(.top, 14).padding(.horizontal, 20)

                // Theme color
                VStack(alignment: .leading, spacing: 12) {
                    cardSectionLabel(l.humanWizThemeLabel)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(themeColorOptions, id: \.hex) { opt in
                                Button {
                                    themeColorHex = opt.hex
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    VStack(spacing: 5) {
                                        Circle()
                                            .fill(Color(hex: opt.hex))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle().strokeBorder(
                                                    themeColorHex == opt.hex ? Color.white : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                            )
                                            .shadow(
                                                color: Color(hex: opt.hex).opacity(themeColorHex == opt.hex ? 0.6 : 0),
                                                radius: 8
                                            )
                                            .scaleEffect(themeColorHex == opt.hex ? 1.15 : 1.0)
                                            .animation(.spring(response: 0.25), value: themeColorHex)
                                        Text(l.humanThemeSwatchLabel(opt.label))
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.ohanaPrimaryText.opacity(themeColorHex == opt.hex ? 1 : 0.4))
                                    }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                Divider().opacity(0.15)

                if isCreatingFirstHuman {
                    firstHumanAppPreferencesSection
                    Divider().opacity(0.15)
                }

                // Summary tags
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizSummaryLabel)
                    FlowTagRow(
                        tags: [
                            isGenderReady ? l.humanGenderDisplay(gender) : nil,
                            HumanProfileOptions.normalizedRole(role) == "owner" ? l.humanWizRoleOwnerTitle : l.humanWizRoleMemberTitle,
                            bloodType.isEmpty ? nil : l.humanWizBloodTag(bloodType),
                            nationalityCountry.isEmpty ? nil : l.humanWizNationalityTag(nationalityCountry),
                            residenceTagText,
                            hasBirthday ? Human.westernZodiacDisplay(for: birthday, isEnglish: l.isEn) : nil,
                            hasBirthday ? birthday.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)) : nil,
                            mbti.isEmpty ? nil : mbti.uppercased(),
                            heightText.isEmpty ? nil : "\(heightText) cm",
                            weightText.isEmpty ? nil : "\(weightText) kg",
                        ].compactMap { $0 },
                        emptyHint: l.humanWizSummaryEmpty,
                        accent: accentColor
                    )
                }

                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let confirmNameOk = !trimmedName.isEmpty && !isNameDuplicate
                let confirmOk = confirmNameOk && isGenderReady
                Button {
                    guard confirmOk else {
                        if isNameDuplicate { showDuplicateNameAlert = true }
                        return
                    }
                    GoKeyboard.dismiss()
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    saveHuman()
                } label: {
                    HStack(spacing: 8) {
                        Text(trimmedName.isEmpty ? l.humanWizNeedName : isNameDuplicate ? l.humanWizNameTakenBtn : !isGenderReady ? l.humanWizNeedGender : l.humanWizJoinIsland)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        Image(systemName: confirmOk ? "checkmark.circle.fill" : "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                    }
                    .foregroundStyle(confirmOk ? Color.arkInk : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(confirmOk ? Color.goPrimary : Color.primary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!confirmOk)
                .padding(.top, 4)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    // MARK: - Component helpers

    private var firstHumanAppPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardSectionLabel(l.tr(
                zh: "App 偏好",
                en: "App preferences",
                de: "App-Einstellungen"
            ))
            Text(l.tr(
                zh: "作为第一个成员，先确认整个 app 使用的货币和计量单位。",
                en: "As the first member, confirm the currency and units for the whole app.",
                de: "Als erstes Mitglied legst du Währung und Einheiten für die App fest."
            ))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText.opacity(0.65))

            VStack(spacing: 10) {
                appPreferenceMenuRow(
                    icon: selectedCurrency.systemIconName,
                    iconColor: Color.goYellow,
                    title: l.currency,
                    value: selectedCurrency.displayName
                ) {
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
                }

                appPreferenceMenuRow(
                    icon: selectedMeasurementSystem.systemIconName,
                    iconColor: Color.goTeal,
                    title: l.measurementUnits,
                    value: selectedMeasurementSystem.title(appLanguage)
                ) {
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
                }
            }
        }
    }

    private func appPreferenceMenuRow<MenuContent: View>(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer()
            Menu {
                menuContent()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 卡内小节标题（与 `AddPetWizardView` 卡内 `Text(…).foregroundStyle(Color.ohanaSecondaryText)` 同级）
    private func cardSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    /// 生日滚轮 Sheet：选日期后点「完成」写回 `birthday`
    private var birthdayPickerSheet: some View {
        let range = birthdaySelectableRange
        return NavigationStack {
            VStack(spacing: 14) {
                DatePicker("", selection: $birthdayPickerDraft, in: range, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                Text(Human.westernZodiacDisplay(for: birthdayPickerDraft, isEnglish: l.isEn))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                Button {
                    let lo = range.lowerBound
                    let hi = range.upperBound
                    birthday = min(max(birthdayPickerDraft, lo), hi)
                    showBirthdayPickerSheet = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text(l.done)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                Spacer(minLength: 8)
            }
            .padding(.top, 8)
            .navigationTitle(l.humanWizBirthdaySheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel) { showBirthdayPickerSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func avatarActionButton(icon: String, label: String, accent: Color = Color.goPrimary) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.65))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func bodyDataField(
        icon: String, iconColor: Color,
        label: String, placeholder: String, unit: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                GoDraftTextField(
                    placeholder,
                    text: text,
                    commitDelayNanoseconds: 140_000_000,
                    keyboardType: .decimalPad,
                    submitLabel: .done,
                    capitalization: .never
                )
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .transaction { $0.animation = nil }
            }
            Text(unit)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func privacyRow(_ title: String, emoji: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 20)).frame(width: 28)
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Toggle("", isOn: binding)
                .tint(Color.goPrimary)
                .labelsHidden()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func roleOption(_ key: String, title: String, desc: String, icon: String) -> some View {
        let normalizedKey = HumanProfileOptions.normalizedRole(key)
        let isSelected = HumanProfileOptions.normalizedRole(role) == normalizedKey

        return Button { role = normalizedKey; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? accentColor : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(desc)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(14)
            .background(
                isSelected ? accentColor.opacity(0.08) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.25), value: role)
    }

    // MARK: - Photo handling

    private func handlePhotosPicker(_ item: PhotosPickerItem?) {
        Task {
            guard let item else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            if let data = try? await item.loadTransferable(type: Data.self) {
                let ui = await Task.detached(priority: .userInitiated) {
                    AddPetWizardView.cropReadyImage(from: data, maxPixel: 1_600)
                }.value
                await MainActor.run {
                    if let ui {
                        cropImageItem = IdentifiableCropImage(image: ui)
                        AppPerformanceMonitor.shared.record("相册到裁剪页", startedAt: startedAt, note: "人类头像")
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

    private func pastePasteboardImage() {
        guard let image = UIPasteboard.general.image else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let startedAt = CFAbsoluteTimeGetCurrent()
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                AddPetWizardView.preparedCropImage(image, maxPixel: 1_600)
            }.value
            cropImageItem = IdentifiableCropImage(image: prepared)
            AppPerformanceMonitor.shared.record("粘贴到裁剪页", startedAt: startedAt, note: "人类头像")
        }
    }

    private func prepareCapturedAvatarForCrop(_ image: UIImage) {
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                AddPetWizardView.preparedCropImage(image, maxPixel: 1_600)
            }.value
            try? await Task.sleep(nanoseconds: 120_000_000)
            cropImageItem = IdentifiableCropImage(image: prepared)
            AppPerformanceMonitor.shared.markEnd("avatar.camera.to.crop", name: "拍照到裁剪页", note: "人类头像")
        }
    }

    private func refreshAutomaticAvatarAssetData() {
        guard usesAutomaticAvatarAsset else { return }
        guard canUseAutomatic2DAvatar else {
            avatarImageData = nil
            return
        }
        avatarImageData = automaticHumanAvatarData()
    }

    private func automaticHumanAvatarData() -> Data? {
        HumanAvatarAssetCatalog.avatarData(
            gender: isGenderReady ? gender : "非二元",
            birthday: hasBirthday ? birthday : nil
        )
    }

    private func restoreAutomaticAvatarAsset() {
        guard canUseAutomatic2DAvatar else { return }
        usesAutomaticAvatarAsset = true
        refreshAutomaticAvatarAssetData()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func scheduleAvatarDecode() {
        guard let data = avatarImageData, !data.isEmpty else {
            decodedAvatar = nil; decodedAvatarTransparent = false; return
        }
        let snap = data
        Task.detached(priority: .utility) {
            let img = UIImage(data: snap).map { AddPetWizardView.downsample($0, maxDim: 900) }
            let transparent = ImageCutoutService.isTransparentPNG(snap)
            await MainActor.run {
                guard avatarImageData == snap else { return }
                decodedAvatar = img
                decodedAvatarTransparent = transparent
            }
        }
    }

    // MARK: - Save

    private func saveHuman() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard isGenderReady else { return }

        let human = Human(
            name: trimmed,
            birthday: hasBirthday ? birthday : nil,
            bloodType: bloodType,
            avatarEmoji: fallbackAvatarEmoji(for: gender),
            role: HumanProfileOptions.normalizedRole(role)
        )
        var parts: [String] = []
        parts.append("性别:\(HumanProfileOptions.normalizedGender(gender))")
        if !notes.isEmpty { parts.append(notes) }
        human.notes = parts.joined(separator: "｜")
        human.nationality = nationalityCountry
        if residenceCountry.isEmpty && residenceCity.isEmpty {
            human.city = ""
        } else if !residenceCountry.isEmpty, !residenceCity.isEmpty {
            human.city = "\(residenceCountry)·\(residenceCity)"
        } else if !residenceCountry.isEmpty {
            human.city = residenceCountry
        } else {
            human.city = residenceCity
        }
        let shouldUseAutomaticAvatar = usesAutomaticAvatarAsset && canUseAutomatic2DAvatar
        let finalAvatarData = shouldUseAutomaticAvatar ? automaticHumanAvatarData() : avatarImageData
        human.avatarImageData = finalAvatarData
        human.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            themeColorHex,
            fallback: OhanaThemeColorPolicy.humanFallbackHex
        )
        human.shouldShowOnHome = true
        human.mbti = mbti.trimmingCharacters(in: .whitespaces).uppercased()
        if let h = Double(heightText), h > 0 { human.heightCm = h }

        human.setPrivate(.weight, privateWeight)
        human.setPrivate(.workout, privateWorkout)
        human.setPrivate(.medication, privateMedication)
        human.setPrivate(.wishlist, privateWishlist)
        human.setPrivate(.expense, privateExpense)

        modelContext.insert(human)
        if shouldUseAutomaticAvatar, finalAvatarData != nil {
            Avatar2DAccess.consumeIfNeeded(kind: .human, existingCount: existingHumans.count)
        }

        if let w = Double(weightText), w > 0 {
            let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                .flatMap { $0.isEmpty ? nil : $0 }
            modelContext.insert(HumanWeightLog(date: Date(), weight: w, human: human, executorId: executorId))
        }
        if hasBirthday {
            let l10 = L10n.current
            let ev = Event(
                title: "\(trimmed)\(l10.humanWizBirthdayEventSuffix)",
                startDate: birthday, isAllDay: true,
                eventType: EventType.birthday.rawValue,
                relatedEntityType: "Human", relatedEntityId: human.id.uuidString
            )
            ev.recurrenceDays = 365
            modelContext.insert(ev)
        }

        modelContext.safeSave()
        onHumanSaved?(human)
        onComplete()
    }
}

// MARK: - Flow Tag Row (accent-aware)

private struct FlowTagRow: View {
    let tags: [String]
    var emptyHint: String
    var accent: Color = Color(hex: OhanaThemeColorPolicy.humanFallbackHex)
    var body: some View {
        if tags.isEmpty {
            Text(emptyHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText.opacity(0.5))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(accent.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
    }
}
