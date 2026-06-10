//
//  IslandWealthDashboardDataContainer.swift
//  Ohana
//
//  Screen-level wallet query container for the wealth dashboard.
//

import SwiftData
import SwiftUI

struct IslandWealthDashboardView: View {
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]
    @Query(sort: \CoconutAccount.updatedAt, order: .reverse) private var walletAccounts: [CoconutAccount]
    @Query(sort: \CoconutLedgerEntry.occurredAt, order: .reverse) private var walletLedgerEntries: [CoconutLedgerEntry]

    var body: some View {
        IslandWealthDashboardContentView(
            pets: pets,
            humans: humans,
            walletAccounts: walletAccounts,
            walletLedgerEntries: walletLedgerEntries
        )
    }
}
