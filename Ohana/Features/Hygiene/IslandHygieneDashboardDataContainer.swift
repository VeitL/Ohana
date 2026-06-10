import SwiftData
import SwiftUI

struct IslandHygieneDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil

    @Query(sort: \Pet.name) private var pets: [Pet]

    var body: some View {
        IslandHygieneDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets
        )
    }
}
