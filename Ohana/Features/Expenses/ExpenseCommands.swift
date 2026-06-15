//
//  ExpenseCommands.swift
//  Ohana
//
//  Domain write boundaries for expense records.
//

import Foundation
import SwiftData

struct ExpenseCommandResult: Equatable {
    let logID: UUID
    let subjectID: UUID?
    let coconutDelta: Int
    let ledgerEventID: UUID?
    let documentID: UUID?

    init(
        logID: UUID,
        subjectID: UUID?,
        coconutDelta: Int,
        ledgerEventID: UUID? = nil,
        documentID: UUID? = nil
    ) {
        self.logID = logID
        self.subjectID = subjectID
        self.coconutDelta = coconutDelta
        self.ledgerEventID = ledgerEventID
        self.documentID = documentID
    }
}

enum ExpenseCommandService {
    @discardableResult
    @MainActor
    static func recordPetExpense(
        pet: Pet,
        amount: Double,
        date: Date,
        category: ExpenseCategory,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        source: CareLedgerSource = .detail,
        receiptTitle: String? = nil,
        receiptCategory: DocumentCategory? = nil,
        receiptAttachments: [ExpenseReceiptAttachmentDraft] = [],
        awardsReward: Bool = true,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> ExpenseCommandResult {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let intent = DomainCareFactCreateIntent(
            kind: .expense(
                amount: amount,
                category: category,
                note: cleanNote,
                sharedSessionId: ""
            ),
            occurredAt: date,
            executorId: executorId,
            source: .userCommand
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "ExpenseCommandService.recordPetExpense"
        ) else {
            return ExpenseCommandResult(logID: UUID(), subjectID: pet.id, coconutDelta: 0)
        }
        let careLedger = providedCareLedger ?? CareLedgerService()
        let log = DomainCareFactWriter.createExpenseLog(plan: write, context: context)

        var document: PetDocument?
        var coconutDelta = 0
        var ledgerEventID: UUID?
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            if !receiptAttachments.isEmpty {
                let draft = ExpenseReceiptDocumentBuilder.makeDraft(
                    title: receiptTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                        ?? "\(pet.name) · \(category.rawValue)",
                    category: receiptCategory ?? .other,
                    cost: amount,
                    date: log.date,
                    visibleNote: cleanNote,
                    linkedExpenseLogId: log.id.uuidString,
                    attachments: receiptAttachments
                )
                if let documentWrite = DomainMemberFactWriteAuthorizer.authorizePetFact(
                    pet: pet,
                    occurredAt: log.date,
                    writeKind: .care,
                    executorId: actor.effectiveExecutorId,
                    context: context,
                    logPrefix: "ExpenseCommandService.recordPetExpense.receipt",
                    actorOverride: actor
                ) {
                    let receiptDocument = DomainMemberFactWriter.createPetDocument(
                        plan: documentWrite,
                        title: draft.title,
                        category: draft.category,
                        pet: pet,
                        context: context
                    )
                    receiptDocument.issueDate = draft.issueDate
                    receiptDocument.cost = draft.cost
                    receiptDocument.notes = draft.notes
                    receiptDocument.attachmentData = draft.attachmentData
                    receiptDocument.attachmentFilename = draft.attachmentFilename
                    for attachment in draft.attachments {
                        _ = DomainMemberFactWriter.createPetDocumentAttachment(
                            plan: documentWrite,
                            data: attachment.data,
                            filename: attachment.filename,
                            isImage: attachment.isImage,
                            document: receiptDocument,
                            context: context
                        )
                    }
                    CloudSyncMutationRecorder.markModified(receiptDocument, context: context, modifiedAt: log.date)
                    document = receiptDocument
                }
            }

            let reward: (humanGot: Int, petGot: Int)?
            if awardsReward {
                let questManager = providedQuestManager ?? QuestManager()
                reward = EconomyRewardDiscipline.awardNonCareReward(
                    type: .expense,
                    pet: pet,
                    context: context,
                    executorId: actor.rewardExecutorId,
                    questManager: questManager
                )
            } else {
                reward = nil
            }
            coconutDelta = careLedger.rewardDelta(reward)
            let ledgerEvent = careLedger.record(
                occurredAt: log.date,
                actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                actorId: actor.effectiveExecutorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .expense,
                actionType: category.rawValue,
                amountValue: amount,
                amountUnit: "currency",
                note: cleanNote,
                source: source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetExpenseLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: coconutDelta,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "",
                context: context,
                save: true
            )
            ledgerEventID = ledgerEvent.id
        }
        return ExpenseCommandResult(
            logID: log.id,
            subjectID: pet.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEventID,
            documentID: document?.id
        )
    }

    @discardableResult
    @MainActor
    static func recordSharedPetExpense(
        sourcePet: Pet,
        targets: [Pet],
        amount: Double,
        date: Date,
        category: ExpenseCategory,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        source: CareLedgerSource = .detail,
        careEvents providedCareEvents: CareEventRecording? = nil
    ) -> SharedPetActionResult {
        let careEvents = providedCareEvents ?? CareEventService()
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return careEvents.recordSharedExpense(
            sourcePet: sourcePet,
            targets: targets,
            amount: amount,
            category: category,
            note: cleanNote,
            context: context,
            executorId: executorId,
            date: date,
            currencyCode: AppCurrency.code,
            source: source
        )
    }

    @discardableResult
    @MainActor
    static func recordHumanExpense(
        human: Human,
        amount: Double,
        date: Date,
        note: String,
        context: ModelContext,
        category: ExpenseCategory = .other,
        source: CareLedgerSource = .quickAction,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> ExpenseCommandResult {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let intent = DomainCareFactCreateIntent(
            kind: .expense(
                amount: amount,
                category: category,
                note: cleanNote,
                sharedSessionId: ""
            ),
            occurredAt: date,
            executorId: human.id.uuidString,
            source: .userCommand
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizeHumanExpense(
            human: human,
            intent: intent,
            context: context,
            logPrefix: "ExpenseCommandService.recordHumanExpense"
        ) else {
            return ExpenseCommandResult(logID: UUID(), subjectID: human.id, coconutDelta: 0)
        }
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger = providedCareLedger ?? CareLedgerService()
        let log = DomainCareFactWriter.createHumanExpenseLog(plan: write, context: context)
        var coconutDelta = 0
        var ledgerEventID: UUID?
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            let reward = EconomyRewardDiscipline.awardNonCareReward(
                type: .expense,
                pet: nil,
                context: context,
                executorId: actor.rewardExecutorId,
                questManager: questManager
            )
            coconutDelta = careLedger.rewardDelta(reward)
            let ledgerEvent = careLedger.record(
                occurredAt: log.date,
                actorKind: .human,
                actorId: actor.effectiveExecutorId,
                subjectKind: .human,
                subjectId: human.id.uuidString,
                eventKind: .expense,
                actionType: category.rawValue,
                amountValue: amount,
                amountUnit: "currency",
                note: cleanNote,
                source: source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetExpenseLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: coconutDelta,
                rewardLogId: nil,
                privacyFieldRaw: HumanPrivateField.expense.rawValue,
                metadataJSON: "",
                context: context,
                save: true
            )
            ledgerEventID = ledgerEvent.id
        }
        return ExpenseCommandResult(
            logID: log.id,
            subjectID: human.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEventID
        )
    }
}
