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
        AddPlantCreationStep.allCases
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
        return trimmedSpecies
    }

    var canAdvanceStep: Bool {
        guard !isSaving else { return false }
        switch currentStep {
        case .plant:
            return selectedCatalog != nil && !resolvedPlantName.isEmpty
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
                    plantTopChrome
                        .frame(maxWidth: MemberCreationCardLayout.maxCardWidth)
                        .opacity(isSaving ? 0.42 : 1)
                        .allowsHitTesting(!isSaving)
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
                    subtitle: l.tr(zh: "植物卡片正在进入卡片堆", en: "The plant card is joining the stack", de: "Die Pflanzenkarte wird in den Stapel eingefügt"),
                    systemImage: "leaf.fill",
                    accent: Color.goTeal
                )
                .zIndex(50)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
                media.prepareCameraIfNeeded()
            }
        }
        .accessibilityIdentifier("add-plant-step-flow")
    }

    var plantTopChrome: some View {
        HStack(spacing: 10) {
            Button {
                onComplete()
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative close glyph; button has localized Cancel label.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.cancel)
            .accessibilityIdentifier("add-plant-cancel-action")

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "添加植物", en: "Add plant", de: "Pflanze hinzufügen"))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(plantTopChromeSubtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer()
        }
    }

    var plantTopChromeSubtitle: String {
        switch currentStep {
        case .plant:
            l.tr(zh: "先选植物、名字和房间", en: "Pick a plant, name, and room", de: "Pflanze, Name und Raum wählen")
        case .avatar:
            l.tr(zh: "选择自带 3D 头像或照片", en: "Choose a built-in 3D avatar or photo", de: "3D-Avatar oder Foto wählen")
        case .care:
            l.tr(zh: "按推荐值微调护理信息", en: "Tune the recommended care info", de: "Empfohlene Pflegeinfos anpassen")
        case .confirm:
            l.tr(zh: "确认后加入植物卡片堆", en: "Confirm and join the plant stack", de: "Bestätigen und Karte hinzufügen")
        }
    }

    var plantCreationCardArea: some View {
        PlantCreationCardSurface {
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
        max(
            340,
            MemberCreationCardLayout.cardHeight(
                in: containerHeight,
                includesTopChrome: true
            ) - 84
        )
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
            plantConfirmationStep
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
                        .font(OhanaFont.callout(.black))
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
                .font(OhanaFont.callout(.black))
                .foregroundStyle(enabled ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(enabled ? Color.goPrimary.opacity(0.42) : Color.ohanaCardSurface.opacity(0.18), lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(actionTitle)
                .accessibilityIdentifier(actionIdentifier)
            }
            .buttonStyle(ScaleButtonStyle(triggersHaptic: !isLastStep))
            .disabled(!enabled)
            .accessibilityIdentifier(actionIdentifier)
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
