import SwiftData

struct DerivedStateLifecycleGoodService {
    func purgeExpiredPet(pet: Pet, context: ModelContext) {
        CloudSyncMutationRecorder.recordDeletion(
            modelName: "Pet",
            modelId: pet.id.uuidString,
            context: context
        )
        context.delete(pet)
    }

    func restorePet(reminders: [Reminder], context: ModelContext, scheduler: ReminderSchedulingManaging) async {
        await scheduler.scheduleManyIfNeeded(reminders: reminders, context: context, source: .restore)
    }
}
