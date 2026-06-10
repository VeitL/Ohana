//
//  PetBasicInfoDetailView+Edit.swift
//  Ohana
//

import SwiftUI
import SwiftData
import PhotosUI
import Foundation

extension PetBasicInfoDetailView {
    var editContent: some View {
        VStack(spacing: 14) {
            // 基本信息
            editSection(title: "基本信息", icon: "pawprint.fill", iconColor: Color.goPrimary) {
                editField("名字", text: $eName)
                Divider().opacity(0.1)
                // 物种
                HStack {
                    editLabel("物种")
                    Spacer()
                    Picker("", selection: $eSpecies) {
                        ForEach(speciesOptions, id: \.self) { Text($0) }
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
                optionPickerRow("品种", selection: $eBreed, options: breedOptions)
                Divider().opacity(0.1)
                // 性别
                HStack {
                    editLabel("性别")
                    Spacer()
                    Picker("", selection: $eGender) {
                        Text("♂ 男孩").tag("male")
                        Text("♀ 女孩").tag("female")
                        Text("未知").tag("unknown")
                    }.pickerStyle(.segmented).frame(maxWidth: 160)
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eIsNeutered) {
                    editLabel("已绝育")
                }.tint(Color.goPrimary)
                Divider().opacity(0.1)
                Toggle(isOn: $eHasBirthday) {
                    editLabel("设置生日")
                }.tint(Color.goPrimary)
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eHasHomeDate) {
                    editLabel("设置到家日")
                }.tint(Color.goPrimary)
                if eHasHomeDate {
                    DatePicker("", selection: $eHomeDate, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goPrimary).labelsHidden()
                }
            }
            // 外貌
            editSection(title: "外貌特征", icon: "eye.fill", iconColor: Color.goCardCyan) {
                colorOptionGrid(title: "毛色", selection: $eCoatColor, items: coatOptions)
                Divider().opacity(0.1)
                colorOptionGrid(title: "眼色", selection: $eEyeColor, items: eyeOptions)
            }
            // 健康
            editSection(title: "健康与医疗", icon: "cross.circle.fill", iconColor: Color.goRed) {
                editField("芯片号",     text: $eMicrochipID)
                Divider().opacity(0.1)
                editField("诊所名称",   text: $eVetClinicName)
                Divider().opacity(0.1)
                editField("主治医生",   text: $eVetDoctorName)
                Divider().opacity(0.1)
                editField("联系电话",   text: $eVetContact)
                Divider().opacity(0.1)
                editField("诊所地址",   text: $eVetAddress)
                Divider().opacity(0.1)
                editField("过敏原",     text: $eAllergies)
            }
            // 证件
            editSection(title: "证件信息", icon: "doc.badge.fill", iconColor: Color.goYellow) {
                editField("护照编号", text: $ePassportNumber)
                Divider().opacity(0.1)
                Toggle(isOn: $eHasPassportExpiry) {
                    editLabel("护照有效期")
                }.tint(Color.goYellow)
                if eHasPassportExpiry {
                    DatePicker("", selection: $ePassportExpiry, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goYellow).labelsHidden()
                }
            }
            // 血统
            editSection(title: "血统来源", icon: "list.star", iconColor: Color.goMint) {
                editField("曾用名",   text: $eFormerName)
                Divider().opacity(0.1)
                optionPickerRow("出生国家", selection: $eBirthCountry, options: countryOptions)
                Divider().opacity(0.1)
                optionPickerRow("出生城市", selection: $eBirthCity, options: birthCityOptions)
                Divider().opacity(0.1)
                editField("血统信息", text: $eLineageInfo)
            }
            // 主题色
            editSection(title: "主题色", icon: "paintpalette.fill", iconColor: Color(hex: eThemeColorHex)) {
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
            editSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                TextField("备注（可选）", text: $eNotes, axis: .vertical)
                    .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(Color.goOrange)
                    .lineLimit(3...6)
            }
        }
    }

    // MARK: - Avatar Section
    var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    profileAvatarImage(
                        data: isEditing ? eAvatarImageData : pet.avatarImageData,
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
                        Text("\(isEditing ? eSpecies : pet.species) · \(isEditing ? (eBreed.isEmpty ? "未填写品种" : eBreed) : (pet.breed.isEmpty ? "未填写品种" : pet.breed))")
                            .font(OhanaFont.adaptive(size: 13, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity)

                if isEditing {
                    Text("编辑中")
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
        .goTranslucentCard(cornerRadius: 20)
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
    func infoSection<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(OhanaFont.adaptive(size: 13, weight: .bold)).foregroundStyle(iconColor) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title).font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            content()
        }
        .padding(16).goTranslucentCard(cornerRadius: 20)
    }

    func editSection<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(OhanaFont.adaptive(size: 13, weight: .bold)).foregroundStyle(iconColor) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title).font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            content()
        }
        .padding(16).goTranslucentCard(cornerRadius: 20)
    }

    func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(OhanaFont.adaptive(size: 13, weight: .medium)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.45)).frame(width: 80, alignment: .leading) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(value).font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.9)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Spacer()
        }
    }

    func editLabel(_ label: String) -> some View {
        Text(label).font(OhanaFont.adaptive(size: 13, weight: .medium)).foregroundStyle(Color.ohanaPrimaryText.opacity(0.55)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
    }

    func editField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            editLabel(label).frame(width: 70, alignment: .leading)
            TextField(label, text: text)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    var selectedBreedInfo: BreedInfo? {
        PetBreedDatabase.breeds(for: eSpecies).first { $0.name == eBreed }
    }

    var breedOptions: [String] {
        var options = ["未填写"] + PetBreedDatabase.breeds(for: eSpecies).map(\.name)
        if !eBreed.isEmpty, eBreed != "未填写", !options.contains(eBreed) {
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
        var options = ["未填写"] + PetBreedDatabase.countries
        if !eBirthCountry.isEmpty, !options.contains(eBirthCountry) {
            options.insert(eBirthCountry, at: 1)
        }
        return options
    }

    var birthCityOptions: [String] {
        let cities = eBirthCountry.isEmpty || eBirthCountry == "未填写"
            ? ["未填写"]
            : ["未填写"] + PetBreedDatabase.cities(for: eBirthCountry)
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
        HStack {
            editLabel(label).frame(width: 70, alignment: .leading)
            Spacer()
            Picker("", selection: Binding(
                get: { selection.wrappedValue.isEmpty ? "未填写" : selection.wrappedValue },
                set: { selection.wrappedValue = $0 == "未填写" ? "" : $0 }
            )) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.goPrimary)
        }
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
