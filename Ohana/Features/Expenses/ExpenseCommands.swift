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

nonisolated struct PetExpenseUpdateInput: Equatable, Sendable {
    let amount: Double
    let date: Date
    let category: ExpenseCategory
    let note: String
    let payerID: UUID?
    /// Nil preserves the stored payer attribution, including anonymous historical shares.
    let payerContributions: [ExpensePayerContribution]?
}

nonisolated struct PetExpenseUpdateCommandResult: Equatable, Sendable {
    let petID: UUID
    let logID: UUID
    let ledgerEventIDs: [UUID]
    let documentIDs: [UUID]
    let sharedSessionID: UUID?
    let didChange: Bool

    var affectedEntityIDs: Set<UUID> {
        var ids = Set(ledgerEventIDs + documentIDs + [petID, logID])
        if let sharedSessionID {
            ids.insert(sharedSessionID)
        }
        return ids
    }
}

nonisolated enum PetExpenseUpdateError: LocalizedError, Equatable, Sendable {
    case invalidRecord
    case inactivePet
    case payerAllocationRequired
    case reimbursementAmountLocked
    case persistenceFailed(String?)

    var errorDescription: String? {
        let l = L10n.current
        return switch self {
        case .invalidRecord:
            l.tr(
                zh: "这条花费记录无法编辑。",
                en: "This expense record cannot be edited.",
                de: "Dieser Ausgabeneintrag kann nicht bearbeitet werden."
            )
        case .inactivePet:
            l.tr(
                zh: "纪念档案中的花费记录无法编辑。",
                en: "Expenses in a memorial profile cannot be edited.",
                de: "Ausgaben in einem Erinnerungsprofil können nicht bearbeitet werden."
            )
        case .payerAllocationRequired:
            l.tr(
                zh: "更改总金额前，请重新选择支付人并分配金额。",
                en: "Select payers and allocate their shares before changing the total.",
                de: "Wähle vor der Änderung des Gesamtbetrags die Zahlenden und ihre Anteile erneut aus."
            )
        case .reimbursementAmountLocked:
            l.tr(
                zh: "保险报销金额不能从花费记录中修改。",
                en: "Insurance reimbursement amounts cannot be changed from expenses.",
                de: "Versicherungserstattungen können nicht über Ausgaben geändert werden."
            )
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                l.tr(
                    zh: "花费保存失败：\(reason)",
                    en: "Could not save the expense: \(reason)",
                    de: "Die Ausgabe konnte nicht gespeichert werden: \(reason)"
                )
            } else {
                l.tr(
                    zh: "花费保存失败，请重试。",
                    en: "Could not save the expense. Try again.",
                    de: "Die Ausgabe konnte nicht gespeichert werden. Versuche es erneut."
                )
            }
        }
    }
}

nonisolated enum ExpenseSubjectPolicyError: LocalizedError, Equatable, Sendable {
    case humanSubjectNotSupported

    var errorDescription: String? {
        L10n.current.tr(
            zh: "花费只能记录在宠物档案中。",
            en: "Expenses can only be recorded for a pet.",
            de: "Ausgaben können nur für ein Haustier erfasst werden.",
            es: "Los gastos solo se pueden registrar para una mascota.",
            pt: "As despesas só podem ser registadas para um pet.",
            fr: "Les dépenses ne peuvent être enregistrées que pour un animal.",
            ja: "支出はペットの記録にのみ追加できます。",
            ko: "지출은 반려동물 기록에만 추가할 수 있습니다.",
            it: "Le spese possono essere registrate solo per un animale."
        )
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
    let payerContributions: [ExpensePayerContribution]
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
        payerContributions: [ExpensePayerContribution] = [],
        source: CareLedgerSource = .detail,
        receiptTitle: String? = nil,
        receiptCategory: DocumentCategory? = nil,
        receiptAttachments: [ExpenseReceiptAttachmentDraft] = [],
        awardsReward: Bool = true,
        questManager providedQuestManager: QuestManager? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil
    ) throws -> ExpenseCommandResult {
        try ExpenseAmountPolicy.validateUserExpense(amount)
        let payerContributions = try validatedPayerContributions(
            payerContributions,
            total: amount,
            context: context
        )
        let primaryPayerID = payerContributions.compactMap(\.humanID).first?.uuidString ?? executorId
        let attribution = ExpenseActorAttribution(
            executorId: primaryPayerID,
            recordedByHumanId: recordedByHumanId,
            payerContributions: payerContributions
        ).validated(context: context)
        return recordPetExpenseFact(PetExpenseFactRequest(
            pet: pet,
            amount: amount,
            date: date,
            category: category,
            note: note,
            context: context,
            attribution: attribution,
            payerContributions: payerContributions,
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
            payerContributions: [],
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
            payerContributions: request.payerContributions,
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
    static func updatePetExpense(
        _ log: PetExpenseLog,
        pet: Pet,
        input: PetExpenseUpdateInput,
        context: ModelContext
    ) throws -> PetExpenseUpdateCommandResult {
        guard log.pet?.id == pet.id else {
            throw PetExpenseUpdateError.invalidRecord
        }
        guard MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects else {
            throw PetExpenseUpdateError.inactivePet
        }

        let cleanNote = input.note.trimmingCharacters(in: .whitespacesAndNewlines)
        try ExpenseAmountPolicy.validatePersistedExpense(
            amount: input.amount,
            categoryRaw: input.category.rawValue,
            note: cleanNote
        )
        if log.amount < 0, input.amount != log.amount {
            throw PetExpenseUpdateError.reimbursementAmountLocked
        }
        if input.payerContributions == nil,
           !log.payerContributionsJSON.isEmpty,
           input.amount != log.amount {
            throw PetExpenseUpdateError.payerAllocationRequired
        }

        let payerUpdate = try validatedPayerUpdate(log: log, input: input, context: context)
        let contributions = payerUpdate.contributions
        let requestedPayerRaw = payerUpdate.payerRaw
        let encodedContributions = payerUpdate.encodedContributions
        let didChange = expenseUpdateHasChanges(
            log: log,
            input: input,
            cleanNote: cleanNote,
            payerRaw: requestedPayerRaw,
            encodedContributions: encodedContributions
        )
        guard didChange else {
            return PetExpenseUpdateCommandResult(
                petID: pet.id,
                logID: log.id,
                ledgerEventIDs: [],
                documentIDs: [],
                sharedSessionID: UUID(uuidString: log.sharedSessionId),
                didChange: false
            )
        }

        let linkedLedgerEvents: [CareLedgerEvent]
        let linkedDocuments: [PetDocument]
        do {
            linkedLedgerEvents = try expenseLedgerEvents(logID: log.id, context: context)
            linkedDocuments = try expenseReceiptDocuments(logID: log.id, context: context)
        } catch {
            throw PetExpenseUpdateError.persistenceFailed(error.localizedDescription)
        }

        let modifiedAt = Date()
        let intent = DomainCareFactCreateIntent(
            kind: .expense(
                amount: input.amount,
                category: input.category,
                note: cleanNote,
                sharedSessionId: log.sharedSessionId
            ),
            occurredAt: input.date,
            modifiedAt: modifiedAt,
            executorId: requestedPayerRaw,
            source: input.amount < 0 ? .domainService : .userCommand
        )
        guard let write = DomainCareFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            intent: intent,
            context: context,
            logPrefix: "ExpenseCommandService.updatePetExpense"
        ) else {
            throw PetExpenseUpdateError.invalidRecord
        }
        _ = DomainCareFactWriter.upsertExpenseLog(
            plan: write,
            recordedByHumanId: HumanActionAttributionPolicy.activeHumanID(
                log.recordedByHumanId,
                context: context
            ),
            payerContributions: contributions,
            existing: log,
            context: context
        )
        if input.payerContributions == nil {
            // The generic writer may resolve an inactive legacy executor to the
            // current actor. An expense edit without payer intent must keep history.
            log.executorId = requestedPayerRaw
        }

        updateLinkedExpenseFacts(
            log: log,
            pet: pet,
            input: input,
            cleanNote: cleanNote,
            events: linkedLedgerEvents,
            documents: linkedDocuments,
            modifiedAt: modifiedAt,
            context: context
        )

        let sharedSessionID = UUID(uuidString: log.sharedSessionId)
        SharedCareSessionMaintenance.reconcileAfterDeletingChild(
            sharedSessionId: log.sharedSessionId,
            context: context,
            reconciledAt: modifiedAt
        )

        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw PetExpenseUpdateError.persistenceFailed(saveResult.errorDescription)
        }
        return PetExpenseUpdateCommandResult(
            petID: pet.id,
            logID: log.id,
            ledgerEventIDs: linkedLedgerEvents.map(\.id),
            documentIDs: linkedDocuments.map(\.id),
            sharedSessionID: sharedSessionID,
            didChange: true
        )
    }

    private struct PetExpensePayerUpdate {
        let contributions: [ExpensePayerContribution]?
        let payerRaw: String?
        let encodedContributions: String
    }

    private static func expenseUpdateHasChanges(
        log: PetExpenseLog,
        input: PetExpenseUpdateInput,
        cleanNote: String,
        payerRaw: String?,
        encodedContributions: String
    ) -> Bool {
        log.amount != input.amount
            || log.date != input.date
            || log.category != input.category.rawValue
            || log.note != cleanNote
            || log.executorId != payerRaw
            || log.payerContributionsJSON != encodedContributions
    }

    @MainActor
    private static func updateLinkedExpenseFacts(
        log: PetExpenseLog,
        pet: Pet,
        input: PetExpenseUpdateInput,
        cleanNote: String,
        events: [CareLedgerEvent],
        documents: [PetDocument],
        modifiedAt: Date,
        context: ModelContext
    ) {
        for event in events {
            event.occurredAt = input.date
            event.actorKind = log.executorId == nil
                ? CareLedgerActorKind.unknown.rawValue
                : CareLedgerActorKind.human.rawValue
            event.actorId = log.executorId
            event.subjectKind = CareLedgerSubjectKind.pet.rawValue
            event.subjectId = pet.id.uuidString
            event.eventKind = CareLedgerEventKind.expense.rawValue
            event.actionType = input.category.rawValue
            event.amountValue = input.amount
            event.amountUnit = "currency"
            event.note = cleanNote
            CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: modifiedAt)
        }

        for document in documents {
            document.cost = input.amount
            document.issueDate = input.date
            document.notes = ExpenseReceiptMetadata.notes(
                visibleNote: cleanNote,
                expenseLogId: log.id.uuidString
            )
            CloudSyncMutationRecorder.markModified(document, context: context, modifiedAt: modifiedAt)
        }
    }

    @MainActor
    private static func validatedPayerUpdate(
        log: PetExpenseLog,
        input: PetExpenseUpdateInput,
        context: ModelContext
    ) throws -> PetExpensePayerUpdate {
        let contributions: [ExpensePayerContribution]?
        if input.amount < 0 {
            guard input.payerContributions?.isEmpty != false else {
                throw ExpensePayerContributionError.invalidAllocation
            }
            contributions = input.payerContributions
        } else if let requestedContributions = input.payerContributions {
            contributions = try validatedPayerContributions(
                requestedContributions,
                total: input.amount,
                context: context
            )
        } else {
            contributions = nil
        }

        let requestedPayerID = contributions?.compactMap(\.humanID).first ?? input.payerID
        if input.payerContributions != nil, let requestedPayerID,
           HumanActionAttributionPolicy.activeHumanID(
               requestedPayerID.uuidString,
               context: context
           ) == nil {
            throw ExpensePayerContributionError.inactivePayer
        }
        return PetExpensePayerUpdate(
            contributions: contributions,
            payerRaw: input.payerContributions == nil ? log.executorId : requestedPayerID?.uuidString,
            encodedContributions: contributions.map(ExpensePayerContributionPolicy.encode)
                ?? log.payerContributionsJSON
        )
    }

    @MainActor
    private static func expenseLedgerEvents(
        logID: UUID,
        context: ModelContext
    ) throws -> [CareLedgerEvent] {
        let logIDString = logID.uuidString
        return try context.fetch(FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.legacyModelName == "PetExpenseLog" && event.legacyModelId == logIDString
            }
        ))
    }

    @MainActor
    private static func expenseReceiptDocuments(
        logID: UUID,
        context: ModelContext
    ) throws -> [PetDocument] {
        let logIDString = logID.uuidString
        return try context.fetch(FetchDescriptor<PetDocument>(
            predicate: #Predicate<PetDocument> { document in
                document.notes.contains(logIDString)
            }
        )).filter {
            ExpenseReceiptMetadata.expenseLogId(from: $0.notes) == logIDString
        }
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
        payerContributions: [ExpensePayerContribution] = [],
        source: CareLedgerSource = .detail,
        careEvents providedCareEvents: CareEventRecording? = nil
    ) throws -> SharedPetActionResult {
        try ExpenseAmountPolicy.validateUserExpense(amount)
        guard let minorUnits = ExpensePayerContributionPolicy.minorUnits(amount),
              minorUnits > 0 else {
            throw ExpenseAmountValidationError.invalidUserExpense
        }
        let payerContributions = try validatedPayerContributions(
            payerContributions,
            total: amount,
            context: context
        )
        let primaryPayerID = payerContributions.compactMap(\.humanID).first?.uuidString ?? executorId
        let careEvents = providedCareEvents ?? CareEventService()
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let attribution = ExpenseActorAttribution(
            executorId: primaryPayerID,
            recordedByHumanId: recordedByHumanId,
            payerContributions: payerContributions
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

    @MainActor
    private static func validatedPayerContributions(
        _ contributions: [ExpensePayerContribution],
        total: Double,
        context: ModelContext
    ) throws -> [ExpensePayerContribution] {
        guard !contributions.isEmpty else { return [] }
        let validated = try ExpensePayerContributionPolicy.validated(contributions, total: total)
        for contribution in validated {
            guard let humanID = contribution.humanID else {
                throw ExpensePayerContributionError.invalidAllocation
            }
            guard HumanActionAttributionPolicy.activeHumanID(
                humanID.uuidString,
                context: context
            ) != nil else {
                throw ExpensePayerContributionError.inactivePayer
            }
        }
        return validated
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
        throw ExpenseSubjectPolicyError.humanSubjectNotSupported
    }
}
