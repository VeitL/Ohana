//
//  PetBasicInfoDetailView+Edit.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

extension PetBasicInfoDetailView {
    var profileEditAccent: Color {
        guard profileExperienceStyle == .zen else { return Color.goPrimary }
        let value = eThemeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? Color.goPrimary : Color(hex: value)
    }

    var profileEditAccentForeground: Color {
        guard profileExperienceStyle == .zen else { return Color.arkInk }
        let value = eThemeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = value.isEmpty ? "C8F34A" : value
        return WalletPetCardTheme.prefersDarkForeground(for: hex)
            ? Color.arkInk
            : Color.goCardWhite
    }

    var editContent: some View {
        Form {
            Section {
                EditableProfileAvatarPicker(
                    avatarImageData: $eAvatarImageData,
                    fallbackEmoji: pet.avatarEmoji,
                    accentColor: Color(hex: eThemeColorHex),
                    cropSpecies: eSpecies,
                    silhouetteSystemName: nil
                )
            } header: {
                Label(l.tr(zh: "头像", en: "Photo", de: "Foto"), systemImage: "photo")
            }

            // 基本信息
            editSection(title: l.tr(zh: "基本信息", en: "Basic info", de: "Basisdaten"), icon: "pawprint.fill", iconColor: Color.goPrimary) {
                editField(l.tr(zh: "名字", en: "Name", de: "Name"), text: $eName, identifier: "pet-basic-info-name-input")
                Divider().opacity(0.1)
                // 物种
                HStack {
                    editLabel(l.tr(zh: "物种", en: "Species", de: "Art"))
                    Spacer()
                    Picker("", selection: speciesSelection) {
                        ForEach(speciesOptions, id: \.self) { species in
                            Text(Pet.localizedSpeciesName(species, l: l)).tag(species)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(profileEditAccent)
                }
                Divider().opacity(0.1)
                optionPickerRow(l.tr(zh: "品种", en: "Breed", de: "Rasse"), selection: $eBreed, options: breedOptions)
                Divider().opacity(0.1)
                primaryPersonalityPickerRow
                Divider().opacity(0.1)
                // 性别
                HStack {
                    editLabel(l.tr(zh: "性别", en: "Gender", de: "Geschlecht"))
                    Spacer()
                    Picker("", selection: $eGender) {
                        Text(l.tr(zh: "♂ 男孩", en: "♂ Boy", de: "♂ Junge")).tag("boy")
                        Text(l.tr(zh: "♀ 女孩", en: "♀ Girl", de: "♀ Maedchen")).tag("girl")
                    }.pickerStyle(.segmented).frame(maxWidth: 160)
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eIsNeutered) {
                    editLabel(l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert"))
                }.tint(profileEditAccent)
                Divider().opacity(0.1)
                Toggle(isOn: $eHasBirthday) {
                    editLabel(l.tr(zh: "设置生日", en: "Set birthday", de: "Geburtstag festlegen"))
                }
                .tint(profileEditAccent)
                .accessibilityIdentifier("pet-basic-info-birthday-toggle")
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact).tint(profileEditAccent).labelsHidden()
                        .accessibilityIdentifier("pet-basic-info-birthday-date-picker")
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eHasHomeDate) {
                    editLabel(l.tr(zh: "设置到家日", en: "Set home date", de: "Einzugstag festlegen"))
                }
                .tint(profileEditAccent)
                .accessibilityIdentifier("pet-basic-info-home-date-toggle")
                if eHasHomeDate {
                    DatePicker("", selection: $eHomeDate, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(profileEditAccent).labelsHidden()
                        .accessibilityIdentifier("pet-basic-info-home-date-picker")
                }
            }
            // 外貌
            editSection(title: l.tr(zh: "外貌特征", en: "Appearance", de: "Aussehen"), icon: "paintpalette.fill", iconColor: Color.goCardCyan) {
                colorOptionGrid(title: l.tr(zh: "毛色", en: "Coat color", de: "Fellfarbe"), selection: $eCoatColor, items: coatOptions)
            }
            // 健康
            editSection(title: l.tr(zh: "健康与医疗", en: "Health & medical", de: "Gesundheit & Medizin"), icon: "cross.circle.fill", iconColor: Color.goRed) {
                editField(l.tr(zh: "芯片号", en: "Microchip", de: "Mikrochip"), text: $eMicrochipID, identifier: "pet-basic-info-microchip-input")
                Divider().opacity(0.1)
                editField(l.tr(zh: "诊所名称", en: "Clinic", de: "Praxis"), text: $eVetClinicName, identifier: "pet-basic-info-vet-clinic-input")
                Divider().opacity(0.1)
                editField(l.tr(zh: "主治医生", en: "Doctor", de: "Tierarzt"), text: $eVetDoctorName, identifier: "pet-basic-info-vet-doctor-input")
                Divider().opacity(0.1)
                editField(l.tr(zh: "联系电话", en: "Phone", de: "Telefon"), text: $eVetContact, identifier: "pet-basic-info-vet-contact-input")
                Divider().opacity(0.1)
                editField(l.tr(zh: "诊所地址", en: "Clinic address", de: "Praxisadresse"), text: $eVetAddress, identifier: "pet-basic-info-vet-address-input")
                Divider().opacity(0.1)
                editField(l.tr(zh: "过敏原", en: "Allergies", de: "Allergien"), text: $eAllergies, identifier: "pet-basic-info-allergies-input")
            }
            // 证件
            editSection(title: l.tr(zh: "证件信息", en: "Documents", de: "Dokumente"), icon: "doc.badge.fill", iconColor: Color.goYellow) {
                editField(l.tr(zh: "护照编号", en: "Passport number", de: "Passnummer"), text: $ePassportNumber, identifier: "pet-basic-info-passport-input")
                Divider().opacity(0.1)
                Toggle(isOn: $eHasPassportExpiry) {
                    editLabel(l.tr(zh: "护照有效期", en: "Passport expiry", de: "Pass gueltig bis"))
                }.tint(profileExperienceStyle == .zen ? profileEditAccent : Color.goYellow)
                if eHasPassportExpiry {
                    DatePicker("", selection: $ePassportExpiry, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(profileExperienceStyle == .zen ? profileEditAccent : Color.goYellow).labelsHidden()
                }
            }
            // 血统
            editSection(title: l.tr(zh: "血统来源", en: "Lineage", de: "Herkunft"), icon: "list.star", iconColor: Color.goMint) {
                editField(l.tr(zh: "曾用名", en: "Former name", de: "Frueherer Name"), text: $eFormerName, identifier: "pet-basic-info-former-name-input")
                Divider().opacity(0.1)
                optionPickerRow(l.tr(zh: "出生国家", en: "Birth country", de: "Geburtsland"), selection: $eBirthCountry, options: countryOptions)
                Divider().opacity(0.1)
                optionPickerRow(l.tr(zh: "出生城市", en: "Birth city", de: "Geburtsstadt"), selection: $eBirthCity, options: birthCityOptions)
                Divider().opacity(0.1)
                editField(l.tr(zh: "血统信息", en: "Lineage info", de: "Abstammungsinfo"), text: $eLineageInfo, identifier: "pet-basic-info-lineage-input")
            }
            // 主题色
            editSection(title: l.tr(zh: "主题色", en: "Accent color", de: "Akzentfarbe"), icon: "paintpalette.fill", iconColor: Color(hex: eThemeColorHex)) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                    ForEach(themePresets, id: \.0) { hex, _ in
                        Button { eThemeColorHex = hex } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex)).frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                if eThemeColorHex.uppercased() == hex.uppercased() {
                                    Circle().strokeBorder(Color.ohanaCardSurface, lineWidth: 2.5)
                                    Image(systemName: "checkmark").font(OhanaFont.adaptive(size: 11, weight: .black)).foregroundStyle(Color.ohanaPrimaryText) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                }
                            }
                        }.buttonStyle(ScaleButtonStyle())
                    }
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: eThemeColorHex) },
                        set: { if let h = $0.toHex() { eThemeColorHex = h } }
                    ), supportsOpacity: false)
                        .labelsHidden().frame(width: 38, height: 38).scaleEffect(1.3).clipShape(Circle()) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .overlay(Circle().strokeBorder(.primary.opacity(0.3), lineWidth: 1))
                }
            }
            // 备注
            editSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
                TextField(l.tr(zh: "备注（可选）", en: "Notes (optional)", de: "Notizen (optional)"), text: $eNotes, axis: .vertical) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(profileExperienceStyle == .zen ? profileEditAccent : Color.goOrange)
                    .lineLimit(3 ... 6)
                    .accessibilityIdentifier("pet-basic-info-notes-input")
            }
        }
        .scrollContentBackground(.hidden)
        .tint(profileEditAccent)
        .background(OhanaAppBackground())
    }

    // MARK: - Avatar Section
    var avatarSection: some View {
        ProfileIdentityHero(
            name: pet.name,
            subtitle: Pet.localizedSpeciesBreedSummary(
                species: pet.species,
                breed: pet.breed,
                l: l
            ),
            themeColorHex: pet.safeThemeColorHex,
            fallbackColor: Color.goPrimary,
            statusTitle: pet.hasPassedAway
                ? l.tr(zh: "彩虹桥纪念", en: "Rainbow Bridge memorial", de: "Regenbogenbrücke")
                : nil,
            avatarAccessibilityLabel: l.tr(
                zh: "\(pet.name) 的头像",
                en: "Avatar for \(pet.name)",
                de: "Avatar von \(pet.name)"
            ),
            nameAccessibilityIdentifier: "pet-basic-info-name-readback",
            onAvatarTap: pet.hasAvatarImageAttachment ? { presentedSheet = .avatarPreview } : nil
        ) {
            PetAvatarPortraitView(
                cacheID: pet.id,
                imageSignature: pet.avatarThumbnailSignature,
                petModelID: pet.persistentModelID,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 88,
                backgroundOpacity: 0.25,
                transparentScale: 0.78
            )
        } badges: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { petProfileBadges }
                VStack(spacing: 8) { petProfileBadges }
            }
        }
    }

    @ViewBuilder
    private var petProfileBadges: some View {
        if let primaryTagID = pet.personalityTagIdList.first {
            ProfileBadge(
                title: PetPersonalityTag.displayTitle(for: primaryTagID, l: l),
                systemImage: PetPersonalityTag.lookup(primaryTagID)?.sfSymbol
            )
        }
        ProfileBadge(
            title: localizedPetDays(pet.daysTogether),
            systemImage: "calendar"
        )
    }

    func profileAvatarImage(data: Data?, fallbackEmoji: String, accent: Color, size: CGFloat) -> some View {
        PetAvatarPortraitView(
            imageData: data,
            fallbackText: fallbackEmoji,
            themeColor: accent,
            size: size,
            backgroundOpacity: 0.25,
            transparentScale: 0.78
        )
    }

    // MARK: - Helpers
    func infoSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        ProfileInfoSection(title: title, systemImage: icon, tint: iconColor, content: content)
    }

    func editSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Label(title, systemImage: icon)
                .foregroundStyle(profileExperienceStyle == .zen ? profileEditAccent : iconColor)
        }
    }

    func infoRow(label: String, value: String) -> some View {
        ProfileInfoRow(label: label, value: value)
    }

    func infoRowLabel(_ label: String) -> some View {
        Text(label)
            .font(OhanaFont.adaptive(size: 13, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.48))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    func infoRowValue(_ value: String, alignment: Alignment, textAlignment: TextAlignment) -> some View {
        Text(value)
            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.9))
            .multilineTextAlignment(textAlignment)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    func editLabel(_ label: String) -> some View {
        Text(label).font(OhanaFont.adaptive(size: 13, weight: .medium)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.55)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    func editField(_ label: String, text: Binding<String>, identifier: String? = nil) -> some View {
        petProfileEditableRow(label) {
            editTextField(label, text: text, identifier: identifier)
        } stackedContent: {
            editTextField(label, text: text, identifier: identifier)
                .multilineTextAlignment(.leading)
        }
    }

    func petProfileEditableRow(
        _ label: String,
        @ViewBuilder horizontalContent: () -> some View,
        @ViewBuilder stackedContent: () -> some View
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                editLabel(label)
                    .frame(minWidth: 72, alignment: .leading)
                horizontalContent()
            }
            VStack(alignment: .leading, spacing: 8) {
                editLabel(label)
                stackedContent()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    func editTextField(_ label: String, text: Binding<String>, identifier: String? = nil) -> some View {
        TextField(label, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryText)
            .tint(profileEditAccent)
            .multilineTextAlignment(.trailing)
            .accessibilityIdentifier(identifier ?? editFieldIdentifier(for: label))
    }

    func editFieldIdentifier(for label: String) -> String {
        let slug = label
            .lowercased()
            .unicodeScalars
            .map { scalar -> Character in
                let value = scalar.value
                return ((48 ... 57).contains(value) || (97 ... 122).contains(value)) ? Character(scalar) : "-"
            }
            .reduce(into: "") { $0.append($1) }
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? "pet-basic-info-field" : "pet-basic-info-field-\(slug)"
    }

    var selectedBreedInfo: BreedInfo? {
        PetBreedDatabase.breeds(for: eSpecies).first { $0.name == eBreed }
    }

    var speciesSelection: Binding<String> {
        Binding(
            get: { eSpecies },
            set: { newSpecies in
                guard newSpecies != eSpecies else { return }
                eSpecies = newSpecies
                let firstBreed = PetBreedDatabase.breeds(for: newSpecies).first
                eBreed = firstBreed?.name ?? ""
                eCoatColor = firstBreed?.coatColors.first?.name ?? ""
                if let hex = firstBreed?.suggestedThemeHex {
                    eThemeColorHex = hex
                }
            }
        )
    }

    var breedOptions: [String] {
        var options = [""] + PetBreedDatabase.breeds(for: eSpecies).map(\.name)
        if !eBreed.isEmpty, !options.contains(eBreed) {
            options.insert(eBreed, at: 1)
        }
        return options
    }

    var coatOptions: [(name: String, hex: String)] {
        let options = PetAvatarAssetCatalog.coatColors(species: eSpecies, breed: eBreed)
            ?? selectedBreedInfo?.coatColors
            ?? PetBreedDatabase.genericCoatColors
        return uniqueColorOptions(options.map { ($0.name, $0.hex) }, current: eCoatColor)
    }

    var countryOptions: [String] {
        var options = [""] + PetBreedDatabase.countries
        if !eBirthCountry.isEmpty, !options.contains(eBirthCountry) {
            options.insert(eBirthCountry, at: 1)
        }
        return options
    }

    var birthCityOptions: [String] {
        let cities = eBirthCountry.isEmpty
            ? [""]
            : [""] + PetBreedDatabase.cities(for: eBirthCountry)
        var options = cities
        if !eBirthCity.isEmpty, !options.contains(eBirthCity) {
            options.insert(eBirthCity, at: 1)
        }
        return options
    }

    func uniqueColorOptions(_ options: [(name: String, hex: String)], current: String) -> [(name: String, hex: String)] {
        var seen: Set<String> = []
        var result = options.filter { seen.insert($0.name).inserted }
        if !current.isEmpty, !result.contains(where: { $0.name == current }) {
            result.insert((current, "BDBDBD"), at: 0)
        }
        return result
    }

    func optionPickerRow(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        petProfileEditableRow(label) {
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.isEmpty ? petProfileEmptyValue : option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(profileEditAccent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        } stackedContent: {
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.isEmpty ? petProfileEmptyValue : option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(profileEditAccent)
        }
    }

    var primaryPersonalityPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            editLabel(l.tr(zh: "主性格", en: "Primary vibe", de: "Hauptcharakter"))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 116), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(primaryPersonalityOptionIDs, id: \.self) { id in
                    let isSelected = ePrimaryPersonalityTagID == id
                    let title = PetPersonalityTag.displayTitle(for: id, l: l)

                    Button {
                        ePrimaryPersonalityTagID = id
                    } label: {
                        HStack(spacing: 6) {
                            if let tag = PetPersonalityTag.lookup(id) {
                                Image(systemName: tag.sfSymbol)
                                    .accessibilityHidden(true)
                            }
                            Text(title)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative selection glyph is hidden by the chained modifier below
                                    .accessibilityHidden(true)
                            }
                        }
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            isSelected
                                ? (profileExperienceStyle == .zen ? profileEditAccent : Color.goPrimary)
                                : Color.ohanaPrimaryText.opacity(0.82)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(
                            isSelected
                                ? (profileExperienceStyle == .zen ? profileEditAccent.opacity(0.16) : Color.goPrimary.opacity(0.16))
                                : Color.ohanaPrimaryText.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(title)
                    .accessibilityValue(
                        isSelected
                            ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt")
                            : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt")
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("pet-basic-info-primary-personality-option-\(id)")
                }
            }
        }
    }

    var primaryPersonalityOptionIDs: [String] {
        var ids = PetPersonalityTag.primaryChoices.map(\.id)
        if !ePrimaryPersonalityTagID.isEmpty,
           !ids.contains(ePrimaryPersonalityTagID) {
            ids.insert(ePrimaryPersonalityTagID, at: 0)
        }
        return ids
    }

    func localizedBreedSummary(_ breed: String) -> String {
        breed.isEmpty ? l.tr(zh: "未填写品种", en: "Breed not set", de: "Rasse nicht festgelegt") : breed
    }

    func colorOptionGrid(title: String, selection: Binding<String>, items: [(name: String, hex: String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            editLabel(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(items, id: \.name) { item in
                    Button {
                        selection.wrappedValue = item.name
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: item.hex))
                                .frame(width: 14, height: 14) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.14), lineWidth: 1))
                            Text(item.name)
                                .font(OhanaFont.adaptive(size: 12, weight: selection.wrappedValue == item.name ? .black : .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(
                            selection.wrappedValue == item.name
                                ? profileEditAccentForeground
                                : Color.ohanaPrimaryText.opacity(0.82)
                        )
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(
                            selection.wrappedValue == item.name
                                ? (profileExperienceStyle == .zen ? profileEditAccent : Color.goPrimary)
                                : Color.ohanaPrimaryText.opacity(0.07),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Vet Visit Summary
}
