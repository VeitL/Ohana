import SwiftData
import SwiftUI

struct IslandMedicationDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Query(sort: \Pet.name) private var pets: [Pet]

    var body: some View {
        IslandMedicationDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets
        )
    }
}
