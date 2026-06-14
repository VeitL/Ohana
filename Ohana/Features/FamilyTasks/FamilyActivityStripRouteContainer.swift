import SwiftData
import SwiftUI

struct FamilyActivityStripRouteContainer: View {
    let pet: Pet
    var style: FamilyActivityStripView.Style = .full
    var onExpand: () -> Void = {}

    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        FamilyActivityStripView(
            pet: pet,
            humans: humans,
            style: style,
            onExpand: onExpand
        )
    }
}
