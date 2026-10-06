//
//  MemberCardCreationContentView+Layout.swift
//  Ohana
//

import AVFoundation
import Combine
import ImageIO
import os
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

extension MemberCardCreationContentView {
    var creationCardArea: some View {
        ZStack {
            if !isJoinHandoffRunning {
                MemberPortraitDraftCardSurface(
                    snapshot: snapshot,
                    layoutMode: memberPortraitCardLayoutMode,
                    showsAvatar: shouldShowDraftCardAvatar
                ) {
                    cardControls
                }
                .allowsHitTesting(true)
            }

            if presentationStyle != .onboarding,
               let joinHandoffSnapshot,
               isJoinHandoffRunning {
                MemberCreationJoinHandoffCard(snapshot: joinHandoffSnapshot)
                    .modifier(MemberCreationJoinHandoffModifier(
                        progress: joinHandoffProgress,
                        reduceMotion: reduceMotion
                    ))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: MemberCreationCardLayout.maxCardWidth)
    }

    var memberPortraitCardLayoutMode: MemberPortraitDraftCardLayoutMode {
        if kind == .pet, currentStep == .avatar {
            return .avatarFocus
        }
        if currentStep == .petPersonality, !dynamicTypeSize.isAccessibilitySize {
            return .compactPersonalization
        }
        return .standard
    }

    var shouldShowDraftCardAvatar: Bool {
        kind != .pet || currentStep == .avatar
    }

    var permissionAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .permissionAlert = media.route { return true }
                return false
            },
            set: { isShowing in
                if !isShowing, case .permissionAlert = media.route {
                    media.route = nil
                    finishAvatarMediaPresentation()
                }
            }
        )
    }

    @ViewBuilder
    var cardControls: some View {
        VStack(alignment: .leading, spacing: cardControlsSpacing) {
            currentStepContent
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            if kind == .pet, currentStep == .petPersonality || currentStep == .avatar {
                Text(PetCareExperienceCopy(l: l).optionalLater)
                    .font(OhanaFont.caption())
                    .foregroundStyle(cardSecondaryForeground)
            }
            if let fieldMessage = creationFieldMessage {
                Text(fieldMessage)
                    .font(OhanaFont.caption())
                    .foregroundStyle(cardSecondaryForeground)
                    .accessibilityIdentifier("member-creation-field-message")
            }
            if kind != .human || currentStep != .basicInfo {
            MemberCreationStepIndicator(
                steps: creationSteps,
                currentStep: currentStep,
                kind: kind,
                l: l,
                secondaryForeground: cardSecondaryForeground,
                inactiveFill: cardControlFill
            )
            .layoutPriority(2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    var cardControlsSpacing: CGFloat {
        currentStep == .theme && kind == .human ? 10 : 14
    }

    @ViewBuilder
    var currentStepContent: some View {
        switch currentStep {
        case .basicInfo:
            humanBasicInfoStep
        case .petName:
            petNameStep
        case .petIdentity:
            petIdentityStep
        case .petAppearance:
            petAppearanceStep
        case .avatar:
            avatarSection
        case .petPersonality:
            petPersonalityStep
        case .theme:
            themeSection
        }
    }

    var bottomCTA: some View {
        let savesImmediately = isLastStep || (kind == .human && currentStep == .basicInfo)
        let isEnabled = savesImmediately ? canSave : canAdvanceStep
        return VStack(spacing: 8) {
            if duplicateName {
                Text(l.tr(zh: "这个名字已经被使用。", en: "This name is already in use.", de: "Dieser Name wird bereits verwendet."))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.goRed)
            }
            HStack(spacing: 10) {
                if shouldShowBottomBackButton {
                    Button {
                        handleBottomBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left").accessibilityHidden(true)
                                .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                            Text(l.tr(zh: "上一步", en: "Back", de: "Zurück"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .font(OhanaFont.callout(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                        .frame(minWidth: 96, idealWidth: 112, maxWidth: 154, minHeight: 54)
                        .background(Color.goCardWhite.opacity(0.12), in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.goCardWhite.opacity(0.18), lineWidth: 1)
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("member-creation-back-action")
                    .disabled(isJoinHandoffRunning || isSaving)
                }

                Button {
                    if savesImmediately {
                        save()
                    } else {
                        advanceStep()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(Color.ohanaPrimaryActionText)
                        } else {
                            Image(systemName: savesImmediately ? "checkmark.seal.fill" : "chevron.right").accessibilityHidden(true)
                        }
                        Text(creationPrimaryTitle)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .font(OhanaFont.callout(.semibold))
                    .foregroundStyle(isEnabled ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .frame(minHeight: 54)
                    .background(isEnabled ? Color.goPrimary : Color.goCardWhite.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(isEnabled ? Color.goPrimary.opacity(0.42) : Color.goCardWhite.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: isEnabled ? Color.goPrimary.opacity(0.22) : Color.clear, radius: 14, y: 6) // ui-v4: allow primary creation action glow
                }
                .buttonStyle(ScaleButtonStyle(triggersHaptic: !isLastStep))
                .accessibilityIdentifier("member-creation-primary-action")
                .disabled(!isEnabled)
            }
            .frame(maxWidth: MemberCreationCardLayout.maxCardWidth)
            if kind == .human, currentStep == .basicInfo {
                Button(HumanHealthHomeText.customize.title(l)) { advanceStep() }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .disabled(!canAdvanceStep || isSaving)
                    .accessibilityIdentifier("member-human-customize-action")
            }
            if kind == .pet, currentStep == .avatar {
                Button(PetCareExperienceCopy(l: l).finishWithDefaultAvatar) {
                    finishPetWithDefaultAvatar()
                }
                .font(OhanaFont.callout())
                .buttonStyle(.plain)
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(minHeight: 44)
                .disabled(!canSave)
                .accessibilityIdentifier("member-pet-avatar-skip")
            }
        }
    }

    var creationPrimaryTitle: String {
        if kind == .pet, currentStep == .petPersonality, draft.personalityTagIds.isEmpty {
            return PetCareExperienceCopy(l: l).skipPersonality
        }
        return (isLastStep || (kind == .human && currentStep == .basicInfo)) ? creationCTA : l.tr(zh: "下一步", en: "Next", de: "Weiter")
    }

    var creationFieldMessage: String? {
        guard kind == .pet else { return nil }
        let copy = PetCareExperienceCopy(l: l)
        switch currentStep {
        case .petName:
            return draft.trimmedName.isEmpty ? copy.requiredName : nil
        case .petIdentity:
            return draft.resolvedSpecies.isEmpty || draft.resolvedBreed.isEmpty ? copy.requiredSpeciesBreed : nil
        case .petAppearance:
            return ["boy", "girl"].contains(draft.petGender) ? nil : copy.requiredSex
        default:
            return nil
        }
    }

    var creationCTA: String {
        l.tr(zh: "加入岛屿", en: "Join Island", de: "Insel beitreten")
    }

    var shouldShowBottomBackButton: Bool {
        currentStepIndex > 0 || presentationStyle.keepsBackButtonVisible
    }

    func handleBottomBack() {
        if currentStepIndex > 0 {
            retreatStep()
        } else {
            clearMediaReturnStepStorage()
            onCancel?()
        }
    }
}
