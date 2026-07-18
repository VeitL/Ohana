//
//  PetBasicInfoDetailView.swift
//  Ohana
//

import Foundation
import PhotosUI
import SwiftData
import SwiftUI

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

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @State var isEditing = false
    @State var didApplyInitialEditing = false
    @State var breedTipsExpanded = true

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
        .navigationTitle(l.tr(zh: "\(pet.name) 的信息", en: "\(pet.name)'s info", de: "Infos zu \(pet.name)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if !isEditing, !pet.hasPassedAway, let onCreateCareTask {
                        Menu {
                            petCareTaskButton(.petFeeding, action: onCreateCareTask)
                            petCareTaskButton(.petWatering, action: onCreateCareTask)
                            petCareTaskButton(.petLitter, action: onCreateCareTask)
                            petCareTaskButton(.petPlay, action: onCreateCareTask)
                        } label: {
                            Image(systemName: "calendar.badge.plus") // a11y: allow decorative glyph; the Menu carries the localized action label.
                                .font(OhanaFont.adaptive(size: 18, weight: .semibold))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .accessibilityHidden(true)
                        }
                        .accessibilityLabel(l.tr(zh: "安排宠物照顾", en: "Schedule pet care", de: "Tierpflege planen"))
                        .accessibilityIdentifier("pet-basic-info-create-care-task")
                    }

                    if isEditing, !pet.hasPassedAway {
                        Button {
                            saveChanges()
                        } label: {
                            Text(l.save)
                                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(canSaveProfileEdit ? Color.goPrimary : Color.ohanaSecondaryText)
                        }
                        .accessibilityIdentifier("pet-basic-info-save-action")
                        .disabled(!canSaveProfileEdit)
                    } else if !pet.hasPassedAway {
                        Button {
                            loadEditState()
                            withAnimation { isEditing = true }
                        } label: {
                            Image(systemName: "pencil.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                                .font(OhanaFont.adaptive(size: 20)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.goPrimary)
                        }
                        .accessibilityLabel(l.tr(zh: "编辑宠物资料", en: "Edit pet profile", de: "Haustierprofil bearbeiten"))
                        .accessibilityIdentifier("pet-basic-info-edit-action")
                    }
                }
            }
            if isEditing || onClose != nil {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) {
                            withAnimation { isEditing = false }
                        }
                        .accessibilityIdentifier("pet-basic-info-cancel-edit-action")
                    } else if let onClose {
                        Button(l.tr(zh: "关闭", en: "Close", de: "Schließen"), action: onClose)
                            .accessibilityIdentifier("pet-basic-info-close-action")
                    }
                }
            }
        }
        .onChange(of: pet.hasPassedAway) { _, hasPassedAway in
            if hasPassedAway {
                isEditing = false
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
            loadEditState()
            isEditing = true
        }
        .task(id: vetVisitSummaryPreparationSignature) {
            await prepareVetVisitSummaryText()
        }
        .sheet(item: $personalUpgradePrompt) { prompt in
            PersonalPlanView(prompt: prompt)
                .ohanaSheetPagePresentation()
        }
        .onDisappear {
            healthSummaryLoadTask?.cancel()
            healthSummaryLoadTask = nil
        }
        .accessibilityIdentifier("pet-basic-info-screen")
    }

    @ViewBuilder
    private func petCareTaskButton(
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
