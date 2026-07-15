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

private struct PetExpenseFactRequest {
    let pet: Pet
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    let note: String
    let context: ModelContext
    let attribution: ExpenseActorAttribution
    let source: CareLedgerSource
    let receiptTitle: String?
    let receiptCategory: DocumentCategory?
    let receiptAttachments: [ExpenseReceiptAttachmentDraft]
    let awardsReward: Bool
    let mutationSource: DomainMutationSourceKind
    let questManager: QuestManager?
    let careLedger: CareLedgerRecording?
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
        recordedByHumanId: String? = nil,
        source: CareLedgerSource = .detail,
        receiptTitle: String? = nil,
        receiptCategory: DocumentCategory? = nil,
        receiptAttachments: [ExpenseReceiptAttachmentDraft] = [],
        awardsReward: Bool = true,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) throws -> ExpenseCommandResult {
        try ExpenseAmountPolicy.validateUserExpense(amount)
        let attribution = ExpenseActorAttribution(
            executorId: executorId,
            recordedByHumanId: recordedByHumanId
        ).validated(context: context)
        return recordPetExpenseFact(PetExpenseFactRequest(
            pet: pet,
            amount: amount,
            date: date,
            category: category,
            note: note,
            context: context,
            attribution: attribution,
            source: source,
            receiptTitle: receiptTitle,
            receiptCategory: receiptCategory,
            receiptAttachments: receiptAttachments,
            awardsReward: awardsReward,
            mutationSource: .userCommand,
            questManager: providedQuestManager,
            careLedger: providedCareLedger
        ))
    }

    @discardableResult
    @MainActor
    static func recordInsuranceReimbursement(
        pet: Pet,
        amount: Double,
        date: Date,
        note: String,
        context: ModelContext,
        executorId: String? = nil,
        source: CareLedgerSource = .detail,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) throws -> ExpenseCommandResult {
        let storedAmount = try ExpenseAmountPolicy.storedInsuranceReimbursementAmount(from: amount)
        let attribution = ExpenseActorAttribution(executorId: executorId).validated(context: context)
        return recordPetExpenseFact(PetExpenseFactRequest(
            pet: pet,
            amount: storedAmount,
            date: date,
            category: .insurancePremium,
            note: note,
            context: context,
            attribution: attribution,
            source: source,
            receiptTitle: nil,
            receiptCategory: nil,
            receiptAttachments: [],
            awardsReward: false,
            mutationSource: .domainService,
            questManager: nil,
            careLedger: providedCareLedger
        ))
    }

    @MainActor
    private static func recordPetExpenseFact(_ request: PetExpenseFactRequest) -> ExpenseCommandResult {
        let cleanNote = request.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let intent = DomainCareFactCreateIntent(
            kind: .expense(
                amount: request.amount,
                category: request.category,
                note: cleanNote,
                sharedSessionId: ""
            ),
            occurredAt: request.date,
            executorId: request.attribution.executorId,
            source: request.mutationSource
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: request.pet,
            intent: intent,
            context: request.context,
            logPrefix: "ExpenseCommandService.recordPetExpense"
        ) else {
            return ExpenseCommandResult(logID: UUID(), subjectID: request.pet.id, coconutDelta: 0)
        }
        let careLedger = request.careLedger ?? CareLedgerService()
        let log = DomainCareFactWriter.createExpenseLog(
            plan: write,
            recordedByHumanId: request.attribution.recordedByHumanId,
            context: request.context
        )

        var document: PetDocument?
        var coconutDelta = 0
        var ledgerEventID: UUID?
        DomainCareFactEffectsDispatcher.run(plan: write) { actor in
            document = createReceiptIfNeeded(
                request: request,
                log: log,
                cleanNote: cleanNote,
                actor: actor
            )

            let reward: (humanGot: Int, petGot: Int)?
            if request.awardsReward {
                let questManager = request.questManager ?? QuestManager()
                reward = EconomyRewardDiscipline.awardNonCareReward(
                    type: .expense,
                    pet: request.pet,
                    context: request.context,
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
                subjectId: request.pet.id.uuidString,
                eventKind: .expense,
                actionType: request.category.rawValue,
                amountValue: request.amount,
                amountUnit: "currency",
                note: cleanNote,
                source: request.source,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetExpenseLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: coconutDelta,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "",
                context: request.context,
                save: true
            )
            ledgerEventID = ledgerEvent.id
        }
        return ExpenseCommandResult(
            logID: log.id,
            subjectID: request.pet.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEventID,
            documentID: document?.id
        )
    }

    @MainActor
    private static func createReceiptIfNeeded(
        request: PetExpenseFactRequest,
        log: PetExpenseLog,
        cleanNote: String,
        actor: EconomyRewardOwnerResolution
    ) -> PetDocument? {
        guard !request.receiptAttachments.isEmpty else { return nil }
        let draft = ExpenseReceiptDocumentBuilder.makeDraft(
            title: request.receiptTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? "\(request.pet.name) · \(request.category.rawValue)",
            category: request.receiptCategory ?? .other,
            cost: request.amount,
            date: log.date,
            visibleNote: cleanNote,
            linkedExpenseLogId: log.id.uuidString,
            attachments: request.receiptAttachments
        )
        guard let documentWrite = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: request.pet,
            occurredAt: log.date,
            writeKind: .care,
            executorId: actor.effectiveExecutorId,
            context: request.context,
            logPrefix: "ExpenseCommandService.recordPetExpense.receipt",
            actorOverride: actor
        ) else { return nil }
        let document = DomainMemberFactWriter.createPetDocument(
            plan: documentWrite,
            title: draft.title,
            category: draft.category,
            pet: request.pet,
            context: request.context
        )
        document.issueDate = draft.issueDate
        document.cost = draft.cost
        document.notes = draft.notes
        document.updateLegacyAttachment(
            data: draft.attachmentData,
            filename: draft.attachmentFilename
        )
        for attachment in draft.attachments {
            _ = DomainMemberFactWriter.createPetDocumentAttachment(
                plan: documentWrite,
                data: attachment.data,
                filename: attachment.filename,
                isImage: attachment.isImage,
                document: document,
                context: request.context
            )
        }
        CloudSyncMutationRecorder.markModified(document, context: request.context, modifiedAt: log.date)
        return document
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
        recordedByHumanId: String? = nil,
        source: CareLedgerSource = .detail,
        careEvents providedCareEvents: CareEventRecording? = nil
    ) throws -> SharedPetActionResult {
        try ExpenseAmountPolicy.validateUserExpense(amount)
        let careEvents = providedCareEvents ?? CareEventService()
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let attribution = ExpenseActorAttribution(
            executorId: executorId,
            recordedByHumanId: recordedByHumanId
        ).validated(context: context)
        return careEvents.recordSharedExpense(
            sourcePet: sourcePet,
            targets: targets,
            amount: amount,
            category: category,
            note: cleanNote,
            context: context,
            attribution: attribution,
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
        recordedByHumanId: String? = nil,
        category: ExpenseCategory = .other,
        source: CareLedgerSource = .quickAction,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) throws -> ExpenseCommandResult {
        try ExpenseAmountPolicy.validateUserExpense(amount)
        let recordedByHumanId = HumanActionAttributionPolicy.activeHumanID(recordedByHumanId, context: context)
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
        let log = DomainCareFactWriter.createHumanExpenseLog(
            plan: write,
            recordedByHumanId: recordedByHumanId,
            context: context
        )
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
