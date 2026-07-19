//
//  MemberCardCreationContentView+Steps.swift
//  Ohana
//

import AVFoundation
import Combine
import ImageIO
import os
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

extension MemberCardCreationContentView {
    var humanBasicInfoStep: some View {
        MemberCreationSection(
            title: l.tr(zh: "称呼与可选资料", en: "Name and optional details", de: "Name und optionale Angaben"),
            icon: "person.crop.rectangle.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    humanNameInput(width: 148)
                    compactGenderIconRow(
                        options: humanGenderOptions,
                        selection: $draft.humanGender,
                        label: humanGenderLabel,
                        icon: humanGenderIcon
                    )
                }
                MemberCompactDateRow(
                    title: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"),
                    icon: "birthday.cake.fill",
                    isEnabled: $draft.hasBirthday,
                    date: $draft.birthday,
                    range: birthdayRange,
                    foreground: cardForeground,
                    secondaryForeground: cardSecondaryForeground,
                    fill: cardControlFill,
                    stroke: cardControlStroke,
                    accent: cardAccent
                )
            }
        }
    }

    var petNameStep: some View {
        MemberCreationSection(
            title: l.tr(zh: "它叫什么名字？", en: "What's their name?", de: "Wie heißt dein Tier?"),
            icon: "pawprint.fill",
            foreground: cardForeground
        ) {
            petNameInput()
        }
    }

    var petIdentityStep: some View {
        MemberCreationSection(
            title: l.tr(zh: "它是什么伙伴？", en: "What kind of pet?", de: "Was für ein Tier?"),
            icon: "pawprint.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(l.tr(zh: "物种", en: "Species", de: "Art"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(cardSecondaryForeground)

                LazyVGrid(columns: petSpeciesGridColumns, spacing: 7) {
                    ForEach(speciesOptions, id: \.self) { species in
                        petSpeciesButton(species)
                    }
                }
                .accessibilityIdentifier("member-pet-species-grid")

                if draft.isCustomSpecies {
                    flatTextField(
                        l.tr(zh: "输入物种", en: "Enter species", de: "Art eingeben"),
                        text: $draft.customSpecies
                    )
                    .accessibilityIdentifier("member-pet-custom-species-input")
                }

                if !draft.species.isEmpty {
                    compactBreedPicker
                        .accessibilityIdentifier("member-pet-breed-picker")
                }

                if draft.isCustomBreed {
                    flatTextField(
                        l.tr(zh: "输入品种", en: "Enter breed", de: "Rasse eingeben"),
                        text: $draft.customBreed
                    )
                    .accessibilityIdentifier("member-pet-custom-breed-input")
                }
            }
        }
    }

    var compactBreedPicker: some View {
        compactMenuPicker(
            title: l.tr(zh: "品种", en: "Breed", de: "Rasse"),
            value: draft.resolvedBreed.isEmpty
                ? l.tr(zh: "选择", en: "Choose", de: "Wählen")
                : breedLabel(draft.resolvedBreed)
        ) {
            ForEach(petBreedPickerOptions, id: \.name) { breed in
                Button(breedLabel(breed.name)) {
                    draft.isCustomBreed = breed.name == "其他"
                    draft.breed = breed.name == "其他" ? "" : breed.name
                    draft.customBreed = ""
                    draft.coatColor = ""
                    clampPetAppearance()
                }
            }
        }
    }

    var petAppearanceStep: some View {
        MemberCreationSection(
            title: l.tr(zh: "它长什么样？", en: "What do they look like?", de: "Wie sieht dein Tier aus?"),
            icon: "paintpalette.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text(l.tr(zh: "性别（必填）", en: "Sex (required)", de: "Geschlecht (Pflicht)"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(cardSecondaryForeground)
                compactGenderIconRow(
                    options: petGenderOptions,
                    selection: $draft.petGender,
                    label: petGenderLabel,
                    icon: petGenderIcon
                )

                compactMenuPicker(
                    title: l.tr(zh: "毛色（可选）", en: "Coat (optional)", de: "Fell (optional)"),
                    value: draft.coatColor.isEmpty
                        ? l.tr(zh: "暂不设置", en: "Skip for now", de: "Vorerst überspringen")
                        : coatLabel(draft.coatColor)
                ) {
                    Button(l.tr(zh: "暂不设置", en: "Skip for now", de: "Vorerst überspringen")) {
                        draft.coatColor = ""
                    }
                    .accessibilityIdentifier("member-pet-coat-skip")
                    .accessibilityValue(
                        draft.coatColor.isEmpty
                            ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
                            : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt")
                    )
                    .accessibilityAddTraits(draft.coatColor.isEmpty ? .isSelected : [])

                    Divider()

                    ForEach(petCoatOptions, id: \.self) { option in
                        let isSelected = draft.coatColor == option
                        Button(coatLabel(option)) {
                            draft.coatColor = option
                        }
                        .accessibilityLabel(coatLabel(option))
                        .accessibilityValue(
                            isSelected
                                ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
                                : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt")
                        )
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .accessibilityIdentifier("member-pet-coat-picker")
            }
        }
    }

    var avatarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(l.tr(zh: "头像", en: "Avatar", de: "Avatar"), systemImage: "sparkles")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(cardForeground)
                Spacer()
                avatar2DToggleButton
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    mediaButton(title: l.tr(zh: "相册", en: "Photos", de: "Fotos"), icon: "photo.on.rectangle") {
                        openPhotoLibraryAfterFirstFrame()
                    }
                    mediaButton(title: isPreparingCamera ? l.tr(zh: "打开中", en: "Opening", de: "Öffnet") : l.tr(zh: "相机", en: "Camera", de: "Kamera"), icon: "camera.fill") {
                        openCameraAfterFirstFrame()
                    }
                }
                if let hint = avatarHintText {
                    Text(hint)
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(cardSecondaryForeground)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var avatar2DToggleButton: some View {
        Toggle(
            isOn: Binding(
                get: { draft.avatarSource == .avatar2D },
                set: { nextValue in
                    guard nextValue != (draft.avatarSource == .avatar2D) else { return }
                    toggle2DAvatar()
                }
            )
        ) {
            Label("2.5D", systemImage: "wand.and.stars")
                .font(OhanaFont.caption(.black))
            }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .tint(Color.goPrimary)
        .accessibilityLabel(l.tr(zh: "2.5D 头像开关", en: "2.5D avatar switch", de: "2,5D-Avatar-Schalter"))
    }

    var avatarHintText: String? {
        guard draft.avatarSource == .avatar2D, !canUseFree2D else { return nil }
        return l.tr(
            zh: "保存时消耗 1 张头像券",
            en: "Uses 1 avatar pass when saved",
            de: "Verbraucht beim Speichern 1 Avatarpass"
        )
    }

    var petPersonalityStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            MemberCreationSection(
                title: l.tr(zh: "性格（可选）", en: "Personality (optional)", de: "Charakter (optional)"),
                icon: "heart.fill",
                foreground: cardForeground
            ) {
                VStack(alignment: .leading, spacing: 7) {
                Text("\(draft.personalityTagIds.count)/3")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(cardForeground)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentTransition(.numericText())
                    .accessibilityLabel(l.tr(
                        zh: "已选择 \(draft.personalityTagIds.count) 个，最多 3 个",
                        en: "\(draft.personalityTagIds.count) selected, 3 maximum",
                        de: "\(draft.personalityTagIds.count) ausgewählt, maximal 3",
                        es: "\(draft.personalityTagIds.count) seleccionados, máximo 3",
                        pt: "\(draft.personalityTagIds.count) selecionados, máximo de 3",
                        fr: "\(draft.personalityTagIds.count) sélectionnés, 3 maximum",
                        ja: "\(draft.personalityTagIds.count)個選択、最大3個",
                        ko: "\(draft.personalityTagIds.count)개 선택됨, 최대 3개",
                        it: "\(draft.personalityTagIds.count) selezionati, massimo 3"
                    ))

                LazyVGrid(columns: personalityGridColumns, spacing: 6) {
                    ForEach(PetPersonalityTag.creationChoices) { tag in
                        let id = tag.id
                        let isSelected = draft.personalityTagIds.contains(id)
                        let isAtLimit = draft.personalityTagIds.count >= 3 && !isSelected
                        Button {
                            togglePetPersonality(id)
                        } label: {
                            HStack(spacing: 3) {
                                Text(personalityLabel(id))
                                    .font(OhanaFont.caption2(.black))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.64)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                if isSelected {
                                    Image(systemName: "checkmark") // a11y: allow decorative selected-state mark; the button exposes a selected value.
                                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                                        .accessibilityHidden(true)
                                }
                            }
                            .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                            .padding(.horizontal, 5)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                isSelected ? cardSelectedFill : cardControlFill,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(isSelected ? cardAccent.opacity(0.62) : cardControlStroke, lineWidth: 1)
                            }
                            .contentShape(Capsule())
                            .opacity(isAtLimit ? 0.58 : 1)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityIdentifier("member-pet-personality-\(id)")
                        .accessibilityLabel(personalityLabel(id))
                        .accessibilityValue(
                            isSelected
                                ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
                                : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt")
                        )
                        .accessibilityHint(
                            isAtLimit
                                ? l.tr(zh: "请先取消一个已选性格", en: "Deselect one personality first", de: "Zuerst eine Auswahl aufheben")
                                : ""
                        )
                    }
                }
            }
            }

            MemberCreationSection(
                title: l.tr(zh: "主题色（可选）", en: "Theme color (optional)", de: "Themenfarbe (optional)"),
                icon: "paintpalette.fill",
                foreground: cardForeground
            ) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(petThemeSelectionDescription)
                            .font(OhanaFont.caption2(.semibold))
                            .foregroundStyle(cardSecondaryForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)

                        if draft.hasExplicitThemeColor {
                            Button {
                                withAnimation(GoMotion.selection) {
                                    draft.hasExplicitThemeColor = false
                                }
                            } label: {
                                Text(l.tr(zh: "恢复自动", en: "Use automatic", de: "Automatisch"))
                                    .font(OhanaFont.caption2(.black))
                                    .foregroundStyle(cardForeground)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("member-pet-theme-auto")
                        }
                    }

                    Spacer(minLength: 4)

                    ColorPicker(
                        l.tr(zh: "选择宠物主题色", en: "Choose pet theme color", de: "Tier-Themenfarbe wählen"),
                        selection: petThemeColorBinding,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(l.tr(zh: "选择宠物主题色", en: "Choose pet theme color", de: "Tier-Themenfarbe wählen"))
                    .accessibilityIdentifier("member-pet-theme-color-picker")
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 48)
                .background(cardControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(cardControlStroke, lineWidth: 1)
                }
            }
        }
    }

    var personalityGridColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 6), count: count)
    }

    var petThemeColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: draft.normalizedThemeHex) },
            set: { color in
                guard let hex = color.toHex() else { return }
                withAnimation(GoMotion.selection) {
                    draft.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
                        hex,
                        fallback: MemberCreationKind.pet.fallbackThemeHex
                    )
                    draft.hasExplicitThemeColor = true
                }
            }
        )
    }

    func togglePetPersonality(_ id: String) {
        if draft.personalityTagIds.contains(id) {
            withAnimation(GoMotion.selection) {
                draft.personalityTagIds.removeAll { $0 == id }
            }
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        guard draft.personalityTagIds.count < 3 else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        withAnimation(GoMotion.selection) {
            draft.personalityTagIds.append(id)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    var humanRegionSection: some View {
        MemberCreationSection(title: l.tr(zh: "地区", en: "Region", de: "Region"), icon: "location.fill", foreground: cardForeground) {
            VStack(alignment: .leading, spacing: 10) {
                menuPicker(title: l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), value: draft.nationality.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : draft.nationality) {
                    ForEach(PetBreedDatabase.countries, id: \.self) { country in
                        Button(country) { draft.nationality = country }
                    }
                }
                menuPicker(title: l.tr(zh: "现居国家", en: "Residence", de: "Wohnort"), value: draft.residenceCountry.isEmpty ? l.tr(zh: "未设置", en: "Not set", de: "Nicht gesetzt") : draft.residenceCountry) {
                    ForEach(PetBreedDatabase.countries, id: \.self) { country in
                        Button(country) {
                            draft.residenceCountry = country
                            draft.residenceCity = ""
                            usesCustomResidenceCity = false
                        }
                    }
                }
                MemberCompactCityPicker(
                    country: draft.residenceCountry,
                    city: $draft.residenceCity,
                    usesCustomCity: $usesCustomResidenceCity
                )
            }
        }
    }

    var humanWellbeingSection: some View {
        MemberCreationSection(title: l.tr(zh: "个性与身体", en: "Personality & body", de: "Persönlichkeit & Körper"), icon: "person.text.rectangle.fill", foreground: cardForeground) {
            VStack(alignment: .leading, spacing: 12) {
                compactOptionRow(options: bloodTypes, selection: $draft.bloodType) { bloodTypeLabel($0) }
                MemberCompactMBTIBar(
                    energy: $mbtiEnergy,
                    information: $mbtiInformation,
                    decision: $mbtiDecision,
                    lifestyle: $mbtiLifestyle,
                    foreground: cardForeground
                ) {
                    updateDraftMBTI()
                }
                HStack(spacing: 10) {
                    compactHumanMetricInput(
                        title: l.tr(zh: "身高", en: "Height", de: "Größe"),
                        text: $draft.heightText,
                        placeholder: "170",
                        unit: "cm",
                        maxFractionDigits: 0
                    )
                    compactHumanMetricInput(
                        title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                        text: $draft.weightText,
                        placeholder: "60",
                        unit: "kg",
                        maxFractionDigits: 1
                    )
                }
                privacyPillGrid
            }
        }
    }

    @ViewBuilder
    var themeSection: some View {
        if kind == .human {
            compactHumanThemeGrid
        } else {
            MemberCreationSection(title: l.tr(zh: "主题色", en: "Theme color", de: "Themenfarbe"), icon: "circle.hexagongrid.fill", foreground: cardForeground) {
                themeGrid(options: AddWizardThemePalette.memberOptions, dotSize: 30, rowHeight: 38, spacing: 7)
            }
        }
    }

    var compactHumanThemeGrid: some View {
        themeGrid(options: humanCompactThemeOptions, dotSize: 24, rowHeight: 34, spacing: 6)
            .padding(.top, 2)
    }

    func themeGrid(
        options: [(hex: String, label: String)],
        dotSize: CGFloat,
        rowHeight: CGFloat,
        spacing: CGFloat
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 6), spacing: spacing) {
            ForEach(options, id: \.hex) { option in
                themeSwatchButton(option: option, dotSize: dotSize, rowHeight: rowHeight)
            }
        }
    }

    func themeSwatchButton(
        option: (hex: String, label: String),
        dotSize: CGFloat,
        rowHeight: CGFloat
    ) -> some View {
        let isSelected = draft.normalizedThemeHex.uppercased() == option.hex.uppercased()
        return Button {
            withAnimation(GoMotion.selection) {
                draft.themeColorHex = option.hex
                draft.hasExplicitThemeColor = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: option.hex))
                    .frame(width: dotSize, height: dotSize) // a11y: visual swatch is intentionally smaller; button row keeps the hit area.
                    .overlay {
                        Circle()
                            .strokeBorder(isSelected ? cardForeground.opacity(0.76) : Color.goCardWhite.opacity(0.18), lineWidth: isSelected ? 2 : 1)
                    }
                if isSelected {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: dotSize < 28 ? 10 : 12, weight: .black))
                        .foregroundStyle(WalletPetCardTheme.prefersDarkForeground(for: option.hex) ? Color.arkInk : Color.goCardWhite)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(option.label)
    }

    var humanCompactThemeOptions: [(hex: String, label: String)] {
        let options = AddWizardThemePalette.memberOptions
        let compactHexes = [
            "FFFFFF", "F2F2F7", "6B7280", "111827", "F97316", "F59E0B",
            "84CC16", "06B6D4", "60A5FA", "2563EB", "4F46E5", "7C3AED",
            "F472B6", "DB2777", "DC2626", "A5F3FC", "DDD6FE", "D9F99D"
        ]
        var compactOptions = compactHexes.compactMap { hex in
            options.first { $0.hex.uppercased() == hex }
        }
        let selectedHex = draft.normalizedThemeHex.uppercased()
        if !compactOptions.contains(where: { $0.hex.uppercased() == selectedHex }),
           let selectedOption = options.first(where: { $0.hex.uppercased() == selectedHex }) {
            compactOptions = Array(compactOptions.prefix(17)) + [selectedOption]
        }
        return compactOptions
    }

    var privacyToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(l.tr(zh: "体重隐私", en: "Private weight", de: "Gewicht privat"), isOn: $draft.privateWeight)
            Toggle(l.tr(zh: "运动隐私", en: "Private workouts", de: "Training privat"), isOn: $draft.privateWorkout)
            Toggle(l.tr(zh: "用药隐私", en: "Private medication", de: "Medikation privat"), isOn: $draft.privateMedication)
            Toggle(l.tr(zh: "愿望隐私", en: "Private wishlist", de: "Wunschliste privat"), isOn: $draft.privateWishlist)
            Toggle(l.tr(zh: "消费隐私", en: "Private expenses", de: "Ausgaben privat"), isOn: $draft.privateExpense)
        }
        .font(OhanaFont.caption(.bold))
        .foregroundStyle(cardForeground)
        .tint(Color.goPrimary)
    }

    var birthdayRange: ClosedRange<Date> {
        let end = Date()
        let start = Calendar.current.date(byAdding: .year, value: -120, to: end) ?? end
        return start ... end
    }

    var avatarCandidates: [Avatar2DCandidate] {
        Avatar2DCandidateProvider.candidates(for: draft, l: l)
    }

    var avatarRefreshSignature: String {
        [
            draft.kind.rawValue,
            draft.resolvedSpecies,
            draft.resolvedBreed,
            draft.petGender,
            draft.coatColor,
            draft.humanGender,
            "\(draft.hasBirthday)",
            "\(draft.birthday.timeIntervalSince1970.rounded())"
        ].joined(separator: "|")
    }

    var cardSubtitle: String {
        switch kind {
        case .pet:
            [
                draft.resolvedSpecies.isEmpty ? "" : speciesLabel(draft.resolvedSpecies),
                draft.resolvedBreed.isEmpty ? "" : breedLabel(draft.resolvedBreed),
                draft.petGender.isEmpty ? "" : petGenderLabel(draft.petGender)
            ]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        case .human:
            [humanGenderLabel(draft.humanGender), draft.mbti.uppercased()]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
    }

    var avatarStatusText: String {
        ""
    }

    var petFallbackSymbol: String {
        Pet.speciesSilhouetteSymbol(forSpecies: draft.resolvedSpecies)
    }

    var speciesOptions: [String] {
        Pet.canonicalSpeciesOptions
    }

    var petGenderOptions: [String] {
        ["boy", "girl"]
    }

    var humanGenderOptions: [String] {
        HumanProfileOptions.genderOptions.map(\.key)
    }

    var humanRoleOptions: [String] {
        ["owner", "member"]
    }

    var bloodTypes: [String] {
        ["", "A", "B", "AB", "O"]
    }

    var petBreedOptions: [BreedInfo] {
        PetBreedDatabase.breeds(for: draft.resolvedSpecies)
    }

    var petBreedPickerOptions: [BreedInfo] {
        let options = petBreedOptions
        guard options.count > 40,
              let other = options.first(where: { $0.name == "其他" }) else {
            return options
        }
        return Array(options.filter { $0.name != "其他" }.prefix(39)) + [other]
    }

    var petCoatOptions: [String] {
        let options = PetAvatarAssetCatalog.coatColors(species: draft.resolvedSpecies, breed: draft.resolvedBreed)
            ?? petBreedOptions.first(where: { $0.name == draft.resolvedBreed })?.coatColors
            ?? PetBreedDatabase.genericCoatColors
        return options.map(\.name)
    }

    var petThemeSelectionDescription: String {
        if draft.hasExplicitThemeColor {
            return l.tr(zh: "已手动选择", en: "Chosen manually", de: "Manuell gewählt")
        }
        if draft.coatColor.isEmpty {
            return l.tr(zh: "已自动分配", en: "Assigned automatically", de: "Automatisch gewählt")
        }
        return l.tr(
            zh: "已按毛色自动搭配",
            en: "Matched automatically to the coat",
            de: "Automatisch passend zum Fell"
        )
    }
}
