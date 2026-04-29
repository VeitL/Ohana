//
//  HumanBasicInfoDetailView.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct HumanBasicInfoDetailView: View {
    let human: Human

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @Query private var allHumans: [Human]

    @State private var isEditing = false
    @State private var showingDeleteConfirm = false
    @State private var deleteConfirmName = ""

    @State private var eName = ""
    @State private var eAvatarEmoji = ""
    @State private var eRole = "owner"
    @State private var eGender = ""
    @State private var eHasBirthday = false
    @State private var eBirthday = Date()
    @State private var eBloodType = ""
    @State private var eHeightText = ""
    @State private var eMBTI = ""
    @State private var eNationality = ""
    @State private var eCity = ""
    @State private var eThemeColorHex = ""
    @State private var eShouldShowOnHome = true
    @State private var eNotes = ""
    @State private var ePrivateWeight = false
    @State private var ePrivateWorkout = false
    @State private var ePrivateMedication = false
    @State private var ePrivateWishlist = false
    @State private var ePrivateExpense = false
    @State private var ePrivateNote = false

    private let themePresets = ["4338FF", "C8FF00", "38BDF8", "EC4899", "F97316", "EF4444", "14B8A6", "A855F7", "FACC15", "64748B"]
    private let bloodTypeOptions = ["未填写", "A", "B", "AB", "O"]
    private let mbtiOptions = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

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
        .navigationTitle("\(human.name) 的信息")
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
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            TextField("输入成员名字确认", text: $deleteConfirmName)
            Button("取消", role: .cancel) { deleteConfirmName = "" }
            Button("删除", role: .destructive) {
                if deleteConfirmName == human.name {
                    deleteHumanAndReturnHome()
                }
            }
        } message: {
            Text("请输入 \"\(human.name)\" 确认删除。此操作不可撤销。")
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: human.themeColorHex).opacity(0.16))
                    .frame(width: 112, height: 112)
                    .overlay(Circle().strokeBorder(Color(hex: human.themeColorHex).opacity(0.35), lineWidth: 2))
                if let data = human.avatarImageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                } else {
                    Text(human.avatarEmoji.isEmpty ? "👤" : human.avatarEmoji)
                        .font(OhanaFont.metric(size: 54))
                }
            }

            VStack(spacing: 6) {
                Text(human.name)
                    .font(OhanaFont.metric(size: 32))
                    .foregroundStyle(Color(hex: "1E3A8A"))
                HStack(spacing: 8) {
                    chip(human.roleText, color: Color(hex: human.themeColorHex))
                    if let birthday = human.birthday {
                        chip(human.ageText, color: Color.goPrimary)
                        chip(Human.westernZodiacChinese(for: birthday), color: Color.goPurple)
                    }
                    if !human.mbti.isEmpty {
                        chip(human.mbti.uppercased(), color: Color.goOrange)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .goIslandModuleCard(cornerRadius: 28)
    }

    private var readContent: some View {
        VStack(spacing: 16) {
            infoSection(title: "基本信息", icon: "person.fill", iconColor: Color.goPrimary) {
                infoRow(label: "名字", value: human.name)
                infoRow(label: "角色", value: human.roleText)
                infoRow(label: "性别", value: human.genderRaw.isEmpty ? "未填写" : human.genderRaw)
                if let birthday = human.birthday {
                    infoRow(label: "生日", value: birthday.formatted(.dateTime.year().month().day()))
                    infoRow(label: "星座", value: Human.westernZodiacChinese(for: birthday))
                } else {
                    infoRow(label: "生日", value: "未填写")
                }
            }

            infoSection(title: "身体资料", icon: "heart.text.square.fill", iconColor: Color.goRed) {
                infoRow(label: "血型", value: human.bloodType.isEmpty ? "未填写" : human.bloodType)
                infoRow(label: "身高", value: human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f cm", human.heightCm) : "未填写")
                infoRow(label: "MBTI", value: human.mbti.isEmpty ? "未填写" : human.mbti.uppercased())
            }

            infoSection(title: "家庭与位置", icon: "house.fill", iconColor: Color.goTeal) {
                infoRow(label: "国籍", value: human.nationality.isEmpty ? "未填写" : human.nationality)
                infoRow(label: "现居地", value: human.city.isEmpty ? "未填写" : human.city)
                infoRow(label: "加入时间", value: human.createdAt.formatted(.dateTime.year().month().day()))
                infoRow(label: "相处天数", value: "\(daysTogether) 天")
            }

            infoSection(title: "显示与隐私", icon: "lock.shield.fill", iconColor: Color.goYellow) {
                infoRow(label: "首页显示", value: human.shouldShowOnHome ? "显示" : "隐藏")
                infoRow(label: "隐私项目", value: privacySummary)
            }

            infoSection(title: "主题色", icon: "paintpalette.fill", iconColor: Color(hex: human.themeColorHex)) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: human.themeColorHex))
                        .frame(width: 32, height: 32)
                    Text("#\(human.themeColorHex.uppercased())")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.8))
                }
            }

            if !displayNotes.isEmpty {
                infoSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                    Text(displayNotes)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            deleteDangerZone
        }
    }

    private var editContent: some View {
        VStack(spacing: 14) {
            editSection(title: "基本信息", icon: "person.fill", iconColor: Color.goPrimary) {
                editField("名字", text: $eName)
                Divider().opacity(0.1)
                editField("头像 Emoji", text: $eAvatarEmoji)
                Divider().opacity(0.1)
                HStack {
                    editLabel("角色")
                    Spacer()
                    Picker("", selection: $eRole) {
                        Text("主人").tag("owner")
                        Text("编辑").tag("editor")
                        Text("查看").tag("viewer")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
                Divider().opacity(0.1)
                HStack {
                    editLabel("性别")
                    Spacer()
                    Picker("", selection: $eGender) {
                        Text("男").tag("male")
                        Text("女").tag("female")
                        Text("未知").tag("")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eHasBirthday) {
                    editLabel("设置生日")
                }
                .tint(Color.goPrimary)
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                }
            }

            editSection(title: "身体资料", icon: "heart.text.square.fill", iconColor: Color.goRed) {
                optionChipGrid(title: "血型", selection: $eBloodType, options: bloodTypeOptions, accent: Color.goRed)
                Divider().opacity(0.1)
                heightStepperRow
                Divider().opacity(0.1)
                optionChipGrid(title: "MBTI", selection: $eMBTI, options: mbtiOptions, accent: Color.goOrange)
            }

            editSection(title: "家庭与位置", icon: "house.fill", iconColor: Color.goTeal) {
                optionPickerRow("国籍", selection: $eNationality, options: countryOptions)
                Divider().opacity(0.1)
                optionPickerRow("现居地", selection: $eCity, options: residenceCityOptions)
                Divider().opacity(0.1)
                Toggle(isOn: $eShouldShowOnHome) {
                    editLabel("在首页显示")
                }
                .tint(Color.goPrimary)
            }

            editSection(title: "隐私设置", icon: "lock.shield.fill", iconColor: Color.goYellow) {
                privacyToggle("体重记录", isOn: $ePrivateWeight)
                privacyToggle("运动记录", isOn: $ePrivateWorkout)
                privacyToggle("吃药提醒", isOn: $ePrivateMedication)
                privacyToggle("备注", isOn: $ePrivateNote)
                privacyToggle("椰子资产与心愿", isOn: $ePrivateWishlist)
                privacyToggle("花费记录", isOn: $ePrivateExpense)
            }

            editSection(title: "主题色", icon: "paintpalette.fill", iconColor: Color(hex: eThemeColorHex)) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                    ForEach(themePresets, id: \.self) { hex in
                        Button { eThemeColorHex = hex } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex)).frame(width: 38, height: 38)
                                if eThemeColorHex.uppercased() == hex.uppercased() {
                                    Circle().strokeBorder(.white, lineWidth: 2.5)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            editSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                TextEditor(text: $eNotes)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var deleteDangerZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("危险操作")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.goRed)
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("删除成员", systemImage: "trash")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goRed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.goRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 16)
    }

    private func infoSection<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            VStack(spacing: 10) { content() }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 16)
    }

    private func editSection<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        infoSection(title: title, icon: icon, iconColor: iconColor, content: content)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.trailing)
        }
    }

    private func editLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private func editField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            editLabel(title)
            TextField(title, text: text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.trailing)
        }
    }

    private var countryOptions: [String] {
        var options = ["未填写"] + PetBreedDatabase.countries
        if !eNationality.isEmpty, !options.contains(eNationality) {
            options.insert(eNationality, at: 1)
        }
        return options
    }

    private var residenceCityOptions: [String] {
        let base = eNationality.isEmpty || eNationality == "未填写"
            ? ["未填写"]
            : ["未填写"] + PetBreedDatabase.cities(for: eNationality)
        var options = base
        if !eCity.isEmpty, !options.contains(eCity) {
            options.insert(eCity, at: 1)
        }
        return options
    }

    private var heightValue: Double {
        Double(eHeightText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private var heightStepperRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                editLabel("身高")
                Spacer()
                Text(heightValue > 0 ? "\(Int(heightValue)) cm" : "未填写")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.82))
            }
            HStack(spacing: 8) {
                ForEach(["未填写", "160", "165", "170", "175", "180"], id: \.self) { option in
                    Button {
                        eHeightText = option == "未填写" ? "" : option
                    } label: {
                        Text(option == "未填写" ? option : "\(option)")
                            .font(.system(size: 12, weight: heightOptionSelected(option) ? .black : .semibold, design: .rounded))
                            .foregroundStyle(heightOptionSelected(option) ? Color.arkInk : .primary.opacity(0.78))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(heightOptionSelected(option) ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Stepper(
                value: Binding(
                    get: { Int(heightValue > 0 ? heightValue : 170) },
                    set: { eHeightText = "\($0)" }
                ),
                in: 80...230,
                step: 1
            ) {
                Text("微调 80-230 cm")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func heightOptionSelected(_ option: String) -> Bool {
        guard option != "未填写", let optionValue = Int(option) else {
            return eHeightText.isEmpty
        }
        return Int(heightValue) == optionValue
    }

    private func optionPickerRow(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            editLabel(title)
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

    private func optionChipGrid(title: String, selection: Binding<String>, options: [String], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            editLabel(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let selected = (selection.wrappedValue.isEmpty && option == "未填写") || selection.wrappedValue.uppercased() == option
                    Button {
                        selection.wrappedValue = option == "未填写" ? "" : option
                    } label: {
                        Text(option)
                            .font(.system(size: 12, weight: selected ? .black : .semibold, design: .rounded))
                            .foregroundStyle(selected ? Color.arkInk : .primary.opacity(0.82))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selected ? accent : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func privacyToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            editLabel(title)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Color.goYellow)
                .labelsHidden()
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var daysTogether: Int {
        max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
    }

    private var privacySummary: String {
        let titles = HumanPrivateField.allCases
            .filter { human.privateFields.contains($0.rawValue) }
            .map(\.title)
        return titles.isEmpty ? "全部公开" : titles.joined(separator: "、")
    }

    private var displayNotes: String {
        visibleNoteParts.joined(separator: "｜")
    }

    private var visibleNoteParts: [String] {
        human.notes
            .split(separator: "｜", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.hasPrefix("性别:") && !$0.hasPrefix("关系:") }
    }

    private var preservedMetadataParts: [String] {
        human.notes
            .split(separator: "｜", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.hasPrefix("关系:") }
    }

    private func loadEditState() {
        eName = human.name
        eAvatarEmoji = human.avatarEmoji
        eRole = human.role
        eGender = human.genderRaw
        eBirthday = human.birthday ?? Date()
        eHasBirthday = human.birthday != nil
        eBloodType = human.bloodType
        eHeightText = human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f", human.heightCm) : ""
        eMBTI = human.mbti
        eNationality = human.nationality
        eCity = human.city
        eThemeColorHex = human.themeColorHex.isEmpty ? "4338FF" : human.themeColorHex
        eShouldShowOnHome = human.shouldShowOnHome
        eNotes = displayNotes
        ePrivateWeight = human.privateFields.contains(HumanPrivateField.weight.rawValue)
        ePrivateWorkout = human.privateFields.contains(HumanPrivateField.workout.rawValue)
        ePrivateMedication = human.privateFields.contains(HumanPrivateField.medication.rawValue)
        ePrivateWishlist = human.privateFields.contains(HumanPrivateField.wishlist.rawValue)
        ePrivateExpense = human.privateFields.contains(HumanPrivateField.expense.rawValue)
        ePrivateNote = human.privateFields.contains(HumanPrivateField.note.rawValue)
    }

    private func saveChanges() {
        human.name = eName.trimmingCharacters(in: .whitespacesAndNewlines)
        human.avatarEmoji = eAvatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "👤" : eAvatarEmoji
        human.role = eRole
        human.birthday = eHasBirthday ? eBirthday : nil
        human.bloodType = eBloodType.trimmingCharacters(in: .whitespacesAndNewlines)
        human.heightCm = Double(eHeightText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        human.mbti = eMBTI.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        human.nationality = eNationality.trimmingCharacters(in: .whitespacesAndNewlines)
        human.city = eCity.trimmingCharacters(in: .whitespacesAndNewlines)
        human.themeColorHex = eThemeColorHex
        human.shouldShowOnHome = eShouldShowOnHome

        var noteParts: [String] = []
        if !eGender.isEmpty { noteParts.append("性别:\(eGender)") }
        noteParts.append(contentsOf: preservedMetadataParts)
        let trimmedNotes = eNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty { noteParts.append(trimmedNotes) }
        human.notes = noteParts.joined(separator: "｜")

        human.setPrivate(.weight, ePrivateWeight)
        human.setPrivate(.workout, ePrivateWorkout)
        human.setPrivate(.medication, ePrivateMedication)
        human.setPrivate(.wishlist, ePrivateWishlist)
        human.setPrivate(.expense, ePrivateExpense)
        human.setPrivate(.note, ePrivateNote)
        modelContext.safeSave()
    }

    private func deleteHumanAndReturnHome() {
        let deletedHumanId = human.id.uuidString
        let fallbackHumanId = allHumans.first(where: { $0.id.uuidString != deletedHumanId })?.id.uuidString ?? ""

        if activeHumanIdStr == deletedHumanId {
            activeHumanIdStr = fallbackHumanId
        }

        modelContext.delete(human)
        modelContext.safeSave()
        NotificationCenter.default.post(name: .ohanaReturnHomeAfterHumanDeletion, object: nil)
        dismiss()
    }
}
