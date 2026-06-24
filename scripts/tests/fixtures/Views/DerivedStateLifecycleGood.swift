import SwiftData

struct DerivedStateLifecycleGoodService {
    func deletePet(pet: Pet, child: PetCareLog, context: ModelContext) {
        CloudSyncMutationRecorder.markDeleted(child, pet: pet, context: context)
        context.delete(child)
        CloudSyncMutationRecorder.markDeleted(pet, context: context)
        context.delete(pet)
    }
}

struct DerivedStateLifecycleDelegatingFamilyTaskCommand {
    let familyTasks: FamilyTaskManaging

    func deleteTask(_ task: FamilyCollaborationTask, modelContext: ModelContext) {
        familyTasks.delete(task, context: modelContext)
    }
}

struct DerivedStateLifecycleDelegatingFamilyTaskManager {
    func deleteTask(_ task: FamilyCollaborationTask, context: ModelContext) {
        FamilyTaskService.delete(task, context: context)
    }
}

struct DerivedStateLifecycleDelegatingCommandExecutorView {
    let modelContext: ModelContext
    let appServices: AppServices

    func deleteHygieneLog(_ log: PetHygieneLog, pet: Pet) {
        PetHygieneCommandExecutor(context: modelContext, services: appServices).delete(
            log,
            pet: pet,
            note: "fixture.delegated.delete"
        )
    }
}

enum DerivedStateLifecycleCommandCase {
    case delete(taskID: Int)

    var affectedID: Int {
        switch self {
        case let .delete(taskID):
            return taskID
        }
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
