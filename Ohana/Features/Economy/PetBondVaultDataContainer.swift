import SwiftData
import SwiftUI

struct PetBondVaultView: View {
    let pet: Pet

    @Query(sort: \CoconutLedgerEntry.occurredAt, order: .reverse) private var walletLedgerEntries: [CoconutLedgerEntry]

    var body: some View {
        PetBondVaultContentView(
            pet: pet,
            walletLedgerEntries: walletLedgerEntries
        )
    }
}
