import Foundation
import SwiftData

struct DerivedStateLifecycleBadService {
    func purgeExpiredPet(pet: Pet, context: ModelContext) {
        pet.trashExpiresAt = Date()
        context.delete(pet)
    }
}
