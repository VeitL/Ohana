//
//  PetBasicInfoDetailView.swift
//  Ohana
//

import SwiftUI
import SwiftData
import PhotosUI

struct PetBasicInfoDetailView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false

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
    @State private var eVetContact = ""
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

    private let speciesOptions = ["狗", "猫", "兔子", "仓鼠", "鸟", "其他"]
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
                            .foregroundStyle(Color.goLime)
                    }
                } else {
                    Button {
                        loadEditState()
                        withAnimation { isEditing = true }
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.goLime)
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button { withAnimation { isEditing = false } } label: {
                        Text("取消").foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Read View
    private var readContent: some View {
        VStack(spacing: 16) {
            infoSection(title: "基本信息", icon: "pawprint.fill", iconColor: Color.goLime) {
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
                infoRow(label: "芯片号",   value: pet.microchipID.isEmpty ? "未登记" : pet.microchipID)
                infoRow(label: "兽医联系", value: pet.vetContact.isEmpty  ? "未填写" : pet.vetContact)
                infoRow(label: "过敏原",   value: pet.allergies.isEmpty   ? "无记录" : pet.allergies)
            }
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
        }
    }

    // MARK: - Edit View
    private var editContent: some View {
        VStack(spacing: 14) {
            // 基本信息
            editSection(title: "基本信息", icon: "pawprint.fill", iconColor: Color.goLime) {
                editField("名字", text: $eName)
                Divider().opacity(0.1)
                // 物种
                HStack {
                    editLabel("物种")
                    Spacer()
                    Picker("", selection: $eSpecies) {
                        ForEach(speciesOptions, id: \.self) { Text($0) }
                    }.pickerStyle(.menu).tint(Color.goLime)
                }
                Divider().opacity(0.1)
                editField("品种", text: $eBreed)
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
                }.tint(Color.goLime)
                Divider().opacity(0.1)
                Toggle(isOn: $eHasBirthday) {
                    editLabel("设置生日")
                }.tint(Color.goLime)
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goLime).labelsHidden()
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eHasHomeDate) {
                    editLabel("设置到家日")
                }.tint(Color.goLime)
                if eHasHomeDate {
                    DatePicker("", selection: $eHomeDate, displayedComponents: .date)
                        .datePickerStyle(.compact).tint(Color.goLime).labelsHidden()
                }
            }
            // 外貌
            editSection(title: "外貌特征", icon: "eye.fill", iconColor: Color.goCardCyan) {
                editField("毛色", text: $eCoatColor)
                Divider().opacity(0.1)
                editField("眼色", text: $eEyeColor)
            }
            // 健康
            editSection(title: "健康与医疗", icon: "cross.circle.fill", iconColor: Color.goRed) {
                editField("芯片号",   text: $eMicrochipID)
                Divider().opacity(0.1)
                editField("兽医联系", text: $eVetContact)
                Divider().opacity(0.1)
                editField("过敏原",   text: $eAllergies)
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
                editField("出生国家", text: $eBirthCountry)
                Divider().opacity(0.1)
                editField("出生城市", text: $eBirthCity)
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
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
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
        HStack(spacing: 16) {
            ZStack {
                Circle().fill((isEditing ? Color(hex: eThemeColorHex) : Color(hex: pet.themeColorHex)).opacity(0.25)).frame(width: 72, height: 72)
                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(Circle())
                } else {
                    Text(pet.avatarEmoji).font(.system(size: 36))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? (eName.isEmpty ? pet.name : eName) : pet.name)
                    .font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(.primary)
                Text("\(isEditing ? eSpecies : pet.species) · \(isEditing ? (eBreed.isEmpty ? "未填写品种" : eBreed) : (pet.breed.isEmpty ? "未填写品种" : pet.breed))")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.primary.opacity(0.5))
            }
            Spacer()
            if isEditing {
                Text("编辑中").font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goLime).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.goLime.opacity(0.15), in: Capsule())
            }
        }
        .padding(16).goTranslucentCard(cornerRadius: 20)
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
                .tint(Color.goLime)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Edit State
    private func loadEditState() {
        eName = pet.name; eSpecies = pet.species; eBreed = pet.breed
        eGender = pet.gender; eIsNeutered = pet.isNeutered
        eHasBirthday = pet.birthday != nil; eBirthday = pet.birthday ?? Date()
        eHasHomeDate = pet.homeDate != nil; eHomeDate = pet.homeDate ?? Date()
        eCoatColor = pet.coatColor; eEyeColor = pet.eyeColor
        eMicrochipID = pet.microchipID; eVetContact = pet.vetContact; eAllergies = pet.allergies
        ePassportNumber = pet.passportNumber
        eHasPassportExpiry = pet.passportExpiryDate != nil
        ePassportExpiry = pet.passportExpiryDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        eFormerName = pet.formerName; eBirthCountry = pet.birthCountry; eBirthCity = pet.birthCity
        eLineageInfo = pet.lineageInfo; eNotes = pet.notes
        eThemeColorHex = pet.themeColorHex
    }

    private func saveChanges() {
        pet.name = eName.trimmingCharacters(in: .whitespaces).isEmpty ? pet.name : eName.trimmingCharacters(in: .whitespaces)
        pet.species = eSpecies; pet.breed = eBreed
        pet.gender = eGender; pet.isNeutered = eIsNeutered
        pet.birthday = eHasBirthday ? eBirthday : nil
        pet.homeDate = eHasHomeDate ? eHomeDate : nil
        pet.coatColor = eCoatColor; pet.eyeColor = eEyeColor
        pet.microchipID = eMicrochipID; pet.vetContact = eVetContact; pet.allergies = eAllergies
        pet.passportNumber = ePassportNumber
        pet.passportExpiryDate = eHasPassportExpiry ? ePassportExpiry : nil
        pet.formerName = eFormerName; pet.birthCountry = eBirthCountry; pet.birthCity = eBirthCity
        pet.lineageInfo = eLineageInfo; pet.notes = eNotes
        pet.themeColorHex = eThemeColorHex
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
