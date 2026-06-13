import Foundation
import SwiftData

struct RecurringEconomyBoundariesGoodCommand {
    let careEvents: CareEventRecording

    func record(pet: Pet, context: ModelContext, executorId: String) {
        _ = careEvents.recordCare(
            pet: pet,
            type: .feeding,
            amountMl: 0,
            context: context,
            executorId: executorId,
            reward: .feeding,
            quality: .none,
            date: Date()
        )
    }
}
