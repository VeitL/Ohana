import SwiftData
import SwiftUI

struct CrewRosterOverlayRouteContainer: View {
    let initialMode: CrewRosterMode
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onAddEntity: ((EntityType) -> Void)?
    var onClose: (() -> Void)?
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var addMemberTrigger: Bool = false
    var safeTopInset: CGFloat = 0
    var safeBottomInset: CGFloat = 0
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    var body: some View {
        if OnlineFeatureGate.allows(.onlineCollaboration) {
            CrewRosterCollaborationRouteDataContainer(
                initialMode: initialMode,
                pets: pets,
                humans: humans,
                onSelectPet: onSelectPet,
                onSelectHuman: onSelectHuman,
                onAddEntity: onAddEntity,
                onClose: onClose,
                hideToolbar: hideToolbar,
                searchTrigger: searchTrigger,
                addMemberTrigger: addMemberTrigger,
                safeTopInset: safeTopInset,
                safeBottomInset: safeBottomInset,
                onPresentCoconutLog: onPresentCoconutLog
            )
        } else {
            CrewRosterOverlay(
                initialMode: .members,
                pets: pets,
                humans: humans,
                plants: [],
                pendingReminders: [],
                familyTasks: [],
                onSelectPet: onSelectPet,
                onSelectHuman: onSelectHuman,
                onAddEntity: onAddEntity,
                onClose: onClose,
                hideToolbar: hideToolbar,
                searchTrigger: searchTrigger,
                addMemberTrigger: addMemberTrigger,
                safeTopInset: safeTopInset,
                safeBottomInset: safeBottomInset,
                onPresentCoconutLog: onPresentCoconutLog
            )
        }
    }
}

private struct CrewRosterCollaborationRouteDataContainer: View {
    let initialMode: CrewRosterMode
    let pets: [Pet]
    let humans: [Human]
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onAddEntity: ((EntityType) -> Void)?
    var onClose: (() -> Void)?
    var hideToolbar: Bool
    var searchTrigger: Bool
    var addMemberTrigger: Bool
    var safeTopInset: CGFloat
    var safeBottomInset: CGFloat
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?

    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]
    @Query(sort: \FamilyCollaborationTask.updatedAt, order: .reverse) private var familyTasks: [FamilyCollaborationTask]

    var body: some View {
        CrewRosterOverlay(
            initialMode: initialMode,
            pets: pets,
            humans: humans,
            plants: [],
            pendingReminders: pendingReminders,
            familyTasks: familyTasks,
            onSelectPet: onSelectPet,
            onSelectHuman: onSelectHuman,
            onAddEntity: onAddEntity,
            onClose: onClose,
            hideToolbar: hideToolbar,
            searchTrigger: searchTrigger,
            addMemberTrigger: addMemberTrigger,
            safeTopInset: safeTopInset,
            safeBottomInset: safeBottomInset,
            onPresentCoconutLog: onPresentCoconutLog
        )
    }
}
