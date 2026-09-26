import Foundation
import SwiftData
import SwiftUI

nonisolated struct ExpenseInsightLogSnapshot: Identifiable, Equatable, Sendable, ExpenseSummaryRecord {
    let id: UUID
    let date: Date
    let amount: Double
    let categoryRaw: String
    let note: String
    let executorId: String?
    let expensePetID: UUID?
    let payerContributions: [ExpensePayerContribution]
    let hasStructuredPayerSnapshot: Bool

    var expenseCategory: ExpenseCategory {
        ExpenseCategory(rawValue: categoryRaw) ?? .other
    }
}

nonisolated struct ExpenseInsightSnapshot: Equatable, Sendable {
    let revisionID: UUID
    let logs: [ExpenseInsightLogSnapshot]
    let isTruncated: Bool
    let hasLoaded: Bool

    static let empty = ExpenseInsightSnapshot(
        revisionID: UUID(),
        logs: [],
        isTruncated: false,
        hasLoaded: false
    )
}

@ModelActor
actor ExpenseInsightDataActor {
    private static let maximumAggregateRecordCount = 20000

    func load(
        range: ExpenseDashboardRange,
        subjectKey: String?,
        activePetIDs: Set<UUID>,
        activeHumanIDs: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ExpenseInsightSnapshot {
        try Task.checkCancellation()
        let cutoff = comparisonCutoff(for: range, now: now, calendar: calendar)
        let subject = Self.parseSubjectKey(subjectKey)
        let fetch = try fetchLogs(cutoff: cutoff, subject: subject)
        try Task.checkCancellation()

        let scoped = fetch.records.filter { log in
            if let subject { return Self.matches(log, subject: subject) }
            if let petID = log.pet?.id { return activePetIDs.contains(petID) }
            let contributions = log.payerContributions
            if !contributions.isEmpty {
                return contributions.contains { contribution in
                    guard let payerID = contribution.humanID else { return true }
                    return activeHumanIDs.contains(payerID.uuidString)
                }
            }
            // A structured-but-invalid snapshot has no trustworthy person to
            // scope against; keep the household fact and project it as unknown.
            if !log.payerContributionsJSON.isEmpty { return true }
            guard let executorID = log.executorId,
                  let normalizedExecutorID = UUID(uuidString: executorID)?.uuidString else {
                return true
            }
            return activeHumanIDs.contains(normalizedExecutorID)
        }

        return ExpenseInsightSnapshot(
            revisionID: UUID(),
            logs: scoped.map { log in
                ExpenseInsightLogSnapshot(
                    id: log.id,
                    date: log.date,
                    amount: log.amount,
                    categoryRaw: log.category,
                    note: log.note,
                    executorId: log.executorId,
                    expensePetID: log.pet?.id,
                    payerContributions: log.payerContributions,
                    hasStructuredPayerSnapshot: !log.payerContributionsJSON.isEmpty
                )
            },
            isTruncated: fetch.isTruncated,
            hasLoaded: true
        )
    }

    private func comparisonCutoff(
        for range: ExpenseDashboardRange,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard let currentStart = range.startDate(now: now, calendar: calendar) else { return nil }
        let span = now.timeIntervalSince(currentStart)
        return currentStart.addingTimeInterval(-max(span, 0))
    }

    private func fetchLogs(
        cutoff: Date?,
        subject: (kind: String, id: String)?
    ) throws -> (records: [PetExpenseLog], isTruncated: Bool) {
        var descriptor: FetchDescriptor<PetExpenseLog>
        if let subject, subject.kind == "pet" {
            guard let id = UUID(uuidString: subject.id) else { return ([], false) }
            if let cutoff {
                descriptor = FetchDescriptor<PetExpenseLog>(
                    predicate: #Predicate<PetExpenseLog> { log in
                        log.date >= cutoff && log.pet?.id == id
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<PetExpenseLog>(
                    predicate: #Predicate<PetExpenseLog> { $0.pet?.id == id },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else if let subject, subject.kind == "human" {
            let executorID = subject.id
            let executorIDLower = executorID.lowercased()
            if let cutoff {
                descriptor = FetchDescriptor<PetExpenseLog>(
                    predicate: #Predicate<PetExpenseLog> { log in
                        log.date >= cutoff && (
                            log.executorId == executorID ||
                                log.executorId == executorIDLower ||
                                log.payerContributionsJSON.contains(executorID) ||
                                log.payerContributionsJSON.contains(executorIDLower)
                        )
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<PetExpenseLog>(
                    predicate: #Predicate<PetExpenseLog> { log in
                        log.executorId == executorID ||
                            log.executorId == executorIDLower ||
                            log.payerContributionsJSON.contains(executorID) ||
                            log.payerContributionsJSON.contains(executorIDLower)
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            }
        } else if let cutoff {
            descriptor = FetchDescriptor<PetExpenseLog>(
                predicate: #Predicate<PetExpenseLog> { $0.date >= cutoff },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<PetExpenseLog>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        }
        descriptor.fetchLimit = Self.maximumAggregateRecordCount + 1
        let fetched = try modelContext.fetch(descriptor) // route-first-frame: allow deferred-fetch
        return (
            Array(fetched.prefix(Self.maximumAggregateRecordCount)),
            fetched.count > Self.maximumAggregateRecordCount
        )
    }

    private static func parseSubjectKey(_ key: String?) -> (kind: String, id: String)? {
        guard let key, let separator = key.firstIndex(of: ":") else { return nil }
        let kind = String(key[..<separator])
        let id = String(key[key.index(after: separator)...])
        guard !kind.isEmpty, !id.isEmpty else { return nil }
        return (kind, id)
    }

    private static func matches(
        _ log: PetExpenseLog,
        subject: (kind: String, id: String)
    ) -> Bool {
        switch subject.kind {
        case "pet": return log.pet?.id.uuidString == subject.id
        case "human":
            guard let humanID = UUID(uuidString: subject.id)?.uuidString else { return false }
            // Structured allocations and legacy reimbursements must use the
            // same attribution rules as every other expense dashboard.
            return ExpenseSummaryBuilder.amountPaid(by: humanID, for: log) != 0
        default: return false
        }
    }
}

struct IslandExpenseDashboard: View {
    var standalone: Bool = true

    @Query private var pets: [Pet]
    @Query private var humans: [Human]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var snapshot = ExpenseInsightSnapshot.empty
    @State private var requestedRange: ExpenseDashboardRange = .month
    @State private var requestedSubjectKey: String?
    @State private var loadTask: Task<Void, Never>?

    init(standalone: Bool = true) {
        self.standalone = standalone

        var petDescriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { $0.passedAwayDate == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        petDescriptor.fetchLimit = 500
        _pets = Query(petDescriptor)

        var humanDescriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        humanDescriptor.fetchLimit = 500
        _humans = Query(humanDescriptor)
    }

    var body: some View {
        IslandExpenseDashboardContentView(
            standalone: standalone,
            pets: pets,
            humans: humans,
            snapshot: snapshot,
            onFilterChange: requestSnapshot
        )
        .onAppear { scheduleLoad() }
        .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
            scheduleLoad(force: true)
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func requestSnapshot(_ range: ExpenseDashboardRange, _ subjectKey: String?) {
        guard requestedRange != range || requestedSubjectKey != subjectKey else { return }
        requestedRange = range
        requestedSubjectKey = subjectKey
        scheduleLoad(force: true)
    }

    private func scheduleLoad(force: Bool = false) {
        guard force || !snapshot.hasLoaded else { return }
        loadTask?.cancel()
        let container = modelContext.container
        let range = requestedRange
        let subjectKey = requestedSubjectKey
        let petIDs = Set(pets.map(\.id))
        let humanIDs = Set(humans.filter { !$0.hasPassedAway }.map(\.id.uuidString))
        loadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 80)
            guard !Task.isCancelled else { return }
            do {
                snapshot = try await ExpenseInsightDataActor(modelContainer: container).load(
                    range: range,
                    subjectKey: subjectKey,
                    activePetIDs: petIDs,
                    activeHumanIDs: humanIDs
                )
            } catch is CancellationError {
                return
            } catch {
                OhanaLog.warning(
                    "Expense insight snapshot load failed: \(error.localizedDescription)",
                    category: "Expenses"
                )
            }
            loadTask = nil
        }
    }
}
