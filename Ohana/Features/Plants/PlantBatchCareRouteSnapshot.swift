//
//  PlantBatchCareRouteSnapshot.swift
//  Ohana
//
//  Route-scoped value snapshots for the plant batch-care sheet.
//

import Foundation
import SwiftData

nonisolated struct PlantBatchCareSheetTask: Identifiable, Equatable, Sendable {
    let id: String
    let plantID: UUID
    let plantModelID: PersistentIdentifier
    let plantName: String
    let roomName: String
    let careType: PlantCareType
    let subtitle: String
    let dueText: String
    let avatarSignature: String
    let tintHex: String

    var selection: PlantBatchCareSelection {
        PlantBatchCareSelection(plantID: plantID, careType: careType, taskID: id)
    }
}

nonisolated struct PlantBatchCareSheetRoomSection: Identifiable, Equatable, Sendable {
    let id: String
    let room: String
    let tasks: [PlantBatchCareSheetTask]
}

nonisolated struct PlantBatchCareSheetFilterSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let careType: PlantCareType?
    let count: Int
    let taskIDs: [String]
    let roomSections: [PlantBatchCareSheetRoomSection]

    static func empty(careType: PlantCareType?) -> PlantBatchCareSheetFilterSnapshot {
        PlantBatchCareSheetFilterSnapshot(
            id: careType?.rawValue ?? "all",
            careType: careType,
            count: 0,
            taskIDs: [],
            roomSections: []
        )
    }
}

nonisolated struct PlantBatchCareSheetSnapshot: Equatable, Sendable {
    let tasks: [PlantBatchCareSheetTask]
    let allFilter: PlantBatchCareSheetFilterSnapshot
    let careTypeFilters: [PlantBatchCareSheetFilterSnapshot]
    let taskLookup: [String: PlantBatchCareSheetTask]
    let signature: String

    static let empty = PlantBatchCareSheetSnapshot(tasks: [])

    init(tasks rawTasks: [PlantBatchCareSheetTask]) {
        let tasks = Self.sortedTasks(rawTasks)
        self.tasks = tasks
        allFilter = Self.makeFilter(careType: nil, tasks: tasks)
        let careTypes = Array(Set(tasks.map(\.careType))).sorted {
            if Self.carePriority($0) != Self.carePriority($1) {
                return Self.carePriority($0) < Self.carePriority($1)
            }
            return $0.rawValue < $1.rawValue
        }
        careTypeFilters = careTypes.map { type in
            Self.makeFilter(careType: type, tasks: tasks.filter { $0.careType == type })
        }
        taskLookup = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        signature = tasks.map { "\($0.id):\($0.plantID.uuidString):\($0.careType.rawValue)" }.joined(separator: "|")
    }

    func filterSnapshot(for careType: PlantCareType?) -> PlantBatchCareSheetFilterSnapshot {
        guard let careType else { return allFilter }
        return careTypeFilters.first(where: { $0.careType == careType }) ?? .empty(careType: careType)
    }

    private static func makeFilter(
        careType: PlantCareType?,
        tasks: [PlantBatchCareSheetTask]
    ) -> PlantBatchCareSheetFilterSnapshot {
        let sorted = sortedTasks(tasks)
        return PlantBatchCareSheetFilterSnapshot(
            id: careType?.rawValue ?? "all",
            careType: careType,
            count: sorted.count,
            taskIDs: sorted.map(\.id),
            roomSections: groupedRooms(from: sorted)
        )
    }

    private static func groupedRooms(from tasks: [PlantBatchCareSheetTask]) -> [PlantBatchCareSheetRoomSection] {
        Dictionary(grouping: tasks, by: \.roomName)
            .map { room, roomTasks in
                PlantBatchCareSheetRoomSection(
                    id: room,
                    room: room,
                    tasks: sortedTasks(roomTasks)
                )
            }
            .sorted { $0.room.localizedStandardCompare($1.room) == .orderedAscending }
    }

    private static func sortedTasks(_ tasks: [PlantBatchCareSheetTask]) -> [PlantBatchCareSheetTask] {
        tasks.sorted {
            if $0.roomName != $1.roomName {
                return $0.roomName.localizedStandardCompare($1.roomName) == .orderedAscending
            }
            if $0.plantName != $1.plantName {
                return $0.plantName.localizedStandardCompare($1.plantName) == .orderedAscending
            }
            if carePriority($0.careType) != carePriority($1.careType) {
                return carePriority($0.careType) < carePriority($1.careType)
            }
            return $0.id < $1.id
        }
    }

    private static func carePriority(_ type: PlantCareType) -> Int {
        switch type {
        case .watering: 0
        case .fertilizing: 1
        case .pestCheck: 2
        case .misting: 3
        case .leafCleaning: 4
        case .rotating: 5
        case .pruning: 6
        case .repotting: 7
        case .photo, .newLeaf, .yellowLeaf, .pestFound, .customNote: 8
        }
    }
}

nonisolated struct PlantBatchCareRouteSnapshotInput: Sendable {
    let careType: PlantCareType?
    let roomID: String?
    let now: Date
    let days: Int
    let unassignedIndoorTitle: String
    let unassignedOutdoorTitle: String
}

@ModelActor
actor PlantBatchCareRouteSnapshotActor {
    func load(input: PlantBatchCareRouteSnapshotInput) throws -> PlantBatchCareSheetSnapshot {
        try Task.checkCancellation()
        let plants = fetchPlants()
        let plantByID = Dictionary(plants.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let tasks = PlantCarePlanService.tasks(for: plants, days: input.days, now: input.now)
            .filter { $0.daysUntilDue <= 0 }
            .filter { input.careType == nil || $0.careType == input.careType }
            .compactMap { task -> PlantBatchCareSheetTask? in
                guard let plant = plantByID[task.plantID] else { return nil }
                let roomName = Self.locationFilterValue(
                    for: plant,
                    unassignedIndoorTitle: input.unassignedIndoorTitle,
                    unassignedOutdoorTitle: input.unassignedOutdoorTitle
                )
                guard input.roomID == nil || roomName == input.roomID else { return nil }
                return PlantBatchCareSheetTask(
                    id: task.id,
                    plantID: plant.id,
                    plantModelID: plant.persistentModelID,
                    plantName: plant.name,
                    roomName: roomName,
                    careType: task.careType,
                    subtitle: task.subtitle,
                    dueText: Self.dueText(for: task),
                    avatarSignature: plant.avatarThumbnailSignature,
                    tintHex: plant.themeColorHex
                )
            }
        try Task.checkCancellation()
        return PlantBatchCareSheetSnapshot(tasks: tasks)
    }

    private func fetchPlants() -> [Plant] {
        do {
            return try modelContext.fetch(FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.createdAt)]))
        } catch {
            OhanaLog.warning("PlantBatchCareRouteSnapshotActor failed to fetch plants: \(error.localizedDescription)", category: "Plants")
            return []
        }
    }

    private static func locationFilterValue(
        for plant: Plant,
        unassignedIndoorTitle: String,
        unassignedOutdoorTitle: String
    ) -> String {
        let room = plant.roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty {
            return room
        }
        return plant.isIndoor ? unassignedIndoorTitle : unassignedOutdoorTitle
    }

    private static func dueText(for task: PlantCareTaskSnapshot) -> String {
        if task.daysUntilDue < 0 {
            return L10n.current.tr(zh: "已逾期 \(abs(task.daysUntilDue)) 天", en: "\(abs(task.daysUntilDue))d overdue", de: "\(abs(task.daysUntilDue)) T. überfällig")
        }
        if task.daysUntilDue == 0 {
            return L10n.current.tr(zh: "今天到期", en: "Due today", de: "Heute fällig")
        }
        return L10n.current.tr(zh: "\(task.daysUntilDue) 天后", en: "In \(task.daysUntilDue)d", de: "In \(task.daysUntilDue) T.")
    }
}
