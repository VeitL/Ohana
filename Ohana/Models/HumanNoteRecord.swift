//
//  HumanNoteRecord.swift
//  Ohana
//
//  Structured attribution sidecar for legacy Human.notes timeline entries.
//

import Foundation
import SwiftData

@Model
final class HumanNoteRecord {
    var id: UUID
    var humanId: UUID
    var sequence: Int
    var date: Date
    var rawEntry: String
    var recordedByHumanId: String?

    init(
        id: UUID = UUID(),
        humanId: UUID,
        sequence: Int,
        date: Date,
        rawEntry: String,
        recordedByHumanId: String?
    ) {
        self.id = id
        self.humanId = humanId
        self.sequence = sequence
        self.date = date
        self.rawEntry = rawEntry
        self.recordedByHumanId = recordedByHumanId
    }
}
