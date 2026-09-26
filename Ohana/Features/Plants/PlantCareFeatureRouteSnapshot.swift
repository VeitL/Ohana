//
//  PlantCareFeatureRouteSnapshot.swift
//  Ohana
//
//  Route-scoped value snapshots for plant care feature detail pages.
//

import Foundation
import SwiftData

struct PlantCareFeatureRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let plantID: UUID
    let plantName: String
    let date: Date
    let careType: PlantCareType
    let note: String
    let healthStatus: PlantHealthStatus?
}

struct PlantCareFeatureRouteSnapshotRequest: Equatable, Sendable {
    let plantIDs: [UUID]
    let feature: PlantCareFeatureDestination
    let focusedCareType: PlantCareType?
    let historyLimit: Int
    let now: Date

    nonisolated init(
        plantIDs: [UUID],
        feature: PlantCareFeatureDestination,
        focusedCareType: PlantCareType?,
        historyLimit: Int = 80,
        now: Date
    ) {
        self.plantIDs = plantIDs
        self.feature = feature
        self.focusedCareType = focusedCareType
        self.historyLimit = max(1, historyLimit)
        self.now = now
    }

    nonisolated var key: String {
        [
            feature.rawValue,
            focusedCareType?.rawValue ?? "all",
            "limit:\(historyLimit)",
            plantIDs.map(\.uuidString).joined(separator: ",")
        ].joined(separator: "|")
    }

    nonisolated var primaryCareType: PlantCareType {
        focusedCareType ?? feature.primaryCareType
    }

    nonisolated func matches(_ careType: PlantCareType) -> Bool {
        focusedCareType.map { $0 == careType } ?? feature.matches(careType)
    }
}

struct PlantCareFeatureRouteSnapshot: Equatable, Sendable {
    let requestKey: String
    let hasLoaded: Bool
    let records: [PlantCareFeatureRecord]
    let totalRecordCount: Int
    let hasMore: Bool
    let duePlantIDs: Set<UUID>
    let primaryIntervalDaysByPlantID: [UUID: Int]
    let wateringTasksByPlantID: [UUID: PlantCareTaskSnapshot]

    static let empty = PlantCareFeatureRouteSnapshot(
        requestKey: "",
        hasLoaded: false,
        records: [],
        totalRecordCount: 0,
        hasMore: false,
        duePlantIDs: [],
        primaryIntervalDaysByPlantID: [:],
        wateringTasksByPlantID: [:]
    )

    static func loading(requestKey: String, preserving snapshot: PlantCareFeatureRouteSnapshot) -> PlantCareFeatureRouteSnapshot {
        PlantCareFeatureRouteSnapshot(
            requestKey: requestKey,
            hasLoaded: false,
            records: snapshot.requestKey == requestKey ? snapshot.records : [],
            totalRecordCount: snapshot.requestKey == requestKey ? snapshot.totalRecordCount : 0,
            hasMore: snapshot.requestKey == requestKey && snapshot.hasMore,
            duePlantIDs: snapshot.requestKey == requestKey ? snapshot.duePlantIDs : [],
            primaryIntervalDaysByPlantID: snapshot.requestKey == requestKey ? snapshot.primaryIntervalDaysByPlantID : [:],
            wateringTasksByPlantID: snapshot.requestKey == requestKey ? snapshot.wateringTasksByPlantID : [:]
        )
    }
}

@ModelActor
actor PlantCareFeatureRouteSnapshotActor {
    func load(request: PlantCareFeatureRouteSnapshotRequest) throws -> PlantCareFeatureRouteSnapshot {
        try Task.checkCancellation()

        var seenPlantIDs = Set<UUID>()
        let uniquePlantIDs = request.plantIDs.filter { seenPlantIDs.insert($0).inserted }
        let plants = try uniquePlantIDs.compactMap { plantID in
            try Task.checkCancellation()
            var descriptor = FetchDescriptor<Plant>(
                predicate: #Predicate<Plant> { plant in plant.id == plantID }
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first
        }
        let matchingCareTypes = PlantCareType.allCases.filter(request.matches)

        var records: [PlantCareFeatureRecord] = []
        var totalRecordCount = 0
        var duePlantIDs = Set<UUID>()
        var primaryIntervalDaysByPlantID: [UUID: Int] = [:]
        var wateringTasksByPlantID: [UUID: PlantCareTaskSnapshot] = [:]

        for plant in plants {
            try Task.checkCancellation()

            for careType in matchingCareTypes {
                try Task.checkCancellation()
                var descriptor = Self.visibleLogDescriptor(
                    plantID: plant.id,
                    careType: careType,
                    sortOrder: .reverse
                )
                totalRecordCount += try modelContext.fetchCount(descriptor)
                descriptor.fetchLimit = request.historyLimit
                records += try modelContext.fetch(descriptor).compactMap { log in
                    guard !PlantCareHistoryPolicy.isInternalFeedback(log) else { return nil }
                    return PlantCareFeatureRecord(
                        id: log.id,
                        plantID: plant.id,
                        plantName: plant.name,
                        date: log.date,
                        careType: log.careType,
                        note: log.note.trimmingCharacters(in: .whitespacesAndNewlines),
                        healthStatus: log.healthStatus
                    )
                }
            }

            let planningHistory = try PlantCarePlanningHistoryQuery.build(
                plantID: plant.id,
                context: modelContext
            )
            let tasks = PlantCarePlanService.tasks(
                for: plant,
                history: planningHistory,
                now: request.now,
                calendar: .current
            )
            if let wateringTask = tasks.first(where: { $0.careType == .watering }) {
                wateringTasksByPlantID[plant.id] = wateringTask
            }

            let primaryCareType = request.primaryCareType
            let intervalDays = tasks.first { $0.careType == primaryCareType }?.effectiveIntervalDays
                ?? Self.fallbackIntervalDays(for: primaryCareType, plant: plant)
            primaryIntervalDaysByPlantID[plant.id] = max(1, intervalDays)

            if request.feature.category?.isSchedulable == true,
               tasks.contains(where: { request.matches($0.careType) && $0.daysUntilDue <= 0 }) {
                duePlantIDs.insert(plant.id)
            }
        }

        let boundedRecords = Array(records.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id.uuidString > rhs.id.uuidString
        }.prefix(request.historyLimit))
        return PlantCareFeatureRouteSnapshot(
            requestKey: request.key,
            hasLoaded: true,
            records: boundedRecords,
            totalRecordCount: totalRecordCount,
            hasMore: totalRecordCount > request.historyLimit,
            duePlantIDs: duePlantIDs,
            primaryIntervalDaysByPlantID: primaryIntervalDaysByPlantID,
            wateringTasksByPlantID: wateringTasksByPlantID
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

    nonisolated static func fallbackIntervalDays(for type: PlantCareType, plant: Plant) -> Int {
        switch type {
        case .watering:
            max(1, plant.wateringIntervalDays)
        case .fertilizing:
            max(1, plant.fertilizingIntervalDays)
        case .misting:
            plant.humidityPreference == .humid ? 3 : 7
        case .pestCheck:
            21
        case .leafCleaning:
            30
        case .rotating:
            14
        case .pruning:
            45
        case .repotting:
            180
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote:
            30
        }
    }
}
