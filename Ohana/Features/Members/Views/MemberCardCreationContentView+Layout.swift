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
                MemberPortraitDraftCardSurface(snapshot: snapshot) {
                    cardControls
                }
                .allowsHitTesting(true)
            }

            if let joinHandoffSnapshot, isJoinHandoffRunning {
                MemberCreationJoinHandoffCard(snapshot: joinHandoffSnapshot)
                    .modifier(MemberCreationJoinHandoffModifier(
                        progress: joinHandoffProgress,
                        reduceMotion: reduceMotion
                    ))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: 390)
        .frame(maxHeight: .infinity)
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

    var topChrome: some View {
        HStack(spacing: 10) {
            Button {
                clearMediaReturnStepStorage()
                onCancel?()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.cancel)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title(l))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(l.tr(zh: "先加入，更多资料稍后编辑", en: "Add now, edit details later", de: "Jetzt hinzufügen, Details später bearbeiten"))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer()
        }
    }

    @ViewBuilder
    var cardControls: some View {
        VStack(alignment: .leading, spacing: cardControlsSpacing) {
            currentStepContent
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            MemberCreationStepIndicator(
                steps: creationSteps,
                currentStep: currentStep,
                kind: kind,
                l: l,
                foreground: cardForeground,
                secondaryForeground: cardSecondaryForeground,
                inactiveFill: cardControlFill
            )
            .layoutPriority(2)
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
            if kind == .pet {
                petBasicInfoStep
            } else {
                humanBasicInfoStep
            }
        case .petProfile:
            petProfileSection
        case .avatar:
            avatarSection
        case .theme:
            themeSection
        }
    }

    var bottomCTA: some View {
        let isEnabled = isLastStep ? canSave : canAdvanceStep
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
                                .font(OhanaFont.adaptive(size: 12, weight: .black))
                            Text(l.tr(zh: "上一步", en: "Back", de: "Zurück"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                        .frame(width: 104, height: 54)
                        .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isJoinHandoffRunning || isSaving)
                }

                Button {
                    if isLastStep {
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
                            Image(systemName: isLastStep ? "checkmark.seal.fill" : "chevron.right")
                        }
                        Text(isLastStep ? creationCTA : l.tr(zh: "下一步", en: "Next", de: "Weiter"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(isEnabled ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isEnabled ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(!isEnabled)
            }
            .frame(maxWidth: 390)
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
