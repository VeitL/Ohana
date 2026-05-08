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

    @MainActor
    @Test func receiptDocumentStoresAttachmentsAndHidesMetadata() {
        let pet = Pet(name: "Momo", species: "猫")
        let document = ExpenseReceiptDocumentBuilder.makeDocument(
            title: "Vet receipt",
            category: .medical,
            cost: 300,
            date: date(2026, 3, 1),
            visibleNote: "复诊",
            linkedExpenseLogId: "expense-1",
            attachments: [
                ExpenseReceiptAttachmentDraft(data: Data([1, 2, 3]), filename: "receipt.jpg", isImage: true)
            ],
            pet: pet
        )

        #expect(document.cost == 300)
        #expect(document.issueDate == date(2026, 3, 1))
        #expect(document.attachments.count == 1)
        #expect(document.attachments.first?.data == Data([1, 2, 3]))
        #expect(document.attachmentFilename == "receipt.jpg")
        #expect(ExpenseReceiptMetadata.expenseLogId(from: document.notes) == "expense-1")
        #expect(ExpenseReceiptMetadata.visibleNotes(from: document.notes) == "复诊")
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
