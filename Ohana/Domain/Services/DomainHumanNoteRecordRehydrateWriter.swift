//
//  DomainHumanNoteRecordRehydrateWriter.swift
//  Ohana
//
//  Backup rehydrate boundary for structured Human note attribution records.
//

import Foundation
import SwiftData

nonisolated struct DomainHumanNoteRecordRehydrateSnapshot: Equatable {
    let id: UUID
    let humanId: UUID
    let sequence: Int
    let date: Date
    let rawEntry: String
    let recordedByHumanId: String?
}

nonisolated enum DomainHumanNoteRecordRehydrateWriter {
    static func insertIfNeeded(
        snapshot: DomainHumanNoteRecordRehydrateSnapshot,
        context: ModelContext
    ) throws {
        guard try fetchHuman(id: snapshot.humanId, context: context) != nil else { return }
        if let existing = try fetchRecord(id: snapshot.id, context: context) {
            existing.humanId = snapshot.humanId
            existing.sequence = snapshot.sequence
            existing.date = snapshot.date
            existing.rawEntry = snapshot.rawEntry
            existing.recordedByHumanId = snapshot.recordedByHumanId
            return
        }
        context.insert(HumanNoteRecord(
            id: snapshot.id,
            humanId: snapshot.humanId,
            sequence: snapshot.sequence,
            date: snapshot.date,
            rawEntry: snapshot.rawEntry,
            recordedByHumanId: snapshot.recordedByHumanId
        ))
    }

    private static func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchRecord(id: UUID, context: ModelContext) throws -> HumanNoteRecord? {
        var descriptor = FetchDescriptor<HumanNoteRecord>(predicate: #Predicate<HumanNoteRecord> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
