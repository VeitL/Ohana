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
    let now: Date

    nonisolated var key: String {
        [
            feature.rawValue,
            focusedCareType?.rawValue ?? "all",
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
    let duePlantIDs: Set<UUID>
    let primaryIntervalDaysByPlantID: [UUID: Int]
    let wateringTasksByPlantID: [UUID: PlantCareTaskSnapshot]

    static let empty = PlantCareFeatureRouteSnapshot(
        requestKey: "",
        hasLoaded: false,
        records: [],
        duePlantIDs: [],
        primaryIntervalDaysByPlantID: [:],
        wateringTasksByPlantID: [:]
    )

    static func loading(requestKey: String, preserving snapshot: PlantCareFeatureRouteSnapshot) -> PlantCareFeatureRouteSnapshot {
        PlantCareFeatureRouteSnapshot(
            requestKey: requestKey,
            hasLoaded: false,
            records: snapshot.requestKey == requestKey ? snapshot.records : [],
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

        let requestedPlantIDs = Set(request.plantIDs)
        let orderByPlantID = Dictionary(uniqueKeysWithValues: request.plantIDs.enumerated().map { ($0.element, $0.offset) })
        let plants = try modelContext.fetch(FetchDescriptor<Plant>())
            .filter { requestedPlantIDs.contains($0.id) }
            .sorted {
                let lhsIndex = orderByPlantID[$0.id] ?? Int.max
                let rhsIndex = orderByPlantID[$1.id] ?? Int.max
                if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

        var records: [PlantCareFeatureRecord] = []
        var duePlantIDs = Set<UUID>()
        var primaryIntervalDaysByPlantID: [UUID: Int] = [:]
        var wateringTasksByPlantID: [UUID: PlantCareTaskSnapshot] = [:]

        for plant in plants {
            try Task.checkCancellation()

            for log in plant.careLogs where request.matches(log.careType) {
                records.append(
                    PlantCareFeatureRecord(
                        id: log.id,
                        plantID: plant.id,
                        plantName: plant.name,
                        date: log.date,
                        careType: log.careType,
                        note: log.note.trimmingCharacters(in: .whitespacesAndNewlines),
                        healthStatus: log.healthStatus
                    )
                )
            }

            let tasks = PlantCarePlanService.tasks(for: plant, now: request.now, calendar: .current)
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

        return PlantCareFeatureRouteSnapshot(
            requestKey: request.key,
            hasLoaded: true,
            records: records.sorted { $0.date > $1.date },
            duePlantIDs: duePlantIDs,
            primaryIntervalDaysByPlantID: primaryIntervalDaysByPlantID,
            wateringTasksByPlantID: wateringTasksByPlantID
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
