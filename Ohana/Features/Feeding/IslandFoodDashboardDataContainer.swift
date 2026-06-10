//
//  IslandFoodDashboardDataContainer.swift
//  Ohana
//
//  Screen-level food dashboard query container.
//

import SwiftData
import SwiftUI

struct IslandFoodDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(sort: \PetCareLog.date) private var allCareLogs: [PetCareLog]
    @Query(sort: \PetFoodRecord.startDate) private var allFoodRecords: [PetFoodRecord]

    var body: some View {
        IslandFoodDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets,
            allEvents: allEvents,
            allCareLogs: allCareLogs,
            allFoodRecords: allFoodRecords
        )
    }
}
