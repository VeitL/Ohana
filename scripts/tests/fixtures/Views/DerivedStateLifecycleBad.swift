import SwiftData

struct DerivedStateLifecycleBadService {
    func deletePet(pet: Pet, context: ModelContext) {
        context.delete(pet)
    }
}

enum DerivedStateLifecycleBadRegistry {
    static let uploadPipelineEntityNames: Set<String> = [
        String(describing: Household.self),
        String(describing: MissingSyncThing.self)
    ]

    static let physicalDeletionOwnerships = [
        deletionOwnership(PetCareLog.self, parent: .pet, reason: "pet relationship"),
        deletionOwnership(LeakyOwnedThing.self, parent: .human, reason: "ownerHumanId")
    ]
}

enum PhysicalDeletionService {
    private static let petDeletionCascadeCoverageEntityNames: Set<String> = [
        String(describing: PetCareLog.self)
    ]

    private static let humanDeletionCascadeCoverageEntityNames: Set<String> = []
}

enum CloudSyncUploadBatchBuilder {
    static func localModel(entityName: String) -> Any? {
        switch entityName {
        case String(describing: Household.self):
            return Household()
        default:
            return nil
        }
    }
}
