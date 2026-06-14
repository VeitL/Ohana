import SwiftData

struct DerivedStateLifecycleBadService {
    func deletePet(pet: Pet, context: ModelContext) {
        context.delete(pet)
    }
}
