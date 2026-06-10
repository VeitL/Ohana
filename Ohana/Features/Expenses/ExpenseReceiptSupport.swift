//
//  ExpenseReceiptSupport.swift
//  Ohana
//
//  Helpers for quick expense receipts and insurance expense sync.
//

import Foundation

struct ExpenseReceiptAttachmentDraft: Equatable {
    var data: Data
    var filename: String
    var isImage: Bool
}

enum InsurancePaymentSchedule {
    static func dates(
        startDate: Date,
        renewalDate: Date,
        frequency: InsurancePaymentFrequency,
        paymentDayOfMonth: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard startDate <= renewalDate else { return [] }

        switch frequency {
        case .once:
            return [startDate]

        case .annual:
            return recurringDates(
                firstDate: startDate,
                renewalDate: renewalDate,
                component: .year,
                value: 1,
                calendar: calendar
            )

        case .monthly:
            return recurringDates(
                firstDate: firstPaymentDate(
                    from: startDate,
                    day: paymentDayOfMonth,
                    componentValue: 1,
                    calendar: calendar
                ),
                renewalDate: renewalDate,
                component: .month,
                value: 1,
                calendar: calendar
            )

        case .quarterly:
            return recurringDates(
                firstDate: firstPaymentDate(
                    from: startDate,
                    day: paymentDayOfMonth,
                    componentValue: 3,
                    calendar: calendar
                ),
                renewalDate: renewalDate,
                component: .month,
                value: 3,
                calendar: calendar
            )
        }
    }

    static func dates(for insurance: PetInsurance, calendar: Calendar = .current) -> [Date] {
        dates(
            startDate: insurance.startDate,
            renewalDate: insurance.renewalDate,
            frequency: insurance.paymentFrequency,
            paymentDayOfMonth: insurance.paymentDayOfMonth,
            calendar: calendar
        )
    }

    private static func recurringDates(
        firstDate: Date,
        renewalDate: Date,
        component: Calendar.Component,
        value: Int,
        calendar: Calendar
    ) -> [Date] {
        guard firstDate <= renewalDate else { return [] }

        var dates: [Date] = []
        var current = firstDate
        var guardCount = 0
        while current <= renewalDate && guardCount < 600 {
            dates.append(current)
            guard let next = calendar.date(byAdding: component, value: value, to: current), next > current else {
                break
            }
            current = next
            guardCount += 1
        }
        return dates
    }

    private static func firstPaymentDate(
        from reference: Date,
        day: Int,
        componentValue: Int,
        calendar: Calendar
    ) -> Date {
        let safeDay = max(1, min(28, day))
        var components = calendar.dateComponents([.year, .month], from: reference)
        components.day = safeDay
        if let candidate = calendar.date(from: components), candidate >= reference {
            return candidate
        }
        components.month = (components.month ?? 1) + componentValue
        return calendar.date(from: components) ?? reference
    }
}

struct DocumentExpensePlan: Equatable {
    var date: Date
    var amount: Double
    var category: ExpenseCategory
    var note: String
    var payerId: String?
}

enum DocumentExpenseSyncPlanner {
    static func plannedExpenses(
        documentCategory: DocumentCategory,
        amount: Double,
        date: Date,
        note: String,
        payerId: String?
    ) -> [DocumentExpensePlan] {
        guard amount > 0 else { return [] }
        return [
            DocumentExpensePlan(
                date: date,
                amount: amount,
                category: expenseCategory(for: documentCategory),
                note: note,
                payerId: payerId
            )
        ]
    }

    static func expenseCategory(for documentCategory: DocumentCategory) -> ExpenseCategory {
        documentCategory == .insurance ? .insurancePremium : .medical
    }
}

enum InsuranceReimbursementExpenseWriter {
    static func reimbursementNote(productName: String) -> String {
        "保险报销到账：\(productName)"
    }

    static func shouldInsertReimbursementLog(
        existingLogs: [PetExpenseLog],
        date: Date,
        amount: Double,
        note: String,
        calendar: Calendar = .current
    ) -> Bool {
        let targetAmount = roundedCurrency(abs(amount))
        guard targetAmount > 0 else { return false }

        return !existingLogs.contains { log in
            calendar.isDate(log.date, inSameDayAs: date)
                && log.expenseCategory == .insurancePremium
                && abs(roundedCurrency(log.amount) + targetAmount) < 0.01
                && normalizedNote(log.note) == normalizedNote(note)
        }
    }

    private static func normalizedNote(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func roundedCurrency(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }
}

enum ExpenseReceiptMetadata {
    static let expenseLinkPrefix = "关联花费:"

    static func notes(visibleNote: String, expenseLogId: String) -> String {
        var parts = visibleNoteParts(from: visibleNote)
        parts.append("\(expenseLinkPrefix)\(expenseLogId)")
        return parts.joined(separator: "｜")
    }

    static func expenseLogId(from notes: String) -> String? {
        metadataValue(from: notes, prefix: expenseLinkPrefix)
    }

    static func visibleNotes(from notes: String) -> String {
        visibleNoteParts(from: notes).joined(separator: "｜")
    }

    static func visibleNoteParts(from notes: String) -> [String] {
        splitNoteParts(notes).filter { part in
            !part.hasPrefix(expenseLinkPrefix)
        }
    }

    private static func metadataValue(from notes: String, prefix: String) -> String? {
        splitNoteParts(notes)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func splitNoteParts(_ notes: String) -> [String] {
        notes
            .components(separatedBy: CharacterSet(charactersIn: "｜\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum ExpenseReceiptDocumentBuilder {
    static func makeDocument(
        title: String,
        category: DocumentCategory,
        cost: Double,
        date: Date,
        visibleNote: String,
        linkedExpenseLogId: String,
        attachments: [ExpenseReceiptAttachmentDraft],
        pet: Pet
    ) -> PetDocument {
        let document = PetDocument(title: title, category: category, pet: pet)
        document.issueDate = date
        document.cost = cost
        document.notes = ExpenseReceiptMetadata.notes(
            visibleNote: visibleNote,
            expenseLogId: linkedExpenseLogId
        )

        if let first = attachments.first {
            document.attachmentData = first.data
            document.attachmentFilename = normalizedFilename(first, index: 1)
        }

        document.attachments = attachments.enumerated().map { index, attachment in
            PetDocumentAttachment(
                data: attachment.data,
                filename: normalizedFilename(attachment, index: index + 1),
                isImage: attachment.isImage
            )
        }

        return document
    }

    private static func normalizedFilename(_ attachment: ExpenseReceiptAttachmentDraft, index: Int) -> String {
        let cleaned = attachment.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty { return cleaned }
        return attachment.isImage ? "receipt_\(index).jpg" : "receipt_\(index)"
    }
}
