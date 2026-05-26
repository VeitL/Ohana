//
//  HomeV2DataContainer.swift
//  Ohana
//
//  SwiftData query boundary for Home V2.
//

import SwiftData
import SwiftUI

struct HomeV2DataContainer: View {
    @Binding var selectedPet: Pet?
    @Binding var selectedHuman: Human?
    @Binding var selectedPlant: Plant?
    @Binding var selectedPetTab: PetDetailTab

    @Query(sort: \Pet.createdAt, order: .reverse) private var pets: [Pet]
    @Query(sort: \Human.createdAt, order: .reverse) private var humans: [Human]
    @Query(sort: \Plant.createdAt, order: .reverse) private var plants: [Plant]
    @Query(sort: \OasisElectronicPet.obtainedAt, order: .reverse) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \Event.startDate) private var allEvents: [Event]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" || $0.status == "failed" }, sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(sort: \HumanMedication.createdAt, order: .reverse) private var humanMedications: [HumanMedication]
    @Query(sort: \HumanMedicationLog.scheduledTime, order: .reverse) private var humanMedicationLogs: [HumanMedicationLog]
    @Query private var careLogs: [PetCareLog]
    @Query private var walkLogs: [PetWalkLog]
    @Query private var pottyLogs: [PetPottyLog]
    @Query private var humanWeightLogs: [HumanWeightLog]
    @Query private var familyTasks: [FamilyCollaborationTask]
    @Query private var exchangeRequests: [CoconutExchangeRequest]

    init(
        selectedPet: Binding<Pet?>,
        selectedHuman: Binding<Human?>,
        selectedPlant: Binding<Plant?>,
        selectedPetTab: Binding<PetDetailTab>
    ) {
        _selectedPet = selectedPet
        _selectedHuman = selectedHuman
        _selectedPlant = selectedPlant
        _selectedPetTab = selectedPetTab

        let todayStart = Calendar.current.startOfDay(for: Date())
        let activeStatus = FamilyCollaborationTaskStatus.active.rawValue
        let claimedStatus = FamilyCollaborationTaskStatus.claimed.rawValue
        let pendingReviewStatus = FamilyCollaborationTaskStatus.pendingReview.rawValue
        let pendingExchangeStatus = CoconutExchangeRequestStatus.pending.rawValue
        _careLogs = Query(
            filter: #Predicate<PetCareLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _walkLogs = Query(
            filter: #Predicate<PetWalkLog> { $0.startDate >= todayStart },
            sort: \.startDate,
            order: .reverse
        )
        _pottyLogs = Query(
            filter: #Predicate<PetPottyLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _humanWeightLogs = Query(
            filter: #Predicate<HumanWeightLog> { $0.date >= todayStart },
            sort: \.date,
            order: .reverse
        )
        _familyTasks = Query(
            filter: #Predicate<FamilyCollaborationTask> {
                $0.statusRaw == activeStatus || $0.statusRaw == claimedStatus || $0.statusRaw == pendingReviewStatus
            },
            sort: \.updatedAt,
            order: .reverse
        )
        _exchangeRequests = Query(
            filter: #Predicate<CoconutExchangeRequest> { $0.statusRaw == pendingExchangeStatus },
            sort: \.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        HomeV2View(
            selectedPet: $selectedPet,
            selectedHuman: $selectedHuman,
            selectedPlant: $selectedPlant,
            selectedPetTab: $selectedPetTab,
            pets: pets,
            humans: humans,
            plants: plants,
            electronicPets: electronicPets,
            allEvents: allEvents,
            pendingReminders: pendingReminders,
            humanMedications: humanMedications,
            humanMedicationLogs: humanMedicationLogs,
            careLogs: careLogs,
            walkLogs: walkLogs,
            pottyLogs: pottyLogs,
            humanWeightLogs: humanWeightLogs,
            familyTasks: familyTasks,
            exchangeRequests: exchangeRequests
        )
    }
}
