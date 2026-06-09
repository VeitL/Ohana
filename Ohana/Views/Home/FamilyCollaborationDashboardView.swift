//
//  FamilyCollaborationDashboardView.swift
//  Ohana
//
//  Ohana member-page collaboration dashboard. Keeps collaboration and bounty in
//  one unified SwiftData task layer, with legacy bounty data imported lazily.
//

import SwiftUI
import SwiftData

struct FamilyCollaborationDashboardHost: View {
    let pets: [Pet]
    let humans: [Human]
    let pendingReminders: [Reminder]
    let familyTasks: [FamilyCollaborationTask]
    var createTaskTrigger: Int = 0
    var onEditorVisibilityChanged: (Bool) -> Void = { _ in }
    var onOpenPetActivity: (Pet) -> Void
    var onOpenWeeklyReport: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("bountyTasks") private var legacyBountyTasksRaw = ""

    var body: some View {
        FamilyCollaborationDashboardView(
            pets: pets,
            humans: humans,
            pendingReminders: pendingReminders,
            familyTasks: familyTasks,
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
    let legacyBountySyncToken: String
    let commandExecutor: FamilyCollaborationCommandExecutor
    var createTaskTrigger: Int = 0
    var onEditorVisibilityChanged: (Bool) -> Void = { _ in }
    var onOpenPetActivity: (Pet) -> Void
    var onOpenWeeklyReport: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""
    @State private var selectedPetId: UUID?
    @State private var selectedTaskScope: TaskScope = .mine
    @State private var activeSheetRoute: FamilyCollaborationSheetRoute?
    @State private var activeEditor: FamilyCollaborationEditorRoute?
    @State private var inlineEditorVisible = false
    @State private var inlineEditorDragOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var memberRailFloating = false
    @State private var legacyBountySyncTask: Task<Void, Never>?
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @ObservedObject private var avatarPipeline = AvatarPipeline.shared
    @State private var petAvatarSignatures: [UUID: String] = [:]
    @State private var petAvatarCacheKey = "family-collaboration-pet-avatar-empty"

    private enum TaskScope: String {
        case mine
        case pet
        case bounty
    }

    private var l: L10n { L10n(appLanguage) }
    private var shouldRunAmbientMotion: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }
    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId } ?? humans.first
    }

    private var activeFamilyTasks: [FamilyCollaborationTask] {
        familyTasks
            .filter { !$0.isFinished }
            .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
    }

    private var assignedFamilyTasks: [FamilyCollaborationTask] {
        guard !activeHumanId.isEmpty else { return [] }
        return activeFamilyTasks.filter { task in
            if task.status == .pendingReview {
                return task.createdById == activeHumanId
            }
            return task.assignedToId == activeHumanId || task.claimedById == activeHumanId
        }
    }

    private var bountyFamilyTasks: [FamilyCollaborationTask] {
        activeFamilyTasks.filter { $0.hasReward }
    }

    private var activePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    private var selectedPet: Pet? {
        if let selectedPetId,
           let pet = activePets.first(where: { $0.id == selectedPetId }) {
            return pet
        }
        return activePets.first
    }

    private var careGapPets: [Pet] {
        activePets.filter { !careGapLabels(for: $0).isEmpty }
    }

    private var petAvatarSourceKey: String {
        let key = activePets
            .map { "\($0.id.uuidString):\($0.avatarImageData?.count ?? 0)" }
            .joined(separator: "|")
        return key.isEmpty ? "family-collaboration-pet-avatar-empty" : key
    }

    private var todayAssignedReminders: [Reminder] {
        guard !activeHumanId.isEmpty else { return [] }
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return pendingReminders.filter { reminder in
            guard let event = reminder.event,
                  event.assigneeId == activeHumanId,
                  reminder.scheduledAt < endOfToday else { return false }
            return isActivePetEvent(event)
        }
        .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var openReminders: [Reminder] {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return pendingReminders.filter { reminder in
            guard let event = reminder.event,
                  (event.assigneeId ?? "").isEmpty,
                  reminder.scheduledAt < endOfToday else { return false }
            return isActivePetEvent(event)
        }
        .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var latestActivity: [CollaborationActivity] {
        pets.flatMap { pet in
            var rows: [CollaborationActivity] = []
            rows += pet.careLogs.map {
                CollaborationActivity(
                    title: careTitle($0.careType),
                    petName: pet.name,
                    actor: actorName($0.executorId),
                    date: $0.date,
                    icon: $0.careType.systemIconName,
                    tint: Color(hex: $0.careType.accentColorHex)
                )
            }
            rows += pet.pottyLogs.map {
                CollaborationActivity(
                    title: pottyTitle($0.pottyType),
                    petName: pet.name,
                    actor: actorName($0.executorId),
                    date: $0.date,
                    icon: $0.pottyType.systemIconName,
                    tint: Color.goYellow
                )
            }
            rows += pet.walkLogs.map {
                CollaborationActivity(
                    title: l.tr(zh: "遛狗", en: "Walk", de: "Gassi"),
                    petName: pet.name,
                    actor: actorName($0.executorId),
                    date: $0.startDate,
                    icon: "figure.walk",
                    tint: Color.goPurple
                )
            }
            return rows
        }
        .sorted { $0.date > $1.date }
    }

    private var todayActivityCount: Int {
        latestActivity.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    private var openFocusCount: Int {
        assignedFamilyTasks.count + careGapPets.count + bountyFamilyTasks.count
    }

    private var boardProgress: Double {
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

    private var mapHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "宠物地图", en: "Pet map", de: "Tierkarte"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                mapScopeButton(.mine, title: l.tr(zh: "待我", en: "Mine", de: "Meine"), count: assignedFamilyTasks.count, icon: "person.crop.circle.badge.clock", tint: Color.goPurple)
                mapScopeButton(.bounty, title: l.tr(zh: "悬赏", en: "Bounty", de: "Prämie"), count: bountyFamilyTasks.count, icon: "target", tint: Color.goTeal)
                progressScopePill
            }
        }
    }

    private func mapScopeButton(_ scope: TaskScope, title: String, count: Int, icon: String, tint: Color) -> some View {
        let selected = selectedTaskScope == scope
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(GoMotion.feedback) { selectedTaskScope = scope }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title)
                    .font(OhanaFont.caption2(.black))
                    .lineLimit(1)
                Text("\(count)")
                    .font(OhanaFont.caption2(.black))
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? tint : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var progressScopePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            Text(l.tr(zh: "完成", en: "Done", de: "Fertig"))
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
            Text("\(Int(boardProgress * 100))%")
                .font(OhanaFont.caption2(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.goPrimary, in: Capsule())
        .animation(GoMotion.feedback, value: boardProgress)
    }

    private var petMapSurface: some View {
        ZStack {
            ForEach(Array(activeMapPets.enumerated()), id: \.element.id) { index, pet in
                let offset = petMapOffset(index: index, count: activeMapPets.count)
                petMapNode(pet)
                    .offset(x: offset.x, y: offset.y)
            }

            floatingMemberRail
        }
        .frame(height: 274)
    }

    private var floatingMemberRail: some View {
        HStack(spacing: 10) {
            ForEach(Array(humans.prefix(4).enumerated()), id: \.element.id) { index, human in
                floatingMemberNode(human, index: index)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface.opacity(0.82), in: Capsule())
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.14), radius: 18, x: 0, y: 12) // ui-v4: allow floating member rail depth
        .shadow(color: Color.goPrimary.opacity(0.10), radius: 20, x: 0, y: 0) // ui-v4: allow subtle family map glow
        .offset(y: memberRailFloating ? -3 : 2)
        .animation(
            shouldRunAmbientMotion
            ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) // smoothness: allow visible-only family rail ambient float gated by AppWorkloadPolicy.
            : nil,
            value: memberRailFloating
        )
        .onAppear {
            isVisible = true
            updateAmbientMotion()
        }
        .onDisappear {
            isVisible = false
            memberRailFloating = false
        }
        .onChange(of: shouldRunAmbientMotion) { _, _ in
            updateAmbientMotion()
        }
    }

    private func updateAmbientMotion() {
        memberRailFloating = shouldRunAmbientMotion
    }

    private func floatingMemberNode(_ human: Human, index: Int) -> some View {
        VStack(spacing: 3) {
            Text(human.avatarEmoji)
                .font(OhanaFont.adaptive(size: 19)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.ohanaControlFill, in: Circle())
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10), radius: 8, x: 0, y: 5) // ui-v4: allow small floating avatar shadow
            Text(human.name)
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(human.id.uuidString == activeHumanId ? Color.goPrimary : Color.ohanaSecondaryText)
                .lineLimit(1)
                .frame(width: 44)
        }
        .offset(y: index.isMultiple(of: 2) ? -1 : 1)
        .animation(GoMotion.feedback, value: activeHumanId)
    }

    private var activeMapPets: [Pet] {
        Array(pets.filter { !$0.hasPassedAway }.prefix(6))
    }

    private func petMapOffset(index: Int, count: Int) -> CGPoint {
        guard count > 1 else { return CGPoint(x: 0, y: -62) }
        let angle = (Double(index) / Double(count)) * (.pi * 2) - .pi / 2
        let radiusX: CGFloat = 112
        let radiusY: CGFloat = 86
        return CGPoint(x: cos(angle) * radiusX, y: sin(angle) * radiusY)
    }

    private func petMapNode(_ pet: Pet) -> some View {
        let selected = selectedPet?.id == pet.id && selectedTaskScope == .pet
        let assigned = assignedTasks(for: pet).count
        let open = openReminders(for: pet).count
        let rewards = familyTasks(for: pet).filter(\.hasReward).count
        let count = assigned + open + rewards
        let tint: Color = assigned > 0 ? Color.goPurple : (rewards > 0 ? Color.goTeal : (open > 0 ? Color.goYellow : Color.goPrimary))

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(GoMotion.page) {
                selectedPetId = pet.id
                selectedTaskScope = .pet
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    petMapAvatar(pet, selected: selected, tint: tint)
                    if count > 0 {
                        Text("\(count)")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .monospacedDigit()
                            .frame(width: 23, height: 23) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(tint, in: Circle())
                            .offset(x: 3, y: -2)
                    }
                }
                Text(pet.name)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .frame(width: 82)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func petMapAvatar(_ pet: Pet, selected: Bool, tint: Color) -> some View {
        let size: CGFloat = selected ? 72 : 66
        let bodyWidth: CGFloat = selected ? 92 : 82
        let bodyHeight: CGFloat = selected ? 96 : 88
        Group {
            if let signature = petAvatarSignatures[pet.id],
               let entry = FocusWalletAvatarCache.cachedEntry(for: pet.id, signature: signature),
               let image = entry.image {
                if entry.isTransparent {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: bodyWidth, height: bodyHeight)
                        .scaleEffect(selected ? 1.05 : 1, anchor: .bottom)
                        .shadow(color: selected ? tint.opacity(0.26) : Color.clear, radius: 14, x: 0, y: 8) // ui-v4: allow selected 2.5D pet focus glow without avatar background
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.ohanaCardSurface)
                            .frame(width: size, height: size)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size - 6, height: size - 6)
                            .clipShape(Circle())
                    }
                    .overlay(Circle().strokeBorder(selected ? tint : Color.ohanaCardStroke, lineWidth: selected ? 2.5 : 1))
                    .shadow(color: selected ? tint.opacity(0.24) : Color.clear, radius: 16, x: 0, y: 8) // ui-v4: allow selected pet map node focus glow
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.ohanaCardSurface)
                        .frame(width: size, height: size)
                    Text(pet.avatarEmoji)
                        .font(OhanaFont.adaptive(size: 32)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .frame(width: size - 6, height: size - 6)
                }
                .overlay(Circle().strokeBorder(selected ? tint : Color.ohanaCardStroke, lineWidth: selected ? 2.5 : 1))
                .shadow(color: selected ? tint.opacity(0.24) : Color.clear, radius: 16, x: 0, y: 8) // ui-v4: allow selected pet map node focus glow
            }
        }
        .animation(GoMotion.feedback, value: selected)
    }

    @MainActor
    private func preparePetAvatars() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 32)
        guard !Task.isCancelled else { return }

        var signatures: [UUID: String] = [:]
        var payloads: [FocusWalletAvatarCache.Payload] = []
        for pet in activePets {
            guard let data = pet.avatarImageData else { continue }
            let signature = FocusWalletAvatarCache.signature(for: data)
            signatures[pet.id] = signature
            payloads.append(FocusWalletAvatarCache.Payload(id: pet.id, data: data))
        }

        let rawKey = payloads
            .map { "\($0.id.uuidString):\($0.data?.count ?? 0)" }
            .joined(separator: "|")
        let nextKey = rawKey.isEmpty ? "family-collaboration-pet-avatar-empty" : "family-collaboration-\(rawKey)"
        if petAvatarCacheKey != nextKey {
            avatarPipeline.cancel(key: petAvatarCacheKey)
            petAvatarCacheKey = nextKey
        }
        petAvatarSignatures = signatures
        guard !payloads.isEmpty else { return }
        avatarPipeline.seedPreviewEntries(payloads)
        avatarPipeline.preload(
            payloads: payloads,
            key: nextKey,
            delayMilliseconds: 56
        )
    }

    private func scheduleLegacyBountySync() {
        legacyBountySyncTask?.cancel()
        legacyBountySyncTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 90) {
            commandExecutor.migrateLegacyBountiesIfNeeded()
        }
    }

    private func presentEditor(_ route: FamilyCollaborationEditorRoute) {
        inlineEditorVisible = false
        inlineEditorDragOffset = 0
        activeEditor = route
        onEditorVisibilityChanged(true)
    }

    private func dismissEditor() {
        withAnimation(GoMotion.page) {
            inlineEditorVisible = false
            inlineEditorDragOffset = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 340_000_000)
            activeEditor = nil
            onEditorVisibilityChanged(false)
        }
    }

    private func inlineTaskEditorOverlay(_ route: FamilyCollaborationEditorRoute) -> some View {
        GeometryReader { proxy in
            let horizontalInset: CGFloat = 6
            let bottomInset = max(proxy.safeAreaInsets.bottom, CGFloat(8))
            let maxHeight = min(proxy.size.height * 0.86, CGFloat(660))
            let hiddenOffset = maxHeight + bottomInset + 64
            let cornerRadius: CGFloat = 52
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let editorContext = FamilyCollaborationEditorContext.resolve(
                route: route,
                reminders: pendingReminders,
                tasks: familyTasks
            )

            ZStack(alignment: .bottom) {
                collaborationInlineBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture { dismissEditor() }

                ZStack(alignment: .top) {
                    ScrollView(.vertical, showsIndicators: false) {
                        if let editorContext {
                            FamilyTaskEditorPanel(
                                context: editorContext,
                                humans: humans,
                                currentHuman: currentHuman,
                                pets: pets,
                                onClose: dismissEditor,
                                onAssignReminder: { reminder, human, reward, note in
                                    commandExecutor.assignReminder(
                                        reminder,
                                        to: human,
                                        by: currentHuman,
                                        rewardCoconuts: reward,
                                        note: note
                                    )
                                },
                                onCreateTask: { title, note, human, reward, dueAt, emoji in
                                    commandExecutor.createTask(
                                        title: title,
                                        note: note,
                                        assignedTo: human,
                                        by: currentHuman,
                                        rewardCoconuts: reward,
                                        dueAt: dueAt,
                                        emoji: emoji
                                    )
                                },
                                onUpdateTask: { task, title, note, human, reward, dueAt, emoji in
                                    commandExecutor.updateTask(
                                        task,
                                        title: title,
                                        note: note,
                                        assignedTo: human,
                                        rewardCoconuts: reward,
                                        dueAt: dueAt,
                                        emoji: emoji
                                    )
                                },
                                onDeleteTask: { task in
                                    commandExecutor.deleteTask(task)
                                }
                            )
                            .padding(.top, 32)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(maxHeight: maxHeight)
                    .clipShape(shape)

                    OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                        .gesture(editorDragGesture)
                        .zIndex(3)

                    HStack {
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                            dismissEditor()
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 8)
                    }
                    .zIndex(2)
                }
                .background {
                    FeedInlineSheetGlassSurface(cornerRadius: cornerRadius, glassMode: .regular)
                }
                .clipShape(shape)
                .frame(width: max(0, proxy.size.width - horizontalInset * 2))
                .shadow(color: Color.black.opacity(inlineEditorVisible ? 0.54 : 0), radius: 46, x: 0, y: -16) // ui-v4: allow liftedAlert inline popup shadow
                .shadow(color: Color(hex: "0B102C").opacity(inlineEditorVisible ? 0.38 : 0), radius: 26, x: 0, y: 12) // ui-v4: allow liftedAlert inline popup shadow
                .offset(y: inlineEditorVisible ? inlineEditorDragOffset : hiddenOffset)
                .opacity(inlineEditorVisible ? 1 : 0.94)
                .scaleEffect(inlineEditorVisible ? 1 : 0.982, anchor: .bottom)
                .padding(.bottom, bottomInset)
                .animation(GoMotion.feedback, value: inlineEditorDragOffset)
                .animation(GoMotion.page, value: inlineEditorVisible)
            }
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                guard editorContext != nil else {
                    dismissEditor()
                    return
                }
                inlineEditorVisible = false
                inlineEditorDragOffset = 0
                DispatchQueue.main.async {
                    withAnimation(GoMotion.page) {
                        inlineEditorVisible = true
                    }
                }
            }
        }
    }

    private var collaborationInlineBackdrop: some View {
        ZStack {
            Color.black.opacity(inlineEditorVisible ? 0.14 : 0) // ui-v4: allow modal scrim behind inline glass sheet
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(inlineEditorVisible ? 0.25 : 0) // ui-v4: allow grounding shade behind bottom glass sheet
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(GoMotion.page, value: inlineEditorVisible)
    }

    private var editorDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                inlineEditorDragOffset = min(150, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 72 || value.predictedEndTranslation.height > 130 {
                    dismissEditor()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineEditorDragOffset = 0
                    }
                }
            }
    }

    private var taskDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: drawerIcon)
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(drawerTint)
                Text(drawerTitle)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }

            if drawerRows.isEmpty {
                compactEmpty(icon: "checkmark.seal.fill", text: emptyDrawerText)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(drawerRows.prefix(4))) { row in
                        collaborationTaskRow(row)
                    }
                }
            }

            Button {
                openMoreCollaboration()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    Text(l.tr(zh: "更多", en: "More", de: "Mehr"))
                    Spacer()
                    Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.top, 2)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var drawerIcon: String {
        switch selectedTaskScope {
        case .mine: return "person.crop.circle.badge.clock"
        case .pet: return "pawprint.fill"
        case .bounty: return "target"
        }
    }

    private var drawerTint: Color {
        switch selectedTaskScope {
        case .mine: return Color.goPurple
        case .pet: return Color.goYellow
        case .bounty: return Color.goTeal
        }
    }

    private var drawerTitle: String {
        switch selectedTaskScope {
        case .mine:
            return l.tr(zh: "发给我的任务", en: "Assigned to me", de: "Meine Aufgaben")
        case .pet:
            return selectedPet.map { l.tr(zh: "\($0.name) 的待办", en: "\($0.name)'s tasks", de: "\($0.name): Aufgaben") }
                ?? l.tr(zh: "宠物待办", en: "Pet tasks", de: "Tieraufgaben")
        case .bounty:
            return l.tr(zh: "奖励悬赏", en: "Reward bounties", de: "Prämien")
        }
    }

    private var emptyDrawerText: String {
        switch selectedTaskScope {
        case .mine:
            return l.tr(zh: "已清空", en: "All clear", de: "Alles klar")
        case .pet:
            return l.tr(zh: "已照顾", en: "Covered", de: "Versorgt")
        case .bounty:
            return l.tr(zh: "暂无悬赏", en: "No bounty", de: "Keine Prämie")
        }
    }

    private enum CollaborationRow: Identifiable {
        case reminder(Reminder)
        case task(FamilyCollaborationTask)

        var id: String {
            switch self {
            case .reminder(let reminder): return "reminder-\(reminder.id.uuidString)"
            case .task(let task): return "task-\(task.id.uuidString)"
            }
        }
    }

    private var drawerRows: [CollaborationRow] {
        switch selectedTaskScope {
        case .mine:
            return assignedFamilyTasks.map { .task($0) }
        case .bounty:
            return bountyFamilyTasks.map { .task($0) }
        case .pet:
            guard let pet = selectedPet else { return [] }
            let taskRows = familyTasks(for: pet).map { CollaborationRow.task($0) }
            let assignedReminderIds = Set(taskRows.compactMap { row -> String? in
                if case .task(let task) = row { return task.relatedReminderId }
                return nil
            })
            let reminderRows = openReminders(for: pet)
                .filter { !assignedReminderIds.contains($0.id.uuidString) }
                .map { CollaborationRow.reminder($0) }
            return taskRows + reminderRows
        }
    }

    private func collaborationTaskRow(_ row: CollaborationRow) -> some View {
        switch row {
        case .reminder(let reminder):
            return AnyView(reminderAssignmentRow(reminder))
        case .task(let task):
            return AnyView(familyTaskRow(task))
        }
    }

    private func reminderAssignmentRow(_ reminder: Reminder) -> some View {
        let assignTitle = l.tr(zh: "分配", en: "Assign", de: "Zuweisen")
        return HStack(spacing: 12) {
            Image(systemName: reminder.event?.silhouetteListSymbol ?? "checklist")
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.event?.title ?? l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                presentEditor(.assignReminder(reminder.id))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(assignTitle)
                        .font(OhanaFont.caption(.black))
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(assignTitle)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            presentEditor(.assignReminder(reminder.id))
        }
    }

    private func familyTaskRow(_ task: FamilyCollaborationTask) -> some View {
        HStack(spacing: 12) {
            Text(task.emoji)
                .font(OhanaFont.title3(.black))
                .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(taskSubtitle(task))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if task.rewardCoconuts > 0 {
                Text("+\(task.rewardCoconuts)🥥")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.goYellow, in: Capsule())
                    .ohanaPing(
                        trigger: "\(task.id.uuidString)-\(task.statusRaw)",
                        accent: Color.goYellow,
                        isEnabled: task.status == .pendingReview
                    )
                    .ohanaShine(trigger: task.statusRaw, cornerRadius: 14, isEnabled: task.status == .pendingReview)
            }
            taskPrimaryAction(task)
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            presentEditor(.editTask(task.id))
        }
    }

    @ViewBuilder
    private func taskPrimaryAction(_ task: FamilyCollaborationTask) -> some View {
        if task.status == .pendingReview, task.createdById == activeHumanId {
            HStack(spacing: 6) {
                smallAction(title: l.tr(zh: "退回", en: "Redo", de: "Zurück"), color: Color.goRed) {
                    runFamilyTaskCommand {
                        commandExecutor.rejectCompletion(task, by: currentHuman)
                    }
                }
                smallAction(title: l.tr(zh: "确认", en: "Confirm", de: "Bestätigen"), color: Color.goPrimary) {
                    runFamilyTaskCommand {
                        commandExecutor.confirmCompletion(task, by: currentHuman)
                    }
                }
            }
        } else if task.status == .pendingReview {
            Text(l.tr(zh: "待确认", en: "Review", de: "Prüfung"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goYellow)
        } else if task.assignedToId == activeHumanId || task.claimedById == activeHumanId {
            smallAction(title: l.tr(zh: "完成", en: "Done", de: "Fertig"), color: Color.goPrimary) {
                runFamilyTaskCommand {
                    commandExecutor.complete(task, by: currentHuman)
                }
            }
        } else if task.isOpen, let human = currentHuman {
            smallAction(title: l.tr(zh: "接手", en: "Take", de: "Nehmen"), color: Color.goTeal) {
                runFamilyTaskCommand {
                    commandExecutor.claim(task, by: human)
                }
            }
        } else if task.createdById == activeHumanId {
            Text(l.tr(zh: "编辑", en: "Edit", de: "Bearb."))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
    }

    private func taskSubtitle(_ task: FamilyCollaborationTask) -> String {
        if task.status == .pendingReview {
            let performer = task.completedByName ?? l.tr(zh: "对方", en: "someone", de: "jemand")
            if task.createdById == activeHumanId {
                return l.tr(
                    zh: "\(performer) 已提交，等你确认",
                    en: "\(performer) submitted it, awaiting your confirmation",
                    de: "\(performer) hat eingereicht, wartet auf deine Bestätigung"
                )
            }
            return l.tr(
                zh: "已提交，等待 \(task.createdByName) 确认",
                en: "Submitted, waiting for \(task.createdByName)",
                de: "Eingereicht, wartet auf \(task.createdByName)"
            )
        }
        let target = task.assignedToName ?? task.claimedByName ?? l.tr(zh: "全家可接", en: "open", de: "offen")
        let due = task.dueAt.map { " · \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
        return "\(task.createdByName) → \(target)\(due)"
    }

    private func runFamilyTaskCommand(_ command: @escaping @MainActor () -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        OhanaFrameScheduler.runAfterNextFrame {
            command()
        }
    }

    private func openMoreCollaboration() {
        activeSheetRoute = .moreCollaboration
    }

    private func dismissMoreCollaboration() {
        if activeSheetRoute == .moreCollaboration {
            activeSheetRoute = nil
        }
    }

    private func familyTasks(for pet: Pet) -> [FamilyCollaborationTask] {
        activeFamilyTasks.filter { $0.relatedPetId == pet.id.uuidString }
    }

    private func assignedTasks(for pet: Pet) -> [FamilyCollaborationTask] {
        familyTasks(for: pet).filter { $0.assignedToId == activeHumanId || $0.claimedById == activeHumanId }
    }

    private func petTaskCount(_ pet: Pet?) -> Int {
        guard let pet else { return 0 }
        return familyTasks(for: pet).count + openReminders(for: pet).count
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "今日协作", en: "Today care", de: "Pflege heute"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(openFocusCount == 0
                         ? l.tr(zh: "全家照护节奏很稳。", en: "The family rhythm is steady.", de: "Der Familienrhythmus ist stabil.")
                         : l.tr(zh: "还有 \(openFocusCount) 个协作点。", en: "\(openFocusCount) care points remain.", de: "\(openFocusCount) Pflegepunkte offen."))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text("\(Int(boardProgress * 100))%")
                    .font(OhanaFont.metric(size: 28, .black))
                    .foregroundStyle(Color.goPrimary)
                    .contentTransition(.numericText())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.goPrimary, Color.goTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * boardProgress))
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .animation(GoMotion.feedback, value: boardProgress)
        }
    }

    private var taskBoardSection: some View {
        VStack(spacing: 10) {
            taskSlot(
                icon: "person.crop.circle.badge.clock",
                title: l.tr(zh: "待我", en: "Mine", de: "Meine"),
                count: todayAssignedReminders.count,
                subtitle: assignedSlotSubtitle,
                tint: Color.goPurple,
                actionTitle: todayAssignedReminders.isEmpty
                    ? l.tr(zh: "稳", en: "Clear", de: "Frei")
                    : l.tr(zh: "查看", en: "View", de: "Ansehen"),
                action: { openMoreCollaboration() }
            )

            taskSlot(
                icon: "pawprint.fill",
                title: l.tr(zh: "缺口", en: "Gaps", de: "Lücken"),
                count: careGapPets.count,
                subtitle: gapSlotSubtitle,
                tint: Color.goYellow,
                actionTitle: careGapPets.isEmpty
                    ? l.tr(zh: "完成", en: "Done", de: "Fertig")
                    : l.tr(zh: "补上", en: "Cover", de: "Erledigen"),
                action: {
                    if let pet = careGapPets.first {
                        onOpenPetActivity(pet)
                    } else {
                        openMoreCollaboration()
                    }
                }
            )

            taskSlot(
                icon: "target",
                title: l.tr(zh: "悬赏", en: "Bounty", de: "Prämie"),
                count: bountyFamilyTasks.count,
                subtitle: bountySlotSubtitle,
                tint: Color.goTeal,
                actionTitle: bountySlotActionTitle,
                action: { performPrimaryBountyAction() }
            )
        }
    }

    private var assignedSlotSubtitle: String {
        guard let reminder = todayAssignedReminders.first else {
            return l.tr(zh: "没有指派给你的任务", en: "Nothing assigned to you", de: "Dir ist nichts zugewiesen")
        }
        return reminder.event?.title ?? reminderSubtitle(reminder)
    }

    private var gapSlotSubtitle: String {
        guard let pet = careGapPets.first else {
            return l.tr(zh: "今天照护已补齐", en: "Care is covered today", de: "Heute ist alles erledigt")
        }
        return "\(pet.name) · \(careGapLabels(for: pet).prefix(2).joined(separator: " · "))"
    }

    private var bountySlotSubtitle: String {
        guard let task = bountyFamilyTasks.first else {
            return l.tr(zh: "发布一个奖励任务", en: "Post a reward task", de: "Prämienaufgabe erstellen")
        }
        return task.rewardCoconuts > 0
            ? "\(task.emoji) \(task.title) · +\(task.rewardCoconuts)🥥"
            : "\(task.emoji) \(task.title)"
    }

    private var bountySlotActionTitle: String {
        guard let task = bountyFamilyTasks.first else {
            return l.tr(zh: "发布", en: "Post", de: "Erstellen")
        }
        if task.status == .pendingReview, task.createdById == activeHumanId {
            return l.tr(zh: "确认", en: "Confirm", de: "Bestätigen")
        }
        if task.createdById == activeHumanId {
            return l.tr(zh: "管理", en: "Manage", de: "Verwalten")
        }
        if task.status == .pendingReview {
            return l.tr(zh: "待确认", en: "Review", de: "Prüfung")
        }
        if task.assignedToId == activeHumanId || task.claimedById == activeHumanId {
            return l.tr(zh: "完成", en: "Done", de: "Fertig")
        }
        if task.isOpen {
            return l.tr(zh: "接手", en: "Take", de: "Übernehmen")
        }
        return l.tr(zh: "查看", en: "View", de: "Ansehen")
    }

    private func taskSlot(icon: String, title: String, count: Int, subtitle: String, tint: Color, actionTitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.16))
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("\(count)")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tint, in: Capsule())
                    }
                    Text(subtitle)
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(actionTitle)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.goPrimary, in: Capsule())
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func performPrimaryBountyAction() {
        guard let task = bountyFamilyTasks.first else {
            presentEditor(.create)
            return
        }
        if task.status == .pendingReview, task.createdById == activeHumanId {
            runFamilyTaskCommand {
                commandExecutor.confirmCompletion(task, by: currentHuman)
            }
        } else if task.createdById == activeHumanId {
            openMoreCollaboration()
        } else if task.status == .pendingReview {
            openMoreCollaboration()
        } else if task.assignedToId == activeHumanId || task.claimedById == activeHumanId {
            runFamilyTaskCommand {
                commandExecutor.complete(task, by: currentHuman)
            }
        } else if task.isOpen, let human = currentHuman {
            runFamilyTaskCommand {
                commandExecutor.claim(task, by: human)
            }
        } else {
            openMoreCollaboration()
        }
    }

    private var myWorkSection: some View {
        collaborationSection(
            title: l.tr(zh: "待我处理", en: "Assigned to me", de: "Mir zugewiesen"),
            icon: "person.crop.circle.badge.clock",
            count: todayAssignedReminders.count
        ) {
            if todayAssignedReminders.isEmpty {
                compactEmpty(
                    icon: "checkmark.seal.fill",
                    text: l.tr(zh: "你今天没有被指派的任务。", en: "Nothing assigned to you today.", de: "Heute ist dir nichts zugewiesen.")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(todayAssignedReminders.prefix(3)) { reminder in
                        reminderTaskRow(reminder, role: .mine)
                    }
                }
            }
        }
    }

    private var careGapSection: some View {
        collaborationSection(
            title: l.tr(zh: "今日缺口", en: "Today gaps", de: "Heutige Lücken"),
            icon: "exclamationmark.circle.fill",
            count: careGapPets.count
        ) {
            if careGapPets.isEmpty {
                compactEmpty(
                    icon: "checkmark.circle.fill",
                    text: l.tr(zh: "今天的照护缺口已经补齐。", en: "Today's care gaps are covered.", de: "Die heutigen Lücken sind geschlossen.")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(careGapPets.prefix(4)) { pet in
                        petCareGapRow(pet)
                    }
                }
            }
        }
    }

    private var bountySection: some View {
        collaborationSection(
            title: l.tr(zh: "奖励悬赏", en: "Reward bounties", de: "Prämienaufgaben"),
            icon: "target",
            count: bountyFamilyTasks.count,
            trailing: {
                Button {
                    presentEditor(.create)
                } label: {
                    Label(l.tr(zh: "发布", en: "Post", de: "Erstellen"), systemImage: "plus")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        ) {
            if bountyFamilyTasks.isEmpty {
                compactEmpty(
                    icon: "sparkles",
                    text: l.tr(zh: "发布一个带椰子奖励的任务。", en: "Post a task with coconut rewards.", de: "Erstelle eine Aufgabe mit Kokosnuss-Belohnung.")
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(bountyFamilyTasks.prefix(3)) { task in
                        familyTaskRow(task)
                    }
                }
            }
        }
    }

    private var moreCollaborationEntry: some View {
        Button {
            openMoreCollaboration()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "ellipsis.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "更多协作", en: "More collaboration", de: "Mehr Zusammenarbeit"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "完整宠物状态、今日动态和家庭周报", en: "Full pet status, activity, and weekly report", de: "Tierstatus, Aktivität und Wochenbericht"))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var moreCollaborationContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                dismissMoreCollaboration()
                onOpenWeeklyReport()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goPrimary, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(zh: "家庭周报", en: "Family weekly report", de: "Familien-Wochenbericht"))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "看本周分工和贡献", en: "Review this week's contribution", de: "Diese Woche ansehen"))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

            collaborationSection(
                title: l.tr(zh: "发给我的任务", en: "Assigned to me", de: "Meine Aufgaben"),
                icon: "person.crop.circle.badge.clock",
                count: assignedFamilyTasks.count
            ) {
                if assignedFamilyTasks.isEmpty {
                    compactEmpty(icon: "checkmark.seal.fill", text: l.tr(zh: "当前没有发给你的任务。", en: "Nothing assigned to you right now.", de: "Dir ist gerade nichts zugewiesen."))
                } else {
                    VStack(spacing: 8) {
                        ForEach(assignedFamilyTasks) { task in
                            familyTaskRow(task)
                        }
                    }
                }
            }

            collaborationSection(
                title: l.tr(zh: "奖励悬赏", en: "Reward bounties", de: "Prämien"),
                icon: "target",
                count: bountyFamilyTasks.count,
                trailing: {
                    Button {
                        dismissMoreCollaboration()
                        presentEditor(.create)
                    } label: {
                        Label(l.tr(zh: "发布", en: "Post", de: "Erstellen"), systemImage: "plus")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.goPrimary, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            ) {
                if bountyFamilyTasks.isEmpty {
                    compactEmpty(icon: "sparkles", text: l.tr(zh: "还没有带椰子奖励的任务。", en: "No reward tasks yet.", de: "Noch keine Prämien."))
                } else {
                    VStack(spacing: 8) {
                        ForEach(bountyFamilyTasks) { task in
                            familyTaskRow(task)
                        }
                    }
                }
            }

            petCareStatusSection
            activitySection
        }
    }

    private var petCareStatusSection: some View {
        collaborationSection(
            title: l.tr(zh: "按宠物查看", en: "By pet", de: "Nach Tier"),
            icon: "pawprint.fill",
            count: pets.count
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(pets) { pet in
                    petStatusCard(pet)
                }
            }
        }
    }

    private var activitySection: some View {
        collaborationSection(
            title: l.tr(zh: "今日动态", en: "Today activity", de: "Aktivität heute"),
            icon: "waveform.path.ecg",
            count: latestActivity.filter { Calendar.current.isDateInToday($0.date) }.count
        ) {
            if latestActivity.isEmpty {
                compactEmpty(
                    icon: "clock",
                    text: l.tr(zh: "完成一次照护后会出现在这里。", en: "Care check-ins will appear here.", de: "Pflegeeinträge erscheinen hier.")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(latestActivity.prefix(5)) { activity in
                        activityRow(activity)
                    }
                }
            }
        }
    }

    private func collaborationSection<Content: View, Trailing: View>(
        title: String,
        icon: String,
        count: Int,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(count)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.goPrimary, in: Capsule())
                Spacer()
                trailing()
            }
            content()
        }
    }

    private func collaborationSection<Content: View>(
        title: String,
        icon: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        collaborationSection(title: title, icon: icon, count: count, trailing: { EmptyView() }, content: content)
    }

    private func reminderTaskRow(_ reminder: Reminder, role: ReminderRole) -> some View {
        let event = reminder.event
        return HStack(spacing: 12) {
            Image(systemName: event?.silhouetteListSymbol ?? "checklist")
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(role == .mine ? Color.goPurple : Color.goTeal)
                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent

            VStack(alignment: .leading, spacing: 3) {
                Text(event?.title ?? l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(reminderSubtitle(reminder))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(reminder.scheduledAt.formatted(.dateTime.hour().minute()))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .monospacedDigit()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func petCareGapRow(_ pet: Pet) -> some View {
        let labels = careGapLabels(for: pet)
        let openCount = openReminders(for: pet).count
        return Button {
            onOpenPetActivity(pet)
        } label: {
            HStack(spacing: 12) {
                Text(pet.avatarEmoji)
                    .font(OhanaFont.title3(.black))
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent

                VStack(alignment: .leading, spacing: 3) {
                    Text(pet.name)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(labels.prefix(3).joined(separator: " · "))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if openCount > 0 {
                    Text("\(openCount)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.arkInk)
                        .monospacedDigit()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.goYellow, in: Capsule())
                }

                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func petStatusCard(_ pet: Pet) -> some View {
        let missing = missingCareLabels(for: pet)
        return Button {
            onOpenPetActivity(pet)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(pet.avatarEmoji)
                        .font(OhanaFont.title3(.black))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pet.name)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(missing.isEmpty
                             ? l.tr(zh: "今日已稳", en: "Covered today", de: "Heute erledigt")
                             : missing.prefix(2).joined(separator: " · "))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(missing.isEmpty ? Color.goTeal : Color.goYellow)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                ProgressView(value: missing.isEmpty ? 1 : 0.42)
                    .tint(missing.isEmpty ? Color.goTeal : Color.goYellow)
                    .scaleEffect(x: 1, y: 1.3, anchor: .center)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func activityRow(_ activity: CollaborationActivity) -> some View {
        HStack(spacing: 11) {
            Image(systemName: activity.icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(activity.tint)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 2) {
                Text("\(activity.actor) · \(activity.title)")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text("\(activity.petName) · \(relativeTime(from: activity.date))")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func compactEmpty(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaTertiaryText)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(text)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func smallAction(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func isActivePetEvent(_ event: Event) -> Bool {
        let type = event.relatedEntityType.lowercased()
        guard type == "pet" || type == EntityKind.pet.rawValue.lowercased() else { return false }
        return pets.contains { $0.id.uuidString == event.relatedEntityId }
    }

    private func reminderSubtitle(_ reminder: Reminder) -> String {
        let petName = reminder.event.flatMap { event in
            pets.first { $0.id.uuidString == event.relatedEntityId }?.name
        } ?? l.tr(zh: "家庭", en: "Family", de: "Familie")
        return "\(petName) · \(relativeTime(from: reminder.scheduledAt))"
    }

    private func openReminders(for pet: Pet) -> [Reminder] {
        openReminders.filter { $0.event?.relatedEntityId == pet.id.uuidString }
    }

    private func careGapLabels(for pet: Pet) -> [String] {
        let reminderLabels = openReminders(for: pet).compactMap { reminder in
            reminder.event?.title.isEmpty == false ? reminder.event?.title : nil
        }
        if !reminderLabels.isEmpty { return reminderLabels }
        return missingCareLabels(for: pet)
    }

    private func missingCareLabels(for pet: Pet) -> [String] {
        let cal = Calendar.current
        func careDone(_ type: CareType) -> Bool {
            pet.careLogs.contains { $0.careType == type && cal.isDateInToday($0.date) }
        }
        func pottyDone() -> Bool {
            pet.pottyLogs.contains { cal.isDateInToday($0.date) } || careDone(.litter)
        }

        let species = pet.species.lowercased()
        let isDog = pet.species.contains("狗") || species.contains("dog")
        let isCat = pet.species.contains("猫") || species.contains("cat")
        let isFish = pet.species.contains("鱼") || species.contains("fish")

        let expected: [(String, Bool)]
        if isFish {
            expected = [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.waterChange), careDone(.waterChange)),
                (careTitle(.filterClean), careDone(.filterClean))
            ]
        } else if isDog {
            expected = [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.watering), careDone(.watering)),
                (l.tr(zh: "遛狗", en: "Walk", de: "Gassi"), pet.walkLogs.contains { cal.isDateInToday($0.startDate) })
            ]
        } else if isCat {
            expected = [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.watering), careDone(.watering)),
                (l.tr(zh: "厕所", en: "Toilet", de: "Toilette"), pottyDone())
            ]
        } else {
            expected = [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.watering), careDone(.watering)),
                (careTitle(.play), careDone(.play))
            ]
        }
        return expected.filter { !$0.1 }.map(\.0)
    }

    private func actorName(_ id: String?) -> String {
        guard let id, !id.isEmpty else {
            return l.tr(zh: "家人", en: "Family", de: "Familie")
        }
        return humans.first { $0.id.uuidString == id }?.name ?? l.tr(zh: "家人", en: "Family", de: "Familie")
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func careTitle(_ type: CareType) -> String {
        switch type {
        case .feeding: return l.tr(zh: "喂食", en: "Feed", de: "Füttern")
        case .watering: return l.tr(zh: "饮水", en: "Water", de: "Wasser")
        case .litter: return l.tr(zh: "铲砂", en: "Scoop", de: "Klo reinigen")
        case .waterChange: return l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case .filterClean: return l.tr(zh: "滤芯", en: "Filter", de: "Filter")
        case .cageCleaning: return l.tr(zh: "清笼", en: "Clean cage", de: "Käfig reinigen")
        case .freeFlight: return l.tr(zh: "放飞", en: "Free flight", de: "Freiflug")
        case .misting: return l.tr(zh: "保湿", en: "Mist", de: "Befeuchten")
        case .substrateChange: return l.tr(zh: "换垫材", en: "Substrate", de: "Substrat")
        case .play: return l.tr(zh: "陪玩", en: "Play", de: "Spielen")
        }
    }

    private func pottyTitle(_ type: PottyType) -> String {
        type.localizedLabel(l)
    }

    private enum ReminderRole {
        case mine
    }

    private struct CollaborationActivity: Identifiable {
        let id = UUID()
        let title: String
        let petName: String
        let actor: String
        let date: Date
        let icon: String
        let tint: Color
    }
}

private struct FamilyTaskEditorPanel: View {
    let context: FamilyCollaborationEditorContext
    let humans: [Human]
    let currentHuman: Human?
    let pets: [Pet]
    var onClose: () -> Void
    var onAssignReminder: (Reminder, Human, Int, String) -> Void
    var onCreateTask: (String, String, Human?, Int, Date?, String) -> Void
    var onUpdateTask: (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Void
    var onDeleteTask: (FamilyCollaborationTask) -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var title: String
    @State private var note: String
    @State private var selectedHumanId: String
    @State private var reward: Int
    @State private var hasDueDate: Bool
    @State private var dueAt: Date
    @State private var emoji: String

    private var l: L10n { L10n(appLanguage) }
    private let rewardOptions = [0, 20, 50, 100, 200, 500]
    private let emojiOptions = ["🎯", "🧹", "🌱", "🐾", "🛒", "💊", "🧺", "🔧"]
    private var route: FamilyCollaborationEditorRoute { context.route }

    init(
        context: FamilyCollaborationEditorContext,
        humans: [Human],
        currentHuman: Human?,
        pets: [Pet],
        onClose: @escaping () -> Void,
        onAssignReminder: @escaping (Reminder, Human, Int, String) -> Void,
        onCreateTask: @escaping (String, String, Human?, Int, Date?, String) -> Void,
        onUpdateTask: @escaping (FamilyCollaborationTask, String, String, Human?, Int, Date?, String) -> Void,
        onDeleteTask: @escaping (FamilyCollaborationTask) -> Void
    ) {
        self.context = context
        self.humans = humans
        self.currentHuman = currentHuman
        self.pets = pets
        self.onClose = onClose
        self.onAssignReminder = onAssignReminder
        self.onCreateTask = onCreateTask
        self.onUpdateTask = onUpdateTask
        self.onDeleteTask = onDeleteTask

        switch context.route {
        case .assignReminder:
            let reminder = context.reminder
            let currentHumanId = currentHuman?.id.uuidString
            let firstAssignableId = humans.first { $0.id.uuidString != currentHumanId }?.id.uuidString ?? ""
            _title = State(initialValue: reminder?.event?.title ?? "")
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _reward = State(initialValue: 0)
            _hasDueDate = State(initialValue: true)
            _dueAt = State(initialValue: reminder?.scheduledAt ?? Date())
            _emoji = State(initialValue: reminder?.event?.emoji ?? "🐾")
        case .editTask:
            let task = context.task
            let currentHumanId = currentHuman?.id.uuidString
            let firstAssignableId = humans.first { $0.id.uuidString != currentHumanId }?.id.uuidString ?? ""
            let existingAssigneeId = task?.assignedToId ?? task?.claimedById ?? ""
            let isExistingAssignable = humans.contains { human in
                human.id.uuidString == existingAssigneeId && human.id.uuidString != currentHumanId
            }
            _title = State(initialValue: task?.title ?? "")
            _note = State(initialValue: task?.note ?? "")
            _selectedHumanId = State(initialValue: isExistingAssignable ? existingAssigneeId : firstAssignableId)
            _reward = State(initialValue: task?.rewardCoconuts ?? 0)
            _hasDueDate = State(initialValue: task?.dueAt != nil)
            _dueAt = State(initialValue: task?.dueAt ?? Date())
            _emoji = State(initialValue: task?.emoji ?? "🎯")
        case .create:
            let currentHumanId = currentHuman?.id.uuidString
            let firstAssignableId = humans.first { $0.id.uuidString != currentHumanId }?.id.uuidString ?? ""
            _title = State(initialValue: "")
            _note = State(initialValue: "")
            _selectedHumanId = State(initialValue: firstAssignableId)
            _reward = State(initialValue: 20)
            _hasDueDate = State(initialValue: false)
            _dueAt = State(initialValue: Date())
            _emoji = State(initialValue: "🎯")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if case .assignReminder = route, let reminder = context.reminder {
                reminderSummary(reminder)
            } else {
                textFieldBlock(
                    title: l.tr(zh: "任务", en: "Task", de: "Aufgabe"),
                    placeholder: l.tr(zh: "例如：周末拖地", en: "e.g. mop this weekend", de: "z. B. am Wochenende wischen"),
                    text: $title
                )
            }
            textFieldBlock(
                title: l.tr(zh: "说明", en: "Note", de: "Notiz"),
                placeholder: l.tr(zh: "可选", en: "Optional", de: "Optional"),
                text: $note
            )
            assigneePicker
            rewardPicker
            dueDateBlock
            if case .create = route {
                emojiPicker
            } else if case .editTask = route {
                emojiPicker
            }
            saveButton
            if case .editTask = route, let task = context.task {
                deleteButton(task)
            }
        }
        .padding(20)
    }

    private var navigationTitle: String {
        switch route {
        case .assignReminder: return l.tr(zh: "分配待办", en: "Assign task", de: "Aufgabe zuweisen")
        case .editTask: return l.tr(zh: "任务详情", en: "Task details", de: "Aufgabendetails")
        case .create: return l.tr(zh: "发布任务", en: "Post task", de: "Aufgabe erstellen")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(navigationTitle)
                .font(OhanaFont.title2(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(
                zh: "选择其他家人，可选椰子悬赏。",
                en: "Choose another family member and optional reward.",
                de: "Anderes Familienmitglied wählen, Prämie optional."
            ))
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(Color.ohanaSecondaryText)
        }
    }

    private func reminderSummary(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.event?.silhouetteListSymbol ?? "checklist")
                .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.event?.title ?? l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe"))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func textFieldBlock(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            TextField(placeholder, text: text, axis: .vertical)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1...3)
                .padding(13)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var assigneePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "分配给", en: "Assign to", de: "Zuweisen an"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            if assignableHumans.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.slash") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(l.tr(
                        zh: "还没有可分配的其他家人",
                        en: "No other family member to assign",
                        de: "Kein anderes Familienmitglied verfügbar"
                    ))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(assignableHumans) { human in
                            assigneeChip(id: human.id.uuidString, title: human.name, emoji: human.avatarEmoji)
                        }
                    }
                }
            }
        }
    }

    private func assigneeChip(id: String, title: String, emoji: String) -> some View {
        let selected = selectedHumanId == id
        return Button {
            withAnimation(GoMotion.feedback) { selectedHumanId = id }
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(title)
                    .lineLimit(1)
            }
            .font(OhanaFont.caption(.black))
            .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(selected ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var rewardPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "椰子悬赏", en: "Coconut reward", de: "Kokos-Prämie"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 8) {
                ForEach(rewardOptions, id: \.self) { value in
                    Button {
                        withAnimation(GoMotion.feedback) { reward = value }
                    } label: {
                        Text(value == 0 ? l.tr(zh: "无", en: "None", de: "Keine") : "\(value)🥥")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(reward == value ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(reward == value ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var dueDateBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasDueDate.animation(GoMotion.feedback)) {
                Text(l.tr(zh: "截止时间", en: "Due time", de: "Fällig"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .tint(Color.goPrimary)
            if hasDueDate {
                DatePicker("", selection: $dueAt)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.tr(zh: "图标", en: "Icon", de: "Icon"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 8) {
                ForEach(emojiOptions, id: \.self) { item in
                    Button {
                        withAnimation(GoMotion.feedback) { emoji = item }
                    } label: {
                        Text(item)
                            .font(OhanaFont.title3(.black))
                            .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(emoji == item ? Color.goPrimary : Color.ohanaCardSurface, in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSave ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .disabled(!canSave)
        .buttonStyle(ScaleButtonStyle())
    }

    private func deleteButton(_ task: FamilyCollaborationTask) -> some View {
        Button {
            onDeleteTask(task)
            onClose()
        } label: {
            Text(l.tr(zh: "删除任务", en: "Delete task", de: "Aufgabe löschen"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var selectedHuman: Human? {
        assignableHumans.first { $0.id.uuidString == selectedHumanId }
    }

    private var assignableHumans: [Human] {
        guard let currentHumanId = currentHuman?.id.uuidString else {
            return humans
        }
        return humans.filter { $0.id.uuidString != currentHumanId }
    }

    private var canSave: Bool {
        switch route {
        case .assignReminder:
            return selectedHuman != nil
        case .create, .editTask:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedHuman != nil
        }
    }

    private func save() {
        let due = hasDueDate ? dueAt : nil
        switch route {
        case .assignReminder:
            guard let reminder = context.reminder else { return }
            guard let selectedHuman else { return }
            onAssignReminder(reminder, selectedHuman, reward, note)
        case .create:
            onCreateTask(title, note, selectedHuman, reward, due, emoji)
        case .editTask:
            guard let task = context.task else { return }
            onUpdateTask(task, title, note, selectedHuman, reward, due, emoji)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onClose()
    }
}
