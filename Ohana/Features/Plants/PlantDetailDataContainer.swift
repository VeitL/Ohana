import SwiftData
import SwiftUI

struct PlantDetailView: View {
    let plant: Plant
    let onOpenCalendar: (UUID) -> Void

    @Query(sort: \Household.createdAt) private var households: [Household]

    init(plant: Plant, onOpenCalendar: @escaping (UUID) -> Void = { _ in }) {
        self.plant = plant
        self.onOpenCalendar = onOpenCalendar
    }

    var body: some View {
        PlantDetailContentView(
            plant: plant,
            households: households,
            onOpenCalendar: onOpenCalendar
        )
    }
}
