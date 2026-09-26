//
//  HumanBasicInfoDetailView.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

struct HumanBasicInfoDetailContentView: View {
    let human: Human
    var startsEditing = false
    var requiresStarterProfileFields = false
    var onSave: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var canEditProfile: Bool {
        HumanProfileEditPolicy.canEdit(hasPassedAway: human.hasPassedAway)
    }
    private var l: L10n { L10n(appLanguage) }

    @State private var didApplyInitialEditing = false
    @State private var isDeleting = false
    @State private var personalUpgradePrompt: PersonalUpgradePrompt?
    @State private var presentedSheet: HumanBasicInfoPresentedSheet?
    @State private var showingDiscardConfirmation = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @State private var showsSavedFeedback = false
    @State private var savedFeedbackTask: Task<Void, Never>?
    @State private var profileCompletionResolutions: Set<MemberProfileCompletionCategory> = []

    @State private var eName = ""
    @State private var eAvatarImageData: Data? = nil
    @State private var eAvatarEmoji = ""
    @State private var eRole = "owner"
    @State private var eGender = ""
    @State private var eHasBirthday = false
    @State private var eBirthday = Date()
    @State private var eBloodType = ""
    @State private var eHeightText = ""
    @State private var eMBTIEnergy = ""
    @State private var eMBTIInformation = ""
    @State private var eMBTIDecision = ""
    @State private var eMBTILifestyle = ""
    @State private var eNationality = ""
    @State private var eResidenceCountry = ""
    @State private var eCity = ""
    @State private var eUsesCustomNationality = false
    @State private var eCustomNationality = ""
    @State private var eUsesCustomResidenceCountry = false
    @State private var eCustomResidenceCountry = ""
    @State private var eUsesCustomResidence = false
    @State private var eCustomResidence = ""
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
    private let genderOptions = HumanProfileOptions.genderOptions

    var body: some View {
        ProfileDetailScaffold(
            title: l.tr(zh: "基础资料", en: "Profile", de: "Profil"),
            closeTitle: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
            editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
            showsEditAction: canEditProfile,
            showsSavedFeedback: showsSavedFeedback,
            savedFeedbackTitle: l.tr(zh: "资料已更新", en: "Profile updated", de: "Profil aktualisiert"),
            closeAccessibilityIdentifier: "human-basic-info-close-action",
            editAccessibilityIdentifier: "human-basic-info-edit-action",
            onClose: onClose,
            onEdit: presentEditor
        ) {
            HumanBasicInfoIdentityHero(
                human: human,
                onAvatarTap: human.avatarImageData == nil
                    ? nil
                    : { presentedSheet = .avatarPreview }
            )
        } content: {
            HumanBasicInfoReadContentView(
                human: human,
                profileCompletionResolutions: profileCompletionResolutions,
                canEditProfile: canEditProfile,
                onEdit: presentEditor,
                onMarkPassedAway: markHumanPassedAway,
                onUndoPassedAway: undoHumanPassedAway,
                onDelete: deleteHumanAndReturnHome
            )
        }
        .onChange(of: human.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway, presentedSheet == .editor {
                presentedSheet = nil
            }
        }
        .onAppear {
            guard startsEditing,
                  !didApplyInitialEditing,
                  canEditProfile else {
                return
            }
            didApplyInitialEditing = true
            presentEditor()
        }
        .task(id: human.id) {
            profileCompletionResolutions = MemberProfileCompletenessReadService
                .explicitlyResolvedCategories(
                    kind: .human,
                    subjectID: human.id,
                    context: modelContext
                )
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .editor:
                humanEditorSheet
            case .avatarPreview:
                if let imageData = human.avatarImageData {
                    ProfileAvatarPreviewSheet(
                        name: human.name,
                        imageData: imageData,
                        closeTitle: l.tr(zh: "关闭", en: "Close", de: "Schließen")
                    )
                }
            }
        }
        .sheet(item: $personalUpgradePrompt) { prompt in
            PersonalPlanView(prompt: prompt)
                .ohanaSheetPagePresentation()
        }
        .onDisappear {
            savedFeedbackTask?.cancel()
        }
        .accessibilityIdentifier("human-basic-info-screen")
    }
}

private extension HumanBasicInfoDetailContentView {
    private var humanEditorSheet: some View {
        NavigationStack {
            editContent
                .navigationTitle(l.tr(zh: "编辑资料", en: "Edit profile", de: "Profil bearbeiten"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), action: cancelEditor)
                            .disabled(isSaving)
                            .accessibilityIdentifier("human-basic-info-cancel-edit-action")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: saveChanges) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                            }
                        }
                        .disabled(!canSaveHumanDraft)
                        .accessibilityHint(
                            requiresStarterProfileFields && !hasRequiredStarterProfileFields
                                ? requiredStarterProfileStatusTitle
                                : ""
                        )
                        .accessibilityIdentifier("human-basic-info-save-action")
                    }
                }
        }
        .interactiveDismissDisabled(hasHumanDraftChanges || isSaving)
        .confirmationDialog(
            l.tr(zh: "放弃未保存的修改？", en: "Discard unsaved changes?", de: "Ungespeicherte Änderungen verwerfen?"),
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(l.tr(zh: "放弃修改", en: "Discard changes", de: "Änderungen verwerfen"), role: .destructive) {
                presentedSheet = nil
            }
            .accessibilityIdentifier("human-basic-info-discard-changes-action")
            Button(l.tr(zh: "继续编辑", en: "Keep editing", de: "Weiter bearbeiten"), role: .cancel) {}
        }
        .alert(
            l.tr(zh: "无法保存资料", en: "Could not save profile", de: "Profil konnte nicht gespeichert werden"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(l.tr(zh: "好的", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .accessibilityIdentifier("human-basic-info-editor")
    }

    private func presentEditor() {
        guard canEditProfile else { return }
        loadEditState()
        presentedSheet = .editor
    }

    private func cancelEditor() {
        guard hasHumanDraftChanges else {
            presentedSheet = nil
            return
        }
        showingDiscardConfirmation = true
    }

    private var canSaveHumanDraft: Bool {
        !isSaving
            && !eName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!requiresStarterProfileFields || hasRequiredStarterProfileFields)
            && hasHumanDraftChanges
    }

    private var draftProfileCompletion: MemberProfileCompletionSnapshot {
        MemberProfileCompletenessPolicy.human(
            HumanProfileCompletionDraft(
                hasMeaningfulAppearance: draftHasMeaningfulAppearance,
                birthday: eHasBirthday ? eBirthday : nil,
                genderIdentityRaw: eGender,
                bloodType: eBloodType,
                heightCm: heightValue,
                mbti: editedMBTI,
                nationality: resolvedNationality,
                city: resolvedResidence,
                notes: eNotes
            ),
            explicitlyResolvedCategories: profileCompletionResolutions
        )
    }

    private var draftHasMeaningfulAppearance: Bool {
        if eAvatarImageData != nil { return true }
        if human.avatarImageData == nil,
           human.avatarAttachmentState == .present || !human.avatarImageSignature.isEmpty {
            return true
        }
        let emoji = eAvatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return !emoji.isEmpty && emoji != "👤"
    }

    private var hasRequiredStarterProfileFields: Bool {
        draftProfileCompletion.missingRequiredCategories.isEmpty
    }

    private var requiredStarterProfileStatusTitle: String {
        if hasRequiredStarterProfileFields {
            return l.tr(
                zh: "生日与性别/身份已完成",
                en: "Birthday and gender/identity are complete",
                de: "Geburtstag und Geschlecht/Identität sind vollständig",
                es: "Cumpleaños y género/identidad completados",
                pt: "Aniversário e gênero/identidade concluídos",
                fr: "Anniversaire et genre/identité complétés",
                ja: "誕生日と性別／本人情報を入力済み",
                ko: "생일 및 성별/정체성 입력 완료",
                it: "Compleanno e genere/identità completati"
            )
        }
        let missing = draftProfileCompletion.missingRequiredCategories
            .map { $0.localizedTitle(l) }
            .joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
        return l.tr(
            zh: "保存前请完成：\(missing)",
            en: "Complete before saving: \(missing)",
            de: "Vor dem Speichern ausfüllen: \(missing)",
            es: "Completa antes de guardar: \(missing)",
            pt: "Conclua antes de salvar: \(missing)",
            fr: "À compléter avant d’enregistrer : \(missing)",
            ja: "保存前に入力：\(missing)",
            ko: "저장 전 입력: \(missing)",
            it: "Completa prima di salvare: \(missing)"
        )
    }

    private var hasHumanDraftChanges: Bool {
        eName != human.name ||
            eAvatarImageData != human.avatarImageData ||
            eAvatarEmoji != human.avatarEmoji ||
            eRole != HumanProfileOptions.normalizedRole(human.role) ||
            eGender != (HumanProfileOptions.storedGenderIdentity(human.genderRaw) ?? "") ||
            eHasBirthday != (human.birthday != nil) ||
            (eHasBirthday && human.birthday.map { eBirthday != $0 } == true) ||
            eBloodType != human.bloodType ||
            eHeightText != originalHeightText ||
            editedMBTI != human.mbti.uppercased() ||
            resolvedNationality != human.nationality ||
            MemberResidenceValue(storedValue: resolvedResidence)
                != MemberResidenceValue(storedValue: human.city) ||
            eThemeColorHex.uppercased() != human.safeThemeColorHex.uppercased() ||
            eNotes != displayNotes ||
            editedPrivateFieldsRaw != human.privateFields
    }

    private var originalHeightText: String {
        human.heightCm > 0 && human.heightCm.isFinite ? String(format: "%.0f", human.heightCm) : ""
    }

    private func presentSavedFeedback() {
        savedFeedbackTask?.cancel()
        withAnimation(GoMotion.feedback) {
            showsSavedFeedback = true
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: l.tr(
                zh: "资料已更新", en: "Profile updated", de: "Profil aktualisiert",
                es: "Perfil actualizado", pt: "Perfil atualizado", fr: "Profil mis à jour",
                ja: "プロフィールを更新しました", ko: "프로필이 업데이트됨", it: "Profilo aggiornato"
            )
        )
        savedFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.feedback) {
                showsSavedFeedback = false
            }
        }
    }

    private var editContent: some View {
        Form {
            if showsSavedFeedback {
                Section {
                    Label(
                        l.tr(
                            zh: "已保存", en: "Saved", de: "Gespeichert",
                            es: "Guardado", pt: "Salvo", fr: "Enregistré",
                            ja: "保存済み", ko: "저장됨", it: "Salvato"
                        ),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.goTeal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("human-basic-info-editor-saved-feedback")
                }
            }

            Section {
                ProfileCompletionCard(
                    snapshot: draftProfileCompletion,
                    onContinue: nil
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("human-basic-info-live-profile-progress")
            }

            Section {
                EditableProfileAvatarPicker(
                    avatarImageData: $eAvatarImageData,
                    fallbackEmoji: eAvatarEmoji.isEmpty ? "👤" : eAvatarEmoji,
                    accentColor: Color(hex: eThemeColorHex),
                    cropSpecies: "",
                    silhouetteSystemName: "person.fill"
                )
            } header: {
                Label(l.tr(zh: "头像", en: "Avatar", de: "Avatar"), systemImage: "person.crop.circle")
            }

            editSection(title: l.tr(zh: "基本信息", en: "Basic Info", de: "Basisinfos"), icon: "person.fill", iconColor: Color.goPrimary) {
                editField(
                    l.tr(zh: "名字", en: "Name", de: "Name"),
                    text: $eName,
                    accessibilityIdentifier: "human-basic-info-name-input"
                )
                Divider().opacity(0.1)
                HStack {
                    editLabel(l.tr(
                        zh: "家庭角色", en: "Household role", de: "Rolle im Haushalt",
                        es: "Rol en el hogar", pt: "Papel na família", fr: "Rôle dans le foyer",
                        ja: "家族での役割", ko: "가족 역할", it: "Ruolo familiare"
                    ))
                    Spacer()
                    Picker("", selection: $eRole) {
                        Text(localizedRoleText(for: "owner")).tag("owner")
                        Text(localizedRoleText(for: "member")).tag("member")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }
                Divider().opacity(0.1)
                VStack(alignment: .leading, spacing: 10) {
                    requiredEditLabel(
                        l.tr(
                            zh: "性别/身份",
                            en: "Gender / Identity",
                            de: "Geschlecht / Identität"
                        ),
                        isRequired: requiresStarterProfileFields
                    )
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(
                            genderOptions.filter { !requiresStarterProfileFields || !$0.key.isEmpty },
                            id: \.key
                        ) { option in
                            let isSelected = eGender == option.key
                            Button {
                                eGender = option.key
                                OhanaFeedback.selection()
                            } label: {
                                HStack(spacing: 7) {
                                    Text(option.icon)
                                        .accessibilityHidden(true)
                                    Text(localizedGenderTitle(for: option.key))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    if isSelected {
                                        Image(systemName: "checkmark") // a11y: allow decorative selected-state glyph hidden below
                                            .font(OhanaFont.caption(.black))
                                            .accessibilityHidden(true)
                                    }
                                }
                                .font(OhanaFont.callout(.semibold))
                                .foregroundStyle(isSelected ? profileEditAccent : Color.ohanaPrimaryText)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    isSelected ? profileEditAccent.opacity(0.14) : Color.ohanaControlFill,
                                    in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? profileEditAccent.opacity(0.64) : Color.ohanaCardStroke,
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "human-basic-info-gender-option-\(option.key.isEmpty ? "unset" : option.key)"
                            )
                            .accessibilityLabel(localizedGenderTitle(for: option.key))
                            .accessibilityValue(isSelected
                                ? l.tr(
                                    zh: "已选择", en: "Selected", de: "Ausgewählt",
                                    es: "Seleccionado", pt: "Selecionado", fr: "Sélectionné",
                                    ja: "選択済み", ko: "선택됨", it: "Selezionato"
                                )
                                : l.tr(
                                    zh: "未选择", en: "Not selected", de: "Nicht ausgewählt",
                                    es: "No seleccionado", pt: "Não selecionado", fr: "Non sélectionné",
                                    ja: "未選択", ko: "선택 안 됨", it: "Non selezionato"
                                )
                            )
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .accessibilityIdentifier("human-basic-info-gender-picker")
                }
                Divider().opacity(0.1)
                HStack {
                    requiredEditLabel(
                        l.tr(
                            zh: "设置生日",
                            en: "Set Birthday",
                            de: "Geburtstag festlegen"
                        ),
                        isRequired: requiresStarterProfileFields
                    )
                    Spacer()
                    Toggle("", isOn: $eHasBirthday)
                        .labelsHidden()
                        .tint(profileEditAccent)
                        .accessibilityLabel(l.tr(
                            zh: "设置生日",
                            en: "Set Birthday",
                            de: "Geburtstag festlegen",
                            es: "Establecer cumpleaños",
                            pt: "Definir aniversário",
                            fr: "Définir l’anniversaire",
                            ja: "誕生日を設定",
                            ko: "생일 설정",
                            it: "Imposta compleanno"
                        ))
                        .accessibilityIdentifier("human-basic-info-birthday-toggle")
                }
                if eHasBirthday {
                    DatePicker("", selection: $eBirthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(profileEditAccent)
                        .labelsHidden()
                        .accessibilityLabel(l.tr(
                            zh: "生日", en: "Birthday", de: "Geburtstag",
                            es: "Cumpleaños", pt: "Aniversário", fr: "Anniversaire",
                            ja: "誕生日", ko: "생일", it: "Compleanno"
                        ))
                        .accessibilityIdentifier("human-basic-info-birthday-picker")

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles") // a11y: allow decorative zodiac glyph hidden below
                            .foregroundStyle(profileEditAccent)
                            .accessibilityHidden(true)
                        Text(l.tr(
                            zh: "星座", en: "Zodiac", de: "Sternzeichen",
                            es: "Signo", pt: "Signo", fr: "Signe",
                            ja: "星座", ko: "별자리", it: "Segno"
                        ))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        Spacer(minLength: 8)
                        Text(Human.westernZodiacDisplay(for: eBirthday, l: l))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                    .font(OhanaFont.callout(.semibold))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("human-basic-info-zodiac")
                }
                if requiresStarterProfileFields {
                    Label(
                        requiredStarterProfileStatusTitle,
                        systemImage: hasRequiredStarterProfileFields
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle.fill"
                    )
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(
                        hasRequiredStarterProfileFields
                            ? Color.goTeal
                            : Color.ohanaSecondaryText
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("human-basic-info-required-fields-status")
                }
            }

            editSection(title: l.tr(zh: "身体资料", en: "Body Info", de: "Körperdaten"), icon: "heart.text.square.fill", iconColor: Color.goRed) {
                optionChipGrid(title: l.tr(zh: "血型", en: "Blood Type", de: "Blutgruppe"), selection: $eBloodType, options: bloodTypeOptions, accent: profileEditAccent)
                Divider().opacity(0.1)
                heightStepperRow
                Divider().opacity(0.1)
                MemberCompactMBTIBar(
                    energy: $eMBTIEnergy,
                    information: $eMBTIInformation,
                    decision: $eMBTIDecision,
                    lifestyle: $eMBTILifestyle,
                    foreground: Color.ohanaPrimaryText,
                    onSelectionChanged: {}
                )
            }

            editSection(title: l.tr(zh: "家庭与位置", en: "Family & Location", de: "Familie & Standort"), icon: "house.fill", iconColor: Color.goTeal) {
                optionPickerRow(
                    l.tr(zh: "国籍", en: "Nationality", de: "Nationalität"),
                    selection: nationalityPickerSelection,
                    options: countryOptions
                )
                if eUsesCustomNationality {
                    TextField(
                        l.tr(zh: "输入国籍", en: "Enter nationality", de: "Nationalität eingeben"),
                        text: $eCustomNationality
                    )
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("human-basic-info-custom-nationality-input")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Divider().opacity(0.1)
                optionPickerRow(
                    l.tr(zh: "现居国家", en: "Residence country", de: "Wohnland"),
                    selection: residenceCountryPickerSelection,
                    options: countryOptions
                )
                if eUsesCustomResidenceCountry {
                    TextField(
                        l.tr(zh: "输入现居国家", en: "Enter residence country", de: "Wohnland eingeben"),
                        text: $eCustomResidenceCountry
                    )
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("human-basic-info-custom-residence-country-input")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Divider().opacity(0.1)
                optionPickerRow(
                    l.tr(zh: "现居城市", en: "Residence city", de: "Wohnort"),
                    selection: residencePickerSelection,
                    options: residenceCityOptions
                )
                if eUsesCustomResidence {
                    TextField(
                        l.tr(zh: "输入现居地", en: "Enter residence", de: "Wohnort eingeben"),
                        text: $eCustomResidence
                    )
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("human-basic-info-custom-residence-input")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
                        let isSelected = eThemeColorHex.uppercased() == hex.uppercased()
                        Button { eThemeColorHex = hex } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex)).frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                if isSelected {
                                    Circle().strokeBorder(Color.ohanaPrimaryText, lineWidth: 2.5)
                                    Image(systemName: "checkmark") // a11y: allow decorative icon covered by surrounding text or control
                                        .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                }
                            }
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(l.tr(
                            zh: "主题色 #\(hex)", en: "Theme color #\(hex)", de: "Designfarbe #\(hex)",
                            es: "Color de acento #\(hex)", pt: "Cor de destaque #\(hex)", fr: "Couleur d’accent #\(hex)",
                            ja: "テーマカラー #\(hex)", ko: "테마 색상 #\(hex)", it: "Colore tema #\(hex)"
                        ))
                        .accessibilityValue(isSelected ? l.tr(
                            zh: "已选择", en: "Selected", de: "Ausgewählt",
                            es: "Seleccionado", pt: "Selecionado", fr: "Sélectionné",
                            ja: "選択中", ko: "선택됨", it: "Selezionato"
                        ) : "")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }

            editSection(title: l.tr(zh: "备注", en: "Notes", de: "Notizen"), icon: "note.text", iconColor: Color.goOrange) {
                ZStack(alignment: .topLeading) {
                    if eNotes.isEmpty {
                        Text(l.tr(
                            zh: "添加想记住的事情（可选）", en: "Add something worth remembering (optional)", de: "Etwas Erinnernswertes hinzufügen (optional)",
                            es: "Añade algo que quieras recordar (opcional)", pt: "Adicione algo que queira lembrar (opcional)", fr: "Ajoutez quelque chose à retenir (facultatif)",
                            ja: "覚えておきたいことを追加（任意）", ko: "기억하고 싶은 내용을 추가하세요(선택 사항)", it: "Aggiungi qualcosa da ricordare (facoltativo)"
                        ))
                        .font(OhanaFont.body())
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                    }
                    TextEditor(text: $eNotes)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .accessibilityLabel(l.tr(
                            zh: "备注", en: "Notes", de: "Notizen",
                            es: "Notas", pt: "Notas", fr: "Notes",
                            ja: "メモ", ko: "메모", it: "Note"
                        ))
                        .accessibilityIdentifier("human-basic-info-notes-input")
                }
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            }
        }
        .formStyle(.grouped)
        .tint(profileEditAccent)
        .scrollContentBackground(.hidden)
        .background(OhanaAppBackground())
        .scrollDismissesKeyboard(.interactively)
    }
}

private extension HumanBasicInfoDetailContentView {
    private func editSection(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> some View) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Label(title, systemImage: icon)
                .foregroundStyle(profileEditAccent)
        }
    }

    private func editLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private func requiredEditLabel(
        _ text: String,
        isRequired: Bool
    ) -> some View {
        HStack(spacing: 6) {
            editLabel(text)
            if isRequired {
                Text(l.tr(
                    zh: "必填",
                    en: "Required",
                    de: "Erforderlich",
                    es: "Obligatorio",
                    pt: "Obrigatório",
                    fr: "Requis",
                    ja: "必須",
                    ko: "필수",
                    it: "Obbligatorio"
                ))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func editField(
        _ title: String,
        text: Binding<String>,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        HStack {
            editLabel(title)
            if let accessibilityIdentifier {
                editTextField(title, text: text)
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                editTextField(title, text: text)
            }
        }
    }

    private func editTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
            .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .multilineTextAlignment(.trailing)
    }

    private var countryOptions: [String] {
        [""] + PetBreedDatabase.sortedCountries(l: l)
    }

    private var residenceCityOptions: [String] {
        let base = eResidenceCountry.isEmpty
            ? [""]
            : [""] + PetBreedDatabase.sortedCities(for: eResidenceCountry, l: l)
        var options = base
        if !options.contains("其他") {
            options.append("其他")
        }
        return options
    }

    private var nationalityPickerSelection: Binding<String> {
        Binding(
            get: { eUsesCustomNationality ? "其他" : eNationality },
            set: { selection in
                withAnimation(GoMotion.selection) {
                    if selection == "其他" {
                        eUsesCustomNationality = true
                        eNationality = ""
                    } else {
                        eUsesCustomNationality = false
                        eCustomNationality = ""
                        eNationality = selection
                    }
                }
            }
        )
    }

    private var residenceCountryPickerSelection: Binding<String> {
        Binding(
            get: { eUsesCustomResidenceCountry ? "其他" : eResidenceCountry },
            set: { selection in
                withAnimation(GoMotion.selection) {
                    let changedCountry = selection != eResidenceCountry
                    if selection == "其他" {
                        eUsesCustomResidenceCountry = true
                        eResidenceCountry = ""
                        eUsesCustomResidence = true
                    } else {
                        eUsesCustomResidenceCountry = false
                        eCustomResidenceCountry = ""
                        eResidenceCountry = selection
                    }
                    if changedCountry {
                        eCity = ""
                        eCustomResidence = ""
                        eUsesCustomResidence = selection == "其他"
                    }
                }
            }
        )
    }

    private var residencePickerSelection: Binding<String> {
        Binding(
            get: { eUsesCustomResidence ? "其他" : eCity },
            set: { selection in
                withAnimation(GoMotion.selection) {
                    if selection == "其他" {
                        eUsesCustomResidence = true
                        eCity = ""
                    } else {
                        eUsesCustomResidence = false
                        eCustomResidence = ""
                        eCity = selection
                    }
                }
            }
        )
    }

    private var resolvedNationality: String {
        (eUsesCustomNationality ? eCustomNationality : eNationality)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedResidenceCountry: String {
        (eUsesCustomResidenceCountry ? eCustomResidenceCountry : eResidenceCountry)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedResidenceCity: String {
        (eUsesCustomResidence ? eCustomResidence : eCity)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedResidence: String {
        MemberResidenceValue(
            country: resolvedResidenceCountry,
            city: resolvedResidenceCity
        ).storedValue
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
                            .foregroundStyle(
                                heightOptionSelected(option)
                                    ? profileEditAccentForeground
                                    : Color.ohanaPrimaryText.opacity(0.78)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(heightOptionSelected(option) ? profileEditAccent : Color.primary.opacity(0.07), in: Capsule())
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
            .tint(profileEditAccent)
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
                            .foregroundStyle(
                                selected
                                    ? profileEditAccentForeground
                                    : Color.ohanaPrimaryText.opacity(0.82)
                            )
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
                .tint(profileEditAccent)
                .labelsHidden()
                .accessibilityLabel(title)
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

    private var profileEditAccent: Color {
        let value = eThemeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? Color.goPrimary : Color(hex: value)
    }

    private var profileEditAccentForeground: Color {
        let value = eThemeColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = value.isEmpty ? "C8F34A" : value
        return WalletPetCardTheme.prefersDarkForeground(for: hex)
            ? Color.arkInk
            : Color.goCardWhite
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
        let mbti = MemberMBTISelectionPolicy.components(from: human.mbti)
        eMBTIEnergy = mbti[0]
        eMBTIInformation = mbti[1]
        eMBTIDecision = mbti[2]
        eMBTILifestyle = mbti[3]
        eUsesCustomNationality = !human.nationality.isEmpty &&
            !PetBreedDatabase.countries.contains(human.nationality)
        eCustomNationality = eUsesCustomNationality ? human.nationality : ""
        eNationality = eUsesCustomNationality ? "" : human.nationality
        let residence = MemberResidenceValue(storedValue: human.city)
        eUsesCustomResidenceCountry = !residence.country.isEmpty &&
            !PetBreedDatabase.countries.contains(residence.country)
        eCustomResidenceCountry = eUsesCustomResidenceCountry ? residence.country : ""
        eResidenceCountry = eUsesCustomResidenceCountry ? "" : residence.country
        let recognizedResidenceOptions = eResidenceCountry.isEmpty
            ? []
            : PetBreedDatabase.cities(for: eResidenceCountry)
        eUsesCustomResidence = !residence.city.isEmpty &&
            !recognizedResidenceOptions.contains(residence.city)
        eCustomResidence = eUsesCustomResidence ? residence.city : ""
        eCity = eUsesCustomResidence ? "" : residence.city
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
        guard canSaveHumanDraft else { return }
        let input = HumanProfileCommandInput(
            name: eName,
            avatarImageData: eAvatarImageData,
            avatarEmoji: eAvatarEmoji,
            role: eRole,
            gender: eGender,
            birthday: eHasBirthday ? eBirthday : nil,
            bloodType: eBloodType,
            heightText: eHeightText,
            mbti: editedMBTI,
            nationality: resolvedNationality,
            city: resolvedResidence,
            themeHex: eThemeColorHex,
            notes: eNotes,
            preservedNoteParts: preservedMetadataParts,
            shouldShowOnHome: true,
            privateFieldsRaw: HumanLocalPrivacyPolicy.isEnabled ? editedPrivateFieldsRaw : nil
        )
        isSaving = true
        commandQueue.enqueue(.memberProfile(entityID: human.id, kind: EntityKind.human.rawValue)) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).updateHumanProfile(
                human,
                input: input,
                note: "humanBasicInfo.profile"
            )
            guard result.didPersist else {
                isSaving = false
                saveErrorMessage = l.tr(
                    zh: "资料没有保存，请稍后再试。",
                    en: "Your changes were not saved. Try again.",
                    de: "Die Änderungen wurden nicht gespeichert. Bitte erneut versuchen."
                )
                OhanaFeedback.error()
                return
            }
            isSaving = false
            presentedSheet = nil
            OhanaFeedback.success()
            presentSavedFeedback()
            onSave?()
        }
    }

    private var editedMBTI: String {
        MemberMBTISelectionPolicy.value(
            energy: eMBTIEnergy,
            information: eMBTIInformation,
            decision: eMBTIDecision,
            lifestyle: eMBTILifestyle
        )
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
        option.isEmpty
            ? localizedEmptyValue
            : PetBreedDatabase.localizedRegionName(option, l: l)
    }

    private func localizedRoleText(for raw: String) -> String {
        HumanProfileOptions.localizedRoleTitle(raw, l: l)
    }

    private func localizedGenderTitle(for raw: String) -> String {
        let title = HumanProfileOptions.localizedGenderTitle(raw, l: l)
        return title.isEmpty ? localizedEmptyValue : title
    }

    private func deleteHumanAndReturnHome(
        completion: @escaping (HumanDeletionPresentationOutcome) -> Void
    ) {
        guard !isDeleting else {
            completion(.failed(message: HumanDeletionPresentationCopy.failureMessage(l: l)))
            return
        }
        isDeleting = true

        let target = human
        let activeHumanID = activeHumanIdStr
        let command = DomainCommand.memberDeletion(entityID: target.id, kind: EntityKind.human.rawValue)

        OhanaFeedback.medium()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deleteHuman(
                target,
                activeHumanID: activeHumanID,
                note: "humanBasicInfo.delete"
            )
            guard result.didPersist else {
                isDeleting = false
                OhanaFeedback.error()
                completion(.failed(message: HumanDeletionPresentationCopy.failureMessage(for: result, l: l)))
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
            isDeleting = false
            OhanaFeedback.success()
            completion(.deleted)
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 180) {
                dismiss()
            }
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
            guard result.didPersist else {
                appServices.islandToasts.show(l.tr(
                    zh: "离世状态没有更新，请稍后重试。",
                    en: "The memorial status was not updated. Try again.",
                    de: "Der Gedenkstatus wurde nicht aktualisiert. Bitte erneut versuchen.",
                    es: "El estado conmemorativo no se actualizó. Inténtalo de nuevo.",
                    pt: "O estado memorial não foi atualizado. Tente novamente.",
                    fr: "Le statut commémoratif n’a pas été mis à jour. Réessayez.",
                    ja: "メモリアル状態を更新できませんでした。もう一度お試しください。",
                    ko: "추모 상태가 업데이트되지 않았습니다. 다시 시도해 주세요.",
                    it: "Lo stato commemorativo non è stato aggiornato. Riprova."
                ))
                OhanaFeedback.error()
                return
            }
            OhanaFeedback.success()
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
            if let denial = result.personalDenial {
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            guard result.didPersist else {
                appServices.islandToasts.show(l.tr(
                    zh: "离世状态没有更新，请稍后重试。",
                    en: "The memorial status was not updated. Try again.",
                    de: "Der Gedenkstatus wurde nicht aktualisiert. Bitte erneut versuchen.",
                    es: "El estado conmemorativo no se actualizó. Inténtalo de nuevo.",
                    pt: "O estado memorial não foi atualizado. Tente novamente.",
                    fr: "Le statut commémoratif n’a pas été mis à jour. Réessayez.",
                    ja: "メモリアル状態を更新できませんでした。もう一度お試しください。",
                    ko: "추모 상태가 업데이트되지 않았습니다. 다시 시도해 주세요.",
                    it: "Lo stato commemorativo non è stato aggiornato. Riprova."
                ))
                OhanaFeedback.error()
                return
            }
            OhanaFeedback.success()
        }
    }
}
