import SwiftData
import SwiftUI

struct PlantDetailView: View {
    let plant: Plant

    @Query(sort: \Household.createdAt) private var households: [Household]

    init(plant: Plant) {
        self.plant = plant
    }

    var body: some View {
        PlantDetailContentView(
            plant: plant,
            households: households
        )
    }
}
