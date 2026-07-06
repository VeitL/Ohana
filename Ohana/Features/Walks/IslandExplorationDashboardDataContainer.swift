import SwiftData
import SwiftUI

struct IslandExplorationDashboard: View {
    var standalone: Bool = true

    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]
    @Query(sort: \PetWalkLog.startDate) private var allWalkLogs: [PetWalkLog]

    var body: some View {
        IslandExplorationDashboardContentView(
            standalone: standalone,
            pets: pets,
            humans: humans,
            allWalkLogs: allWalkLogs.filter { !$0.isRecoveryCheckpoint }
        )
    }
}
