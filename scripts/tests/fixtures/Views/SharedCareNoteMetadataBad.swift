import Foundation

struct SharedCareNoteMetadataBad {
    func writesLegacyHelper(id: UUID) {
        let note = SharedCareMetadata.legacyEncodedNote(
            prefix: SharedCareMetadata.feedNotePrefix,
            sessionId: id,
            stockTotalGrams: 120,
            isStockOwner: true,
            targetCount: 2
        )
        save(note: note)
    }

    func writesRawPrefix(id: UUID) {
        let log = PetCareLog(note: "ohana_shared_feed:\(id.uuidString) stockTotal=120 stockOwner=1")
        log.note = SharedCareMetadata.feedNotePrefix + id.uuidString
    }

    private func save(note _: String) {}
}
