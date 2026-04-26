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

// MARK: - Human wizard steps

private enum HumanWizardStep: Int, CaseIterable {
    case identity = 0   // 名字 + 头像
    case profile  = 1   // 性别 + 生日 + 血型
    case family   = 2   // 家庭角色 + 国籍
    case body     = 3   // 身高体重 + 隐私
    case confirm  = 4   // 主题色 + 权限 + 确认
}

// MARK: - AddHumanWizardView

struct AddHumanWizardView: View {
    let onComplete: () -> Void
    var onHumanSaved: ((Human) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @Query(sort: \Pet.createdAt)   private var existingPets:   [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    private var l: L10n { L10n(appLanguage) }

    // ── Identity
    @State private var name            = ""
    @State private var avatarEmoji     = "😊"
    @State private var avatarImageData: Data? = nil
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera   = false
    @State private var cropImageItem: IdentifiableCropImage? = nil

    // ── Profile
    @State private var gender      = ""
    @State private var hasBirthday = false
    @State private var birthday    = Date()
    @State private var bloodType   = ""
    @State private var mbti        = ""
    @State private var showBirthdayPickerSheet = false
    @State private var birthdayPickerDraft     = Date()

    // ── Family（国籍 / 现居地：列表选择，写入 Human.nationality / Human.city）
    @State private var familyRole           = ""
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
    @State private var themeColorHex = "C8FF00"
    @State private var role          = "owner"

    // ── Wizard navigation
    @State private var wizardPageIndex      = 0
    @State private var wizardTabViewRemountID = 0

    // ── Alerts
    @State private var showDuplicateNameAlert = false

    // ── Avatar decoded cache (avoid re-decoding on each keystroke)
    @State private var decodedAvatar:           UIImage? = nil
    @State private var decodedAvatarTransparent = false

    private let totalCards = HumanWizardStep.allCases.count

    private let emojiOptions: [String] = [
        "😊","😎","🧑‍💻","👩‍🍳","🧑‍🎨","🐱","🐶","🦊","🐸","🦁",
        "👤","👨","👩","🧑","👦","👧","👴","👵","🧔","👱‍♀️",
        "👩‍🦰","🧑‍🦱","🧒","👨‍🦳","👩‍🦳","🧓","👨‍🦲","👩‍🦲","👱","🥷"
    ]
    private let bloodTypes     = ["A", "B", "AB", "O"]
    private let mbtiOptions: [String] = [
        "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"
    ]
    private let genderOptions  = [("男", "♂️"), ("女", "♀️"), ("非二元", "⚧️")]
    private let familyRoleOptions = [
        "爸爸","妈妈","爷爷","奶奶","外公","外婆",
        "哥哥","姐姐","弟弟","妹妹","朋友","伴侣","自己"
    ]
    private let themeColorOptions: [(hex: String, label: String)] = [
        ("C8FF00","青柠"), ("FF7600","橙色"), ("5B6AFF","靛蓝"),
        ("FF6B9D","粉色"), ("00E5C8","青色"), ("A855F7","紫色"),
        ("FF4757","红色"), ("FDCB6E","金色")
    ]

    // MARK: - Computed

    private var accentColor: Color { Color(hex: themeColorHex) }

    private var walletDraftCardHeight: CGFloat { (ScreenCompat.width - 48) / 1.586 }
    private let walletCardCorner: CGFloat = 24

    /// 顶卡脚注：关系 · 国籍 · 现居 · 年龄（仅「岁」，不含月；星座单独显示在卡上）
    private var draftWalletSubtitle: String {
        var parts: [String] = []
        if !familyRole.isEmpty { parts.append(l.humanFamilyRoleDisplay(familyRole)) }
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

    // MARK: - Body

    var body: some View {
        wizardMainColumn
            .onAppear { scheduleAvatarDecode() }
            .onChange(of: avatarImageData)    { _, _ in scheduleAvatarDecode() }
            .onChange(of: photosPickerItem)   { _, item in handlePhotosPicker(item) }
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
                    PetImageCropView(
                        image: item.image,
                        species: "",
                        silhouetteSystemName: "person.fill"
                    ) { cropped in
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
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)

            wizardPageDotRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 与添加宠物向导同比例钱包顶卡
    private var stickyWalletHumanPreview: some View {
        WalletHumanCardDraftFront(
            name: name,
            avatarEmoji: avatarEmoji,
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
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: name)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: avatarEmoji)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: avatarImageData?.count)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: themeColorHex)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: familyRole)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: nationalityCountry)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: residenceCountry)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: residenceCity)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: hasBirthday)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: birthday)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: mbti)
    }

    // MARK: - Paged cards

    private var pagedCards: some View {
        TabView(selection: $wizardPageIndex) {
            pagedCard { card1Identity }.tag(0)
            pagedCard { card2Profile }.tag(1)
            pagedCard { card3Family }.tag(2)
            pagedCard { card4Body }.tag(3)
            pagedCard { card5Confirm }.tag(4)
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

    // MARK: - Card 1: Identity (Name + Avatar)

    private var card1Identity: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                meshCardLabel(l.humanWizMesh1).padding(.top, 14).padding(.horizontal, 20)

                // Name field
                VStack(alignment: .leading, spacing: 6) {
                    cardSectionLabel(l.humanWizNameLabel)
                    TextField(l.humanWizNamePlaceholder, text: $name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.primary)
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
                    if isNameDuplicate {
                        Text(l.humanWizDupNameInline)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "FF6B00"))
                            .padding(.leading, 4)
                    }
                }

                // Avatar photo
                VStack(spacing: 10) {
                    cardSectionLabel(l.humanWizAvatarPhoto)
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            avatarActionButton(icon: "photo.on.rectangle", label: l.humanWizPhotoLibrary)
                        }
                        Button { showingCamera = true } label: {
                            avatarActionButton(icon: "camera.fill", label: l.humanWizCamera)
                        }
                        Button { pastePasteboardImage() } label: {
                            avatarActionButton(icon: "clipboard.fill", label: l.humanWizPasteSubject, accent: .goYellow)
                        }
                    }
                    Text(l.humanWizPasteHint)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.5))
                }

                Divider().opacity(0.15)

                // Emoji grid
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizEmojiAvatar)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                        spacing: 8
                    ) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                avatarEmoji = emoji
                                avatarImageData = nil
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        avatarEmoji == emoji && avatarImageData == nil
                                            ? Color.goPrimary.opacity(0.22)
                                            : Color.primary.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                avatarEmoji == emoji && avatarImageData == nil
                                                    ? Color.goPrimary : .clear,
                                                lineWidth: 1.5
                                            )
                                    )
                                    .scaleEffect(avatarEmoji == emoji && avatarImageData == nil ? 1.06 : 1.0)
                                    .animation(.spring(response: 0.2), value: avatarEmoji)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    // MARK: - Card 2: Profile (Gender + Birthday + Blood type)

    private var card2Profile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh2).padding(.top, 14).padding(.horizontal, 20)

                // Gender
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizGenderLabel)
                    HStack(spacing: 10) {
                        ForEach(genderOptions, id: \.0) { opt in
                            Button {
                                gender = gender == opt.0 ? "" : opt.0
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 6) {
                                    Text(opt.1).font(.system(size: 24))
                                    Text(l.humanGenderDisplay(opt.0))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(gender == opt.0 ? Color.arkInk : .primary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(
                                    gender == opt.0 ? Color.goPrimary : Color.primary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .scaleEffect(gender == opt.0 ? 0.96 : 1.0)
                                .animation(.spring(response: 0.25), value: gender)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().opacity(0.15)

                // Birthday（滚轮在 Sheet 内，需点「完成」确认）
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
                            birthdayPickerDraft = birthday
                            showBirthdayPickerSheet = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(birthday.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)))
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
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
                        .buttonStyle(.plain)
                        Text(l.humanWizBirthdayHint)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.55))
                    }
                }
                .animation(.spring(response: 0.35), value: hasBirthday)

                Divider().opacity(0.15)

                // Blood type
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
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().opacity(0.15)

                // MBTI（可选）
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
                            .buttonStyle(.plain)
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
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    // MARK: - Card 3: Family (Role + Nationality + Notes)

    private var card3Family: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh3).padding(.top, 14).padding(.horizontal, 20)

                // Family role grid
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizFamilyRoleLabel)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                        spacing: 8
                    ) {
                        ForEach(familyRoleOptions, id: \.self) { opt in
                            Button {
                                familyRole = familyRole == opt ? "" : opt
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(l.humanFamilyRoleDisplay(opt))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(familyRole == opt ? Color.arkInk : .primary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(
                                        familyRole == opt ? Color.goPrimary : Color.primary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .scaleEffect(familyRole == opt ? 0.96 : 1.0)
                                    .animation(.spring(response: 0.22), value: familyRole)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().opacity(0.15)

                // 国籍（列表）
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizNationalityLabel)
                    Text(l.humanWizNationalityHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.65))
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
                            .buttonStyle(.plain)
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
                                .buttonStyle(.plain)
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
                        .foregroundStyle(.secondary.opacity(0.65))
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
                            .buttonStyle(.plain)
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
                                .buttonStyle(.plain)
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
                                .buttonStyle(.plain)
                            }
                        }
                        if isCustomResidenceCity {
                            TextField(l.humanWizResidenceCityPlaceholder, text: $residenceCity)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(12)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizNotesLabel)
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "note.text")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        TextField(l.humanWizNotesPlaceholder, text: $notes, axis: .vertical)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(3...5)
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

    // MARK: - Card 4: Body data + Privacy

    private var card4Body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh4).padding(.top, 14).padding(.horizontal, 20)

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
                        .foregroundStyle(.secondary.opacity(0.5))
                }

                Divider().opacity(0.15)

                // Privacy
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizPrivacyLabel)
                    Text(l.humanWizPrivacyHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.6))
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

    // MARK: - Card 5: Theme + Role + Confirm

    private var card5Confirm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                meshCardLabel(l.humanWizMesh5).padding(.top, 14).padding(.horizontal, 20)

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
                                            .foregroundStyle(.primary.opacity(themeColorHex == opt.hex ? 1 : 0.4))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                Divider().opacity(0.15)

                // Role
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizRolePermsLabel)
                    roleOption("owner",  title: l.humanWizRoleOwnerTitle,  desc: l.humanWizRoleOwnerDesc,   icon: "crown.fill")
                    roleOption("editor", title: l.humanWizRoleEditorTitle, desc: l.humanWizRoleEditorDesc, icon: "pencil")
                    roleOption("viewer", title: l.humanWizRoleViewerTitle, desc: l.humanWizRoleViewerDesc, icon: "eye.fill")
                }

                Divider().opacity(0.15)

                // Summary tags
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizSummaryLabel)
                    FlowTagRow(
                        tags: [
                            gender.isEmpty ? nil : l.humanGenderDisplay(gender),
                            familyRole.isEmpty ? nil : l.humanFamilyRoleDisplay(familyRole),
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
                Button {
                    guard confirmNameOk else {
                        if isNameDuplicate { showDuplicateNameAlert = true }
                        return
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    saveHuman()
                } label: {
                    HStack(spacing: 8) {
                        Text(trimmedName.isEmpty ? l.humanWizNeedName : isNameDuplicate ? l.humanWizNameTakenBtn : l.humanWizJoinIsland)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        Image(systemName: confirmNameOk ? "checkmark.circle.fill" : "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .symbolRenderingMode(.monochrome)
                    }
                    .foregroundStyle(confirmNameOk ? Color.arkInk : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(confirmNameOk ? Color.goPrimary : Color.primary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!confirmNameOk)
                .padding(.top, 4)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        }
    }

    // MARK: - Component helpers

    /// 卡内小节标题（与 `AddPetWizardView` 卡内 `Text(…).foregroundStyle(.secondary)` 同级）
    private func cardSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
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
                .foregroundStyle(.primary.opacity(0.65))
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
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(unit)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: binding)
                .tint(Color.goPrimary)
                .labelsHidden()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func roleOption(_ key: String, title: String, desc: String, icon: String) -> some View {
        Button { role = key; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(role == key ? accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(role == key ? accentColor : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(desc)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if role == key {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(14)
            .background(
                role == key ? accentColor.opacity(0.08) : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(role == key ? accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: role)
    }

    // MARK: - Photo handling

    private func handlePhotosPicker(_ item: PhotosPickerItem?) {
        Task {
            guard let item else { return }
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                await MainActor.run {
                    cropImageItem = IdentifiableCropImage(image: ui)
                }
            }
        }
    }

    private func pastePasteboardImage() {
        guard let image = UIPasteboard.general.image else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let pngData = image.pngData() {
            avatarImageData = pngData
        } else if let jpg = image.jpegData(compressionQuality: 0.92) {
            avatarImageData = jpg
        }
    }

    private func scheduleAvatarDecode() {
        guard let data = avatarImageData, !data.isEmpty else {
            decodedAvatar = nil; decodedAvatarTransparent = false; return
        }
        let snap = data
        Task.detached(priority: .utility) {
            let img = UIImage(data: snap)
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

        let human = Human(
            name: trimmed,
            birthday: hasBirthday ? birthday : nil,
            bloodType: bloodType,
            avatarEmoji: avatarEmoji,
            role: role
        )
        var parts: [String] = []
        if !gender.isEmpty { parts.append("性别:\(gender)") }
        if !familyRole.isEmpty { parts.append("关系:\(familyRole)") }
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
        human.avatarImageData = avatarImageData
        human.themeColorHex   = themeColorHex
        human.shouldShowOnHome = true
        human.mbti = mbti.trimmingCharacters(in: .whitespaces).uppercased()
        if let h = Double(heightText), h > 0 { human.heightCm = h }

        human.setPrivate(.weight, privateWeight)
        human.setPrivate(.workout, privateWorkout)
        human.setPrivate(.medication, privateMedication)
        human.setPrivate(.wishlist, privateWishlist)
        human.setPrivate(.expense, privateExpense)

        modelContext.insert(human)

        if let w = Double(weightText), w > 0 {
            modelContext.insert(HumanWeightLog(date: Date(), weight: w, human: human))
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
    var accent: Color = Color(hex: "C8FF00")
    var body: some View {
        if tags.isEmpty {
            Text(emptyHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.5))
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
