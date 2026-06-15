//
//  DashboardRecordCommands.swift
//  Ohana
//
//  Domain write boundaries for dashboard weight and expense records.
//

import Foundation
import SwiftData

@MainActor
private func fetchDashboardRecordModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "DashboardRecordCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

struct WeightCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID?
    let coconutDelta: Int
    let ledgerEventID: UUID?
    let didRecord: Bool
    let allowsDerivedEffects: Bool

    init(
        logID: UUID,
        subjectID: UUID?,
        coconutDelta: Int,
        ledgerEventID: UUID? = nil,
        didRecord: Bool = true,
        allowsDerivedEffects: Bool = true
    ) {
        self.logID = logID
        self.subjectID = subjectID
        self.coconutDelta = coconutDelta
        self.ledgerEventID = ledgerEventID
        self.didRecord = didRecord
        self.allowsDerivedEffects = allowsDerivedEffects
    }
}

struct DashboardRecordDeleteCommandResult: Equatable {
    let subjectID: UUID
    let subjectKind: String
    let recordID: UUID
    let recordKind: String
    let removedLedgerEventIDs: [UUID]
    let didChange: Bool
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
        let disposition = CareFactWritePolicy.disposition(
            pet: pet,
            date: date,
            executorId: executorId,
            context: context
        )
        guard disposition.didWriteFact else {
            return WeightCommandResult(
                logID: UUID(),
                subjectID: pet.id,
                coconutDelta: 0,
                didRecord: false,
                allowsDerivedEffects: false
            )
        }
        let actor = CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: "WeightCommandService.recordPetWeight"
        )
        let log = PetWeightLog(
            date: date,
            weight: weight,
            weightUnit: weightUnit,
            bcsScore: bcsScore,
            pet: pet,
            executorId: actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        let allowsDerivedEffects = disposition.allowsDerivedEffects
        let reward: (humanGot: Int, petGot: Int)? = if awardsReward, allowsDerivedEffects {
            EconomyRewardDiscipline.awardCareAction(
                type: .weight,
                pet: pet,
                context: context,
                executorId: actor.rewardExecutorId,
                questManager: questManager
            )
        } else {
            nil
        }

        let ledgerEvent = allowsDerivedEffects ? ledgerSource.map { source in
            careLedger.record(
                occurredAt: log.date,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
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
        } : nil

        if !awardsReward || !allowsDerivedEffects || ledgerEvent != nil {
            context.safeSave()
        }
        return WeightCommandResult(
            logID: log.id,
            subjectID: pet.id,
            coconutDelta: careLedger.rewardDelta(reward),
            ledgerEventID: ledgerEvent?.id,
            didRecord: true,
            allowsDerivedEffects: allowsDerivedEffects
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
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return WeightCommandResult(
                logID: UUID(),
                subjectID: human.id,
                coconutDelta: 0,
                didRecord: false,
                allowsDerivedEffects: false
            )
        }
        let log = HumanWeightLog(
            date: date,
            weight: weight,
            human: human,
            executorId: executorId
        )
        context.insert(log)
        human.weightLogs.append(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: date)
        context.safeSave()
        return WeightCommandResult(logID: log.id, subjectID: human.id, coconutDelta: 0)
    }
}

@MainActor
struct DashboardRecordCommandExecutor {
    let context: ModelContext
    let revisions: DomainRevisionPublishing
    private let derivations: CareDerivationExecutor
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
        derivations = CareDerivationExecutor(revisions: revisions)
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
        derivePetWeight(result, command: command, subjectID: pet.id, factDate: date, note: note)
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
        guard result.didRecord else { return result }
        revisions.publishWeightEntry(command: command, subjectID: human.id, result: result, note: note)
        return result
    }

    @discardableResult
    func deletePetWeight(_ log: PetWeightLog, pet: Pet, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deletePetWeight(log, pet: pet, context: context)
        if result.didChange {
            revisions.publishWeightDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    func deleteHumanWeight(_ log: HumanWeightLog, human: Human, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deleteHumanWeight(log, human: human, context: context)
        if result.didChange {
            revisions.publishWeightDelete(result, note: note)
        }
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
        guard result.ledgerEventID != nil else { return result }
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
        guard result.didWriteFact else {
            derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: [sourcePet.id],
                    note: revisionNote
                )
            )
            return result
        }
        var affectedIDs = Set(result.targetPetIDs)
        affectedIDs.insert(result.sessionID)
        result.expenseLogIDs.forEach { affectedIDs.insert($0) }
        derivations.derive(
            .active(
                disposition: result.disposition,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: sourcePet.id,
                    logIDs: result.expenseLogIDs,
                    factDate: date,
                    operationDate: date
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: command,
                    affectedEntityIDs: affectedIDs,
                    note: revisionNote
                ),
                sharedSession: CareWriteOutcome.SharedSessionPayload(
                    sessionID: result.sessionID,
                    sourcePetID: sourcePet.id,
                    targetPetIDs: result.targetPetIDs
                ),
                noopNote: "\(revisionNote).factOnly"
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
        guard result.ledgerEventID != nil else { return result }
        revisions.publishExpenseEntry(command: command, subjectID: human.id, result: result, note: revisionNote)
        return result
    }

    @discardableResult
    func deletePetExpense(_ log: PetExpenseLog, pet: Pet, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deletePetExpense(log, pet: pet, context: context)
        if result.didChange {
            revisions.publishExpenseDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    func deleteHumanExpense(_ log: PetExpenseLog, human: Human, note: String) -> DashboardRecordDeleteCommandResult {
        let result = DashboardRecordCommandService.deleteHumanExpense(log, human: human, context: context)
        if result.didChange {
            revisions.publishExpenseDelete(result, note: note)
        }
        return result
    }

    @discardableResult
    private func derivePetWeight(
        _ result: WeightCommandResult,
        command: DomainCommand,
        subjectID: UUID,
        factDate: Date,
        note: String
    ) -> CareDerivationResult {
        guard result.didRecord else {
            return derivations.derive(
                .noOp(
                    command: command,
                    affectedEntityIDs: [subjectID],
                    note: note
                )
            )
        }
        var affected: Set<UUID> = [subjectID, result.logID]
        if let ledgerEventID = result.ledgerEventID {
            affected.insert(ledgerEventID)
        }
        return derivations.derive(
            .active(
                disposition: result.allowsDerivedEffects ? .active : .noOp,
                fact: CareWriteOutcome.FactPayload(
                    subjectID: subjectID,
                    logIDs: [result.logID],
                    factDate: factDate,
                    operationDate: factDate
                ),
                revision: CareWriteOutcome.RevisionPayload(
                    command: command,
                    affectedEntityIDs: affected,
                    note: note
                ),
                reward: CareWriteOutcome.RewardPayload(
                    humanDelta: result.coconutDelta,
                    petDelta: 0
                ),
                ledger: result.ledgerEventID.map { CareWriteOutcome.LedgerPayload(eventIDs: [$0]) },
                noopNote: note
            )
        )
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
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return noOpDeleteResult(
                subjectID: pet.id,
                subjectKind: EntityKind.pet.rawValue,
                recordID: log.id,
                recordKind: "PetWeightLog"
            )
        }
        return deleteRecord(
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
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return noOpDeleteResult(
                subjectID: human.id,
                subjectKind: EntityKind.human.rawValue,
                recordID: log.id,
                recordKind: "HumanWeightLog"
            )
        }
        return deleteRecord(
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
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            return noOpDeleteResult(
                subjectID: pet.id,
                subjectKind: EntityKind.pet.rawValue,
                recordID: log.id,
                recordKind: "PetExpenseLog"
            )
        }
        let recordID = log.id
        let sharedSessionId = log.sharedSessionId
        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetExpenseLog", id: recordID, context: context)
        for event in ledgerEvents {
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        CloudSyncMutationRecorder.markDeleted(log, pet: pet, context: context)
        context.delete(log)
        SharedCareSessionMaintenance.reconcileAfterDeletingChild(sharedSessionId: sharedSessionId, context: context)
        context.safeSave()
        return DashboardRecordDeleteCommandResult(
            subjectID: pet.id,
            subjectKind: EntityKind.pet.rawValue,
            recordID: recordID,
            recordKind: "PetExpenseLog",
            removedLedgerEventIDs: ledgerEvents.map(\.id),
            didChange: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteHumanExpense(
        _ log: PetExpenseLog,
        human: Human,
        context: ModelContext
    ) -> DashboardRecordDeleteCommandResult {
        guard MemberWritePolicy.disposition(human: human, intent: .activeOnly).allowsDerivedEffects else {
            return noOpDeleteResult(
                subjectID: human.id,
                subjectKind: EntityKind.human.rawValue,
                recordID: log.id,
                recordKind: "PetExpenseLog"
            )
        }
        return deleteRecord(
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
            CloudSyncMutationRecorder.markDeleted(event, context: context)
            context.delete(event)
        }
        markSyncedRecordDeletedIfNeeded(record, context: context)
        context.delete(record)
        context.safeSave()
        return DashboardRecordDeleteCommandResult(
            subjectID: subjectID,
            subjectKind: subjectKind,
            recordID: recordID,
            recordKind: recordKind,
            removedLedgerEventIDs: ledgerEvents.map(\.id),
            didChange: true
        )
    }

    private static func noOpDeleteResult(
        subjectID: UUID,
        subjectKind: String,
        recordID: UUID,
        recordKind: String
    ) -> DashboardRecordDeleteCommandResult {
        DashboardRecordDeleteCommandResult(
            subjectID: subjectID,
            subjectKind: subjectKind,
            recordID: recordID,
            recordKind: recordKind,
            removedLedgerEventIDs: [],
            didChange: false
        )
    }

    @MainActor
    private static func markSyncedRecordDeletedIfNeeded(
        _ record: some PersistentModel,
        context: ModelContext
    ) {
        switch record {
        case let log as PetExpenseLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context)
        case let log as PetWeightLog:
            CloudSyncMutationRecorder.markDeleted(log, pet: log.pet, context: context)
        default:
            break
        }
    }

    @MainActor
    private static func ledgerEvents(
        forLegacyModelName modelName: String,
        id: UUID,
        context: ModelContext
    ) -> [CareLedgerEvent] {
        let idString = id.uuidString
        let descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == modelName && event.legacyModelId == idString
            }
        )
        return fetchDashboardRecordModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch dashboard ledger events for legacy record"
        )
    }
}
