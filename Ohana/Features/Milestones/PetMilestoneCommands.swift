//
//  PetMilestoneCommands.swift
//  Ohana
//
//  Pet milestone write boundary and revision publishing.
//

import Foundation
import SwiftData

@MainActor
private func fetchPetMilestoneModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "PetMilestoneCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

struct PetMilestoneCommandInput: Equatable {
    let date: Date
    let title: String
    let emoji: String
    let notes: String
    let photoData: Data?
    let location: String
}

struct PetMilestoneCommandResult: Equatable {
    let petID: UUID
    let milestoneIDs: [UUID]
    let coconutDelta: Int
}

struct PetMilestoneDeleteCommandResult: Equatable {
    let petID: UUID
    let milestoneID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum PetMilestoneCommandError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                return "里程碑保存失败：\(reason)"
            }
            return "里程碑保存失败，请稍后重试。"
        }
    }
}

enum PetMilestoneCommandService {
    @discardableResult
    @MainActor
    static func seedSystemMilestones(
        for pet: Pet,
        context: ModelContext
    ) throws -> PetMilestoneCommandResult {
        var existingTitles = Set(pet.milestones.map(\.title))
        var created: [PetMilestone] = []

        func appendIfNeeded(date: Date?, title: String, emoji: String, notes: String) {
            guard let date, !existingTitles.contains(title) else { return }
            guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
                pet: pet,
                occurredAt: date,
                writeKind: .memorial,
                context: context,
                logPrefix: "PetMilestoneCommandService.seedSystemMilestones"
            ) else { return }
            let milestone = DomainMemberFactWriter.createPetMilestone(
                plan: write,
                date: date,
                title: title,
                emoji: emoji,
                notes: notes,
                pet: pet,
                context: context
            )
            existingTitles.insert(title)
            created.append(milestone)
        }

        appendIfNeeded(
            date: pet.birthday,
            title: L10n.current.tr(
                zh: "\(pet.name)的生日 🎂",
                en: "\(pet.name)'s birthday 🎂",
                de: "\(pet.name) hat Geburtstag 🎂"
            ),
            emoji: "🎂",
            notes: L10n.current.tr(zh: "出生啦！", en: "Born today!", de: "Geboren!")
        )
        appendIfNeeded(
            date: pet.homeDate,
            title: L10n.current.tr(
                zh: "\(pet.name)到家了 🏠",
                en: "\(pet.name)'s gotcha day 🏠",
                de: "\(pet.name)s Einzugstag 🏠"
            ),
            emoji: "🏠",
            notes: L10n.current.tr(zh: "第一天回家!", en: "First day home!", de: "Erster Tag zuhause!")
        )
        if let heaviest = pet.weightLogs.max(by: { $0.weight < $1.weight }) {
            let formattedWeight = String(format: "%.1f", heaviest.weight)
            appendIfNeeded(
                date: heaviest.date,
                title: L10n.current.tr(
                    zh: "最重记录：\(formattedWeight)kg",
                    en: "Highest weight: \(formattedWeight) kg",
                    de: "Hoechstgewicht: \(formattedWeight) kg"
                ),
                emoji: "⚖️",
                notes: L10n.current.tr(
                    zh: "历史最高体重记录",
                    en: "Highest weight on record",
                    de: "Hoechstes gespeichertes Gewicht"
                )
            )
        }

        if !created.isEmpty {
            try saveMilestoneChanges(context: context)
        }
        return PetMilestoneCommandResult(
            petID: pet.id,
            milestoneIDs: created.map(\.id),
            coconutDelta: 0
        )
    }

    @discardableResult
    @MainActor
    static func createMilestone(
        input: PetMilestoneCommandInput,
        pet: Pet,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil
    ) throws -> PetMilestoneCommandResult {
        let questManager = providedQuestManager ?? QuestManager()
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return PetMilestoneCommandResult(petID: pet.id, milestoneIDs: [], coconutDelta: 0)
        }
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: input.date,
            writeKind: .memorial,
            context: context,
            logPrefix: "PetMilestoneCommandService.createMilestone"
        ) else {
            return PetMilestoneCommandResult(petID: pet.id, milestoneIDs: [], coconutDelta: 0)
        }

        let milestone = DomainMemberFactWriter.createPetMilestone(
            plan: write,
            date: input.date,
            title: title,
            emoji: input.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🎉" : input.emoji,
            notes: input.notes,
            pet: pet,
            photoData: input.photoData,
            location: input.location,
            context: context
        )
        try saveMilestoneChanges(context: context)

        guard write.allowsDerivedEffects else {
            return PetMilestoneCommandResult(
                petID: pet.id,
                milestoneIDs: [milestone.id],
                coconutDelta: 0
            )
        }

        let rewardHuman = EconomyRewardOwnerResolver.rewardHuman(
            executorId: nil,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            context: context,
            logPrefix: "PetMilestoneCommandService"
        )
        let executorId = rewardHuman?.id.uuidString
        var coconutDelta = 0
        DomainMemberFactEffectsDispatcher.run(plan: write) { _ in
            let reward = EconomyRewardDiscipline.awardNonCareReward(
                type: .milestone,
                pet: pet,
                context: context,
                executorId: executorId,
                questManager: questManager
            )
            coconutDelta = max(0, reward.humanGot + reward.petGot)
        }

        return PetMilestoneCommandResult(
            petID: pet.id,
            milestoneIDs: [milestone.id],
            coconutDelta: coconutDelta
        )
    }

    @discardableResult
    @MainActor
    static func deleteMilestone(
        _ milestone: PetMilestone,
        pet: Pet,
        context: ModelContext
    ) throws -> PetMilestoneDeleteCommandResult {
        guard MemberWritePolicy.disposition(pet: pet, intent: .memorialContent).writesContent else {
            return PetMilestoneDeleteCommandResult(petID: pet.id, milestoneID: milestone.id, removedLedgerEventIDs: [])
        }
        let milestoneID = milestone.id
        let removedLedgerEventIDs = ledgerEvents(for: milestone, context: context).map(\.id)
        PhysicalDeletionService.deletePetScopedRecord(milestone, pet: pet, context: context)
        try saveMilestoneChanges(context: context)
        return PetMilestoneDeleteCommandResult(
            petID: pet.id,
            milestoneID: milestoneID,
            removedLedgerEventIDs: removedLedgerEventIDs
        )
    }

    @MainActor
    private static func saveMilestoneChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw PetMilestoneCommandError.persistenceFailed(saveResult.errorDescription)
        }
    }

    @MainActor
    private static func ledgerEvents(
        for milestone: PetMilestone,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = milestone.id.uuidString
        let modelName = "PetMilestone"
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == modelName && event.legacyModelId == idString
            }
        )
        return fetchPetMilestoneModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch milestone ledger events"
        )
    }
}

@MainActor
struct PetMilestoneCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing

    init(context: ModelContext) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher())
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(context: context, revisions: SharedDomainRevisionPublisher(center: revisionCenter))
    }

    init(context: ModelContext, services: AppServices) {
        self.init(context: context, revisions: services.domainRevisions)
    }

    init(context: ModelContext, revisions: DomainRevisionPublishing) {
        self.context = context
        self.revisions = revisions
    }

    @discardableResult
    func seedSystemMilestones(for pet: Pet, note: String) throws -> PetMilestoneCommandResult {
        let result = try PetMilestoneCommandService.seedSystemMilestones(for: pet, context: context)
        revisions.publishPetMilestoneSeed(result, note: note)
        return result
    }

    @discardableResult
    func createMilestone(
        input: PetMilestoneCommandInput,
        pet: Pet,
        note: String
    ) throws -> PetMilestoneCommandResult {
        let result = try PetMilestoneCommandService.createMilestone(input: input, pet: pet, context: context)
        revisions.publishPetMilestoneRecord(result, note: note)
        return result
    }

    @discardableResult
    func deleteMilestone(
        _ milestone: PetMilestone,
        pet: Pet,
        note: String
    ) throws -> PetMilestoneDeleteCommandResult {
        let result = try PetMilestoneCommandService.deleteMilestone(milestone, pet: pet, context: context)
        revisions.publishPetMilestoneDelete(result, note: note)
        return result
    }
}
