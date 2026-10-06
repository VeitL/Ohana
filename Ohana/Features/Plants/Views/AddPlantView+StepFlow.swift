//
//  AddPlantView+StepFlow.swift
//  Ohana
//
//  Card-step shell and media routing for Add Plant.
//

import PhotosUI
import SwiftUI
import UIKit

extension AddPlantView {
    var plantCreationSteps: [AddPlantCreationStep] {
        [.plant, .confirm]
    }

    var currentStepIndex: Int {
        plantCreationSteps.firstIndex(of: currentStep) ?? 0
    }

    var isLastStep: Bool {
        currentStepIndex == plantCreationSteps.count - 1
    }

    var resolvedPlantName: String {
        if !trimmedName.isEmpty { return trimmedName }
        if let selectedCatalog { return selectedCatalog.localizedCommonName }
        if !trimmedSpecies.isEmpty { return trimmedSpecies }
        return isUnknownSpeciesSelected ? l.tr(zh: "我的植物", en: "My plant", de: "Meine Pflanze") : ""
    }

    var canAdvanceStep: Bool {
        guard !isSaving else { return false }
        switch currentStep {
        case .plant:
            return selectedCatalog != nil || isUnknownSpeciesSelected
        case .avatar, .care:
            return true
        case .confirm:
            return !resolvedPlantName.isEmpty
        }
    }

    var plantCreationFlow: some View {
        ZStack {
            OhanaAppBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { proxy in
                let cardHeight = plantCreationCardHeight(in: proxy.size.height)
                VStack(spacing: MemberCreationCardLayout.stackSpacing) {
                    Spacer(minLength: 0)
                    plantCreationCardArea
                        .frame(height: cardHeight)
                    plantBottomCTA
                        .opacity(didShowSuccess ? 0 : 1)
                        .allowsHitTesting(!didShowSuccess)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, MemberCreationCardLayout.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }

            if didShowSuccess {
                AddWizardJoinCelebrationOverlay(
                    title: l.tr(zh: "\(resolvedPlantName) 已加入植物页", en: "\(resolvedPlantName) joined Plants", de: "\(resolvedPlantName) ist bei Pflanzen"),
                    systemImage: "leaf.fill",
                    accent: Color.goTeal
                )
                .zIndex(50)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(alignment: .topLeading) {
            PlantCreationAccessibilityMarker(identifier: "add-plant-step-flow")
        }
    }

    var plantCreationCardArea: some View {
        PlantCreationCardSurface(
            title: profilePreviewName,
            subtitle: plantCreationCardSubtitle,
            avatarImage: selectedAvatarSource == .customImage ? decodedAvatarImage : nil,
            catalog: selectedCatalog,
            layoutMode: plantCreationCardLayoutMode
        ) {
            currentPlantStepContent
            Spacer(minLength: 2)
            PlantCreationStepIndicator(
                steps: plantCreationSteps,
                currentStep: currentStep,
                l: l
            )
            .layoutPriority(2)
        }
        .frame(maxWidth: MemberCreationCardLayout.maxCardWidth)
    }

    func plantCreationCardHeight(in containerHeight: CGFloat) -> CGFloat {
        MemberCreationCardLayout.cardHeight(
            in: containerHeight,
            includesTopChrome: false
        )
    }

    var plantCreationCardLayoutMode: PlantCreationCardLayoutMode {
        switch currentStep {
        case .plant:
            .standard
        case .avatar:
            .avatarFocus
        case .care, .confirm:
            .compact
        }
    }

    var plantCreationCardSubtitle: String {
        let identity = selectedCatalog?.latinName ?? profilePreviewSpecies
        guard !trimmedRoomName.isEmpty else { return identity }
        return "\(identity) · \(trimmedRoomName)"
    }

    @ViewBuilder
    var currentPlantStepContent: some View {
        switch currentStep {
        case .plant:
            plantSelectionStep
        case .avatar:
            plantAvatarStep
        case .care:
            plantCareDetailsStep
        case .confirm:
            plantQuickSetupStep
        }
    }

    var plantQuickSetupStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            PlantCreationSection(
                title: l.tr(zh: "名字", en: "Name", de: "Name"),
                icon: "text.cursor"
            ) {
                plantNameSummarySection
            }
            PlantCreationSection(
                title: l.tr(zh: "摆放位置（可选）", en: "Placement (optional)", de: "Standort (optional)"),
                icon: "house.fill"
            ) {
                roomAndSpotControls
            }
            duplicateWarningSection
            Button {
                withAnimation(GoMotion.selection) {
                    showingOptionalPlantDetails.toggle()
                }
            } label: {
                Label(
                    l.tr(zh: "照片与更多资料（可选）", en: "Photo and more details (optional)", de: "Foto und weitere Angaben (optional)"),
                    systemImage: "slider.horizontal.3"
                )
                .font(OhanaFont.callout(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("add-plant-optional-details-toggle")
            if showingOptionalPlantDetails {
                plantAvatarStep
                plantCareDetailsStep
            }
        }
        .overlay(alignment: .topLeading) {
            PlantCreationAccessibilityMarker(identifier: "add-plant-step-confirm")
        }
    }

    var plantBottomCTA: some View {
        let enabled = isLastStep ? canAdvanceStep && !isSaving : canAdvanceStep
        let actionIdentifier = isLastStep ? "add-plant-save-action" : "add-plant-next-action"
        let actionTitle = isLastStep ? l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen") : l.tr(zh: "下一步", en: "Next", de: "Weiter")
        return HStack(spacing: 10) {
            if currentStepIndex > 0 {
                Button {
                    retreatPlantStep()
                } label: {
                    Label(l.tr(zh: "上一步", en: "Back", de: "Zurück"), systemImage: "chevron.left")
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                        .frame(minWidth: 96, idealWidth: 112, maxWidth: 154, minHeight: 54)
                        .background(Color.ohanaControlFill.opacity(0.62), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isSaving)
                .accessibilityIdentifier("add-plant-back-action")
            }

            Button {
                if isLastStep {
                    savePlant()
                } else {
                    advancePlantStep()
                }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(Color.ohanaPrimaryActionText)
                    } else {
                        Image(systemName: isLastStep ? "checkmark.seal.fill" : "chevron.right")
                            .accessibilityHidden(true)
                    }
                    Text(actionTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(enabled ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(enabled ? Color.goPrimary.opacity(0.42) : Color.ohanaCardSurface.opacity(0.18), lineWidth: 1)
                }
            }
            .buttonStyle(ScaleButtonStyle(triggersHaptic: !isLastStep))
            .accessibilityIdentifier(actionIdentifier)
            .accessibilityLabel(actionTitle)
            .disabled(!enabled)
        }
        .frame(maxWidth: MemberCreationCardLayout.maxCardWidth)
        .zIndex(10)
    }

    func advancePlantStep() {
        guard canAdvanceStep, !isLastStep else { return }
        GoKeyboard.dismiss()
        withAnimation(GoMotion.selection) {
            currentStep = plantCreationSteps[min(currentStepIndex + 1, plantCreationSteps.count - 1)]
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func retreatPlantStep() {
        guard currentStepIndex > 0 else { return }
        GoKeyboard.dismiss()
        withAnimation(GoMotion.selection) {
            currentStep = plantCreationSteps[max(currentStepIndex - 1, 0)]
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    var plantPermissionAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .permissionAlert = media.route { return true }
                return false
            },
            set: { isShowing in
                if !isShowing, case .permissionAlert = media.route {
                    media.route = nil
                    finishPlantAvatarMediaPresentation()
                }
            }
        )
    }

    func openPlantPhotoLibraryAfterFirstFrame() {
        GoKeyboard.dismiss()
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
            media.openPhotoLibrary()
        }
    }

    func openPlantCameraAfterFirstFrame() {
        guard !isPreparingCamera else { return }
        GoKeyboard.dismiss()
        isPreparingCamera = true
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
            media.openCamera()
            isPreparingCamera = false
        }
    }

    func handlePlantPhotoPickerItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        media.photoItem = nil
        media.route = nil
        presentPlantAvatarCrop(
            MemberPortraitCropItem(source: .photoItem(item)),
            delayMilliseconds: 140
        )
    }

    func presentPlantAvatarCrop(_ item: MemberPortraitCropItem, delayMilliseconds: UInt64) {
        cropPresentationTask?.cancel()
        cropPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            media.showCrop(for: item)
        }
    }

    func applyPlantAvatarImageData(_ data: Data) {
        withAnimation(GoMotion.selection) {
            avatarImageData = data
            decodedAvatarImage = MemberAvatarImageProcessor.image(from: data, maxPixel: 900)
            selectedAvatarSource = .customImage
        }
    }

    func selectBuiltInPlantAvatar() {
        withAnimation(GoMotion.selection) {
            avatarImageData = nil
            decodedAvatarImage = nil
            selectedAvatarSource = .builtIn
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func finishPlantAvatarMediaPresentation() {
        isPreparingCamera = false
        cropPresentationTask?.cancel()
        cropPresentationTask = nil
    }
}
