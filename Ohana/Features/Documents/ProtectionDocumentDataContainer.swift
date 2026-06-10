import SwiftData
import SwiftUI

struct ProtectionDocumentPopup: View {
    let pet: Pet
    var existing: PetDocument?
    let onClose: () -> Void

    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        ProtectionDocumentContentPopup(
            pet: pet,
            humans: humans,
            existing: existing,
            onClose: onClose
        )
    }
}
