import SwiftData
import SwiftUI

struct PlantDetailView: View {
    let plant: Plant
    let initialFeatureDestination: PlantFeatureDestination?

    @Query(sort: \Household.createdAt) private var households: [Household]

    init(plant: Plant, initialFeatureDestination: PlantFeatureDestination? = nil) {
        self.plant = plant
        self.initialFeatureDestination = initialFeatureDestination
    }

    var body: some View {
        PlantDetailContentView(
            plant: plant,
            households: households,
            initialFeatureDestination: initialFeatureDestination
        )
    }
}
