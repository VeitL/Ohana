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
    static func sortedRecent(_ logs: [PetExpenseLog]) -> [PetExpenseLog] {
        logs.sorted { $0.date > $1.date }
    }

    static func logs(
        _ logs: [PetExpenseLog],
        in range: ExpenseDashboardRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PetExpenseLog] {
        guard let cutoff = range.startDate(now: now, calendar: calendar) else {
            return logs
        }
        return logs.filter { $0.date >= cutoff }
    }

    static func logs(
        _ logs: [PetExpenseLog],
        category: ExpenseCategory?
    ) -> [PetExpenseLog] {
        guard let category else { return logs }
        return logs.filter { $0.expenseCategory == category }
    }

    static func paidBy(_ humanID: UUID, from logs: [PetExpenseLog]) -> [PetExpenseLog] {
        paidBy(humanID.uuidString, from: logs)
    }

    static func paidBy(_ humanID: String, from logs: [PetExpenseLog]) -> [PetExpenseLog] {
        logs.filter { $0.executorId == humanID }
    }

    static func linkedToPet(_ petID: UUID, from logs: [PetExpenseLog]) -> [PetExpenseLog] {
        logs.filter { $0.pet?.id == petID }
    }

    static func humanDirectExpenses(_ humanID: UUID, from logs: [PetExpenseLog]) -> [PetExpenseLog] {
        logs.filter { $0.executorId == humanID.uuidString && $0.pet == nil }
    }

    static func positiveLogs(_ logs: [PetExpenseLog]) -> [PetExpenseLog] {
        logs.filter { $0.amount > 0 }
    }

    static func reimbursementLogs(_ logs: [PetExpenseLog]) -> [PetExpenseLog] {
        logs.filter { $0.amount < 0 }
    }

    static func totals(from logs: [PetExpenseLog]) -> ExpenseTotals {
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

    static func categoryBreakdown(from logs: [PetExpenseLog]) -> [ExpenseCategoryBreakdown] {
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

    static func topCategory(from logs: [PetExpenseLog]) -> ExpenseCategoryBreakdown? {
        categoryBreakdown(from: logs).first
    }
}
