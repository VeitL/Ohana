import SwiftData

func saveFailureBoundaryBadFixture(context: ModelContext) {
    context.safeSave()
    context.safeSaveResult()
}
