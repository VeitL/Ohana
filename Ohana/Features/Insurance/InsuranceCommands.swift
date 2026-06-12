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

enum InsurancePolicyCommandService {
    @discardableResult
    @MainActor
    static func savePolicy(
        existing insurance: PetInsurance?,
        pet: Pet,
        input: InsurancePolicySaveCommandInput,
        context: ModelContext
    ) -> InsurancePolicyCommandResult {
        if let insurance {
            apply(input, to: insurance)
            context.safeSave()
            return InsurancePolicyCommandResult(
                policyID: insurance.id,
                petID: pet.id,
                didChange: true
            )
        }

        let insurance = PetInsurance(
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
            pet: pet
        )
        context.insert(insurance)

        let schedule = input.autoGeneratesPayments && input.annualPremium > 0
            ? generatePaymentSchedule(for: insurance, pet: pet, executorId: input.executorId, context: context)
            : (expenses: [], events: [])
        context.safeSave()
        return InsurancePolicyCommandResult(
            policyID: insurance.id,
            petID: pet.id,
            didChange: true,
            expenseLogIDs: schedule.expenses.map(\.id),
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
    ) -> InsurancePolicyCommandResult {
        let didChange = insurance.isActive != isActive
        insurance.isActive = isActive
        context.safeSave()
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
    ) -> InsurancePolicyCommandResult {
        let policyID = insurance.id
        let petID = pet.id
        RecycleBinService.moveToRecycleBin(insurance, context: context)
        context.safeSave()
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
    ) -> InsuranceClaimCommandResult {
        let approvedAmount = input.status == .approved ? input.claimedAmount : 0
        let approvedAt = input.status == .approved ? (input.approvedAt ?? input.claimDate) : nil
        let claim = InsuranceClaim(
            claimDate: input.claimDate,
            incidentDate: input.incidentDate,
            totalExpense: input.totalExpense,
            claimedAmount: input.claimedAmount,
            approvedAmount: approvedAmount,
            status: input.status,
            note: input.note,
            relatedExpenseLogId: input.relatedExpenseLogId,
            insurance: insurance
        )
        claim.approvedAt = approvedAt
        context.insert(claim)

        let expense = makeReimbursementExpenseIfNeeded(
            insurance: insurance,
            pet: pet,
            amount: approvedAmount,
            approvedDate: approvedAt ?? input.claimDate,
            executorId: input.executorId,
            context: context
        )

        context.safeSave()
        return InsuranceClaimCommandResult(
            claimID: claim.id,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: expense?.id,
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
    ) -> InsuranceClaimCommandResult {
        let oldStatus = claim.claimStatus
        let oldApprovedAmount = claim.approvedAmount
        claim.statusRaw = status.rawValue

        var expense: PetExpenseLog?
        if status == .approved, claim.approvedAmount == 0 {
            claim.approvedAmount = claim.claimedAmount
            claim.approvedAt = approvedAt
            expense = makeReimbursementExpenseIfNeeded(
                insurance: insurance,
                pet: pet,
                amount: claim.approvedAmount,
                approvedDate: approvedAt,
                executorId: executorId,
                context: context
            )
        }

        context.safeSave()
        return InsuranceClaimCommandResult(
            claimID: claim.id,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: expense?.id,
            didChange: oldStatus != status || oldApprovedAmount != claim.approvedAmount
        )
    }

    @discardableResult
    @MainActor
    static func deleteClaim(
        _ claim: InsuranceClaim,
        insurance: PetInsurance,
        pet: Pet,
        context: ModelContext
    ) -> InsuranceClaimCommandResult {
        let claimID = claim.id
        CloudSyncMutationRecorder.markDeleted(claim, pet: pet, context: context)
        context.delete(claim)
        context.safeSave()
        return InsuranceClaimCommandResult(
            claimID: claimID,
            policyID: insurance.id,
            petID: pet.id,
            expenseLogID: nil,
            didChange: true
        )
    }

    @MainActor
    private static func makeReimbursementExpenseIfNeeded(
        insurance: PetInsurance,
        pet: Pet,
        amount: Double,
        approvedDate: Date,
        executorId: String?,
        context: ModelContext
    ) -> PetExpenseLog? {
        guard amount > 0 else { return nil }
        let productName = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let note = InsuranceReimbursementExpenseWriter.reimbursementNote(productName: productName)
        guard InsuranceReimbursementExpenseWriter.shouldInsertReimbursementLog(
            existingLogs: pet.expenseLogs,
            date: approvedDate,
            amount: amount,
            note: note
        ) else { return nil }

        let expense = PetExpenseLog(
            date: approvedDate,
            amount: -amount,
            category: .insurancePremium,
            note: note,
            pet: pet,
            executorId: executorId
        )
        context.insert(expense)
        return expense
    }

    @MainActor
    private static func apply(_ input: InsurancePolicySaveCommandInput, to insurance: PetInsurance) {
        insurance.companyName = input.companyName
        insurance.policyNumber = input.policyNumber
        insurance.productName = input.productName
        insurance.annualPremium = input.annualPremium
        insurance.coverageAmount = input.coverageAmount
        insurance.startDate = input.startDate
        insurance.renewalDate = input.renewalDate
        insurance.notes = input.notes
        insurance.paymentFrequencyRaw = input.paymentFrequency.rawValue
        insurance.paymentDayOfMonth = input.paymentDayOfMonth
        insurance.showInCalendar = input.showInCalendar
        insurance.otherFeeAmount = input.otherFeeAmount
        insurance.otherFeeNote = input.otherFeeNote
    }

    @discardableResult
    @MainActor
    private static func generatePaymentSchedule(
        for insurance: PetInsurance,
        pet: Pet,
        executorId: String?,
        context: ModelContext
    ) -> (expenses: [PetExpenseLog], events: [Event]) {
        let dates = InsurancePaymentSchedule.dates(for: insurance, calendar: .current)
        let name = insurance.productName.isEmpty ? insurance.companyName : insurance.productName
        let perPeriodBase = insurance.paymentFrequency.periodAmount(fromAnnual: insurance.annualPremium)
        let perPeriod = perPeriodBase + insurance.otherFeeAmount
        var expenses: [PetExpenseLog] = []
        var events: [Event] = []

        for (index, payDate) in dates.enumerated() {
            let otherNote = insurance.otherFeeNote.isEmpty ? "其他费用" : insurance.otherFeeNote
            let expNote = index == 0
                ? "\(name) 首期保费\(insurance.otherFeeAmount > 0 ? "（含\(otherNote)）" : "")"
                : "\(name) 保费\(insurance.otherFeeAmount > 0 ? "（含\(otherNote)）" : "")"
            let expense = PetExpenseLog(
                date: payDate,
                amount: perPeriod,
                category: .insurancePremium,
                note: expNote,
                pet: pet,
                executorId: executorId
            )
            context.insert(expense)
            expenses.append(expense)

            if insurance.showInCalendar {
                let event = Event(
                    title: "🛡️ \(name) 缴费",
                    startDate: payDate,
                    isAllDay: true,
                    eventType: EventType.insurancePremium.rawValue,
                    relatedEntityType: "pet_insurance",
                    relatedEntityId: insurance.id.uuidString
                )
                context.insert(event)
                events.append(event)
            }
        }
        return (expenses, events)
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
    ) -> InsurancePolicyCommandResult {
        let result = InsurancePolicyCommandService.savePolicy(
            existing: insurance,
            pet: pet,
            input: input,
            context: context
        )
        revisions.publishInsurancePolicy(
            result,
            action: insurance == nil ? "create" : "update",
            note: note
        )
        return result
    }

    @discardableResult
    func setPolicyActive(
        _ insurance: PetInsurance,
        isActive: Bool,
        pet: Pet,
        note: String
    ) -> InsurancePolicyCommandResult {
        let result = InsurancePolicyCommandService.setPolicyActive(
            insurance,
            isActive: isActive,
            pet: pet,
            context: context
        )
        revisions.publishInsurancePolicy(
            result,
            action: isActive ? "activate" : "deactivate",
            note: note
        )
        return result
    }

    @discardableResult
    func deletePolicy(_ insurance: PetInsurance, pet: Pet, note: String) -> InsurancePolicyCommandResult {
        let result = InsurancePolicyCommandService.deletePolicy(insurance, pet: pet, context: context)
        revisions.publishInsurancePolicy(result, action: "delete", note: note)
        return result
    }

    @discardableResult
    func createClaim(
        insurance: PetInsurance,
        pet: Pet,
        input: InsuranceClaimCommandInput,
        note: String
    ) -> InsuranceClaimCommandResult {
        let result = InsurancePolicyCommandService.createClaim(
            insurance: insurance,
            pet: pet,
            input: input,
            context: context
        )
        revisions.publishInsuranceClaim(result, action: "create", note: note)
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
    ) -> InsuranceClaimCommandResult {
        let result = InsurancePolicyCommandService.updateClaimStatus(
            claim,
            to: status,
            insurance: insurance,
            pet: pet,
            context: context,
            executorId: executorId
        )
        revisions.publishInsuranceClaim(result, action: "status.\(status.rawValue)", note: note)
        return result
    }

    @discardableResult
    func deleteClaim(
        _ claim: InsuranceClaim,
        insurance: PetInsurance,
        pet: Pet,
        note: String
    ) -> InsuranceClaimCommandResult {
        let result = InsurancePolicyCommandService.deleteClaim(
            claim,
            insurance: insurance,
            pet: pet,
            context: context
        )
        revisions.publishInsuranceClaim(result, action: "delete", note: note)
        return result
    }
}
