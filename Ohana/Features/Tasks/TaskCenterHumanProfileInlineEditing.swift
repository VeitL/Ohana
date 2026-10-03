//
//  TaskCenterHumanProfileInlineEditing.swift
//  Ohana
//
//  Compact, in-card editing for the Human starter-profile journey.
//

import Foundation
import SwiftUI
import UIKit

nonisolated enum TaskCenterProfileDecimalText {
    static func preserving(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let text = String(value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }
}

nonisolated enum TaskCenterHumanProfileInlineUpdate: Equatable, Sendable {
    case avatarImageData(Data?)
    case birthday(Date)
    case gender(String)
    case optionalDetails(bloodType: String, heightText: String, notes: String)
}

nonisolated enum TaskCenterHumanProfileInlineNormalization {
    static func bloodType(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "未填写" ? "" : trimmed
    }

    static func heightText(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let number = Double(normalized), number.isFinite else { return normalized }
        return TaskCenterProfileDecimalText.preserving(number)
    }

    static func notes(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func pendingUpdate(
        _ candidate: TaskCenterHumanProfileInlineUpdate?,
        lastSuccessfulUpdate: TaskCenterHumanProfileInlineUpdate?
    ) -> TaskCenterHumanProfileInlineUpdate? {
        candidate == lastSuccessfulUpdate ? nil : candidate
    }
}

@MainActor
enum TaskCenterHumanProfileInlineInputBuilder {
    static func input(
        for human: Human,
        applying update: TaskCenterHumanProfileInlineUpdate
    ) -> HumanProfileCommandInput {
        var avatarImageData = human.avatarImageData
        var birthday = human.birthday
        var gender = HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? ""
        var bloodType = human.bloodType
        var heightText = human.heightCm > 0 && human.heightCm.isFinite
            ? TaskCenterProfileDecimalText.preserving(human.heightCm)
            : ""
        var notes = HumanProfileOptions.visibleNoteParts(from: human.notes)
            .joined(separator: "｜")

        switch update {
        case let .avatarImageData(data):
            avatarImageData = data
        case let .birthday(value):
            birthday = Calendar.current.startOfDay(for: value)
        case let .gender(value):
            gender = value
        case let .optionalDetails(nextBloodType, nextHeightText, nextNotes):
            bloodType = TaskCenterHumanProfileInlineNormalization.bloodType(nextBloodType)
            heightText = TaskCenterHumanProfileInlineNormalization.heightText(nextHeightText)
            notes = TaskCenterHumanProfileInlineNormalization.notes(nextNotes)
        }

        return HumanProfileCommandInput(
            name: human.name,
            avatarImageData: avatarImageData,
            avatarEmoji: human.avatarEmoji,
            role: HumanProfileOptions.normalizedRole(human.role),
            gender: gender,
            birthday: birthday,
            bloodType: bloodType,
            heightText: heightText,
            mbti: human.mbti,
            nationality: human.nationality,
            city: human.city,
            themeHex: human.safeThemeColorHex,
            notes: notes,
            preservedNoteParts: preservedMetadataParts(from: human.notes)
        )
    }

    static func isSatisfied(
        _ checkpoint: HouseholdStarterJourneyCheckpoint,
        by human: Human
    ) -> Bool {
        let category: MemberProfileCompletionCategory? = switch checkpoint {
        case .humanAppearance: .humanAppearance
        case .humanLifeStage: .humanLifeStage
        case .humanBodyProfile: .humanBodyProfile
        case .humanPersonalityContext, .humanOptionalDetails: .humanPersonalityContext
        default: nil
        }
        guard let category else { return false }
        return MemberProfileCompletenessPolicy.humanActualCategories(human).contains(category)
    }

    private static func preservedMetadataParts(from notes: String) -> [String] {
        notes
            .split(separator: "｜", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.hasPrefix("关系:") }
    }
}

struct TaskCenterHumanProfileInlineEditor: View {
    let checkpoint: HouseholdStarterJourneyCheckpoint
    let human: Human
    let onSave: (TaskCenterHumanProfileInlineUpdate) -> TaskCenterSystemJourneyMutationOutcome
    let onCancel: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var avatarImageData: Data?
    @State private var birthday: Date
    @State private var gender: String
    @State private var bloodType: String
    @State private var heightText: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var didSaveSuccessfully = false
    @State private var saveErrorMessage: String?
    @State private var lastSuccessfulUpdate: TaskCenterHumanProfileInlineUpdate?

    private let bloodTypeOptions = ["", "A", "B", "AB", "O"]

    init(
        checkpoint: HouseholdStarterJourneyCheckpoint,
        human: Human,
        onSave: @escaping (TaskCenterHumanProfileInlineUpdate) -> TaskCenterSystemJourneyMutationOutcome,
        onCancel: @escaping () -> Void
    ) {
        self.checkpoint = checkpoint
        self.human = human
        self.onSave = onSave
        self.onCancel = onCancel
        _avatarImageData = State(initialValue: human.avatarImageData)
        _birthday = State(initialValue: human.birthday ?? Self.defaultBirthday)
        _gender = State(
            initialValue: HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? ""
        )
        _bloodType = State(initialValue: human.bloodType)
        _heightText = State(
            initialValue: human.heightCm > 0 && human.heightCm.isFinite
                ? TaskCenterProfileDecimalText.preserving(human.heightCm)
                : ""
        )
        _notes = State(
            initialValue: HumanProfileOptions.visibleNoteParts(from: human.notes)
                .joined(separator: "｜")
        )
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            editorContent
            actionRow
        }
        .padding(14)
        .background(
            Color.goPrimary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.18), lineWidth: 1)
        }
        .onChange(of: pendingUpdate) { _, update in
            guard !isSaving else { return }
            if update != nil {
                didSaveSuccessfully = false
            }
            saveErrorMessage = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task-center-human-profile-inline-editor-\(checkpoint.rawValue)")
    }

    @ViewBuilder
    private var editorContent: some View {
        switch checkpoint {
        case .humanAppearance:
            EditableProfileAvatarPicker(
                avatarImageData: $avatarImageData,
                fallbackEmoji: human.avatarEmoji,
                accentColor: Color(hex: human.safeThemeColorHex),
                cropSpecies: "",
                silhouetteSystemName: "person.fill"
            )
        case .humanLifeStage:
            VStack(alignment: .leading, spacing: 10) {
                DatePicker(
                    MemberProfileCompletionCategory.humanLifeStage.localizedTitle(l),
                    selection: $birthday,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(Color.goPrimary)
                .accessibilityIdentifier("task-center-human-profile-inline-birthday")

                HStack(spacing: 8) {
                    Image(systemName: "sparkles") // a11y: allow decorative zodiac glyph; hidden by the chained modifier below
                        .foregroundStyle(Color.goPrimary)
                        .accessibilityHidden(true)
                    Text(l.tr(
                        zh: "星座", en: "Zodiac", de: "Sternzeichen",
                        es: "Signo", pt: "Signo", fr: "Signe",
                        ja: "星座", ko: "별자리", it: "Segno"
                    ))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer(minLength: 8)
                    Text(Human.westernZodiacDisplay(for: birthday, l: l))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .font(OhanaFont.callout(.semibold))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("task-center-human-profile-inline-zodiac")
            }
        case .humanBodyProfile:
            genderSelectionButtons
        case .humanPersonalityContext, .humanOptionalDetails:
            optionalDetailsEditor
        default:
            EmptyView()
        }
    }

    private var genderSelectionButtons: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(MemberProfileCompletionCategory.humanBodyProfile.localizedTitle(l))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 148), spacing: 8)],
                spacing: 8
            ) {
                ForEach(HumanProfileOptions.genderOptions.filter { !$0.key.isEmpty }, id: \.key) { option in
                    let isSelected = HumanProfileOptions.storedGenderIdentity(gender) == option.key
                    Button {
                        gender = option.key
                        OhanaFeedback.selection()
                    } label: {
                        HStack(spacing: 7) {
                            Text(option.icon)
                                .accessibilityHidden(true)
                            Text(HumanProfileOptions.localizedGenderTitle(option.key, l: l))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if isSelected {
                                Image(systemName: "checkmark") // a11y: allow decorative selection glyph; hidden by the chained modifier below
                                    .font(OhanaFont.caption(.black))
                                    .accessibilityHidden(true)
                            }
                        }
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaPrimaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            isSelected ? Color.goPrimary.opacity(0.14) : Color.ohanaCardSurface,
                            in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.goPrimary.opacity(0.64) : Color.ohanaCardStroke,
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("task-center-human-profile-inline-gender-\(option.key)")
                }
            }
        }
        .accessibilityIdentifier("task-center-human-profile-inline-gender")
    }

    private var optionalDetailsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(
                l.tr(
                    zh: "血型", en: "Blood type", de: "Blutgruppe",
                    es: "Grupo sanguíneo", pt: "Tipo sanguíneo", fr: "Groupe sanguin",
                    ja: "血液型", ko: "혈액형", it: "Gruppo sanguigno"
                ),
                selection: $bloodType
            ) {
                ForEach(bloodTypeOptions, id: \.self) { option in
                    Text(option.isEmpty ? localizedNotSet : option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("task-center-human-profile-inline-blood-type")

            TextField(
                l.tr(
                    zh: "身高（cm）", en: "Height (cm)", de: "Größe (cm)",
                    es: "Altura (cm)", pt: "Altura (cm)", fr: "Taille (cm)",
                    ja: "身長（cm）", ko: "키(cm)", it: "Altezza (cm)"
                ),
                text: $heightText
            )
            .keyboardType(.decimalPad)
            .ohanaRoundedTextFieldStyle()
            .accessibilityIdentifier("task-center-human-profile-inline-height")

            TextField(
                l.tr(
                    zh: "想记住的事", en: "Something to remember", de: "Etwas zum Merken",
                    es: "Algo para recordar", pt: "Algo para lembrar", fr: "Quelque chose à retenir",
                    ja: "覚えておきたいこと", ko: "기억하고 싶은 것", it: "Qualcosa da ricordare"
                ),
                text: $notes,
                axis: .vertical
            )
            .lineLimit(2 ... 4)
            .ohanaRoundedTextFieldStyle()
            .accessibilityIdentifier("task-center-human-profile-inline-notes")

            if !heightIsValid {
                Text("80–230 cm")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goRed)
                    .accessibilityIdentifier("task-center-human-profile-inline-height-error")
            }
        }
        .tint(Color.goPrimary)
    }

    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if didSaveSuccessfully {
                Label(
                    l.tr(
                        zh: "已保存", en: "Saved", de: "Gespeichert",
                        es: "Guardado", pt: "Salvo", fr: "Enregistré",
                        ja: "保存済み", ko: "저장됨", it: "Salvato"
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goTeal)
                .transition(.opacity)
                .accessibilityIdentifier("task-center-human-profile-inline-saved-\(checkpoint.rawValue)")
            }

            if let saveErrorMessage {
                Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goRed)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("task-center-human-profile-inline-save-error-\(checkpoint.rawValue)")
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: 10)],
                spacing: 10
            ) {
                Button(didSaveSuccessfully ? localizedDone : l.cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .disabled(isSaving)
                    .accessibilityIdentifier("task-center-human-profile-inline-cancel-\(checkpoint.rawValue)")

                Button(action: save) {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Text(l.save)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.goPrimary)
                .disabled(pendingUpdate == nil || isSaving)
                .accessibilityLabel(isSaving ? localizedSaving : l.save)
                .accessibilityIdentifier("task-center-human-profile-inline-save-\(checkpoint.rawValue)")
            }
        }
    }

    private var pendingUpdate: TaskCenterHumanProfileInlineUpdate? {
        switch checkpoint {
        case .humanAppearance:
            guard avatarImageData != human.avatarImageData else { return nil }
            return unsaved(.avatarImageData(avatarImageData))
        case .humanLifeStage:
            let normalized = Calendar.current.startOfDay(for: birthday)
            guard human.birthday.map({ !Calendar.current.isDate($0, inSameDayAs: normalized) }) ?? true else {
                return nil
            }
            return unsaved(.birthday(normalized))
        case .humanBodyProfile:
            let normalized = HumanProfileOptions.storedGenderIdentity(gender) ?? ""
            let current = HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? ""
            guard !normalized.isEmpty, normalized != current else { return nil }
            return unsaved(.gender(normalized))
        case .humanPersonalityContext, .humanOptionalDetails:
            guard heightIsValid else { return nil }
            let update = TaskCenterHumanProfileInlineUpdate.optionalDetails(
                bloodType: TaskCenterHumanProfileInlineNormalization.bloodType(bloodType),
                heightText: TaskCenterHumanProfileInlineNormalization.heightText(heightText),
                notes: TaskCenterHumanProfileInlineNormalization.notes(notes)
            )
            let current = TaskCenterHumanProfileInlineUpdate.optionalDetails(
                bloodType: TaskCenterHumanProfileInlineNormalization.bloodType(human.bloodType),
                heightText: human.heightCm > 0 && human.heightCm.isFinite
                    ? TaskCenterProfileDecimalText.preserving(human.heightCm)
                    : "",
                notes: TaskCenterHumanProfileInlineNormalization.notes(
                    HumanProfileOptions.visibleNoteParts(from: human.notes)
                        .joined(separator: "｜")
                )
            )
            return update == current ? nil : unsaved(update)
        default:
            return nil
        }
    }

    private func unsaved(
        _ candidate: TaskCenterHumanProfileInlineUpdate
    ) -> TaskCenterHumanProfileInlineUpdate? {
        TaskCenterHumanProfileInlineNormalization.pendingUpdate(
            candidate,
            lastSuccessfulUpdate: lastSuccessfulUpdate
        )
    }

    private var heightIsValid: Bool {
        let trimmed = normalizedHeightText
        guard !trimmed.isEmpty else { return true }
        guard let value = Double(trimmed), value.isFinite else { return false }
        return (80 ... 230).contains(value)
    }

    private var normalizedHeightText: String {
        heightText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
    }

    private var localizedNotSet: String {
        l.tr(
            zh: "未设置", en: "Not set", de: "Nicht festgelegt",
            es: "Sin definir", pt: "Não definido", fr: "Non défini",
            ja: "未設定", ko: "설정 안 함", it: "Non impostato"
        )
    }

    private var localizedDone: String {
        l.tr(
            zh: "完成", en: "Done", de: "Fertig",
            es: "Listo", pt: "Concluído", fr: "Terminé",
            ja: "完了", ko: "완료", it: "Fine"
        )
    }

    private var localizedSaving: String {
        l.tr(
            zh: "正在保存", en: "Saving", de: "Wird gespeichert",
            es: "Guardando", pt: "Salvando", fr: "Enregistrement",
            ja: "保存中", ko: "저장 중", it: "Salvataggio"
        )
    }

    private func save() {
        guard let update = pendingUpdate, !isSaving else { return }
        isSaving = true
        OhanaFeedback.light()
        OhanaFrameScheduler.runAfterNextFrame {
            let outcome = onSave(update)
            isSaving = false
            switch outcome {
            case .success:
                lastSuccessfulUpdate = update
                saveErrorMessage = nil
                withAnimation(GoMotion.feedback) {
                    didSaveSuccessfully = true
                }
                OhanaFeedback.success()
                UIAccessibility.post(
                    notification: .announcement,
                    argument: l.tr(
                        zh: "资料已保存", en: "Profile saved", de: "Profil gespeichert",
                        es: "Perfil guardado", pt: "Perfil salvo", fr: "Profil enregistré",
                        ja: "プロフィールを保存しました", ko: "프로필이 저장됨", it: "Profilo salvato"
                    )
                )
            case let .failure(message):
                saveErrorMessage = message
                OhanaFeedback.error()
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
    }

    private static var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }
}
