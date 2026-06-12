//
//  FamilyWeeklyReportDataContainer.swift
//  Ohana
//
//  Screen-level query container for the weekly family report.
//

import SwiftData
import SwiftUI

struct FamilyWeeklyReportDashboardView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \CareLedgerEvent.occurredAt, order: .reverse) private var ledgerEvents: [CareLedgerEvent]

    var body: some View {
        FamilyWeeklyReportDashboardContentView(
            pets: pets.activeRecycleBinItems,
            humans: humans.activeRecycleBinItems,
            ledgerEvents: ledgerEvents
        )
    }
}
