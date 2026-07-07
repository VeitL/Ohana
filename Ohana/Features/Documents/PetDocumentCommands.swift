//
//  PetDocumentCommands.swift
//  Ohana
//
//  Pet document write boundary and revision publishing.
//

import Foundation
import SwiftData

@MainActor
private func fetchPetDocumentModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "PetDocumentCommands failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

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
    let didChange: Bool
}

struct PetDocumentDeleteCommandResult: Equatable {
    let petID: UUID
    let documentID: UUID
    let removedLedgerEventIDs: [UUID]
    let didChange: Bool
}

enum PetDocumentCommandError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        let l = L10n.current
        switch self {
        case let .persistenceFailed(reason):
            let detail = reason.map { "\n\($0)" } ?? ""
            return l.tr(
                zh: "证件保存失败，请稍后重试。\(detail)",
                en: "Could not save the document. Try again.\(detail)",
                de: "Dokument konnte nicht gespeichert werden. Versuche es erneut.\(detail)"
            )
        }
    }
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
    ) throws -> PetDocumentCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: now,
            writeKind: writeKind(for: input),
            context: context,
            logPrefix: "PetDocumentCommandService.createDocument"
        ) else {
            return PetDocumentCommandResult(petID: pet.id, documentID: UUID(), expenseLogIDs: [], ledgerEventIDs: [], didChange: false)
        }
        let careLedger = providedCareLedger ?? CareLedgerService()
        let finalTitle = input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(pet.name)\(input.category.rawValue)"
            : input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = DomainMemberFactWriter.createPetDocument(
            plan: write,
            title: finalTitle,
            category: input.category,
            pet: pet,
            context: context
        )
        document.issuingAuthority = input.issuingAuthority
        document.notes = input.notes
        document.issueDate = input.issueDate
        document.expiryDate = input.expiryDate
        document.cost = max(0, input.cost)
        applyAttachments(input.attachments, to: document, write: write, context: context)

        let expenseWrites = write.allowsDerivedEffects
            ? makeExpensesIfNeeded(
                pet: pet,
                document: document,
                category: input.category,
                amount: document.cost,
                issueDate: input.issueDate,
                payerId: validPayerId(input.payerId, context: context),
                now: now,
                context: context
            )
            : []

        CloudSyncMutationRecorder.markModified(document, context: context, modifiedAt: now)
        if write.allowsDerivedEffects,
           !input.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           input.category == .passport {
            pet.passportNumber = input.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let ledgerEvents = expenseWrites.compactMap { expenseWrite in
            let expense = expenseWrite.expense
            let write = expenseWrite.write
            var ledgerEvent: CareLedgerEvent?
            DomainCareFactEffectsDispatcher.run(plan: write) { actor in
                expense.executorId = actor.effectiveExecutorId
                CloudSyncMutationRecorder.markModified(expense, context: context, modifiedAt: expense.date)
                ledgerEvent = careLedger.record(
                    occurredAt: expense.date,
                    actorKind: actor.effectiveExecutorId == nil ? .unknown : .human,
                    actorId: actor.effectiveExecutorId,
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
            return ledgerEvent
        }

        try saveDocumentChanges(context: context)
        return PetDocumentCommandResult(
            petID: pet.id,
            documentID: document.id,
            expenseLogIDs: expenseWrites.map { expenseWrite in expenseWrite.expense.id },
            ledgerEventIDs: ledgerEvents.map(\.id),
            didChange: true
        )
    }

    @discardableResult
    @MainActor
    static func updateDocument(
        _ document: PetDocument,
        pet: Pet,
        input: PetDocumentUpdateCommandInput,
        context: ModelContext
    ) throws -> PetDocumentCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: Date(),
            writeKind: writeKind(for: input),
            context: context,
            logPrefix: "PetDocumentCommandService.updateDocument"
        ) else {
            return PetDocumentCommandResult(petID: pet.id, documentID: document.id, expenseLogIDs: [], ledgerEventIDs: [], didChange: false)
        }
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
            document.updateLegacyAttachment(data: nil, filename: "")
            document.attachments.removeAll()
        } else if !input.attachments.isEmpty {
            applyAttachments(input.attachments, to: document, write: write, context: context)
        } else if let data = input.attachmentData {
            let filename = document.attachmentFilename.isEmpty ? "image.jpg" : document.attachmentFilename
            let sanitizedData = AttachmentPrivacySanitizer.sanitizedData(
                data,
                filename: filename,
                isImage: AttachmentPrivacySanitizer.isImageFilename(filename)
            )
            document.updateLegacyAttachment(data: sanitizedData, filename: filename)
        }
        CloudSyncMutationRecorder.markModified(document, context: context)
        try saveDocumentChanges(context: context)
        return PetDocumentCommandResult(
            petID: pet.id,
            documentID: document.id,
            expenseLogIDs: [],
            ledgerEventIDs: [],
            didChange: true
        )
    }

    @discardableResult
    @MainActor
    static func deleteDocument(
        _ document: PetDocument,
        pet: Pet,
        context: ModelContext
    ) throws -> PetDocumentDeleteCommandResult {
        let disposition = MemberLifecycleGate.disposition(pet: pet, writeKind: writeKind(for: document))
        guard disposition.writesContent else {
            return PetDocumentDeleteCommandResult(petID: pet.id, documentID: document.id, removedLedgerEventIDs: [], didChange: false)
        }
        let documentID = document.id
        PhysicalDeletionService.deleteDocument(document, pet: pet, context: context)
        try saveDocumentChanges(context: context)
        return PetDocumentDeleteCommandResult(
            petID: pet.id,
            documentID: documentID,
            removedLedgerEventIDs: [],
            didChange: true
        )
    }

    @MainActor
    private static func saveDocumentChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw PetDocumentCommandError.persistenceFailed(saveResult.errorDescription)
        }
    }

    @MainActor
    private static func applyAttachments(
        _ attachments: [PetDocumentAttachmentCommandInput],
        to document: PetDocument,
        write: AuthorizedDomainMemberFactWrite,
        context: ModelContext
    ) {
        guard let first = attachments.first else { return }
        let sanitizedAttachments = attachments.map(sanitizedAttachment)
        let sanitizedFirst = sanitizedAttachments[0]
        let legacyFilename = first.filename.isEmpty
            ? (first.isImage ? "image.jpg" : "attachment")
            : first.filename
        document.updateLegacyAttachment(data: sanitizedFirst.data, filename: legacyFilename)
        document.attachments.removeAll()
        for input in sanitizedAttachments {
            _ = DomainMemberFactWriter.createPetDocumentAttachment(
                plan: write,
                data: input.data,
                filename: input.filename.isEmpty ? (input.isImage ? "image.jpg" : "attachment") : input.filename,
                isImage: input.isImage,
                document: document,
                context: context
            )
        }
    }

    private static func writeKind(for input: PetDocumentCreateCommandInput) -> MemberWriteKind {
        if input.cost > 0 ||
            input.expiryDate != nil ||
            (input.category == .passport && !input.documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            return .care
        }
        return .memorial
    }

    private static func writeKind(for input: PetDocumentUpdateCommandInput) -> MemberWriteKind {
        if input.cost > 0 || input.expiryDate != nil || input.category == .passport {
            return .care
        }
        return .memorial
    }

    private static func writeKind(for document: PetDocument) -> MemberWriteKind {
        let category = DocumentCategory(rawValue: document.category)
        if document.cost > 0 || document.expiryDate != nil || category == .passport {
            return .care
        }
        return .memorial
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
    ) -> [(expense: PetExpenseLog, write: AuthorizedDomainCareFactWrite)] {
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
        return plans.compactMap { plan in
            let intent = DomainCareFactCreateIntent(
                kind: .expense(
                    amount: plan.amount,
                    category: plan.category,
                    note: plan.note,
                    sharedSessionId: ""
                ),
                occurredAt: plan.date,
                executorId: plan.payerId,
                source: .userCommand
            )
            guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
                pet: pet,
                intent: intent,
                context: context,
                logPrefix: "PetDocumentCommandService.makeExpensesIfNeeded"
            ) else { return nil }
            return (
                expense: DomainCareFactWriter.createExpenseLog(plan: write, context: context),
                write: write
            )
        }
    }

    @MainActor
    private static func validPayerId(_ payerId: String?, context: ModelContext) -> String? {
        guard let payerId, !payerId.isEmpty, let id = UUID(uuidString: payerId) else { return nil }
        let descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.id == id
            }
        )
        let humans = fetchPetDocumentModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch document payer"
        )
        guard let human = humans.first, EconomyWalletWritePolicy.canWrite(human) else { return nil }
        return payerId
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
        return fetchPetDocumentModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch document ledger events"
        )
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
    ) throws -> PetDocumentCommandResult {
        let result = try PetDocumentCommandService.createDocument(input: input, pet: pet, context: context)
        if result.didChange {
            revisions.publishPetDocumentCreate(result, category: input.category, note: note)
        }
        return result
    }

    @discardableResult
    func updateDocument(
        _ document: PetDocument,
        pet: Pet,
        input: PetDocumentUpdateCommandInput,
        note: String
    ) throws -> PetDocumentCommandResult {
        let result = try PetDocumentCommandService.updateDocument(document, pet: pet, input: input, context: context)
        if result.didChange {
            revisions.publishPetDocumentUpdate(result, note: note)
        }
        return result
    }

    @discardableResult
    func deleteDocument(
        _ document: PetDocument,
        pet: Pet,
        note: String
    ) throws -> PetDocumentDeleteCommandResult {
        let result = try PetDocumentCommandService.deleteDocument(document, pet: pet, context: context)
        if result.didChange {
            revisions.publishPetDocumentDelete(result, note: note)
        }
        return result
    }
}
