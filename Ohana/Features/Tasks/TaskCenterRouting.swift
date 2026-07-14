//
//  TaskCenterRouting.swift
//  Ohana
//
//  Typed route context for opening the single Task Center from subject pages.
//

import Foundation

nonisolated enum TaskCenterScope: Hashable, Sendable {
    case all
    case human(UUID)
    case pet(UUID)
    case plant(UUID)

    var routeID: String {
        switch self {
        case .all:
            "all"
        case let .human(id):
            "human-\(id.uuidString)"
        case let .pet(id):
            "pet-\(id.uuidString)"
        case let .plant(id):
            "plant-\(id.uuidString)"
        }
    }
}

nonisolated struct TaskCenterRouteContext: Hashable, Sendable {
    var scope: TaskCenterScope
    var focusedItemID: String?
    var focusedFamilyTaskID: UUID?
    var focusRequestID: UUID? = nil
    var creationPreset: TaskCreationPreset? = nil

    init(scope: TaskCenterScope, focusedFamilyTaskID: UUID?) {
        self.scope = scope
        focusedItemID = nil
        self.focusedFamilyTaskID = focusedFamilyTaskID
        focusRequestID = nil
        creationPreset = nil
    }

    init(scope: TaskCenterScope, focusedFamilyTaskID: UUID?, focusRequestID: UUID?) {
        self.scope = scope
        focusedItemID = nil
        self.focusedFamilyTaskID = focusedFamilyTaskID
        self.focusRequestID = focusRequestID
        creationPreset = nil
    }

    init(
        scope: TaskCenterScope,
        focusedItemID: String?,
        focusedFamilyTaskID: UUID? = nil,
        focusRequestID: UUID? = nil,
        creationPreset: TaskCreationPreset? = nil
    ) {
        self.scope = scope
        self.focusedItemID = focusedItemID
        self.focusedFamilyTaskID = focusedFamilyTaskID
        self.focusRequestID = focusRequestID
        self.creationPreset = creationPreset
    }

    static let all = TaskCenterRouteContext(scope: .all, focusedFamilyTaskID: nil)

    static func human(_ id: UUID) -> TaskCenterRouteContext {
        TaskCenterRouteContext(scope: .human(id), focusedFamilyTaskID: nil)
    }

    static func familyTask(_ id: UUID) -> TaskCenterRouteContext {
        TaskCenterRouteContext(scope: .all, focusedFamilyTaskID: id, focusRequestID: UUID())
    }

    static func createCare(_ preset: TaskCreationPreset) -> TaskCenterRouteContext {
        let scope: TaskCenterScope = switch preset.subjectKind {
        case .pet: .pet(preset.subjectID)
        case .plant: .plant(preset.subjectID)
        }
        return TaskCenterRouteContext(
            scope: scope,
            focusedItemID: nil,
            creationPreset: preset
        )
    }

    var preselectedEntityType: String? {
        switch scope {
        case .all: nil
        case .human: EntityKind.human.rawValue
        case .pet: EntityKind.pet.rawValue
        case .plant: EntityKind.plant.rawValue
        }
    }

    var preselectedEntityId: String? {
        switch scope {
        case .all: nil
        case let .human(id), let .pet(id), let .plant(id): id.uuidString
        }
    }
}
