//
//  HomeExpensePreviewStore.swift
//  Ohana
//
//  Route-scoped expense preview for expanded human home cards.
//

import Combine
import Foundation
import SwiftData

struct HomeExpensePreviewEntry: Equatable, Identifiable {
    let id: UUID
    let date: Date
    let actorId: String
    let amount: Double
}

@MainActor
final class HomeExpensePreviewStore: ObservableObject {
    @Published private(set) var expenseEntries: [HomeExpensePreviewEntry] = []

    private var activeKey = ""
    private var fetchTask: Task<Void, Never>?

    func request(context: ModelContext, humanID: UUID?, now: Date = Date()) {
        guard let humanID else {
            clear()
            return
        }

        let key = cacheKey(humanID: humanID, now: now)
        guard key != activeKey else { return }
        activeKey = key

        fetchTask?.cancel()
        fetchTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 96) { [weak self] in
            guard let self else { return }
            let startedAt = CFAbsoluteTimeGetCurrent()
            self.expenseEntries = Self.fetchExpenseEntries(context: context, humanID: humanID, now: now)
            AppPerformanceMonitor.shared.record(
                "home_expense_preview_refresh",
                startedAt: startedAt,
                note: "\(self.expenseEntries.count) ledger entries"
            )
            self.fetchTask = nil
        }
    }

    func clear() {
        activeKey = ""
        fetchTask?.cancel()
        fetchTask = nil
        if !expenseEntries.isEmpty {
            expenseEntries = []
        }
    }

    func cancel() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    static func fetchExpenseEntries(context: ModelContext, humanID: UUID, now: Date = Date()) -> [HomeExpensePreviewEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) ?? today
        let actorId = humanID.uuidString
        let expenseKind = CareLedgerEventKind.expense.rawValue
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.occurredAt >= monthStart &&
                    event.eventKind == expenseKind &&
                    event.actorId == actorId
            },
            sortBy: [SortDescriptor(\CareLedgerEvent.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        do {
            return try context.fetch(descriptor).map { event in
                HomeExpensePreviewEntry(
                    id: event.id,
                    date: event.occurredAt,
                    actorId: actorId,
                    amount: event.amountValue
                )
            }
        } catch {
            OhanaLog.warning(
                "Home expense preview ledger fetch failed: \(error.localizedDescription)",
                category: "Home"
            )
            return []
        }
    }

    private func cacheKey(humanID: UUID, now: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: now)
        return "\(humanID.uuidString)|\(components.year ?? 0)-\(components.month ?? 0)"
    }
}
