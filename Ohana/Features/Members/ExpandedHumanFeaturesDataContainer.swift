//
//  ExpandedHumanFeaturesDataContainer.swift
//  Ohana
//
//  Screen-level human feature sheet query container.
//

import SwiftData
import SwiftUI

struct ExpandedHumanFeaturesSheet: View {
    let human: Human

    @Query private var allPets: [Pet]
    @Query private var allHumans: [Human]
    @Query(
        filter: #Predicate<Reminder> { $0.status == "pending" },
        sort: \Reminder.scheduledAt
    ) private var allPendingReminders: [Reminder]
    @Query private var allMeds: [HumanMedication]
    @Query private var allReports: [HumanHealthReport]

    var body: some View {
        ExpandedHumanFeaturesContentSheet(
            human: human,
            allPets: allPets,
            allHumans: allHumans,
            allPendingReminders: allPendingReminders,
            allMeds: allMeds,
            allReports: allReports
        )
    }
}
