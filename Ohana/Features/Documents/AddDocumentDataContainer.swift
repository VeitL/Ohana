import SwiftData
import SwiftUI

struct AddDocumentSheet: View {
    let pet: Pet

    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        AddDocumentContentSheet(
            pet: pet,
            humans: humans
        )
    }
}
