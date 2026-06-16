import SwiftData

extension CalendarEventCommandService {
    @MainActor
    @discardableResult
    static func tombstoneAndDeleteEvent(_ event: Event, context: ModelContext) -> DomainScheduleDeleteResult {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .care,
            source: .userCommand,
            context: context
        ) else { return .notDeleted }
        let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context)
        DomainScheduleEffectsDispatcher.dispatch(delete: result)
        return result
    }
}
