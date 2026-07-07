//
//  InsuranceCommands.swift
//  Ohana
//
//  Domain write boundaries for pet insurance policies and claims.
//

import Foundation
import SwiftData

struct InsuranceClaimCommandInput: Equatable {
    let claimDate: Date
    let incidentDate: Date
    let totalExpense: Double
    let claimedAmount: Double
    let status: ClaimStatus
    let note: String
    let executorId: String?
    let relatedExpenseLogId: String?
    let approvedAt: Date?

    init(
        claimDate: Date = Date(),
        incidentDate: Date,
        totalExpense: Double,
        claimedAmount: Double,
        status: ClaimStatus,
        note: String,
        executorId: String?,
        relatedExpenseLogId: String? = nil,
        approvedAt: Date? = nil
    ) {
        self.claimDate = claimDate
        self.incidentDate = incidentDate
        self.totalExpense = max(0, totalExpense.isFinite ? totalExpense : 0)
        self.claimedAmount = max(0, claimedAmount.isFinite ? claimedAmount : 0)
        self.status = status
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.executorId = executorId
        self.relatedExpenseLogId = relatedExpenseLogId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.approvedAt = approvedAt
    }
}

struct InsurancePolicySaveCommandInput: Equatable {
    let companyName: String
    let policyNumber: String
    let productName: String
    let annualPremium: Double
    let coverageAmount: Double
    let startDate: Date
    let renewalDate: Date
    let notes: String
    let paymentFrequency: InsurancePaymentFrequency
    let paymentDayOfMonth: Int
    let showInCalendar: Bool
    let otherFeeAmount: Double
    let otherFeeNote: String
    let autoGeneratesPayments: Bool
    let executorId: String?

    init(
        companyName: String,
        policyNumber: String,
        productName: String,
        annualPremium: Double,
        coverageAmount: Double,
        startDate: Date,
        renewalDate: Date,
        notes: String,
        paymentFrequency: InsurancePaymentFrequency,
        paymentDayOfMonth: Int,
        showInCalendar: Bool,
        otherFeeAmount: Double,
        otherFeeNote: String,
        autoGeneratesPayments: Bool,
        executorId: String?
    ) {
        self.companyName = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.policyNumber = policyNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.productName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.annualPremium = max(0, annualPremium.isFinite ? annualPremium : 0)
        self.coverageAmount = max(0, coverageAmount.isFinite ? coverageAmount : 0)
        self.startDate = startDate
        self.renewalDate = renewalDate
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.paymentFrequency = paymentFrequency
        self.paymentDayOfMonth = max(1, min(28, paymentDayOfMonth))
        self.showInCalendar = showInCalendar
        self.otherFeeAmount = max(0, otherFeeAmount.isFinite ? otherFeeAmount : 0)
        self.otherFeeNote = otherFeeNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.autoGeneratesPayments = autoGeneratesPayments
        self.executorId = executorId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

struct InsurancePolicyCommandResult: Equatable {
    let policyID: UUID
    let petID: UUID
    let didChange: Bool
    let expenseLogIDs: [UUID]
    let eventIDs: [UUID]

    init(
        policyID: UUID,
        petID: UUID,
        didChange: Bool,
        expenseLogIDs: [UUID] = [],
        eventIDs: [UUID] = []
    ) {
        self.policyID = policyID
        self.petID = petID
        self.didChange = didChange
        self.expenseLogIDs = expenseLogIDs
        self.eventIDs = eventIDs
    }
}

struct InsuranceClaimCommandResult: Equatable {
    let claimID: UUID
    let policyID: UUID
    let petID: UUID
    let expenseLogID: UUID?
    let didChange: Bool
}

enum InsuranceCommandError: LocalizedError, Equatable {
    case persistenceFailed(String?)

    var errorDescription: String? {
        switch self {
        case let .persistenceFailed(reason):
            if let reason, !reason.isEmpty {
                return "保险信息保存失败：\(reason)"
            }
            return "保险信息保存失败，请稍后重试。"
        }
    }
}

enum InsurancePolicyCommandService {
    @discardableResult
    @MainActor
    static func savePolicy(
        existing insurance: PetInsurance?,
        pet: Pet,
        input: InsurancePolicySaveCommandInput,
        context: ModelContext
    ) throws -> InsurancePolicyCommandResult {
        let modifiedAt = insurance == nil ? input.startDate : Date()
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: input.startDate,
            modifiedAt: modifiedAt,
            writeKind: .care,
            source: .userCommand,
            executorId: input.executorId,
            context: context,
            logPrefix: "InsurancePolicyCommandService.savePolicy"
        ) else {
            return InsurancePolicyCommandResult(
                policyID: insurance?.id ?? UUID(),
                petID: pet.id,
                didChange: false
            )
        }
        if let insurance {
            DomainMemberFactWriter.updatePetInsurancePolicy(
                plan: write,
                insurance: insurance,
                companyName: input.companyName,
                policyNumber: input.policyNumber,
                productName: input.productName,
                annualPremium: input.annualPremium,
                coverageAmount: input.coverageAmount,
                startDate: input.startDate,
                renewalDate: input.renewalDate,
                notes: input.notes,
                paymentFrequency: input.paymentFrequency,
                paymentDayOfMonth: input.paymentDayOfMonth,
                showInCalendar: input.showInCalendar,
                otherFeeAmount: input.otherFeeAmount,
                otherFeeNote: input.otherFeeNote,
                context: context
            )
            try saveInsuranceChanges(context: context)
            return InsurancePolicyCommandResult(
                policyID: insurance.id,
                petID: pet.id,
                didChange: true
            )
        }

        let insurance = DomainMemberFactWriter.createPetInsurancePolicy(
            plan: write,
            companyName: input.companyName,
            policyNumber: input.policyNumber,
            productName: input.productName,
            annualPremium: input.annualPremium,
            coverageAmount: input.coverageAmount,
            startDate: input.startDate,
            renewalDate: input.renewalDate,
            notes: input.notes,
            paymentFrequency: input.paymentFrequency,
            paymentDayOfMonth: input.paymentDayOfMonth,
            showInCalendar: input.showInCalendar,
            otherFeeAmount: input.otherFeeAmount,
            otherFeeNote: input.otherFeeNote,
            pet: pet,
            context: context
        )

        let schedule = input.autoGeneratesPayments && input.annualPremium > 0
            ? generatePaymentSchedule(for: insurance, pet: pet, executorId: input.executorId, context: context)
            : (expenseIDs: [], events: [])
        try saveInsuranceChanges(context: context)
        return InsurancePolicyCommandResult(
            policyID: insurance.id,
            petID: pet.id,
            didChange: true,
            expenseLogIDs: schedule.expenseIDs,
            eventIDs: schedule.events.map(\.id)
        )
    }

    @discardableResult
    @MainActor
    static func setPolicyActive(
        _ insurance: PetInsurance,
        isActive: Bool,
        pet: Pet,
        context: ModelContext
    ) throws -> InsurancePolicyCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: Date(),
            writeKind: .care,
            context: context,
            logPrefix: "InsurancePolicyCommandService.setPolicyActive"
        ) else {
            return InsurancePolicyCommandResult(policyID: insurance.id, petID: pet.id, didChange: false)
        }
        let didChange = DomainMemberFactWriter.setPetInsurancePolicyActive(
            plan: write,
            insurance: insurance,
            isActive: isActive,
            context: context
        )
        if didChange {
            try saveInsuranceChanges(context: context)
        }
        return InsurancePolicyCommandResult(
            policyID: insurance.id,
            petID: pet.id,
            didChange: didChange
        )
    }

    @discardableResult
    @MainActor
    static func deletePolicy(
        _ insurance: PetInsurance,
        pet: Pet,
        context: ModelContext
    ) throws -> InsurancePolicyCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: Date(),
            writeKind: .care,
            context: context,
            logPrefix: "InsurancePolicyCommandService.deletePolicy"
        ) else {
            return InsurancePolicyCommandResult(policyID: insurance.id, petID: pet.id, didChange: false)
        }
        let policyID = insurance.id
        let petID = pet.id
        DomainMemberFactWriter.deletePetInsurancePolicy(plan: write, insurance: insurance, pet: pet, context: context)
        try saveInsuranceChanges(context: context)
        return InsurancePolicyCommandResult(
            policyID: policyID,
            petID: petID,
            didChange: true
        )
    }

    @discardableResult
    @MainActor
    static func createClaim(
        insurance: PetInsurance,
        pet: Pet,
        input: InsuranceClaimCommandInput,
        context: ModelContext
    ) throws -> InsuranceClaimCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: input.claimDate,
            writeKind: .care,
            source: .userCommand,
            executorId: input.executorId,
            context: context,
            logPrefix: "InsurancePolicyCommandService.createClaim"
        ) else {
            return InsuranceClaimCommandResult(
                claimID: UUID(),
                policyID: insurance.id,
                petID: pet.id,
                expenseLogID: nil,
                didChange: false
            )
        }
        let approvedAmount = input.status == .approved ? input.claimedAmount : 0
        let approvedAt = input.status == .approved ? (input.approvedAt ?? input.claimDate) : nil
        let claim = DomainMemberFactWriter.createInsuranceClaim(
            plan: write,
            claimDate: input.claimDate,
            incidentDate: input.incidentDate,
            totalExpense: input.totalExpense,
            claimedAmount: input.claimedAmount,
            approvedAmount: approvedAmount,
            status: input.status,
            note: input.note,
            relatedExpenseLogId: input.relatedExpenseLogId,
            approvedAt: approvedAt,
            insurance: insurance,
            context: context
        )

        let expenseID = makeReimbursementExpenseIfNeeded(
            insurance: insurance,
            pet: pet,
            amount: approvedAmount,
            approvedDate: approvedAt ?? input.claimDate,
            executorId: input.executorId,
            context: context
        )

        try saveInsuranceChanges(context: context)
        return InsuranceClaimCommandResult(
            claimID: claim.id,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: expenseID,
            didChange: true
        )
    }

    @discardableResult
    @MainActor
    static func updateClaimStatus(
        _ claim: InsuranceClaim,
        to status: ClaimStatus,
        insurance: PetInsurance,
        pet: Pet,
        context: ModelContext,
        approvedAt: Date = Date(),
        executorId: String? = nil
    ) throws -> InsuranceClaimCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: approvedAt,
            writeKind: .care,
            source: .userCommand,
            executorId: executorId,
            context: context,
            logPrefix: "InsurancePolicyCommandService.updateClaimStatus"
        ) else {
            return InsuranceClaimCommandResult(
                claimID: claim.id,
                policyID: insurance.id,
                petID: pet.id,
                expenseLogID: nil,
                didChange: false
            )
        }
        let oldStatus = claim.claimStatus
        let oldApprovedAmount = claim.approvedAmount

        var expenseID: UUID?
        let nextApprovedAmount: Double
        let nextApprovedAt: Date?
        if status == .approved, claim.approvedAmount == 0 {
            nextApprovedAmount = claim.claimedAmount
            nextApprovedAt = approvedAt
            expenseID = makeReimbursementExpenseIfNeeded(
                insurance: insurance,
                pet: pet,
                amount: nextApprovedAmount,
                approvedDate: approvedAt,
                executorId: executorId,
                context: context
            )
        } else {
            nextApprovedAmount = claim.approvedAmount
            nextApprovedAt = claim.approvedAt
        }
        let didChange = DomainMemberFactWriter.updateInsuranceClaimStatus(
            plan: write,
            claim: claim,
            status: status,
            approvedAmount: nextApprovedAmount,
            approvedAt: nextApprovedAt,
            context: context
        )

        if didChange || oldStatus != status || oldApprovedAmount != nextApprovedAmount {
            try saveInsuranceChanges(context: context)
        }
        return InsuranceClaimCommandResult(
            claimID: claim.id,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: expenseID,
            didChange: didChange || oldStatus != status || oldApprovedAmount != nextApprovedAmount
        )
    }

    @discardableResult
    @MainActor
    static func deleteClaim(
        _ claim: InsuranceClaim,
        insurance: PetInsurance,
        pet: Pet,
        context: ModelContext
    ) throws -> InsuranceClaimCommandResult {
        guard let write = DomainMemberFactWriteAuthorizer.authorizePetFact(
            pet: pet,
            occurredAt: Date(),
            writeKind: .care,
            context: context,
            logPrefix: "InsurancePolicyCommandService.deleteClaim"
        ) else {
            return InsuranceClaimCommandResult(
                claimID: claim.id,
                policyID: insurance.id,
                petID: pet.id,
                expenseLogID: nil,
                didChange: false
            )
        }
        let claimID = claim.id
        DomainMemberFactWriter.deleteInsuranceClaim(plan: write, claim: claim, pet: pet, context: context)
        try saveInsuranceChanges(context: context)
        return InsuranceClaimCommandResult(
            claimID: claimID,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: nil,
            didChange: true
        )
    }

    @MainActor
    private static func saveInsuranceChanges(context: ModelContext) throws {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            throw InsuranceCommandError.persistenceFailed(saveResult.errorDescription)
        }
    }

    @MainActor
    private static func makeReimbursementExpenseIfNeeded(
        insurance: PetInsurance,
        pet: Pet,
        amount: Double,
        approvedDate: Date,
        executorId: String?,
        context: ModelContext
    ) -> UUID? {
        guard amount > 0 else { return nil }
        let productName = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let note = InsuranceReimbursementExpenseWriter.reimbursementNote(productName: productName)
        guard InsuranceReimbursementExpenseWriter.shouldInsertReimbursementLog(
            existingLogs: pet.expenseLogs,
            date: approvedDate,
            amount: amount,
            note: note
        ) else { return nil }

        let result = ExpenseCommandService.recordPetExpense(
            pet: pet,
            amount: -amount,
            date: approvedDate,
            category: .insurancePremium,
            note: note,
            context: context,
            executorId: executorId,
            source: .detail,
            awardsReward: false
        )
        return result.logID
    }

    @discardableResult
    @MainActor
    private static func generatePaymentSchedule(
        for insurance: PetInsurance,
        pet: Pet,
        executorId: String?,
        context: ModelContext
    ) -> (expenseIDs: [UUID], events: [Event]) {
        let dates = InsurancePaymentSchedule.dates(for: insurance, calendar: .current)
        let name = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let perPeriodBase = insurance.paymentFrequency.periodAmount(fromAnnual: insurance.annualPremium)
        let perPeriod = perPeriodBase + insurance.otherFeeAmount
        var expenseIDs: [UUID] = []
        var events: [Event] = []

        for (index, payDate) in dates.enumerated() {
            let otherNote = insurance.otherFeeNote.isEmpty ? "其他费用" : insurance.otherFeeNote
            let expNote = index == 0
                ? "\(name) 首期保费\(insurance.otherFeeAmount > 0 ? "（含\(otherNote)）" : "")"
                : "\(name) 保费\(insurance.otherFeeAmount > 0 ? "（含\(otherNote)）" : "")"
            let expense = ExpenseCommandService.recordPetExpense(
                pet: pet,
                amount: perPeriod,
                date: payDate,
                category: .insurancePremium,
                note: expNote,
                context: context,
                executorId: executorId,
                source: .detail,
                awardsReward: false
            )
            expenseIDs.append(expense.logID)

            if insurance.showInCalendar {
                let intent = DomainScheduleCreateIntent(
                    title: L10n.current.tr(
                        zh: "🛡️ \(name) 缴费",
                        en: "🛡️ \(name) premium payment",
                        de: "🛡️ \(name) Versicherungszahlung"
                    ),
                    startDate: payDate,
                    isAllDay: true,
                    eventType: EventType.insurancePremium.rawValue,
                    relatedEntityType: DomainEntityLinkRegistry.petInsurance,
                    relatedEntityId: insurance.id.uuidString,
                    writeKind: .care,
                    source: .domainService
                )
                guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(intent: intent, context: context) else {
                    continue
                }
                let event = DomainScheduleWriter.createEvent(plan: plan, context: context).event
                CloudSyncMutationRecorder.markModified(event, context: context, modifiedAt: payDate)
                events.append(event)
            }
        }
        return (expenseIDs, events)
    }
}

@MainActor
struct InsuranceCommandExecutor {
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
    func savePolicy(
        existing insurance: PetInsurance?,
        pet: Pet,
        input: InsurancePolicySaveCommandInput,
        note: String
    ) throws -> InsurancePolicyCommandResult {
        let result = try InsurancePolicyCommandService.savePolicy(
            existing: insurance,
            pet: pet,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishInsurancePolicy(
                result,
                action: insurance == nil ? "create" : "update",
                note: note
            )
        }
        return result
    }

    @discardableResult
    func setPolicyActive(
        _ insurance: PetInsurance,
        isActive: Bool,
        pet: Pet,
        note: String
    ) throws -> InsurancePolicyCommandResult {
        let result = try InsurancePolicyCommandService.setPolicyActive(
            insurance,
            isActive: isActive,
            pet: pet,
            context: context
        )
        if result.didChange {
            revisions.publishInsurancePolicy(
                result,
                action: isActive ? "activate" : "deactivate",
                note: note
            )
        }
        return result
    }

    @discardableResult
    func deletePolicy(_ insurance: PetInsurance, pet: Pet, note: String) throws -> InsurancePolicyCommandResult {
        let result = try InsurancePolicyCommandService.deletePolicy(insurance, pet: pet, context: context)
        if result.didChange {
            revisions.publishInsurancePolicy(result, action: "delete", note: note)
        }
        return result
    }

    @discardableResult
    func createClaim(
        insurance: PetInsurance,
        pet: Pet,
        input: InsuranceClaimCommandInput,
        note: String
    ) throws -> InsuranceClaimCommandResult {
        let result = try InsurancePolicyCommandService.createClaim(
            insurance: insurance,
            pet: pet,
            input: input,
            context: context
        )
        if result.didChange {
            revisions.publishInsuranceClaim(result, action: "create", note: note)
        }
        return result
    }

    @discardableResult
    func updateClaimStatus(
        _ claim: InsuranceClaim,
        to status: ClaimStatus,
        insurance: PetInsurance,
        pet: Pet,
        executorId: String?,
        note: String
    ) throws -> InsuranceClaimCommandResult {
        let result = try InsurancePolicyCommandService.updateClaimStatus(
            claim,
            to: status,
            insurance: insurance,
            pet: pet,
            context: context,
            executorId: executorId
        )
        if result.didChange {
            revisions.publishInsuranceClaim(result, action: "status.\(status.rawValue)", note: note)
        }
        return result
    }

    @discardableResult
    func deleteClaim(
        _ claim: InsuranceClaim,
        insurance: PetInsurance,
        pet: Pet,
        note: String
    ) throws -> InsuranceClaimCommandResult {
        let result = try InsurancePolicyCommandService.deleteClaim(
            claim,
            insurance: insurance,
            pet: pet,
            context: context
        )
        if result.didChange {
            revisions.publishInsuranceClaim(result, action: "delete", note: note)
        }
        return result
    }
}
