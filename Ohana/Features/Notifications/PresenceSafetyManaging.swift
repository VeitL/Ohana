import Foundation
import SwiftData

@MainActor
protocol PresenceSafetyManaging {
    func contacts(context: ModelContext) throws -> [SafetyContactSnapshot]
    func createContact(
        name: String,
        phoneNumber: String,
        capabilities: OhanaPlanCapabilities,
        context: ModelContext
    ) throws
    func updateContact(
        id: UUID,
        name: String,
        phoneNumber: String,
        isEnabled: Bool,
        context: ModelContext
    ) throws
    func deleteContact(id: UUID, context: ModelContext) throws
    func activateReminder(
        _ configuration: PresenceReminderConfiguration,
        capabilities: OhanaPlanCapabilities,
        title: String,
        body: String,
        notifications: UserNotificationManaging,
        scheduler: PresenceReminderScheduling,
        store: PresenceReminderConfigurationStoring
    ) async -> PresenceReminderActivationResult
    func homeSnapshot(
        context: ModelContext,
        ownerHumanId: UUID,
        now: Date
    ) throws -> PresenceHomeSnapshot
}

@MainActor
struct LivePresenceSafetyManager: PresenceSafetyManaging {
    func contacts(context: ModelContext) throws -> [SafetyContactSnapshot] {
        try SafetyContactCommandService.snapshots(context: context)
    }

    func createContact(
        name: String,
        phoneNumber: String,
        capabilities: OhanaPlanCapabilities,
        context: ModelContext
    ) throws {
        try SafetyContactCommandService.create(
            name: name,
            phoneNumber: phoneNumber,
            capabilities: capabilities,
            context: context
        )
    }

    func updateContact(
        id: UUID,
        name: String,
        phoneNumber: String,
        isEnabled: Bool,
        context: ModelContext
    ) throws {
        try SafetyContactCommandService.update(
            id: id,
            name: name,
            phoneNumber: phoneNumber,
            isEnabled: isEnabled,
            context: context
        )
    }

    func deleteContact(id: UUID, context: ModelContext) throws {
        try SafetyContactCommandService.delete(id: id, context: context) // derived-state: allow delegated device-local contact deletion
    }

    func activateReminder(
        _ configuration: PresenceReminderConfiguration,
        capabilities: OhanaPlanCapabilities,
        title: String,
        body: String,
        notifications: UserNotificationManaging,
        scheduler: PresenceReminderScheduling,
        store: PresenceReminderConfigurationStoring
    ) async -> PresenceReminderActivationResult {
        await PresenceReminderActivationCoordinator.applyAfterUserRequest(
            configuration,
            capabilities: capabilities,
            title: title,
            body: body,
            notifications: notifications,
            scheduler: scheduler,
            store: store
        )
    }

    func homeSnapshot(
        context: ModelContext,
        ownerHumanId: UUID,
        now: Date
    ) throws -> PresenceHomeSnapshot {
        try PresenceCheckInReadService.homeSnapshot(
            context: context,
            ownerHumanId: ownerHumanId,
            now: now
        )
    }
}
