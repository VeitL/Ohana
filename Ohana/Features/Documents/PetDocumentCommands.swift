//
//  PetDocumentCommands.swift
//  Ohana
//
//  Pet document write boundary and revision publishing.
//

import Foundation
import SwiftData

struct PetDocumentAttachmentCommandInput: Equatable {
    let data: Data
    let filename: String
    let isImage: Bool
}

struct PetDocumentCreateCommandInput: Equatable {
    let title: String
    let category: DocumentCategory
    let issuingAuthority: String
    let notes: String
    let issueDate: Date?
    let expiryDate: Date?
    let cost: Double
    let payerId: String?
    let documentNumber: String
    let attachments: [PetDocumentAttachmentCommandInput]
}

struct PetDocumentUpdateCommandInput: Equatable {
    let title: String
    let category: DocumentCategory
    let issuingAuthority: String
    let notes: String
    let issueDate: Date?
    let expiryDate: Date?
    let cost: Double
    let attachmentData: Data?
    let clearsAttachment: Bool
    let attachments: [PetDocumentAttachmentCommandInput]

    init(
        title: String,
        category: DocumentCategory,
        issuingAuthority: String,
        notes: String,
        issueDate: Date?,
        expiryDate: Date?,
        cost: Double,
        attachmentData: Data?,
        clearsAttachment: Bool,
        attachments: [PetDocumentAttachmentCommandInput] = []
    ) {
        self.title = title
        self.category = category
        self.issuingAuthority = issuingAuthority
        self.notes = notes
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.cost = cost
        self.attachmentData = attachmentData
        self.clearsAttachment = clearsAttachment
        self.attachments = attachments
    }
}

struct PetDocumentCommandResult: Equatable {
    let petID: UUID
    let documentID: UUID
    let expenseLogIDs: [UUID]
    let ledgerEventIDs: [UUID]
}

struct PetDocumentDeleteCommandResult: Equatable {
    let petID: UUID
    let documentID: UUID
    let removedLedgerEventIDs: [UUID]
}

enum PetDocumentCommandService {
    @discardableResult
    @MainActor
    static func createDocument(
        input: PetDocumentCreateCommandInput,
        pet: Pet,
        context: ModelContext,
        now: Date = Date(),
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) -> PetDocumentCommandResult {
        let careLedger = providedCareLedger ?? CareLedgerService()
        let finalTitle = input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(pet.name)\(input.category.rawValue)"
            : input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = PetDocument(title: finalTitle, category: input.category, pet: pet)
        document.issuingAuthority = input.issuingAuthority
        document.notes = input.notes
        document.issueDate = input.issueDate
        document.expiryDate = input.expiryDate
        document.cost = max(0, input.cost)
        applyAttachments(input.attachments, to: document, context: context)

        let expenseLogs = makeExpensesIfNeeded(
            pet: pet,
            document: document,
            category: input.category,
            amount: document.cost,
            issueDate: input.issueDate,
            payerId: validPayerId(input.payerId, context: context),
            now: now,
            context: context
        )

        context.insert(document)
        if !input.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           input.category == .passport {
            pet.passportNumber = input.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let ledgerEvents = expenseLogs.map { expense in
            careLedger.record(
                occurredAt: expense.date,
                actorKind: expense.executorId == nil ? .unknown : .human,
                actorId: expense.executorId,
                subjectKind: .pet,
                subjectId: pet.id.uuidString,
                eventKind: .expense,
                actionType: expense.expenseCategory.rawValue,
                amountValue: expense.amount,
                amountUnit: "currency",
                note: expense.note,
                source: .detail,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "PetExpenseLog",
                legacyModelId: expense.id.uuidString,
                coconutDelta: 0,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "",
                context: context,
                save: false
            )
        }

        context.safeSave()
        return PetDocumentCommandResult(
            petID: pet.id,
            documentID: document.id,
            expenseLogIDs: expenseLogs.map(\.id),
            ledgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @discardableResult
    @MainActor
    static func updateDocument(
        _ document: PetDocument,
        pet: Pet,
        input: PetDocumentUpdateCommandInput,
        context: ModelContext
    ) -> PetDocumentCommandResult {
        document.title = input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(pet.name)\(input.category.rawValue)"
            : input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        document.category = input.category.rawValue
        document.issuingAuthority = input.issuingAuthority
        document.notes = input.notes
        document.issueDate = input.issueDate
        document.expiryDate = input.expiryDate
        document.cost = max(0, input.cost)
        if input.clearsAttachment {
            document.attachmentData = nil
            document.attachmentFilename = ""
            document.attachments.removeAll()
        } else if !input.attachments.isEmpty {
            applyAttachments(input.attachments, to: document, context: context)
        } else if let data = input.attachmentData {
            let filename = document.attachmentFilename.isEmpty ? "image.jpg" : document.attachmentFilename
            document.attachmentData = AttachmentPrivacySanitizer.sanitizedData(
                data,
                filename: filename,
                isImage: AttachmentPrivacySanitizer.isImageFilename(filename)
            )
            document.attachmentFilename = filename
        }
        context.safeSave()
        return PetDocumentCommandResult(
            petID: pet.id,
            documentID: document.id,
            expenseLogIDs: [],
            ledgerEventIDs: []
        )
    }

    @discardableResult
    @MainActor
    static func deleteDocument(
        _ document: PetDocument,
        pet: Pet,
        context: ModelContext
    ) -> PetDocumentDeleteCommandResult {
        let ledgerEvents = ledgerEvents(forLegacyModelName: "PetDocument", id: document.id, context: context)
        for event in ledgerEvents {
            context.delete(event)
        }
        let documentID = document.id
        context.delete(document)
        context.safeSave()
        return PetDocumentDeleteCommandResult(
            petID: pet.id,
            documentID: documentID,
            removedLedgerEventIDs: ledgerEvents.map(\.id)
        )
    }

    @MainActor
    private static func applyAttachments(
        _ attachments: [PetDocumentAttachmentCommandInput],
        to document: PetDocument,
        context: ModelContext
    ) {
        guard let first = attachments.first else { return }
        let sanitizedAttachments = attachments.map(sanitizedAttachment)
        let sanitizedFirst = sanitizedAttachments[0]
        document.attachmentData = sanitizedFirst.data
        document.attachmentFilename = first.filename.isEmpty
            ? (first.isImage ? "image.jpg" : "attachment")
            : first.filename
        document.attachments = sanitizedAttachments.map { input in
            PetDocumentAttachment(
                data: input.data,
                filename: input.filename.isEmpty ? (input.isImage ? "image.jpg" : "attachment") : input.filename,
                isImage: input.isImage
            )
        }
        for attachment in document.attachments {
            context.insert(attachment)
        }
    }

    private static func sanitizedAttachment(
        _ input: PetDocumentAttachmentCommandInput
    ) -> PetDocumentAttachmentCommandInput {
        PetDocumentAttachmentCommandInput(
            data: AttachmentPrivacySanitizer.sanitizedData(
                input.data,
                filename: input.filename,
                isImage: input.isImage
            ),
            filename: input.filename,
            isImage: input.isImage
        )
    }

    @MainActor
    private static func makeExpensesIfNeeded(
        pet: Pet,
        document: PetDocument,
        category: DocumentCategory,
        amount: Double,
        issueDate: Date?,
        payerId: String?,
        now: Date,
        context: ModelContext
    ) -> [PetExpenseLog] {
        guard amount > 0 else { return [] }
        let expenseDate: Date = {
            guard let issueDate else { return now }
            return issueDate > now ? now : issueDate
        }()
        let plans = DocumentExpenseSyncPlanner.plannedExpenses(
            documentCategory: category,
            amount: amount,
            date: expenseDate,
            note: document.title,
            payerId: payerId
        )
        return plans.map { plan in
            let expense = PetExpenseLog(
                date: plan.date,
                amount: plan.amount,
                category: plan.category,
                note: plan.note,
                pet: pet,
                executorId: plan.payerId
            )
            context.insert(expense)
            return expense
        }
    }

    @MainActor
    private static func validPayerId(_ payerId: String?, context: ModelContext) -> String? {
        guard let payerId, !payerId.isEmpty, UUID(uuidString: payerId) != nil else { return nil }
        let humans = (try? context.fetch(FetchDescriptor<Human>())) ?? [] // smoothness: allow legacy plan lookup; QuickCare read-model migration tracked after P1 baseline
        return humans.contains { $0.id.uuidString == payerId } ? payerId : nil
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

@MainActor
struct PetDocumentCommandExecutor {
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
    func createDocument(
        input: PetDocumentCreateCommandInput,
        pet: Pet,
        note: String
    ) -> PetDocumentCommandResult {
        let result = PetDocumentCommandService.createDocument(input: input, pet: pet, context: context)
        revisions.publishPetDocumentCreate(result, category: input.category, note: note)
        return result
    }

    @discardableResult
    func updateDocument(
        _ document: PetDocument,
        pet: Pet,
        input: PetDocumentUpdateCommandInput,
        note: String
    ) -> PetDocumentCommandResult {
        let result = PetDocumentCommandService.updateDocument(document, pet: pet, input: input, context: context)
        revisions.publishPetDocumentUpdate(result, note: note)
        return result
    }

    @discardableResult
    func deleteDocument(
        _ document: PetDocument,
        pet: Pet,
        note: String
    ) -> PetDocumentDeleteCommandResult {
        let result = PetDocumentCommandService.deleteDocument(document, pet: pet, context: context)
        revisions.publishPetDocumentDelete(result, note: note)
        return result
    }
}
