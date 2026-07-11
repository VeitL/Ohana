//
//  EditHumanSheet.swift
//  Ohana
//

import SwiftData
import SwiftUI

// MARK: - Edit Human Sheet
struct EditHumanSheet: View {
    let human: Human
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name: String = ""
    @State private var avatarEmoji: String = ""
    @State private var birthday: Date = .init()
    @State private var hasBirthday = false
    @State private var bloodType: String = ""
    @State private var role: String = "owner"
    @State private var gender: String = ""
    @State private var notes: String = ""
    @State private var nationality: String = ""
    @State private var city: String = ""
    // FIX 1: 隐私设置
    @State private var privateWeight = false
    @State private var privateWorkout = false
    @State private var privateMedication = false
    @State private var privateWishlist = false
    @State private var privateExpense = false
    @State private var privateNote = false

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        OhanaSheetWrapper(title: l.tr(zh: "编辑成员", en: "Edit Member", de: "Mitglied bearbeiten"), onDismiss: { dismiss() }) {
            VStack(spacing: 16) {
                formField(l.tr(zh: "姓名", en: "Name", de: "Name"), text: $name)
                formField(l.tr(zh: "头像 Emoji", en: "Avatar Emoji", de: "Avatar-Emoji"), text: $avatarEmoji)

                Toggle(l.tr(zh: "设置生日", en: "Set Birthday", de: "Geburtstag festlegen"), isOn: $hasBirthday)
                    .tint(Color.goPrimary)
                    .padding(.horizontal, 4)

                if hasBirthday {
                    DatePicker(l.tr(zh: "生日", en: "Birthday", de: "Geburtstag"), selection: $birthday, displayedComponents: .date)
                }

                formField(l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), text: $bloodType)
                formField(l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"), text: $nationality)
                formField(l.tr(zh: "城市", en: "City", de: "Stadt"), text: $city)

                Picker(l.tr(zh: "角色", en: "Role", de: "Rolle"), selection: $role) {
                    Text(l.tr(zh: "管理者", en: "Owner", de: "Verwaltung")).tag("owner")
                    Text(l.tr(zh: "成员", en: "Member", de: "Mitglied")).tag("member")
                }
                .pickerStyle(.segmented)

                Picker(l.tr(zh: "性别/身份", en: "Gender / Identity", de: "Geschlecht / Identität"), selection: $gender) {
                    ForEach(HumanProfileOptions.genderOptions, id: \.key) { option in
                        Text(localizedGenderTitle(for: option.key)).tag(option.key)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "备注", en: "Notes", de: "Notizen"))
                        .font(OhanaFont.subheadline())
                        .foregroundStyle(Color.ohanaSecondaryText)
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.chip))
                }

                if HumanLocalPrivacyPolicy.isEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(l.tr(zh: "🔒  隐私设置", en: "🔒  Privacy Settings", de: "🔒  Datenschutzeinstellungen"))
                            .font(OhanaFont.subheadline())
                            .foregroundStyle(Color.ohanaSecondaryText)
                        editPrivacyRow(l.tr(zh: "体重记录", en: "Weight Records", de: "Gewichtsverlauf"), binding: $privateWeight)
                        editPrivacyRow(l.tr(zh: "运动记录", en: "Workout Records", de: "Trainingseinträge"), binding: $privateWorkout)
                        editPrivacyRow(l.tr(zh: "吃药提醒", en: "Medication Reminders", de: "Medikamentenerinnerungen"), binding: $privateMedication)
                        editPrivacyRow(l.tr(zh: "备注", en: "Notes", de: "Notizen"), binding: $privateNote)
                        editPrivacyRow(l.tr(zh: "心愿单", en: "Wishlist", de: "Wunschliste"), binding: $privateWishlist)
                        editPrivacyRow(l.tr(zh: "花费记录", en: "Expense Records", de: "Ausgabeneinträge"), binding: $privateExpense)
                    }
                }

                Button {
                    save()
                } label: {
                    Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                        .capsuleButton()
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            name = human.name
            avatarEmoji = human.avatarEmoji
            birthday = human.birthday ?? Date()
            hasBirthday = human.birthday != nil
            bloodType = human.bloodType
            role = HumanProfileOptions.normalizedRole(human.role)
            gender = HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? ""
            notes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            nationality = human.nationality
            city = human.city
            // FIX 1: 加载隐私设置
            let fields = human.privateFields
            privateWeight = fields.contains(HumanPrivateField.weight.rawValue)
            privateWorkout = fields.contains(HumanPrivateField.workout.rawValue)
            privateMedication = fields.contains(HumanPrivateField.medication.rawValue)
            privateNote = fields.contains(HumanPrivateField.note.rawValue)
            privateWishlist = fields.contains(HumanPrivateField.wishlist.rawValue)
            privateExpense = fields.contains(HumanPrivateField.expense.rawValue)
        }
    }

    private func formField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OhanaFont.subheadline())
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                .textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        let input = HumanProfileCommandInput(
            name: name,
            avatarImageData: human.avatarImageData,
            avatarEmoji: avatarEmoji,
            role: role,
            gender: gender,
            birthday: hasBirthday ? birthday : nil,
            bloodType: bloodType,
            heightText: human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f", human.heightCm) : "",
            mbti: human.mbti,
            nationality: nationality,
            city: city,
            themeHex: human.safeThemeColorHex,
            notes: notes,
            preservedNoteParts: preservedRelationshipMetadataParts,
            privateFieldsRaw: HumanLocalPrivacyPolicy.isEnabled ? editedPrivateFieldsRaw : nil
        )
        commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                human,
                input: input,
                note: "human.detail.profile"
            )
            guard result.didPersist else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    private var preservedRelationshipMetadataParts: [String] {
        human.notes
            .split(separator: "｜", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.hasPrefix("关系:") }
    }

    private var editedPrivateFieldsRaw: Set<String> {
        var fields = Set<String>()
        if privateWeight { fields.insert(HumanPrivateField.weight.rawValue) }
        if privateWorkout { fields.insert(HumanPrivateField.workout.rawValue) }
        if privateMedication { fields.insert(HumanPrivateField.medication.rawValue) }
        if privateNote { fields.insert(HumanPrivateField.note.rawValue) }
        if privateWishlist { fields.insert(HumanPrivateField.wishlist.rawValue) }
        if privateExpense { fields.insert(HumanPrivateField.expense.rawValue) }
        return fields
    }

    private func localizedGenderTitle(for raw: String) -> String {
        let title = HumanProfileOptions.localizedGenderTitle(raw, l: l)
        return title.isEmpty ? l.notSet : title
    }

    private func editPrivacyRow(_ title: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Toggle("", isOn: binding).tint(Color.goPrimary).labelsHidden()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
    }
}
