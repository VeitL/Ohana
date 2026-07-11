import SwiftData

func saveFailureBoundaryBadFixture(context: ModelContext) {
    try? context.save()
    context.safeSave()
    context.safeSaveResult()
}
