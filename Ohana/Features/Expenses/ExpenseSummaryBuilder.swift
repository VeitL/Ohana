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
}

extension PetExpenseLog: ExpenseSummaryRecord {
    var expensePetID: UUID? { pet?.id }
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
        logs.filter { $0.executorId == humanID }
    }

    static func linkedToPet<Log: ExpenseSummaryRecord>(_ petID: UUID, from logs: [Log]) -> [Log] {
        logs.filter { $0.expensePetID == petID }
    }

    static func humanDirectExpenses<Log: ExpenseSummaryRecord>(_ humanID: UUID, from logs: [Log]) -> [Log] {
        logs.filter { $0.executorId == humanID.uuidString && $0.expensePetID == nil }
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
}
