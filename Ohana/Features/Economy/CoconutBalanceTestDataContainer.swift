import SwiftData
import SwiftUI

struct CoconutBalanceTestView: View {
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \CoconutAccount.updatedAt, order: .reverse) private var walletAccounts: [CoconutAccount]

    var body: some View {
        CoconutBalanceTestContentView(
            humans: humans,
            walletAccounts: walletAccounts
        )
    }
}
