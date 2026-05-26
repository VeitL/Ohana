//
//  HomeDataContainer.swift
//  Ohana
//
//  SwiftData query boundary for the home flow.
//

import SwiftUI
import SwiftData

struct HomeDataContainer: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab
    let heroNS: Namespace.ID

    @Query(sort: \Pet.createdAt, order: .reverse) private var pets: [Pet]
    @Query(sort: \Human.createdAt, order: .reverse) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \OasisElectronicPet.obtainedAt, order: .reverse) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" || $0.status == "failed" }, sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(sort: \HumanMedication.createdAt, order: .reverse) private var humanMedications: [HumanMedication]
    @Query(sort: \HumanMedicationLog.scheduledTime, order: .reverse) private var humanMedicationLogs: [HumanMedicationLog]

    var body: some View {
        FocusHomeView(
            selectedPet: $selectedPet,
            selectedHuman: $selectedHuman,
            selectedPlant: $selectedPlant,
            selectedPetTab: $selectedPetTab,
            heroNS: heroNS,
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            allEvents: allEvents,
            pendingReminders: pendingReminders,
            humanMedications: humanMedications,
            humanMedicationLogs: humanMedicationLogs,
            commandExecutor: HomeCommandExecutor(modelContext: modelContext)
        )
    }
}
