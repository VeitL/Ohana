//
//  FamilyCollaborationDashboardView.swift
//  Ohana
//
//  Ohana member-page collaboration dashboard. Keeps collaboration and bounty in
//  one unified SwiftData task layer, with legacy bounty data imported lazily.
//

import SwiftData
import SwiftUI

struct FamilyCollaborationDashboardHost: View {
    let pets: [Pet]
    let humans: [Human]
    let pendingReminders: [Reminder]
    let familyTasks: [FamilyCollaborationTask]
    let careLedgerEntries: [FamilyCareLedgerEntry]
    var createTaskTrigger: Int = 0
    var onEditorVisibilityChanged: (Bool) -> Void = { _ in }
    var onOpenPetActivity: (Pet) -> Void
    var onOpenWeeklyReport: () -> Void

    @Environment(\.modelContext) var modelContext
    @Environment(AppServices.self) var appServices
    @AppStorage("bountyTasks") var legacyBountyTasksRaw = ""

    var body: some View {
        FamilyCollaborationDashboardView(
            pets: pets,
            humans: humans,
            pendingReminders: pendingReminders,
            familyTasks: familyTasks,
            careLedgerEntries: careLedgerEntries,
            legacyBountySyncToken: legacyBountyTasksRaw,
            commandExecutor: FamilyCollaborationCommandExecutor(
                modelContext: modelContext,
                familyTasks: appServices.familyTasks,
                revisions: appServices.domainRevisions
            ),
            createTaskTrigger: createTaskTrigger,
            onEditorVisibilityChanged: onEditorVisibilityChanged,
            onOpenPetActivity: onOpenPetActivity,
            onOpenWeeklyReport: onOpenWeeklyReport
        )
    }
}

struct FamilyCollaborationDashboardView: View {
    let pets: [Pet]
    let humans: [Human]
    let pendingReminders: [Reminder]
    let familyTasks: [FamilyCollaborationTask]
    let careLedgerEntries: [FamilyCareLedgerEntry]
    let legacyBountySyncToken: String
    let commandExecutor: FamilyCollaborationCommandExecutor
    var createTaskTrigger: Int = 0
    var onEditorVisibilityChanged: (Bool) -> Void = { _ in }
    var onOpenPetActivity: (Pet) -> Void
    var onOpenWeeklyReport: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appLanguage") var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") var activeHumanId = ""
    @State var selectedPetId: UUID?
    @State var selectedTaskScope: TaskScope = .mine
    @State var activeSheetRoute: FamilyCollaborationSheetRoute?
    @State var activeEditor: FamilyCollaborationEditorRoute?
    @State var inlineEditorVisible = false
    @State var inlineEditorDragOffset: CGFloat = 0
    @State var isVisible = false
    @State var memberRailFloating = false
    @State var legacyBountySyncTask: Task<Void, Never>?
    @StateObject var workloadPolicy = AppWorkloadPolicy.shared
    @ObservedObject var avatarPipeline = AvatarPipelineRegistry.current
    @State var petAvatarSignatures: [UUID: String] = [:]
    @State var petAvatarCacheKey = "family-collaboration-pet-avatar-empty"

    enum TaskScope: String {
        case mine
        case pet
        case bounty
    }

    var l: L10n { L10n(appLanguage) }
    var shouldRunAmbientMotion: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }

    var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId } ?? humans.first
    }

    var activeFamilyTasks: [FamilyCollaborationTask] {
        familyTasks
            .filter { !$0.isFinished }
            .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
    }

    var assignedFamilyTasks: [FamilyCollaborationTask] {
        guard !activeHumanId.isEmpty else { return [] }
        return activeFamilyTasks.filter { task in
            if task.status == .pendingReview {
                return task.createdById == activeHumanId
            }
            return task.assignedToId == activeHumanId || task.claimedById == activeHumanId
        }
    }

    var bountyFamilyTasks: [FamilyCollaborationTask] {
        activeFamilyTasks.filter(\.hasReward)
    }

    var activePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    var activePetNamesByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: activePets.map { ($0.id, $0.name) })
    }

    var selectedPet: Pet? {
        if let selectedPetId,
           let pet = activePets.first(where: { $0.id == selectedPetId }) {
            return pet
        }
        return activePets.first
    }

    var careGapPets: [Pet] {
        activePets.filter { !careGapLabels(for: $0).isEmpty }
    }

    var petAvatarSourceKey: String {
        let key = activePets
            .map { "\($0.id.uuidString):\($0.avatarImageData?.count ?? 0)" }
            .joined(separator: "|")
        return key.isEmpty ? "family-collaboration-pet-avatar-empty" : key
    }

    var todayAssignedReminders: [Reminder] {
        guard !activeHumanId.isEmpty else { return [] }
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return pendingReminders.filter { reminder in
            guard let event = reminder.event,
                  MemberLifecycleActiveScheduleResolver.eventAssignedToHuman(event, humanId: activeHumanId),
                  reminder.scheduledAt < endOfToday else { return false }
            return isActivePetEvent(event)
        }
        .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var openReminders: [Reminder] {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return pendingReminders.filter { reminder in
            guard let event = reminder.event,
                  MemberLifecycleActiveScheduleResolver.eventHasNoHumanAssignee(event),
                  reminder.scheduledAt < endOfToday else { return false }
            return isActivePetEvent(event)
        }
        .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var latestActivity: [CollaborationActivity] {
        careLedgerEntries.compactMap { entry in
            guard let petName = activePetNamesByID[entry.petID],
                  let activity = collaborationActivity(from: entry, petName: petName)
            else { return nil }
            return activity
        }
        .sorted { $0.date > $1.date }
    }

    var todayActivityCount: Int {
        latestActivity.count(where: { Calendar.current.isDateInToday($0.date) })
    }

    var openFocusCount: Int {
        assignedFamilyTasks.count + careGapPets.count + bountyFamilyTasks.count
    }

    var boardProgress: Double {
        let done = Double(todayActivityCount)
        let open = Double(openFocusCount)
        guard done + open > 0 else { return 1 }
        return min(1, max(0, done / (done + open)))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    mapHeader
                    petMapSurface
                    taskDrawer
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 88)
            }

            if let activeEditor {
                inlineTaskEditorOverlay(activeEditor)
                    .zIndex(20)
            }
        }
        .onAppear {
            scheduleLegacyBountySync()
            if selectedPetId == nil {
                selectedPetId = pets.first { !$0.hasPassedAway }?.id
            }
            if activeEditor == nil {
                onEditorVisibilityChanged(false)
            }
        }
        .onDisappear {
            legacyBountySyncTask?.cancel()
            avatarPipeline.cancel(key: petAvatarCacheKey)
            onEditorVisibilityChanged(false)
        }
        .task(id: petAvatarSourceKey) {
            await preparePetAvatars()
        }
        .onChange(of: legacyBountySyncToken) { _, _ in
            scheduleLegacyBountySync()
        }
        .onChange(of: createTaskTrigger) { _, newValue in
            guard newValue != 0 else { return }
            presentEditor(.create)
        }
        .familyCollaborationPresentations(
            sheetRoute: $activeSheetRoute,
            title: l.tr(zh: "更多协作", en: "More collaboration", de: "Mehr Zusammenarbeit"),
            doneTitle: l.tr(zh: "完成", en: "Done", de: "Fertig")
        ) {
            moreCollaborationContent
        }
        .interactiveDismissDisabled(activeEditor != nil)
    }
}
