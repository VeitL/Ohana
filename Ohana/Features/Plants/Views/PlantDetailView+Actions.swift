//
//  PlantDetailView+Actions.swift
//  Ohana
//
//  Thin UI actions for Plant detail routing and care logging.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

struct PlantDetailCareFeatureDraft: Identifiable, Hashable {
    let feature: PlantCareFeatureDestination
    let focusedCareType: PlantCareType?

    var id: String {
        [feature.rawValue, focusedCareType?.rawValue].compactMap(\.self).joined(separator: "-")
    }
}

extension PlantDetailContentView {
    // MARK: - Actions

    func queuePlantFeatureHubDestination(_ destination: PlantFeatureDestination) {
        showingAllFeaturesHub = false
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
            openPlantFeatureDestination(destination)
        }
    }

    func scheduleInitialPlantFeatureDestinationIfNeeded() {
        guard initialFeatureDestination != nil, !didOpenInitialFeatureDestination else { return }
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 180)
            openInitialPlantFeatureDestinationIfReady()
        }
    }

    func openInitialPlantFeatureDestinationIfReady() {
        guard let destination = initialFeatureDestination,
              !didOpenInitialFeatureDestination else { return }
        guard !initialDestinationNeedsRenderData(destination) || isRenderDataReady else { return }
        didOpenInitialFeatureDestination = true
        openPlantFeatureDestination(destination)
    }

    private func initialDestinationNeedsRenderData(_ destination: PlantFeatureDestination) -> Bool {
        switch destination {
        case .water, .fertilize, .maintenance, .health, .growth, .pestCheck, .leafCleaning, .profile, .reminders:
            false
        case .carePlan, .healthReview, .photos, .timeline, .catalog, .safety:
            true
        }
    }

    func waterPlant() {
        presentQuickCareConfirm(for: .watering)
    }

    func fertilizePlant() {
        presentQuickCareConfirm(for: .fertilizing)
    }

    func openPlantFeatureDestination(_ destination: PlantFeatureDestination) {
        if let careFeatureDestination = destination.careFeatureDestination {
            openPlantCareFeatureDetail(careFeatureDestination)
            return
        }

        switch destination {
        case .water, .fertilize, .maintenance, .health, .growth:
            return
        case .pestCheck:
            openPlantCareFeatureDetail(for: .pestCheck)
        case .leafCleaning:
            openPlantCareFeatureDetail(for: .leafCleaning)
        case .profile:
            showingEditSheet = true
        case .photos:
            if galleryPhotoItems.isEmpty {
                openCareLogSheet(.photo)
            } else {
                showingPhotoGallery = true
            }
        case .carePlan:
            revealPlantDetailExtrasAndScroll(to: .carePlan)
        case .reminders:
            openReminderSettings()
        case .healthReview:
            revealPlantDetailExtrasAndScroll(to: .healthReview)
        case .timeline:
            revealPlantDetailExtrasAndScroll(to: .timeline)
        case .catalog:
            revealPlantDetailExtrasAndScroll(to: .knowledge)
        case .safety:
            if activeSafetyWarningCount > 0 {
                revealPlantDetailExtrasAndScroll(to: .safety)
            } else {
                showingEditSheet = true
            }
        }
    }

    func openPlantCareFeatureDetail(
        _ feature: PlantCareFeatureDestination,
        focusedCareType: PlantCareType? = nil
    ) {
        showingAllFeaturesHub = false
        careFeatureDraft = PlantDetailCareFeatureDraft(feature: feature, focusedCareType: focusedCareType)
    }

    func openPlantCareFeatureDetail(for careType: PlantCareType) {
        openPlantCareFeatureDetail(
            PlantCareFeatureDestination.categoryDestination(for: careType),
            focusedCareType: careType
        )
    }

    func revealPlantDetailExtrasAndScroll(to anchor: PlantDetailFeatureAnchor) {
        if !showingPlantDetailExtras {
            withAnimation(GoMotion.quick) {
                showingPlantDetailExtras = true
            }
        }
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            pendingFeatureScrollTarget = anchor
        }
    }

    func openReminderSettings() {
        showingAllFeaturesHub = false
        showingEditSheet = true
    }

    func openPlantPhotos() {
        showingAllFeaturesHub = false
        if galleryPhotoItems.isEmpty {
            openCareLogSheet(.photo)
        } else {
            showingPhotoGallery = true
        }
    }

    func openCareLogSheet(_ type: PlantCareType) {
        careLogDraftType = type
    }

    func presentQuickCareConfirm(for task: PlantCareTaskSnapshot) {
        presentQuickCareConfirm(
            for: task.careType,
            detail: "\(dueText(for: task)) · \(task.subtitle)"
        )
    }

    func presentQuickCareConfirm(for careType: PlantCareType, detail: String? = nil) {
        quickCareConfirmDraft = PlantQuickCareConfirmDraft(
            careType: careType,
            title: careType.displayName(l: l),
            detail: detail ?? quickCareConfirmDetail(for: careType)
        )
        OhanaFeedback.light()
    }

    func quickCareConfirmDetail(for careType: PlantCareType) -> String {
        if pendingDetailQuickCareTypes.contains(careType) {
            return l.tr(zh: "正在记录，稍等一下。", en: "Logging now. One moment.", de: "Wird erfasst. Einen Moment.")
        }
        if completedDetailQuickCareTypes.contains(careType) {
            return l.tr(zh: "刚刚已记录。", en: "Just logged.", de: "Gerade erfasst.")
        }
        if failedDetailQuickCareTypes.contains(careType) {
            return l.tr(zh: "上次记录失败，可以重试。", en: "Last attempt failed. You can retry.", de: "Letzter Versuch fehlgeschlagen. Du kannst es erneut versuchen.")
        }
        return l.tr(
            zh: "快速记录只保存这次护理；照片、备注和细节去详情里补。",
            en: "Quick log saves this care only; add photos, notes, and details from the detail page.",
            de: "Schnell erfassen speichert nur diese Pflege; Fotos, Notizen und Details gibt es auf der Detailseite."
        )
    }

    func savePlantCareLog(_ type: PlantCareType, careNote: String, healthStatus: PlantHealthStatus, photoData: Data?) {
        recordCare(type, careNote: careNote, photoData: photoData, healthStatus: healthStatus)
    }

    func recordQuickCare(_ type: PlantCareType) {
        guard !pendingDetailQuickCareTypes.contains(type) else { return }
        quickCareConfirmDraft = nil
        withAnimation(GoMotion.feedback) {
            pendingDetailQuickCareTypes.insert(type)
            completedDetailQuickCareTypes.remove(type)
            failedDetailQuickCareTypes.remove(type)
        }

        let plantID = plant.id
        commandQueue.enqueue(.plantCare(plantID: plantID, action: type.rawValue)) {
            let result = commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: currentExecutorId()
            )
            guard result.didPersist else {
                withAnimation(GoMotion.feedback) {
                    pendingDetailQuickCareTypes.remove(type)
                    failedDetailQuickCareTypes.insert(type)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            withAnimation(GoMotion.feedback) {
                pendingDetailQuickCareTypes.remove(type)
                completedDetailQuickCareTypes.insert(type)
            }
            showQuickCareToast(type: type, result: result)
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
        }
    }

    func openBatchQuickRecordFromDetail(careType: PlantCareType) {
        quickCareConfirmDraft = nil
        batchQuickRecordCareType = careType
        UISelectionFeedbackGenerator().selectionChanged()
        reloadBatchQuickRecordTargetsAndPresent()
    }

    func reloadBatchQuickRecordTargetsAndPresent() {
        showingBatchQuickRecordSheet = false
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            do {
                batchQuickRecordTargets = try await batchQuickRecordTargetLoader()
                showingBatchQuickRecordSheet = true
            } catch {
                OhanaLog.warning("Plant detail batch target load failed: \(error.localizedDescription)", category: "Plants")
                presentBatchCareFailure(nil)
            }
        }
    }

    func batchQuickRecordImageData(for modelID: PersistentIdentifier) async -> Data? {
        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        return await loader.plantAvatarImageData(modelID: modelID)
    }

    func recordBatchQuickCareFromDetail(_ selections: [PlantBatchCareSelection]) async -> Bool {
        guard !selections.isEmpty else { return false }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let executorId = currentExecutorId()
        await OhanaFrameScheduler.waitAfterNextFrame()
        let result = commandExecutor.recordPlantBatchQuickCare(
            selections: selections,
            executorId: executorId
        )
        return handleBatchQuickCareResult(result, selections: selections)
    }

    func handleBatchQuickCareResult(
        _ result: PlantBatchCareCommandResult,
        selections: [PlantBatchCareSelection]
    ) -> Bool {
        guard result.didPersist else {
            presentBatchCareFailure(result.persistenceErrorDescription)
            return false
        }
        guard result.skipped.isEmpty else {
            presentBatchCareFailure(l.tr(
                zh: "植物状态已变化，整批未写入。请刷新后重新选择。",
                en: "Plant status changed, so nothing was written. Refresh and select again.",
                de: "Der Pflanzenstatus hat sich geändert. Es wurde nichts gespeichert; bitte neu auswählen."
            ))
            return false
        }
        guard result.didWrite else { return true }
        guard let token = result.undoToken else { return false }
        PlantBatchCarePendingRewardStore.upsert(token)
        publishDetailBatchPendingRewardChange(batchID: token.batchID, action: "batchQuickRecordPendingRewardsChanged")
        pendingBatchCareUndoToken = token
        scheduleDetailBatchCareRewardCommit(for: token)
        showDetailBatchCareSuccess(result, selections: selections)
        return true
    }

    func undoPendingBatchCareFromDetail() {
        guard let token = pendingBatchCareUndoToken else { return }
        pendingBatchCareRewardTask?.cancel()
        pendingBatchCareRewardTask = nil
        pendingBatchCareUndoToken = nil
        let result = commandExecutor.undoPlantBatchCare(token)
        guard result.didPersist else {
            pendingBatchCareUndoToken = token
            PlantBatchCarePendingRewardStore.upsert(token)
            publishDetailBatchPendingRewardChange(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
            presentBatchCareFailure(result.persistenceErrorDescription)
            scheduleDetailBatchCareRewardCommit(for: token)
            return
        }
        PlantBatchCarePendingRewardStore.remove(batchID: token.batchID)
        publishDetailBatchPendingRewardChange(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
    }

    func scheduleDetailBatchCareRewardCommit(for token: PlantBatchCareUndoToken) {
        pendingBatchCareRewardTask?.cancel()
        pendingBatchCareRewardTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled, pendingBatchCareUndoToken?.id == token.id else { return }
            pendingBatchCareUndoToken = nil
            let result = commandExecutor.commitPlantBatchCareRewards(for: token)
            if result.didPersist {
                PlantBatchCarePendingRewardStore.remove(batchID: token.batchID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            publishDetailBatchPendingRewardChange(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
            pendingBatchCareRewardTask = nil
        }
    }

    func publishDetailBatchPendingRewardChange(batchID: UUID, action: String) {
        appServices.domainRevisions.publishPlantBatchCarePendingRewardsChanged(
            batchID: batchID,
            action: action,
            pendingCount: PlantBatchCarePendingRewardStore.load().count,
            note: "plant.detail.batchCare.pendingRewardsChanged"
        )
    }

    func showDetailBatchCareSuccess(
        _ result: PlantBatchCareCommandResult,
        selections: [PlantBatchCareSelection]
    ) {
        let careType = selections.first?.careType ?? .watering
        quickCareToastClearTask?.cancel()
        quickCareToast = PlantQuickCareToast(
            careType: careType,
            message: l.tr(
                zh: "已为 \(result.completedCount) 株植物记录",
                en: "Logged care for \(result.completedCount) plants",
                de: "Pflege für \(result.completedCount) Pflanzen erfasst"
            )
        )
        quickCareToastClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1800) {
            withAnimation(GoMotion.selection) {
                quickCareToast = nil
            }
            quickCareToastClearTask = nil
        }
        schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
    }

    func presentBatchCareFailure(_ detail: String?) {
        batchCareFailureDetail = detail ?? l.tr(
            zh: "没有写入任何护理记录，请重新选择后再试。",
            en: "No care records were written. Select the plants and try again.",
            de: "Es wurden keine Pflegeeinträge gespeichert. Bitte neu auswählen."
        )
        showingBatchCareFailure = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func showQuickCareToast(type: PlantCareType, result: PlantCareCommandResult) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        quickCareToastClearTask?.cancel()
        quickCareToast = PlantQuickCareToast(
            careType: type,
            message: result.coconutDelta > 0
                ? l.tr(zh: "已记录\(type.displayName(l: l)) · +\(result.coconutDelta)🥥", en: "\(type.displayName(l: l)) logged · +\(result.coconutDelta)🥥", de: "\(type.displayName(l: l)) erfasst · +\(result.coconutDelta)🥥")
                : l.tr(zh: "已记录\(type.displayName(l: l))", en: "\(type.displayName(l: l)) logged", de: "\(type.displayName(l: l)) erfasst")
        )
        quickCareToastClearTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 1800) {
            withAnimation(GoMotion.selection) {
                completedDetailQuickCareTypes.remove(type)
                quickCareToast = nil
            }
            quickCareToastClearTask = nil
        }
    }

    func recordCare(
        _ type: PlantCareType,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        let plantID = plant.id
        commandQueue.enqueue(.plantCare(plantID: plantID, action: type.rawValue)) {
            let result = commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: currentExecutorId(),
                careNote: careNote,
                photoData: photoData,
                healthStatus: healthStatus
            )
            if result.didPersist {
                schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    func deferTaskOneDay(_ task: PlantCareTaskSnapshot, reason: String? = nil) {
        let formatter = ISO8601DateFormatter()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        let reasonSuffix = reason.map { "|\($0)" } ?? ""
        recordCare(.customNote, careNote: "defer:\(task.careType.rawValue):\(formatter.string(from: tomorrow))\(reasonSuffix)")
    }

    func skipTask(_ task: PlantCareTaskSnapshot, reason: String? = nil) {
        let formatter = ISO8601DateFormatter()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        let reasonSuffix = reason.map { "|\($0)" } ?? ""
        recordCare(.customNote, careNote: "skip:\(task.careType.rawValue):\(formatter.string(from: tomorrow))\(reasonSuffix)")
    }

    func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }

    func stagePlantDelete() {
        guard !isDeletePending, !isDeleteCommitting else { return }
        isDeletePending = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        deleteUndoTask?.cancel()
        deleteUndoTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                commitPendingDelete()
            }
        }
    }

    func cancelPendingDelete() {
        guard !isDeleteCommitting else { return }
        deleteUndoTask?.cancel()
        deleteUndoTask = nil
        isDeletePending = false
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func commitPendingDelete() {
        guard isDeletePending, !isDeleteCommitting else { return }
        deleteUndoTask?.cancel()
        deleteUndoTask = nil
        isDeletePending = false
        deletePlant()
    }

    func archivePlant() {
        let command = DomainCommand.memberLifecycle(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            action: "archive.mark"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).archivePlant(
                plant,
                date: Date(),
                note: "plant.detail.archive"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    func restorePlant() {
        let command = DomainCommand.memberLifecycle(
            entityID: plant.id,
            kind: EntityKind.plant.rawValue,
            action: "archive.restore"
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).restorePlant(
                plant,
                note: "plant.detail.restore"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }

    func deletePlant() {
        guard !isDeleteCommitting else { return }
        isDeleteCommitting = true
        let targetPlant = plant
        let command = DomainCommand.memberDeletion(entityID: plant.id, kind: EntityKind.plant.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            let result = MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
                targetPlant,
                note: "plant.detail.delete"
            )
            UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        }
    }
}
