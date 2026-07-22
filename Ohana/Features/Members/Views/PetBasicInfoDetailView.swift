//
//  PetBasicInfoDetailView.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

enum PetProfilePresentedSheet: String, Identifiable {
    case editor
    case avatarPreview

    var id: String { rawValue }
}

struct PetBasicInfoDetailView: View {
    let pet: Pet
    var startsEditing = false
    var onSave: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var onCreateCareTask: ((TaskCreationPreset) -> Void)? = nil
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage
    @Environment(\.memberProfileExperienceStyle) var profileExperienceStyle

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @State var didApplyInitialEditing = false
    @State var breedTipsExpanded = false
    @State var showsMoreDetails = false
    @State var presentedSheet: PetProfilePresentedSheet?
    @State var showingDiscardConfirmation = false
    @State var isSaving = false
    @State var saveErrorMessage: String?
    @State var showsSavedFeedback = false
    @State var savedFeedbackTask: Task<Void, Never>?
    @State var profileCompletionResolutions: Set<MemberProfileCompletionCategory> = []

    @State var showingRainbowBridgeAlert = false
    @State var showingUndoPassingAlert = false
    @State var personalUpgradePrompt: PersonalUpgradePrompt?
    @State var rainbowBridgeDate = Date()
    @State var healthSummary = PetBasicInfoHealthSummary.empty
    @State var healthSummaryLoadTask: Task<Void, Never>?
    @State var preparedVetVisitSummaryText: String?

    // Edit state mirrors
    @State var eName = ""
    @State var eSpecies = ""
    @State var eBreed = ""
    @State var eGender = ""
    @State var eIsNeutered = false
    @State var eHasBirthday = false
    @State var eBirthday = Date()
    @State var eHasHomeDate = false
    @State var eHomeDate = Date()
    @State var eCoatColor = ""
    @State var eMicrochipID = ""
    @State var eVetContact = "" // 电话
    @State var eVetClinicName = ""
    @State var eVetDoctorName = ""
    @State var eVetAddress = ""
    @State var eAllergies = ""
    @State var ePassportNumber = ""
    @State var eHasPassportExpiry = false
    @State var ePassportExpiry = Date()
    @State var eFormerName = ""
    @State var eBirthCountry = ""
    @State var eBirthCity = ""
    @State var eLineageInfo = ""
    @State var eNotes = ""
    @State var eThemeColorHex = ""
    @State var eAvatarImageData: Data? = nil
    @State var ePrimaryPersonalityTagID = ""

    let speciesOptions = Pet.canonicalSpeciesOptions
    let themePresets: [(String, String)] = [
        ("FF6B6B", "coral"), ("4ECDC4", "ocean"), ("B8A9C9", "lavender"),
        ("95E1D3", "mint"), ("F38181", "sunset"), ("AA96DA", "berry"),
        ("F472B6", "rose"), ("A8E6CF", "sage"), ("FFD3B6", "peach"), ("95ADBE", "slate")
    ]
    var l: L10n { L10n(appLanguage) }
    var canSaveProfileEdit: Bool {
        Pet.canonicalSex(eGender) != nil || Pet.canonicalSex(pet.gender) == nil
    }

    var body: some View {
        ProfileDetailScaffold(
            title: l.tr(zh: "基础资料", en: "Profile", de: "Profil"),
            closeTitle: l.tr(zh: "关闭", en: "Close", de: "Schließen"),
            editTitle: l.tr(zh: "编辑", en: "Edit", de: "Bearbeiten"),
            showsEditAction: !pet.hasPassedAway,
            showsSavedFeedback: showsSavedFeedback,
            savedFeedbackTitle: l.tr(zh: "资料已更新", en: "Profile updated", de: "Profil aktualisiert"),
            closeAccessibilityIdentifier: "pet-basic-info-close-action",
            editAccessibilityIdentifier: "pet-basic-info-edit-action",
            onClose: onClose,
            onEdit: presentEditor
        ) {
            avatarSection
        } content: {
            readContent
        }
        .onChange(of: pet.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway, presentedSheet == .editor {
                presentedSheet = nil
            }
        }
        .onAppear {
            scheduleHealthSummaryLoad()
            guard startsEditing,
                  !didApplyInitialEditing,
                  !pet.hasPassedAway else {
                return
            }
            didApplyInitialEditing = true
            presentEditor()
        }
        .task(id: vetVisitSummaryPreparationSignature) {
            await prepareVetVisitSummaryText()
        }
        .task(id: pet.id) {
            profileCompletionResolutions = MemberProfileCompletenessReadService
                .explicitlyResolvedCategories(
                    kind: .pet,
                    subjectID: pet.id,
                    context: modelContext
                )
        }
        .sheet(item: $personalUpgradePrompt) { prompt in
            PersonalPlanView(prompt: prompt)
                .ohanaSheetPagePresentation()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .editor:
                petEditorSheet
            case .avatarPreview:
                if let imageData = pet.avatarImageData {
                    ProfileAvatarPreviewSheet(
                        name: pet.name,
                        imageData: imageData,
                        closeTitle: l.tr(zh: "关闭", en: "Close", de: "Schließen")
                    )
                }
            }
        }
        .onDisappear {
            healthSummaryLoadTask?.cancel()
            healthSummaryLoadTask = nil
            savedFeedbackTask?.cancel()
        }
        .accessibilityIdentifier("pet-basic-info-screen")
    }

    private var petEditorSheet: some View {
        NavigationStack {
            editContent
                .navigationTitle(l.tr(zh: "编辑资料", en: "Edit profile", de: "Profil bearbeiten"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), action: cancelEditor)
                            .disabled(isSaving)
                            .accessibilityIdentifier("pet-basic-info-cancel-edit-action")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: saveChanges) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                            }
                        }
                        .disabled(!canSavePetDraft)
                        .accessibilityIdentifier("pet-basic-info-save-action")
                    }
                }
        }
        .interactiveDismissDisabled(hasPetDraftChanges || isSaving)
        .confirmationDialog(
            l.tr(zh: "放弃未保存的修改？", en: "Discard unsaved changes?", de: "Ungespeicherte Änderungen verwerfen?"),
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(l.tr(zh: "放弃修改", en: "Discard changes", de: "Änderungen verwerfen"), role: .destructive) {
                presentedSheet = nil
            }
            .accessibilityIdentifier("pet-basic-info-discard-changes-action")
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
        .accessibilityIdentifier("pet-basic-info-editor")
    }

    func presentEditor() {
        guard !pet.hasPassedAway else { return }
        loadEditState()
        presentedSheet = .editor
    }

    private func cancelEditor() {
        guard hasPetDraftChanges else {
            presentedSheet = nil
            return
        }
        showingDiscardConfirmation = true
    }

    var canSavePetDraft: Bool {
        !isSaving &&
            canSaveProfileEdit &&
            !eName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            hasPetDraftChanges
    }

    private var hasPetDraftChanges: Bool {
        eName != pet.name ||
            eAvatarImageData != pet.avatarImageData ||
            Pet.canonicalSpeciesKey(eSpecies) != Pet.canonicalSpeciesKey(pet.species) ||
            eBreed != pet.breed ||
            eGender != (Pet.canonicalSex(pet.gender) ?? "") ||
            eIsNeutered != pet.isNeutered ||
            eHasBirthday != (pet.birthday != nil) ||
            (eHasBirthday && pet.birthday.map { eBirthday != $0 } == true) ||
            eHasHomeDate != (pet.homeDate != nil) ||
            (eHasHomeDate && pet.homeDate.map { eHomeDate != $0 } == true) ||
            eCoatColor != pet.coatColor ||
            eMicrochipID != pet.microchipID ||
            eVetContact != pet.vetContact ||
            eVetClinicName != pet.vetClinicName ||
            eVetDoctorName != pet.vetDoctorName ||
            eVetAddress != pet.vetAddress ||
            eAllergies != pet.allergies ||
            ePassportNumber != pet.passportNumber ||
            eHasPassportExpiry != (pet.passportExpiryDate != nil) ||
            (eHasPassportExpiry && pet.passportExpiryDate.map { ePassportExpiry != $0 } == true) ||
            eFormerName != pet.formerName ||
            eBirthCountry != pet.birthCountry ||
            eBirthCity != pet.birthCity ||
            eLineageInfo != pet.lineageInfo ||
            eNotes != pet.notes ||
            eThemeColorHex.uppercased() != pet.safeThemeColorHex.uppercased() ||
            ePrimaryPersonalityTagID != (pet.personalityTagIdList.first ?? "")
    }

    func presentSavedFeedback() {
        savedFeedbackTask?.cancel()
        withAnimation(GoMotion.feedback) {
            showsSavedFeedback = true
        }
        savedFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(GoMotion.feedback) {
                showsSavedFeedback = false
            }
        }
    }

    @ViewBuilder
    func petCareTaskButton(
        _ careKind: TaskCareKind,
        action: @escaping (TaskCreationPreset) -> Void
    ) -> some View {
        Button {
            action(TaskCreationPreset(subjectID: pet.id, careKind: careKind))
        } label: {
            Label(careKind.localizedTitle(l: l), systemImage: careKind.defaultIcon)
        }
    }

    // MARK: - Read View
}
