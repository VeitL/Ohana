import SwiftData
import SwiftUI

struct AppAccountSwitcherRouteContainer: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query private var electronicPets: [OasisElectronicPet]

    let onSwitched: () -> Void

    var body: some View {
        HumanAccountSwitcherSheet(
            humans: humans,
            homePets: pets,
            homeHumans: humans,
            homeElectronicPets: electronicPets,
            onSwitched: onSwitched
        )
    }
}

struct AppSettingsSheetRouteContainer: View {
    @Query(sort: \Household.createdAt) private var households: [Household]
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query private var electronicPets: [OasisElectronicPet]

    let onClose: () -> Void

    var body: some View {
        SettingsView(
            homeHouseholds: households,
            homePets: pets,
            homeHumans: humans,
            homeElectronicPets: electronicPets,
            onClose: onClose
        )
    }
}
