import SwiftData

extension CalendarEventCommandService {
    @MainActor
    static func tombstoneAndDeleteEvent(_ event: Event, context: ModelContext) {
        let reminders = event.reminders
        CloudSyncMutationRecorder.markDeleted(event, context: context)
        for reminder in reminders {
            CloudSyncMutationRecorder.markDeleted(reminder, context: context)
        }
        context.delete(event)
    }
}
