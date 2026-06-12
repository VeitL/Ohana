import SwiftData
import SwiftUI

struct MemberCardCreationView: View {
    let kind: MemberCreationKind
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onPetSaved: ((Pet) -> Void)?
    var onHumanSaved: ((Human) -> Void)?
    private let recoverySessionId: UUID
    private let presentationStyle: MemberCreationPresentationStyle
    private let onHomeJoinHandoffPreflight: (() -> Void)?
    private let onHomeJoinHandoffStarted: (() -> Void)?
    private let onHomeJoinHandoffEnded: (() -> Void)?

    @Query(sort: \Pet.createdAt) private var existingPets: [Pet]
    @Query(sort: \Human.createdAt) private var existingHumans: [Human]

    init(
        kind: MemberCreationKind,
        onComplete: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onPetSaved: ((Pet) -> Void)? = nil,
        onHumanSaved: ((Human) -> Void)? = nil,
        recoverySessionId: UUID = UUID(),
        presentationStyle: MemberCreationPresentationStyle = .standard,
        onHomeJoinHandoffPreflight: (() -> Void)? = nil,
        onHomeJoinHandoffStarted: (() -> Void)? = nil,
        onHomeJoinHandoffEnded: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onPetSaved = onPetSaved
        self.onHumanSaved = onHumanSaved
        self.recoverySessionId = recoverySessionId
        self.presentationStyle = presentationStyle
        self.onHomeJoinHandoffPreflight = onHomeJoinHandoffPreflight
        self.onHomeJoinHandoffStarted = onHomeJoinHandoffStarted
        self.onHomeJoinHandoffEnded = onHomeJoinHandoffEnded
    }

    var body: some View {
        MemberCardCreationContentView(
            kind: kind,
            onComplete: onComplete,
            onCancel: onCancel,
            onPetSaved: onPetSaved,
            onHumanSaved: onHumanSaved,
            existingPets: existingPets.activeRecycleBinItems,
            existingHumans: existingHumans.activeRecycleBinItems,
            recoverySessionId: recoverySessionId,
            presentationStyle: presentationStyle,
            onHomeJoinHandoffPreflight: onHomeJoinHandoffPreflight,
            onHomeJoinHandoffStarted: onHomeJoinHandoffStarted,
            onHomeJoinHandoffEnded: onHomeJoinHandoffEnded
        )
    }
}
