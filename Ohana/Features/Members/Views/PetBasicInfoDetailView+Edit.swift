//
//  PetBasicInfoDetailView+Edit.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

extension PetBasicInfoDetailView {
    var editContent: some View {
        VStack(spacing: 14) {
            // 基本信息
            editSection(title: l.tr(zh: "基本信息", en: "Basic info", de: "Basisdaten"), icon: "pawprint.fill", iconColor: Color.goPrimary) {
                editField(l.tr(zh: "名字", en: "Name", de: "Name"), text: $eName, identifier: "pet-basic-info-name-input")
                Divider().opacity(0.1)
                // 物种
                HStack {
                    editLabel(l.tr(zh: "物种", en: "Species", de: "Art"))
                    Spacer()
                    Picker("", selection: $eSpecies) {
                        ForEach(speciesOptions, id: \.self) { species in
                            Text(Pet.localizedSpeciesName(species, l: l)).tag(species)
                        }
                    }.pickerStyle(.menu).tint(Color.goPrimary)
                        .onChange(of: eSpecies) { _, _ in
                            let firstBreed = PetBreedDatabase.breeds(for: eSpecies).first
                            eBreed = firstBreed?.name ?? ""
                            eCoatColor = firstBreed?.coatColors.first?.name ?? ""
                            eEyeColor = firstBreed?.eyeColors.first?.name ?? ""
                            if let hex = firstBreed?.suggestedThemeHex { eThemeColorHex = hex }
                        }
                }
                Divider().opacity(0.1)
                optionPickerRow(l.tr(zh: "品种", en: "Breed", de: "Rasse"), selection: $eBreed, options: breedOptions)
                Divider().opacity(0.1)
                // 性别
                HStack {
                    editLabel(l.tr(zh: "性别", en: "Gender", de: "Geschlecht"))
                    Spacer()
                    Picker("", selection: $eGender) {
                        Text(l.tr(zh: "♂ 男孩", en: "♂ Boy", de: "♂ Junge")).tag("male")
                        Text(l.tr(zh: "♀ 女孩", en: "♀ Girl", de: "♀ Maedchen")).tag("female")
                        Text(l.tr(zh: "未知", en: "Unknown", de: "Unbekannt")).tag("unknown")
                    }.pickerStyle(.segmented).frame(maxWidth: 160)
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eIsNeutered) {
                    editLabel(l.tr(zh: "已绝育", en: "Neutered", de: "Kastriert"))
                }.tint(Color.goPrimary)
                Divider().opacity(0.1)
                Toggle(isOn: $eHasBirthday) {
                    editLabel(l.tr(zh: "设置生日", en: "Set birthday", de: "Geburtstag festlegen"))
                }.tint(Color.goPrimary)
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eHasHomeDate) {
                    editLabel(l.tr(zh: "设置到家日", en: "Set home date", de: "Einzugstag festlegen"))
                }.tint(Color.goPrimary)
                if eHasHomeDate {
                    DatePicker("", selection: $eHomeDate, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                }
            }
            // 外貌
            editSection(title: l.tr(zh: "外貌特征", en: "Appearance", de: "Aussehen"), icon: "eye.fill", iconColor: Color.goCardCyan) {
                colorOptionGrid(title: l.tr(zh: "毛色", en: "Coat color", de: "Fellfarbe"), selection: $eCoatColor, items: coatOptions)
                Divider().opacity(0.1)
                colorOptionGrid(title: l.tr(zh: "眼色", en: "Eye color", de: "Augenfarbe"), selection: $eEyeColor, items: eyeOptions)
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
                }.tint(Color.goYellow)
                if eHasPassportExpiry {
                    DatePicker("", selection: $ePassportExpiry, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goYellow).labelsHidden()
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
                    .tint(Color.goOrange)
                    .lineLimit(3 ... 6)
                    .accessibilityIdentifier("pet-basic-info-notes-input")
            }
        }
    }

    // MARK: - Avatar Section
    var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    profileAvatarImage(
                        data: isEditing ? eAvatarImageData : nil,
                        fallbackEmoji: pet.avatarEmoji,
                        accent: isEditing ? Color(hex: eThemeColorHex) : Color(hex: pet.safeThemeColorHex),
                        size: 84
                    )
                    VStack(spacing: 4) {
                        Text(isEditing ? (eName.isEmpty ? pet.name : eName) : pet.name)
                            .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .accessibilityIdentifier("pet-basic-info-name-readback")
                        Text(Pet.localizedSpeciesBreedSummary(
                            species: isEditing ? eSpecies : pet.species,
                            breed: isEditing ? eBreed : pet.breed,
                            l: l
                        ))
                            .font(OhanaFont.adaptive(size: 13, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity)

                if isEditing {
                    Text(l.tr(zh: "编辑中", en: "Editing", de: "Bearbeitung"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.goPrimary.opacity(0.15), in: Capsule())
                }
            }

            if isEditing {
                EditableProfileAvatarPicker(
                    avatarImageData: $eAvatarImageData,
                    fallbackEmoji: pet.avatarEmoji,
                    accentColor: Color(hex: eThemeColorHex),
                    cropSpecies: eSpecies,
                    silhouetteSystemName: nil
                )
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon).font(OhanaFont.adaptive(size: 13, weight: .bold)).foregroundStyle(iconColor) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(16).goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    func editSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(OhanaFont.adaptive(size: 13, weight: .bold)).foregroundStyle(iconColor) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title).font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            content()
        }
        .padding(16).goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    func infoRow(label: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                infoRowLabel(label)
                    .frame(minWidth: 72, maxWidth: 128, alignment: .leading)
                infoRowValue(value, alignment: .trailing, textAlignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                infoRowLabel(label)
                infoRowValue(value, alignment: .leading, textAlignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
            .tint(Color.goPrimary)
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

    var eyeOptions: [(name: String, hex: String)] {
        let options = PetBreedDatabase.refinedEyeColors(breed: selectedBreedInfo, coatColor: eCoatColor)
        return uniqueColorOptions(options.map { ($0.name, $0.hex) }, current: eEyeColor)
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
            .tint(Color.goPrimary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        } stackedContent: {
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.isEmpty ? petProfileEmptyValue : option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.goPrimary)
        }
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
                        .foregroundStyle(selection.wrappedValue == item.name ? Color.arkInk : .primary.opacity(0.82))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(selection.wrappedValue == item.name ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Vet Visit Summary
}
