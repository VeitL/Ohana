import SwiftData
import SwiftUI

struct MemberCardCreationView: View {
    @Environment(\.modelContext) private var modelContext

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

    @State private var existingPets: [Pet] = []
    @State private var existingHumans: [Human] = []
    @State private var dataLoadTask: Task<Void, Never>?

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
            existingPets: existingPets,
            existingHumans: existingHumans,
            recoverySessionId: recoverySessionId,
            presentationStyle: presentationStyle,
            onHomeJoinHandoffPreflight: onHomeJoinHandoffPreflight,
            onHomeJoinHandoffStarted: onHomeJoinHandoffStarted,
            onHomeJoinHandoffEnded: onHomeJoinHandoffEnded
        )
        .onAppear {
            scheduleExistingMemberLoad()
        }
        .onDisappear {
            dataLoadTask?.cancel()
            dataLoadTask = nil
        }
    }

    private func scheduleExistingMemberLoad(force: Bool = false) {
        guard force || (existingPets.isEmpty && existingHumans.isEmpty) else { return }
        guard dataLoadTask == nil else { return }
        let delay = presentationStyle == .onboarding ? UInt64(180) : UInt64(96)
        dataLoadTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: delay) {
            let data = MemberCreationRouteData.load(from: modelContext)
            existingPets = data.pets
            existingHumans = data.humans
            dataLoadTask = nil
        }
    }
}

private struct MemberCreationRouteData {
    var pets: [Pet]
    var humans: [Human]

    static func load(from context: ModelContext) -> MemberCreationRouteData {
        MemberCreationRouteData(
            pets: fetch(
                FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Pet"
            ),
            humans: fetch(
                FetchDescriptor<Human>(sortBy: [SortDescriptor(\.createdAt)]),
                context: context,
                name: "Human"
            )
        )
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        name: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor) // route-first-frame: allow deferred-fetch
        } catch {
            OhanaLog.warning(
                "Member creation route data fetch failed for \(name): \(error.localizedDescription)",
                category: "Members"
            )
            return []
        }
    }
}
