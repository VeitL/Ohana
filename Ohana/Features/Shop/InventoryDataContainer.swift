import SwiftData
import SwiftUI

struct InventoryView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \ShopPurchaseRecord.purchasedAt, order: .reverse) private var purchaseRecords: [ShopPurchaseRecord]

    var body: some View {
        InventoryContentView(
            pets: pets,
            humans: humans,
            purchaseRecords: purchaseRecords
        )
    }
}
