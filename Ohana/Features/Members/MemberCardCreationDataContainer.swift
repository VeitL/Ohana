import SwiftData
import SwiftUI

struct MemberCardCreationView: View {
    let kind: MemberCreationKind
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onPetSaved: ((Pet) -> Void)?
    var onHumanSaved: ((Human) -> Void)?
    private let recoverySessionId: UUID

    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    init(
        kind: MemberCreationKind,
        onComplete: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onPetSaved: ((Pet) -> Void)? = nil,
        onHumanSaved: ((Human) -> Void)? = nil,
        recoverySessionId: UUID = UUID()
    ) {
        self.kind = kind
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onPetSaved = onPetSaved
        self.onHumanSaved = onHumanSaved
        self.recoverySessionId = recoverySessionId
    }

    var body: some View {
        MemberCardCreationContentView(
            kind: kind,
            onComplete: onComplete,
            onCancel: onCancel,
            onPetSaved: onPetSaved,
            onHumanSaved: onHumanSaved,
            existingPets: existingPets,
            existingHumans: existingHumans,
            recoverySessionId: recoverySessionId
        )
    }
}
