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
            title: l.tr(zh: "必要信息", en: "Essentials", de: "Wichtiges"),
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

    var petBasicInfoStep: some View {
        MemberCreationSection(
            title: l.tr(zh: "必要信息", en: "Essentials", de: "Wichtiges"),
            icon: "pawprint.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    compactNameInput(width: 148)
                    compactGenderIconRow(
                        options: petGenderOptions,
                        selection: $draft.petGender,
                        label: petGenderLabel,
                        icon: petGenderIcon
                    )
                }
                HStack(spacing: 10) {
                    compactMenuPicker(
                        title: l.tr(zh: "物种", en: "Species", de: "Art"),
                        value: speciesLabel(draft.species)
                    ) {
                        ForEach(speciesOptions, id: \.self) { species in
                            Button(speciesLabel(species)) {
                                draft.species = species
                                draft.breed = ""
                                draft.customBreed = ""
                                draft.isCustomBreed = false
                                clampPetAppearance()
                            }
                        }
                    }
                    compactBreedPicker
                }
                if draft.isCustomBreed {
                    flatTextField(l.tr(zh: "自定义品种", en: "Custom breed", de: "Eigene Rasse"), text: $draft.customBreed) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                }
                VStack(alignment: .leading, spacing: 7) {
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
                    MemberCompactDateRow(
                        title: l.tr(zh: "到家日", en: "Home date", de: "Einzugstag"),
                        icon: "house.fill",
                        isEnabled: $draft.hasHomeDate,
                        date: $draft.homeDate,
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
    }

    var compactBreedPicker: some View {
        compactMenuPicker(
            title: l.tr(zh: "品种", en: "Breed", de: "Rasse"),
            value: draft.resolvedBreed.isEmpty ? l.tr(zh: "选择", en: "Choose", de: "Wählen") : draft.resolvedBreed
        ) {
            ForEach(petBreedOptions.prefix(40), id: \.name) { breed in
                Button(breed.name) {
                    draft.isCustomBreed = breed.name == "其他"
                    draft.breed = breed.name == "其他" ? "" : breed.name
                    clampPetAppearance()
                }
            }
        }
    }

    var petProfileSection: some View {
        MemberCreationSection(
            title: l.tr(zh: "毛色与性格", en: "Coat & vibe", de: "Fell & Charakter"),
            icon: "list.bullet.clipboard.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                compactMenuPicker(
                    title: l.tr(zh: "毛色", en: "Coat", de: "Fell"),
                    value: draft.coatColor.isEmpty ? l.tr(zh: "自动", en: "Auto", de: "Auto") : draft.coatColor
                ) {
                    ForEach(petCoatOptions, id: \.self) { option in
                        Button(option) {
                            draft.coatColor = option
                            clampPetAppearance()
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 7)], spacing: 7) {
                    ForEach(Array(PetPersonalityTag.allTags.prefix(8).map(\.id)), id: \.self) { id in
                        let isSelected = draft.personalityTagIds.contains(id)
                        Button {
                            withAnimation(GoMotion.selection) {
                                if draft.personalityTagIds.contains(id) {
                                    draft.personalityTagIds.removeAll { $0 == id }
                                } else {
                                    if draft.personalityTagIds.count >= 3 {
                                        draft.personalityTagIds.removeFirst()
                                    }
                                    draft.personalityTagIds.append(id)
                                }
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text(personalityLabel(id))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(isSelected ? cardSelectedFill : cardControlFill, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(cardControlStroke, lineWidth: 1)
                                }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
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
        let isOn = draft.avatarSource == .avatar2D
        return Button {
            toggle2DAvatar()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "wand.and.stars").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                Text("2.5D")
                    .font(OhanaFont.caption(.black))
                Circle()
                    .fill(isOn ? cardSelectedForeground : cardForeground)
                    .frame(width: 8, height: 8) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .foregroundStyle(isOn ? cardSelectedForeground : cardForeground)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isOn ? cardSelectedFill : cardControlFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(cardControlStroke, lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "2.5D 头像开关", en: "2.5D avatar switch", de: "2,5D-Avatar-Schalter"))
    }

    var avatarHintText: String? {
        if draft.avatarSource == .avatar2D {
            return canUseFree2D
                ? l.tr(zh: "已使用首位免费智能 2.5D。", en: "Using the first free smart 2.5D avatar.", de: "Der erste kostenlose smarte 2,5D-Avatar ist aktiv.")
                : l.tr(zh: "保存时将消耗 1 张头像券。", en: "Saving will use 1 avatar pass.", de: "Beim Speichern wird 1 Avatarpass verwendet.")
        }
        if !canUseFree2D, avatarPassCount > 0 {
            return l.tr(zh: "你有 \(avatarPassCount) 张头像券，可手动开启 2.5D。", en: "You have \(avatarPassCount) avatar pass; turn on 2.5D when you want it.", de: "Du hast \(avatarPassCount) Avatarpass; aktiviere 2,5D bei Bedarf.")
        }
        if !canUseFree2D {
            return l.tr(zh: "2.5D 头像券 \(avatarPassCost) 椰子。", en: "A 2.5D avatar pass costs \(avatarPassCost) coconuts.", de: "Ein 2,5D-Avatarpass kostet \(avatarPassCost) Kokosnüsse.")
        }
        return nil
    }

    var petVibeSection: some View {
        MemberCreationSection(
            title: l.tr(zh: "性格", en: "Vibe", de: "Charakter"),
            icon: "heart.fill",
            foreground: cardForeground
        ) {
            VStack(alignment: .leading, spacing: 12) {
                compactTogglePill(
                    title: l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert"),
                    icon: "checkmark.seal.fill",
                    isOn: $draft.isNeutered
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 7)], spacing: 7) {
                    ForEach(Array(PetPersonalityTag.allTags.prefix(8).map(\.id)), id: \.self) { id in
                        let isSelected = draft.personalityTagIds.contains(id)
                        Button {
                            withAnimation(GoMotion.selection) {
                                if draft.personalityTagIds.contains(id) {
                                    draft.personalityTagIds.removeAll { $0 == id }
                                } else {
                                    if draft.personalityTagIds.count >= 3 {
                                        draft.personalityTagIds.removeFirst()
                                    }
                                    draft.personalityTagIds.append(id)
                                }
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Text(personalityLabel(id))
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(isSelected ? cardSelectedForeground : cardForeground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(isSelected ? cardSelectedFill : cardControlFill, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .strokeBorder(cardControlStroke, lineWidth: 1)
                                }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
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
            draft.species,
            draft.resolvedBreed,
            draft.petGender,
            draft.coatColor,
            draft.eyeColor,
            draft.humanGender,
            "\(draft.hasBirthday)",
            "\(draft.birthday.timeIntervalSince1970.rounded())"
        ].joined(separator: "|")
    }

    var cardSubtitle: String {
        switch kind {
        case .pet:
            [speciesLabel(draft.species), draft.resolvedBreed, draft.petGender == "unknown" ? "" : petGenderLabel(draft.petGender)]
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
        Pet.speciesSilhouetteSymbol(forSpecies: draft.species)
    }

    var speciesOptions: [String] {
        Pet.canonicalSpeciesOptions
    }

    var petGenderOptions: [String] {
        ["unknown", "boy", "girl"]
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
        PetBreedDatabase.breeds(for: draft.species)
    }

    var petCoatOptions: [String] {
        let options = PetAvatarAssetCatalog.coatColors(species: draft.species, breed: draft.resolvedBreed)
            ?? PetBreedDatabase.genericCoatColors
        return options.map(\.name)
    }

    var petEyeOptions: [String] {
        let options = PetAvatarAssetCatalog.eyeColors(species: draft.species, breed: draft.resolvedBreed, coatColor: draft.coatColor)
            ?? PetBreedDatabase.genericEyeColors
        return options.map(\.name)
    }

    var personalitySelection: Binding<String> {
        Binding(
            get: { draft.personalityTagIds.first ?? "" },
            set: { id in
                if draft.personalityTagIds.contains(id) {
                    draft.personalityTagIds.removeAll { $0 == id }
                } else {
                    if draft.personalityTagIds.count >= 3 {
                        draft.personalityTagIds.removeFirst()
                    }
                    draft.personalityTagIds.append(id)
                }
            }
        )
    }
}
