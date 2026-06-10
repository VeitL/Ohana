//
//  AchievementWallDataContainer.swift
//  Ohana
//
//  Screen-level SwiftData query container for the achievement wall.
//

import SwiftData
import SwiftUI

struct AchievementWallView: View {
    let pet: Pet
    var allPets: [Pet] = []
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    @Query(sort: \OasisElectronicPet.obtainedAt, order: .reverse) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \OasisCritterFragmentBalance.updatedAt, order: .reverse) private var critterFragments: [OasisCritterFragmentBalance]
    @Query(sort: \OasisCritterActionLog.createdAt, order: .reverse) private var critterActionLogs: [OasisCritterActionLog]
    @Query(sort: \GachaOwnedItem.latestObtainedAt, order: .reverse) private var gachaOwnedItems: [GachaOwnedItem]
    @Query(sort: \GachaDrawLog.drawDate, order: .reverse) private var gachaDrawLogs: [GachaDrawLog]
    @Query(sort: \Human.createdAt, order: .reverse) private var allHumans: [Human]
    @Query(sort: \HumanMedication.createdAt, order: .reverse) private var humanMedications: [HumanMedication]
    @Query(sort: \HumanMedicationLog.createdAt, order: .reverse) private var humanMedicationLogs: [HumanMedicationLog]
    @Query(sort: \PetExpenseLog.date, order: .reverse) private var allExpenseLogs: [PetExpenseLog]

    var body: some View {
        AchievementWallContentView(
            pet: pet,
            allPets: allPets,
            onPresentCoconutLog: onPresentCoconutLog,
            electronicPets: electronicPets,
            critterFragments: critterFragments,
            critterActionLogs: critterActionLogs,
            gachaOwnedItems: gachaOwnedItems,
            gachaDrawLogs: gachaDrawLogs,
            allHumans: allHumans,
            humanMedications: humanMedications,
            humanMedicationLogs: humanMedicationLogs,
            allExpenseLogs: allExpenseLogs
        )
    }
}
