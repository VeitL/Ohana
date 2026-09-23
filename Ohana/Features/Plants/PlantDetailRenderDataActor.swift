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
    private static let recentLogLimit = 80
    private static let photoPreviewLimit = 120
    private static let healthReviewTypes: [PlantCareType] = [
        .pestCheck,
        .pestFound,
        .yellowLeaf,
        .newLeaf,
        .leafCleaning,
        .photo,
        .customNote
    ]

    func build(request: PlantDetailRenderDataRequest) throws -> PlantDetailRenderData {
        try Task.checkCancellation()
        guard let plant = modelContext.model(for: request.plantModelID) as? Plant else {
            throw PlantDetailRenderDataBuildError.missingPlant
        }

        let plantID = plant.id
        var recentDescriptor = Self.visibleLogDescriptor(plantID: plantID, sortOrder: .reverse)
        recentDescriptor.fetchLimit = Self.recentLogLimit
        let recentLogs: [PlantDetailLogSnapshot] = try modelContext.fetch(recentDescriptor).compactMap { log in
            guard !PlantCareHistoryPolicy.isInternalFeedback(log) else { return nil }
            return PlantDetailLogSnapshot(log: log)
        }
        try Task.checkCancellation()

        let planningHistory = try PlantCarePlanningHistoryQuery.build(
            plantID: plantID,
            context: modelContext
        )
        let tasks = PlantCarePlanService.tasks(
            for: plant,
            history: planningHistory,
            now: request.now,
            calendar: .current
        )
        var photoDescriptor = Self.visiblePhotoLogDescriptor(plantID: plantID)
        photoDescriptor.fetchLimit = Self.photoPreviewLimit
        let photoLogs: [PlantDetailLogSnapshot] = try modelContext.fetch(photoDescriptor).compactMap { log in
            guard !PlantCareHistoryPolicy.isInternalFeedback(log) else { return nil }
            return PlantDetailLogSnapshot(log: log)
        }
        let photos = Self.galleryPhotoItems(
            for: plant,
            logs: photoLogs,
            languageCode: request.languageCode
        )
        let taskSummary = Self.taskSummary(
            for: plant,
            tasks: tasks
        )
        let logSummary = try buildLogSummary(
            plantID: plantID,
            recentLogs: recentLogs,
            now: request.now
        )
        let logPhotoCount = try modelContext.fetchCount(Self.visiblePhotoLogDescriptor(plantID: plantID))

        return PlantDetailRenderData(
            revision: request.revision,
            careTasks: tasks,
            recentLogs: recentLogs,
            taskSummary: taskSummary,
            logSummary: logSummary,
            galleryPhotoItems: photos,
            growthDiaryPhotoCount: logPhotoCount
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

    private func buildLogSummary(
        plantID: UUID,
        recentLogs: [PlantDetailLogSnapshot],
        now: Date
    ) throws -> PlantDetailLogSummary {
        let windowStart = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 86400)
        let logCount = try modelContext.fetchCount(Self.visibleLogDescriptor(plantID: plantID, sortOrder: .reverse))
        let firstLog = try fetchOne(Self.visibleLogDescriptor(plantID: plantID, sortOrder: .forward))
        let latestLog = try recentLogs.first ?? fetchOne(Self.visibleLogDescriptor(plantID: plantID, sortOrder: .reverse))
        let latestHealthReviewLog = try Self.healthReviewTypes.compactMap { careType in
            try fetchOne(Self.visibleLogDescriptor(plantID: plantID, careType: careType, sortOrder: .reverse))
        }.max { lhs, rhs in lhs.date < rhs.date }
        let recentStressSignalCount = try [.yellowLeaf, .pestFound].reduce(into: 0) { count, careType in
            count += try modelContext.fetchCount(
                Self.visibleLogDescriptor(plantID: plantID, careType: careType, since: windowStart)
            )
        }
        let recentObservationLogCount = try Self.healthReviewTypes.reduce(into: 0) { count, careType in
            count += try modelContext.fetchCount(
                Self.visibleLogDescriptor(plantID: plantID, careType: careType, since: windowStart)
            )
        }

        return PlantDetailLogSummary(
            logCount: logCount,
            firstLogDate: firstLog?.date,
            latestLogDate: latestLog?.date,
            latestLog: latestLog,
            latestHealthReviewLog: latestHealthReviewLog,
            recentStressSignalCount: recentStressSignalCount,
            recentObservationLogCount: recentObservationLogCount
        )
    }

    private func fetchOne(_ descriptor: FetchDescriptor<PlantCareLog>) throws -> PlantDetailLogSnapshot? {
        var descriptor = descriptor
        descriptor.fetchLimit = 1
        guard let log = try modelContext.fetch(descriptor).first,
              !PlantCareHistoryPolicy.isInternalFeedback(log) else {
            return nil
        }
        return PlantDetailLogSnapshot(log: log)
    }

    private static func visibleLogDescriptor(
        plantID: UUID,
        sortOrder: SortOrder
    ) -> FetchDescriptor<PlantCareLog> {
        let customNoteRaw = PlantCareType.customNote.rawValue
        let deferPrefix = PlantCareHistoryPolicy.internalDeferPrefix
        let skipPrefix = PlantCareHistoryPolicy.internalSkipPrefix
        return FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.plant?.id == plantID &&
                    (log.careTypeRaw != customNoteRaw ||
                        (!log.note.starts(with: deferPrefix) && !log.note.starts(with: skipPrefix)))
            },
            sortBy: [SortDescriptor(\PlantCareLog.date, order: sortOrder)]
        )
    }

    private static func visibleLogDescriptor(
        plantID: UUID,
        careType: PlantCareType,
        sortOrder: SortOrder
    ) -> FetchDescriptor<PlantCareLog> {
        let typeRaw = careType.rawValue
        let sortBy = [SortDescriptor(\PlantCareLog.date, order: sortOrder)]
        guard careType == .customNote else {
            return FetchDescriptor<PlantCareLog>(
                predicate: #Predicate<PlantCareLog> { log in
                    log.plant?.id == plantID && log.careTypeRaw == typeRaw
                },
                sortBy: sortBy
            )
        }

        let deferPrefix = PlantCareHistoryPolicy.internalDeferPrefix
        let skipPrefix = PlantCareHistoryPolicy.internalSkipPrefix
        return FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.plant?.id == plantID &&
                    log.careTypeRaw == typeRaw &&
                    !log.note.starts(with: deferPrefix) &&
                    !log.note.starts(with: skipPrefix)
            },
            sortBy: sortBy
        )
    }

    private static func visibleLogDescriptor(
        plantID: UUID,
        careType: PlantCareType,
        since startDate: Date
    ) -> FetchDescriptor<PlantCareLog> {
        let typeRaw = careType.rawValue
        guard careType == .customNote else {
            return FetchDescriptor<PlantCareLog>(
                predicate: #Predicate<PlantCareLog> { log in
                    log.plant?.id == plantID &&
                        log.careTypeRaw == typeRaw &&
                        log.date >= startDate
                }
            )
        }

        let deferPrefix = PlantCareHistoryPolicy.internalDeferPrefix
        let skipPrefix = PlantCareHistoryPolicy.internalSkipPrefix
        return FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.plant?.id == plantID &&
                    log.careTypeRaw == typeRaw &&
                    log.date >= startDate &&
                    !log.note.starts(with: deferPrefix) &&
                    !log.note.starts(with: skipPrefix)
            }
        )
    }

    private static func visiblePhotoLogDescriptor(plantID: UUID) -> FetchDescriptor<PlantCareLog> {
        let customNoteRaw = PlantCareType.customNote.rawValue
        let absentStateRaw = PlantCarePhotoAttachmentState.absent.rawValue
        let deferPrefix = PlantCareHistoryPolicy.internalDeferPrefix
        let skipPrefix = PlantCareHistoryPolicy.internalSkipPrefix
        return FetchDescriptor<PlantCareLog>(
            predicate: #Predicate<PlantCareLog> { log in
                log.plant?.id == plantID &&
                    log.photoAttachmentStateRaw != absentStateRaw &&
                    (log.careTypeRaw != customNoteRaw ||
                        (!log.note.starts(with: deferPrefix) && !log.note.starts(with: skipPrefix)))
            },
            sortBy: [SortDescriptor(\PlantCareLog.date, order: .reverse)]
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

        return Array(items.prefix(photoPreviewLimit))
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
