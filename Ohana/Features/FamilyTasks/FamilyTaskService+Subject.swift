import Foundation
import SwiftData

extension FamilyTaskService {
    struct FamilyTaskSubject {
        let kind: FamilyCollaborationTaskSubjectKind
        let subjectId: String?
        let relatedPetId: String?
        let ledgerSubjectKind: CareLedgerSubjectKind
        let ledgerSubjectId: String?

        static let household = FamilyTaskSubject(
            kind: .household,
            subjectId: nil,
            relatedPetId: nil,
            ledgerSubjectKind: .household,
            ledgerSubjectId: nil
        )
    }

    static func householdTaskSubjectRequest(assigneeId: String?) -> DomainSubjectResolutionRequest {
        DomainSubjectResolutionRequest(assigneeId: assigneeId)
    }

    @MainActor
    static func taskSubjectRequest(
        for reminder: Reminder,
        assigneeId: String?,
        context _: ModelContext
    ) -> DomainSubjectResolutionRequest {
        guard let event = reminder.event else {
            return householdTaskSubjectRequest(assigneeId: assigneeId)
        }
        return DomainSubjectResolutionRequest(
            link: DomainEntityLink(event: event),
            assigneeId: assigneeId
        )
    }

    @MainActor
    static func taskSubjectRequest(
        for task: FamilyCollaborationTask,
        assigneeId: String? = nil,
        context: ModelContext
    ) -> DomainSubjectResolutionRequest {
        if let reminder = reminder(for: task, context: context) {
            return taskSubjectRequest(
                for: reminder,
                assigneeId: assigneeId ?? task.assignedToId ?? task.claimedById ?? task.createdById,
                context: context
            )
        }
        let subject = taskSubject(for: task, context: context)
        let resolvedAssigneeId = assigneeId ?? task.assignedToId ?? task.claimedById ?? task.createdById
        switch subject.kind {
        case .household:
            return householdTaskSubjectRequest(assigneeId: resolvedAssigneeId)
        case .human:
            return DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: subject.subjectId ?? "",
                assigneeId: resolvedAssigneeId
            )
        case .pet:
            return DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: subject.subjectId ?? "",
                assigneeId: resolvedAssigneeId
            )
        case .plant:
            guard subject.subjectId != nil else {
                return DomainSubjectResolutionRequest(
                    relatedEntityType: "invalid-family-task-subject",
                    assigneeId: resolvedAssigneeId
                )
            }
            return DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.plant.rawValue,
                relatedEntityId: subject.subjectId ?? "",
                assigneeId: resolvedAssigneeId
            )
        }
    }

    static func canWriteCollaboration(for human: Human?) -> Bool {
        guard let human else { return true }
        return MemberLifecycleGate.disposition(human: human, writeKind: .collaboration).allowsDerivedEffects
    }

    @MainActor
    static func canWriteCollaboration(forHumanId humanId: String?, context: ModelContext) -> Bool {
        guard let humanId, !humanId.isEmpty else { return true }
        guard let uuid = UUID(uuidString: humanId),
              let human = humans(context: context).first(where: { $0.id == uuid }) else {
            return false
        }
        return canWriteCollaboration(for: human)
    }

    static func canWriteCollaboration(for pet: Pet) -> Bool {
        MemberLifecycleGate.disposition(pet: pet, writeKind: .collaboration).allowsDerivedEffects
    }

    @MainActor
    static func canWriteSubject(for task: FamilyCollaborationTask, context: ModelContext) -> Bool {
        let subject = taskSubject(for: task, context: context)
        switch subject.kind {
        case .household:
            return true
        case .human:
            guard let subjectId = subject.subjectId,
                  let uuid = UUID(uuidString: subjectId),
                  let human = humans(context: context).first(where: { $0.id == uuid }) else {
                return false
            }
            return canWriteCollaboration(for: human)
        case .pet:
            guard let subjectId = subject.subjectId,
                  let pet = pet(idRaw: subjectId, context: context) else {
                return false
            }
            return canWriteCollaboration(for: pet)
        case .plant:
            guard PlantFeatureGate.allows(.plants),
                  let subjectId = subject.subjectId,
                  let uuid = UUID(uuidString: subjectId),
                  let plant = plants(context: context).first(where: { $0.id == uuid }) else {
                return false
            }
            return !plant.isArchived
        }
    }

    @MainActor
    static func reminderTargetsWritableMember(_ reminder: Reminder, context: ModelContext) -> Bool {
        let activePets = pets(context: context).filter(canWriteCollaboration)
        let activeHumans = humans(context: context).filter(canWriteCollaboration)
        let humanMedications = humanMedications(context: context)
        return MemberLifecycleActiveScheduleResolver.reminderTargetsActiveMember(
            reminder,
            activePets: activePets,
            activeHumans: activeHumans,
            humanMedications: humanMedications
        )
    }

    @MainActor
    static func pets(context: ModelContext) -> [Pet] {
        fetchOrLog(FetchDescriptor<Pet>(), context: context, operation: "fetch pets for family task lifecycle gate")
    }

    @MainActor
    static func humans(context: ModelContext) -> [Human] {
        fetchOrLog(FetchDescriptor<Human>(), context: context, operation: "fetch humans for family task lifecycle gate")
    }

    @MainActor
    static func plants(context: ModelContext) -> [Plant] {
        fetchOrLog(FetchDescriptor<Plant>(), context: context, operation: "fetch plants for family task lifecycle gate")
    }

    @MainActor
    static func humanMedications(context: ModelContext) -> [HumanMedication] {
        fetchOrLog(FetchDescriptor<HumanMedication>(), context: context, operation: "fetch human medications for family task lifecycle gate")
    }

    @MainActor
    static func pet(idRaw: String, context: ModelContext) -> Pet? {
        let petIdRaw = idRaw.split(separator: ":").first.map(String.init) ?? idRaw
        guard let uuid = UUID(uuidString: petIdRaw) else { return nil }
        return pets(context: context).first { $0.id == uuid }
    }

    @MainActor
    static func taskSubject(for reminder: Reminder, context: ModelContext) -> FamilyTaskSubject {
        guard let event = reminder.event else { return .household }
        let resolution = DomainSubjectResolver.resolve(
            request: DomainSubjectResolutionRequest(event: event),
            context: context
        )
        return taskSubject(from: resolution)
    }

    @MainActor
    static func taskSubject(for task: FamilyCollaborationTask, context: ModelContext) -> FamilyTaskSubject {
        if FamilyCollaborationTaskSubjectKind(rawValue: task.subjectKindRaw) != nil {
            return storedTaskSubject(for: task)
        }
        if let reminder = reminder(for: task, context: context) {
            return taskSubject(for: reminder, context: context)
        }
        return storedTaskSubject(for: task)
    }

    private static func storedTaskSubject(for task: FamilyCollaborationTask) -> FamilyTaskSubject {
        let subjectId = task.resolvedSubjectId
        switch task.subjectKind {
        case .household:
            return .household
        case .human:
            return FamilyTaskSubject(
                kind: .human,
                subjectId: subjectId,
                relatedPetId: nil,
                ledgerSubjectKind: .human,
                ledgerSubjectId: subjectId
            )
        case .pet:
            return FamilyTaskSubject(
                kind: .pet,
                subjectId: subjectId,
                relatedPetId: subjectId,
                ledgerSubjectKind: .pet,
                ledgerSubjectId: subjectId
            )
        case .plant:
            return FamilyTaskSubject(
                kind: .plant,
                subjectId: subjectId,
                relatedPetId: nil,
                ledgerSubjectKind: .plant,
                ledgerSubjectId: subjectId
            )
        }
    }

    static func taskSubject(from resolution: DomainSubjectResolution) -> FamilyTaskSubject {
        switch resolution.owner {
        case let .pet(petId):
            return FamilyTaskSubject(
                kind: .pet,
                subjectId: petId.uuidString,
                relatedPetId: petId.uuidString,
                ledgerSubjectKind: .pet,
                ledgerSubjectId: petId.uuidString
            )
        case let .human(humanId):
            return FamilyTaskSubject(
                kind: .human,
                subjectId: humanId.uuidString,
                relatedPetId: nil,
                ledgerSubjectKind: .human,
                ledgerSubjectId: humanId.uuidString
            )
        case nil where resolution.role.isPetScoped:
            let petId = normalizedPetId(resolution.link.trimmedId)
            return FamilyTaskSubject(
                kind: .pet,
                subjectId: petId,
                relatedPetId: petId,
                ledgerSubjectKind: .pet,
                ledgerSubjectId: petId
            )
        case nil where resolution.role.isHumanScoped:
            let humanId = normalizedUUIDString(resolution.link.trimmedId)
            return FamilyTaskSubject(
                kind: .human,
                subjectId: humanId,
                relatedPetId: nil,
                ledgerSubjectKind: .human,
                ledgerSubjectId: humanId
            )
        case nil where resolution.role.isPlantScoped:
            let plantId = normalizedUUIDString(resolution.link.trimmedId)
            return FamilyTaskSubject(
                kind: .plant,
                subjectId: plantId,
                relatedPetId: nil,
                ledgerSubjectKind: .plant,
                ledgerSubjectId: plantId
            )
        case nil:
            return .household
        }
    }

    static func normalizedPetId(_ raw: String?) -> String? {
        guard let raw,
              let petId = DomainEntityLinkRegistry.petIdFromCompoundStockId(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return petId.uuidString
    }

    static func normalizedUUIDString(_ raw: String) -> String? {
        UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))?.uuidString
    }

    @MainActor
    static func reminder(for task: FamilyCollaborationTask, context: ModelContext) -> Reminder? {
        guard let id = task.relatedReminderId, let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return fetchOrLog(
            descriptor,
            context: context,
            operation: "fetch related reminder for family task"
        ).first
    }
}
