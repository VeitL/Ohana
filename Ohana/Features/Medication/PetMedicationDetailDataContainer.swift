import SwiftData
import SwiftUI

struct PetMedicationDetailSheet: View {
    let pet: Pet
    let medication: PetMedication

    @Query(sort: \Event.startDate, order: .reverse) private var allEvents: [Event]

    var body: some View {
        PetMedicationDetailContentSheet(
            pet: pet,
            medication: medication,
            allEvents: allEvents
        )
    }
}
