import SwiftData

/// Read-only route boundary for loading an editable care record.
enum PlantCareHistorySnapshotReader {
    static func load(
        recordID: PlantCareHistoryRecordID,
        context: ModelContext
    ) throws -> PlantCareHistoryRecordSnapshot {
        try PlantCareHistoryCommandService.snapshot(recordID: recordID, context: context)
    }
}
