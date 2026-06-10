import SwiftData
import SwiftUI

struct AddEventView: View {
    var onClose: (() -> Void)? = nil

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        AddEventContentView(
            onClose: onClose,
            pets: pets,
            humans: humans
        )
    }
}
