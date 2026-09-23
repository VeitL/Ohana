import Foundation
import SwiftData

@MainActor
struct PlantCreationCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let personalAccessLevel: PersonalAccessLevel

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            personalAccessLevel: .personal
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            personalAccessLevel: .personal
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            personalAccessLevel: services.commerce.personalAccessLevel
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        personalAccessLevel: PersonalAccessLevel = .personal
    ) {
        self.context = context
        self.revisions = revisions
        self.personalAccessLevel = personalAccessLevel
    }

    @discardableResult
    func createPlant(
        input: PlantCreationCommandInput,
        note: String,
        scheduleNotifications: Bool = true,
        reminderScheduling providedReminderScheduling: ReminderSchedulingManaging? = nil
    ) -> PlantCreationCommandResult {
        let result = PlantCreationCommandService.createPlant(
            input: input,
            context: context,
            personalAccessLevel: personalAccessLevel,
            scheduleNotifications: scheduleNotifications,
            reminderScheduling: providedReminderScheduling
        )
        if result.didPersist {
            revisions.publishMemberCreation(result, note: note)
        }
        return result
    }
}
