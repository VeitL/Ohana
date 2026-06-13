import SwiftData
import SwiftUI

struct WalkTrackingCardHost: View {
    let pet: Pet
    var onCloseSummaryToPetCard: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]

    var body: some View {
        let commandExecutor = WalkTrackingCommandExecutor(modelContext: modelContext, services: appServices)
        WalkTrackingCard(
            pet: pet,
            allPets: allPets.activeRecycleBinItems,
            allHumans: allHumans.activeRecycleBinItems,
            snapshot: WalkTrackingSnapshot.make(pet: pet, manager: appServices.walking),
            onCloseSummaryToPetCard: onCloseSummaryToPetCard,
            onStopWalk: { sharedTargets, executorIds in
                commandExecutor.stopWalk(
                    manager: appServices.walking,
                    sharedTargets: sharedTargets,
                    executorIds: executorIds
                )
            },
            onSaveWeeklyGoal: { goal in
                commandExecutor.saveWeeklyGoal(goal, for: pet)
            }
        )
    }
}
