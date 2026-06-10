import SwiftData
import SwiftUI

struct IslandPottyDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil

    @Query(sort: \Pet.name) private var pets: [Pet]

    var body: some View {
        IslandPottyDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets
        )
    }
}
