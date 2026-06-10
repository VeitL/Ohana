import SwiftData
import SwiftUI

struct PlantDetailView: View {
    let plant: Plant

    @Query(sort: \Household.createdAt) private var households: [Household]

    var body: some View {
        PlantDetailContentView(
            plant: plant,
            households: households
        )
    }
}
