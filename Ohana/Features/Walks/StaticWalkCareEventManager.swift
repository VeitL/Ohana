import Foundation
import SwiftData

@MainActor
final class StaticWalkCareEventManager: WalkCareEventManaging {
    private let dependencies: CareEventServiceDependencies

    init(dependencies: CareEventServiceDependencies? = nil) {
        self.dependencies = dependencies ?? .live()
    }

    func recordSharedWalk(
        sourcePet: Pet,
        targets: [Pet],
        distanceMeters: Double,
        endDate: Date?,
        context: ModelContext,
        executorId: String?,
        executorIds: [String],
        startDate: Date
    ) -> SharedPetActionResult {
        CareEventService.recordSharedWalk(
            sourcePet: sourcePet,
            targets: targets,
            distanceMeters: distanceMeters,
            endDate: endDate,
            context: context,
            executorId: executorId,
            executorIds: executorIds,
            startDate: startDate,
            dependencies: dependencies
        )
    }
}
