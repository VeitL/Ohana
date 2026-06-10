import SwiftData
import SwiftUI

struct PetHealthDetailView: View {
    let pet: Pet
    var isModal: Bool = false
    var initialSection: PetHealthInitialSection? = nil
    var onFullDismiss: (() -> Void)? = nil

    @Query(sort: \Event.startDate) private var allEvents: [Event]

    var body: some View {
        PetHealthDetailContentView(
            pet: pet,
            allEvents: allEvents,
            isModal: isModal,
            initialSection: initialSection,
            onFullDismiss: onFullDismiss
        )
    }
}
