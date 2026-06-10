//
//  MemberCardCreationContentView+MediaAndSave.swift
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
    func configureInitialAvatarIfNeeded() {
        guard !didConfigureInitialAvatar else { return }
        didConfigureInitialAvatar = true
        clampPetAppearance()
    }

    func configureAvatarStepIfNeeded() {
        guard !didConfigureAvatarStep else { return }
        didConfigureAvatarStep = true
        guard canUseFree2D, draft.avatarSource == .placeholder else { return }
        applyDefault2DCandidate(usesInventoryPass: false)
    }

    func advanceStep() {
        guard canAdvanceStep, !isLastStep else { return }
        GoKeyboard.dismiss()
        withAnimation(GoMotion.selection) {
            currentStep = creationSteps[min(currentStepIndex + 1, creationSteps.count - 1)]
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func retreatStep() {
        guard currentStepIndex > 0 else { return }
        GoKeyboard.dismiss()
        withAnimation(GoMotion.selection) {
            currentStep = creationSteps[max(currentStepIndex - 1, 0)]
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func updateDraftMBTI() {
        let letters = [mbtiEnergy, mbtiInformation, mbtiDecision, mbtiLifestyle]
        draft.mbti = letters.allSatisfy { !$0.isEmpty } ? letters.joined() : ""
    }

    func refresh2DAvatarForProfileChange() {
        clampPetAppearance()
        guard draft.avatarSource == .avatar2D else { return }
        applyDefault2DCandidate(usesInventoryPass: draft.usesPurchasedOrInventoryPass)
    }

    func applyDefault2DCandidate(usesInventoryPass: Bool? = nil) {
        guard let candidate = avatarCandidates.first else { return }
        apply(candidate, usesInventoryPass: usesInventoryPass ?? !canUseFree2D)
    }

    func apply(_ candidate: Avatar2DCandidate, usesInventoryPass: Bool? = nil) {
        rememberCurrentCustomAvatarIfNeeded()
        withAnimation(GoMotion.selection) {
            draft.avatarSource = .avatar2D
            draft.selectedAvatarCandidateId = candidate.id
            draft.avatarImageData = candidate.data
            draft.usesPurchasedOrInventoryPass = usesInventoryPass ?? !canUseFree2D
        }
    }

    func toggle2DAvatar() {
        if draft.avatarSource == .avatar2D {
            clearAvatarSelection()
        } else {
            enable2DAvatarFromToggle()
        }
    }

    func enable2DAvatarFromToggle() {
        if canUseFree2D {
            applyDefault2DCandidate(usesInventoryPass: false)
            return
        }
        if avatarPassCount > 0 {
            applyDefault2DCandidate(usesInventoryPass: true)
            return
        }
        guard currentHuman != nil else {
            showInlineError(l.tr(zh: "需要先有一个当前人类成员来支付椰子。", en: "Create or select a human member before spending coconuts.", de: "Erstelle oder wähle zuerst ein menschliches Mitglied."))
            return
        }
        guard currentBalance >= avatarPassCost else {
            let missing = avatarPassCost - currentBalance
            showInlineError(l.tr(zh: "还差 \(missing) 个椰子。", en: "Need \(missing) more coconuts.", de: "Noch \(missing) Kokosnüsse nötig."))
            return
        }
        shouldApply2DAfterPurchase = true
        showPurchaseConfirm = true
    }

    func clearAvatarSelection() {
        withAnimation(GoMotion.selection) {
            if let lastCustomAvatarImageData {
                draft.avatarSource = .customImage
                draft.avatarImageData = lastCustomAvatarImageData
            } else {
                draft.avatarSource = .placeholder
                draft.avatarImageData = nil
            }
            draft.selectedAvatarCandidateId = nil
            draft.usesPurchasedOrInventoryPass = false
        }
    }

    func rememberCurrentCustomAvatarIfNeeded() {
        guard draft.avatarSource == .customImage,
              let data = draft.avatarImageData
        else { return }
        lastCustomAvatarImageData = data
    }

    func beginAvatarMediaPresentation() {
        guard !isAvatarMediaTransitioning else { return }
        GoKeyboard.dismiss()
        avatarMediaReturnStep = currentStep
        storeMediaReturnStep(currentStep)
        storeMediaRecoverySnapshot()
        isAvatarMediaTransitioning = true
    }

    func finishAvatarMediaPresentation() {
        restoreAvatarMediaReturnStep()
        avatarMediaReturnStep = nil
        isAvatarMediaTransitioning = false
        cropPresentationTask?.cancel()
        cropPresentationTask = nil
    }

    func restoreAvatarMediaReturnStep() {
        guard let step = avatarMediaReturnStep,
              creationSteps.contains(step),
              currentStep != step
        else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentStep = step
        }
    }

    func restoreMediaReturnStepFromSceneStorage() {
        let rawStep = kind == .pet ? petMediaReturnStepRaw : humanMediaReturnStepRaw
        let rawSession = kind == .pet ? petMediaReturnSessionRaw : humanMediaReturnSessionRaw
        guard rawSession == recoverySessionId.uuidString else {
            if !rawStep.isEmpty || !rawSession.isEmpty {
                clearMediaReturnStepStorage()
            }
            return
        }
        guard let step = MemberCreationStep(rawValue: rawStep),
              creationSteps.contains(step),
              currentStep != step
        else { return }
        avatarMediaReturnStep = step
        restoreAvatarMediaReturnStep()
    }

    func restoreMediaRecoverySnapshotIfNeeded() {
        let rawSnapshot = kind == .pet ? petMediaRecoveryRaw : humanMediaRecoveryRaw
        guard draft.trimmedName.isEmpty,
              !rawSnapshot.isEmpty,
              let data = rawSnapshot.data(using: .utf8),
              let snapshot = try? JSONDecoder().decode(MemberCreationMediaRecoverySnapshot.self, from: data),
              snapshot.sessionId == recoverySessionId.uuidString,
              snapshot.isFresh
        else {
            let rawSession = kind == .pet ? petMediaReturnSessionRaw : humanMediaReturnSessionRaw
            if !rawSnapshot.isEmpty, rawSession != recoverySessionId.uuidString {
                clearMediaReturnStepStorage()
            }
            return
        }
        var restored = draft
        snapshot.apply(to: &restored)
        draft = restored
    }

    func storeMediaReturnStep(_ step: MemberCreationStep) {
        switch kind {
        case .pet:
            petMediaReturnStepRaw = step.rawValue
            petMediaReturnSessionRaw = recoverySessionId.uuidString
        case .human:
            humanMediaReturnStepRaw = step.rawValue
            humanMediaReturnSessionRaw = recoverySessionId.uuidString
        }
    }

    func storeMediaRecoverySnapshot() {
        let snapshot = MemberCreationMediaRecoverySnapshot(draft: draft, sessionId: recoverySessionId.uuidString)
        guard let data = try? JSONEncoder().encode(snapshot),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        switch kind {
        case .pet:
            petMediaRecoveryRaw = raw
        case .human:
            humanMediaRecoveryRaw = raw
        }
    }

    func clearMediaReturnStepStorage() {
        switch kind {
        case .pet:
            petMediaReturnStepRaw = ""
            petMediaReturnSessionRaw = ""
            petMediaRecoveryRaw = ""
        case .human:
            humanMediaReturnStepRaw = ""
            humanMediaReturnSessionRaw = ""
            humanMediaRecoveryRaw = ""
        }
    }

    func openPhotoLibraryAfterFirstFrame() {
        MemberCreationPerformance.event("Photo Library Button Tap")
        beginAvatarMediaPresentation()
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
            media.openPhotoLibrary()
        }
    }

    func openCameraAfterFirstFrame() {
        guard !isPreparingCamera else { return }
        MemberCreationPerformance.event("Camera Button Tap")
        beginAvatarMediaPresentation()
        isPreparingCamera = true
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 16) {
            media.openCamera()
            isPreparingCamera = false
        }
    }

    func handlePhotoPickerItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        beginAvatarMediaPresentation()
        let cropItem = MemberPortraitCropItem(source: .photoItem(item))
        media.photoItem = nil
        media.route = nil
        presentAvatarCropAfterMediaDismissal(cropItem, delayMilliseconds: 140)
    }

    func handlePhotoLibraryDismissed() {
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 140) {
            finishPhotoLibraryIfIdle()
        }
    }

    func handleCameraDismissed() {
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 140) {
            guard media.cropItem == nil, cropPresentationTask == nil else { return }
            finishAvatarMediaPresentation()
        }
    }

    func finishPhotoLibraryIfIdle() {
        guard !media.isPhotoPickerPresented,
              media.photoItem == nil,
              media.cropItem == nil,
              cropPresentationTask == nil,
              !media.isCameraPresented
        else { return }
        finishAvatarMediaPresentation()
    }

    func presentAvatarCropAfterMediaDismissal(
        _ item: MemberPortraitCropItem,
        delayMilliseconds: UInt64
    ) {
        cropPresentationTask?.cancel()
        cropPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delayMilliseconds) {
            guard !media.isPhotoPickerPresented, !media.isCameraPresented else {
                presentAvatarCropAfterMediaDismissal(item, delayMilliseconds: 140)
                return
            }
            restoreAvatarMediaReturnStep()
            cropPresentationTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 50) {
                guard !media.isPhotoPickerPresented, !media.isCameraPresented else {
                    presentAvatarCropAfterMediaDismissal(item, delayMilliseconds: 140)
                    return
                }
                media.showCrop(for: item)
                cropPresentationTask = nil
            }
        }
    }

    func scheduleAvatarDecode() {
        decodeTask?.cancel()
        guard let data = draft.avatarImageData else {
            decodedAvatar = nil
            decodedAvatarTransparent = false
            return
        }
        let snapshot = data
        decodeTask = Task.detached(priority: .userInitiated) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            let decodeID = MemberCreationPerformance.begin("Avatar Preview Decode")
            let image = UIImage(data: snapshot) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
            let transparent = image.map { ImageSubjectCutoutProcessor.imageHasTransparentPixels($0) } ?? false
            let rendered = image.map { image -> UIImage in
                let downsampled = MemberAvatarImageProcessor.downsample(image, maxPixel: 900, preserveAlpha: transparent)
                if transparent, let trimmed = ImageSubjectCutoutProcessor.trimmedTransparentSubjectImage(from: downsampled) {
                    return trimmed
                }
                return downsampled
            }
            MemberCreationPerformance.end("Avatar Preview Decode", decodeID)
            await MainActor.run {
                guard draft.avatarImageData == snapshot else { return }
                decodedAvatar = rendered
                decodedAvatarTransparent = transparent
            }
        }
    }

    func purchaseAvatarPass() {
        do {
            try appServices.memberCreation.purchaseAvatarPassForCurrentDraft(
                humans: existingHumans,
                context: modelContext,
                l: l
            )
            draft.usesPurchasedOrInventoryPass = false
            if shouldApply2DAfterPurchase {
                applyDefault2DCandidate(usesInventoryPass: true)
                shouldApply2DAfterPurchase = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let MemberCreationError.insufficientCoconuts(missing) {
            shouldApply2DAfterPurchase = false
            showInlineError(l.tr(zh: "还差 \(missing) 个椰子。", en: "Need \(missing) more coconuts.", de: "Noch \(missing) Kokosnüsse nötig."))
        } catch MemberCreationError.missingActiveHuman {
            shouldApply2DAfterPurchase = false
            showInlineError(l.tr(zh: "需要先有一个当前人类成员来支付椰子。", en: "Create or select a human member before spending coconuts.", de: "Erstelle oder wähle zuerst ein menschliches Mitglied."))
        } catch {
            shouldApply2DAfterPurchase = false
            showInlineError(error.localizedDescription)
        }
    }

    func save() {
        guard canSave else { return }
        joinSaveTask?.cancel()
        if canRunHomeJoinHandoff {
            startHomeJoinHandoff()
        } else {
            isSaving = true
            performSave(showsHomeJoinHandoff: false)
        }
    }

    var homeJoinHandoffStartDelayMilliseconds: UInt64 {
        reduceMotion ? 20 : 24
    }

    var homeJoinHandoffSaveDelayMilliseconds: UInt64 {
        reduceMotion ? 120 : 520
    }

    var homeJoinHandoffSettleDelayMilliseconds: UInt64 {
        reduceMotion ? 120 : 280
    }

    func startHomeJoinHandoff() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            joinHandoffSnapshot = snapshot
            isSaving = true
            isJoinHandoffRunning = true
            joinHandoffProgress = 0
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: homeJoinHandoffStartDelayMilliseconds) {
            guard isJoinHandoffRunning else { return }
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
                joinHandoffProgress = 1
            }
            joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: homeJoinHandoffSaveDelayMilliseconds) {
                performSave(showsHomeJoinHandoff: true)
            }
        }
    }

    func performSave(showsHomeJoinHandoff: Bool) {
        do {
            let result = try appServices.memberCreation.save(
                draft: draft,
                existingPets: existingPets,
                existingHumans: existingHumans,
                context: modelContext,
                countryCode: appCountry
            )
            if let pet = result.pet {
                FocusWalletAvatarCache.storeDecodedImage(
                    cardId: pet.id,
                    data: pet.avatarImageData,
                    image: decodedAvatar,
                    isTransparent: decodedAvatarTransparent
                )
            }
            if let human = result.human {
                FocusWalletAvatarCache.storeDecodedImage(
                    cardId: human.id,
                    data: human.avatarImageData,
                    image: decodedAvatar,
                    isTransparent: decodedAvatarTransparent
                )
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if showsHomeJoinHandoff {
                finishSaveAfterHomeJoinHandoff(pet: result.pet, human: result.human)
                return
            }
            withAnimation(GoMotion.sheet) {
                didShowSuccess = true
            }
            joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 780) {
                didShowSuccess = false
                isSaving = false
                clearMediaReturnStepStorage()
                joinSaveTask = OhanaFrameScheduler.runAfterNextFrame {
                    notifySavedMembers(pet: result.pet, human: result.human)
                    joinSaveTask = OhanaFrameScheduler.runAfterNextFrame {
                        onComplete()
                    }
                }
            }
        } catch MemberCreationError.duplicateName {
            handleSaveFailure(l.tr(zh: "这个名字已经被使用。", en: "This name is already in use.", de: "Dieser Name wird bereits verwendet."))
        } catch MemberCreationError.emptyName {
            handleSaveFailure(l.tr(zh: "请先输入名字。", en: "Enter a name first.", de: "Gib zuerst einen Namen ein."))
        } catch {
            handleSaveFailure(error.localizedDescription)
        }
    }

    func finishSaveAfterHomeJoinHandoff(pet: Pet?, human: Human?) {
        joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: homeJoinHandoffSettleDelayMilliseconds) {
            guard isJoinHandoffRunning else { return }
            clearMediaReturnStepStorage()
            joinSaveTask = OhanaFrameScheduler.runAfterNextFrame {
                notifySavedMembers(pet: pet, human: human)
                joinSaveTask = OhanaFrameScheduler.runAfterNextFrame {
                    onComplete()
                    joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 240) {
                        resetHomeJoinHandoffState()
                    }
                }
            }
        }
    }

    func notifySavedMembers(pet: Pet?, human: Human?) {
        if let pet {
            onPetSaved?(pet)
        }
        if let human {
            onHumanSaved?(human)
        }
    }

    func handleSaveFailure(_ message: String) {
        isSaving = false
        restoreHomeJoinHandoffAfterFailure()
        showInlineError(message)
    }

    func resetHomeJoinHandoffState() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isSaving = false
            isJoinHandoffRunning = false
            joinHandoffProgress = 0
            joinHandoffSnapshot = nil
        }
    }

    func restoreHomeJoinHandoffAfterFailure() {
        guard isJoinHandoffRunning else { return }
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.selection) {
            joinHandoffProgress = 0
        }
        joinSaveTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: reduceMotion ? 90 : 240) {
            resetHomeJoinHandoffState()
        }
    }

    func showInlineError(_ message: String) {
        errorMessage = message
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        showError = true
    }
}
