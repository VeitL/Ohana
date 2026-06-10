import SwiftData
import SwiftUI

struct ReminderObservabilityView: View {
    @Query(sort: \Reminder.scheduledAt) private var reminders: [Reminder]
    @Query(sort: \CareLedgerEvent.occurredAt, order: .reverse) private var ledgerEvents: [CareLedgerEvent]

    var body: some View {
        ReminderObservabilityContentView(
            reminders: reminders,
            ledgerEvents: ledgerEvents
        )
    }
}
