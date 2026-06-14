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

enum PetMilestoneCommandService {
    @discardableResult
    @MainActor
    static func seedSystemMilestones(
        for pet: Pet,
        context: ModelContext
    ) -> PetMilestoneCommandResult {
        var existingTitles = Set(pet.milestones.map(\.title))
        var created: [(milestone: PetMilestone, actionType: String)] = []

        func appendIfNeeded(date: Date?, title: String, emoji: String, notes: String, actionType: String) {
            guard let date, !existingTitles.contains(title) else { return }
            let milestone = PetMilestone(date: date, title: title, emoji: emoji, notes: notes, pet: pet)
            context.insert(milestone)
            existingTitles.insert(title)
            created.append((milestone, actionType))
        }

        appendIfNeeded(
            date: pet.birthday,
            title: "\(pet.name)的生日 🎂",
            emoji: "🎂",
            notes: "出生啦！",
            actionType: "autoBirthday"
        )
        appendIfNeeded(
            date: pet.homeDate,
            title: "\(pet.name)到家了 🏠",
            emoji: "🏠",
            notes: "第一天回家!",
            actionType: "autoHomeDate"
        )
        if let heaviest = pet.weightLogs.max(by: { $0.weight < $1.weight }) {
            appendIfNeeded(
                date: heaviest.date,
                title: "最重记录：\(String(format: "%.1f", heaviest.weight))kg",
                emoji: "⚖️",
                notes: "历史最高体重记录",
                actionType: "autoHeaviestWeight"
            )
        }

        for entry in created {
            recordLedger(
                milestone: entry.milestone,
                pet: pet,
                actionType: entry.actionType,
                source: .service,
                coconutDelta: 0,
                context: context,
                save: false
            )
        }
        if !created.isEmpty {
            context.safeSave()
        }
        return PetMilestoneCommandResult(
            petID: pet.id,
            milestoneIDs: created.map(\.milestone.id),
            coconutDelta: 0
        )
    }

    @discardableResult
    @MainActor
    static func createMilestone(
        input: PetMilestoneCommandInput,
        pet: Pet,
        context: ModelContext,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> PetMilestoneCommandResult {
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger = providedCareLedger ?? CareLedgerService()
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return PetMilestoneCommandResult(petID: pet.id, milestoneIDs: [], coconutDelta: 0)
        }

        let milestone = PetMilestone(
            date: input.date,
            title: title,
            emoji: input.emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🎉" : input.emoji,
            notes: input.notes,
            pet: pet,
            photoData: input.photoData,
            location: input.location
        )
        context.insert(milestone)
        context.safeSave()

        let rewardHuman = EconomyRewardOwnerResolver.rewardHuman(
            executorId: nil,
            activeHumanSelection: UserDefaultsActiveHumanSelection(),
            context: context,
            logPrefix: "PetMilestoneCommandService"
        )
        let executorId = rewardHuman?.id.uuidString
        let reward = EconomyRewardDiscipline.awardNonCareReward(
            type: .milestone,
            pet: pet,
            context: context,
            executorId: executorId,
            questManager: questManager
        )
        let coconutDelta = max(0, reward.humanGot + reward.petGot)
        recordLedger(
            milestone: milestone,
            pet: pet,
            actionType: "manual",
            source: .detail,
            coconutDelta: coconutDelta,
            executorId: executorId,
            context: context,
            careLedger: careLedger
        )

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
    ) -> PetMilestoneDeleteCommandResult {
        let milestoneID = milestone.id
        PhysicalDeletionService.deletePetScopedRecord(milestone, pet: pet, context: context)
        context.safeSave()
        return PetMilestoneDeleteCommandResult(
            petID: pet.id,
            milestoneID: milestoneID,
            removedLedgerEventIDs: []
        )
    }

    @discardableResult
    @MainActor
    private static func recordLedger(
        milestone: PetMilestone,
        pet: Pet,
        actionType: String,
        source: CareLedgerSource,
        coconutDelta: Int,
        executorId: String? = nil,
        context: ModelContext,
        save: Bool = true,
        careLedger: CareLedgerRecording = CareLedgerService()
    ) -> CareLedgerEvent {
        careLedger.record(
            occurredAt: milestone.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .milestone,
            actionType: actionType,
            amountValue: 0,
            amountUnit: "",
            note: milestone.title,
            source: source,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "PetMilestone",
            legacyModelId: milestone.id.uuidString,
            coconutDelta: coconutDelta,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "",
            context: context,
            save: save
        )
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
    func seedSystemMilestones(for pet: Pet, note: String) -> PetMilestoneCommandResult {
        let result = PetMilestoneCommandService.seedSystemMilestones(for: pet, context: context)
        revisions.publishPetMilestoneSeed(result, note: note)
        return result
    }

    @discardableResult
    func createMilestone(
        input: PetMilestoneCommandInput,
        pet: Pet,
        note: String
    ) -> PetMilestoneCommandResult {
        let result = PetMilestoneCommandService.createMilestone(input: input, pet: pet, context: context)
        revisions.publishPetMilestoneRecord(result, note: note)
        return result
    }

    @discardableResult
    func deleteMilestone(
        _ milestone: PetMilestone,
        pet: Pet,
        note: String
    ) -> PetMilestoneDeleteCommandResult {
        let result = PetMilestoneCommandService.deleteMilestone(milestone, pet: pet, context: context)
        revisions.publishPetMilestoneDelete(result, note: note)
        return result
    }
}
