//
//  PlantDashboardView+Actions.swift
//  Ohana
//
//  Route, care-command, batch-care, and feedback actions for Plant Dashboard.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

extension PlantDashboardView {
    // MARK: - Actions

    func waterPlant(_ plant: Plant) {
        openCareLogSheet(for: plant, type: .watering)
    }

    func waterAll() {
        openBatchCareSheet(careType: .watering)
    }

    var preferredCareAggregateFeature: PlantCareFeatureDestination {
        if careWindowTasks.contains(where: { $0.careType == .watering || $0.careType == .misting }) {
            return .water
        }
        if careWindowTasks.contains(where: { $0.careType == .fertilizing }) {
            return .fertilize
        }
        if let next = careWindowTasks.first {
            return PlantCareFeatureDestination.categoryDestination(for: next.careType)
        }
        return .growth
    }

    func openCareAggregate(
        _ feature: PlantCareFeatureDestination? = nil,
        focusedCareType: PlantCareType? = nil
    ) {
        careAggregateDraft = PlantDashboardCareAggregateDraft(
            feature: feature ?? preferredCareAggregateFeature,
            focusedCareType: focusedCareType
        )
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func careAggregateFeature(for careType: PlantCareType) -> PlantCareFeatureDestination {
        PlantCareFeatureDestination.categoryDestination(for: careType)
    }

    func clearPlantSearchAndFilters() {
        searchText = ""
        searchFocused = false
        selectedFilter = .all
        selectedLocation = nil
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func completeTask(_ task: PlantCareTaskSnapshot) {
        guard let plant = plants.first(where: { $0.id == task.plantID }) else { return }
        openCareLogSheet(for: plant, type: task.careType)
    }

    func openCareLogSheet(for plant: Plant, type: PlantCareType) {
        careLogDraft = PlantDashboardCareLogDraft(plant: plant, careType: type)
    }

    func toggleExpandedPlantCard(_ plantID: UUID) {
        if expandedPlantCardID == plantID {
            collapsePlantWalletCard()
        } else if let snapshot = makePlantHeroSnapshot(for: plantID) {
            expandPlantWalletCard(snapshot)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func collapseExpandedPlantCard() {
        guard expandedPlantCardID != nil else { return }
        collapsePlantWalletCard()
    }

    func collapseExpandedPlantIfNeeded() {
        guard let expandedPlantCardID else { return }
        if !visiblePlants.contains(where: { $0.id == expandedPlantCardID }) {
            collapseExpandedPlantCard()
        }
    }

    func scheduleMediaAttachmentIndexRepair() {
        guard !plants.isEmpty else { return }
        mediaAttachmentIndexRepairTask?.cancel()
        mediaAttachmentIndexRepairTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 140)
            guard !Task.isCancelled else { return }
            _ = PlantMediaAttachmentIndexRepair.repair(
                plants: plants,
                modelContext: modelContext
            )
            mediaAttachmentIndexRepairTask = nil
        }
    }

    func openDashboardFilters() {
        selectedDashboardMode = .plants
        searchFocused = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func openDashboardCarePlan() {
        showingCarePlanSheet = true
    }

    func openBatchCareSheet(careType: PlantCareType? = nil, roomID: String? = nil) {
        guard !dueTasks.isEmpty else { return }
        batchCareInitialType = careType
        batchCareRoomFilter = roomID
        prepareBatchCareSheetSnapshot(careType: careType, roomID: roomID)

        if showingCarePlanSheet {
            showingCarePlanSheet = false
            Task { @MainActor in
                await OhanaFrameScheduler.waitAfterNextFrame()
                showingBatchCareSheet = true
            }
        } else {
            showingBatchCareSheet = true
        }
    }

    func prepareBatchCareSheetSnapshot(careType: PlantCareType?, roomID: String?) {
        batchCareSheetSnapshot = makeBatchCareSheetSnapshot(careType: careType, roomID: roomID)
        batchCareRouteSnapshotTask?.cancel()
        batchCareRouteSnapshotGeneration += 1
        let generation = batchCareRouteSnapshotGeneration
        let container = modelContext.container
        let input = PlantBatchCareRouteSnapshotInput(
            careType: careType,
            roomID: roomID,
            now: Date(),
            days: 7,
            unassignedIndoorTitle: l.tr(zh: "未设置室内位置", en: "Unassigned indoor", de: "Innen ohne Ort"),
            unassignedOutdoorTitle: l.tr(zh: "未设置户外位置", en: "Unassigned outdoor", de: "Außen ohne Ort")
        )
        batchCareRouteSnapshotTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }
            let actor = PlantBatchCareRouteSnapshotActor(modelContainer: container)
            do {
                let snapshot = try await actor.load(input: input)
                guard !Task.isCancelled, generation == batchCareRouteSnapshotGeneration else { return }
                batchCareSheetSnapshot = snapshot
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning("Plant batch-care route snapshot load failed: \(error.localizedDescription)", category: "Plants")
            }
            guard generation == batchCareRouteSnapshotGeneration else { return }
            batchCareRouteSnapshotTask = nil
        }
    }

    func openInitialBatchCareSheetIfNeeded() {
        guard opensBatchCareOnAppear, !didOpenInitialBatchCareSheet else { return }
        didOpenInitialBatchCareSheet = true
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            openBatchCareSheet(careType: initialBatchCareType)
        }
    }

    func openBatchQuickRecordSheet() {
        guard !plants.isEmpty else { return }
        showingBatchQuickRecordSheet = true
    }

    func openInitialBatchQuickRecordSheetIfNeeded() {
        guard opensBatchQuickRecordOnAppear, !didOpenInitialBatchQuickRecordSheet else { return }
        didOpenInitialBatchQuickRecordSheet = true
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            openBatchQuickRecordSheet()
        }
    }

    func openDashboardProfileQueue() {
        selectedDashboardMode = .plants
        selectedFilter = .all
        selectedLocation = nil
        searchFocused = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func openDashboardPhotos() {
        selectedDashboardMode = .photos
        searchFocused = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func showPlants(for summary: PlantDashboardRoomSummary) {
        selectedSiteSummary = nil
        selectedLocation = summary.id
        selectedDashboardMode = .plants
        searchFocused = false
    }

    func openPlantFromSite(_ plantID: UUID) {
        selectedSiteSummary = nil
        onOpenPlant(plantID)
    }

    func openCareLogFromSite(plant: Plant, type: PlantCareType) {
        selectedSiteSummary = nil
        openCareLogSheet(for: plant, type: type)
    }

    func openPlantFromPhoto(_ plantID: UUID) {
        selectedDashboardPhoto = nil
        onOpenPlant(plantID)
    }

    func openPlantFromCarePlan(_ plantID: UUID) {
        showingCarePlanSheet = false
        onOpenPlant(plantID)
    }

    func openCareLogFromCarePlan(plant: Plant, type: PlantCareType) {
        showingCarePlanSheet = false
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            openCareLogSheet(for: plant, type: type)
        }
    }

    func openCareLogFromBatchCare(plantID: UUID, type: PlantCareType) {
        showingBatchCareSheet = false
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard let plant = plants.first(where: { $0.id == plantID }) else { return }
            openCareLogSheet(for: plant, type: type)
        }
    }

    func savePlantCareLog(
        for plant: Plant,
        type: PlantCareType,
        careNote: String,
        photoData: Data?,
        healthStatus: PlantHealthStatus,
        executorID: UUID?
    ) {
        recordPlantCare(
            type,
            plant: plant,
            executorId: executorID?.uuidString,
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus
        )
    }

    func recordPlantCare(
        _ type: PlantCareType,
        plant: Plant,
        executorId: String?,
        careNote: String = "",
        photoData: Data? = nil,
        healthStatus: PlantHealthStatus? = nil
    ) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(.plantCare(plantID: plant.id, action: type.rawValue)) {
            commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: executorId,
                careNote: careNote,
                photoData: photoData,
                healthStatus: healthStatus
            )
        }
    }

    func completeDueTasks() {
        openBatchCareSheet()
    }

    func completeBatchCare(_ selections: [PlantBatchCareSelection], executorID: UUID?) {
        guard !selections.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let executorId = executorID?.uuidString
        let retryCareType = batchCareInitialType
        let retryRoomID = batchCareRoomFilter
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            let result = commandExecutor.completePlantBatchCare(
                selections: selections,
                executorId: executorId
            )
            guard result.didPersist else {
                showBatchCarePersistenceFailure(result.persistenceErrorDescription)
                return
            }
            if !result.didWrite, !result.skipped.isEmpty {
                showBatchCareSelectionChanged()
                await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 220)
                openBatchCareSheet(careType: retryCareType, roomID: retryRoomID)
                return
            }
            guard let token = result.undoToken else { return }
            PlantBatchCarePendingRewardStore.upsert(token)
            publishPendingBatchCareRewardStoreChanged(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
            pendingBatchCareUndoToken = token
            publishBatchCareVisualReward(result, actorId: token.executorId)
            scheduleBatchCareRewardCommit(for: token)
        }
    }

    func recordBatchQuickCare(_ selections: [PlantBatchCareSelection], executorID: UUID?) async -> Bool {
        guard !selections.isEmpty else { return false }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let executorId = executorID?.uuidString
        await OhanaFrameScheduler.waitAfterNextFrame()
        let result = commandExecutor.recordPlantBatchQuickCare(
            selections: selections,
            executorId: executorId
        )
        guard result.didPersist else {
            showBatchCarePersistenceFailure(result.persistenceErrorDescription)
            return false
        }
        guard result.skipped.isEmpty else {
            showBatchCareSelectionChanged()
            return false
        }
        guard result.didWrite else { return true }
        guard let token = result.undoToken else { return false }
        PlantBatchCarePendingRewardStore.upsert(token)
        publishPendingBatchCareRewardStoreChanged(batchID: token.batchID, action: "batchQuickRecordPendingRewardsChanged")
        pendingBatchCareUndoToken = token
        publishBatchCareVisualReward(result, actorId: token.executorId)
        scheduleBatchCareRewardCommit(for: token)
        return true
    }

    func undoPendingBatchCare() {
        guard let token = pendingBatchCareUndoToken else { return }
        pendingBatchCareRewardTask?.cancel()
        pendingBatchCareRewardTask = nil
        pendingBatchCareUndoToken = nil
        let result = commandExecutor.undoPlantBatchCare(token)
        guard result.didPersist else {
            PlantBatchCarePendingRewardStore.upsert(token)
            publishPendingBatchCareRewardStoreChanged(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
            pendingBatchCareUndoToken = token
            showBatchCarePersistenceFailure(result.persistenceErrorDescription)
            scheduleBatchCareRewardCommit(for: token)
            return
        }
        PlantBatchCarePendingRewardStore.remove(batchID: token.batchID)
        publishPendingBatchCareRewardStoreChanged(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func scheduleBatchCareRewardCommit(for token: PlantBatchCareUndoToken) {
        pendingBatchCareRewardTask?.cancel()
        pendingBatchCareRewardTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled,
                  pendingBatchCareUndoToken?.id == token.id else { return }
            pendingBatchCareUndoToken = nil
            let result = commandExecutor.commitPlantBatchCareRewards(for: token)
            guard result.didPersist else {
                PlantBatchCarePendingRewardStore.upsert(token)
                publishPendingBatchCareRewardStoreChanged(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
                showBatchCarePersistenceFailure(result.persistenceErrorDescription)
                pendingBatchCareRewardTask = nil
                return
            }
            PlantBatchCarePendingRewardStore.remove(batchID: token.batchID)
            publishPendingBatchCareRewardStoreChanged(batchID: token.batchID, action: "batchCarePendingRewardsChanged")
            if result.didCommit {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            pendingBatchCareRewardTask = nil
        }
    }

    func publishBatchCareVisualReward(_ result: PlantBatchCareCommandResult, actorId: String?) {
        guard result.estimatedCoconutDelta > 0 else { return }
        appServices.domainRevisions.publishCoconutRewardFeedback(
            OhanaCoconutRewardEvent(
                id: result.batchID,
                amount: result.estimatedCoconutDelta,
                growthXP: 0,
                emoji: "🥥",
                title: l.tr(zh: "批量照护", en: "Batch care", de: "Sammelpflege"),
                actorId: actorId,
                date: Date()
            )
        )
    }

    func publishPendingBatchCareRewardStoreChanged(batchID: UUID, action: String) {
        appServices.domainRevisions.publishPlantBatchCarePendingRewardsChanged(
            batchID: batchID,
            action: action,
            pendingCount: PlantBatchCarePendingRewardStore.load().count,
            note: "plant.batchCare.pendingRewardsChanged"
        )
    }

    func deferTaskFromBatchCare(_ task: PlantBatchCareSheetTask) {
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            if let source = dueTasks.first(where: { $0.id == task.id }) {
                deferTaskOneDay(source)
            }
        }
    }

    func skipTaskFromBatchCare(_ task: PlantBatchCareSheetTask) {
        Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            if let source = dueTasks.first(where: { $0.id == task.id }) {
                skipTask(source)
            }
        }
    }

    func deferDueTasksOneDay() {
        let duePlantIDs = Set(dueTasks.map(\.plantID))
        let duePlants = plants.filter { duePlantIDs.contains($0.id) }
        guard !duePlants.isEmpty else { return }

        commandQueue.enqueue(
            .command(
                "plants",
                "deferDueTasksOneDay",
                ["plantCount": String(duePlants.count)]
            )
        ) {
            commandExecutor.deferPlantDueTasksOneDay(
                plants: duePlants,
                executorId: currentExecutorId()
            )
        }
    }

    func deferTaskOneDay(_ task: PlantCareTaskSnapshot) {
        guard let plant = plants.first(where: { $0.id == task.plantID }) else { return }
        let formatter = ISO8601DateFormatter()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        recordPlantCare(
            .customNote,
            plant: plant,
            executorId: currentExecutorId(),
            careNote: "defer:\(task.careType.rawValue):\(formatter.string(from: tomorrow))"
        )
    }

    func skipTask(_ task: PlantCareTaskSnapshot) {
        guard let plant = plants.first(where: { $0.id == task.plantID }) else { return }
        let formatter = ISO8601DateFormatter()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        recordPlantCare(
            .customNote,
            plant: plant,
            executorId: currentExecutorId(),
            careNote: "skip:\(task.careType.rawValue):\(formatter.string(from: tomorrow))"
        )
    }

    func currentExecutorId() -> String? {
        activeHumanIdRaw.isEmpty ? nil : activeHumanIdRaw
    }
}
