import SwiftData
import SwiftUI

struct CoconutShopRouteContainer: View {
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \CoconutExchangeRequest.createdAt, order: .reverse) private var exchangeRequests: [CoconutExchangeRequest]

    let initialCategory: ShopItem.ShopCategory

    init(initialCategory: ShopItem.ShopCategory = .appIcon) {
        self.initialCategory = initialCategory
    }

    var body: some View {
        CoconutShopView(
            initialCategory: initialCategory,
            humans: humans,
            pets: pets,
            exchangeRequests: exchangeRequests
        )
    }
}
