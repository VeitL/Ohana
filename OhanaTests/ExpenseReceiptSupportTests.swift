import Foundation
import Testing
@testable import Ohana

struct ExpenseReceiptSupportTests {
    @Test func insurancePaymentScheduleGeneratesMonthlyQuarterlyAndAnnualDates() {
        let calendar = gregorianCalendar

        let monthly = InsurancePaymentSchedule.dates(
            startDate: date(2026, 1, 15),
            renewalDate: date(2026, 4, 14),
            frequency: .monthly,
            paymentDayOfMonth: 20,
            calendar: calendar
        )
        #expect(monthly.map(dayKey) == ["2026-01-20", "2026-02-20", "2026-03-20"])

        let quarterly = InsurancePaymentSchedule.dates(
            startDate: date(2026, 1, 10),
            renewalDate: date(2026, 8, 10),
            frequency: .quarterly,
            paymentDayOfMonth: 5,
            calendar: calendar
        )
        #expect(quarterly.map(dayKey) == ["2026-04-05", "2026-07-05"])

        let annual = InsurancePaymentSchedule.dates(
            startDate: date(2026, 5, 1),
            renewalDate: date(2028, 5, 1),
            frequency: .annual,
            paymentDayOfMonth: 1,
            calendar: calendar
        )
        #expect(annual.map(dayKey) == ["2026-05-01", "2027-05-01", "2028-05-01"])
    }

    @Test func documentInsuranceCostPlansOneInsurancePremiumExpense() {
        let plans = DocumentExpenseSyncPlanner.plannedExpenses(
            documentCategory: .insurance,
            amount: 120,
            date: date(2026, 2, 9),
            note: "保单凭证",
            payerId: "human-1"
        )

        #expect(plans.count == 1)
        #expect(plans.first?.category == .insurancePremium)
        #expect(plans.first?.date == date(2026, 2, 9))
        #expect(plans.first?.note == "保单凭证")
        #expect(plans.first?.payerId == "human-1")
    }

    @Test func reimbursementWriterSkipsDuplicateApprovedClaimExpense() {
        let note = InsuranceReimbursementExpenseWriter.reimbursementNote(productName: "Ohana Care")
        let existing = PetExpenseLog(
            date: date(2026, 2, 9),
            amount: -80,
            category: .insurancePremium,
            note: note,
            executorId: "human-1"
        )

        #expect(!InsuranceReimbursementExpenseWriter.shouldInsertReimbursementLog(
            existingLogs: [existing],
            date: date(2026, 2, 9),
            amount: 80,
            note: " \(note) ",
            calendar: gregorianCalendar
        ))

        #expect(InsuranceReimbursementExpenseWriter.shouldInsertReimbursementLog(
            existingLogs: [existing],
            date: date(2026, 2, 10),
            amount: 80,
            note: note,
            calendar: gregorianCalendar
        ))
    }

    @Test func expenseSummaryBuilderUnifiesHumanPetAndReimbursementRollups() {
        let human = Human(name: "Guan")
        let pet = Pet(name: "Momo", species: "猫")
        let directHumanExpense = PetExpenseLog(
            date: date(2026, 3, 1),
            amount: 30,
            category: .other,
            note: "Coffee",
            executorId: human.id.uuidString
        )
        let petExpense = PetExpenseLog(
            date: date(2026, 3, 2),
            amount: 70,
            category: .food,
            note: "Food",
            pet: pet,
            executorId: human.id.uuidString
        )
        let reimbursement = PetExpenseLog(
            date: date(2026, 3, 3),
            amount: -20,
            category: .insurancePremium,
            note: "Claim paid",
            pet: pet,
            executorId: human.id.uuidString
        )
        let logs = [directHumanExpense, petExpense, reimbursement]

        let totals = ExpenseSummaryBuilder.totals(from: logs)
        let paidByHuman = ExpenseSummaryBuilder.paidBy(human.id, from: logs)
        let humanDirect = ExpenseSummaryBuilder.humanDirectExpenses(human.id, from: logs)
        let linkedToPet = ExpenseSummaryBuilder.linkedToPet(pet.id, from: logs)
        let categories = ExpenseSummaryBuilder.categoryBreakdown(from: logs)

        #expect(totals.spent == 100)
        #expect(totals.reimbursed == 20)
        #expect(totals.net == 80)
        #expect(totals.recordCount == 3)
        #expect(totals.spendCount == 2)
        #expect(totals.reimbursementCount == 1)
        #expect(paidByHuman.map(\.id) == logs.map(\.id))
        #expect(humanDirect.map(\.id) == [directHumanExpense.id])
        #expect(linkedToPet.map(\.id) == [petExpense.id, reimbursement.id])
        #expect(categories.map(\.category) == [.food, .other])
        #expect(abs((categories.first?.pct ?? 0) - 0.7) < 0.001)
    }

    @Test func expenseSummaryBuilderAttributesOnlyCoPayerShareToHumanTotals() throws {
        let primaryPayerID = UUID()
        let coPayerID = UUID()
        let contributions = [
            ExpensePayerContribution(humanID: primaryPayerID, minorUnits: 6000),
            ExpensePayerContribution(humanID: coPayerID, minorUnits: 4000)
        ]
        let expense = PetExpenseLog(
            date: date(2026, 3, 4),
            amount: 100,
            category: .medical,
            note: "Shared clinic bill",
            executorId: primaryPayerID.uuidString,
            payerContributionsJSON: ExpensePayerContributionPolicy.encode(contributions)
        )

        let paidByCoPayer = ExpenseSummaryBuilder.paidBy(coPayerID, from: [expense])
        let coPayerSlices = ExpenseSummaryBuilder.summarySlices(
            from: paidByCoPayer,
            attributedTo: coPayerID.uuidString
        )
        let coPayerTotals = ExpenseSummaryBuilder.totals(from: coPayerSlices)

        #expect(paidByCoPayer.map(\.id) == [expense.id])
        #expect(ExpenseSummaryBuilder.amountPaid(by: primaryPayerID, for: expense) == 60)
        #expect(ExpenseSummaryBuilder.amountPaid(by: coPayerID, for: expense) == 40)
        #expect(coPayerSlices.map(\.amount) == [40])
        #expect(coPayerSlices.first?.executorId == coPayerID.uuidString)
        #expect(coPayerTotals.spent == 40)
        #expect(coPayerTotals.net == 40)
        #expect(coPayerTotals.recordCount == 1)
        #expect(coPayerTotals.spendCount == 1)
    }

    @Test func householdExpensePayerProjectionKeepsSixAndEightSeparate() {
        let firstPayerID = UUID()
        let secondPayerID = UUID()
        let expense = PetExpenseLog(
            date: date(2026, 3, 6),
            amount: 14,
            category: .food,
            note: "Shared food",
            executorId: firstPayerID.uuidString,
            payerContributionsJSON: ExpensePayerContributionPolicy.encode([
                ExpensePayerContribution(humanID: firstPayerID, minorUnits: 600),
                ExpensePayerContribution(humanID: secondPayerID, minorUnits: 800)
            ])
        )

        let slices = ExpenseSummaryBuilder.payerContributionSlices(from: [expense])
        let amountByPayer = Dictionary(uniqueKeysWithValues: slices.compactMap { slice in
            slice.executorId.map { ($0, slice.amount) }
        })

        #expect(slices.count == 2)
        #expect(amountByPayer[firstPayerID.uuidString] == 6)
        #expect(amountByPayer[secondPayerID.uuidString] == 8)
        #expect(slices.reduce(0) { $0 + $1.amount } == 14)
    }

    @Test func expenseChartBucketsKeepCalendarIdentityAcrossRefreshesAndValueChanges() {
        let now = date(2026, 8, 9)
        let recordDate = date(2026, 8, 2)
        let firstRecord = ExpenseSummarySlice(
            date: recordDate,
            amount: 6,
            expenseCategory: .food,
            executorId: nil,
            expensePetID: nil
        )
        let updatedRecord = ExpenseSummarySlice(
            date: recordDate,
            amount: 8,
            expenseCategory: .food,
            executorId: nil,
            expensePetID: nil
        )

        let initial = makeExpenseBuckets(
            from: [firstRecord],
            range: .year,
            now: now,
            calendar: gregorianCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let repeated = makeExpenseBuckets(
            from: [firstRecord],
            range: .year,
            now: now,
            calendar: gregorianCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )
        let updated = makeExpenseBuckets(
            from: [updatedRecord],
            range: .year,
            now: now,
            calendar: gregorianCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        )

        #expect(initial == repeated)
        #expect(initial.map(\.id) == updated.map(\.id))
        #expect(Set(initial.map(\.id)).count == initial.count)
        #expect(initial != updated)
    }

    @Test func expenseSummaryBuilderTreatsCorruptStructuredSnapshotAsUnknownWithoutDroppingAmount() {
        let legacyExecutorID = UUID()
        let expense = PetExpenseLog(
            date: date(2026, 3, 5),
            amount: 100,
            category: .medical,
            note: "Corrupt split",
            executorId: legacyExecutorID.uuidString,
            payerContributionsJSON: "{not-json"
        )

        let shares = ExpenseSummaryBuilder.payerShares(for: expense)
        let paidByLegacyExecutor = ExpenseSummaryBuilder.paidBy(legacyExecutorID, from: [expense])
        let allSlices = ExpenseSummaryBuilder.summarySlices(from: [expense])
        let legacyExecutorSlices = ExpenseSummaryBuilder.summarySlices(
            from: [expense],
            attributedTo: legacyExecutorID.uuidString
        )
        let totals = ExpenseSummaryBuilder.totals(from: allSlices)

        #expect(shares == [ExpensePayerShare(humanID: nil, amount: 100)])
        #expect(paidByLegacyExecutor.isEmpty)
        #expect(legacyExecutorSlices.isEmpty)
        #expect(allSlices.map(\.amount) == [100])
        #expect(allSlices.first?.hasStructuredPayerSnapshot == true)
        #expect(allSlices.first?.payerContributions.isEmpty == true)
        #expect(totals.spent == 100)
        #expect(totals.net == 100)
        #expect(totals.recordCount == 1)
    }

    @Test func receiptDocumentStoresAttachmentsAndHidesMetadata() {
        let draft = ExpenseReceiptDocumentBuilder.makeDraft(
            title: "Vet receipt",
            category: .medical,
            cost: 300,
            date: date(2026, 3, 1),
            visibleNote: "复诊",
            linkedExpenseLogId: "expense-1",
            attachments: [
                ExpenseReceiptAttachmentDraft(data: Data([1, 2, 3]), filename: "receipt.jpg", isImage: true)
            ]
        )

        #expect(draft.cost == 300)
        #expect(draft.issueDate == date(2026, 3, 1))
        #expect(draft.attachments.count == 1)
        #expect(draft.attachments.first?.data == Data([1, 2, 3]))
        #expect(draft.attachmentFilename == "receipt.jpg")
        #expect(ExpenseReceiptMetadata.expenseLogId(from: draft.notes) == "expense-1")
        #expect(ExpenseReceiptMetadata.visibleNotes(from: draft.notes) == "复诊")
    }

    @Test func addExpenseLocalizationHasChineseEnglishAndGermanText() {
        #expect(L10n("zh").quickExpenseReceipt == "凭证")
        #expect(L10n("en").quickExpenseReceipt == "Receipt")
        #expect(L10n("de").quickExpenseReceipt == "Beleg")
        #expect(L10n("zh").quickExpenseInsuranceSingleTitle == "单笔保险费")
        #expect(L10n("en").quickExpenseInsuranceSingleTitle == "Single insurance expense")
        #expect(L10n("de").quickExpenseInsuranceSingleTitle == "Einzelne Versicherungszahlung")
        #expect(L10n("en").expenseCategoryTitle(.insurancePremium) == "Insurance")
        #expect(L10n("de").insuranceFrequencyTitle(.quarterly) == "Vierteljährlich")
    }

    private var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(calendar: gregorianCalendar, timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day).date!
    }

    private func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
