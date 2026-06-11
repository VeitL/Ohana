import SwiftData
import SwiftUI

struct ExpenseHistoryView: View {
    let pet: Pet
    var onRemove: (() -> Void)?
    var showsCloseButton: Bool = true

    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]

    var body: some View {
        ExpenseHistoryContentView(
            pet: pet,
            allHumans: allHumans,
            allPets: allPets,
            onRemove: onRemove,
            showsCloseButton: showsCloseButton
        )
    }
}
