import SwiftData
import SwiftUI

struct CoHealthDashboardView: View {
    let human: Human

    @Query(sort: \Pet.name) private var allPets: [Pet]

    var body: some View {
        CoHealthDashboardContentView(
            human: human,
            allPets: allPets
        )
    }
}
