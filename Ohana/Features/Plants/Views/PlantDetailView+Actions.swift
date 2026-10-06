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
            showingBasicInfo = true
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
        let human = PlantActionHumanSelectionResolver.resolve(
            context: modelContext,
            currentLocalHumanIDRaw: activeHumanIdRaw
        )
        if !human.needsConfirmation {
            recordQuickCare(careType, executorID: human.defaultHumanID)
            return
        }
        quickCareExecutorID = nil
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

    func savePlantCareLog(
        _ type: PlantCareType,
        careNote: String,
        healthStatus: PlantHealthStatus,
        photoData: Data?,
        executorID: UUID?,
        completion: @escaping (Bool) -> Void
    ) {
        recordCare(
            type,
            executorId: executorID?.uuidString,
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus,
            completion: completion
        )
    }

    func recordQuickCare(_ type: PlantCareType, executorID: UUID?) {
        guard !pendingDetailQuickCareTypes.contains(type) else { return }
        guard !(pendingBatchCareUndoToken?.items.contains { $0.plantID == plant.id && $0.careType == type } ?? false) else { return }
        quickCareConfirmDraft = nil
        withAnimation(GoMotion.feedback) {
            pendingDetailQuickCareTypes.insert(type)
            completedDetailQuickCareTypes.remove(type)
            failedDetailQuickCareTypes.remove(type)
        }

        let plantID = plant.id
        let selection = PlantBatchCareSelection(plantID: plantID, careType: type)
        let operationID = quickCareOperationIDs[type] ?? UUID()
        quickCareOperationIDs[type] = operationID
        commandQueue.enqueue(.plantCare(plantID: plantID, action: type.rawValue)) {
            let result = commandExecutor.recordPlantBatchQuickCare(
                selections: [selection],
                executorId: executorID?.uuidString,
                operationID: operationID
            )
            let didCommit = handleBatchQuickCareResult(result, selections: [selection])
            guard didCommit else {
                withAnimation(GoMotion.feedback) {
                    pendingDetailQuickCareTypes.remove(type)
                    failedDetailQuickCareTypes.insert(type)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            quickCareOperationIDs[type] = nil
            withAnimation(GoMotion.feedback) {
                pendingDetailQuickCareTypes.remove(type)
                completedDetailQuickCareTypes.insert(type)
            }
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
        }
    }

    func deferCare(_ type: PlantCareType, byDays days: Int) {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)
        deferCare(type, until: date, wetSoil: days == 1 && type == .watering && !plant.isHydroponic)
    }

    func deferCare(_ type: PlantCareType, until date: Date, wetSoil: Bool = false) {
        OhanaFeedback.light()
        let result = commandExecutor.deferPlantCare(
            plant: plant,
            careType: type,
            until: date,
            wetSoil: wetSoil,
            executorId: activeHumanIdRaw
        )
        guard result.didPersist else {
            careActionFailureText = result.persistenceErrorDescription ?? l.tr(
                zh: "没有修改检查时间，请重试。",
                en: "The check date was not changed. Please try again.",
                de: "Der Prüftermin wurde nicht geändert. Bitte erneut versuchen."
            )
            showingCareActionFailure = true
            return
        }
        if result.didChange {
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 0)
        }
    }

    func enableWateringCheckReminder() {
        OhanaFeedback.light()
        let result = commandExecutor.enablePlantWateringCheck(plant: plant, intervalDays: draftWateringCheckDays)
        guard result.didPersist else {
            careActionFailureText = result.persistenceErrorDescription ?? l.tr(
                zh: "提醒设置未保存，请重试。",
                en: "Reminder settings were not saved. Please try again.",
                de: "Erinnerung konnte nicht gespeichert werden. Bitte erneut versuchen."
            )
            showingCareActionFailure = true
            return
        }
        showingWaterReminderOptIn = false
        Task {
            if await appServices.userNotifications.authorizationStatus() == .notDetermined {
                _ = await appServices.userNotifications.requestPermission()
            }
            notificationAuthorizationStatus = await appServices.userNotifications.authorizationStatus()
        }
        schedulePlantDetailRenderDataRebuild(delayMilliseconds: 0)
    }

    func openBatchQuickRecordFromDetail(careType: PlantCareType) {
        batchQuickRecordInitialExecutorID = quickCareExecutorID
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

    func recordBatchQuickCareFromDetail(
        _ selections: [PlantBatchCareSelection],
        executorID: UUID?
    ) async -> Bool {
        guard !selections.isEmpty else { return false }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let executorId = executorID?.uuidString
        let operationID = UUID()
        await OhanaFrameScheduler.waitAfterNextFrame()
        let result = commandExecutor.recordPlantBatchQuickCare(
            selections: selections,
            executorId: executorId,
            operationID: operationID
        )
        return handleBatchQuickCareResult(result, selections: selections)
    }

    func handleBatchQuickCareResult(
        _ result: PlantBatchCareCommandResult,
        selections: [PlantBatchCareSelection]
    ) -> Bool {
        guard result.didPersist else {
            presentQuickOrBatchCareFailure(result.persistenceErrorDescription, selectionCount: selections.count)
            return false
        }
        guard result.skipped.isEmpty else {
            let detail = selections.count == 1
                ? l.tr(zh: "植物状态已变化，未记录这次护理。请刷新后重试。", en: "Plant status changed. Care was not logged; refresh and try again.", de: "Der Pflanzenstatus hat sich geändert. Bitte aktualisieren und erneut versuchen.")
                : l.tr(zh: "植物状态已变化，整批未写入。请刷新后重新选择。", en: "Plant status changed, so nothing was written. Refresh and select again.", de: "Der Pflanzenstatus hat sich geändert. Es wurde nichts gespeichert; bitte neu auswählen.")
            presentQuickOrBatchCareFailure(detail, selectionCount: selections.count)
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

    func presentQuickOrBatchCareFailure(_ detail: String?, selectionCount: Int) {
        if selectionCount == 1 {
            careActionFailureText = detail ?? l.tr(zh: "没有记录这次护理，请重试。", en: "Care was not logged. Please try again.", de: "Pflege wurde nicht erfasst. Bitte erneut versuchen.")
            showingCareActionFailure = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            presentBatchCareFailure(detail)
        }
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
        executorId: String?,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        let plantID = plant.id
        commandQueue.enqueue(.plantCare(plantID: plantID, action: type.rawValue)) {
            let result = commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: executorId,
                careNote: careNote,
                photoData: photoData,
                healthStatus: healthStatus
            )
            if result.didPersist {
                schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            completion?(result.didPersist)
        }
    }

    func deferTaskOneDay(_ task: PlantCareTaskSnapshot, reason: String? = nil) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        deferCare(task.careType, until: tomorrow, wetSoil: reason == "soilWet")
    }

    func skipTask(_ task: PlantCareTaskSnapshot, reason: String? = nil) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        OhanaFeedback.light()
        let result = commandExecutor.deferPlantCare(plant: plant, careType: task.careType, until: tomorrow, skip: true, executorId: currentExecutorId())
        if result.didPersist {
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 0)
        } else {
            careActionFailureText = result.persistenceErrorDescription ?? l.tr(zh: "没有修改检查时间，请重试。", en: "The check date was not changed. Please try again.", de: "Der Prüftermin wurde nicht geändert. Bitte erneut versuchen.")
            showingCareActionFailure = true
        }
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
            if let denial = result.personalDenial {
                personalUpgradePrompt = PersonalUpgradePrompt(denial: denial)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
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
