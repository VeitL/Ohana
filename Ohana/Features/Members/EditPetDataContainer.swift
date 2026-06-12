import SwiftData
import SwiftUI

struct EditPetSheet: View {
    let pet: Pet

    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]

    var body: some View {
        EditPetContentSheet(
            pet: pet,
            allPets: allPets.activeRecycleBinItems,
            allHumans: allHumans.activeRecycleBinItems
        )
    }
}
