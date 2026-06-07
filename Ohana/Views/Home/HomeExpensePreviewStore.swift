//
//  HomeExpensePreviewStore.swift
//  Ohana
//
//  Route-scoped expense preview for expanded human home cards.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class HomeExpensePreviewStore: ObservableObject {
    @Published private(set) var expenseLogs: [PetExpenseLog] = []

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
            self.expenseLogs = Self.fetchExpenseLogs(context: context, humanID: humanID, now: now)
            AppPerformanceMonitor.shared.record(
                "home_expense_preview_refresh",
                startedAt: startedAt,
                note: "\(self.expenseLogs.count) logs"
            )
            self.fetchTask = nil
        }
    }

    func clear() {
        activeKey = ""
        fetchTask?.cancel()
        fetchTask = nil
        if !expenseLogs.isEmpty {
            expenseLogs = []
        }
    }

    func cancel() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    static func fetchExpenseLogs(context: ModelContext, humanID: UUID, now: Date = Date()) -> [PetExpenseLog] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) ?? today
        let executorId = humanID.uuidString
        var descriptor = FetchDescriptor<PetExpenseLog>(
            predicate: #Predicate<PetExpenseLog> { log in
                log.date >= monthStart && log.executorId == executorId
            },
            sortBy: [SortDescriptor(\PetExpenseLog.date, order: .reverse)]
        )
        descriptor.fetchLimit = 80
        return (try? context.fetch(descriptor)) ?? []
    }

    private func cacheKey(humanID: UUID, now: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: now)
        return "\(humanID.uuidString)|\(components.year ?? 0)-\(components.month ?? 0)"
    }
}
