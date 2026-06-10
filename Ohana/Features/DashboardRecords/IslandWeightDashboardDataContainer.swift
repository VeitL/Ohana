import SwiftData
import SwiftUI

struct IslandWeightDashboard: View {
    var standalone: Bool = true

    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]

    var body: some View {
        IslandWeightDashboardContentView(
            standalone: standalone,
            pets: pets,
            humans: humans
        )
    }
}
