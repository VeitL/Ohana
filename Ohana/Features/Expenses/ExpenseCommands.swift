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
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> ExpenseCommandResult {
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger = providedCareLedger ?? CareLedgerService()
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = PetExpenseLog(
            date: date,
            amount: amount,
            category: category,
            note: cleanNote,
            pet: pet,
            executorId: executorId
        )
        context.insert(log)

        let document: PetDocument?
        if !receiptAttachments.isEmpty {
            let receiptDocument = ExpenseReceiptDocumentBuilder.makeDocument(
                title: receiptTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? "\(pet.name) · \(category.rawValue)",
                category: receiptCategory ?? .other,
                cost: amount,
                date: log.date,
                visibleNote: cleanNote,
                linkedExpenseLogId: log.id.uuidString,
                attachments: receiptAttachments,
                pet: pet
            )
            context.insert(receiptDocument)
            for attachment in receiptDocument.attachments {
                context.insert(attachment)
            }
            document = receiptDocument
        } else {
            document = nil
        }

        let reward = questManager.awardAction(type: .expense, pet: pet, context: context)
        let coconutDelta = careLedger.rewardDelta(reward)
        let ledgerEvent = careLedger.record(
            occurredAt: log.date,
            actorKind: executorId == nil ? .unknown : .human,
            actorId: executorId,
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
        return ExpenseCommandResult(
            logID: log.id,
            subjectID: pet.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEvent.id,
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
        let questManager = providedQuestManager ?? QuestManager()
        let careLedger = providedCareLedger ?? CareLedgerService()
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = PetExpenseLog(
            date: date,
            amount: amount,
            category: category,
            note: cleanNote,
            pet: nil,
            executorId: human.id.uuidString
        )
        context.insert(log)

        let reward = questManager.awardAction(type: .expense, pet: nil, context: context)
        let coconutDelta = careLedger.rewardDelta(reward)
        let ledgerEvent = careLedger.record(
            occurredAt: date,
            actorKind: .human,
            actorId: human.id.uuidString,
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
        return ExpenseCommandResult(
            logID: log.id,
            subjectID: human.id,
            coconutDelta: coconutDelta,
            ledgerEventID: ledgerEvent.id
        )
    }
}
