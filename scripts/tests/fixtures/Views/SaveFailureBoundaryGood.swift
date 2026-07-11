import SwiftData

func saveFailureBoundaryGoodFixture(context: ModelContext) throws {
    try context.save()
    _ = context.safeSaveResult(publishFailureEvent: true)
}
