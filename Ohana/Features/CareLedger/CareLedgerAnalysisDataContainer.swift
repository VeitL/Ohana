//
//  CareLedgerAnalysisDataContainer.swift
//  Ohana
//
//  Screen-level query container for care ledger analysis.
//

import SwiftData
import SwiftUI

struct CareLedgerAnalysisView: View {
    @Query(sort: \CareLedgerEvent.occurredAt, order: .reverse) private var ledgerEvents: [CareLedgerEvent]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        CareLedgerAnalysisContentView(
            ledgerEvents: ledgerEvents,
            pets: pets,
            humans: humans
        )
    }
}
