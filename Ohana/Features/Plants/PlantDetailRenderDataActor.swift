//
//  PlantDetailRenderDataActor.swift
//  Ohana
//
//  Created by Codex on 04.07.26.
//

import Foundation
import SwiftData

enum PlantDetailRenderDataBuildError: Error {
    case missingPlant
}

@ModelActor
actor PlantDetailRenderDataActor {
    func build(request: PlantDetailRenderDataRequest) throws -> PlantDetailRenderData {
        try Task.checkCancellation()
        guard let plant = modelContext.model(for: request.plantModelID) as? Plant else {
            throw PlantDetailRenderDataBuildError.missingPlant
        }

        let logs = plant.careLogs
            .sorted { $0.date > $1.date }
            .map { PlantDetailLogSnapshot(log: $0) }
        try Task.checkCancellation()

        let tasks = PlantCarePlanService.tasks(
            for: plant,
            now: request.now,
            calendar: .current
        )
        let photos = Self.galleryPhotoItems(
            for: plant,
            logs: logs,
            languageCode: request.languageCode
        )
        let taskSummary = Self.taskSummary(
            for: plant,
            tasks: tasks
        )
        let logSummary = Self.logSummary(
            logs: logs,
            now: request.now
        )
        let logPhotoCount = photos.count {
            if case .careLog = $0.source { return true }
            return false
        }
        let diaryMarkdown = PlantDetailGrowthDiaryMarkdownBuilder.markdown(
            plantID: plant.id,
            plantName: plant.name,
            species: plant.species,
            location: plant.location,
            createdAt: plant.createdAt,
            acquiredDate: plant.acquiredDate,
            healthStatusRaw: plant.healthStatusRaw,
            logs: logs,
            languageCode: request.languageCode
        )

        return PlantDetailRenderData(
            revision: request.revision,
            careTasks: tasks,
            recentLogs: logs,
            taskSummary: taskSummary,
            logSummary: logSummary,
            galleryPhotoItems: photos,
            growthDiaryPhotoCount: logPhotoCount,
            growthDiaryMarkdown: diaryMarkdown
        )
    }

    private static func taskSummary(
        for plant: Plant,
        tasks: [PlantCareTaskSnapshot]
    ) -> PlantDetailTaskSummary {
        PlantDetailTaskSummary(
            nextTask: tasks.first,
            dueTaskCount: tasks.count { $0.daysUntilDue <= 0 },
            todayCareTasks: Array(tasks.lazy.filter { $0.daysUntilDue <= 0 }.prefix(4)),
            isWateringDue: tasks.contains { $0.careType == .watering && $0.daysUntilDue <= 0 },
            isFertilizingDue: tasks.contains { $0.careType == .fertilizing && $0.daysUntilDue <= 0 },
            wateringIntervalDays: tasks.first { $0.careType == .watering }?.effectiveIntervalDays ?? plant.wateringIntervalDays,
            fertilizingIntervalDays: tasks.first { $0.careType == .fertilizing }?.effectiveIntervalDays ?? plant.fertilizingIntervalDays,
            pestCheckTask: tasks.first { $0.careType == .pestCheck },
            leafCleaningTask: tasks.first { $0.careType == .leafCleaning },
            learningSummary: tasks.first { !$0.learningSummary.isEmpty }?.learningSummary
        )
    }

    private static func logSummary(
        logs: [PlantDetailLogSnapshot],
        now: Date
    ) -> PlantDetailLogSummary {
        let reviewTypes: Set<PlantCareType> = [
            .pestCheck,
            .pestFound,
            .yellowLeaf,
            .newLeaf,
            .leafCleaning,
            .photo,
            .customNote
        ]
        let windowStart = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 86400)
        let latestHealthReviewLog = logs.first { reviewTypes.contains($0.careType) }
        var recentStressSignalCount = 0
        var recentObservationLogCount = 0
        for log in logs where log.date >= windowStart {
            if log.careType == .yellowLeaf || log.careType == .pestFound {
                recentStressSignalCount += 1
            }
            if reviewTypes.contains(log.careType) {
                recentObservationLogCount += 1
            }
        }

        return PlantDetailLogSummary(
            logCount: logs.count,
            firstLogDate: logs.last?.date,
            latestLogDate: logs.first?.date,
            latestLog: logs.first,
            latestHealthReviewLog: latestHealthReviewLog,
            recentStressSignalCount: recentStressSignalCount,
            recentObservationLogCount: recentObservationLogCount
        )
    }

    private static func galleryPhotoItems(
        for plant: Plant,
        logs: [PlantDetailLogSnapshot],
        languageCode: String
    ) -> [PlantDetailPhotoItem] {
        let l = L10n(languageCode)
        var items: [PlantDetailPhotoItem] = []

        if plant.hasAvatarImageAttachment {
            items.append(
                PlantDetailPhotoItem(
                    id: "\(plant.id.uuidString)-profile",
                    source: .profile,
                    mediaSignature: plant.avatarThumbnailSignature,
                    title: plant.name,
                    subtitle: l.tr(zh: "档案照片", en: "Profile photo", de: "Profilfoto"),
                    detail: placementSummary(for: plant, l: l),
                    tintToken: healthTintToken(for: plant)
                )
            )
        }

        items += logs.compactMap { log -> PlantDetailPhotoItem? in
            guard log.hasPhoto else { return nil }
            return PlantDetailPhotoItem(
                id: "\(plant.id.uuidString)-log-\(log.id.uuidString)",
                source: .careLog(log.modelID, log.id),
                mediaSignature: log.photoImageSignature,
                title: log.careType.displayName(l: l),
                subtitle: timelineDateText(for: log),
                detail: timelineNoteText(for: log) ?? plant.name,
                tintToken: careTintToken(for: log.careType)
            )
        }

        return items
    }

    private static func placementSummary(for plant: Plant, l: L10n) -> String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactSpot = plant.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty, !exactSpot.isEmpty, room != exactSpot {
            return "\(room) · \(exactSpot)"
        }
        if !room.isEmpty { return room }
        if !exactSpot.isEmpty { return exactSpot }
        return l.tr(zh: "未设置位置", en: "No location set", de: "Kein Standort")
    }

    private static func healthTintToken(for plant: Plant) -> PlantDetailPhotoTint {
        switch plant.healthStatus {
        case .thriving:
            .primary
        case .stable:
            .teal
        case .watching:
            .yellow
        case .stressed:
            .red
        }
    }

    private static func timelineDateText(for log: PlantDetailLogSnapshot) -> String {
        log.date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func timelineNoteText(for log: PlantDetailLogSnapshot) -> String? {
        let note = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty,
              !note.hasPrefix("defer:"),
              !note.hasPrefix("skip:") else { return nil }
        return note
    }

    private static func careTintToken(for type: PlantCareType) -> PlantDetailPhotoTint {
        switch type {
        case .watering, .misting:
            .teal
        case .fertilizing, .newLeaf:
            .primary
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            .yellow
        case .yellowLeaf, .pestFound:
            .red
        }
    }
}
