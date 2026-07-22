//
//  MemberDeletionCommands.swift
//  Ohana
//
//  Domain write boundaries for member deletion.
//

import Foundation
import SwiftData

@MainActor
private func fetchMemberDeletionModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "MemberDeletionCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

struct MemberDeletionCommandResult: Equatable {
    let entityID: UUID
    let kind: String
    let removedRelatedEventIDs: [UUID]
    let removedQuickActionCount: Int
    let requiresReplacementHuman: Bool
    let requiresAccountSwitch: Bool
    let clearsActiveHumanID: Bool
    let didPersist: Bool
    let persistenceErrorDescription: String?
    let attachmentCleanup: HumanNoteAttachmentCleanupResult

    init(
        entityID: UUID,
        kind: String,
        removedRelatedEventIDs: [UUID],
        removedQuickActionCount: Int,
        requiresReplacementHuman: Bool,
        requiresAccountSwitch: Bool,
        clearsActiveHumanID: Bool,
        didPersist: Bool,
        persistenceErrorDescription: String?,
        attachmentCleanup: HumanNoteAttachmentCleanupResult = .notRequired
    ) {
        self.entityID = entityID
        self.kind = kind
        self.removedRelatedEventIDs = removedRelatedEventIDs
        self.removedQuickActionCount = removedQuickActionCount
        self.requiresReplacementHuman = requiresReplacementHuman
        self.requiresAccountSwitch = requiresAccountSwitch
        self.clearsActiveHumanID = clearsActiveHumanID
        self.didPersist = didPersist
        self.persistenceErrorDescription = persistenceErrorDescription
        self.attachmentCleanup = attachmentCleanup
    }

    var didWrite: Bool { didPersist }
}

enum MemberDeletionCommandService {
    private static let quickActionItemsKey = "quickActionItems_v2"

    @discardableResult
    @MainActor
    static func deletePet(
        _ pet: Pet,
        context: ModelContext,
        userDefaults: UserDefaults = .standard,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> MemberDeletionCommandResult {
        // member-lifecycle-gate: allow physical deletion is an explicit data-removal boundary, not an active member write.
        let now = Date()
        let petID = pet.id
        let relatedEvents = fetchPetEvents(pet, context: context)
        let quickAccessPlan = quickAccessRemovalPlan(forPetID: petID, userDefaults: userDefaults)
        let notificationCancels = DeferredNotificationCancellationScheduler(delegate: notifications)
        for event in relatedEvents {
            PhysicalDeletionService.deleteEvent(
                event,
                context: context,
                deletedAt: now,
                notifications: notificationCancels
            )
        }

        PhysicalDeletionService.deletePet(
            pet,
            context: context,
            deletedAt: now,
            notifications: notificationCancels
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return MemberDeletionCommandResult(
                entityID: petID,
                kind: EntityKind.pet.rawValue,
                removedRelatedEventIDs: [],
                removedQuickActionCount: 0,
                requiresReplacementHuman: false,
                requiresAccountSwitch: false,
                clearsActiveHumanID: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        quickAccessPlan.apply(to: userDefaults, key: quickActionItemsKey)
        notificationCancels.flush()

        return MemberDeletionCommandResult(
            entityID: petID,
            kind: EntityKind.pet.rawValue,
            removedRelatedEventIDs: relatedEvents.map(\.id),
            removedQuickActionCount: quickAccessPlan.removedCount,
            requiresReplacementHuman: false,
            requiresAccountSwitch: false,
            clearsActiveHumanID: false,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @discardableResult
    @MainActor
    static func deleteHuman(
        _ human: Human,
        activeHumanID: String,
        context: ModelContext,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current,
        attachmentStorage: HumanNoteAttachmentStorage = .live,
        saveChanges: (ModelContext) -> ModelContextSaveResult = {
            $0.safeSaveResult(publishFailureEvent: true)
        }
    ) -> MemberDeletionCommandResult {
        // member-lifecycle-gate: allow physical deletion is an explicit data-removal boundary, not an active member write.
        let humanID = human.id
        let humanIDString = humanID.uuidString
        guard !PhysicalDeletionService.hasUnsettledShopPurchaseReference(
            humanID: humanID,
            context: context
        ) else {
            return MemberDeletionCommandResult(
                entityID: humanID,
                kind: EntityKind.human.rawValue,
                removedRelatedEventIDs: [],
                removedQuickActionCount: 0,
                requiresReplacementHuman: false,
                requiresAccountSwitch: false,
                clearsActiveHumanID: false,
                didPersist: false,
                persistenceErrorDescription: "Settle or refund the pending shop purchase before deleting this member."
            )
        }
        let remainingHumanDescriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { candidate in
                candidate.id != humanID && candidate.passedAwayDate == nil
            }
        )
        let remainingHumans = fetchMemberDeletionModelsOrLog(
            remainingHumanDescriptor,
            context: context,
            operation: "fetch remaining humans for deletion"
        )
        let hasRemainingHuman = !remainingHumans.isEmpty
        let deletedCurrentHuman = activeHumanID == humanIDString
        // D17 keeps Human optional. Deleting the last Human clears local
        // identity state but must not force a replacement profile.
        let requiresReplacementHuman = false
        let requiresAccountSwitch = deletedCurrentHuman && hasRemainingHuman

        let now = Date()
        do {
            try PhysicalDeletionService.stageGuardianOwnerUnavailableIfNeeded(
                ownerHumanID: humanID,
                occurredAt: now,
                context: context
            )
        } catch {
            context.rollback()
            return MemberDeletionCommandResult(
                entityID: humanID,
                kind: EntityKind.human.rawValue,
                removedRelatedEventIDs: [],
                removedQuickActionCount: 0,
                requiresReplacementHuman: false,
                requiresAccountSwitch: false,
                clearsActiveHumanID: false,
                didPersist: false,
                persistenceErrorDescription: error.localizedDescription
            )
        }
        let relatedEvents = fetchHumanOwnedEvents(humanId: humanIDString, context: context)
        let notificationCancels = DeferredNotificationCancellationScheduler(delegate: notifications)
        for event in relatedEvents {
            PhysicalDeletionService.deleteEvent(
                event,
                context: context,
                deletedAt: now,
                deletedByHumanId: activeHumanID,
                notifications: notificationCancels
            )
        }
        PhysicalDeletionService.deleteHuman(
            human,
            context: context,
            deletedAt: now,
            deletedByHumanId: activeHumanID,
            notifications: notificationCancels
        )
        let saveResult = saveChanges(context)
        guard saveResult.didSave else {
            context.rollback()
            return MemberDeletionCommandResult(
                entityID: humanID,
                kind: EntityKind.human.rawValue,
                removedRelatedEventIDs: [],
                removedQuickActionCount: 0,
                requiresReplacementHuman: false,
                requiresAccountSwitch: false,
                clearsActiveHumanID: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        notificationCancels.flush()
        let attachmentCleanup = cleanDeletedHumanAttachments(
            humanID: humanID,
            context: context,
            storage: attachmentStorage
        )

        return MemberDeletionCommandResult(
            entityID: humanID,
            kind: EntityKind.human.rawValue,
            removedRelatedEventIDs: relatedEvents.map(\.id),
            removedQuickActionCount: 0,
            requiresReplacementHuman: requiresReplacementHuman,
            requiresAccountSwitch: requiresAccountSwitch,
            clearsActiveHumanID: deletedCurrentHuman || !hasRemainingHuman,
            didPersist: true,
            persistenceErrorDescription: nil,
            attachmentCleanup: attachmentCleanup
        )
    }

    @MainActor
    private static func cleanDeletedHumanAttachments(
        humanID: UUID,
        context: ModelContext,
        storage: HumanNoteAttachmentStorage
    ) -> HumanNoteAttachmentCleanupResult {
        do {
            let survivingHumans = try context.fetch(FetchDescriptor<Human>())
            let referencedPaths = HumanNoteAttachmentStore.referencedRelativePaths(
                in: survivingHumans.map(\.notes)
            )
            return HumanNoteAttachmentStore.deleteHumanDirectory(
                humanID: humanID,
                preservingRelativePaths: referencedPaths,
                storage: storage
            )
        } catch {
            OhanaLog.error(
                "Human note attachment reference scan failed after member deletion.",
                category: "Privacy",
                privacy: .publicText
            )
            return .pending("Local attachment references could not be verified: \(error.localizedDescription)")
        }
    }

    @discardableResult
    @MainActor
    static func deletePlant(
        _ plant: Plant,
        context: ModelContext,
        userDefaults: UserDefaults = .standard,
        notifications: ReminderNotificationScheduling = ReminderNotificationSchedulerRegistry.current
    ) -> MemberDeletionCommandResult {
        let now = Date()
        let plantID = plant.id
        let notificationCancels = DeferredNotificationCancellationScheduler(delegate: notifications)
        let deletionResult = PhysicalDeletionService.deletePlant(
            plant,
            context: context,
            deletedAt: now,
            notifications: notificationCancels
        )
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return MemberDeletionCommandResult(
                entityID: plantID,
                kind: EntityKind.plant.rawValue,
                removedRelatedEventIDs: [],
                removedQuickActionCount: 0,
                requiresReplacementHuman: false,
                requiresAccountSwitch: false,
                clearsActiveHumanID: false,
                didPersist: false,
                persistenceErrorDescription: saveResult.errorDescription
            )
        }
        notificationCancels.flush()
        PlantReminderPreferenceStore.removePlantScopedOverrides(forPlantID: plantID, defaults: userDefaults)

        return MemberDeletionCommandResult(
            entityID: plantID,
            kind: EntityKind.plant.rawValue,
            removedRelatedEventIDs: deletionResult.removedRelatedEventIDs,
            removedQuickActionCount: 0,
            requiresReplacementHuman: false,
            requiresAccountSwitch: false,
            clearsActiveHumanID: false,
            didPersist: true,
            persistenceErrorDescription: nil
        )
    }

    @MainActor
    private static func fetchPetEvents(_ pet: Pet, context: ModelContext) -> [Event] {
        fetchEvents(context: context, operation: "fetch pet-related events for deletion").filter { event in
            MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                event,
                petId: pet.id.uuidString,
                petMedications: pet.medications,
                insurances: pet.insurances
            )
        }
    }

    @MainActor
    private static func fetchHumanOwnedEvents(humanId: String, context: ModelContext) -> [Event] {
        let humanMedications = fetchMemberDeletionModelsOrLog(
            FetchDescriptor<HumanMedication>(),
            context: context,
            operation: "fetch human medications for deletion event resolution"
        ).filter { $0.humanId == humanId }

        return fetchEvents(context: context, operation: "fetch human-owned events for deletion").filter { event in
            MemberLifecycleActiveScheduleResolver.eventOwnedByHuman(
                event,
                humanId: humanId,
                humanMedications: humanMedications
            )
        }
    }

    @MainActor
    private static func fetchEvents(context: ModelContext, operation: String) -> [Event] {
        fetchMemberDeletionModelsOrLog(
            FetchDescriptor<Event>(),
            context: context,
            operation: operation
        )
    }

    private static func quickAccessRemovalPlan(forPetID petID: UUID, userDefaults: UserDefaults) -> QuickAccessRemovalPlan {
        guard let json = userDefaults.string(forKey: quickActionItemsKey),
              let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let items = object as? [[String: Any]]
        else { return QuickAccessRemovalPlan(removedCount: 0, replacementJSON: nil) }

        let petIDString = petID.uuidString
        var removedCount = 0
        let filtered = items.filter { item in
            let petId = item["petId"] as? String
            let entityId = item["entityId"] as? String
            let entityKindRaw = item["entityKindRaw"] as? String
            let shouldRemove = petId == petIDString || (entityId == petIDString && entityKindRaw == EntityKind.pet.rawValue)
            if shouldRemove {
                removedCount += 1
            }
            return !shouldRemove
        }

        guard removedCount > 0,
              let newData = try? JSONSerialization.data(withJSONObject: filtered, options: []),
              let newJSON = String(data: newData, encoding: .utf8)
        else { return QuickAccessRemovalPlan(removedCount: removedCount, replacementJSON: nil) }
        return QuickAccessRemovalPlan(removedCount: removedCount, replacementJSON: newJSON)
    }
}

private struct QuickAccessRemovalPlan {
    let removedCount: Int
    let replacementJSON: String?

    func apply(to userDefaults: UserDefaults, key: String) {
        guard let replacementJSON else { return }
        userDefaults.set(replacementJSON, forKey: key)
    }
}

private final class DeferredNotificationCancellationScheduler: ReminderNotificationScheduling, @unchecked Sendable {
    private let scheduler: ReminderNotificationScheduling
    private var pendingCancelIds: [String] = []

    init(delegate: ReminderNotificationScheduling) {
        scheduler = delegate
    }

    func schedule(reminder: Reminder) {
        scheduler.schedule(reminder: reminder)
    }

    func schedule(
        reminder: Reminder,
        existingNotificationIds: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        scheduler.schedule(reminder: reminder, existingNotificationIds: existingNotificationIds, completion: completion)
    }

    func schedule(
        reminder: Reminder,
        deliveryDate: Date?,
        existingNotificationIds: Set<String>?,
        completion: ((ReminderNotificationScheduleResult) -> Void)?
    ) {
        scheduler.schedule(
            reminder: reminder,
            deliveryDate: deliveryDate,
            existingNotificationIds: existingNotificationIds,
            completion: completion
        )
    }

    func pendingNotificationIds() async -> Set<String> {
        await scheduler.pendingNotificationIds()
    }

    func scheduleRollingWindow(reminders: [Reminder]) {
        scheduler.scheduleRollingWindow(reminders: reminders)
    }

    func refillWindowIfNeeded(allReminders: [Reminder]) {
        scheduler.refillWindowIfNeeded(allReminders: allReminders)
    }

    func cancel(notificationId: String) {
        guard !notificationId.isEmpty else { return }
        pendingCancelIds.append(notificationId)
    }

    func cancelAll(for pet: Pet, reminders: [Reminder]) {
        for reminder in reminders {
            cancel(notificationId: reminder.notificationId)
        }
    }

    func compensate(reminders: [Reminder]) {
        scheduler.compensate(reminders: reminders)
    }

    func flush() {
        for notificationId in Set(pendingCancelIds) {
            scheduler.cancel(notificationId: notificationId)
        }
        pendingCancelIds.removeAll()
    }
}
