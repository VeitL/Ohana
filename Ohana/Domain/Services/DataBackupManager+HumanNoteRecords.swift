//
//  DataBackupManager+HumanNoteRecords.swift
//  Ohana
//
//  Backup projection for structured Human note attribution.
//

import SwiftData

nonisolated extension DataBackupManager {
    func backupHumanHealthRecords(
        context: ModelContext,
        scope: DataBackupExportScope
    ) throws -> (reports: [HumanHealthReport], noteRecords: [HumanNoteRecordBackup]) {
        guard !scope.excludesHumanHealthData else { return ([], []) }
        return (
            reports: try context.fetch(FetchDescriptor<HumanHealthReport>()),
            noteRecords: try backupHumanNoteRecords(context: context, scope: scope)
        )
    }

    func backupHumanNoteRecords(
        context: ModelContext,
        scope: DataBackupExportScope
    ) throws -> [HumanNoteRecordBackup] {
        guard !scope.excludesHumanHealthData else { return [] }
        return try context.fetch(FetchDescriptor<HumanNoteRecord>()).map(encodeHumanNoteRecord)
    }

    func restoreHumanNoteRecords(
        _ records: [HumanNoteRecordBackup],
        context: ModelContext
    ) throws {
        for record in records {
            try DomainHumanNoteRecordRehydrateWriter.insertIfNeeded(
                snapshot: decodeHumanNoteRecordSnapshot(record),
                context: context
            )
        }
    }

    func restoreHumanNoteRecordsAfterMemberScheduleBoundary(
        _ backup: OhanaBackup,
        context: ModelContext,
        boundary: (DataBackupRestorePhase) throws -> Void
    ) throws {
        try boundary(.membersAndSchedulesPrepared)
        try restoreHumanNoteRecords(backup.humanNoteRecords ?? [], context: context)
    }
}
