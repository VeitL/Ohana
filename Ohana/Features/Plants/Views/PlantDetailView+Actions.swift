//
//  PlantDetailView+Actions.swift
//  Ohana
//
//  Thin UI actions for Plant detail routing and care logging.
//

import Foundation
import SwiftUI
import UIKit

struct PlantDetailCareFeatureDraft: Identifiable, Hashable {
    let feature: PlantCareFeatureDestination

    var id: String { feature.rawValue }
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
        case .water, .fertilize, .pestCheck, .leafCleaning, .profile, .reminders:
            false
        case .carePlan, .healthReview, .photos, .timeline, .catalog, .safety:
            true
        }
    }

    func waterPlant() {
        openCareLogSheet(.watering)
    }

    func fertilizePlant() {
        openCareLogSheet(.fertilizing)
    }

    func performActionQueueItem(_ item: PlantDetailActionItem) {
        if item.opensEdit {
            showingEditSheet = true
            return
        }
        if let task = item.task {
            openCareLogSheet(task.careType)
            return
        }
        if let careType = item.careType {
            openCareLogSheet(careType)
        }
    }

    func careActionButton(type: PlantCareType, icon: String, color: Color) -> some View {
        Button {
            openCareLogSheet(type)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).accessibilityHidden(true)
                Text(type.displayName(l: l))
            }
            .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.45), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .strokeBorder(Color.ohanaCardSurface.opacity(0.24), lineWidth: 1)
            }
        }
        .accessibilityIdentifier("plant-detail-care-action-\(type.rawValue)")
    }

    func openPlantFeatureDestination(_ destination: PlantFeatureDestination) {
        if let careFeatureDestination = destination.careFeatureDestination {
            openPlantCareFeatureDetail(careFeatureDestination)
            return
        }

        switch destination {
        case .water, .fertilize:
            return
        case .pestCheck:
            openCareLogSheet(.pestCheck)
        case .leafCleaning:
            openCareLogSheet(.leafCleaning)
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

    func openPlantCareFeatureDetail(_ feature: PlantCareFeatureDestination) {
        showingAllFeaturesHub = false
        careFeatureDraft = PlantDetailCareFeatureDraft(feature: feature)
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

    func savePlantCareLog(_ type: PlantCareType, careNote: String, healthStatus: PlantHealthStatus, photoData: Data?) {
        recordCare(type, careNote: careNote, photoData: photoData, healthStatus: healthStatus)
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
            commandExecutor.recordPlantCare(
                type,
                plant: plant,
                executorId: currentExecutorId(),
                careNote: careNote,
                photoData: photoData,
                healthStatus: healthStatus
            )
            schedulePlantDetailRenderDataRebuild(delayMilliseconds: 24)
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

    func deletePlant() {
        guard !isDeleteCommitting else { return }
        isDeleteCommitting = true
        let targetPlant = plant
        let command = DomainCommand.memberDeletion(entityID: plant.id, kind: EntityKind.plant.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
        commandQueue.enqueue(command, delayMilliseconds: DeferredDomainCommandQueue.destructiveRouteDismissDelayMilliseconds) {
            MemberCommandExecutor(context: modelContext, services: appServices).deletePlant(
                targetPlant,
                note: "plant.detail.delete"
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
