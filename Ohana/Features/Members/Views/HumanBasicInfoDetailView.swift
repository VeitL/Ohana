//
//  HumanBasicInfoDetailView.swift
//  Ohana
//

import SwiftData
import SwiftUI

struct HumanBasicInfoDetailContentView: View {
    let human: Human
    let allPets: [Pet]
    let allHumans: [Human]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }

    @State private var isEditing = false
    @State private var isDeleting = false
    @State private var showingHomeStackFullAlert = false

    @State private var eName = ""
    @State private var eAvatarImageData: Data? = nil
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

    private let themePresets = ["F97316", "EC4899", "A855F7", "EF4444", "14B8A6", "FACC15", "8B5CF6", "64748B", "B45309", "DB2777"]
    private let bloodTypeOptions = ["未填写", "A", "B", "AB", "O"]
    private let mbtiOptions = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]
    private let genderOptions = HumanProfileOptions.genderOptions

    var body: some View {
        ZStack {
            OhanaAppBackground()

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
                if isViewingOwnProfile, !human.hasPassedAway {
                    if isEditing {
                        Button {
                            saveChanges()
                            withAnimation { isEditing = false }
                        } label: {
                            Text("保存")
                                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.goPrimary)
                        }
                    } else {
                        Button {
                            loadEditState()
                            withAnimation { isEditing = true }
                        } label: {
                            Image(systemName: "pencil.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.goPrimary)
                        }
                    }
                }
            }
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { withAnimation { isEditing = false } }
                }
            }
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway {
                isEditing = false
            }
        }
        .alert("首页卡片堆已满", isPresented: $showingHomeStackFullAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("首页最多显示 \(HomeCardVisibility.maxVisibleCards) 张卡片。请先从首页移除一张宠物或人类卡片，再添加 \(human.name)。")
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 14) {
            humanAvatarImage(
                data: isEditing ? eAvatarImageData : human.avatarImageData,
                fallbackEmoji: isEditing ? eAvatarEmoji : human.avatarEmoji,
                accent: isEditing ? Color(hex: eThemeColorHex) : Color(hex: human.safeThemeColorHex),
                size: 112
            )

            VStack(spacing: 6) {
                Text(isEditing ? (eName.isEmpty ? human.name : eName) : human.name)
                    .font(OhanaFont.metric(size: 32))
                    .foregroundStyle(Color(hex: "1E3A8A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                HStack(spacing: 8) {
                    chip(isEditing ? roleLabel(for: eRole) : human.roleText, color: isEditing ? Color(hex: eThemeColorHex) : Color(hex: human.safeThemeColorHex))
                    if let birthday = isEditing && eHasBirthday ? eBirthday : human.birthday {
                        chip(isEditing && eHasBirthday ? humanAgeText(for: birthday) : human.ageText, color: Color.goPrimary)
                        chip(Human.westernZodiacChinese(for: birthday), color: Color.goPurple)
                    }
                    let mbti = isEditing ? eMBTI : human.mbti
                    if !mbti.isEmpty {
                        chip(mbti.uppercased(), color: Color.goOrange)
                    }
                }
            }

            if isEditing {
                EditableProfileAvatarPicker(
                    avatarImageData: $eAvatarImageData,
                    fallbackEmoji: eAvatarEmoji.isEmpty ? "👤" : eAvatarEmoji,
                    accentColor: Color(hex: eThemeColorHex),
                    cropSpecies: "",
                    silhouetteSystemName: "person.fill"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .goIslandModuleCard(cornerRadius: OhanaRadius.hero)
    }

    private func humanAvatarImage(data: Data?, fallbackEmoji: String, accent: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(accent.opacity(0.35), lineWidth: 2))
            AsyncDecodedImageView(data: data) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: max(0, size - 8), height: max(0, size - 8), alignment: .center)
                    .clipShape(Circle())
            } placeholder: {
                Text(fallbackEmoji.isEmpty ? "👤" : fallbackEmoji)
                    .font(OhanaFont.metric(size: size * 0.48))
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }

    private func roleLabel(for role: String) -> String {
        HumanPermissionRole.title(for: role)
    }

    private func humanAgeText(for birthday: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return years > 0 ? "\(years)岁" : "未满1岁"
    }

    private var readContent: some View {
        VStack(spacing: 16) {
            infoSection(title: "基本信息", icon: "person.fill", iconColor: Color.goPrimary) {
                infoRow(label: "名字", value: human.name)
                infoRow(label: "权限", value: human.roleText)
                infoRow(label: "性别/身份", value: HumanGenderIdentity.title(for: human.genderRaw))
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

            infoSection(title: "主题色", icon: "paintpalette.fill", iconColor: Color(hex: human.safeThemeColorHex)) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: OhanaRadius.icon)
                        .fill(Color(hex: human.safeThemeColorHex))
                        .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    Text("#\(human.safeThemeColorHex.uppercased())")
                        .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .monospaced)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.8))
                }
            }

            if !displayNotes.isEmpty {
                infoSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                    Text(displayNotes)
                        .font(OhanaFont.adaptive(size: 14, weight: .medium)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            humanLifecycleDangerZone
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
                    editLabel("权限")
                    Spacer()
                    Picker("", selection: $eRole) {
                        Text("管理者").tag("owner")
                        Text("成员").tag("member")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
                Divider().opacity(0.1)
                HStack {
                    editLabel("性别/身份")
                    Spacer()
                    Picker("", selection: $eGender) {
                        ForEach(genderOptions, id: \.key) { option in
                            Text(HumanGenderIdentity.title(for: option.key)).tag(option.key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180, alignment: .trailing)
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
                Toggle(isOn: Binding(
                    get: { eShouldShowOnHome },
                    set: { visible in
                        if visible, !HomeCardVisibility.canShowHuman(human, pets: allPets, humans: allHumans, raw: hiddenHomePetIDsRaw) {
                            showingHomeStackFullAlert = true
                            return
                        }
                        eShouldShowOnHome = visible
                    }
                )) {
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
                                Circle().fill(Color(hex: hex)).frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                if eThemeColorHex.uppercased() == hex.uppercased() {
                                    Circle().strokeBorder(Color.ohanaPrimaryText, lineWidth: 2.5)
                                    Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                }
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }

            editSection(title: "备注", icon: "note.text", iconColor: Color.goOrange) {
                TextEditor(text: $eNotes)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            }
        }
    }

    private var humanLifecycleDangerZone: some View {
        HumanLifecycleDangerZone(
            human: human,
            onMarkPassedAway: markHumanPassedAway,
            onUndoPassedAway: undoHumanPassedAway,
            onDelete: deleteHumanAndReturnHome
        )
        .disabled(isDeleting)
    }

    private func infoSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.icon, style: .continuous))
                Text(title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            VStack(spacing: 10) { content() }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: OhanaRadius.control)
    }

    private func editSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        infoSection(title: title, icon: icon, iconColor: iconColor, content: content)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer(minLength: 16)
            Text(value)
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.85))
                .multilineTextAlignment(.trailing)
        }
    }

    private func editLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func editField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            editLabel(title)
            TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
            }
            HStack(spacing: 8) {
                ForEach(["未填写", "160", "165", "170", "175", "180"], id: \.self) { option in
                    Button {
                        eHeightText = option == "未填写" ? "" : option
                    } label: {
                        Text(option == "未填写" ? option : "\(option)")
                            .font(OhanaFont.adaptive(size: 12, weight: heightOptionSelected(option) ? .black : .semibold, design: .rounded))
                            .foregroundStyle(heightOptionSelected(option) ? Color.arkInk : .primary.opacity(0.78))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(heightOptionSelected(option) ? Color.goPrimary : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            Stepper(
                value: Binding(
                    get: { Int(heightValue > 0 ? heightValue : 170) },
                    set: { eHeightText = "\($0)" }
                ),
                in: 80 ... 230,
                step: 1
            ) {
                Text("微调 80-230 cm")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
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
                            .font(OhanaFont.adaptive(size: 12, weight: selected ? .black : .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(selected ? Color.arkInk : .primary.opacity(0.82))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(selected ? accent : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
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
        HumanProfileOptions.visibleNoteParts(from: human.notes)
    }

    private var preservedMetadataParts: [String] {
        human.notes
            .split(separator: "｜", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.hasPrefix("关系:") }
    }

    private func loadEditState() {
        eName = human.name
        eAvatarImageData = human.avatarImageData
        eAvatarEmoji = human.avatarEmoji
        eRole = HumanProfileOptions.normalizedRole(human.role)
        eGender = human.genderRaw.isEmpty ? "不透露" : human.genderRaw
        eBirthday = human.birthday ?? Date()
        eHasBirthday = human.birthday != nil
        eBloodType = human.bloodType
        eHeightText = human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f", human.heightCm) : ""
        eMBTI = human.mbti
        eNationality = human.nationality
        eCity = human.city
        eThemeColorHex = human.safeThemeColorHex
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
        if eShouldShowOnHome, !HomeCardVisibility.canShowHuman(human, pets: allPets, humans: allHumans, raw: hiddenHomePetIDsRaw) {
            showingHomeStackFullAlert = true
            return
        }

        let input = HumanProfileCommandInput(
            name: eName,
            avatarImageData: eAvatarImageData,
            avatarEmoji: eAvatarEmoji,
            role: eRole,
            gender: eGender,
            birthday: eHasBirthday ? eBirthday : nil,
            bloodType: eBloodType,
            heightText: eHeightText,
            mbti: eMBTI,
            nationality: eNationality,
            city: eCity,
            themeHex: eThemeColorHex,
            notes: eNotes,
            preservedNoteParts: preservedMetadataParts,
            shouldShowOnHome: eShouldShowOnHome,
            privateFieldsRaw: editedPrivateFieldsRaw
        )
        commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                human,
                input: input,
                note: "humanBasicInfo.profile"
            )
            appServices.domainRevisions.publishMemberProfile(result, note: "humanBasicInfo.profile")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var editedPrivateFieldsRaw: Set<String> {
        var fields = Set<String>()
        if ePrivateWeight { fields.insert(HumanPrivateField.weight.rawValue) }
        if ePrivateWorkout { fields.insert(HumanPrivateField.workout.rawValue) }
        if ePrivateMedication { fields.insert(HumanPrivateField.medication.rawValue) }
        if ePrivateWishlist { fields.insert(HumanPrivateField.wishlist.rawValue) }
        if ePrivateExpense { fields.insert(HumanPrivateField.expense.rawValue) }
        if ePrivateNote { fields.insert(HumanPrivateField.note.rawValue) }
        return fields
    }

    private func deleteHumanAndReturnHome() {
        guard !isDeleting else { return }
        isDeleting = true

        let target = human
        let activeHumanID = activeHumanIdStr
        let command = DomainCommand.memberDeletion(entityID: target.id, kind: EntityKind.human.rawValue)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                target,
                activeHumanID: activeHumanID,
                note: "humanBasicInfo.delete"
            )
            if result.clearsActiveHumanID {
                activeHumanIdStr = ""
            }
            appServices.notificationRoutes.publishRouteEvent(
                .humanDeleted(
                    requiresReplacementHuman: result.requiresReplacementHuman,
                    requiresAccountSwitch: result.requiresAccountSwitch
                )
            )
        }
    }

    private func markHumanPassedAway(date: Date) {
        let command = DomainCommand.memberLifecycle(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.mark"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            _ = MemberCommandExecutor(context: modelContext, services: appServices).markHumanPassedAway(
                human,
                date: date,
                note: "humanBasicInfo.passed.mark"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func undoHumanPassedAway() {
        let command = DomainCommand.memberLifecycle(
            entityID: human.id,
            kind: EntityKind.human.rawValue,
            action: "passed.undo"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            _ = MemberCommandExecutor(context: modelContext, services: appServices).undoHumanPassedAway(
                human,
                note: "humanBasicInfo.passed.undo"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

struct HumanLifecycleDangerZone: View {
    private static let deleteAfterSheetDismissDelayMilliseconds: UInt64 = 180

    let human: Human
    let onMarkPassedAway: (Date) -> Void
    let onUndoPassedAway: () -> Void
    let onDelete: () -> Void

    @State private var passedDate = Date()
    @State private var showingPassedAlert = false
    @State private var showingUndoPassedAlert = false
    @State private var showingDeleteSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.goRed.opacity(0.72))
                Text("生命与危险操作")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goRed.opacity(0.78))
                    .tracking(1.2)
                Spacer(minLength: 0)
            }

            if human.hasPassedAway {
                passedAwaySummary
                lifecycleButton(
                    title: "撤销离世标记",
                    icon: "arrow.uturn.backward",
                    color: Color.goYellow
                ) {
                    showingUndoPassedAlert = true
                }
            } else {
                DatePicker("离世日期", selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                lifecycleButton(
                    title: "标记 \(human.name) 已离世",
                    icon: "rainbow",
                    color: Color.goPurple
                ) {
                    showingPassedAlert = true
                }
            }

            lifecycleButton(
                title: "彻底删除 \(human.name)",
                icon: "trash.fill",
                color: Color.goRed
            ) {
                showingDeleteSheet = true
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: OhanaRadius.control)
        .onAppear {
            passedDate = human.passedAwayDate ?? Date()
        }
        .onChange(of: human.passedAwayDate) { _, date in
            passedDate = date ?? Date()
        }
        .alert("确认标记离世", isPresented: $showingPassedAlert) {
            Button("确认", role: .destructive) {
                onMarkPassedAway(passedDate)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将标记 \(human.name) 为离世，并让未来安排退出活跃提醒。原有数据会保留，此操作可撤销。")
        }
        .alert("撤销离世标记", isPresented: $showingUndoPassedAlert) {
            Button("撤销", role: .destructive) {
                onUndoPassedAway()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除 \(human.name) 的离世记录，恢复为在世状态。")
        }
        .sheet(isPresented: $showingDeleteSheet) {
            HumanDeleteConfirmationSheet(
                humanName: human.name,
                onCancel: { showingDeleteSheet = false },
                onDelete: {
                    showingDeleteSheet = false
                    OhanaFrameScheduler.runAfterNextFrame(
                        milliseconds: Self.deleteAfterSheetDismissDelayMilliseconds
                    ) {
                        onDelete()
                    }
                }
            )
            .ohanaCompactSheetPresentation(detents: [.height(360), .medium])
        }
    }

    private var passedAwaySummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = human.passedAwayDate {
                Text("离世日期：\(date.formatted(.dateTime.year().month().day()))")
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
            }
            Text("相伴 \(human.daysTogetherAtPassing) 天 · \(human.ageAtPassingText)")
                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.goPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            .strokeBorder(Color.goPurple.opacity(0.22), lineWidth: 1))
    }

    private func lifecycleButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon) // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .bold))
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(color.opacity(0.26), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct HumanDeleteConfirmationSheet: View {
    let humanName: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var confirmName = ""
    @FocusState private var confirmNameFocused: Bool

    private var canDelete: Bool {
        ConfirmationNameMatcher.matches(confirmName, expectedName: humanName)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed)
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("删除成员 \(humanName)")
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("输入名字后才能继续")
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Button(action: cancelAfterResigningKeyboard) {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("这会删除成员资料、体重与运动记录，无法撤销。")
                        .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))
                    Text("请输入：\(humanName)")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed.opacity(0.8))
                }

                TextField("成员名字", text: $confirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($confirmNameFocused)
                    .onSubmit { attemptDelete() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1))

                HStack(spacing: 10) {
                    Button(action: cancelAfterResigningKeyboard) {
                        Text("取消")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: attemptDelete) {
                        Text("删除")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(canDelete ? Color.white : Color.ohanaTertiaryText) // ui-v4: allow destructive red button needs white contrast
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canDelete ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                }
            }
            .padding(20)
        }
    }

    private func cancelAfterResigningKeyboard() {
        confirmNameFocused = false
        onCancel()
    }

    private func attemptDelete() {
        guard canDelete else { return }
        confirmNameFocused = false
        onDelete()
    }
}
