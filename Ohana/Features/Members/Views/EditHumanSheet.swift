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

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var name: String = ""
    @State private var avatarEmoji: String = ""
    @State private var birthday: Date = .init()
    @State private var hasBirthday = false
    @State private var bloodType: String = ""
    @State private var role: String = "owner"
    @State private var gender: String = "不透露"
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

    var body: some View {
        OhanaSheetWrapper(title: "编辑成员", onDismiss: { dismiss() }) {
            VStack(spacing: 16) {
                formField("姓名", text: $name)
                formField("头像 Emoji", text: $avatarEmoji)

                Toggle("设置生日", isOn: $hasBirthday)
                    .tint(Color.goPrimary)
                    .padding(.horizontal, 4)

                if hasBirthday {
                    DatePicker("生日", selection: $birthday, displayedComponents: .date)
                }

                formField("血型", text: $bloodType)
                formField("国籍", text: $nationality)
                formField("城市", text: $city)

                Picker("角色", selection: $role) {
                    Text("管理者").tag("owner")
                    Text("成员").tag("member")
                }
                .pickerStyle(.segmented)

                Picker("性别/身份", selection: $gender) {
                    ForEach(HumanProfileOptions.genderOptions, id: \.key) { option in
                        Text(HumanGenderIdentity.title(for: option.key)).tag(option.key)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text("备注")
                        .font(OhanaFont.subheadline())
                        .foregroundStyle(Color.ohanaSecondaryText)
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.chip))
                }

                // FIX 1: 隐私设置 Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("🔒  隐私设置")
                        .font(OhanaFont.subheadline())
                        .foregroundStyle(Color.ohanaSecondaryText)
                    editPrivacyRow("体重记录", binding: $privateWeight)
                    editPrivacyRow("运动记录", binding: $privateWorkout)
                    editPrivacyRow("吃药提醒", binding: $privateMedication)
                    editPrivacyRow("备注", binding: $privateNote)
                    editPrivacyRow("心愿单", binding: $privateWishlist)
                    editPrivacyRow("花费记录", binding: $privateExpense)
                }

                Button {
                    save()
                } label: {
                    Text("保存")
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
            gender = human.genderRaw.isEmpty ? "不透露" : human.genderRaw
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
            privateFieldsRaw: editedPrivateFieldsRaw
        )
        commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                human,
                input: input,
                note: "human.detail.profile"
            )
            appServices.domainRevisions.publishMemberProfile(result, note: "human.detail.profile")
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
