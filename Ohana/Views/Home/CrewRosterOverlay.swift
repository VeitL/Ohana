//
//  CrewRosterOverlay.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

// MARK: - Ohana 图鉴主视图

struct CrewRosterOverlay: View {
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onAddEntity: ((EntityType) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var addMemberTrigger: Bool = false
    var safeTopInset: CGFloat = 0
    var safeBottomInset: CGFloat = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]

    @State private var activeFullScreenRoute: CrewRosterFullScreenRoute?
    @State private var activeSheetRoute: CrewRosterSheetRoute?
    @State private var memberAddMenuExpanded = false
    @State private var memberAddMenuItemsVisible = false
    @State private var selectedRosterMode: CrewRosterMode = .members
    @State private var collaborationCreateTaskTrigger = 0
    @State private var collaborationEditorPresented = false
    @State private var pendingInlineSavedPet: Pet? = nil
    @State private var pendingInlineSavedHuman: Human? = nil
    @State private var expandedRosterCardId: UUID? = nil
    @State private var showHomeStackFullAlert = false
    @State private var homeStackFullMemberName = ""
    @State private var homeVisibilityOverrides: [UUID: Bool] = [:]
    @State private var homeVisibilityCommitTasks: [UUID: Task<Void, Never>] = [:]
    @State private var rosterHeroProgress: CGFloat = 0
    @State private var rosterHeroDirection: Int = 1
    @State private var editingRosterCardId: UUID? = nil
    @State private var rosterEditorProgress: CGFloat = 0
    @State private var isRosterEditorContentMounted = false
    @Namespace private var rosterWalletNamespace
    @Namespace private var rosterHeroNamespace
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""
    @Environment(\.colorScheme) private var colorScheme

    private var isMaterial: Bool { false }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var matAccent:  Color { Color(hex: "FF5A00") }
    private var l: L10n { L10n(appLanguage) }

    private var filteredPets: [Pet] { Array(pets) }
    private var filteredHumans: [Human] { Array(humans) }
    private var filteredPlants: [Plant] { Array(plants) }
    private var isEmpty: Bool { pets.isEmpty && humans.isEmpty && plants.isEmpty }
    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var showsFamilyCollaboration: Bool { humans.count > 1 && !activePets.isEmpty }
    private var activeHumanCoconutBalance: Int {
        humans.first { $0.id.uuidString == activeHumanIdStr }?.coconutBalance ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                IslandMoodWeatherView(mood: .breezy)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    rosterTopChrome

                    if isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                emptyState
                                Spacer(minLength: 60)
                            }
                            .padding(.top, 4)
                        }
                    } else if showsFamilyCollaboration && selectedRosterMode == .collaboration {
                        FamilyCollaborationDashboardHost(
                            pets: activePets,
                            humans: humans,
                            pendingReminders: pendingReminders,
                            createTaskTrigger: collaborationCreateTaskTrigger,
                            onEditorVisibilityChanged: { isPresented in
                                withAnimation(GoMotion.feedback) {
                                    collaborationEditorPresented = isPresented
                                }
                            },
                            onOpenPetActivity: { activeSheetRoute = .familyActivity($0.id) },
                            onOpenWeeklyReport: { activeSheetRoute = .familyWeeklyReport }
                        )
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else {
                        rosterWalletDeck
                            .transition(.opacity.combined(with: .scale(scale: 0.992)))
                            .animation(GoMotion.page, value: selectedRosterMode)
                    }
                }

                if memberAddMenuExpanded && selectedRosterMode == .members {
                    Color.black.opacity(0.001) // ui-v4: allow transparent tap shield for expanded FAB menu
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeMemberAddMenu()
                        }
                }

                if shouldShowRosterFab {
                    rosterFloatingActionOverlay
                        .padding(.trailing, 22)
                        .padding(.bottom, safeBottomInset + 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.scale(scale: 0.86, anchor: .center).combined(with: .opacity))
                }

            }
            .toolbar(.hidden, for: .navigationBar)
            .crewRosterPresentations(
                pets: pets,
                l: l,
                fullScreenRoute: $activeFullScreenRoute,
                sheetRoute: $activeSheetRoute,
                onAddEntityDismissed: resetPendingInlineAddEntity,
                onAddEntityComplete: completeInlineAddEntity,
                onPetSaved: { pendingInlineSavedPet = $0 },
                onHumanSaved: { pendingInlineSavedHuman = $0 }
            )
            .onChange(of: addMemberTrigger) { _, _ in
                memberAddMenuItemsVisible = false
                memberAddMenuExpanded = false
                selectedRosterMode = .members
                openMemberAddMenu()
            }
            .onAppear {
                selectedRosterMode = .members
            }
            .onChange(of: showsFamilyCollaboration) { _, canCollaborate in
                if !canCollaborate {
                    selectedRosterMode = .members
                }
                collaborationEditorPresented = false
                memberAddMenuItemsVisible = false
                memberAddMenuExpanded = false
            }
            .alert(homeVisibilityLimitTitle, isPresented: $showHomeStackFullAlert) {
                Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {}
            } message: {
                Text(homeVisibilityLimitMessage)
            }
            .interactiveDismissDisabled(collaborationEditorPresented)
        }
    }

    // MARK: - Top Chrome

    private var rosterTopChrome: some View {
        VStack(spacing: 12) {
            rosterHeader
            rosterControlRow
        }
        .padding(.horizontal, 18)
        .padding(.top, safeTopInset + 16)
        .padding(.bottom, 12)
        .background {
            LinearGradient(
                colors: [
                    Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.36 : 0.54),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var rosterControlRow: some View {
        HStack(spacing: 8) {
            Spacer()
            if showsFamilyCollaboration {
                if selectedRosterMode == .collaboration {
                    rosterCoconutButton
                }
                rosterModeShortcutButton
            }
        }
        .frame(height: showsFamilyCollaboration ? 34 : 0)
    }

    private var rosterCoconutButton: some View {
        CoconutBalanceCapsule(balance: activeHumanCoconutBalance) {
            activeFullScreenRoute = .coconutLog
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(l.tr(zh: "我的椰子 \(activeHumanCoconutBalance)", en: "My coconuts \(activeHumanCoconutBalance)", de: "Meine Kokosnuesse \(activeHumanCoconutBalance)"))
    }

    private var rosterModeShortcutButton: some View {
        let showsMembers = selectedRosterMode == .members || !showsFamilyCollaboration
        let title = showsMembers
            ? l.tr(zh: "协作", en: "Care", de: "Pflege")
            : l.tr(zh: "成员", en: "Members", de: "Mitglieder")
        let icon = showsMembers ? "hands.sparkles.fill" : "person.2.fill"
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(GoMotion.feedback) {
                selectedRosterMode = showsMembers && showsFamilyCollaboration ? .collaboration : .members
                memberAddMenuItemsVisible = false
                memberAddMenuExpanded = false
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(Color.goPrimary, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(title)
    }

    private var rosterHeader: some View {
        let isCollaboration = showsFamilyCollaboration && selectedRosterMode == .collaboration
        return HStack(spacing: 12) {
            Image(systemName: isCollaboration ? "hands.sparkles.fill" : "person.2.crop.square.stack.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42)
                .background(Color.goPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(isCollaboration
                     ? l.tr(zh: "家庭协作", en: "Family Care", de: "Familienpflege")
                     : l.tr(zh: "Ohana 成员", en: "Ohana Members", de: "Ohana Mitglieder"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isCollaboration
                     ? l.tr(zh: "任务、悬赏和今日分工", en: "Tasks, bounties, and today's handoff", de: "Aufgaben, Prämien und heutige Übergabe")
                     : l.tr(zh: "成员和首页显示", en: "Members and home cards", de: "Mitglieder und Startkarten"))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            if !hideToolbar {
                Button { closeRoster() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 40, height: 40)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
            }
        }
    }

    private func closeRoster() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var shouldShowRosterFab: Bool {
        guard !isPresentingAddEntity else { return false }
        guard expandedRosterCardId == nil else { return false }
        if showsFamilyCollaboration && selectedRosterMode == .collaboration {
            return !collaborationEditorPresented
        }
        return selectedRosterMode == .members || isEmpty
    }

    private var isPresentingAddEntity: Bool {
        if case .addEntity = activeFullScreenRoute { return true }
        return false
    }

    private func presentInlineAddEntity(_ type: EntityType) {
        memberAddMenuItemsVisible = false
        withAnimation(GoMotion.fab) {
            memberAddMenuExpanded = false
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            guard activeFullScreenRoute == nil else { return }
            activeFullScreenRoute = .addEntity(type)
        }
    }

    private func completeInlineAddEntity() {
        let savedPet = pendingInlineSavedPet
        let savedHuman = pendingInlineSavedHuman
        pendingInlineSavedPet = nil
        pendingInlineSavedHuman = nil

        withAnimation(GoMotion.sheet) {
            activeFullScreenRoute = nil
        }

        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            if let savedPet {
                onSelectPet(savedPet)
            } else if let savedHuman {
                onSelectHuman(savedHuman)
            }
        }
    }

    private func resetPendingInlineAddEntity() {
        pendingInlineSavedPet = nil
        pendingInlineSavedHuman = nil
    }

    private var rosterFloatingActionOverlay: some View {
        VStack(alignment: .trailing, spacing: 14) {
            if selectedRosterMode == .members && memberAddMenuExpanded {
                ForEach(Array(memberAddMenuItems.enumerated()), id: \.element) { index, type in
                    memberAddActionRow(type)
                        .ohanaStaggeredMenuItem(isVisible: memberAddMenuItemsVisible, index: index, total: memberAddMenuItems.count)
                        .allowsHitTesting(memberAddMenuItemsVisible)
                        .accessibilityHidden(!memberAddMenuItemsVisible)
                }
            }

            Button {
                OhanaFeedback.medium()
                if showsFamilyCollaboration && selectedRosterMode == .collaboration {
                    withAnimation(GoMotion.page) {
                        collaborationCreateTaskTrigger &+= 1
                    }
                } else {
                    toggleMemberAddMenu()
                }
            } label: {
                Image(systemName: selectedRosterMode == .members && memberAddMenuExpanded ? "xmark" : "plus")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 58, height: 58)
                    .background(Color.goPrimary, in: Circle())
                    .rotationEffect(.degrees(selectedRosterMode == .members && memberAddMenuExpanded ? 90 : 0))
                    .shadow(color: Color.goPrimary.opacity(0.28), radius: 18, x: 0, y: 10) // ui-v4: allow floating FAB lift shadow
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(fabAccessibilityLabel)
        }
    }

    private var memberAddMenuItems: [EntityType] {
        [.pet, .human, .plant]
    }

    private func openMemberAddMenu() {
        guard !memberAddMenuExpanded else { return }
        memberAddMenuItemsVisible = false
        withAnimation(GoMotion.fab) {
            memberAddMenuExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(GoMotion.fab) {
                memberAddMenuItemsVisible = true
            }
        }
    }

    private func closeMemberAddMenu() {
        guard memberAddMenuExpanded else { return }
        withAnimation(GoMotion.fab) {
            memberAddMenuItemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if memberAddMenuExpanded && !memberAddMenuItemsVisible {
                withAnimation(GoMotion.fab) {
                    memberAddMenuExpanded = false
                }
            }
        }
    }

    private func toggleMemberAddMenu() {
        memberAddMenuExpanded ? closeMemberAddMenu() : openMemberAddMenu()
    }

    private var fabAccessibilityLabel: String {
        if showsFamilyCollaboration && selectedRosterMode == .collaboration {
            return l.tr(zh: "发布协作任务", en: "Post collaboration task", de: "Aufgabe erstellen")
        }
        return memberAddMenuExpanded
            ? l.tr(zh: "收起添加菜单", en: "Collapse add menu", de: "Menü einklappen")
            : l.tr(zh: "添加成员", en: "Add member", de: "Mitglied hinzufügen")
    }

    private func memberAddActionRow(_ type: EntityType) -> some View {
        Button {
            OhanaFeedback.light()
            if let onAddEntity {
                memberAddMenuItemsVisible = false
                memberAddMenuExpanded = false
                onAddEntity(type)
            } else {
                presentInlineAddEntity(type)
            }
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Text(addEntityTitle(for: type))
                        .font(OhanaFont.caption(.black))
                        .lineLimit(1)
                    if !type.isAvailable {
                        Text(l.addEntityWIP)
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.goPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.goPrimary.opacity(0.14), in: Capsule())
                    }
                }
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.ohanaCardSurface, in: Capsule())

                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 48, height: 48)
                    .background(Color.goPrimary, in: Circle())
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(addEntityTitle(for: type))
    }

    private func addEntityTitle(for type: EntityType) -> String {
        switch type {
        case .pet: return l.addEntityPetTitle
        case .human: return l.addEntityHumanTitle
        case .plant: return l.addEntityPlantTitle
        }
    }

    // MARK: - Bento Dex 主体
    private var rosterFocusCards: [FocusCard] {
        let petCards = filteredPets.map { FocusCard.from($0, includeAvatarData: true) }
        let humanCards = filteredHumans.map { FocusCard.from($0, includeAvatarData: true) }
        let plantCards = filteredPlants.map { plantFocusCard($0) }
        return (petCards + humanCards + plantCards).sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    private var rosterWalletDeck: some View {
        CrewRosterWalletScene(
            cards: rosterFocusCards,
            pets: filteredPets,
            safeTop: 0,
            safeBottom: 20,
            selectedCardId: expandedRosterCardId,
            progress: rosterHeroProgress,
            heroDirection: rosterHeroDirection,
            reduceMotion: AppWorkloadPolicy.shared.interactionMotionBudget(isVisible: true) != .full,
            namespace: rosterWalletNamespace,
            heroNamespace: rosterHeroNamespace,
            avatarCacheRevision: 0,
            editingCardId: editingRosterCardId,
            editorProgress: rosterEditorProgress,
            isEditorContentMounted: isRosterEditorContentMounted,
            expandedInfo: { card in
                CrewRosterWalletInfoOverlay(card: card)
            },
            cardOverlay: { card in
                rosterHomeVisibilityOverlay(for: card)
            },
            editorContent: { card in
                rosterProfileEditor(for: card)
            },
            onSelect: openRosterWalletCard,
            onCollapse: closeRosterWalletCard,
            onOpenEditor: openRosterCardEditor,
            onCloseEditor: closeRosterCardEditor
        )
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func rosterProfileEditor(for card: FocusCard) -> some View {
        if let pet = filteredPets.first(where: { $0.id == card.id }) {
            CrewRosterPetProfileEditor(pet: pet, onCancel: closeRosterCardEditor) {
                postHomeVisibilityChanged(id: pet.id, kind: "pet")
                closeRosterCardEditor()
            }
        } else if let human = filteredHumans.first(where: { $0.id == card.id }) {
            CrewRosterHumanProfileEditor(human: human, onCancel: closeRosterCardEditor) {
                postHomeVisibilityChanged(id: human.id, kind: "human")
                closeRosterCardEditor()
            }
        } else if let plant = filteredPlants.first(where: { $0.id == card.id }) {
            CrewRosterPlantProfileEditor(plant: plant, onCancel: closeRosterCardEditor) {
                postHomeVisibilityChanged(id: plant.id, kind: "plant")
                closeRosterCardEditor()
            }
        }
    }

    @ViewBuilder
    private func rosterHomeVisibilityOverlay(for card: FocusCard) -> some View {
        if let pet = filteredPets.first(where: { $0.id == card.id && !$0.hasPassedAway }) {
            RosterHomeVisibilityToggle(
                isOn: effectivePetHomeVisibility(pet),
                label: l.tr(zh: "首页", en: "Home", de: "Start")
            ) {
                setPetHomeVisibility(pet, visible: $0)
            }
        } else if let human = filteredHumans.first(where: { $0.id == card.id }) {
            RosterHomeVisibilityToggle(
                isOn: effectiveHumanHomeVisibility(human),
                label: l.tr(zh: "首页", en: "Home", de: "Start")
            ) {
                setHumanHomeVisibility(human, visible: $0)
            }
        }
    }

    private var homeVisibilityLimitTitle: String {
        l.tr(zh: "首页卡片堆已满", en: "Home card stack is full", de: "Startkartenstapel ist voll")
    }

    private var homeVisibilityLimitMessage: String {
        let name = homeStackFullMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? l.tr(zh: "该成员", en: "this member", de: "dieses Mitglied") : name
        return l.tr(
            zh: "首页最多显示 \(HomeCardVisibility.maxVisibleCards) 张卡片。请先关闭一个成员的首页开关，再开启 \(displayName)。",
            en: "Home can show up to \(HomeCardVisibility.maxVisibleCards) cards. Turn off another member first, then enable \(displayName).",
            de: "Auf Start sind bis zu \(HomeCardVisibility.maxVisibleCards) Karten moglich. Schalte zuerst ein anderes Mitglied aus, dann \(displayName) ein."
        )
    }

    private func setPetHomeVisibility(_ pet: Pet, visible: Bool) -> Bool {
        let currentlyVisible = effectivePetHomeVisibility(pet)
        guard currentlyVisible != visible else { return true }
        OhanaFeedback.light()
        if visible,
           !canShowHomeCard(id: pet.id) {
            showHomeVisibilityLimit(for: pet.name)
            return false
        }
        withAnimation(GoMotion.feedback) {
            homeVisibilityOverrides[pet.id] = visible
        }
        scheduleHomeVisibilityCommit(id: pet.id) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                hiddenHomePetIDsRaw = HomeCardVisibility.rawBySettingPet(pet, visible: visible, raw: hiddenHomePetIDsRaw)
                homeVisibilityOverrides[pet.id] = nil
            }
            postHomeVisibilityChanged(id: pet.id, kind: "pet")
        }
        return true
    }

    private func setHumanHomeVisibility(_ human: Human, visible: Bool) -> Bool {
        guard effectiveHumanHomeVisibility(human) != visible else { return true }
        OhanaFeedback.light()
        if visible,
           !canShowHomeCard(id: human.id) {
            showHomeVisibilityLimit(for: human.name)
            return false
        }
        withAnimation(GoMotion.feedback) {
            homeVisibilityOverrides[human.id] = visible
        }
        scheduleHomeVisibilityCommit(id: human.id) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                human.shouldShowOnHome = visible
                homeVisibilityOverrides[human.id] = nil
            }
            modelContext.safeSave()
            postHomeVisibilityChanged(id: human.id, kind: "human")
        }
        return true
    }

    private func effectivePetHomeVisibility(_ pet: Pet) -> Bool {
        homeVisibilityOverrides[pet.id] ?? HomeCardVisibility.isPetVisible(pet, raw: hiddenHomePetIDsRaw)
    }

    private func effectiveHumanHomeVisibility(_ human: Human) -> Bool {
        homeVisibilityOverrides[human.id] ?? human.shouldShowOnHome
    }

    private func canShowHomeCard(id: UUID) -> Bool {
        if effectiveHomeVisibilityCount() < HomeCardVisibility.maxVisibleCards {
            return true
        }
        if pets.contains(where: { $0.id == id && effectivePetHomeVisibility($0) }) {
            return true
        }
        if humans.contains(where: { $0.id == id && effectiveHumanHomeVisibility($0) }) {
            return true
        }
        return false
    }

    private func effectiveHomeVisibilityCount() -> Int {
        let petCount = pets.filter { !$0.hasPassedAway && effectivePetHomeVisibility($0) }.count
        let humanCount = humans.filter { effectiveHumanHomeVisibility($0) }.count
        return petCount + humanCount
    }

    private func scheduleHomeVisibilityCommit(id: UUID, operation: @escaping @MainActor () -> Void) {
        homeVisibilityCommitTasks[id]?.cancel()
        homeVisibilityCommitTasks[id] = OhanaFrameScheduler.runAfterNextFrame(milliseconds: homeVisibilityCommitDelayMilliseconds) {
            guard !Task.isCancelled else { return }
            operation()
            homeVisibilityCommitTasks[id] = nil
        }
    }

    private var homeVisibilityCommitDelayMilliseconds: UInt64 {
        AppWorkloadPolicy.shared.interactionMotionBudget(isVisible: true).allowsMotion ? 220 : 70
    }

    private func showHomeVisibilityLimit(for name: String) {
        homeStackFullMemberName = name
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        showHomeStackFullAlert = true
    }

    private func postHomeVisibilityChanged(id: UUID, kind: String) {
        NotificationCenter.default.post(
            name: .ohanaMemberProfileDidChange,
            object: nil,
            userInfo: ["id": id.uuidString, "kind": kind]
        )
    }

    private func plantFocusCard(_ plant: Plant) -> FocusCard {
        let days = max(0, Calendar.current.dateComponents([.day], from: plant.createdAt, to: Date()).day ?? 0)
        let needsCare = plant.needsWatering || plant.needsFertilizing
        let status = needsCare
            ? l.tr(zh: "待照护", en: "Needs care", de: "Braucht Pflege")
            : l.tr(zh: "状态良好", en: "All good", de: "Alles gut")
        return FocusCard(
            id: plant.id,
            name: plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name,
            kind: plant.species.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.species,
            emoji: plant.avatarEmoji.isEmpty ? "leaf" : plant.avatarEmoji,
            color: Color(hex: plant.themeColorHex),
            streak: 0,
            coconutBalance: 0,
            createdAt: plant.createdAt,
            daysTogetherText: l.tr(zh: "\(days) 天", en: "\(days) days", de: "\(days) Tage"),
            ageText: status,
            personalityHint: plant.location.isEmpty ? nil : plant.location,
            avatarImageData: plant.avatarImageData,
            themeColorHex: plant.themeColorHex,
            daysTogether: days,
            statusBadgeText: status,
            statusBadgeIsWarning: needsCare,
            isReal: true,
            actions: [
                .init(label: l.tr(zh: "浇水", en: "WATER", de: "GIESSEN"), icon: "drop.fill", colorHex: "00D4AA"),
                .init(label: l.tr(zh: "施肥", en: "FEED", de: "DUENGEN"), icon: "leaf.fill", colorHex: "9EF06A")
            ]
        )
    }

    private func openRosterWalletCard(_ card: FocusCard) {
        guard expandedRosterCardId == nil else { return }
        memberAddMenuItemsVisible = false
        memberAddMenuExpanded = false
        editingRosterCardId = nil
        rosterEditorProgress = 0
        isRosterEditorContentMounted = false
        rosterHeroDirection = 1
        rosterHeroProgress = 0
        expandedRosterCardId = card.id
        OhanaFeedback.medium()
        OhanaFrameScheduler.runAfterNextFrame {
            withAnimation(HeroAnim.walletSpring) {
                rosterHeroProgress = 1
            }
        }
    }

    private func closeRosterWalletCard() {
        guard editingRosterCardId == nil else {
            closeRosterCardEditor()
            return
        }
        guard expandedRosterCardId != nil else { return }
        rosterHeroDirection = -1
        OhanaFeedback.light()
        withAnimation(HeroAnim.walletCollapseSpring) {
            rosterHeroProgress = 0
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 520) {
            guard rosterHeroProgress <= 0.02 else { return }
            expandedRosterCardId = nil
            rosterHeroDirection = 1
        }
    }

    private func openRosterCardEditor(_ card: FocusCard) {
        guard expandedRosterCardId == card.id, editingRosterCardId == nil else { return }
        editingRosterCardId = card.id
        rosterEditorProgress = 0
        isRosterEditorContentMounted = false
        OhanaFeedback.medium()
        OhanaFrameScheduler.runAfterNextFrame {
            withAnimation(HeroAnim.walletSpring) {
                rosterEditorProgress = 1
            }
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 170) {
            guard editingRosterCardId == card.id else { return }
            withAnimation(GoMotion.feedback) {
                isRosterEditorContentMounted = true
            }
        }
    }

    private func closeRosterCardEditor() {
        guard editingRosterCardId != nil else { return }
        isRosterEditorContentMounted = false
        OhanaFeedback.light()
        withAnimation(HeroAnim.walletCollapseSpring) {
            rosterEditorProgress = 0
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 360) {
            guard rosterEditorProgress <= 0.02 else { return }
            editingRosterCardId = nil
            isRosterEditorContentMounted = false
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 72, height: 72)
                .background(Color.goPrimary.opacity(0.14), in: Circle())
            Text(l.tr(zh: "还没有成员", en: "No members yet", de: "Noch keine Mitglieder"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "添加宠物、人类或植物开始照顾。", en: "Add a pet, human, or plant to begin.", de: "Füge Tier, Mensch oder Pflanze hinzu."))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }

}
private struct RosterHomeVisibilityToggle: View {
    let isOn: Bool
    let label: String
    let onChange: (Bool) -> Bool

    @State private var visualOverride: Bool?

    private var visualIsOn: Bool {
        visualOverride ?? isOn
    }

    var body: some View {
        Button {
            let nextValue = !visualIsOn
            withAnimation(GoMotion.feedback) {
                visualOverride = nextValue
            }
            guard onChange(nextValue) else {
                withAnimation(GoMotion.feedback) {
                    visualOverride = isOn
                }
                return
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: visualIsOn ? "house.fill" : "house")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(visualIsOn ? Color.goPrimary : Color.goCardWhite.opacity(0.78))
                    .symbolEffect(.bounce, value: visualIsOn)

                ZStack(alignment: visualIsOn ? .trailing : .leading) {
                    Capsule()
                        .fill(visualIsOn ? Color.goPrimary.opacity(0.92) : Color.goCardWhite.opacity(0.18))
                        .frame(width: 28, height: 16)
                    Circle()
                        .fill(visualIsOn ? Color.arkInk : Color.goCardWhite.opacity(0.92))
                        .frame(width: 12, height: 12)
                        .padding(.horizontal, 2)
                }
            }
            .frame(width: 58, height: 32)
            .background(Color.goCardWhite.opacity(visualIsOn ? 0.18 : 0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.goCardWhite.opacity(visualIsOn ? 0.22 : 0.16), lineWidth: 0.75))
            .contentShape(Capsule())
            .animation(GoMotion.feedback, value: visualIsOn)
            .frame(width: 66, height: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityValue(visualIsOn ? "开启" : "关闭")
        .onChange(of: isOn) { _, newValue in
            guard visualOverride == newValue else { return }
            visualOverride = nil
        }
    }
}

private struct CrewRosterEditorShell<Content: View>: View {
    let title: String
    let subtitle: String
    let tint: Color
    let onCancel: () -> Void
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.goCardWhite)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("取消")

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.goCardWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(subtitle)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.goCardWhite.opacity(0.66))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    onSave()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 44, height: 44)
                        .background(tint, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("保存")
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    content()
                }
                .padding(.bottom, 10)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.arkInk.opacity(0.50), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.goCardWhite.opacity(0.16), lineWidth: 0.75)
        )
    }
}

private struct CrewRosterPetProfileEditor: View {
    let pet: Pet
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var species = ""
    @State private var breed = ""
    @State private var gender = "unknown"
    @State private var isNeutered = false
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var hasHomeDate = false
    @State private var homeDate = Date()
    @State private var themeHex = ""
    @State private var notes = ""

    private let speciesOptions = ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]

    var body: some View {
        CrewRosterEditorShell(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "编辑宠物" : name,
            subtitle: "宠物基本信息",
            tint: Color(hex: resolvedThemeHex),
            onCancel: onCancel,
            onSave: saveChanges
        ) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor")
            CrewRosterEditorMenuRow(title: "物种", icon: "pawprint.fill", selection: $species, options: speciesOptions)
            CrewRosterEditorTextField(title: "品种", text: $breed, icon: "tag.fill")
            CrewRosterEditorSegmentedRow(
                title: "性别",
                selection: $gender,
                options: [("male", "男孩"), ("female", "女孩"), ("unknown", "未知")]
            )
            CrewRosterEditorToggleRow(title: "已绝育", icon: "checkmark.seal.fill", isOn: $isNeutered)
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorDateToggleRow(title: "到家日", icon: "house.fill", isOn: $hasHomeDate, date: $homeDate)
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical)
        }
        .onAppear(perform: loadState)
    }

    private var resolvedThemeHex: String {
        themeHex.isEmpty ? pet.safeThemeColorHex : themeHex
    }

    private func loadState() {
        name = pet.name
        species = pet.species.isEmpty ? "其他" : pet.species
        breed = pet.breed
        gender = pet.gender.isEmpty ? "unknown" : pet.gender
        isNeutered = pet.isNeutered
        hasBirthday = pet.birthday != nil
        birthday = pet.birthday ?? Date()
        hasHomeDate = pet.homeDate != nil
        homeDate = pet.homeDate ?? Date()
        themeHex = pet.safeThemeColorHex
        notes = pet.notes
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.name = trimmedName.isEmpty ? pet.name : trimmedName
        pet.species = species
        pet.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        pet.gender = gender
        pet.isNeutered = isNeutered
        pet.birthday = hasBirthday ? birthday : nil
        pet.homeDate = hasHomeDate ? homeDate : nil
        pet.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            themeHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        pet.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.safeSave()
        onSave()
    }
}

private struct CrewRosterHumanProfileEditor: View {
    let human: Human
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var role = "member"
    @State private var gender = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var bloodType = ""
    @State private var mbti = ""
    @State private var nationality = ""
    @State private var city = ""
    @State private var themeHex = ""
    @State private var notes = ""

    private let bloodTypeOptions = ["未填写", "A", "B", "AB", "O"]
    private let mbtiOptions = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

    var body: some View {
        CrewRosterEditorShell(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "编辑成员" : name,
            subtitle: "人类基本信息",
            tint: Color(hex: resolvedThemeHex),
            onCancel: onCancel,
            onSave: saveChanges
        ) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor")
            CrewRosterEditorSegmentedRow(
                title: "权限",
                selection: $role,
                options: [("owner", "管理者"), ("member", "成员")]
            )
            CrewRosterEditorMenuRow(
                title: "性别/身份",
                icon: "person.fill",
                selection: $gender,
                options: HumanProfileOptions.genderOptions.map(\.key)
            )
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorMenuRow(title: "血型", icon: "drop.fill", selection: $bloodType, options: bloodTypeOptions)
            CrewRosterEditorMenuRow(title: "MBTI", icon: "brain.head.profile", selection: $mbti, options: mbtiOptions)
            CrewRosterEditorTextField(title: "国籍", text: $nationality, icon: "globe.asia.australia.fill")
            CrewRosterEditorTextField(title: "现居地", text: $city, icon: "location.fill")
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical)
        }
        .onAppear(perform: loadState)
    }

    private var resolvedThemeHex: String {
        themeHex.isEmpty ? human.safeThemeColorHex : themeHex
    }

    private func loadState() {
        name = human.name
        role = HumanProfileOptions.normalizedRole(human.role)
        gender = HumanProfileOptions.normalizedGender(human.genderRaw)
        hasBirthday = human.birthday != nil
        birthday = human.birthday ?? Date()
        bloodType = human.bloodType.isEmpty ? "未填写" : human.bloodType
        mbti = human.mbti.isEmpty ? "未填写" : human.mbti.uppercased()
        nationality = human.nationality
        city = human.city
        themeHex = human.safeThemeColorHex
        notes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        human.name = trimmedName.isEmpty ? human.name : trimmedName
        human.role = HumanProfileOptions.normalizedRole(role)
        human.birthday = hasBirthday ? birthday : nil
        human.bloodType = bloodType == "未填写" ? "" : bloodType
        human.mbti = mbti == "未填写" ? "" : mbti.uppercased()
        human.nationality = nationality.trimmingCharacters(in: .whitespacesAndNewlines)
        human.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        human.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            themeHex,
            fallback: OhanaThemeColorPolicy.humanFallbackHex
        )

        var noteParts: [String] = []
        let normalizedGender = HumanProfileOptions.normalizedGender(gender)
        if !normalizedGender.isEmpty {
            noteParts.append("性别:\(normalizedGender)")
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            noteParts.append(trimmedNotes)
        }
        human.notes = noteParts.joined(separator: "｜")
        modelContext.safeSave()
        onSave()
    }
}

private struct CrewRosterPlantProfileEditor: View {
    let plant: Plant
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var species = ""
    @State private var location = ""
    @State private var wateringDays = 7
    @State private var fertilizingDays = 30
    @State private var themeHex = ""
    @State private var notes = ""

    var body: some View {
        CrewRosterEditorShell(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "编辑植物" : name,
            subtitle: "植物基本信息",
            tint: Color(hex: resolvedThemeHex),
            onCancel: onCancel,
            onSave: saveChanges
        ) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor")
            CrewRosterEditorTextField(title: "品种", text: $species, icon: "leaf.fill")
            CrewRosterEditorTextField(title: "位置", text: $location, icon: "location.fill")
            CrewRosterEditorStepperRow(title: "浇水间隔", icon: "drop.fill", value: $wateringDays, range: 1...60, unit: "天")
            CrewRosterEditorStepperRow(title: "施肥间隔", icon: "sparkles", value: $fertilizingDays, range: 1...120, unit: "天")
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical)
        }
        .onAppear(perform: loadState)
    }

    private var resolvedThemeHex: String {
        themeHex.isEmpty ? plant.themeColorHex : themeHex
    }

    private func loadState() {
        name = plant.name
        species = plant.species
        location = plant.location
        wateringDays = plant.wateringIntervalDays
        fertilizingDays = plant.fertilizingIntervalDays
        themeHex = plant.themeColorHex
        notes = plant.notes
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.name = trimmedName.isEmpty ? plant.name : trimmedName
        plant.species = species.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.wateringIntervalDays = wateringDays
        plant.fertilizingIntervalDays = fertilizingDays
        plant.themeColorHex = themeHex
        plant.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.safeSave()
        onSave()
    }
}

private struct CrewRosterEditorTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CrewRosterEditorLabel(title: title, icon: icon)
            TextField(title, text: $text, axis: axis)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goCardWhite)
                .textFieldStyle(.plain)
                .lineLimit(axis == .vertical ? 2...4 : 1...1)
                .padding(.horizontal, 12)
                .padding(.vertical, axis == .vertical ? 11 : 10)
                .background(Color.goCardWhite.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CrewRosterEditorMenuRow: View {
    let title: String
    let icon: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: icon)
            Spacer(minLength: 8)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.isEmpty ? "未填写" : option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.goPrimary)
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CrewRosterEditorSegmentedRow: View {
    let title: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: "slider.horizontal.3")
            Picker(title, selection: $selection) {
                ForEach(options, id: \.0) { key, value in
                    Text(value).tag(key)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CrewRosterEditorToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            CrewRosterEditorLabel(title: title, icon: icon)
        }
        .tint(Color.goPrimary)
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CrewRosterEditorDateToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    @Binding var date: Date
    var upperBound: Date? = nil

    var body: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $isOn) {
                CrewRosterEditorLabel(title: title, icon: icon)
            }
            .tint(Color.goPrimary)

            if isOn {
                if let upperBound {
                    DatePicker(title, selection: $date, in: ...upperBound, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                } else {
                    DatePicker(title, selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                }
            }
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(GoMotion.feedback, value: isOn)
    }
}

private struct CrewRosterEditorStepperRow: View {
    let title: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: icon)
            Spacer(minLength: 8)
            Stepper(value: $value, in: range) {
                Text("\(value) \(unit)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .monospacedDigit()
            }
            .labelsHidden()
            Text("\(value) \(unit)")
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goCardWhite)
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CrewRosterThemeSwatchRow: View {
    let title: String
    @Binding var selectedHex: String

    private var themeHexes: [String] {
        PetThemeColor.allCases.map(\.hexValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CrewRosterEditorLabel(title: title, icon: "paintpalette.fill")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(themeHexes, id: \.self) { hex in
                    Button {
                        selectedHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                            if selectedHex.uppercased() == hex.uppercased() {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(WalletPetCardTheme.prefersDarkForeground(for: hex) ? Color.arkInk : Color.goCardWhite)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("主题色")
                }
            }
        }
        .padding(12)
        .background(Color.goCardWhite.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CrewRosterEditorLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 18)
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.goCardWhite.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}
