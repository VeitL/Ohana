import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct ReminderMaintenanceServiceTests {
    @Test func pendingReminderQueryExcludesNonPendingAndSortsBySchedule() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let later = Reminder(scheduledAt: Date(timeIntervalSince1970: 300))
        let completed = Reminder(scheduledAt: Date(timeIntervalSince1970: 100))
        completed.statusEnum = .completed
        let earlier = Reminder(scheduledAt: Date(timeIntervalSince1970: 200))
        let skipped = Reminder(scheduledAt: Date(timeIntervalSince1970: 50))
        skipped.statusEnum = .skipped

        context.insert(later)
        context.insert(completed)
        context.insert(earlier)
        context.insert(skipped)
        try context.save()

        let reminders = ReminderMaintenanceService.pendingReminders(context: context)

        #expect(reminders.map(\.id) == [earlier.id, later.id])
    }

    @Test func runCompensatesOnlyPendingExpiredReminders() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let expiredPending = Reminder(scheduledAt: Date(timeIntervalSince1970: 1))
        let expiredCompleted = Reminder(scheduledAt: Date(timeIntervalSince1970: 1))
        expiredCompleted.statusEnum = .completed
        let futurePending = Reminder(scheduledAt: Date().addingTimeInterval(86400))

        context.insert(expiredPending)
        context.insert(expiredCompleted)
        context.insert(futurePending)
        try context.save()

        let result = await ReminderMaintenanceService.runPendingReminderMaintenance(context: context)

        #expect(result.completed)
        #expect(result.pendingCount == 2)
        #expect(expiredPending.statusEnum == .skipped)
        #expect(expiredCompleted.statusEnum == .completed)
        #expect(futurePending.statusEnum == .pending)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV64.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
