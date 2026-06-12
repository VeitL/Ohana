import Foundation

struct SharedCareNoteMetadataGood {
    func writesVisibleNote(session: SharedCareSession) {
        let visibleNote = SharedCareMetadata.userNoteForStorage("Dinner together")
        session.note = visibleNote
        save(note: visibleNote)
    }

    func readsLegacyNoteForDisplay(note: String) -> String {
        SharedCareMetadata.visibleNote(note)
    }

    private func save(note _: String) {}
}
