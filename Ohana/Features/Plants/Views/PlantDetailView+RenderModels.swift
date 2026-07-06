//
//  PlantDetailView+RenderModels.swift
//  Ohana
//
//  Created by Codex on 04.07.26.
//

import SwiftData
import SwiftUI

struct PlantCarePlanInsight: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

struct PlantQuickCareConfirmDraft: Identifiable, Hashable {
    let careType: PlantCareType
    let title: String
    let detail: String

    var id: String { careType.rawValue }
}

struct PlantQuickCareToast: Identifiable, Hashable {
    let id = UUID()
    let careType: PlantCareType
    let message: String
}

struct PlantPlacementFitItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

struct PlantSeasonalCareItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

struct PlantHealthReviewSignal: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let priority: Int
}

enum PlantDetailFeatureAnchor: Hashable {
    case overview
    case todayCare
    case carePlan
    case profile
    case safety
    case knowledge
    case healthReview
    case growthDiary
    case timeline
}

nonisolated enum PlantDetailPhotoTint: Sendable {
    case primary
    case teal
    case yellow
    case red

    @MainActor
    var color: Color {
        switch self {
        case .primary:
            Color.goPrimary
        case .teal:
            Color.goTeal
        case .yellow:
            Color.goYellow
        case .red:
            Color.goRed
        }
    }
}

nonisolated struct PlantDetailPhotoItem: Identifiable, Sendable {
    enum Source: Equatable, Sendable {
        case profile
        case careLog(PersistentIdentifier, UUID)
    }

    let id: String
    let source: Source
    let mediaSignature: String
    let title: String
    let subtitle: String
    let detail: String
    let tintToken: PlantDetailPhotoTint

    @MainActor
    var tint: Color {
        tintToken.color
    }
}

nonisolated struct PlantDetailLogSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let modelID: PersistentIdentifier
    let date: Date
    let careType: PlantCareType
    let note: String
    let healthStatusRaw: String
    let hasPhoto: Bool
    let photoImageSignature: String

    init(log: PlantCareLog) {
        id = log.id
        modelID = log.persistentModelID
        date = log.date
        careType = log.careType
        note = log.note
        healthStatusRaw = log.healthStatusRaw
        hasPhoto = log.hasPhotoAttachment
        photoImageSignature = log.photoThumbnailSignature
    }
}

nonisolated struct PlantDetailTaskSummary: Equatable, Sendable {
    let nextTask: PlantCareTaskSnapshot?
    let dueTaskCount: Int
    let todayCareTasks: [PlantCareTaskSnapshot]
    let isWateringDue: Bool
    let isFertilizingDue: Bool
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let pestCheckTask: PlantCareTaskSnapshot?
    let leafCleaningTask: PlantCareTaskSnapshot?
    let learningSummary: String?
}

nonisolated struct PlantDetailLogSummary: Equatable, Sendable {
    let logCount: Int
    let firstLogDate: Date?
    let latestLogDate: Date?
    let latestLog: PlantDetailLogSnapshot?
    let latestHealthReviewLog: PlantDetailLogSnapshot?
    let recentStressSignalCount: Int
    let recentObservationLogCount: Int

    var hasLogs: Bool { logCount > 0 }
    var hasRecentStressSignals: Bool { recentStressSignalCount > 0 }
}

nonisolated struct PlantDetailRenderData: Sendable {
    let revision: Int
    let careTasks: [PlantCareTaskSnapshot]
    let recentLogs: [PlantDetailLogSnapshot]
    let taskSummary: PlantDetailTaskSummary
    let logSummary: PlantDetailLogSummary
    let galleryPhotoItems: [PlantDetailPhotoItem]
    let growthDiaryPhotoCount: Int
    let growthDiaryMarkdown: String
}

nonisolated struct PlantDetailRenderDataRequest: Sendable {
    let plantModelID: PersistentIdentifier
    let revision: Int
    let languageCode: String
    let now: Date
}
