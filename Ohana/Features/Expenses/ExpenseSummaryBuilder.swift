//
//  ExpenseSummaryBuilder.swift
//  Ohana
//
//  Shared expense rollups for human, pet, and island dashboards.
//

import Foundation

struct ExpenseTotals: Equatable {
    let spent: Double
    let reimbursed: Double
    let net: Double
    let recordCount: Int
    let spendCount: Int
    let reimbursementCount: Int

    static let empty = ExpenseTotals(
        spent: 0,
        reimbursed: 0,
        net: 0,
        recordCount: 0,
        spendCount: 0,
        reimbursementCount: 0
    )
}

struct ExpenseCategoryBreakdown: Identifiable, Equatable {
    var id: String { category.rawValue }
    let category: ExpenseCategory
    let total: Double
    let pct: Double
}

protocol ExpenseSummaryRecord {
    var date: Date { get }
    var amount: Double { get }
    var expenseCategory: ExpenseCategory { get }
    var executorId: String? { get }
    var expensePetID: UUID? { get }
    var payerContributions: [ExpensePayerContribution] { get }
    var hasStructuredPayerSnapshot: Bool { get }
}

extension ExpenseSummaryRecord {
    /// Legacy/test summary records have no structured split and continue to use
    /// their singular executor as the payer of the whole amount.
    var payerContributions: [ExpensePayerContribution] { [] }
    var hasStructuredPayerSnapshot: Bool { false }
}

extension PetExpenseLog: ExpenseSummaryRecord {
    var expensePetID: UUID? { pet?.id }
    var hasStructuredPayerSnapshot: Bool { !payerContributionsJSON.isEmpty }
}

nonisolated struct ExpensePayerShare: Equatable, Sendable {
    let humanID: String?
    let amount: Double
}

nonisolated struct ExpenseSummarySlice: ExpenseSummaryRecord, Equatable {
    let date: Date
    let amount: Double
    let expenseCategory: ExpenseCategory
    let executorId: String?
    let expensePetID: UUID?
    let payerContributions: [ExpensePayerContribution]
    let hasStructuredPayerSnapshot: Bool

    init(
        date: Date,
        amount: Double,
        expenseCategory: ExpenseCategory,
        executorId: String?,
        expensePetID: UUID?,
        payerContributions: [ExpensePayerContribution] = [],
        hasStructuredPayerSnapshot: Bool = false
    ) {
        self.date = date
        self.amount = amount
        self.expenseCategory = expenseCategory
        self.executorId = executorId
        self.expensePetID = expensePetID
        self.payerContributions = payerContributions
        self.hasStructuredPayerSnapshot = hasStructuredPayerSnapshot
    }
}

enum ExpenseAmountPresets {
    static func defaults(for category: ExpenseCategory) -> [Double] {
        switch category {
        case .food: [20, 50, 100]
        case .treats: [10, 20, 50]
        case .medical: [100, 300, 800]
        case .grooming: [80, 150, 300]
        case .toys: [20, 50, 100]
        case .insurancePremium: [60, 120, 300]
        case .other: [20, 100, 300]
        }
    }

    static func roundedCurrency(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }
}

enum ExpenseSummaryBuilder {
    static func sortedRecent<Log: ExpenseSummaryRecord>(_ logs: [Log]) -> [Log] {
        logs.sorted { $0.date > $1.date }
    }

    static func logs<Log: ExpenseSummaryRecord>(
        _ logs: [Log],
        in range: ExpenseDashboardRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Log] {
        guard let cutoff = range.startDate(now: now, calendar: calendar) else {
            return logs
        }
        return logs.filter { $0.date >= cutoff }
    }

    static func logs<Log: ExpenseSummaryRecord>(
        _ logs: [Log],
        category: ExpenseCategory?
    ) -> [Log] {
        guard let category else { return logs }
        return logs.filter { $0.expenseCategory == category }
    }

    static func paidBy<Log: ExpenseSummaryRecord>(_ humanID: UUID, from logs: [Log]) -> [Log] {
        paidBy(humanID.uuidString, from: logs)
    }

    static func paidBy<Log: ExpenseSummaryRecord>(_ humanID: String, from logs: [Log]) -> [Log] {
        logs.filter { amountPaid(by: humanID, for: $0) != 0 }
    }

    static func linkedToPet<Log: ExpenseSummaryRecord>(_ petID: UUID, from logs: [Log]) -> [Log] {
        logs.filter { $0.expensePetID == petID }
    }

    static func humanDirectExpenses<Log: ExpenseSummaryRecord>(_ humanID: UUID, from logs: [Log]) -> [Log] {
        logs.filter { $0.expensePetID == nil && amountPaid(by: humanID.uuidString, for: $0) != 0 }
    }

    static func payerShares(for log: some ExpenseSummaryRecord) -> [ExpensePayerShare] {
        if !log.payerContributions.isEmpty {
            return log.payerContributions.map {
                ExpensePayerShare(humanID: $0.humanID?.uuidString, amount: $0.amount)
            }
        }
        if log.hasStructuredPayerSnapshot {
            return [ExpensePayerShare(humanID: nil, amount: log.amount)]
        }
        return [ExpensePayerShare(humanID: normalizedHumanID(log.executorId), amount: log.amount)]
    }

    static func amountPaid(by humanID: UUID, for log: some ExpenseSummaryRecord) -> Double {
        amountPaid(by: humanID.uuidString, for: log)
    }

    static func amountPaid(by humanID: String, for log: some ExpenseSummaryRecord) -> Double {
        payerShares(for: log)
            .filter { payerIDsMatch($0.humanID, humanID) }
            .reduce(0) { $0 + $1.amount }
    }

    static func summarySlices(
        from logs: [some ExpenseSummaryRecord],
        attributedTo humanID: String? = nil
    ) -> [ExpenseSummarySlice] {
        logs.compactMap { log in
            let attributedAmount: Double
            if let humanID {
                attributedAmount = amountPaid(by: humanID, for: log)
                guard attributedAmount != 0 else { return nil }
            } else {
                attributedAmount = log.amount
            }
            return ExpenseSummarySlice(
                date: log.date,
                amount: attributedAmount,
                expenseCategory: log.expenseCategory,
                executorId: humanID ?? log.executorId,
                expensePetID: log.expensePetID,
                payerContributions: humanID == nil ? log.payerContributions : [],
                hasStructuredPayerSnapshot: humanID == nil && log.hasStructuredPayerSnapshot
            )
        }
    }

    /// Projects every expense into one exact slice per payer contribution.
    /// Household member rollups must consume these slices instead of assigning
    /// the whole expense to `executorId`, which is only the legacy/primary payer.
    static func payerContributionSlices(
        from logs: [some ExpenseSummaryRecord],
        attributedTo humanID: String? = nil
    ) -> [ExpenseSummarySlice] {
        logs.flatMap { log in
            payerShares(for: log).compactMap { share in
                guard share.amount != 0 else { return nil }
                if let humanID, !payerIDsMatch(share.humanID, humanID) {
                    return nil
                }
                return ExpenseSummarySlice(
                    date: log.date,
                    amount: share.amount,
                    expenseCategory: log.expenseCategory,
                    executorId: normalizedHumanID(share.humanID),
                    expensePetID: log.expensePetID
                )
            }
        }
    }

    static func positiveLogs<Log: ExpenseSummaryRecord>(_ logs: [Log]) -> [Log] {
        logs.filter { $0.amount > 0 }
    }

    static func reimbursementLogs<Log: ExpenseSummaryRecord>(_ logs: [Log]) -> [Log] {
        logs.filter { $0.amount < 0 }
    }

    static func totals(from logs: [some ExpenseSummaryRecord]) -> ExpenseTotals {
        guard !logs.isEmpty else { return .empty }
        let spentLogs = positiveLogs(logs)
        let refunds = reimbursementLogs(logs)
        let spent = spentLogs.reduce(0) { $0 + $1.amount }
        let reimbursed = refunds.reduce(0) { $0 + abs($1.amount) }
        return ExpenseTotals(
            spent: spent,
            reimbursed: reimbursed,
            net: spent - reimbursed,
            recordCount: logs.count,
            spendCount: spentLogs.count,
            reimbursementCount: refunds.count
        )
    }

    static func categoryBreakdown(from logs: [some ExpenseSummaryRecord]) -> [ExpenseCategoryBreakdown] {
        let positiveLogs = positiveLogs(logs)
        let grandTotal = max(1, positiveLogs.reduce(0) { $0 + $1.amount })
        var totalsByCategory: [ExpenseCategory: Double] = [:]

        for log in positiveLogs {
            totalsByCategory[log.expenseCategory, default: 0] += log.amount
        }

        return totalsByCategory
            .map { category, categoryTotal in
                ExpenseCategoryBreakdown(category: category, total: categoryTotal, pct: categoryTotal / grandTotal)
            }
            .sorted { $0.total > $1.total }
    }

    static func topCategory(from logs: [some ExpenseSummaryRecord]) -> ExpenseCategoryBreakdown? {
        categoryBreakdown(from: logs).first
    }

    static func payerIDsMatch(_ lhs: String?, _ rhs: String) -> Bool {
        guard let left = normalizedHumanID(lhs), let right = normalizedHumanID(rhs) else { return false }
        return left == right
    }

    private static func normalizedHumanID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return UUID(uuidString: clean)?.uuidString ?? clean
    }
}
