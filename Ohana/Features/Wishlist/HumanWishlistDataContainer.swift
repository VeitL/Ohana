import SwiftData
import SwiftUI

struct HumanWishlistView: View {
    let human: Human

    @Query private var myItems: [WishlistItem]

    init(human: Human) {
        self.human = human
        let humanId = human.id.uuidString
        _myItems = Query(
            filter: #Predicate<WishlistItem> { $0.creatorId == humanId },
            sort: \WishlistItem.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        HumanWishlistContentView(
            human: human,
            myItems: myItems
        )
    }
}
