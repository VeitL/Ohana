import SwiftData
import SwiftUI

struct IslandHealthDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Query(sort: \Pet.name) private var pets: [Pet]

    var body: some View {
        IslandHealthDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets
        )
    }
}
