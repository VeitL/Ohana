import SwiftData
import SwiftUI

struct PetMedicationView: View {
    let pet: Pet

    @Query(sort: \Event.startDate, order: .reverse) private var allEvents: [Event]

    var body: some View {
        PetMedicationContentView(
            pet: pet,
            allEvents: allEvents
        )
    }
}
