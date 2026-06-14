import SwiftData
import SwiftUI

struct BountyBoardView: View {
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]

    var body: some View {
        BountyBoardContentView(
            humans: humans,
            pets: pets
        )
    }
}
