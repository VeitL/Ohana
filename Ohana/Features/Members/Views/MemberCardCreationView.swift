//
//  MemberCardCreationView.swift
//  Ohana
//
//  Portrait-card member creation flow for humans and pets.
//

import AVFoundation
import Combine
import ImageIO
import os
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MemberCardCreationContentView: View {
    let kind: MemberCreationKind
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onPetSaved: ((Pet) -> Void)?
    var onHumanSaved: ((Human) -> Void)?
    let existingPets: [Pet]
    let existingHumans: [Human]
    let recoverySessionId: UUID
    let presentationStyle: MemberCreationPresentationStyle

    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.memberCreationCardFlipProgress) var memberCreationCardFlipProgress
    @Environment(AppServices.self) var appServices
    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @AppStorage(AppCountry.storageKey) var appCountry = AppCountry.detectedCode
    @AppStorage(Avatar2DAccess.extraPassInventoryKey) var avatarPassCount = 0
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenHomePetIDsRaw = ""
    @SceneStorage("memberCreation.pet.mediaReturnStep") var petMediaReturnStepRaw = ""
    @SceneStorage("memberCreation.human.mediaReturnStep") var humanMediaReturnStepRaw = ""
    @SceneStorage("memberCreation.pet.mediaReturnSession") var petMediaReturnSessionRaw = ""
    @SceneStorage("memberCreation.human.mediaReturnSession") var humanMediaReturnSessionRaw = ""
    @SceneStorage("memberCreation.pet.mediaRecovery") var petMediaRecoveryRaw = ""
    @SceneStorage("memberCreation.human.mediaRecovery") var humanMediaRecoveryRaw = ""

    @State var draft: MemberCreationDraft
    @State var decodedAvatar: UIImage?
    @State var decodedAvatarTransparent = false
    @State var decodeTask: Task<Void, Never>?
    @StateObject var media = MemberAvatarMediaCoordinator()
    @State var isSaving = false
    @State var errorMessage = ""
    @State var showError = false
    @State var showPurchaseConfirm = false
    @State var didConfigureInitialAvatar = false
    @State var didConfigureAvatarStep = false
    @State var shouldApply2DAfterPurchase = false
    @State var didShowSuccess = false
    @State var isPreparingCamera = false
    @State var currentStep: MemberCreationStep = .basicInfo
    @State var lastCustomAvatarImageData: Data?
    @State var avatarMediaReturnStep: MemberCreationStep?
    @State var isAvatarMediaTransitioning = false
    @State var cropPresentationTask: Task<Void, Never>?
    @State var mbtiEnergy = ""
    @State var mbtiInformation = ""
    @State var mbtiDecision = ""
    @State var mbtiLifestyle = ""
    @State var usesCustomResidenceCity = false
    @State var isJoinHandoffRunning = false
    @State var joinHandoffProgress: CGFloat = 0
    @State var joinHandoffSnapshot: MemberCardRenderSnapshot?
    @State var joinSaveTask: Task<Void, Never>?

    init(
        kind: MemberCreationKind,
        onComplete: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onPetSaved: ((Pet) -> Void)? = nil,
        onHumanSaved: ((Human) -> Void)? = nil,
        existingPets: [Pet],
        existingHumans: [Human],
        recoverySessionId: UUID = UUID(),
        presentationStyle: MemberCreationPresentationStyle = .standard
    ) {
        self.kind = kind
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onPetSaved = onPetSaved
        self.onHumanSaved = onHumanSaved
        self.existingPets = existingPets
        self.existingHumans = existingHumans
        self.recoverySessionId = recoverySessionId
        self.presentationStyle = presentationStyle
        _draft = State(initialValue: MemberCreationDraft(kind: kind))
    }

    var l: L10n { L10n(appLanguage) }
    var existingCount: Int { kind == .pet ? existingPets.count : existingHumans.count }
    var canUseFree2D: Bool { Avatar2DAccess.usesFreeSlot(kind: kind.avatarKind, existingCount: existingCount) }
    var has2DAccess: Bool { canUseFree2D || avatarPassCount > 0 }
    var currentHuman: Human? { appServices.memberCreation.currentHuman(in: existingHumans) }
    var currentBalance: Int { currentHuman?.coconutBalance ?? 0 }
    var avatarPassCost: Int { appServices.memberCreation.avatarPassCost }
    var duplicateName: Bool {
        let candidate = draft.trimmedName.lowercased()
        guard !candidate.isEmpty else { return false }
        let names = existingPets.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            + existingHumans.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return names.contains(candidate)
    }

    var canSave: Bool {
        !isSaving && !isJoinHandoffRunning && !draft.trimmedName.isEmpty && !duplicateName
    }

    var creationSteps: [MemberCreationStep] { MemberCreationStep.steps(for: kind) }
    var currentStepIndex: Int { creationSteps.firstIndex(of: currentStep) ?? 0 }
    var isLastStep: Bool { currentStepIndex == creationSteps.count - 1 }
    var canAdvanceStep: Bool {
        guard !isSaving, !isJoinHandoffRunning else { return false }
        if currentStep == .basicInfo {
            return !draft.trimmedName.isEmpty && !duplicateName
        }
        return true
    }

    var canRunHomeJoinHandoff: Bool {
        HomeCardVisibility.visibleCardCount(
            pets: existingPets,
            humans: existingHumans,
            raw: hiddenHomePetIDsRaw
        ) < HomeCardVisibility.maxVisibleCards
    }

    var mbtiSignature: String {
        [mbtiEnergy, mbtiInformation, mbtiDecision, mbtiLifestyle].joined(separator: "|")
    }

    var cardAccent: Color {
        Color(hex: draft.normalizedThemeHex)
    }

    var prefersDarkCardForeground: Bool {
        WalletPetCardTheme.prefersDarkForeground(for: draft.normalizedThemeHex)
    }

    var cardForeground: Color {
        Color.goCardWhite.opacity(0.94)
    }

    var cardSecondaryForeground: Color {
        Color.goCardWhite.opacity(0.66)
    }

    var cardControlFill: Color {
        Color.goCardWhite.opacity(0.14)
    }

    var cardControlStroke: Color {
        Color.goCardWhite.opacity(0.30)
    }

    var cardSelectedFill: Color {
        cardAccent.mix(with: .white, by: 0.28)
    }

    var cardSelectedForeground: Color {
        WalletPetCardTheme.prefersDarkForeground(for: draft.normalizedThemeHex) ? Color.arkInk : Color.goCardWhite
    }

    var stepContentSpacing: CGFloat { 18 }

    var profileCardFlipProgress: CGFloat {
        guard presentationStyle == .onboarding,
              let memberCreationCardFlipProgress else {
            return 1
        }
        return min(max(memberCreationCardFlipProgress, 0), 1)
    }

    var profileCardFlipIsActive: Bool {
        presentationStyle == .onboarding && memberCreationCardFlipProgress != nil
    }

    var profileCardFlipOpacity: Double {
        guard profileCardFlipIsActive else { return 1 }
        return profileCardFlipProgress > 0.48 ? 1 : 0
    }

    var profileCardFlipAngle: Double {
        guard profileCardFlipIsActive, !reduceMotion else { return 0 }
        return 180 - 180 * Double(profileCardFlipProgress)
    }

    var snapshot: MemberCardRenderSnapshot {
        let displayName = draft.trimmedName.isEmpty ? l.tr(zh: "新成员", en: "New member", de: "Neues Mitglied") : draft.trimmedName
        return MemberCardRenderSnapshot(
            kind: kind,
            title: displayName,
            subtitle: cardSubtitle,
            themeColorHex: draft.normalizedThemeHex,
            avatarImage: decodedAvatar,
            avatarIsTransparent: decodedAvatarTransparent,
            avatarSource: draft.avatarSource,
            fallbackSymbol: kind == .pet ? petFallbackSymbol : "person.fill",
            statusText: avatarStatusText
        )
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            GeometryReader { proxy in
                let cardHeight = MemberCreationCardLayout.cardHeight(
                    in: proxy.size.height,
                    includesTopChrome: presentationStyle.showsTopChrome
                )
                VStack(spacing: MemberCreationCardLayout.stackSpacing) {
                    Spacer(minLength: 0)
                    if presentationStyle.showsTopChrome {
                        topChrome
                            .frame(maxWidth: MemberCreationCardLayout.maxCardWidth)
                            .opacity(isJoinHandoffRunning ? 0.28 : 1)
                            .allowsHitTesting(!isJoinHandoffRunning)
                    }
                    creationCardArea
                        .frame(height: cardHeight)
                        .opacity(profileCardFlipOpacity)
                        .rotation3DEffect(
                            .degrees(profileCardFlipAngle),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.78
                        )
                    bottomCTA
                        .opacity(isJoinHandoffRunning ? 0 : 1)
                        .allowsHitTesting(!isJoinHandoffRunning)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, MemberCreationCardLayout.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            if didShowSuccess {
                AddWizardJoinCelebrationOverlay(
                    title: l.tr(zh: "\(draft.trimmedName) 已加入 Ohana", en: "\(draft.trimmedName) joined Ohana", de: "\(draft.trimmedName) ist bei Ohana"),
                    subtitle: l.tr(zh: "成员竖卡已准备好", en: "The portrait card is ready", de: "Die Hochformatkarte ist bereit"),
                    systemImage: kind == .pet ? "pawprint.fill" : "person.crop.circle.badge.checkmark",
                    accent: Color(hex: draft.normalizedThemeHex)
                )
                .zIndex(50)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            MemberCreationPerformance.event("Member Creation Appeared")
            restoreMediaRecoverySnapshotIfNeeded()
            restoreMediaReturnStepFromSceneStorage()
            configureInitialAvatarIfNeeded()
            scheduleAvatarDecode()
            OhanaFrameScheduler.runAfterNextFrame(milliseconds: presentationStyle.cameraPreparationDelayMilliseconds) {
                media.prepareCameraIfNeeded()
            }
        }
        .onDisappear {
            MemberCreationPerformance.event("Member Creation Disappeared")
            decodeTask?.cancel()
            joinSaveTask?.cancel()
            if !isAvatarMediaTransitioning {
                cropPresentationTask?.cancel()
                cropPresentationTask = nil
                if !isSaving, !isJoinHandoffRunning {
                    clearMediaReturnStepStorage()
                }
            }
        }
        .onChange(of: draft.name) { _, _ in
            MemberCreationPerformance.event("Draft Name Changed")
        }
        .onChange(of: draft.avatarImageData) { _, _ in scheduleAvatarDecode() }
        .onChange(of: avatarRefreshSignature) { _, _ in refresh2DAvatarForProfileChange() }
        .onChange(of: mbtiSignature) { _, _ in updateDraftMBTI() }
        .onChange(of: currentStep) { _, newStep in
            if newStep == .avatar {
                configureAvatarStepIfNeeded()
            }
        }
        .onChange(of: media.photoItem) { _, item in handlePhotoPickerItem(item) }
        .photosPicker(
            isPresented: Binding(
                get: { media.isPhotoPickerPresented },
                set: { isPresented in
                    if !isPresented, media.isPhotoPickerPresented {
                        media.route = nil
                        handlePhotoLibraryDismissed()
                    }
                }
            ),
            selection: $media.photoItem,
            matching: .images
        )
        .fullScreenCover(
            isPresented: Binding(
                get: { media.isCameraPresented },
                set: { isPresented in
                    if !isPresented, media.isCameraPresented {
                        media.route = nil
                        handleCameraDismissed()
                    }
                }
            )
        ) {
            MemberCameraCaptureView(maxPixel: 2000) { image in
                media.route = nil
                Task {
                    let normalizeID = MemberCreationPerformance.begin("Camera Image Normalize")
                    let prepared = await Task.detached(priority: .userInitiated) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
                        MemberAvatarImageProcessor.normalized(image)
                    }.value
                    MemberCreationPerformance.end("Camera Image Normalize", normalizeID)
                    await MainActor.run {
                        presentAvatarCropAfterMediaDismissal(
                            MemberPortraitCropItem(source: .image(prepared)),
                            delayMilliseconds: 320
                        )
                    }
                }
            } onCancel: {
                media.route = nil
                finishAvatarMediaPresentation()
            }
        }
        .sheet(
            item: Binding<MemberPortraitCropItem?>(
                get: { media.cropItem },
                set: { item in
                    if item == nil, media.cropItem != nil {
                        media.route = nil
                    }
                }
            )
        ) { item in
            MemberPortraitCropView(item: item) { data in
                withAnimation(GoMotion.selection) {
                    draft.avatarSource = .customImage
                    draft.selectedAvatarCandidateId = nil
                    draft.usesPurchasedOrInventoryPass = false
                    lastCustomAvatarImageData = data
                    draft.avatarImageData = data
                }
                media.route = nil
                finishAvatarMediaPresentation()
            } onCancel: {
                media.route = nil
                finishAvatarMediaPresentation()
            }
            .presentationDetents([.large]) // ui-v4: allow portrait crop editor needs full-height working area
        }
        .alert(l.tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar"), isPresented: permissionAlertBinding) {
            Button(l.done, role: .cancel) {
                media.route = nil
                finishAvatarMediaPresentation()
            }
        } message: {
            Text(l.tr(zh: "请在系统设置中允许 Ohana 访问相机，或在支持相机的设备上使用。", en: "Allow camera access in Settings, or use a device with a camera.", de: "Erlaube den Kamerazugriff in den Einstellungen oder nutze ein Gerät mit Kamera."))
        }
        .alert(l.tr(zh: "购买 2.5D 头像券", en: "Buy 2.5D Avatar Pass", de: "2,5D-Avatarpass kaufen"), isPresented: $showPurchaseConfirm) {
            Button(l.cancel, role: .cancel) { shouldApply2DAfterPurchase = false }
            Button(l.tr(zh: "购买头像券", en: "Buy pass", de: "Pass kaufen")) {
                purchaseAvatarPass()
            }
        } message: {
            Text(l.tr(zh: "将消耗 \(avatarPassCost) 个椰子。购买后会为当前草稿开启智能 2.5D 头像；取消创建时头像券仍保留。", en: "Costs \(avatarPassCost) coconuts. After purchase, the smart 2.5D avatar is applied to this draft; canceling creation keeps the pass.", de: "Kostet \(avatarPassCost) Kokosnüsse. Danach wird der smarte 2,5D-Avatar auf diesen Entwurf angewendet; beim Abbrechen bleibt der Pass erhalten."))
        }
        .alert(l.tr(zh: "无法创建成员", en: "Could not create member", de: "Mitglied konnte nicht erstellt werden"), isPresented: $showError) {
            Button(l.done, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}
