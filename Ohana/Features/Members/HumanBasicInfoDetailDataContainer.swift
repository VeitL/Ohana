import SwiftData
import SwiftUI

struct HumanBasicInfoDetailView: View {
    let human: Human
    var startsEditing = false
    var onSave: (() -> Void)? = nil

    @Query private var allPets: [Pet]
    @Query private var allHumans: [Human]

    var body: some View {
        HumanBasicInfoDetailContentView(
            human: human,
            allPets: allPets,
            allHumans: allHumans,
            startsEditing: startsEditing,
            onSave: onSave
        )
    }
}
