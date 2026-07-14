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
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaAppLanguageCode) var appLanguage

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @State var isEditing = false
    @State var breedTipsExpanded = true

    @State var showingRainbowBridgeAlert = false
    @State var showingUndoPassingAlert = false
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
                if isEditing, !pet.hasPassedAway {
                    Button {
                        saveChanges()
                    } label: {
                        Text(l.save)
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Pet.canonicalSex(eGender) == nil ? Color.ohanaSecondaryText : Color.goPrimary)
                    }
                    .accessibilityIdentifier("pet-basic-info-save-action")
                    .disabled(Pet.canonicalSex(eGender) == nil)
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
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) { withAnimation { isEditing = false } }
                        .accessibilityIdentifier("pet-basic-info-cancel-edit-action")
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
        }
        .task(id: vetVisitSummaryPreparationSignature) {
            await prepareVetVisitSummaryText()
        }
        .onDisappear {
            healthSummaryLoadTask?.cancel()
            healthSummaryLoadTask = nil
        }
        .accessibilityIdentifier("pet-basic-info-screen")
    }

    // MARK: - Read View
}
