//
//  DashboardRecordCommands.swift
//  Ohana
//
//  Domain write boundaries for dashboard weight and expense records.
//

import Foundation
import SwiftData

struct WeightCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID?
    let coconutDelta: Int
    let ledgerEventID: UUID?

    init(logID: UUID, subjectID: UUID?, coconutDelta: Int, ledgerEventID: UUID? = nil) {
        self.logID = logID
        self.subjectID = subjectID
        self.coconutDelta = coconutDelta
        self.ledgerEventID = ledgerEventID
    }
}

struct DashboardRecordDeleteCommandResult: Equatable {
    let subjectID: UUID
    let subjectKind: String
    let recordID: UUID
    let recordKind: String
    let removedLedgerEventIDs: [UUID]
}

enum WeightCommandService {
    @discardableResult
    @MainActor
    static func recordPetWeight(
        pet: Pet,
        weight: Double,
        date: Date,
        context: ModelContext,
        executorId: String? = nil,
        weightUnit: String = "kg",
        bcsScore: Int = 0,
        awardsReward: Bool = false,
        ledgerSource: CareLedgerSource? = nil,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> WeightCommandResult {
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger: CareLedgerRecording = providedCareLedger ?? CareLedgerService()
        let log = PetWeightLog(
            date: date,
            weight: weight,
            weightUnit: weightUnit,
            bcsScore: bcsScore,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)
        let reward: (humanGot: Int, petGot: Int)? = if awardsReward {
            questManager.awardAction(type: .weight, pet: pet, context: context)
        } else {
            nil
        }

        let ledgerEvent = ledgerSource.map { source in
            careLedger.record(
                occurredAt: log.date,
                actorKind: executorId == nil ? .unknown : .human,
                actorId: executorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .weight,
                actionType: "petWeight",
                amountValue: log.weightInKg,
                amountUnit: "kg",
                note: "",
                source: source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetWeightLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: careLedger.rewardDelta(reward),
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: careLedger.rewardMetadata(reward, questManager: questManager),
                context: context,
                save: false
            )
        }

        if !awardsReward || ledgerEvent != nil {
            context.safeSave()
        }
        return WeightCommandResult(
            logID: log.id,
            subjectID: pet.id,
            coconutDelta: careLedger.rewardDelta(reward),
            ledgerEventID: ledgerEvent?.id
        )
    }

    @discardableResult
    @MainActor
    static func recordHumanWeight(
        human: Human,
        weight: Double,
        date: Date,
        context: ModelContext,
        executorId: String? = nil
    ) -> WeightCommandResult {
        let log = HumanWeightLog(
            date: date,
            weight: weight,
            human: human,
            executorId: executorId
        )
        context.insert(log)
        human.weightLogs.append(log)
        context.safeSave()
        return WeightCommandResult(logID: log.id, subjectID: human.id, coconutDelta: 0)
    }
}

@MainActor
struct DashboardRecordCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    let questManager: QuestManager
    let careLedger: CareLedgerRecording
    let careEvents: CareEventRecording

    init(context: ModelContext) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(),
            questManager: QuestManager(),
            careLedger: CareLedgerService(),
            careEvents: CareEventService()
        )
    }

    init(context: ModelContext, revisionCenter: ReadModelRevisionCenter) {
        self.init(
            context: context,
            revisions: SharedDomainRevisionPublisher(center: revisionCenter),
            questManager: QuestManager(),
            careLedger: CareLedgerService(),
            careEvents: CareEventService()
        )
    }

    init(context: ModelContext, services: AppServices) {
        self.init(
            context: context,
            revisions: services.domainRevisions,
            questManager: services.questManager,
            careLedger: services.careLedger,
            careEvents: services.careEvents
        )
    }

    init(
        context: ModelContext,
        revisions: DomainRevisionPublishing,
        questManager: QuestManager,
        careLedger: CareLedgerRecording,
        careEvents: CareEventRecording
    ) {
        self.context = context
        self.revisions = revisions
        self.questManager = questManager
        self.careLedger = careLedger
        self.careEvents = careEvents
    }

    @discardableResult
    func recordPetWeight(
        pet: Pet,
        weight: Double,
        date: Date,
        executorId: String?,
        weightUnit: String = "kg",
        bcsScore: Int = 0,
        awardsReward: Bool = false,
        ledgerSource: CareLedgerSource? = nil,
        command: DomainCommand,
        note: String
    ) -> WeightCommandResult {
        let result = WeightCommandService.recordPetWeight(
            pet: pet,
            weight: weight,
            date: date,
            context: context,
            executorId: executorId,
            weightUnit: weightUnit,
            bcsScore: bcsScore,
            awardsReward: awardsReward,
            ledgerSource: ledgerSource,
            questManager: questManager,
            careLedger: careLedger
        )
        revisions.publishWeightEntry(command: command, subjectID: pet.id, result: result, note: note)
        return result
    }

    @discardableResult
    func recordHumanWeight(
        human: Human,
        weight: Double,
        date: Date,
        executorId: String?,
        command: DomainCommand,
        note: String
    ) -> WeightCommandResult {
        let result = WeightCommandService.recordHumanWeight(
            human: human,
            weight: weight,
            date: date,
            context: context,
            executorId: executorId
        )
        revisions.publishWeightEntry(command: command, subjectID: human.id, result: result, note: note)
        return result
    }

    @discardableResult
    func deletePetWeight(_ log: PetWeightLog, pet: Pet, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deletePetWeight(log, pet: pet, context: context)
        revisions.publishWeightDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteHumanWeight(_ log: HumanWeightLog, human: Human, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deleteHumanWeight(log, human: human, context: context)
        revisions.publishWeightDelete(result, note: note)
        return result
    }

    @discardableResult
    func recordPetExpense(
        pet: Pet,
        amount: Double,
        date: Date,
        category: ExpenseCategory,
        note expenseNote: String,
        executorId: String?,
        source: CareLedgerSource = .detail,
        receiptTitle: String? = nil,
        receiptCategory: DocumentCategory? = nil,
        receiptAttachments: [ExpenseReceiptAttachmentDraft] = [],
        command: DomainCommand,
        revisionNote: String
    ) -> ExpenseCommandResult {
        let result = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: amount,
            date: date,
            category: category,
            note: expenseNote,
            context: context,
            executorId: executorId,
            source: source,
            receiptTitle: receiptTitle,
            receiptCategory: receiptCategory,
            receiptAttachments: receiptAttachments,
            questManager: questManager,
            careLedger: careLedger
        )
        revisions.publishExpenseEntry(command: command, subjectID: pet.id, result: result, note: revisionNote)
        return result
    }

    @discardableResult
    func recordSharedPetExpense(
        sourcePet: Pet,
        targets: [Pet],
        amount: Double,
        date: Date,
        category: ExpenseCategory,
        note expenseNote: String,
        executorId: String?,
        source: CareLedgerSource = .detail,
        command: DomainCommand,
        revisionNote: String
    ) -> SharedPetActionResult {
        let result = ExpenseCommandService.recordSharedPetExpense(
            sourcePet: sourcePet,
            targets: targets,
            amount: amount,
            date: date,
            category: category,
            note: expenseNote,
            context: context,
            executorId: executorId,
            source: source,
            careEvents: careEvents
        )
        var affectedIDs = Set(result.targetPetIDs)
        affectedIDs.insert(result.sessionID)
        result.expenseLogIDs.forEach { affectedIDs.insert($0) }
        revisions.publish(
            DomainMutationResult(
                command: command,
                affectedEntityIDs: affectedIDs,
                wroteBusinessFact: true,
                note: revisionNote
            )
        )
        return result
    }

    @discardableResult
    func recordHumanExpense(
        human: Human,
        amount: Double,
        date: Date,
        note expenseNote: String,
        category: ExpenseCategory = .other,
        source: CareLedgerSource = .quickAction,
        command: DomainCommand,
        revisionNote: String
    ) -> ExpenseCommandResult {
        let result = ExpenseCommandService.recordHumanExpense(
            human: human,
            amount: amount,
            date: date,
            note: expenseNote,
            context: context,
            category: category,
            source: source,
            questManager: questManager,
            careLedger: careLedger
        )
        revisions.publishExpenseEntry(command: command, subjectID: human.id, result: result, note: revisionNote)
        return result
    }

    @discardableResult
    func deletePetExpense(_ log: PetExpenseLog, pet: Pet, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deletePetExpense(log, pet: pet, context: context)
        revisions.publishExpenseDelete(result, note: note)
        return result
    }

    @discardableResult
    func deleteHumanExpense(_ log: PetExpenseLog, human: Human, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deleteHumanExpense(log, human: human, context: context)
        revisions.publishExpenseDelete(result, note: note)
        return result
    }
}

enum DashboardRecordCommandService {
    @discardableResult
    @MainActor
    static func deletePetWeight(
        _ log: PetWeightLog,
        pet: Pet,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        deleteRecord(
            log,
            subjectID: pet.id,
            subjectKind: EntityKind.pet.rawValue,
            recordID: log.id,
            recordKind: "PetWeightLog",
            context: context
        )
    }

    @discardableResult
    @MainActor
    static func deleteHumanWeight(
        _ log: HumanWeightLog,
        human: Human,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        deleteRecord(
            log,
            subjectID: human.id,
            subjectKind: EntityKind.human.rawValue,
            recordID: log.id,
            recordKind: "HumanWeightLog",
            context: context
        )
    }

    @discardableResult
    @MainActor
    static func deletePetExpense(
        _ log: PetExpenseLog,
        pet: Pet,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        let recordID = log.id
        let sharedSessionId = log.sharedSessionId
        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetExpenseLog", id: recordID, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        context.delete(log)
        SharedCareSessionMaintenance.reconcileAfterDeletingChild(sharedSessionId: sharedSessionId, context: context)
        context.safeSave()
        return DashboardRecordDeleteCommandResult(
            subjectID: pet.id,
            subjectKind: EntityKind.pet.rawValue,
            recordID: recordID,
            recordKind: "PetExpenseLog",
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @discardableResult
    @MainActor
    static func deleteHumanExpense(
        _ log: PetExpenseLog,
        human: Human,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        deleteRecord(
            log,
            subjectID: human.id,
            subjectKind: EntityKind.human.rawValue,
            recordID: log.id,
            recordKind: "PetExpenseLog",
            context: context
        )
    }

    @discardableResult
    @MainActor
    private static func deleteRecord(
        _ record: some PersistentModel,
        subjectID: UUID,
        subjectKind: String,
        recordID: UUID,
        recordKind: String,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        let ledgerEvents = ledgerEvents(forLegacyModelName: recordKind, id: recordID, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        context.delete(record)
        context.safeSave()
        return DashboardRecordDeleteCommandResult(
            subjectID: subjectID,
            subjectKind: subjectKind,
            recordID: recordID,
            recordKind: recordKind,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = id.uuidString
        let events = (try? context.fetch(FetchDescriptor<CareLedgerEvent>())) ?? [] // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        return events.filter { $0.legacyModelName == modelName && $0.legacyModelId == idString }
    }
}
