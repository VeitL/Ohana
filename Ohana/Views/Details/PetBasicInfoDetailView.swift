//
//  PetBasicInfoDetailView.swift
//  Ohana
//

import SwiftUI
import SwiftData
import PhotosUI
import Foundation

struct PetBasicInfoDetailView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false

    @State private var showingRainbowBridgeAlert = false
    @State private var showingUndoPassingAlert   = false
    @State private var rainbowBridgeDate         = Date()

    // Edit state mirrors
    @State private var eName = ""
    @State private var eSpecies = ""
    @State private var eBreed = ""
    @State private var eGender = ""
    @State private var eIsNeutered = false
    @State private var eHasBirthday = false
    @State private var eBirthday = Date()
    @State private var eHasHomeDate = false
    @State private var eHomeDate = Date()
    @State private var eCoatColor = ""
    @State private var eEyeColor = ""
    @State private var eMicrochipID = ""
    @State private var eVetContact = ""      // 电话
    @State private var eVetClinicName = ""
    @State private var eVetDoctorName = ""
    @State private var eVetAddress = ""
    @State private var eAllergies = ""
    @State private var ePassportNumber = ""
    @State private var eHasPassportExpiry = false
    @State private var ePassportExpiry = Date()
    @State private var eFormerName = ""
    @State private var eBirthCountry = ""
    @State private var eBirthCity = ""
    @State private var eLineageInfo = ""
    @State private var eNotes = ""
    @State private var eThemeColorHex = ""
    @State private var eAvatarImageData: Data? = nil

    private let speciesOptions = ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]
    private let themePresets: [(String, String)] = [
        ("FF6B6B","coral"), ("4ECDC4","ocean"), ("B8A9C9","lavender"),
        ("95E1D3","mint"), ("F38181","sunset"), ("AA96DA","berry"),
        ("8EC5FC","sky"), ("A8E6CF","sage"), ("FFD3B6","peach"), ("95ADBE","slate"),
    ]

    var body: some View {
        ZStack {
            ArkBackgroundView()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    avatarSection
                    if isEditing {
                        editContent
                    } else {
                        readContent
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationTitle("\(pet.name) 的信息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        saveChanges()
                        withAnimation { isEditing = false }
                    } label: {
                        Text("保存")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                    }
                } else {
                    Button {
                        loadEditState()
                        withAnimation { isEditing = true }
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.goPrimary)
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { withAnimation { isEditing = false } }
                }
            }
        }
    }

    // MARK: - Read View
    private var readContent: some View {
        VStack(spacing: 16) {
            // 品种护理小贴士（有品种且有数据时显示）
            if !pet.breed.isEmpty, let tips = PetBreedDatabase.careTips(for: pet.breed) {
                breedTipsCard(breed: pet.breed, tips: tips)
            }

            infoSection(title: "基本信息", icon: "pawprint.fill", iconColor: Color.goPrimary) {
                infoRow(label: "名字", value: pet.name)
                infoRow(label: "物种", value: pet.species)
                infoRow(label: "品种", value: pet.breed.isEmpty ? "未填写" : pet.breed)
                infoRow(label: "性别", value: pet.genderSymbol + (pet.isNeutered ? "（已绝育）" : "（未绝育）"))
                if let birthday = pet.birthday {
                    infoRow(label: "生日", value: birthday.formatted(.dateTime.year().month().day()))
                }
                if let homeDate = pet.homeDate {
                    infoRow(label: "到家日", value: homeDate.formatted(.dateTime.year().month().day()))
                }
                infoRow(label: "相处天数", value: "\(pet.daysTogether) 天")
            }
            if !pet.coatColor.isEmpty || !pet.eyeColor.isEmpty {
                infoSection(title: "外貌特征", icon: "eye.fill", iconColor: Color.goCardCyan) {
                    if !pet.coatColor.isEmpty { infoRow(label: "毛色", value: pet.coatColor) }
                    if !pet.eyeColor.isEmpty  { infoRow(label: "眼色", value: pet.eyeColor) }
                }
            }
            infoSection(title: "健康与医疗", icon: "cross.circle.fill", iconColor: Color.goRed) {
                infoRow(label: "芯片号", value: pet.microchipID.isEmpty ? "未登记" : pet.microchipID)
                infoRow(label: "诊所名称", value: pet.vetClinicName.isEmpty ? "未填写" : pet.vetClinicName)
                infoRow(label: "主治医生", value: pet.vetDoctorName.isEmpty ? "未填写" : pet.vetDoctorName)
                infoRow(label: "联系电话", value: pet.vetContact.isEmpty   ? "未填写" : pet.vetContact)
                if !pet.vetAddress.isEmpty {
                    infoRow(label: "诊所地址", value: pet.vetAddress)
                }
                infoRow(label: "过敏原", value: pet.allergies.isEmpty ? "无记录" : pet.allergies)
            }
            vetVisitSummaryCard
            infoSection(title: "证件信息", icon: "doc.badge.fill", iconColor: Color.goYellow) {
                infoRow(label: "护照编号", value: pet.passportNumber.isEmpty ? "未填写" : pet.passportNumber)
                if let expiry = pet.passportExpiryDate {
                    infoRow(label: "护照有效期", value: expiry.formatted(.dateTime.year().month().day()))
                } else {
                    infoRow(label: "护照有效期", value: "未填写")
                }
            }
            if !pet.formerName.isEmpty || !pet.lineageInfo.isEmpty || !pet.birthCountry.isEmpty {
                infoSection(title: "血统来源", icon: "list.star", iconColor: Color.goMint) {
                    if !pet.formerName.isEmpty {
                        infoRow(label: "曾用名", value: pet.formerName)
                    }
                    if !pet.birthCountry.isEmpty {
                        infoRow(label: "出生地", value: pet.birthCountry + (pet.birthCity.isEmpty ? "" : " · \(pet.birthCity)"))
                    }
                    if !pet.lineageInfo.isEmpty {
                        infoRow(label: "血统", value: pet.lineageInfo)
                    }
                }
            }
            // 主题色预览
            infoSection(title: "主题色", icon: "paintpalette.fill", iconColor: Color(hex: pet.themeColorHex)) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: pet.themeColorHex)).frame(width: 32, height: 32)
                    Text("#\(pet.themeColorHex.uppercased())")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
                }
            }
            if !pet.notes.isEmpty {
                infoSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                    Text(pet.notes)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            rainbowBridgeSection
            deleteDangerZone
        }
    }

    // MARK: - Breed Tips Card
    @State private var breedTipsExpanded = true

    private func breedTipsCard(breed: String, tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) { breedTipsExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.goYellow)
                        .frame(width: 32, height: 32)
                        .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(breed) · 护理贴士")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("基于品种特点的个性化建议")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: breedTipsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if breedTipsExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.goYellow.opacity(0.7))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(tip)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.75))
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 16)
    }

    // MARK: - Edit View
    private var editContent: some View {
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
                                Circle().fill(Color(hex: hex)).frame(width: 38, height: 38)
                                if eThemeColorHex.uppercased() == hex.uppercased() {
                                    Circle().strokeBorder(.white, lineWidth: 2.5)
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.primary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: eThemeColorHex) },
                        set: { if let h = $0.toHex() { eThemeColorHex = h } }
                    ), supportsOpacity: false)
                    .labelsHidden().frame(width: 38, height: 38).scaleEffect(1.3).clipShape(Circle())
                    .overlay(Circle().strokeBorder(.primary.opacity(0.3), lineWidth: 1))
                }
            }
            // 备注
            editSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                TextField("备注（可选）", text: $eNotes, axis: .vertical)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .tint(Color.goOrange)
                    .lineLimit(3...6)
            }
        }
    }

    // MARK: - Avatar Section
    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    profileAvatarImage(
                        data: isEditing ? eAvatarImageData : pet.avatarImageData,
                        fallbackEmoji: pet.avatarEmoji,
                        accent: isEditing ? Color(hex: eThemeColorHex) : Color(hex: pet.themeColorHex),
                        size: 84
                    )
                    VStack(spacing: 4) {
                        Text(isEditing ? (eName.isEmpty ? pet.name : eName) : pet.name)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text("\(isEditing ? eSpecies : pet.species) · \(isEditing ? (eBreed.isEmpty ? "未填写品种" : eBreed) : (pet.breed.isEmpty ? "未填写品种" : pet.breed))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity)

                if isEditing {
                    Text("编辑中")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
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

    private func profileAvatarImage(data: Data?, fallbackEmoji: String, accent: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.25))
                .frame(width: size, height: size)
            if let data, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 8, height: size - 8, alignment: .center)
                    .clipShape(Circle())
            } else {
                Text(fallbackEmoji)
                    .font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }

    // MARK: - Helpers
    private func infoSection<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(iconColor)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            }
            content()
        }
        .padding(16).goTranslucentCard(cornerRadius: 20)
    }

    private func editSection<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(iconColor)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.primary)
            }
            content()
        }
        .padding(16).goTranslucentCard(cornerRadius: 20)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary.opacity(0.45)).frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.primary.opacity(0.9))
            Spacer()
        }
    }

    private func editLabel(_ label: String) -> some View {
        Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary.opacity(0.55))
    }

    private func editField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            editLabel(label).frame(width: 70, alignment: .leading)
            TextField(label, text: text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .tint(Color.goPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var selectedBreedInfo: BreedInfo? {
        PetBreedDatabase.breeds(for: eSpecies).first { $0.name == eBreed }
    }

    private var breedOptions: [String] {
        var options = ["未填写"] + PetBreedDatabase.breeds(for: eSpecies).map(\.name)
        if !eBreed.isEmpty, eBreed != "未填写", !options.contains(eBreed) {
            options.insert(eBreed, at: 1)
        }
        return options
    }

    private var coatOptions: [(name: String, hex: String)] {
        let options = selectedBreedInfo?.coatColors ?? PetBreedDatabase.genericCoatColors
        return uniqueColorOptions(options.map { ($0.name, $0.hex) }, current: eCoatColor)
    }

    private var eyeOptions: [(name: String, hex: String)] {
        let options = PetBreedDatabase.refinedEyeColors(breed: selectedBreedInfo, coatColor: eCoatColor)
        return uniqueColorOptions(options.map { ($0.name, $0.hex) }, current: eEyeColor)
    }

    private var countryOptions: [String] {
        var options = ["未填写"] + PetBreedDatabase.countries
        if !eBirthCountry.isEmpty, !options.contains(eBirthCountry) {
            options.insert(eBirthCountry, at: 1)
        }
        return options
    }

    private var birthCityOptions: [String] {
        let cities = eBirthCountry.isEmpty || eBirthCountry == "未填写"
            ? ["未填写"]
            : ["未填写"] + PetBreedDatabase.cities(for: eBirthCountry)
        var options = cities
        if !eBirthCity.isEmpty, !options.contains(eBirthCity) {
            options.insert(eBirthCity, at: 1)
        }
        return options
    }

    private func uniqueColorOptions(_ options: [(name: String, hex: String)], current: String) -> [(name: String, hex: String)] {
        var seen: Set<String> = []
        var result = options.filter { seen.insert($0.name).inserted }
        if !current.isEmpty, !result.contains(where: { $0.name == current }) {
            result.insert((current, "BDBDBD"), at: 0)
        }
        return result
    }

    private func optionPickerRow(_ label: String, selection: Binding<String>, options: [String]) -> some View {
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

    private func colorOptionGrid(title: String, selection: Binding<String>, items: [(name: String, hex: String)]) -> some View {
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
                                .frame(width: 14, height: 14)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.14), lineWidth: 1))
                            Text(item.name)
                                .font(.system(size: 12, weight: selection.wrappedValue == item.name ? .black : .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(selection.wrappedValue == item.name ? Color.arkInk : .primary.opacity(0.82))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(selection.wrappedValue == item.name ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Vet Visit Summary
    private var vetVisitSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.goRed)
                Text("就诊卡片")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                ShareLink(item: vetVisitSummaryText) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                        Text("给兽医")
                    }
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.goPrimary, in: Capsule())
                }
            }

            VStack(spacing: 8) {
                compactSummaryRow("疫苗", vaccineSummaryText)
                compactSummaryRow("过敏", pet.allergies.isEmpty ? "无记录" : pet.allergies)
                compactSummaryRow("用药中", activeMedicationSummaryText)
                compactSummaryRow("近期症状", recentSymptomSummaryText)
                compactSummaryRow("保险", insuranceSummaryText)
                compactSummaryRow("最近体重", recentWeightSummaryText)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private func compactSummaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.primary.opacity(0.46))
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }

    private var vaccineSummaryText: String {
        let latest = pet.healthLogs
            .filter { $0.healthLogType == .vaccine }
            .sorted { $0.date > $1.date }
            .first
        guard let latest else { return "未记录" }
        let name = latest.note.isEmpty ? "疫苗" : latest.note
        if let expiry = latest.expirationDate {
            return "\(name) · 有效至 \(expiry.formatted(.dateTime.year().month().day()))"
        }
        return "\(name) · \(latest.date.formatted(.dateTime.year().month().day()))"
    }

    private var activeMedicationSummaryText: String {
        let meds = pet.medications.filter(\.isActiveToday)
        guard !meds.isEmpty else { return "无进行中用药" }
        return meds.prefix(3)
            .map { "\($0.name.isEmpty ? "未命名药品" : $0.name)（\($0.dosage.isEmpty ? "按医嘱" : $0.dosage)）" }
            .joined(separator: "、")
    }

    private var recentSymptomSummaryText: String {
        let recent = pet.symptomLogs
            .sorted { $0.date > $1.date }
            .prefix(3)
        guard !recent.isEmpty else { return "近况无症状记录" }
        return recent
            .map { "\($0.symptomName)（\($0.severity.label)）" }
            .joined(separator: "、")
    }

    private var insuranceSummaryText: String {
        let active = pet.insurances.filter(\.isActive)
        guard let first = active.sorted(by: { $0.renewalDate < $1.renewalDate }).first else { return "未登记保险" }
        let name = first.productName.isEmpty ? (first.companyName.isEmpty ? "保险" : first.companyName) : first.productName
        return "\(name) · \(first.renewalStatusLabel)"
    }

    private var recentWeightSummaryText: String {
        guard let latest = pet.weightLogs.sorted(by: { $0.date > $1.date }).first else { return "未记录体重" }
        let value = latest.weightUnit == "g"
            ? "\(Int(latest.weight))g"
            : String(format: "%.2fkg", latest.weight)
        return "\(value) · \(latest.date.formatted(.dateTime.year().month().day()))"
    }

    private var vetVisitSummaryText: String {
        """
        \(pet.name) 就诊摘要
        物种/品种：\(pet.species) / \(pet.breed.isEmpty ? "未填写" : pet.breed)
        年龄：\(pet.ageText)
        过敏：\(pet.allergies.isEmpty ? "无记录" : pet.allergies)
        疫苗：\(vaccineSummaryText)
        用药中：\(activeMedicationSummaryText)
        近期症状：\(recentSymptomSummaryText)
        保险：\(insuranceSummaryText)
        最近体重：\(recentWeightSummaryText)
        芯片号：\(pet.microchipID.isEmpty ? "未登记" : pet.microchipID)
        """
    }

    // MARK: - Rainbow Bridge Section
    @ViewBuilder
    private var rainbowBridgeSection: some View {
        if pet.hasPassedAway {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text("🌈").font(.system(size: 14))
                    Text("岁月史书 · 彩虹桥彼端")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let d = pet.passedAwayDate {
                            Text("离世日期：\(d.formatted(.dateTime.year().month().day()))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                        Text("相伴 \(pet.daysTogetherAtPassing) 天 · \(pet.ageAtPassingText)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                    }
                    Spacer()
                    Button { showingUndoPassingAlert = true } label: {
                        Text("撤销离世")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goYellow)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.goYellow.opacity(0.1), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.goYellow.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1))
            }
            .alert("撤销离世标记", isPresented: $showingUndoPassingAlert) {
                Button("撤销", role: .destructive) {
                    RainbowBridgeService.undoPassedAway(pet: pet, context: modelContext)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清除 \(pet.name) 的离世记录，恢复为在世状态。")
            }
        } else {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "rainbow").foregroundStyle(Color.purple.opacity(0.6)).font(.system(size: 12))
                    Text("生命终章")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.purple.opacity(0.6))
                        .tracking(2)
                    Spacer()
                }
                Button {
                    rainbowBridgeDate = Date()
                    showingRainbowBridgeAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Text("🌈")
                        Text("标记 \(pet.name) 已离世")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.purple.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .alert("确认标记离世", isPresented: $showingRainbowBridgeAlert) {
                Button("确认", role: .destructive) {
                    RainbowBridgeService.markPassedAway(pet: pet, date: rainbowBridgeDate, context: modelContext)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将标记 \(pet.name) 为离世，并删除所有未来的提醒和事件。此操作可撤销。")
            }
        }
    }

    // MARK: - Danger Zone
    private var deleteDangerZone: some View {
        PetBasicInfoDangerZone(
            petName: pet.name,
            onClear: clearPetLogs,
            onDelete: { deletePetWithCascade(pet) }
        )
    }

    // MARK: - Delete Helpers
    private func deletePetWithCascade(_ p: Pet) {
        let petIdStr = p.id.uuidString
        if let allEvents = try? modelContext.fetch(FetchDescriptor<Event>()) {
            for event in allEvents where event.relatedEntityId == petIdStr {
                modelContext.delete(event)
            }
        }
        removeQuickAccessItems(for: p.id)
        modelContext.delete(p)
        modelContext.safeSave()
        dismiss()
    }

    private func removeQuickAccessItems(for petId: UUID) {
        let key = "quickActionItems_v2"
        guard let json = UserDefaults.standard.string(forKey: key),
              let data = json.data(using: .utf8),
              var items = try? JSONDecoder().decode([QuickActionItem].self, from: data) else { return }
        items.removeAll { $0.petId == petId }
        if let newData = try? JSONEncoder().encode(items),
           let newJSON = String(data: newData, encoding: .utf8) {
            UserDefaults.standard.set(newJSON, forKey: key)
        }
    }

    private func clearPetLogs() {
        pet.clearAllActivityRecords(in: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Edit State
    private func loadEditState() {
        eName = pet.name; eSpecies = pet.species; eBreed = pet.breed
        eGender = pet.gender; eIsNeutered = pet.isNeutered
        eHasBirthday = pet.birthday != nil; eBirthday = pet.birthday ?? Date()
        eHasHomeDate = pet.homeDate != nil; eHomeDate = pet.homeDate ?? Date()
        eCoatColor = pet.coatColor; eEyeColor = pet.eyeColor
        eMicrochipID = pet.microchipID; eVetContact = pet.vetContact
        eVetClinicName = pet.vetClinicName; eVetDoctorName = pet.vetDoctorName; eVetAddress = pet.vetAddress
        eAllergies = pet.allergies
        ePassportNumber = pet.passportNumber
        eHasPassportExpiry = pet.passportExpiryDate != nil
        ePassportExpiry = pet.passportExpiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        eFormerName = pet.formerName; eBirthCountry = pet.birthCountry; eBirthCity = pet.birthCity
        eLineageInfo = pet.lineageInfo; eNotes = pet.notes
        eThemeColorHex = pet.themeColorHex
        eAvatarImageData = pet.avatarImageData
    }

    private func saveChanges() {
        pet.name = eName.trimmingCharacters(in: .whitespaces).isEmpty ? pet.name : eName.trimmingCharacters(in: .whitespaces)
        pet.species = eSpecies; pet.breed = eBreed
        pet.gender = eGender; pet.isNeutered = eIsNeutered
        pet.birthday = eHasBirthday ? eBirthday : nil
        pet.homeDate = eHasHomeDate ? eHomeDate : nil
        pet.coatColor = eCoatColor; pet.eyeColor = eEyeColor
        pet.microchipID = eMicrochipID; pet.vetContact = eVetContact
        pet.vetClinicName = eVetClinicName; pet.vetDoctorName = eVetDoctorName; pet.vetAddress = eVetAddress
        pet.allergies = eAllergies
        pet.passportNumber = ePassportNumber
        pet.passportExpiryDate = eHasPassportExpiry ? ePassportExpiry : nil
        pet.formerName = eFormerName; pet.birthCountry = eBirthCountry; pet.birthCity = eBirthCity
        pet.lineageInfo = eLineageInfo; pet.notes = eNotes
        pet.themeColorHex = eThemeColorHex
        pet.avatarImageData = eAvatarImageData
        CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: modelContext)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private enum AvatarImageEditingSupport {
    nonisolated static func downsample(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDim / max(size.width, size.height), 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

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
}

struct EditableProfileAvatarPicker: View {
    @Binding var avatarImageData: Data?
    let fallbackEmoji: String
    let accentColor: Color
    let cropSpecies: String
    let silhouetteSystemName: String?

    @State private var photosPickerItem: PhotosPickerItem? = nil
    @State private var showingCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var pendingCapturedAvatarImage: UIImage? = nil
    @State private var cropImageItem: IdentifiableCropImage? = nil
    @State private var isPasting = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                avatarActionButton(icon: "doc.on.clipboard.fill", title: "粘贴") {
                    pastePasteboardImage()
                }

                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    avatarActionLabel(icon: "photo.on.rectangle.angled", title: "相册")
                }
                .buttonStyle(.plain)

                avatarActionButton(icon: "camera.fill", title: "拍照") {
                    presentCamera()
                }
            }

            if avatarImageData != nil {
                Button {
                    avatarImageData = nil
                } label: {
                    Text("移除头像")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(isPasting)
        .onChange(of: photosPickerItem) { _, item in
            handlePhotosPickerItemChanged(item)
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
                    species: cropSpecies,
                    silhouetteSystemName: silhouetteSystemName
                ) { cropped in
                    if let cropped {
                        let hasAlpha = ImageCutoutService.imageHasTransparentPixels(cropped)
                        let optimized = AvatarImageEditingSupport.optimizedAvatarAsset(cropped, preserveAlpha: hasAlpha)
                        avatarImageData = hasAlpha
                            ? optimized.pngData()
                            : optimized.jpegData(compressionQuality: 0.88)
                    }
                    cropImageItem = nil
                    photosPickerItem = nil
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            cropImageItem = nil
                            photosPickerItem = nil
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .alert("无法打开相机", isPresented: $showCameraPermissionAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text("请在系统设置中允许 Ohana 访问相机。")
        }
    }

    private func avatarActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            avatarActionLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func avatarActionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.monochrome)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color.arkInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func handlePhotosPickerItemChanged(_ item: PhotosPickerItem?) {
        Task {
            guard let item else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            if let data = try? await item.loadTransferable(type: Data.self) {
                let resized = await Task.detached(priority: .userInitiated) {
                    AddPetWizardView.cropReadyImage(from: data, maxPixel: 1_600)
                }.value
                await MainActor.run {
                    if let resized {
                        cropImageItem = IdentifiableCropImage(image: resized)
                        AppPerformanceMonitor.shared.record("相册到裁剪页", startedAt: startedAt, note: cropSpecies)
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
        guard let img = UIPasteboard.general.image else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let startedAt = CFAbsoluteTimeGetCurrent()
        isPasting = true
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                AddPetWizardView.preparedCropImage(img, maxPixel: 1_600)
            }.value
            cropImageItem = IdentifiableCropImage(image: prepared)
            AppPerformanceMonitor.shared.record("粘贴到裁剪页", startedAt: startedAt, note: cropSpecies)
            isPasting = false
        }
    }

    private func prepareCapturedAvatarForCrop(_ image: UIImage) {
        Task {
            let prepared = await Task.detached(priority: .userInitiated) {
                AddPetWizardView.preparedCropImage(image, maxPixel: 1_600)
            }.value
            try? await Task.sleep(nanoseconds: 120_000_000)
            cropImageItem = IdentifiableCropImage(image: prepared)
            AppPerformanceMonitor.shared.markEnd("avatar.camera.to.crop", name: "拍照到裁剪页", note: cropSpecies)
        }
    }
}

private struct PetBasicInfoDangerZone: View {
    let petName: String
    let onClear: () -> Void
    let onDelete: () -> Void

    @State private var showingClearConfirm = false
    @State private var showingDeleteSheet = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.goRed.opacity(0.7))
                    .font(.system(size: 12))
                Text("危险区域")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goRed.opacity(0.7))
                    .tracking(2)
                Spacer()
            }

            Button {
                showingClearConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("仅清空所有记录")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.goOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.goOrange.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                showingDeleteSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("彻底删除 \(petName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
        .alert("仅清空所有记录", isPresented: $showingClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空记录", role: .destructive) { onClear() }
        } message: {
            Text("将删除 \(petName) 的护理、体重、花费、健康、散步、喂食、清洁、里程碑、用药与相册等记录，并移除日历中该宠物的计划；保留名字、头像、品种与证件/保险档案。此操作不可撤销。")
        }
        .sheet(isPresented: $showingDeleteSheet) {
            PetDeleteConfirmationSheet(
                petName: petName,
                onCancel: { showingDeleteSheet = false },
                onDelete: {
                    showingDeleteSheet = false
                    onDelete()
                }
            )
            .presentationDetents([.height(380), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
        }
    }
}

private struct PetDeleteConfirmationSheet: View {
    let petName: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var confirmName = ""

    private var canDelete: Bool {
        confirmName.trimmingCharacters(in: .whitespacesAndNewlines) == petName
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.goRed)
                        .frame(width: 36, height: 36)
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("彻底删除 \(petName)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("输入名字后才能继续")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("这会删除宠物和所有关联记录，无法撤销。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.68))
                    Text("请输入：\(petName)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed.opacity(0.8))
                }

                TextField("宠物名字", text: $confirmName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1))

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Text("删除")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(canDelete ? Color.white : Color.primary.opacity(0.32))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canDelete ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDelete)
                }
            }
            .padding(20)
        }
    }
}
