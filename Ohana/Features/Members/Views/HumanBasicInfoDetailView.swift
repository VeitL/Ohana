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
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var l: L10n { L10n(appLanguage) }

    @State private var isEditing = false
    @State private var isDeleting = false

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
    @State private var eNotes = ""
    @State private var ePrivateWeight = false
    @State private var ePrivateWorkout = false
    @State private var ePrivateMedication = false
    @State private var ePrivateWishlist = false
    @State private var ePrivateExpense = false
    @State private var ePrivateNote = false

    private let themePresets = ["F97316", "EC4899", "A855F7", "EF4444", "14B8A6", "FACC15", "8B5CF6", "64748B", "B45309", "DB2777"]
    private let bloodTypeOptions = ["", "A", "B", "AB", "O"]
    private let mbtiOptions = ["", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]
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
        .navigationTitle(l.tr(zh: "\(human.name) 的信息", en: "\(human.name)'s Info", de: "Infos zu \(human.name)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isViewingOwnProfile, !human.hasPassedAway {
                    if isEditing {
                        Button {
                            saveChanges()
                        } label: {
                            Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.goPrimary)
                        }
                        .accessibilityIdentifier("human-basic-info-save-action")
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
                        .accessibilityIdentifier("human-basic-info-edit-action")
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) { withAnimation { isEditing = false } }
                } else {
                    Button(l.tr(zh: "关闭", en: "Close", de: "Schließen")) { dismiss() }
                        .accessibilityIdentifier("human-basic-info-close-action")
                }
            }
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway {
                isEditing = false
            }
        }
        .accessibilityIdentifier("human-basic-info-screen")
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
                    chip(isEditing ? roleLabel(for: eRole) : localizedRoleText(for: human.role), color: isEditing ? Color(hex: eThemeColorHex) : Color(hex: human.safeThemeColorHex))
                    if let birthday = isEditing && eHasBirthday ? eBirthday : human.birthday {
                        chip(humanAgeText(for: birthday), color: Color.goPrimary)
                        chip(Human.westernZodiacDisplay(for: birthday, l: l), color: Color.goPurple)
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
        localizedRoleText(for: role)
    }

    private func humanAgeText(for birthday: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return years > 0
            ? l.tr(zh: "\(years)岁", en: "\(years) yrs", de: "\(years) J.")
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }

    private var readContent: some View {
        VStack(spacing: 16) {
            infoSection(title: l.tr(zh: "基本信息", en: "Basic Info", de: "Basisinfos"), icon: "person.fill", iconColor: Color.goPrimary) {
                infoRow(label: l.tr(zh: "名字", en: "Name", de: "Name"), value: human.name)
                infoRow(label: l.tr(zh: "权限", en: "Role", de: "Rolle"), value: localizedRoleText(for: human.role))
                infoRow(label: l.tr(zh: "性别/身份", en: "Gender / Identity", de: "Geschlecht / Identität"), value: localizedGenderTitle(for: human.genderRaw))
                if let birthday = human.birthday {
                    infoRow(label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), value: birthday.formatted(.dateTime.year().month().day()))
                    infoRow(label: l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen"), value: Human.westernZodiacDisplay(for: birthday, l: l))
                } else {
                    infoRow(label: l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), value: localizedEmptyValue)
                }
            }

            infoSection(title: l.tr(zh: "身体资料", en: "Body Info", de: "Körperdaten"), icon: "heart.text.square.fill", iconColor: Color.goRed) {
                infoRow(label: l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), value: human.bloodType.isEmpty ? localizedEmptyValue : human.bloodType)
                infoRow(label: l.tr(zh: "身高", en: "Height", de: "Größe"), value: human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f cm", human.heightCm) : localizedEmptyValue)
                infoRow(label: "MBTI", value: human.mbti.isEmpty ? localizedEmptyValue : human.mbti.uppercased())
            }

            infoSection(title: l.tr(zh: "家庭与位置", en: "Family & Location", de: "Familie & Standort"), icon: "house.fill", iconColor: Color.goTeal) {
                infoRow(label: l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), value: human.nationality.isEmpty ? localizedEmptyValue : human.nationality)
                infoRow(label: l.tr(zh: "现居地", en: "Residence", de: "Wohnort"), value: human.city.isEmpty ? localizedEmptyValue : human.city)
                infoRow(label: l.tr(zh: "加入时间", en: "Joined", de: "Beigetreten"), value: human.createdAt.formatted(.dateTime.year().month().day()))
                infoRow(label: l.tr(zh: "相处天数", en: "Days Together", de: "Gemeinsame Tage"), value: l.tr(zh: "\(daysTogether) 天", en: "\(daysTogether) days", de: "\(daysTogether) Tage"))
            }

            if HumanLocalPrivacyPolicy.isEnabled {
                infoSection(title: l.tr(zh: "隐私", en: "Privacy", de: "Datenschutz"), icon: "lock.shield.fill", iconColor: Color.goYellow) {
                    infoRow(label: l.tr(zh: "隐私项目", en: "Private Fields", de: "Private Felder"), value: privacySummary)
                }
            }

            infoSection(title: l.tr(zh: "主题色", en: "Theme Color", de: "Designfarbe"), icon: "paintpalette.fill", iconColor: Color(hex: human.safeThemeColorHex)) {
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
                infoSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
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
            editSection(title: l.tr(zh: "基本信息", en: "Basic Info", de: "Basisinfos"), icon: "person.fill", iconColor: Color.goPrimary) {
                editField(l.tr(zh: "名字", en: "Name", de: "Name"), text: $eName)
                Divider().opacity(0.1)
                editField(l.tr(zh: "头像 Emoji", en: "Avatar Emoji", de: "Avatar-Emoji"), text: $eAvatarEmoji)
                Divider().opacity(0.1)
                HStack {
                    editLabel(l.tr(zh: "权限", en: "Role", de: "Rolle"))
                    Spacer()
                    Picker("", selection: $eRole) {
                        Text(l.tr(zh: "管理者", en: "Owner", de: "Verwaltung")).tag("owner")
                        Text(l.tr(zh: "成员", en: "Member", de: "Mitglied")).tag("member")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
                Divider().opacity(0.1)
                HStack {
                    editLabel(l.tr(zh: "性别/身份", en: "Gender / Identity", de: "Geschlecht / Identität"))
                    Spacer()
                    Picker("", selection: $eGender) {
                        ForEach(genderOptions, id: \.key) { option in
                            Text(localizedGenderTitle(for: option.key)).tag(option.key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 180, alignment: .trailing)
                }
                Divider().opacity(0.1)
                Toggle(isOn: $eHasBirthday) {
                    editLabel(l.tr(zh: "设置生日", en: "Set Birthday", de: "Geburtstag festlegen"))
                }
                .tint(Color.goPrimary)
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                }
            }

            editSection(title: l.tr(zh: "身体资料", en: "Body Info", de: "Körperdaten"), icon: "heart.text.square.fill", iconColor: Color.goRed) {
                optionChipGrid(title: l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), selection: $eBloodType, options: bloodTypeOptions, accent: Color.goRed)
                Divider().opacity(0.1)
                heightStepperRow
                Divider().opacity(0.1)
                optionChipGrid(title: "MBTI", selection: $eMBTI, options: mbtiOptions, accent: Color.goOrange)
            }

            editSection(title: l.tr(zh: "家庭与位置", en: "Family & Location", de: "Familie & Standort"), icon: "house.fill", iconColor: Color.goTeal) {
                optionPickerRow(l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), selection: $eNationality, options: countryOptions)
                Divider().opacity(0.1)
                optionPickerRow(l.tr(zh: "现居地", en: "Residence", de: "Wohnort"), selection: $eCity, options: residenceCityOptions)
            }

            if HumanLocalPrivacyPolicy.isEnabled {
                editSection(title: l.tr(zh: "隐私设置", en: "Privacy Settings", de: "Datenschutzeinstellungen"), icon: "lock.shield.fill", iconColor: Color.goYellow) {
                    privacyToggle(l.tr(zh: "体重记录", en: "Weight Records", de: "Gewichtsverlauf"), isOn: $ePrivateWeight)
                    privacyToggle(l.tr(zh: "运动记录", en: "Workout Records", de: "Trainingseinträge"), isOn: $ePrivateWorkout)
                    privacyToggle(l.tr(zh: "吃药提醒", en: "Medication Reminders", de: "Medikamentenerinnerungen"), isOn: $ePrivateMedication)
                    privacyToggle(l.tr(zh: "备注", en: "Notes", de: "Notizen"), isOn: $ePrivateNote)
                    privacyToggle(l.tr(zh: "椰子资产与心愿", en: "Coconut Assets & Wishes", de: "Kokosnussvermögen & Wünsche"), isOn: $ePrivateWishlist)
                    privacyToggle(l.tr(zh: "花费记录", en: "Expense Records", de: "Ausgabeneinträge"), isOn: $ePrivateExpense)
                }
            }

            editSection(title: l.tr(zh: "主题色", en: "Theme Color", de: "Designfarbe"), icon: "paintpalette.fill", iconColor: Color(hex: eThemeColorHex)) {
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

            editSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
                TextEditor(text: $eNotes)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                    .accessibilityIdentifier("human-basic-info-notes-input")
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
        var options = [""] + PetBreedDatabase.countries
        if !eNationality.isEmpty, !options.contains(eNationality) {
            options.insert(eNationality, at: 1)
        }
        return options
    }

    private var residenceCityOptions: [String] {
        let base = eNationality.isEmpty
            ? [""]
            : [""] + PetBreedDatabase.cities(for: eNationality)
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
                editLabel(l.tr(zh: "身高", en: "Height", de: "Größe"))
                Spacer()
                Text(heightValue > 0 ? "\(Int(heightValue)) cm" : localizedEmptyValue)
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
            }
            HStack(spacing: 8) {
                ForEach(["", "160", "165", "170", "175", "180"], id: \.self) { option in
                    Button {
                        eHeightText = option
                    } label: {
                        Text(option.isEmpty ? localizedEmptyValue : "\(option)")
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
                Text(l.tr(zh: "微调 80-230 cm", en: "Fine tune 80-230 cm", de: "Feinabstimmung 80-230 cm"))
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func heightOptionSelected(_ option: String) -> Bool {
        guard let optionValue = Int(option) else {
            return eHeightText.isEmpty
        }
        return Int(heightValue) == optionValue
    }

    private func optionPickerRow(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        HStack {
            editLabel(title)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(localizedOptionTitle(option)).tag(option)
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
                    let selected = (selection.wrappedValue.isEmpty && option.isEmpty) || selection.wrappedValue.uppercased() == option
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text(localizedOptionTitle(option))
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
            .map(localizedPrivateFieldTitle)
        return titles.isEmpty ? l.tr(zh: "全部公开", en: "All visible", de: "Alles sichtbar") : titles.joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
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
        eGender = HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? ""
        eBirthday = human.birthday ?? Date()
        eHasBirthday = human.birthday != nil
        eBloodType = human.bloodType
        eHeightText = human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f", human.heightCm) : ""
        eMBTI = human.mbti
        eNationality = human.nationality
        eCity = human.city
        eThemeColorHex = human.safeThemeColorHex
        eNotes = displayNotes
        ePrivateWeight = human.privateFields.contains(HumanPrivateField.weight.rawValue)
        ePrivateWorkout = human.privateFields.contains(HumanPrivateField.workout.rawValue)
        ePrivateMedication = human.privateFields.contains(HumanPrivateField.medication.rawValue)
        ePrivateWishlist = human.privateFields.contains(HumanPrivateField.wishlist.rawValue)
        ePrivateExpense = human.privateFields.contains(HumanPrivateField.expense.rawValue)
        ePrivateNote = human.privateFields.contains(HumanPrivateField.note.rawValue)
    }

    private func saveChanges() {
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
            shouldShowOnHome: true,
            privateFieldsRaw: HumanLocalPrivacyPolicy.isEnabled ? editedPrivateFieldsRaw : nil
        )
        commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                human,
                input: input,
                note: "humanBasicInfo.profile"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { isEditing = false }
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

    private var localizedEmptyValue: String {
        l.tr(zh: "未填写", en: "Not set", de: "Nicht festgelegt")
    }

    private func localizedOptionTitle(_ option: String) -> String {
        option.isEmpty ? localizedEmptyValue : option
    }

    private func localizedRoleText(for raw: String) -> String {
        HumanProfileOptions.localizedRoleTitle(raw, l: l)
    }

    private func localizedGenderTitle(for raw: String) -> String {
        let title = HumanProfileOptions.localizedGenderTitle(raw, l: l)
        return title.isEmpty ? localizedEmptyValue : title
    }

    private func localizedPrivateFieldTitle(_ field: HumanPrivateField) -> String {
        switch field {
        case .weight:
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .workout:
            l.tr(zh: "运动", en: "Workouts", de: "Training")
        case .medication:
            l.tr(zh: "吃药提醒", en: "Medication", de: "Medikamente")
        case .wishlist:
            l.tr(zh: "椰子资产与心愿", en: "Coconut Assets & Wishes", de: "Kokosnussvermögen & Wünsche")
        case .expense:
            l.tr(zh: "花费", en: "Expenses", de: "Ausgaben")
        case .note:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
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
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            if case .pending = result.attachmentCleanup {
                appServices.islandToasts.show(l.tr(
                    zh: "成员已删除，但其本地备注附件未能完全清理。请联系支持。",
                    en: "The member was deleted, but local note attachments could not be fully removed. Contact support.",
                    de: "Das Mitglied wurde gelöscht, aber lokale Notizanhänge konnten nicht vollständig entfernt werden. Kontaktiere den Support."
                ))
            }
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
            let result = MemberCommandExecutor(context: modelContext, services: appServices).markHumanPassedAway(
                human,
                date: date,
                note: "humanBasicInfo.passed.mark"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
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
            let result = MemberCommandExecutor(context: modelContext, services: appServices).undoHumanPassedAway(
                human,
                note: "humanBasicInfo.passed.undo"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }
}

struct HumanLifecycleDangerZone: View {
    private static let deleteAfterSheetDismissDelayMilliseconds: UInt64 = 180

    let human: Human
    let onMarkPassedAway: (Date) -> Void
    let onUndoPassedAway: () -> Void
    let onDelete: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var passedDate = Date()
    @State private var showingPassedAlert = false
    @State private var showingUndoPassedAlert = false
    @State private var showingDeleteSheet = false
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(Color.goRed.opacity(0.72))
                Text(l.tr(zh: "生命与危险操作", en: "Life & Danger Actions", de: "Lebens- & Gefahrenaktionen"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goRed.opacity(0.78))
                    .tracking(1.2)
                Spacer(minLength: 0)
            }

            if human.hasPassedAway {
                passedAwaySummary
                lifecycleButton(
                    title: l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Verstorben-Markierung zurücknehmen"),
                    icon: "arrow.uturn.backward",
                    color: Color.goYellow,
                    identifier: "human-memorial-undo-action"
                ) {
                    showingUndoPassedAlert = true
                }
            } else {
                DatePicker(l.tr(zh: "离世日期", en: "Date of Passing", de: "Sterbedatum"), selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                lifecycleButton(
                    title: l.tr(zh: "标记 \(human.name) 已离世", en: "Mark \(human.name) as passed away", de: "\(human.name) als verstorben markieren"),
                    icon: "rainbow",
                    color: Color.goPurple,
                    identifier: "human-memorial-mark-action"
                ) {
                    showingPassedAlert = true
                }
            }

            lifecycleButton(
                title: l.tr(zh: "彻底删除 \(human.name)", en: "Permanently delete \(human.name)", de: "\(human.name) endgültig löschen"),
                icon: "trash.fill",
                color: Color.goRed,
                identifier: "human-danger-delete-action"
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
        .alert(l.tr(zh: "确认标记离世", en: "Confirm Passing Mark", de: "Verstorben-Markierung bestätigen"), isPresented: $showingPassedAlert) {
            Button(l.tr(zh: "确认", en: "Confirm", de: "Bestätigen"), role: .destructive) {
                onMarkPassedAway(passedDate)
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "将标记 \(human.name) 为离世，并让未来安排退出活跃提醒。原有数据会保留，此操作可撤销。",
                en: "\(human.name) will be marked as passed away, and future schedules will leave active reminders. Existing data is kept, and this can be undone.",
                de: "\(human.name) wird als verstorben markiert, und zukünftige Termine verlassen aktive Erinnerungen. Bestehende Daten bleiben erhalten und dies kann rückgängig gemacht werden."
            ))
        }
        .alert(l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Verstorben-Markierung zurücknehmen"), isPresented: $showingUndoPassedAlert) {
            Button(l.tr(zh: "撤销", en: "Undo", de: "Zurücknehmen"), role: .destructive) {
                onUndoPassedAway()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "将清除 \(human.name) 的离世记录，恢复为在世状态。",
                en: "\(human.name)'s passing record will be cleared and restored to active status.",
                de: "Der Verstorben-Eintrag von \(human.name) wird gelöscht und der aktive Status wiederhergestellt."
            ))
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
                Text(l.tr(
                    zh: "离世日期：\(date.formatted(.dateTime.year().month().day()))",
                    en: "Date of passing: \(date.formatted(.dateTime.year().month().day()))",
                    de: "Sterbedatum: \(date.formatted(.dateTime.year().month().day()))"
                ))
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
            }
            Text(l.tr(
                zh: "相伴 \(human.daysTogetherAtPassing) 天 · \(human.ageAtPassingText)",
                en: "Together for \(human.daysTogetherAtPassing) days · \(localizedAgeAtPassing)",
                de: "\(human.daysTogetherAtPassing) Tage zusammen · \(localizedAgeAtPassing)"
            ))
                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.goPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            .strokeBorder(Color.goPurple.opacity(0.22), lineWidth: 1))
        .accessibilityIdentifier("human-memorial-passed-date")
    }

    private func lifecycleButton(
        title: String,
        icon: String,
        color: Color,
        identifier: String,
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
        .accessibilityIdentifier(identifier)
    }

    private var localizedAgeAtPassing: String {
        guard let birthday = human.birthday,
              let passed = human.passedAwayDate else {
            return l.tr(zh: "未知年龄", en: "Unknown age", de: "Unbekanntes Alter")
        }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: passed).year ?? 0
        return years > 0
            ? l.tr(zh: "\(years)岁", en: "\(years) yrs", de: "\(years) J.")
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }
}

private struct HumanDeleteConfirmationSheet: View {
    let humanName: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var confirmName = ""
    @FocusState private var confirmNameFocused: Bool
    private var l: L10n { L10n(appLanguage) }

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
                        Text(l.tr(zh: "删除成员 \(humanName)", en: "Delete member \(humanName)", de: "Mitglied \(humanName) löschen"))
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "输入名字后才能继续", en: "Enter the name to continue", de: "Namen eingeben, um fortzufahren"))
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
                    .accessibilityIdentifier("human-delete-confirm-close")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(
                        zh: "这会删除成员资料、体重与运动记录，无法撤销。",
                        en: "This deletes the member profile, weight records, and workout records. It cannot be undone.",
                        de: "Dies löscht Mitgliederprofil, Gewichtseinträge und Trainingseinträge. Es kann nicht rückgängig gemacht werden."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))
                    Text(l.tr(zh: "请输入：\(humanName)", en: "Enter: \(humanName)", de: "Eingeben: \(humanName)"))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed.opacity(0.8))
                }

                TextField(l.tr(zh: "成员名字", en: "Member name", de: "Mitgliedsname"), text: $confirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
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
                    .accessibilityIdentifier("human-delete-confirm-name-input")

                HStack(spacing: 10) {
                    Button(action: cancelAfterResigningKeyboard) {
                        Text(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("human-delete-confirm-cancel")

                    Button(action: attemptDelete) {
                        Text(l.tr(zh: "删除", en: "Delete", de: "Löschen"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(canDelete ? Color.white : Color.ohanaTertiaryText) // ui-v4: allow destructive red button needs white contrast
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canDelete ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                    .accessibilityIdentifier("human-delete-confirm-delete")
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
