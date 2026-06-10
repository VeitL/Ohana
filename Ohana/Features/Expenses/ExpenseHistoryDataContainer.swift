import SwiftData
import SwiftUI

struct ExpenseHistoryView: View {
    let pet: Pet
    var onRemove: (() -> Void)? = nil
    var showsCloseButton: Bool = true

    @Query(sort: \Human.createdAt) private var allHumans: [Human]

    var body: some View {
        ExpenseHistoryContentView(
            pet: pet,
            allHumans: allHumans,
            onRemove: onRemove,
            showsCloseButton: showsCloseButton
        )
    }
}
