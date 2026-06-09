//
//  AddHumanWizardView.swift
//  Ohana
//
//  Lightweight RPG-style human creation wizard.
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

// MARK: - AddHumanWizardView

struct AddHumanWizardView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)? = nil
    var onHumanSaved: ((Human) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) private var appMeasurementSystem = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) private var appCurrency = AppCurrency.fallbackCode
    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    private var l: L10n { L10n(appLanguage) }

    // ── Identity
    @State private var memberCreationSessionId = UUID()
    @State private var name = ""
    @State private var avatarImageData: Data? = nil
    @State private var usesAutomaticAvatarAsset = true
    @State private var showingPhotoPicker = false
    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var pendingCapturedAvatarImage: UIImage? = nil
    @State private var cropImageItem: IdentifiableCropImage? = nil
    @State private var cropPresentationTask: Task<Void, Never>? = nil
    @State private var isAvatarMediaTransitioning = false
    @State private var avatarMediaReturnPageIndex: Int? = nil

    // ── Profile
    @State private var gender = ""
    @State private var hasBirthday = true
    @State private var birthday = Date()
    @State private var bloodType = ""
    @State private var mbti = ""

    // ── Family（权限 / 性别身份 / 国籍 / 现居地：写入 role / notes / Human.nationality / Human.city）
    @State private var nationalityCountry = ""
    @State private var residenceCountry = ""
    @State private var residenceCity = ""
    @State private var isCustomResidenceCity = false
    @State private var notes = ""

    // ── Body data
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var activeBodyMetric: BodyMetricField? = nil
    @State private var privateWeight = false
    @State private var privateWorkout = false
    @State private var privateMedication = false
    @State private var privateWishlist = false
    @State private var privateExpense = false

    // ── Theme + Role
    @State private var themeColorHex = OhanaThemeColorPolicy.humanFallbackHex
    @State private var role = "owner"

    // ── Wizard navigation
    @State private var wizardPageIndex = 0
    @State private var wizardPageDirection = 1
    @Namespace private var themeSelectionNamespace

    // ── Alerts
    @State private var showDuplicateNameAlert = false
    @State private var showJoinCelebration = false
    @State private var joinedHumanName = ""

    // ── Avatar decoded cache (avoid re-decoding on each keystroke)
    @State private var decodedAvatar: UIImage? = nil
    @State private var decodedAvatarTransparent = false
    @State private var avatarAssetLoadTask: Task<Void, Never>? = nil

    private var totalCards: Int { 5 }

    private enum BodyMetricField: Equatable {
        case height
        case weight
    }

    private let bloodTypes = ["A", "B", "AB", "O"]
    private let mbtiOptions: [String] = [
        "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP",
    ]
    private var genderOptions: [(key: String, icon: String)] {
        HumanProfileOptions.genderOptions.filter {
            HumanProfileOptions.normalizedGender($0.key) != "不透露"
        }
    }

    private let themeColorOptions = AddWizardThemePalette.memberOptions

    // MARK: - Computed

    private var wizardAccent: Color { Color.goPrimary }
    private var memberThemeColor: Color { Color(hex: themeColorHex) }
    private var isCreatingFirstHuman: Bool { existingHumans.isEmpty }
    private var selectedMeasurementSystem: AppMeasurementSystem.Option {
        AppMeasurementSystem.option(for: appMeasurementSystem)
    }

    private var selectedCurrency: AppCurrency.Option {
        AppCurrency.supported.first { $0.code == AppCurrency.normalize(appCurrency) } ?? AppCurrency.supported[0]
    }

    /// 创建页顶卡与首页卡片堆保持同一尺寸，不再压缩。
    private var walletDraftCardHeight: CGFloat { K.cardH }
    private let walletCardCorner: CGFloat = 24

    private var wizardStages: [AddWizardStageItem] {
        [
            AddWizardStageItem(id: 0, title: l.tr(zh: "身份卡", en: "Identity", de: "Identität"), systemImage: "person.text.rectangle.fill"),
            AddWizardStageItem(id: 1, title: l.tr(zh: "形象", en: "Avatar", de: "Avatar"), systemImage: "sparkles"),
            AddWizardStageItem(id: 2, title: l.tr(zh: "权限", en: "Role", de: "Rolle"), systemImage: "crown.fill"),
            AddWizardStageItem(id: 3, title: l.tr(zh: "身体档案", en: "Body", de: "Körper"), systemImage: "heart.text.square.fill"),
            AddWizardStageItem(id: 4, title: l.tr(zh: "加入 Ohana", en: "Join", de: "Beitreten"), systemImage: "checkmark.seal.fill"),
        ]
    }

    /// 顶卡脚注：身份 · 国籍 · 现居 · 年龄（仅「岁」，不含月；星座单独显示在卡上）
    private var draftWalletSubtitle: String {
        var parts: [String] = []
        if !gender.isEmpty { parts.append(l.humanGenderDisplay(gender)) }
        if !bloodType.isEmpty { parts.append(l.humanWizBloodTag(bloodType)) }
        if !nationalityCountry.isEmpty {
            parts.append(l.humanWizNationalityTag(nationalityCountry))
        }
        if !residenceCountry.isEmpty || !residenceCity.isEmpty {
            if residenceCountry.isEmpty {
                parts.append(l.tr(zh: "现居 \(residenceCity)", en: "Nest: \(residenceCity)", de: "Nest: \(residenceCity)"))
            } else if residenceCity.isEmpty {
                parts.append(l.tr(zh: "现居 \(residenceCountry)", en: "Nest: \(residenceCountry)", de: "Nest: \(residenceCountry)"))
            } else {
                parts.append(l.tr(zh: "现居 \(residenceCountry)·\(residenceCity)", en: "Nest: \(residenceCountry) · \(residenceCity)", de: "Nest: \(residenceCountry) · \(residenceCity)"))
            }
        }
        if hasBirthday {
            let cal = Calendar.current
            let y = cal.dateComponents([.year], from: birthday, to: Date()).year ?? 0
            if y >= 1 {
                parts.append(l.tr(zh: "\(y)岁", en: "\(y) yrs young", de: "\(y) J. jung"))
            } else {
                parts.append(l.tr(zh: "不满1岁", en: "Under 1 ✨", de: "Unter 1 ✨"))
            }
        }
        let cleanHeight = heightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanHeight.isEmpty { parts.append("\(cleanHeight) cm") }
        let cleanWeight = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanWeight.isEmpty { parts.append("\(cleanWeight) kg") }
        return parts.joined(separator: " · ")
    }

    private var birthdaySelectableRange: ClosedRange<Date> {
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .year, value: -120, to: end) else { return end ... end }
        return start ... end
    }

    private var residenceTagText: String? {
        if residenceCountry.isEmpty, residenceCity.isEmpty { return nil }
        if residenceCity.isEmpty {
            return l.tr(zh: "现居 \(residenceCountry)", en: "Nest: \(residenceCountry)", de: "Nest: \(residenceCountry)")
        }
        if residenceCountry.isEmpty {
            return l.tr(zh: "现居 \(residenceCity)", en: "Nest: \(residenceCity)", de: "Nest: \(residenceCity)")
        }
        return l.tr(zh: "现居 \(residenceCountry)·\(residenceCity)", en: "Nest: \(residenceCountry) · \(residenceCity)", de: "Nest: \(residenceCountry) · \(residenceCity)")
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

    private var isShowingAutomatic2DAvatar: Bool {
        usesAutomaticAvatarAsset && canUseAutomatic2DAvatar
    }

    // MARK: - Body

    var body: some View {
        MemberCardCreationView(
            kind: .human,
            onComplete: onComplete,
            onCancel: onCancel,
            onHumanSaved: onHumanSaved,
            recoverySessionId: memberCreationSessionId
        )
    }

    // MARK: - Layout

    private var wizardMainColumn: some View {
        AddWizardThreePanelLayout(previewPanelHeight: walletDraftCardHeight + 12) {
            stickyWalletHumanPreview
        } content: {
            pagedCards
                .padding(.horizontal, 7) // Match the wallet preview card width above.
        } footer: {
            wizardPageDotRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            zodiacText: hasBirthday ? Human.westernZodiacDisplay(for: birthday, l: l) : nil,
            mbtiText: mbti.trimmingCharacters(in: .whitespaces).isEmpty ? nil : mbti.uppercased(),
            subtitle: draftWalletSubtitle,
            cornerRadius: walletCardCorner
        )
        .frame(height: walletDraftCardHeight)
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 8) {
                AddWizardStatusBadge(
                    title: l.tr(zh: "角色卡", en: "Character card", de: "Charakterkarte"),
                    systemImage: "sparkles",
                    tint: Color.goPrimary
                )
                if isShowingAutomatic2DAvatar {
                    AddWizardStatusBadge(
                        title: l.tr(zh: "2.5D 头像", en: "2.5D avatar", de: "2,5D-Avatar"),
                        systemImage: "wand.and.stars",
                        tint: Color.goTeal
                    )
                }
            }
            .padding(.leading, 16)
            .padding(.bottom, 14)
        }
        .overlay(alignment: .topTrailing) {
            if let onCancel {
                AddWizardCardCloseButton(action: onCancel)
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
        }
        .padding(.horizontal, 7) // 与首页卡片堆 K.cardMargin 保持一致
        .padding(.top, 6)
        .padding(.bottom, 6)
        .animation(GoMotion.feedback, value: name)
        .animation(GoMotion.feedback, value: gender)
        .animation(GoMotion.feedback, value: avatarImageData?.count)
        .animation(GoMotion.feedback, value: themeColorHex)
        .animation(GoMotion.feedback, value: nationalityCountry)
        .animation(GoMotion.feedback, value: residenceCountry)
        .animation(GoMotion.feedback, value: hasBirthday)
        .animation(GoMotion.feedback, value: birthday)
        .animation(GoMotion.feedback, value: mbti)
    }

    // MARK: - Paged cards

    private var pagedCards: some View {
        AddWizardPagedCardCarousel(
            pageIndex: $wizardPageIndex,
            pageDirection: $wizardPageDirection,
            pageCount: totalCards
        ) { index in
            AnyView(pagedCard {
                wizardCard(for: index)
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func wizardCard(for index: Int) -> some View {
        switch index {
        case 0:
            card1IdentityAndProfile
        case 1:
            card3Avatar
        case 2:
            card4Family
        case 3:
            card5Body
        default:
            card6Confirm
        }
    }

    // MARK: - Stage row

    private var wizardPageDotRow: some View {
        AddWizardStageProgress(stages: wizardStages, currentIndex: wizardPageIndex) { index in
            GoKeyboard.dismiss()
            navigateToWizardPage(index)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func navigateToWizardPage(_ index: Int) {
        let clamped = min(max(index, 0), totalCards - 1)
        guard clamped != wizardPageIndex else { return }
        wizardPageDirection = clamped > wizardPageIndex ? 1 : -1
        withAnimation(GoMotion.page) {
            wizardPageIndex = clamped
        }
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

    private var meshIdentityProfile: String {
        isCreatingFirstHuman
            ? l.tr(zh: "本人档案 · 1/5", en: "YOUR PROFILE · 1/5", de: "DEIN PROFIL · 1/5")
            : l.tr(zh: "身份卡 · 1/5", en: "IDENTITY CARD · 1/5", de: "IDENTITÄTSKARTE · 1/5")
    }

    private var meshAvatar: String {
        l.tr(zh: "形象确认 · 2/5", en: "AVATAR CHECK · 2/5", de: "AVATAR-CHECK · 2/5")
    }

    private var meshFamily: String {
        l.tr(zh: "权限徽章 · 3/5", en: "ROLE BADGE · 3/5", de: "ROLLENABZEICHEN · 3/5")
    }

    private var meshBody: String {
        l.tr(zh: "身体档案 · 4/5", en: "BODY FILE · 4/5", de: "KÖRPERAKTE · 4/5")
    }

    private var meshConfirm: String {
        l.tr(zh: "加入 Ohana · 5/5", en: "JOIN OHANA · 5/5", de: "OHANA BEITRETEN · 5/5")
    }

    private var card1IdentityAndProfile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                meshCardLabel(meshIdentityProfile).padding(.top, 10).padding(.horizontal, 16)
                humanNameSection
                VStack(spacing: 16) {
                    humanProfileFields
                }
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 16)
        }
        .scrollDisabled(true)
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
            .font(.system(size: 27, weight: .black, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.vertical, 15).padding(.horizontal, 14)
            .background(Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        name.isEmpty ? Color.red.opacity(0.4) :
                            isNameDuplicate ? Color.orange.opacity(0.7)
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

    @ViewBuilder
    private var humanProfileFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardSectionLabel(l.humanWizGenderLabel)
            HStack(spacing: 8) {
                ForEach(genderOptions, id: \.key) { opt in
                    genderOptionButton(opt)
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                cardSectionLabel(l.humanWizBirthdayLabel)
                Spacer()
                Toggle("", isOn: $hasBirthday)
                    .tint(Color.goPrimary)
                    .labelsHidden()
            }
            if hasBirthday {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(birthday.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(Human.westernZodiacDisplay(for: birthday, l: l))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                    }
                    Spacer()
                    DatePicker("", selection: $birthday, in: birthdaySelectableRange, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .simultaneousGesture(TapGesture().onEnded {
                            GoKeyboard.dismiss()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        })
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
                )
            }
        }
        .animation(GoMotion.feedback, value: hasBirthday)

        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                cardSectionLabel(l.humanWizBloodLabel)
                HStack(spacing: 6) {
                    ForEach(bloodTypes, id: \.self) { bt in
                        Button {
                            bloodType = bloodType == bt ? "" : bt
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(bt)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(bloodType == bt ? Color.arkInk : Color.ohanaPrimaryText)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(
                                    bloodType == bt ? Color.goPrimary : Color.ohanaCardSurfaceElevated,
                                    in: Capsule()
                                )
                                .scaleEffect(bloodType == bt ? 0.96 : 1.0)
                                .animation(GoMotion.feedback, value: bloodType)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                cardSectionLabel(l.humanWizMbtiLabel)
                Menu {
                    Button(l.humanWizSkipChip) {
                        mbti = ""
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    ForEach(mbtiOptions, id: \.self) { code in
                        Button(code) {
                            mbti = code
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(mbti.isEmpty ? l.humanWizSkipChip : mbti)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(mbti.isEmpty ? Color.ohanaSecondaryText : Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(
                        mbti.isEmpty ? Color.ohanaCardSurfaceElevated : Color.goPrimary,
                        in: Capsule()
                    )
                }
            }
        }
    }

    // MARK: - Card 3: Avatar

    private var card3Avatar: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                meshCardLabel(meshAvatar).padding(.top, 10).padding(.horizontal, 16)

                avatarPreviewHero

                VStack(spacing: 8) {
                    cardSectionLabel(l.humanWizAvatarPhoto)
                    HStack(spacing: 10) {
                        Button {
                            presentPhotoLibrary()
                        } label: {
                            avatarActionButton(icon: "photo.on.rectangle", label: l.humanWizPhotoLibrary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isAvatarMediaTransitioning)
                        Button { presentCamera() } label: {
                            avatarActionButton(icon: "camera.fill", label: l.humanWizCamera)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isAvatarMediaTransitioning)
                    }
                    if isShowingAutomatic2DAvatar {
                        HStack {
                            AddWizardStatusBadge(
                                title: l.tr(zh: "2.5D 头像", en: "2.5D avatar", de: "2,5D-Avatar"),
                                systemImage: "sparkles",
                                tint: Color.goPrimary
                            )
                            Spacer()
                        }
                    }
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

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        }
        .scrollDisabled(true)
    }

    // MARK: - Card 4: Family (Role + Nationality + Notes)

    private var card4Family: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                meshCardLabel(meshFamily).padding(.top, 10).padding(.horizontal, 16)

                // Permission
                VStack(alignment: .leading, spacing: 8) {
                    cardSectionLabel(l.humanWizRolePermsLabel)
                    HStack(spacing: 8) {
                        roleOption("owner", title: l.humanWizRoleOwnerTitle, desc: l.humanWizRoleOwnerDesc, icon: "crown.fill")
                        roleOption("member", title: l.humanWizRoleMemberTitle, desc: l.humanWizRoleMemberDesc, icon: "person.fill")
                    }
                }

                // 国籍（列表）
                VStack(alignment: .leading, spacing: 6) {
                    cardSectionLabel(l.humanWizNationalityLabel)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                nationalityCountry = ""
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(l.humanWizSkipChip)
                                    .font(.system(size: 13, weight: nationalityCountry.isEmpty ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(nationalityCountry.isEmpty ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.75))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .frame(minHeight: 44)
                                    .background(
                                        nationalityCountry.isEmpty ? Color.goPrimary : Color.ohanaCardSurfaceElevated,
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
                                        .foregroundStyle(nationalityCountry == country ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.75))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .frame(minHeight: 44)
                                        .background(
                                            nationalityCountry == country ? Color.goPrimary : Color.ohanaCardSurfaceElevated,
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }

                // 现居地：国家 + 城市（列表，与宠物出生地同源数据）
                VStack(alignment: .leading, spacing: 6) {
                    cardSectionLabel(l.humanWizResidenceLabel)
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
                                    .foregroundStyle(residenceCountry.isEmpty && residenceCity.isEmpty ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.75))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .frame(minHeight: 44)
                                    .background(
                                        residenceCountry.isEmpty && residenceCity.isEmpty ? Color.goPrimary : Color.ohanaCardSurfaceElevated,
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
                                        .foregroundStyle(residenceCountry == country ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.75))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .frame(minHeight: 44)
                                        .background(
                                            residenceCountry == country ? Color.goPrimary : Color.ohanaCardSurfaceElevated,
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                    if !residenceCountry.isEmpty {
                        let cities = PetBreedDatabase.cities(for: residenceCountry)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
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
                                                ? Color.arkInk : Color.ohanaPrimaryText.opacity(0.75)
                                        )
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 44)
                                        .background(
                                            (residenceCity == city && !isCustomResidenceCity) || (city == "其他" && isCustomResidenceCity)
                                                ? Color.goPrimary : Color.ohanaCardSurfaceElevated,
                                            in: Capsule()
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
                VStack(alignment: .leading, spacing: 6) {
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
                        .lineLimit(2 ... 3)
                        .transaction { $0.animation = nil }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        }
        .scrollDisabled(true)
    }

    // MARK: - Card 5: Body data + Privacy

    private var card5Body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                meshCardLabel(meshBody).padding(.top, 10).padding(.horizontal, 16)

                // Height
                VStack(alignment: .leading, spacing: 7) {
                    cardSectionLabel(l.humanWizBodyLabel)
                    HStack(spacing: 12) {
                        bodyDataMetricButton(
                            field: .height,
                            icon: "ruler", iconColor: Color(hex: "00E5C8"),
                            label: l.humanWizHeightLabel, placeholder: l.humanWizHeightPh, unit: "cm", text: $heightText
                        )
                        bodyDataMetricButton(
                            field: .weight,
                            icon: "scalemass.fill", iconColor: Color.goPrimary,
                            label: l.humanWizWeightLabel, placeholder: l.humanWizWeightPh, unit: "kg", text: $weightText
                        )
                    }
                    if let activeBodyMetric {
                        EmbeddedDecimalKeypad(
                            text: activeBodyMetric == .height ? $heightText : $weightText,
                            countryCode: appCountry,
                            maxFractionDigits: 1,
                            accent: Color.goPrimary,
                            isMini: true,
                            showsSubmitButton: true
                        ) {
                            withAnimation(GoMotion.feedback) {
                                self.activeBodyMetric = nil
                            }
                        }
                        .padding(10)
                        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }
                }
                .animation(GoMotion.feedback, value: activeBodyMetric)

                // Privacy
                VStack(alignment: .leading, spacing: 10) {
                    cardSectionLabel(l.humanWizPrivacyLabel)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        privacyPill(l.humanWizPrivacyWeight, systemImage: "scalemass.fill", binding: $privateWeight)
                        privacyPill(l.humanWizPrivacyWorkout, systemImage: "figure.run", binding: $privateWorkout)
                        privacyPill(l.medication, systemImage: "pills.fill", binding: $privateMedication)
                        privacyPill(l.humanWizPrivacyWishlist, systemImage: "gift.fill", binding: $privateWishlist)
                        privacyPill(l.humanWizPrivacyExpense, systemImage: "creditcard.fill", binding: $privateExpense)
                    }
                }

                Spacer(minLength: 14)
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 16)
        }
        .scrollDisabled(true)
    }

    // MARK: - Card 6: Theme + Role + Confirm

    private var card6Confirm: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 13) {
                meshCardLabel(meshConfirm).padding(.top, 10).padding(.horizontal, 16)

                themeColorQuestSection

                if isCreatingFirstHuman {
                    firstHumanAppPreferencesSection
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
                            hasBirthday ? Human.westernZodiacDisplay(for: birthday, l: l) : nil,
                            hasBirthday ? birthday.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted)) : nil,
                            mbti.isEmpty ? nil : mbti.uppercased(),
                            heightText.isEmpty ? nil : "\(heightText) cm",
                            weightText.isEmpty ? nil : "\(weightText) kg",
                        ].compactMap { $0 },
                        emptyHint: l.humanWizSummaryEmpty,
                        accent: memberThemeColor
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
                    .foregroundStyle(confirmOk ? Color.arkInk : Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(confirmOk ? Color.goPrimary : Color.primary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!confirmOk)
                .padding(.top, 4)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        }
        .scrollDisabled(true)
    }

    // MARK: - Component helpers

    private func genderOptionButton(_ opt: (key: String, icon: String)) -> some View {
        let isSelected = gender == opt.key
        return Button {
            withAnimation(GoMotion.selection) {
                gender = opt.key
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 7) {
                genderOptionAvatar(for: opt.key)
                    .frame(height: 64)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Text(l.humanGenderDisplay(opt.key))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Color.goPrimary : Color.ohanaCardSurfaceElevated,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.goPrimary.opacity(0.55) : Color.ohanaCardStroke, lineWidth: 1)
            )
            .scaleEffect(isSelected ? 0.98 : 1.0)
            .animation(GoMotion.selection, value: gender)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func genderOptionAvatar(for option: String) -> some View {
        HumanGenderAvatarPreview(
            gender: option,
            birthday: hasBirthday ? birthday : nil,
            isSelected: gender == option,
            accent: wizardAccent
        )
    }

    private var firstSelfProfileKickoff: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(wizardAccent)
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .symbolEffect(.bounce, value: wizardPageIndex)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(
                        zh: "先建立你的本人档案",
                        en: "Create your own profile first",
                        de: "Erstelle zuerst dein Profil"
                    ))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    Text(l.tr(
                        zh: "这是这个设备的主人身份卡。",
                        en: "This becomes the owner card for this device.",
                        de: "Das wird die Besitzerkarte dieses Geräts."
                    ))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                firstSelfProfileChip(
                    icon: "person.fill.checkmark",
                    title: l.tr(zh: "本人", en: "Owner", de: "Ich")
                )
                firstSelfProfileChip(
                    icon: "creditcard.fill",
                    title: l.tr(zh: "椰子钱包", en: "Wallet", de: "Wallet")
                )
                firstSelfProfileChip(
                    icon: "lock.shield.fill",
                    title: l.tr(zh: "隐私边界", en: "Privacy", de: "Privat")
                )
            }
        }
        .padding(.horizontal, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func firstSelfProfileChip(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(Color.ohanaPrimaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.ohanaCardSurfaceElevated, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            )
    }

    private var selectedThemeOption: (hex: String, label: String) {
        themeColorOptions.first { $0.hex == themeColorHex } ?? themeColorOptions[0]
    }

    private var themeColorQuestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    memberThemeColor.opacity(colorScheme == .dark ? 0.95 : 0.82),
                                    memberThemeColor.opacity(colorScheme == .dark ? 0.42 : 0.28),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Circle()
                        .fill(Color.goCardWhite.opacity(0.86))
                        .frame(width: 15, height: 15)
                        .offset(x: 9, y: -9)
                    Circle()
                        .fill(Color.goCardWhite.opacity(0.32))
                        .frame(width: 28, height: 28)
                        .offset(x: -7, y: 8)
                }
                .shadow(color: memberThemeColor.opacity(0.24), radius: 16, x: 0, y: 10) // ui-v4: allow selected member theme preview glow.

                VStack(alignment: .leading, spacing: 4) {
                    cardSectionLabel(l.humanWizThemeLabel)
                    Text(l.humanThemeSwatchLabel(selectedThemeOption.label))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: AddWizardThemePalette.gridColumnCount),
                spacing: 0
            ) {
                ForEach(themeColorOptions, id: \.hex) { opt in
                    themeSwatchButton(opt)
                }
            }
            .padding(.top, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            )
        }
        .animation(GoMotion.selection, value: themeColorHex)
    }

    private func themeSwatchButton(_ option: (hex: String, label: String)) -> some View {
        let isSelected = themeColorHex == option.hex
        let color = Color(hex: option.hex)

        return Button {
            withAnimation(GoMotion.selection) {
                themeColorHex = option.hex
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            AddWizardThemeMatrixCell(
                fill: color,
                liftColor: color,
                checkmarkColor: AddWizardThemeMatrixContrast.readableCheckmarkColor(for: option.hex),
                isSelected: isSelected,
                accessibilityTitle: l.humanThemeSwatchLabel(option.label)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .zIndex(isSelected ? 2 : 0)
        .accessibilityLabel(l.humanThemeSwatchLabel(option.label))
    }

    private var firstHumanAppPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardSectionLabel(l.tr(
                zh: "App 偏好",
                en: "App preferences",
                de: "App-Einstellungen"
            ))

            HStack(spacing: 8) {
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
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
            Menu {
                menuContent()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(wizardAccent)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 卡内小节标题（与 `AddPetWizardView` 卡内 `Text(…).foregroundStyle(Color.ohanaSecondaryText)` 同级）
    private func cardSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
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
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.vertical, 4)
        .background(Color.ohanaCardSurfaceElevated, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var avatarPreviewHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.ohanaCardSurfaceElevated)
            if let decodedAvatar {
                Image(uiImage: decodedAvatar)
                    .resizable()
                    .scaledToFit()
                    .padding(decodedAvatarTransparent ? 18 : 28)
            } else {
                AddWizardPlainAvatarPlaceholder(kind: .human, tint: memberThemeColor)
                    .padding(22)
            }
            VStack {
                HStack {
                    AddWizardStatusBadge(
                        title: isShowingAutomatic2DAvatar
                            ? l.tr(zh: "2.5D 头像", en: "2.5D avatar", de: "2,5D-Avatar")
                            : l.tr(zh: "普通头像", en: "Plain avatar", de: "Einfacher Avatar"),
                        systemImage: isShowingAutomatic2DAvatar ? "wand.and.stars" : "person.crop.circle",
                        tint: isShowingAutomatic2DAvatar ? Color.goTeal : memberThemeColor
                    )
                    Spacer()
                }
                Spacer()
            }
            .padding(14)
        }
        .frame(height: 164)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
        .animation(GoMotion.feedback, value: avatarImageData?.count)
        .animation(GoMotion.feedback, value: usesAutomaticAvatarAsset)
    }

    private func bodyDataMetricButton(
        field: BodyMetricField,
        icon: String, iconColor: Color,
        label: String, placeholder: String, unit: String,
        text: Binding<String>
    ) -> some View {
        let isActive = activeBodyMetric == field
        return Button {
            GoKeyboard.dismiss()
            withAnimation(GoMotion.feedback) {
                activeBodyMetric = isActive ? nil : field
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isActive ? Color.arkInk : iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? Color.arkInk.opacity(0.72) : Color.ohanaSecondaryText)
                    Text(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(isActive ? Color.arkInk : text.wrappedValue.isEmpty ? Color.ohanaSecondaryText.opacity(0.45) : Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Text(unit)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? Color.arkInk.opacity(0.72) : Color.ohanaSecondaryText)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isActive ? Color.goPrimary : Color.ohanaCardSurfaceElevated, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.goPrimary.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func privacyPill(_ title: String, systemImage: String, binding: Binding<Bool>) -> some View {
        Button {
            withAnimation(GoMotion.selection) {
                binding.wrappedValue.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(binding.wrappedValue ? Color.ohanaSecondaryText : Color.goPrimary)
                        .frame(width: 18)
                    Text(title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Spacer(minLength: 0)
                }

                privacySwitchLabel(isPrivate: binding.wrappedValue)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                Color.ohanaCardSurfaceElevated,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(binding.wrappedValue ? Color.goPrimary.opacity(0.50) : Color.ohanaCardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(title), \(binding.wrappedValue ? l.tr(zh: "隐私", en: "Private", de: "Privat") : l.tr(zh: "公开", en: "Public", de: "Öffentlich"))")
    }

    private func privacySwitchLabel(isPrivate: Bool) -> some View {
        HStack(spacing: 0) {
            Text(l.tr(zh: "公开", en: "Public", de: "Offen"))
                .foregroundStyle(isPrivate ? Color.ohanaSecondaryText : Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    !isPrivate ? Color.goPrimary : Color.clear,
                    in: Capsule()
                )
            Text(l.tr(zh: "隐私", en: "Private", de: "Privat"))
                .foregroundStyle(isPrivate ? Color.arkInk : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    isPrivate ? Color.goPrimary : Color.clear,
                    in: Capsule()
                )
        }
        .font(.system(size: 10, weight: .black, design: .rounded))
        .padding(3)
        .background(Color.ohanaCardSurface, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
        .animation(GoMotion.selection, value: isPrivate)
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
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : wizardAccent)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    Text(desc)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle((isSelected ? Color.arkInk : Color.ohanaSecondaryText).opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.arkInk)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(
                isSelected ? wizardAccent : Color.ohanaCardSurfaceElevated,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? wizardAccent.opacity(0.4) : Color.ohanaCardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.feedback, value: role)
    }

    // MARK: - Photo handling

    private func beginAvatarMediaPresentation() {
        guard !isAvatarMediaTransitioning else { return }
        GoKeyboard.dismiss()
        avatarMediaReturnPageIndex = wizardPageIndex
        isAvatarMediaTransitioning = true
    }

    private func finishAvatarMediaPresentation() {
        isAvatarMediaTransitioning = false
        restoreAvatarMediaReturnPage()
        avatarMediaReturnPageIndex = nil
    }

    private func restoreAvatarMediaReturnPage() {
        guard let index = avatarMediaReturnPageIndex else { return }
        let clamped = min(max(index, 0), totalCards - 1)
        guard clamped != wizardPageIndex else { return }
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            wizardPageDirection = clamped > wizardPageIndex ? 1 : -1
            wizardPageIndex = clamped
        }
    }

    private func presentPhotoLibrary() {
        beginAvatarMediaPresentation()
        showingPhotoPicker = true
    }

    private func handlePhotosPicker(_ item: PhotosPickerItem?) {
        Task {
            guard let item else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            await MainActor.run {
                beginAvatarMediaPresentation()
            }
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    photosPickerItem = nil
                    finishAvatarMediaPresentation()
                }
                return
            }
            let ui = await Task.detached(priority: .userInitiated) {
                AddPetWizardView.cropReadyImage(from: data, maxPixel: 1600)
            }.value
            await MainActor.run {
                photosPickerItem = nil
                guard let ui else {
                    finishAvatarMediaPresentation()
                    return
                }
                presentAvatarCropAfterMediaDismissal(ui, delayMilliseconds: 360) {
                    AppPerformanceMonitor.shared.record("相册到裁剪页", startedAt: startedAt, note: "人类头像")
                }
            }
        }
    }

    private func presentCamera() {
        beginAvatarMediaPresentation()
        requestOhanaCameraAccess {
            showingCamera = true
        } onDenied: {
            finishAvatarMediaPresentation()
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
                AddPetWizardView.preparedCropImage(image, maxPixel: 1600)
            }.value
            cropImageItem = IdentifiableCropImage(image: prepared)
            AppPerformanceMonitor.shared.record("粘贴到裁剪页", startedAt: startedAt, note: "人类头像")
        }
    }

    private func prepareCapturedAvatarForCrop(_ image: UIImage) {
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                AddPetWizardView.preparedCropImage(image, maxPixel: 1600)
            }.value
            await MainActor.run {
                presentAvatarCropAfterMediaDismissal(prepared, delayMilliseconds: 320) {
                    AppPerformanceMonitor.shared.markEnd("avatar.camera.to.crop", name: "拍照到裁剪页", note: "人类头像")
                }
            }
        }
    }

    private func presentAvatarCropAfterMediaDismissal(
        _ image: UIImage,
        delayMilliseconds: UInt64,
        onPresented: @escaping @MainActor () -> Void
    ) {
        cropPresentationTask?.cancel()
        cropPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            guard !showingPhotoPicker, !showingCamera else {
                presentAvatarCropAfterMediaDismissal(image, delayMilliseconds: 140, onPresented: onPresented)
                return
            }
            restoreAvatarMediaReturnPage()
            cropPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 50) {
                guard !showingPhotoPicker, !showingCamera else {
                    presentAvatarCropAfterMediaDismissal(image, delayMilliseconds: 140, onPresented: onPresented)
                    return
                }
                cropImageItem = IdentifiableCropImage(image: image)
                cropPresentationTask = nil
                onPresented()
            }
        }
    }

    private func refreshAutomaticAvatarAssetDataAsync() {
        guard usesAutomaticAvatarAsset else { return }
        guard canUseAutomatic2DAvatar else {
            avatarImageData = nil
            return
        }
        let requestedGender = isGenderReady ? gender : "非二元"
        let requestedBirthday = hasBirthday ? birthday : nil
        avatarAssetLoadTask?.cancel()
        avatarAssetLoadTask = Task {
            let data = await Task.detached(priority: .utility) {
                HumanAvatarAssetCatalog.avatarData(
                    gender: requestedGender,
                    birthday: requestedBirthday
                )
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard usesAutomaticAvatarAsset else { return }
                avatarImageData = data
            }
        }
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
        refreshAutomaticAvatarAssetDataAsync()
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

        let shouldUseAutomaticAvatar = usesAutomaticAvatarAsset && canUseAutomatic2DAvatar
        let finalAvatarData = shouldUseAutomaticAvatar ? automaticHumanAvatarData() : avatarImageData

        var draft = MemberCreationDraft(kind: .human)
        draft.name = trimmed
        draft.themeColorHex = themeColorHex
        draft.avatarSource = shouldUseAutomaticAvatar
            ? .avatar2D
            : (finalAvatarData == nil ? .placeholder : .customImage)
        draft.avatarImageData = finalAvatarData
        draft.humanGender = gender
        draft.hasBirthday = hasBirthday
        draft.birthday = birthday
        draft.bloodType = bloodType
        draft.mbti = mbti
        draft.role = role
        draft.usesExplicitHumanRole = true
        draft.nationality = nationalityCountry
        draft.residenceCountry = residenceCountry
        draft.residenceCity = residenceCity
        draft.notes = notes
        draft.heightText = heightText
        draft.weightText = weightText
        draft.privateWeight = privateWeight
        draft.privateWorkout = privateWorkout
        draft.privateMedication = privateMedication
        draft.privateWishlist = privateWishlist
        draft.privateExpense = privateExpense

        let result: MemberCreationService.SaveResult
        do {
            result = try MemberCreationService.save(
                draft: draft,
                existingPets: existingPets,
                existingHumans: existingHumans,
                context: modelContext,
                countryCode: appCountry
            )
        } catch MemberCreationService.ServiceError.duplicateName {
            showDuplicateNameAlert = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        guard let human = result.human else { return }
        onHumanSaved?(human)
        joinedHumanName = trimmed
        withAnimation(GoMotion.sheet) {
            showJoinCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(GoMotion.quick) {
                showJoinCelebration = false
            }
            onComplete()
        }
    }
}

// MARK: - Lightweight async avatar preview

private struct HumanGenderAvatarPreview: View {
    let gender: String
    let birthday: Date?
    let isSelected: Bool
    let accent: Color

    @State private var image: UIImage? = nil

    private var taskKey: String {
        "\(gender)-\(birthday?.timeIntervalSinceReferenceDate ?? -1)"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
            } else {
                HumanSilhouetteView(gender: gender, accent: isSelected ? .arkInk : accent)
                    .padding(.horizontal, 18)
                    .transition(.opacity)
            }
        }
        .animation(GoMotion.quick, value: image != nil)
        .task(id: taskKey) {
            let requestedGender = gender
            let requestedBirthday = birthday
            let decoded = await Task.detached(priority: .utility) {
                HumanAvatarAssetCatalog.avatarData(gender: requestedGender, birthday: requestedBirthday)
                    .flatMap { UIImage(data: $0) }
                    .map { AddPetWizardView.downsample($0, maxDim: 260) }
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                image = decoded
            }
        }
    }
}

// MARK: - Flow Tag Row (accent-aware)

private struct FlowTagRow: View {
    let tags: [String]
    var emptyHint: String
    var accent: Color = .init(hex: OhanaThemeColorPolicy.humanFallbackHex)
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
