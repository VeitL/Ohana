import SwiftData

struct DerivedStateLifecycleGoodService {
    func deletePet(pet: Pet, child: PetCareLog, context: ModelContext) {
        CloudSyncMutationRecorder.markDeleted(child, pet: pet, context: context)
        context.delete(child)
        CloudSyncMutationRecorder.markDeleted(pet, context: context)
        context.delete(pet)
    }
}
