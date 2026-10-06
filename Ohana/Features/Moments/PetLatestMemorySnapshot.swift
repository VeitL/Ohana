import Foundation
import SwiftData

nonisolated struct PetLatestMemorySnapshot: Equatable, Sendable {
    let reference: PetRecordReference
    let date: Date
    let title: String

    static func load(petID: UUID, context: ModelContext) -> Self? {
        var photos = FetchDescriptor<PetPhotoLog>(
            predicate: #Predicate { $0.pet?.id == petID },
            sortBy: [SortDescriptor(\PetPhotoLog.date, order: .reverse)]
        )
        photos.fetchLimit = 1
        var milestones = FetchDescriptor<PetMilestone>(
            predicate: #Predicate { $0.pet?.id == petID },
            sortBy: [SortDescriptor(\PetMilestone.date, order: .reverse)]
        )
        milestones.fetchLimit = 1
        do {
            let photo = try context.fetch(photos).first.map {
                Self(reference: PetRecordReference(petID: petID, recordID: $0.id, filter: .memories), date: $0.date, title: $0.note)
            }
            let milestone = try context.fetch(milestones).first.map {
                Self(reference: PetRecordReference(petID: petID, recordID: $0.id, filter: .memories), date: $0.date, title: $0.title)
            }
            return [photo, milestone].compactMap { $0 }.max { $0.date < $1.date }
        } catch {
            OhanaLog.warning("Pet latest memory read failed: \(error.localizedDescription)", category: "Moments")
            return nil
        }
    }
}
