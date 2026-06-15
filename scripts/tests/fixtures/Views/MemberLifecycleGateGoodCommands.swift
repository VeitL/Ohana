import SwiftData

enum MemberLifecycleGateGoodCommandService {
    @MainActor
    static func recordCare(pet: Pet, context: ModelContext) {
        let disposition = MemberLifecycleGate.disposition(pet: pet, writeKind: .care)
        guard disposition.allowsCareFactWrite else { return }
        context.insert(PetCareLog(type: .feeding, pet: pet))
    }
}
