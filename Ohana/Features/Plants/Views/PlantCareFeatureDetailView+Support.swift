//
//  PlantCareFeatureDetailView+Support.swift
//  Ohana
//
//  Projection helpers, persistence actions, and formatting for plant care pages.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

extension PlantCareFeatureDetailView {
    func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    func featureRecords(for plant: Plant) -> [PlantCareFeatureRecord] {
        records.filter { $0.plantID == plant.id && matchesFocusedFeature($0.careType) }
    }

    var duePlantsForFeature: [Plant] {
        guard feature.category?.isSchedulable == true else { return [] }
        return scopedPlants.filter { routeSnapshot.duePlantIDs.contains($0.id) }
    }

    func roomName(for plant: Plant) -> String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty { return room }
        return plant.isIndoor
            ? l.tr(zh: "未设置室内位置", en: "Unassigned indoor", de: "Innen ohne Ort")
            : l.tr(zh: "未设置户外位置", en: "Unassigned outdoor", de: "Außen ohne Ort")
    }

    func daysSinceFeatureCare(for plant: Plant) -> Int? {
        switch feature {
        case .water:
            plant.daysSinceWatered
        case .fertilize:
            plant.daysSinceFertilized
        case .maintenance, .health, .growth, .log:
            lastFeatureCareDate(for: plant).flatMap {
                Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: $0), to: Calendar.current.startOfDay(for: Date())).day
            }
        }
    }

    func plannedIntervalDays(for plant: Plant) -> Int {
        routeSnapshot.primaryIntervalDaysByPlantID[plant.id] ?? PlantCareFeatureRouteSnapshotActor.fallbackIntervalDays(
            for: primaryCareType,
            plant: plant
        )
    }

    func overdueDays(for plant: Plant) -> Int {
        let planned = plannedIntervalDays(for: plant)
        guard let daysSinceFeatureCare = daysSinceFeatureCare(for: plant) else { return planned }
        return max(0, daysSinceFeatureCare - planned)
    }

    func featureCadenceDates(for plant: Plant) -> [Date] {
        featureRecords(for: plant)
            .map(\.date)
            .sorted()
    }

    func averageIntervalDays(for plant: Plant) -> Int? {
        let dates = featureCadenceDates(for: plant)
        guard dates.count >= 2 else { return nil }
        var gaps: [Int] = []
        for index in dates.indices.dropFirst() {
            let previous = Calendar.current.startOfDay(for: dates[index - 1])
            let current = Calendar.current.startOfDay(for: dates[index])
            gaps.append(max(0, Calendar.current.dateComponents([.day], from: previous, to: current).day ?? 0))
        }
        guard !gaps.isEmpty else { return nil }
        return Int((Double(gaps.reduce(0, +)) / Double(gaps.count)).rounded())
    }

    func lastFeatureCareDate(for plant: Plant) -> Date? {
        featureRecords(for: plant)
            .map(\.date)
            .max()
    }

    func openLog(for plant: Plant) {
        logDraft = PlantCareFeatureLogDraft(plantID: plant.id, careType: primaryCareType)
    }

    func saveCareLog(
        _ careType: PlantCareType,
        plant: Plant,
        careNote: String,
        healthStatus: PlantHealthStatus,
        photoData: Data?,
        executorID: UUID?
    ) {
        let request = PlantCareCommandRequest(
            careType: careType,
            plant: plant,
            executorID: executorID?.uuidString,
            careNote: careNote,
            photoData: photoData,
            healthStatus: healthStatus
        )
        let result = PlantCareCommandExecutor(context: modelContext, services: appServices).recordCare(
            request,
            note: "plant.feature.care",
            options: PlantCareCommandOptions()
        )
        UINotificationFeedbackGenerator().notificationOccurred(result.didPersist ? .success : .error)
        if result.didPersist {
            scheduleRouteSnapshotRefresh(force: true, delayMilliseconds: 0)
        }
    }

    func scheduleRouteSnapshotRefresh(force: Bool = false, delayMilliseconds: UInt64 = 24) {
        let request = routeSnapshotRequest
        guard force || routeSnapshot.requestKey != request.key || !routeSnapshot.hasLoaded else { return }
        routeSnapshotRefreshTask?.cancel()
        routeSnapshotRefreshGeneration += 1
        let generation = routeSnapshotRefreshGeneration
        let container = modelContext.container
        routeSnapshot = PlantCareFeatureRouteSnapshot.loading(requestKey: request.key, preserving: routeSnapshot)
        routeSnapshotRefreshTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: delayMilliseconds)
            guard !Task.isCancelled,
                  generation == routeSnapshotRefreshGeneration else {
                return
            }
            let builder = PlantCareFeatureRouteSnapshotActor(modelContainer: container)
            do {
                let snapshot = try await builder.load(request: request)
                guard !Task.isCancelled,
                      generation == routeSnapshotRefreshGeneration,
                      snapshot.requestKey == routeSnapshotRequest.key else {
                    return
                }
                applyRouteSnapshot(snapshot)
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning("Plant care feature route snapshot load failed: \(error)", category: "Plants")
            }
            clearRouteSnapshotRefreshTask(generation: generation)
        }
    }

    func applyRouteSnapshot(_ snapshot: PlantCareFeatureRouteSnapshot) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            routeSnapshot = snapshot
        }
    }

    func clearRouteSnapshotRefreshTask(generation: Int) {
        guard generation == routeSnapshotRefreshGeneration else { return }
        routeSnapshotRefreshTask = nil
    }

    func plant(for id: UUID) -> Plant? {
        plants.first { $0.id == id }
    }

    func relativeDateText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func fullDateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    func healthStatusText(_ status: PlantHealthStatus) -> String {
        switch status {
        case .thriving:
            l.tr(zh: "状态很好", en: "Thriving", de: "Sehr guter Zustand")
        case .stable:
            l.tr(zh: "稳定", en: "Stable", de: "Stabil")
        case .watching:
            l.tr(zh: "需要观察", en: "Needs watching", de: "Beobachten")
        case .stressed:
            l.tr(zh: "状态紧张", en: "Stressed", de: "Gestresst")
        }
    }

    func healthTint(for status: PlantHealthStatus) -> Color {
        switch status {
        case .thriving:
            Color.goPrimary
        case .stable:
            Color.goTeal
        case .watching:
            Color.goYellow
        case .stressed:
            Color.goRed
        }
    }

    func careTint(for type: PlantCareType) -> Color {
        switch type {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goPrimary
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        case .yellowLeaf, .pestFound:
            Color.goRed
        }
    }

    func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering:
            "drop.fill"
        case .fertilizing:
            "leaf.fill"
        case .repotting:
            "arrow.triangle.2.circlepath"
        case .pruning:
            "scissors"
        case .misting:
            "cloud.drizzle.fill"
        case .rotating:
            "rotate.3d"
        case .leafCleaning:
            "sparkles"
        case .pestCheck:
            "ladybug.fill"
        case .photo:
            "camera.fill"
        case .newLeaf:
            "leaf.circle.fill"
        case .yellowLeaf:
            "exclamationmark.triangle.fill"
        case .pestFound:
            "ant.fill"
        case .customNote:
            "note.text"
        }
    }

    func plantAvatar(_ plant: Plant) -> some View {
        Text(plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji)
            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
            .frame(width: 44, height: 44)
            .background(Color(hex: plant.themeColorHex).opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }

    func plantStatusText(_ plant: Plant) -> String {
        if showsFertilizingCadence {
            guard let lastDate = plant.lastFertilizedDate else {
                return l.tr(
                    zh: "还没有施肥记录",
                    en: "No fertilizer log yet",
                    de: "Noch kein Düngeprotokoll"
                )
            }
            return l.tr(
                zh: "最近施肥：\(fullDateText(lastDate))",
                en: "Last fertilized: \(fullDateText(lastDate))",
                de: "Zuletzt gedüngt: \(fullDateText(lastDate))"
            )
        }

        switch feature {
        case .water:
            if let days = plant.daysSinceWatered {
                return l.tr(zh: "上次浇水 \(days) 天前", en: "Last watered \(days)d ago", de: "Zuletzt vor \(days) T. gegossen")
            }
            return l.tr(zh: "还没有浇水记录", en: "No water log yet", de: "Noch kein Gießprotokoll")
        case .fertilize:
            let count = featureRecords(for: plant).count
            return count == 0
                ? l.tr(zh: "还没有相关记录", en: "No matching logs yet", de: "Noch keine passenden Einträge")
                : l.tr(zh: "\(count) 条相关记录", en: "\(count) matching logs", de: "\(count) passende Einträge")
        case .maintenance, .health, .growth, .log:
            let count = featureRecords(for: plant).count
            return count == 0
                ? l.tr(zh: "还没有相关记录", en: "No matching logs yet", de: "Noch keine passenden Einträge")
                : l.tr(zh: "\(count) 条相关记录", en: "\(count) matching logs", de: "\(count) passende Einträge")
        }
    }

    func fertilizingCadenceText(for plant: Plant) -> String {
        let intervalDays = plannedIntervalDays(for: plant)
        let statusText = if let status = CareCycleStatus.make(
            lastDate: plant.lastFertilizedDate,
            intervalDays: intervalDays
        ) {
            switch status.duePhase {
            case .upcoming:
                l.tr(
                    zh: "距下次施肥 \(status.compactDueText(l: l))",
                    en: "Next fertilizing in \(status.compactDueText(l: l))",
                    de: "Nächste Düngung in \(status.compactDueText(l: l))"
                )
            case .dueToday, .overdue:
                status.compactDueText(l: l)
            }
        } else {
            l.tr(
                zh: "待首次施肥",
                en: "Awaiting first fertilizing",
                de: "Erste Düngung ausstehend"
            )
        }
        return l.tr(
            zh: "计划每 \(intervalDays) 天 · \(statusText)",
            en: "Every \(intervalDays)d · \(statusText)",
            de: "Alle \(intervalDays) T. · \(statusText)"
        )
    }
}
