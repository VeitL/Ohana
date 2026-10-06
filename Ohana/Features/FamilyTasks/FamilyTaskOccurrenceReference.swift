//
//  FamilyTaskOccurrenceReference.swift
//  Ohana
//
//  Sendable identities shared by recurrence editing and command boundaries.
//

import Foundation

nonisolated enum FamilyTaskEditScope: String, Codable, CaseIterable, Sendable {
    case onlyThis
    case thisAndFuture
}

nonisolated struct FamilyTaskOccurrenceReference: Codable, Equatable, Hashable, Sendable {
    let planID: UUID
    let occurrenceKey: String
    let taskID: UUID?

    init(planID: UUID, occurrenceKey: String, taskID: UUID? = nil) {
        self.planID = planID
        self.occurrenceKey = occurrenceKey
        self.taskID = taskID
    }
}
