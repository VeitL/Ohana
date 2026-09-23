//
//  TaskCenterPetProfileInlineEditing.swift
//  Ohana
//
//  Compact, in-card editing for the Pet starter-profile journey.
//

import Foundation
import SwiftUI
import UIKit

nonisolated enum TaskCenterPetProfileInlineCopy {
    static func birthday(_ l: L10n) -> String {
        l.tr(
            zh: "生日", en: "Birthday", de: "Geburtstag",
            es: "Cumpleaños", pt: "Aniversário", fr: "Anniversaire",
            ja: "誕生日", ko: "생일", it: "Compleanno"
        )
    }

    static func homeDate(_ l: L10n) -> String {
        l.tr(
            zh: "到家日", en: "Home date", de: "Einzugsdatum",
            es: "Fecha de llegada", pt: "Data de chegada", fr: "Date d’arrivée",
            ja: "お迎え日", ko: "입양일", it: "Data di arrivo"
        )
    }

    static func boy(_ l: L10n) -> String {
        l.tr(
            zh: "♂ 男孩", en: "♂ Boy", de: "♂ Junge",
            es: "♂ Macho", pt: "♂ Macho", fr: "♂ Mâle",
            ja: "♂ 男の子", ko: "♂ 남아", it: "♂ Maschio"
        )
    }

    static func girl(_ l: L10n) -> String {
        l.tr(
            zh: "♀ 女孩", en: "♀ Girl", de: "♀ Mädchen",
            es: "♀ Hembra", pt: "♀ Fêmea", fr: "♀ Femelle",
            ja: "♀ 女の子", ko: "♀ 여아", it: "♀ Femmina"
        )
    }

    static func coatColor(_ l: L10n) -> String {
        l.tr(
            zh: "毛色（可选）", en: "Coat color (optional)", de: "Fellfarbe (optional)",
            es: "Color del pelaje (opcional)", pt: "Cor da pelagem (opcional)", fr: "Couleur du pelage (facultatif)",
            ja: "毛色（任意）", ko: "털 색상(선택)", it: "Colore del mantello (facoltativo)"
        )
    }

    static func foodBrand(_ l: L10n) -> String {
        l.tr(
            zh: "粮食品牌", en: "Food brand", de: "Futtermarke",
            es: "Marca de alimento", pt: "Marca da ração", fr: "Marque d’aliment",
            ja: "フードブランド", ko: "사료 브랜드", it: "Marca del cibo"
        )
    }

    static func dailyPortion(_ l: L10n) -> String {
        l.tr(
            zh: "每日份量（克）", en: "Daily portion (g)", de: "Tagesportion (g)",
            es: "Porción diaria (g)", pt: "Porção diária (g)", fr: "Portion quotidienne (g)",
            ja: "1日の量（g）", ko: "하루 급여량(g)", it: "Porzione giornaliera (g)"
        )
    }

    static func invalidPortion(_ l: L10n) -> String {
        l.tr(
            zh: "请输入大于 0 的数字", en: "Enter a number greater than 0", de: "Zahl größer als 0 eingeben",
            es: "Introduce un número mayor que 0", pt: "Insira um número maior que 0", fr: "Saisissez un nombre supérieur à 0",
            ja: "0より大きい数値を入力", ko: "0보다 큰 숫자를 입력하세요", it: "Inserisci un numero maggiore di 0"
        )
    }

    static func saved(_ l: L10n) -> String {
        l.tr(
            zh: "已保存", en: "Saved", de: "Gespeichert",
            es: "Guardado", pt: "Salvo", fr: "Enregistré",
            ja: "保存済み", ko: "저장됨", it: "Salvato"
        )
    }

    static func exactValues(_ l: L10n) -> [String] {
        [
            birthday(l), homeDate(l), boy(l), girl(l), coatColor(l),
            foodBrand(l), dailyPortion(l), invalidPortion(l), saved(l)
        ]
    }
}

nonisolated enum TaskCenterPetProfileInlineUpdate: Equatable, Sendable {
    case lifeStage(birthday: Date?, homeDate: Date?)
    case bodyProfile(gender: String, coatColor: String)
    case personality(primaryTagID: String)
    case dailyCare(foodBrand: String, dailyPortionGrams: Double?)
}

@MainActor
enum TaskCenterPetProfileInlineInputBuilder {
    static func input(
        for pet: Pet,
        applying update: TaskCenterPetProfileInlineUpdate
    ) -> PetProfileCommandInput {
        var birthday = pet.birthday
        var homeDate = pet.homeDate
        var gender = Pet.canonicalSex(pet.gender) ?? pet.gender
        var coatColor = pet.coatColor
        var personalityTagIDs = pet.personalityTagIdList
        var foodBrand = pet.foodBrand
        var dailyPortionGrams: Double? = pet.dailyPortionGrams > 0
            ? pet.dailyPortionGrams
            : nil

        switch update {
        case let .lifeStage(nextBirthday, nextHomeDate):
            birthday = nextBirthday.map { Calendar.current.startOfDay(for: $0) }
            homeDate = nextHomeDate.map { Calendar.current.startOfDay(for: $0) }
        case let .bodyProfile(nextGender, nextCoatColor):
            gender = nextGender
            coatColor = nextCoatColor
        case let .personality(primaryTagID):
            personalityTagIDs = PetPrimaryPersonalitySelection.replacingPrimary(
                in: personalityTagIDs,
                with: primaryTagID
            )
        case let .dailyCare(nextFoodBrand, nextDailyPortionGrams):
            foodBrand = nextFoodBrand
            dailyPortionGrams = nextDailyPortionGrams ?? 0
        }

        return PetProfileCommandInput(
            name: pet.name,
            avatarImageData: pet.avatarImageData,
            avatarEmoji: pet.avatarEmoji,
            species: pet.species,
            breed: pet.breed,
            gender: gender,
            isNeutered: pet.isNeutered,
            birthday: birthday,
            homeDate: homeDate,
            themeHex: pet.safeThemeColorHex,
            notes: pet.notes,
            coatColor: coatColor,
            microchipID: pet.microchipID,
            vetContact: pet.vetContact,
            vetClinicName: pet.vetClinicName,
            vetDoctorName: pet.vetDoctorName,
            vetAddress: pet.vetAddress,
            allergies: pet.allergies,
            passportNumber: pet.passportNumber,
            hasPassportExpiry: pet.passportExpiryDate != nil,
            passportExpiryDate: pet.passportExpiryDate,
            formerName: pet.formerName,
            birthCountry: pet.birthCountry,
            birthCity: pet.birthCity,
            lineageInfo: pet.lineageInfo,
            foodBrand: foodBrand,
            dailyPortionGrams: dailyPortionGrams,
            personalityTagIDs: personalityTagIDs
        )
    }

    static func isSatisfied(
        _ checkpoint: HouseholdStarterJourneyCheckpoint,
        by pet: Pet
    ) -> Bool {
        let category: MemberProfileCompletionCategory? = switch checkpoint {
        case .petLifeStage: .petLifeStage
        case .petBodyProfile: .petBodyProfile
        case .petPersonalityAppearance: .petPersonalityAppearance
        case .petDailyCare: .petDailyCare
        default: nil
        }
        guard let category else { return false }
        return MemberProfileCompletenessPolicy.petActualCategories(pet).contains(category)
    }
}

struct TaskCenterPetProfileInlineEditor: View {
    let checkpoint: HouseholdStarterJourneyCheckpoint
    let pet: Pet
    let onSave: (TaskCenterPetProfileInlineUpdate) -> TaskCenterSystemJourneyMutationOutcome
    let onCancel: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var hasHomeDate: Bool
    @State private var homeDate: Date
    @State private var gender: String
    @State private var coatColor: String
    @State private var primaryTagID: String
    @State private var foodBrand: String
    @State private var dailyPortionText: String
    @State private var isSaving = false
    @State private var didSaveSuccessfully = false
    @State private var saveErrorMessage: String?

    init(
        checkpoint: HouseholdStarterJourneyCheckpoint,
        pet: Pet,
        onSave: @escaping (TaskCenterPetProfileInlineUpdate) -> TaskCenterSystemJourneyMutationOutcome,
        onCancel: @escaping () -> Void
    ) {
        self.checkpoint = checkpoint
        self.pet = pet
        self.onSave = onSave
        self.onCancel = onCancel
        _hasBirthday = State(initialValue: pet.birthday != nil)
        _birthday = State(initialValue: pet.birthday ?? Date())
        _hasHomeDate = State(initialValue: pet.homeDate != nil)
        _homeDate = State(initialValue: pet.homeDate ?? Date())
        _gender = State(initialValue: Pet.canonicalSex(pet.gender) ?? "")
        _coatColor = State(initialValue: pet.coatColor)
        _primaryTagID = State(initialValue: pet.personalityTagIdList.first ?? "")
        _foodBrand = State(initialValue: pet.foodBrand)
        _dailyPortionText = State(
            initialValue: pet.dailyPortionGrams > 0 && pet.dailyPortionGrams.isFinite
                ? TaskCenterProfileDecimalText.preserving(pet.dailyPortionGrams)
                : ""
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
        .accessibilityIdentifier("task-center-pet-profile-inline-editor-\(checkpoint.rawValue)")
    }

    @ViewBuilder
    private var editorContent: some View {
        switch checkpoint {
        case .petLifeStage:
            lifeStageEditor
        case .petBodyProfile:
            bodyProfileEditor
        case .petPersonalityAppearance:
            personalityEditor
        case .petDailyCare:
            dailyCareEditor
        default:
            EmptyView()
        }
    }

    private var lifeStageEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(TaskCenterPetProfileInlineCopy.birthday(l), isOn: $hasBirthday)
                .accessibilityIdentifier("task-center-pet-profile-inline-birthday-toggle")
            if hasBirthday {
                DatePicker(
                    TaskCenterPetProfileInlineCopy.birthday(l),
                    selection: $birthday,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .accessibilityIdentifier("task-center-pet-profile-inline-birthday")
            }

            Toggle(TaskCenterPetProfileInlineCopy.homeDate(l), isOn: $hasHomeDate)
                .accessibilityIdentifier("task-center-pet-profile-inline-home-date-toggle")
            if hasHomeDate {
                DatePicker(
                    TaskCenterPetProfileInlineCopy.homeDate(l),
                    selection: $homeDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .accessibilityIdentifier("task-center-pet-profile-inline-home-date")
            }
        }
        .tint(Color.goPrimary)
    }

    private var bodyProfileEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: 8)],
                spacing: 8
            ) {
                genderButton(value: "boy", title: TaskCenterPetProfileInlineCopy.boy(l))
                genderButton(value: "girl", title: TaskCenterPetProfileInlineCopy.girl(l))
            }

            TextField(
                TaskCenterPetProfileInlineCopy.coatColor(l),
                text: $coatColor
            )
            .ohanaRoundedTextFieldStyle()
            .accessibilityIdentifier("task-center-pet-profile-inline-coat-color")
        }
    }

    private func genderButton(value: String, title: String) -> some View {
        let isSelected = gender == value
        return Button {
            gender = value
            OhanaFeedback.selection()
        } label: {
            HStack(spacing: 7) {
                Text(title)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark") // a11y: allow decorative selection glyph; the Button has a text label
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
        .accessibilityIdentifier("task-center-pet-profile-inline-gender-\(value)")
    }

    private var personalityEditor: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 116), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(personalityOptionIDs, id: \.self) { id in
                let isSelected = primaryTagID == id
                Button {
                    primaryTagID = id
                    OhanaFeedback.selection()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: PetPersonalityTag.symbolName(for: id))
                            .accessibilityHidden(true)
                        Text(PetPersonalityTag.displayTitle(for: id, l: l))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark") // a11y: allow decorative selection glyph; the Button has a text label
                                .font(OhanaFont.caption(.black))
                                .accessibilityHidden(true)
                        }
                    }
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaPrimaryText)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
                .accessibilityIdentifier("task-center-pet-profile-inline-personality-\(id)")
            }
        }
    }

    private var dailyCareEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                TaskCenterPetProfileInlineCopy.foodBrand(l),
                text: $foodBrand
            )
            .ohanaRoundedTextFieldStyle()
            .accessibilityIdentifier("task-center-pet-profile-inline-food-brand")

            TextField(
                TaskCenterPetProfileInlineCopy.dailyPortion(l),
                text: $dailyPortionText
            )
            .keyboardType(.decimalPad)
            .ohanaRoundedTextFieldStyle()
            .accessibilityIdentifier("task-center-pet-profile-inline-daily-portion")

            if !dailyPortionIsValid {
                Text(TaskCenterPetProfileInlineCopy.invalidPortion(l))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goRed)
                    .accessibilityIdentifier("task-center-pet-profile-inline-daily-portion-error")
            }
        }
    }

    private var actionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            if didSaveSuccessfully {
                Label(TaskCenterPetProfileInlineCopy.saved(l), systemImage: "checkmark.circle.fill")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goTeal)
                    .transition(.opacity)
                    .accessibilityIdentifier("task-center-pet-profile-inline-saved-\(checkpoint.rawValue)")
            }

            if let saveErrorMessage {
                Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goRed)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("task-center-pet-profile-inline-save-error-\(checkpoint.rawValue)")
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: 10)],
                spacing: 10
            ) {
                Button(didSaveSuccessfully ? localizedDone : l.cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .disabled(isSaving)
                    .accessibilityIdentifier("task-center-pet-profile-inline-cancel-\(checkpoint.rawValue)")

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
                .accessibilityIdentifier("task-center-pet-profile-inline-save-\(checkpoint.rawValue)")
            }
        }
    }

    private var pendingUpdate: TaskCenterPetProfileInlineUpdate? {
        switch checkpoint {
        case .petLifeStage:
            let nextBirthday = hasBirthday ? Calendar.current.startOfDay(for: birthday) : nil
            let nextHomeDate = hasHomeDate ? Calendar.current.startOfDay(for: homeDate) : nil
            guard !sameDay(nextBirthday, pet.birthday) || !sameDay(nextHomeDate, pet.homeDate) else {
                return nil
            }
            return .lifeStage(birthday: nextBirthday, homeDate: nextHomeDate)
        case .petBodyProfile:
            let normalizedGender = Pet.canonicalSex(gender) ?? ""
            let normalizedCoat = coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentGender = Pet.canonicalSex(pet.gender) ?? ""
            let currentCoat = pet.coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedGender.isEmpty || !normalizedCoat.isEmpty else { return nil }
            guard normalizedGender != currentGender || normalizedCoat != currentCoat else { return nil }
            return .bodyProfile(gender: normalizedGender, coatColor: normalizedCoat)
        case .petPersonalityAppearance:
            guard !primaryTagID.isEmpty,
                  primaryTagID != pet.personalityTagIdList.first else { return nil }
            return .personality(primaryTagID: primaryTagID)
        case .petDailyCare:
            guard dailyPortionIsValid else { return nil }
            let normalizedBrand = foodBrand.trimmingCharacters(in: .whitespacesAndNewlines)
            let portion = normalizedDailyPortion
            let currentBrand = pet.foodBrand.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentPortion: Double? = pet.dailyPortionGrams > 0 ? pet.dailyPortionGrams : nil
            guard !normalizedBrand.isEmpty || portion != nil else { return nil }
            guard normalizedBrand != currentBrand || portion != currentPortion else { return nil }
            return .dailyCare(foodBrand: normalizedBrand, dailyPortionGrams: portion)
        default:
            return nil
        }
    }

    private var dailyPortionIsValid: Bool {
        let trimmed = normalizedDailyPortionText
        guard !trimmed.isEmpty else { return true }
        guard let value = Double(trimmed), value.isFinite else { return false }
        return value > 0
    }

    private var normalizedDailyPortion: Double? {
        guard dailyPortionIsValid else { return nil }
        let trimmed = normalizedDailyPortionText
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private var normalizedDailyPortionText: String {
        dailyPortionText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
    }

    private var personalityOptionIDs: [String] {
        var ids = PetPersonalityTag.primaryChoices.map(\.id)
        if !primaryTagID.isEmpty, !ids.contains(primaryTagID) {
            ids.insert(primaryTagID, at: 0)
        }
        return ids
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

    private func sameDay(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (lhs?, rhs?): Calendar.current.isDate(lhs, inSameDayAs: rhs)
        case (nil, _?), (_?, nil): false
        }
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
}
