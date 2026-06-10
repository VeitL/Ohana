import SwiftData
import SwiftUI

struct IslandExpenseDashboard: View {
    var standalone: Bool = true

    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        IslandExpenseDashboardContentView(
            standalone: standalone,
            pets: pets,
            humans: humans
        )
    }
}
