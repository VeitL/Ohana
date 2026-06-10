import SwiftData
import SwiftUI

struct CoHealthDashboardFullView: View {
    let human: Human

    @Query(sort: \Pet.name) private var allPets: [Pet]

    var body: some View {
        CoHealthDashboardFullContentView(
            human: human,
            allPets: allPets
        )
    }
}
