import SwiftData
import SwiftUI

struct PetHygieneDetailView: View {
    let pet: Pet

    @Query(sort: \Reminder.scheduledAt, order: .forward) private var allReminders: [Reminder]

    var body: some View {
        PetHygieneDetailContentView(
            pet: pet,
            allReminders: allReminders
        )
    }
}
