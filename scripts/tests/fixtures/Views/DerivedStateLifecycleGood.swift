import SwiftData

struct DerivedStateLifecycleGoodService {
    func deletePet(pet: Pet, child: PetCareLog, context: ModelContext) {
        CloudSyncMutationRecorder.markDeleted(child, pet: pet, context: context)
        context.delete(child)
        CloudSyncMutationRecorder.markDeleted(pet, context: context)
        context.delete(pet)
    }
}

enum DerivedStateLifecycleGoodRegistry {
    static let uploadPipelineEntityNames: Set<String> = [
        String(describing: Household.self),
        String(describing: SyncedThing.self)
    ]

    static let physicalDeletionOwnerships = [
        deletionOwnership(PetCareLog.self, parent: .pet, reason: "pet relationship"),
        deletionOwnership(GachaOwnedItem.self, parent: .human, reason: "ownerHumanId")
    ]
}

enum PhysicalDeletionService {
    private static let petDeletionCascadeCoverageEntityNames: Set<String> = [
        String(describing: PetCareLog.self)
    ]

    private static let humanDeletionCascadeCoverageEntityNames: Set<String> = [
        String(describing: GachaOwnedItem.self)
    ]
}

enum CloudSyncUploadBatchBuilder {
    static func localModel(entityName: String) -> Any? {
        switch entityName {
        case String(describing: Household.self):
            return Household()
        case String(describing: SyncedThing.self):
            return SyncedThing()
        default:
            return nil
        }
    }
}
