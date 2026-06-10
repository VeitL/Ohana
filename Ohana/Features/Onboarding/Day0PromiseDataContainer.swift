import SwiftData
import SwiftUI

struct Day0PromiseSheet: View {
    let petName: String
    let species: String
    let petEmoji: String
    let onDone: () -> Void

    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        Day0PromiseContentSheet(
            petName: petName,
            species: species,
            petEmoji: petEmoji,
            humans: humans,
            onDone: onDone
        )
    }
}
