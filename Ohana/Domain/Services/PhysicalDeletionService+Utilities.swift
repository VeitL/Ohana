//
//  PhysicalDeletionService+Utilities.swift
//  Ohana
//
//  Shared helpers for irreversible local deletion boundaries.
//

import Foundation
import SwiftData

extension PhysicalDeletionService {
    nonisolated static func stageGuardianOwnerUnavailableIfNeeded(
        ownerHumanID: UUID,
        occurredAt: Date,
        context: ModelContext
    ) throws {
        let policyKey = GuardianSafetyPolicyProjection.key(ownerHumanId: ownerHumanID)
        var policyDescriptor = FetchDescriptor<GuardianSafetyPolicyProjection>(
            predicate: #Predicate { $0.policyKey == policyKey && $0.isEnabled }
        )
        policyDescriptor.fetchLimit = 1
        guard let policy = try context.fetch(policyDescriptor).first,
              policy.serverPolicyId != nil,
              policy.status != .stopped
        else { return }

        let revision = policy.scheduleRevision + 1
        let eventKey = "guardian-safety:stop:\(ownerHumanID.uuidString.lowercased()):\(revision)"
        var eventDescriptor = FetchDescriptor<GuardianSafetySyncOutbox>(
            predicate: #Predicate { $0.eventKey == eventKey }
        )
        eventDescriptor.fetchLimit = 1
        if try context.fetch(eventDescriptor).isEmpty {
            context.insert(GuardianSafetySyncOutbox(
                eventKey: eventKey,
                eventKind: .monitoringStopped,
                ownerHumanId: ownerHumanID,
                occurredAt: occurredAt,
                timeZoneIdentifier: TimeZone.current.identifier,
                stopReason: .ownerUnavailable
            ))
        }
        policy.isEnabled = false
        policy.status = .stopped
        policy.scheduleRevision = revision
        policy.pauseUntil = nil
        policy.updatedAt = occurredAt
    }

    @discardableResult
    nonisolated static func deleteGuardianSafetyProjections(
        ownerHumanID: UUID,
        context: ModelContext
    ) -> Int {
        let ownerID = ownerHumanID.uuidString
        let policies = fetchAll(GuardianSafetyPolicyProjection.self, context: context).filter {
            idsMatch($0.ownerHumanIdRaw, ownerID)
        }
        let relationships = fetchAll(GuardianRelationshipProjection.self, context: context).filter {
            idsMatch($0.ownerHumanIdRaw, ownerID)
        }
        let incidents = fetchAll(GuardianIncidentProjection.self, context: context).filter {
            idsMatch($0.ownerHumanIdRaw, ownerID)
        }
        for value in policies {
            context.delete(value)
        }
        for value in relationships {
            context.delete(value)
        }
        for value in incidents {
            context.delete(value)
        }

        // Keep the minimal outbox, including the stop signal, until the
        // authenticated API accepts it. It contains no name or profile data.
        return policies.count + relationships.count + incidents.count
    }

    @discardableResult
    nonisolated static func deleteEvents(
        _ events: [Event],
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let uniqueEvents = unique(events, by: \.id)
        for event in uniqueEvents {
            _ = deleteEvent(
                event,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId,
                notifications: notifications
            )
        }
        return uniqueEvents.count
    }

    @discardableResult
    nonisolated static func deletePetRelationships(
        petId: UUID,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        let petIdString = petId.uuidString
        return deleteRows(fetchAll(PetRelationship.self, context: context).filter { relationship in
            relationship.fromPetId == petId || relationship.toPetId == petId
        }, context: context) {
            markGenericDeleted(
                entityName: String(describing: PetRelationship.self),
                localRecordId: $0.id,
                parentId: petIdString,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
    }

    @discardableResult
    nonisolated static func deleteFamilyTasksReferencingPet(
        petId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let allTasks = fetchAll(FamilyCollaborationTask.self, context: context)
        let directlyMatchingTasks = allTasks.filter { task in
            (task.subjectKind == .pet && idsMatch(task.resolvedSubjectId, petId)) ||
                idsMatch(task.relatedPetId, petId)
        }
        let directlyMatchingPlans = fetchAll(FamilyTaskPlan.self, context: context).filter {
            $0.subjectKind == .pet && idsMatch($0.subjectId, petId)
        }
        return deleteFamilyTaskGraph(
            directlyMatchingTasks: directlyMatchingTasks,
            directlyMatchingPlans: directlyMatchingPlans,
            directlyMatchingActivities: [],
            parentId: petId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
    }

    @discardableResult
    nonisolated static func deleteFamilyTasksReferencingPlant(
        plantId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let directlyMatchingTasks = fetchAll(FamilyCollaborationTask.self, context: context).filter { task in
            task.subjectKind == .plant && idsMatch(task.resolvedSubjectId, plantId)
        }
        let directlyMatchingPlans = fetchAll(FamilyTaskPlan.self, context: context).filter {
            $0.subjectKind == .plant && idsMatch($0.subjectId, plantId)
        }
        return deleteFamilyTaskGraph(
            directlyMatchingTasks: directlyMatchingTasks,
            directlyMatchingPlans: directlyMatchingPlans,
            directlyMatchingActivities: [],
            parentId: plantId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
    }

    @discardableResult
    nonisolated static func deleteFamilyTaskPlansAndActivitiesReferencingHuman(
        humanId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let directlyMatchingPlans = fetchAll(FamilyTaskPlan.self, context: context).filter { plan in
            idsMatch(plan.createdById, humanId) ||
                idsMatch(plan.assignedToId, humanId) ||
                (plan.subjectKind == .human && idsMatch(plan.subjectId, humanId))
        }
        let directlyMatchingTasks = fetchAll(FamilyCollaborationTask.self, context: context).filter {
            referencesHuman($0, humanId: humanId)
        }
        let directlyMatchingActivities = fetchAll(FamilyTaskActivity.self, context: context).filter { activity in
            idsMatch(activity.actorHumanId, humanId) ||
                idsMatch(activity.recipientHumanId, humanId)
        }
        return deleteFamilyTaskGraph(
            directlyMatchingTasks: directlyMatchingTasks,
            directlyMatchingPlans: directlyMatchingPlans,
            directlyMatchingActivities: directlyMatchingActivities,
            parentId: humanId,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
    }

    /// Deletes an entire V95 collaboration graph once any plan or occurrence
    /// references a physically removed member. A series edit may change the
    /// plan's current subject while historical occurrences retain their old
    /// subject, so plan identity—not the latest subject snapshot—owns the
    /// cascade boundary.
    @discardableResult
    private nonisolated static func deleteFamilyTaskGraph(
        directlyMatchingTasks: [FamilyCollaborationTask],
        directlyMatchingPlans: [FamilyTaskPlan],
        directlyMatchingActivities: [FamilyTaskActivity],
        parentId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?,
        notifications: ReminderNotificationScheduling
    ) -> Int {
        let allPlans = fetchAll(FamilyTaskPlan.self, context: context)
        let planIDs = Set(
            directlyMatchingPlans.map(\.id.uuidString) +
                directlyMatchingTasks.compactMap(\.planId)
        )
        let plans = unique(
            allPlans.filter { planIDs.contains($0.id.uuidString) },
            by: \.id
        )

        let directlyMatchingTaskIDs = Set(directlyMatchingTasks.map(\.id))
        let tasks = unique(
            fetchAll(FamilyCollaborationTask.self, context: context).filter { task in
                directlyMatchingTaskIDs.contains(task.id) ||
                    (task.planId.map(planIDs.contains) ?? false)
            },
            by: \.id
        )
        let taskIDs = Set(tasks.map(\.id.uuidString))
        let directlyMatchingActivityIDs = Set(directlyMatchingActivities.map(\.id))
        let activities = unique(
            fetchAll(FamilyTaskActivity.self, context: context).filter { activity in
                directlyMatchingActivityIDs.contains(activity.id) ||
                    (activity.planId.map(planIDs.contains) ?? false) ||
                    (activity.taskId.map(taskIDs.contains) ?? false)
            },
            by: \.id
        )

        let eventIDs = Set(
            tasks.compactMap(\.relatedEventId) +
                plans.compactMap(\.sourceEventId)
        )
        let events = unique(
            fetchAll(Event.self, context: context).filter { event in
                eventIDs.contains(event.id.uuidString) ||
                    (event.familyTaskPlanId.map(planIDs.contains) ?? false)
            },
            by: \.id
        )
        let selectedEventIDs = Set(events.map(\.id))
        let eventReminderIDs = Set(events.flatMap(\.reminders).map(\.id.uuidString))
        let taskReminderIDs = Set(tasks.compactMap(\.relatedReminderId))
        let detachedReminders = unique(
            fetchAll(Reminder.self, context: context).filter { reminder in
                (taskReminderIDs.contains(reminder.id.uuidString) ||
                    (reminder.event.map { selectedEventIDs.contains($0.id) } ?? false)) &&
                    !eventReminderIDs.contains(reminder.id.uuidString)
            },
            by: \.id
        )

        let deletedEventCount = deleteEvents(
            events,
            context: context,
            deletedAt: deletedAt,
            deletedByHumanId: deletedByHumanId,
            notifications: notifications
        )
        let deletedDetachedReminderCount = detachedReminders.reduce(into: 0) { count, reminder in
            count += deleteReminder(
                reminder,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId,
                notifications: notifications
            )
        }
        for activity in activities {
            context.delete(activity)
        }
        let deletedTaskCount = deleteRows(tasks, context: context) { task in
            markGenericDeleted(
                entityName: String(describing: FamilyCollaborationTask.self),
                localRecordId: task.id,
                parentId: parentId,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }
        for plan in plans {
            context.delete(plan)
        }
        return deletedEventCount + deletedDetachedReminderCount + activities.count + deletedTaskCount + plans.count
    }

    @discardableResult
    nonisolated static func scrubSharedCareSessionsReferencingPet(
        petId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        var changedCount = 0
        for session in fetchAll(SharedCareSession.self, context: context) {
            guard idsMatch(session.sourcePetId, petId) ||
                idsMatch(session.stockOwnerPetId, petId) ||
                session.targetPetIds.contains(where: { idsMatch($0, petId) }) else {
                continue
            }

            let hadDeletedStockOwner = idsMatch(session.stockOwnerPetId, petId)
            let sessionID = session.id
            SharedCareSessionMaintenance.reconcile(session, context: context, reconciledAt: deletedAt)
            guard fetchAll(SharedCareSession.self, context: context).contains(where: { $0.id == sessionID }) else {
                changedCount += 1
                continue
            }

            let originalTargets = session.targetPetIds
            let filteredTargets = originalTargets.filter { !idsMatch($0, petId) }
            var changed = filteredTargets.count != originalTargets.count

            if idsMatch(session.sourcePetId, petId) {
                session.sourcePetId = ""
                changed = true
            }
            if hadDeletedStockOwner || idsMatch(session.stockOwnerPetId, petId) {
                session.stockOwnerPetId = ""
                changed = true
            }
            if filteredTargets.isEmpty && changed {
                CloudSyncMutationRecorder.markDeleted(
                    session,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
                context.delete(session)
                changedCount += 1
                continue
            }
            guard changed else { continue }
            session.targetPetIdsRaw = filteredTargets.joined(separator: "|")
            CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: deletedAt)
            changedCount += 1
        }
        return changedCount
    }

    @discardableResult
    nonisolated static func scrubSharedCareSessionsReferencingHuman(
        humanId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) -> Int {
        var changedCount = 0
        for session in fetchAll(SharedCareSession.self, context: context) {
            let originalExecutors = session.executorIds
            let filteredExecutors = originalExecutors.filter { !idsMatch($0, humanId) }
            guard filteredExecutors.count != originalExecutors.count else { continue }
            if filteredExecutors.isEmpty {
                changedCount += scrubSharedCareChildrenReferencingSession(
                    session,
                    deletedHumanId: humanId,
                    remainingExecutorIds: [],
                    clearsSessionLink: true,
                    context: context,
                    modifiedAt: deletedAt
                )
                CloudSyncMutationRecorder.markDeleted(
                    session,
                    context: context,
                    deletedAt: deletedAt,
                    deletedByHumanId: deletedByHumanId
                )
                context.delete(session)
                changedCount += 1
                continue
            }
            session.setExecutorIds(filteredExecutors, primaryExecutorId: filteredExecutors.first)
            changedCount += scrubSharedCareChildrenReferencingSession(
                session,
                deletedHumanId: humanId,
                remainingExecutorIds: filteredExecutors,
                clearsSessionLink: false,
                context: context,
                modifiedAt: deletedAt
            )
            CloudSyncMutationRecorder.markModified(session, context: context, modifiedAt: deletedAt)
            changedCount += 1
        }
        return changedCount
    }

    nonisolated static func referencesPet(_ event: CareLedgerEvent, petId: String) -> Bool {
        idsMatch(event.actorId, petId) || idsMatch(event.subjectId, petId)
    }

    nonisolated static func referencesHuman(_ event: CareLedgerEvent, humanId: String) -> Bool {
        idsMatch(event.actorId, humanId) || idsMatch(event.subjectId, humanId)
    }

    nonisolated static func referencesPet(_ event: EconomyBudgetUsageEvent, petId: String) -> Bool {
        idsMatch(event.careObjectKey, petId) || idsMatch(event.scopeKey, petId)
    }

    nonisolated static func referencesHuman(_ event: EconomyBudgetUsageEvent, humanId: String) -> Bool {
        idsMatch(event.memberKey, humanId) || idsMatch(event.scopeKey, humanId)
    }

    nonisolated static func referencesHuman(_ task: FamilyCollaborationTask, humanId: String) -> Bool {
        (task.subjectKind == .human && idsMatch(task.resolvedSubjectId, humanId)) ||
            idsMatch(task.createdById, humanId) ||
            idsMatch(task.assignedToId, humanId) ||
            idsMatch(task.claimedById, humanId) ||
            idsMatch(task.completedById, humanId)
    }

    nonisolated static func idsMatch(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        let left = CloudSyncRecordState.normalizedRecordId(lhs)
        let right = CloudSyncRecordState.normalizedRecordId(rhs)
        return !left.isEmpty && left == right
    }

    nonisolated static func deleteRows<T: PersistentModel>(
        _ rows: [T],
        context: ModelContext,
        markDeleted: (T) -> Void
    ) -> Int {
        for row in rows {
            markDeleted(row)
            context.delete(row)
        }
        return rows.count
    }

    struct CareLedgerDeletionContext {
        let deletedOwnerKind: CareLedgerSubjectKind?
        let deletedOwnerId: String?
        let deletedLegacyModelName: String?
        let deletedLegacyModelId: String?
        let reason: String
        let deletedAt: Date
        let deletedByHumanId: String?
    }

    @discardableResult
    nonisolated static func deleteOrRetainCareLedgerEvents(
        _ events: [CareLedgerEvent],
        context: ModelContext,
        deletionContext: (CareLedgerEvent) -> CareLedgerDeletionContext
    ) -> Int {
        let uniqueEvents = unique(events, by: \.id)
        for event in uniqueEvents {
            let contextForEvent = deletionContext(event)
            if shouldRetainEconomicCareLedger(event) {
                retainEconomicCareLedger(
                    event,
                    context: context,
                    deletionContext: contextForEvent
                )
            } else {
                CloudSyncMutationRecorder.markDeleted(
                    event,
                    context: context,
                    deletedAt: contextForEvent.deletedAt,
                    deletedByHumanId: contextForEvent.deletedByHumanId
                )
                context.delete(event)
            }
        }
        return uniqueEvents.count
    }

    private nonisolated static func shouldRetainEconomicCareLedger(_ event: CareLedgerEvent) -> Bool {
        event.coconutDelta != 0 || event.rewardLogId?.isEmpty == false
    }

    private nonisolated static func retainEconomicCareLedger(
        _ event: CareLedgerEvent,
        context: ModelContext,
        deletionContext: CareLedgerDeletionContext
    ) {
        let originalActorKind = event.actorKind
        let originalSubjectKind = event.subjectKind
        let originalLegacyModelName = event.legacyModelName
        event.note = ""

        if let deletedOwnerId = deletionContext.deletedOwnerId {
            if idsMatch(event.actorId, deletedOwnerId) {
                event.actorKind = CareLedgerActorKind.unknown.rawValue
                event.actorId = nil
            }
            if idsMatch(event.subjectId, deletedOwnerId) {
                event.subjectKind = CareLedgerSubjectKind.unknown.rawValue
                event.subjectId = nil
            }
        }

        if let deletedLegacyModelName = deletionContext.deletedLegacyModelName,
           let deletedLegacyModelId = deletionContext.deletedLegacyModelId,
           event.legacyModelName == deletedLegacyModelName,
           idsMatch(event.legacyModelId, deletedLegacyModelId) {
            event.legacyModelName = nil
            event.legacyModelId = nil
        }

        event.metadataJSON = retainedEconomicCareLedgerMetadata(
            existingMetadataJSON: event.metadataJSON,
            reason: deletionContext.reason,
            deletedOwnerKind: deletionContext.deletedOwnerKind?.rawValue,
            deletedAt: deletionContext.deletedAt,
            originalActorKind: originalActorKind,
            originalSubjectKind: originalSubjectKind,
            originalLegacyModelName: originalLegacyModelName
        )
        CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: deletionContext.deletedAt)
    }

    @discardableResult
    nonisolated static func scrubCoconutLedgerEntriesReferencingDeletedOwner(
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        subjectKind: CareLedgerSubjectKind,
        legacyModelIds: Set<String> = [],
        reason: String,
        context: ModelContext,
        modifiedAt: Date
    ) -> Int {
        let entries = fetchAll(CoconutLedgerEntry.self, context: context).filter { entry in
            idsMatch(entry.ownerId, ownerId) ||
                idsMatch(entry.actorId, ownerId) ||
                idsMatch(entry.subjectId, ownerId) ||
                legacyModelIds.containsNormalized(entry.sourceModelId)
        }
        guard !entries.isEmpty else { return 0 }

        for entry in entries {
            let originalOwnerKind = entry.ownerKindRaw
            let originalSubjectKind = entry.subjectKindRaw
            let originalSourceModelName = entry.sourceModelName

            if idsMatch(entry.ownerId, ownerId) && entry.ownerKind == ownerKind {
                entry.ownerKindRaw = CoconutWalletOwnerKind.system.rawValue
                entry.ownerId = ""
                entry.ownerName = ""
            }
            if idsMatch(entry.actorId, ownerId) {
                entry.actorId = nil
                entry.actorName = nil
            }
            if idsMatch(entry.subjectId, ownerId) {
                entry.subjectKindRaw = CareLedgerSubjectKind.unknown.rawValue
                entry.subjectId = nil
            }
            if legacyModelIds.containsNormalized(entry.sourceModelId) {
                entry.sourceModelName = ""
                entry.sourceModelId = ""
            }

            entry.metadataJSON = retainedCoconutLedgerMetadata(
                existingMetadataJSON: entry.metadataJSON,
                reason: reason,
                deletedOwnerKind: subjectKind.rawValue,
                deletedAt: modifiedAt,
                originalOwnerKind: originalOwnerKind,
                originalSubjectKind: originalSubjectKind,
                originalSourceModelName: originalSourceModelName
            )
        }

        CloudSyncMutationRecorder.markModified(entries, context: context, modifiedAt: modifiedAt)
        return entries.count
    }

    private nonisolated static func retainedEconomicCareLedgerMetadata(
        existingMetadataJSON: String,
        reason: String,
        deletedOwnerKind: String?,
        deletedAt: Date,
        originalActorKind: String,
        originalSubjectKind: String,
        originalLegacyModelName: String?
    ) -> String {
        var payload: [String: Any] = [
            "deletedOwnerRetention": true,
            "retentionReason": reason,
            "retainedAt": deletedAt.timeIntervalSince1970,
            "originalActorKind": originalActorKind,
            "originalSubjectKind": originalSubjectKind
        ]
        if let deletedOwnerKind {
            payload["deletedOwnerKind"] = deletedOwnerKind
        }
        if let originalLegacyModelName {
            payload["originalLegacyModelName"] = originalLegacyModelName
        }
        if !existingMetadataJSON.isEmpty,
           let data = existingMetadataJSON.data(using: .utf8),
           let existingPayload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["previousMetadata"] = existingPayload
        } else if !existingMetadataJSON.isEmpty {
            payload["previousMetadataRaw"] = existingMetadataJSON
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"deletedOwnerRetention\":true,\"retentionReason\":\"\(reason)\"}"
        }
        return json
    }

    private nonisolated static func retainedCoconutLedgerMetadata(
        existingMetadataJSON: String,
        reason: String,
        deletedOwnerKind: String,
        deletedAt: Date,
        originalOwnerKind: String,
        originalSubjectKind: String,
        originalSourceModelName: String
    ) -> String {
        var payload: [String: Any] = [
            "deletedOwnerRetention": true,
            "retentionReason": reason,
            "retainedAt": deletedAt.timeIntervalSince1970,
            "deletedOwnerKind": deletedOwnerKind,
            "originalOwnerKind": originalOwnerKind,
            "originalSubjectKind": originalSubjectKind,
            "originalSourceModelName": originalSourceModelName
        ]
        if !existingMetadataJSON.isEmpty,
           let data = existingMetadataJSON.data(using: .utf8),
           let existingPayload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["previousMetadata"] = existingPayload
        } else if !existingMetadataJSON.isEmpty {
            payload["previousMetadataRaw"] = existingMetadataJSON
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"deletedOwnerRetention\":true,\"retentionReason\":\"\(reason)\"}"
        }
        return json
    }

    @discardableResult
    nonisolated static func retireWalletAccounts(
        ownerKind: CoconutWalletOwnerKind,
        ownerId: String,
        context: ModelContext,
        deletedAt: Date
    ) -> Int {
        let accounts = fetchAll(CoconutAccount.self, context: context).filter { account in
            account.ownerKind == ownerKind && idsMatch(account.ownerId, ownerId)
        }
        for account in accounts {
            account.balance = 0
            account.updatedAt = deletedAt
            CoconutWalletAccountLifecycleMetadata.markDeletedOwner(account, deletedAt: deletedAt)
            CloudSyncMutationRecorder.markModified(account, context: context, modifiedAt: deletedAt)
        }
        return accounts.count
    }

    nonisolated static func markGenericDeleted(
        entityName: String,
        localRecordId: UUID,
        parentId: String,
        context: ModelContext,
        deletedAt: Date,
        deletedByHumanId: String?
    ) {
        _ = CloudSyncMutationRecorder.markDeleted(
            entityName: entityName,
            localRecordId: localRecordId,
            householdId: CloudSyncMutationRecorder.sharedHouseholdId(context: context, now: deletedAt),
            fallbackHouseholdId: CloudSyncMutationRecorder.uuid(from: parentId),
            deletedAt: deletedAt,
            deletedByHumanId: CloudSyncMutationRecorder.uuid(from: deletedByHumanId),
            context: context
        )
    }

    nonisolated static func fetchAll<T: PersistentModel>(_: T.Type, context: ModelContext) -> [T] {
        do {
            return try context.fetch(FetchDescriptor<T>())
        } catch {
            OhanaLog.warning("PhysicalDeletionService failed to fetch \(T.self): \(error.localizedDescription)", category: "Care")
            return []
        }
    }

    nonisolated static func unique<T, ID: Hashable>(_ values: [T], by keyPath: KeyPath<T, ID>) -> [T] {
        var seen: Set<ID> = []
        return values.filter { seen.insert($0[keyPath: keyPath]).inserted }
    }

    nonisolated static func reconcileWalletAfterEconomyDeletion(context: ModelContext) {
        _ = CoconutWalletService.reconcileFormalAccountBalancesWithLedger(context: context, saveChanges: false)
    }
}

extension Set<String> {
    nonisolated func containsNormalized(_ value: String?) -> Bool {
        guard let value else { return false }
        let normalizedValue = CloudSyncRecordState.normalizedRecordId(value)
        return contains { CloudSyncRecordState.normalizedRecordId($0) == normalizedValue }
    }
}
