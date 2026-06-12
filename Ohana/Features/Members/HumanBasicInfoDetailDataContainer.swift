import SwiftData
import SwiftUI

struct HumanBasicInfoDetailView: View {
    let human: Human

    @Query private var allPets: [Pet]
    @Query private var allHumans: [Human]

    var body: some View {
        HumanBasicInfoDetailContentView(
            human: human,
            allPets: allPets.activeRecycleBinItems,
            allHumans: allHumans.activeRecycleBinItems
        )
    }
}
