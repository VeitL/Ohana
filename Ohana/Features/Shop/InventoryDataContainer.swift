import SwiftData
import SwiftUI

struct InventoryView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        InventoryContentView(
            pets: pets,
            humans: humans
        )
    }
}
