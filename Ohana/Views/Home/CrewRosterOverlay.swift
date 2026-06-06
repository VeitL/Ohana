//
//  CrewRosterOverlay.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Ohana 图鉴主视图

struct CrewRosterOverlay: View {
    var initialMode: CrewRosterMode = .members
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
    private var resolvedInitialMode: CrewRosterMode {
        showsFamilyCollaboration ? initialMode : .members
    }
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
                selectedRosterMode = resolvedInitialMode
            }
            .onChange(of: showsFamilyCollaboration) { _, canCollaborate in
                if !canCollaborate {
                    selectedRosterMode = .members
                } else if selectedRosterMode == .members && initialMode == .collaboration {
                    selectedRosterMode = .collaboration
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
        VStack(spacing: 0) {
            rosterHeader
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
        EmptyView()
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

            if showsFamilyCollaboration {
                if isCollaboration {
                    rosterCoconutButton
                }
                rosterModeShortcutButton
            }

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
            cardOverlay: { card in
                rosterHomeVisibilityOverlay(for: card)
            },
            memberContent: { card, detailProgress, isDetailMounted in
                rosterProfileSurface(
                    for: card,
                    detailProgress: detailProgress,
                    isDetailMounted: isDetailMounted
                )
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
    private func rosterProfileSurface(
        for card: FocusCard,
        detailProgress: CGFloat,
        isDetailMounted: Bool
    ) -> some View {
        if let pet = filteredPets.first(where: { $0.id == card.id }) {
            CrewRosterProfilePanel(
                card: card,
                pet: pet,
                human: nil,
                plant: nil,
                allPets: pets,
                allHumans: humans,
                detailProgress: detailProgress,
                isDetailMounted: isDetailMounted,
                onClose: closeRosterCardEditor,
                onDeleted: finishRosterProfileDeletion,
                onSaved: { id, kind in postHomeVisibilityChanged(id: id, kind: kind) }
            )
        } else if let human = filteredHumans.first(where: { $0.id == card.id }) {
            CrewRosterProfilePanel(
                card: card,
                pet: nil,
                human: human,
                plant: nil,
                allPets: pets,
                allHumans: humans,
                detailProgress: detailProgress,
                isDetailMounted: isDetailMounted,
                onClose: closeRosterCardEditor,
                onDeleted: finishRosterProfileDeletion,
                onSaved: { id, kind in postHomeVisibilityChanged(id: id, kind: kind) }
            )
        } else if let plant = filteredPlants.first(where: { $0.id == card.id }) {
            CrewRosterProfilePanel(
                card: card,
                pet: nil,
                human: nil,
                plant: plant,
                allPets: pets,
                allHumans: humans,
                detailProgress: detailProgress,
                isDetailMounted: isDetailMounted,
                onClose: closeRosterCardEditor,
                onDeleted: finishRosterProfileDeletion,
                onSaved: { id, kind in postHomeVisibilityChanged(id: id, kind: kind) }
            )
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
            guard editingRosterCardId == card.id else { return }
            isRosterEditorContentMounted = true
            withAnimation(HeroAnim.walletSpring) {
                rosterEditorProgress = 1
            }
        }
    }

    private func closeRosterCardEditor() {
        guard editingRosterCardId != nil else { return }
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

    private func finishRosterProfileDeletion() {
        isRosterEditorContentMounted = false
        editingRosterCardId = nil
        expandedRosterCardId = nil
        rosterEditorProgress = 0
        rosterHeroProgress = 0
        rosterHeroDirection = 1
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
            .contentShape(Rectangle())
            .animation(GoMotion.feedback, value: visualIsOn)
            .frame(width: 66, height: 44)
            .contentShape(Rectangle())
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

private struct CrewRosterProfilePanel: View {
    let card: FocusCard
    let pet: Pet?
    let human: Human?
    let plant: Plant?
    let allPets: [Pet]
    let allHumans: [Human]
    let detailProgress: CGFloat
    let isDetailMounted: Bool
    let onClose: () -> Void
    let onDeleted: () -> Void
    let onSaved: (UUID, String) -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var isEditing = false
    @State private var showingPetPassedAlert = false
    @State private var showingPetUndoPassedAlert = false
    @State private var showingPetClearAlert = false
    @State private var showingPetDeleteSheet = false
    @State private var showingHumanPassedAlert = false
    @State private var showingHumanUndoPassedAlert = false
    @State private var showingHumanDeleteSheet = false
    @State private var showingPlantDeleteAlert = false
    @State private var passedDate = Date()

    @State private var name = ""
    @State private var avatarImageData: Data?
    @State private var avatarEmoji = ""
    @State private var species = ""
    @State private var breed = ""
    @State private var gender = "unknown"
    @State private var role = "member"
    @State private var isNeutered = false
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var hasHomeDate = false
    @State private var homeDate = Date()
    @State private var bloodType = ""
    @State private var heightText = ""
    @State private var mbti = ""
    @State private var nationality = ""
    @State private var city = ""
    @State private var location = ""
    @State private var wateringDays = 7
    @State private var fertilizingDays = 30
    @State private var themeHex = ""
    @State private var notes = ""

    private let speciesOptions = ["狗", "猫", "鱼", "鸟", "兔子", "爬宠", "仓鼠", "其他"]
    private let bloodTypeOptions = ["未填写", "A", "B", "AB", "O"]
    private let mbtiOptions = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

    private var tint: Color { Color(hex: resolvedThemeHex) }
    private var resolvedThemeHex: String {
        if !themeHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return themeHex }
        if let pet { return pet.safeThemeColorHex }
        if let human { return human.safeThemeColorHex }
        if let plant { return plant.themeColorHex }
        return "9EF06A"
    }
    private var l: L10n { L10n(appLanguage) }
    private var detailReveal: CGFloat { min(max(detailProgress, 0), 1) }
    private var controlReveal: CGFloat { WalletHeroTimeline.smooth(detailProgress, 0.12, 0.34) }
    private var summarySnapshot: CrewRosterProfileSummarySnapshot {
        CrewRosterProfileSummarySnapshot.make(card: card, l: l)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.arkInk.opacity(0.58 * Double(detailReveal))
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: CrewRosterProfileContinuityMetrics.summaryDetailGap) {
                CrewRosterProfileSummaryHeader(snapshot: summarySnapshot)

                if isDetailMounted {
                    detailScroll
                }
            }
            .padding(.horizontal, CrewRosterProfileContinuityMetrics.horizontalInset)
            .padding(.top, CrewRosterProfileContinuityMetrics.summaryTopInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            toolbar
                .opacity(Double(controlReveal))
                .allowsHitTesting(detailProgress > 0.985)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: loadEditState)
        .alert("确认标记离世", isPresented: $showingPetPassedAlert) {
            Button("确认", role: .destructive) {
                guard let pet else { return }
                RainbowBridgeService.markPassedAway(pet: pet, date: passedDate, context: modelContext)
                onSaved(pet.id, "pet")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将进入纪念模式，并删除未来未完成的提醒和事件。此操作可撤销。")
        }
        .alert("撤销离世标记", isPresented: $showingPetUndoPassedAlert) {
            Button("撤销", role: .destructive) {
                guard let pet else { return }
                RainbowBridgeService.undoPassedAway(pet: pet, context: modelContext)
                onSaved(pet.id, "pet")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除离世日期，恢复为在世状态。")
        }
        .alert("仅清空所有记录", isPresented: $showingPetClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空记录", role: .destructive) {
                guard let pet else { return }
                pet.clearAllActivityRecords(in: modelContext)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onSaved(pet.id, "pet")
            }
        } message: {
            Text("将删除护理、体重、花费、健康、散步、喂食、清洁、里程碑、用药与相册等记录；保留名字、头像、品种与证件/保险档案。此操作不可撤销。")
        }
        .alert("确认标记纪念模式", isPresented: $showingHumanPassedAlert) {
            Button("确认", role: .destructive) {
                guard let human else { return }
                human.passedAwayDate = passedDate
                modelContext.safeSave()
                onSaved(human.id, "human")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将把该成员设为纪念模式。")
        }
        .alert("撤销纪念模式", isPresented: $showingHumanUndoPassedAlert) {
            Button("撤销", role: .destructive) {
                guard let human else { return }
                human.passedAwayDate = nil
                modelContext.safeSave()
                onSaved(human.id, "human")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将清除该成员的纪念模式日期。")
        }
        .alert("确认删除植物", isPresented: $showingPlantDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                guard let plant else { return }
                modelContext.delete(plant)
                modelContext.safeSave()
                onDeleted()
            }
        } message: {
            Text("确定要删除 \(plant?.name ?? "这株植物") 吗？")
        }
        .sheet(isPresented: $showingPetDeleteSheet) {
            CrewRosterDeleteConfirmationSheet(
                title: "彻底删除 \(pet?.name ?? "宠物")",
                name: pet?.name ?? "",
                warning: "这会删除宠物和所有关联记录，无法撤销。",
                onCancel: { showingPetDeleteSheet = false },
                onDelete: deletePetWithCascade
            )
            .ohanaCompactSheetPresentation(detents: [.height(380), .medium])
        }
        .sheet(isPresented: $showingHumanDeleteSheet) {
            CrewRosterDeleteConfirmationSheet(
                title: "删除成员 \(human?.name ?? "")",
                name: human?.name ?? "",
                warning: "这会删除成员资料、体重与运动记录，无法撤销。",
                onCancel: { showingHumanDeleteSheet = false },
                onDelete: deleteHumanAndReturnHome
            )
            .ohanaCompactSheetPresentation(detents: [.height(360), .medium])
        }
    }

    private var detailScroll: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                isEditing ? AnyView(editContent) : AnyView(readContent)
            }
            .padding(.bottom, 28)
        }
        .opacity(Double(WalletHeroTimeline.smooth(detailProgress, 0.06, 0.28)))
        .mask(alignment: .top) {
            GeometryReader { proxy in
                Color.arkInk
                    .frame(height: proxy.size.height * detailReveal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                if isEditing {
                    saveChanges()
                } else {
                    loadEditState()
                    withAnimation(GoMotion.feedback) { isEditing = true }
                }
            } label: {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 44, height: 44)
                    .background(tint, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(isEditing ? "保存" : "编辑")

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text(isEditing ? "编辑基本信息" : "基本信息")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.goCardWhite.opacity(0.64))
            }
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.goCardWhite)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("关闭")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var readContent: some View {
        VStack(spacing: 12) {
            if let pet {
                petReadContent(pet)
            } else if let human {
                humanReadContent(human)
            } else if let plant {
                plantReadContent(plant)
            }
        }
    }

    private var editContent: some View {
        VStack(spacing: 12) {
            profileEditAvatar
            if pet != nil {
                petEditContent
            } else if human != nil {
                humanEditContent
            } else if plant != nil {
                plantEditContent
            }
        }
    }

    private func petReadContent(_ pet: Pet) -> some View {
        VStack(spacing: 12) {
            profileSection("身份", icon: "pawprint.fill") {
                infoRow("物种", emptyText(pet.species))
                infoRow("品种", emptyText(pet.breed))
                infoRow("年龄", pet.hasPassedAway ? pet.ageAtPassingText : pet.ageText)
                infoRow("性别", pet.genderSymbol + (pet.isNeutered ? " · 已绝育" : ""))
                infoRow("主题色", "#\(pet.safeThemeColorHex.uppercased())")
            }
            profileSection("照护", icon: "heart.fill") {
                infoRow("生日", formattedDate(pet.birthday))
                infoRow("到家日", formattedDate(pet.homeDate))
                infoRow("陪伴", pet.hasPassedAway ? "\(pet.daysTogetherAtPassing) 天" : "\(pet.daysTogether) 天")
                infoRow("主粮", emptyText(pet.foodBrand))
                infoRow("粮仓", pet.restockWeight > 0 ? "\(Int(pet.restockWeight)) g" : "未填写")
            }
            profileSection("保障", icon: "cross.case.fill") {
                infoRow("芯片号", emptyText(pet.microchipID))
                infoRow("医院", emptyText(pet.vetClinicName))
                infoRow("医生", emptyText(pet.vetDoctorName))
                infoRow("电话", emptyText(pet.vetContact))
                infoRow("过敏", emptyText(pet.allergies))
                infoRow("证件", "\(pet.documents.count)")
            }
            if !pet.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileSection("备注", icon: "note.text") { paragraph(pet.notes) }
            }
            petLifecycleSection(pet)
        }
    }

    private func humanReadContent(_ human: Human) -> some View {
        VStack(spacing: 12) {
            profileSection("身份", icon: "person.fill") {
                infoRow("权限", HumanPermissionRole.title(for: human.role))
                infoRow("年龄", human.hasPassedAway ? human.ageAtPassingText : human.ageText)
                infoRow("性别/身份", HumanGenderIdentity.title(for: human.genderRaw))
                infoRow("生日", formattedDate(human.birthday))
                infoRow("星座", human.birthday.map { Human.westernZodiacChinese(for: $0) } ?? "未填写")
            }
            profileSection("身体", icon: "heart.text.square.fill") {
                infoRow("血型", emptyText(human.bloodType))
                infoRow("身高", human.heightCm > 0 ? "\(Int(human.heightCm)) cm" : "未填写")
                infoRow("MBTI", human.mbti.isEmpty ? "未填写" : human.mbti.uppercased())
            }
            profileSection("家庭与显示", icon: "house.fill") {
                infoRow("国籍", emptyText(human.nationality))
                infoRow("现居地", emptyText(human.city))
                infoRow("首页显示", human.shouldShowOnHome ? "显示" : "隐藏")
                infoRow("隐私项目", privacySummary(for: human))
            }
            let humanNotes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            if !humanNotes.isEmpty {
                profileSection("备注", icon: "note.text") { paragraph(humanNotes) }
            }
            humanLifecycleSection(human)
        }
    }

    private func plantReadContent(_ plant: Plant) -> some View {
        VStack(spacing: 12) {
            profileSection("植物", icon: "leaf.fill") {
                infoRow("品种", emptyText(plant.species))
                infoRow("位置", emptyText(plant.location))
                infoRow("浇水间隔", "\(plant.wateringIntervalDays) 天")
                infoRow("施肥间隔", "\(plant.fertilizingIntervalDays) 天")
                infoRow("上次浇水", formattedDate(plant.lastWateredDate))
                infoRow("上次施肥", formattedDate(plant.lastFertilizedDate))
            }
            if !plant.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileSection("备注", icon: "note.text") { paragraph(plant.notes) }
            }
            destructiveButton("删除植物", icon: "trash.fill", color: Color.goRed) {
                showingPlantDeleteAlert = true
            }
        }
    }

    private var profileEditAvatar: some View {
        profileSection("头像", icon: "person.crop.square.fill") {
            HStack(spacing: 14) {
                profileAvatar(size: 72)
                EditableProfileAvatarPicker(
                    avatarImageData: $avatarImageData,
                    fallbackEmoji: avatarEmoji.isEmpty ? fallbackEmoji : avatarEmoji,
                    accentColor: tint,
                    cropSpecies: pet == nil ? "" : species,
                    silhouetteSystemName: human == nil ? nil : "person.fill"
                )
            }
        }
    }

    private var petEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor")
            CrewRosterEditorMenuRow(title: "物种", icon: "pawprint.fill", selection: $species, options: speciesOptions)
            CrewRosterEditorTextField(title: "品种", text: $breed, icon: "tag.fill")
            CrewRosterEditorSegmentedRow(title: "性别", selection: $gender, options: [("male", "男孩"), ("female", "女孩"), ("unknown", "未知")])
            CrewRosterEditorToggleRow(title: "已绝育", icon: "checkmark.seal.fill", isOn: $isNeutered)
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorDateToggleRow(title: "到家日", icon: "house.fill", isOn: $hasHomeDate, date: $homeDate)
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical)
        }
    }

    private var humanEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor")
            CrewRosterEditorTextField(title: "头像 Emoji", text: $avatarEmoji, icon: "face.smiling")
            CrewRosterEditorSegmentedRow(title: "权限", selection: $role, options: [("owner", "管理者"), ("member", "成员")])
            CrewRosterEditorMenuRow(title: "性别/身份", icon: "person.fill", selection: $gender, options: HumanProfileOptions.genderOptions.map(\.key))
            CrewRosterEditorDateToggleRow(title: "生日", icon: "gift.fill", isOn: $hasBirthday, date: $birthday, upperBound: Date())
            CrewRosterEditorMenuRow(title: "血型", icon: "drop.fill", selection: $bloodType, options: bloodTypeOptions)
            CrewRosterEditorTextField(title: "身高 cm", text: $heightText, icon: "ruler.fill")
            CrewRosterEditorMenuRow(title: "MBTI", icon: "brain.head.profile", selection: $mbti, options: mbtiOptions)
            CrewRosterEditorTextField(title: "国籍", text: $nationality, icon: "globe.asia.australia.fill")
            CrewRosterEditorTextField(title: "现居地", text: $city, icon: "location.fill")
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical)
        }
    }

    private var plantEditContent: some View {
        VStack(spacing: 10) {
            CrewRosterEditorTextField(title: "名字", text: $name, icon: "text.cursor")
            CrewRosterEditorTextField(title: "品种", text: $species, icon: "leaf.fill")
            CrewRosterEditorTextField(title: "位置", text: $location, icon: "location.fill")
            CrewRosterEditorStepperRow(title: "浇水间隔", icon: "drop.fill", value: $wateringDays, range: 1...60, unit: "天")
            CrewRosterEditorStepperRow(title: "施肥间隔", icon: "sparkles", value: $fertilizingDays, range: 1...120, unit: "天")
            CrewRosterThemeSwatchRow(title: "主题色", selectedHex: $themeHex)
            CrewRosterEditorTextField(title: "备注", text: $notes, icon: "note.text", axis: .vertical)
        }
    }

    private func petLifecycleSection(_ pet: Pet) -> some View {
        profileSection("生命与危险操作", icon: "exclamationmark.triangle.fill") {
            if pet.hasPassedAway {
                infoRow("离世日期", formattedDate(pet.passedAwayDate))
                secondaryButton("撤销离世标记", icon: "arrow.uturn.backward", color: Color.goYellow) {
                    showingPetUndoPassedAlert = true
                }
            } else {
                DatePicker("离世日期", selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .foregroundStyle(Color.goCardWhite)
                secondaryButton("标记离世", icon: "rainbow", color: Color.goPurple) {
                    showingPetPassedAlert = true
                }
            }
            secondaryButton("仅清空所有记录", icon: "eraser.fill", color: Color.goOrange) {
                showingPetClearAlert = true
            }
            destructiveButton("彻底删除 \(pet.name)", icon: "trash.fill", color: Color.goRed) {
                showingPetDeleteSheet = true
            }
        }
    }

    private func humanLifecycleSection(_ human: Human) -> some View {
        profileSection("生命与危险操作", icon: "exclamationmark.triangle.fill") {
            if human.hasPassedAway {
                infoRow("纪念日期", formattedDate(human.passedAwayDate))
                secondaryButton("撤销纪念模式", icon: "arrow.uturn.backward", color: Color.goYellow) {
                    showingHumanUndoPassedAlert = true
                }
            } else {
                DatePicker("纪念日期", selection: $passedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .foregroundStyle(Color.goCardWhite)
                secondaryButton("标记纪念模式", icon: "sparkles", color: Color.goPurple) {
                    showingHumanPassedAlert = true
                }
            }
            destructiveButton("删除成员", icon: "trash.fill", color: Color.goRed) {
                showingHumanDeleteSheet = true
            }
        }
    }

    private func profileSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goCardWhite.opacity(0.88))
                Spacer(minLength: 0)
            }
            VStack(spacing: 9) { content() }
        }
        .padding(13)
        .background(Color.goCardWhite.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.goCardWhite.opacity(0.54))
                .frame(width: 74, alignment: .leading)
            Text(value)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.goCardWhite.opacity(0.88))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.caption(.bold))
            .foregroundStyle(Color.goCardWhite.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func secondaryButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func destructiveButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        secondaryButton(title, icon: icon, color: color, action: action)
    }

    @ViewBuilder
    private func profileAvatar(size: CGFloat) -> some View {
        if let pet {
            PetAvatarPortraitView(
                imageData: isEditing ? avatarImageData : pet.avatarImageData,
                fallbackText: pet.avatarEmoji.isEmpty ? "🐾" : pet.avatarEmoji,
                themeColor: tint,
                size: size,
                backgroundOpacity: 0.25,
                transparentScale: 0.78
            )
        } else if let human {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: size, height: size)
                if let data = isEditing ? avatarImageData : human.avatarImageData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size - 6, height: size - 6)
                        .clipShape(Circle())
                } else {
                    Text((isEditing ? avatarEmoji : human.avatarEmoji).isEmpty ? "👤" : (isEditing ? avatarEmoji : human.avatarEmoji))
                        .font(.system(size: size * 0.42))
                }
            }
            .frame(width: size, height: size)
        } else if let plant {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .frame(width: size, height: size)
                Text(plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji)
                    .font(.system(size: size * 0.45))
            }
        }
    }

    private var displayName: String {
        if isEditing, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        return pet?.name ?? human?.name ?? plant?.name ?? card.name
    }

    private var fallbackEmoji: String {
        pet?.avatarEmoji ?? human?.avatarEmoji ?? plant?.avatarEmoji ?? "👤"
    }

    private func emptyText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未填写" : value
    }

    private func formattedDate(_ date: Date?) -> String {
        date?.formatted(.dateTime.year().month().day()) ?? "未填写"
    }

    private func privacySummary(for human: Human) -> String {
        let titles = HumanPrivateField.allCases
            .filter { human.privateFields.contains($0.rawValue) }
            .map(\.title)
        return titles.isEmpty ? "全部公开" : titles.joined(separator: "、")
    }

    private func loadEditState() {
        if let pet {
            name = pet.name
            avatarImageData = pet.avatarImageData
            avatarEmoji = pet.avatarEmoji
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
            passedDate = pet.passedAwayDate ?? Date()
        } else if let human {
            name = human.name
            avatarImageData = human.avatarImageData
            avatarEmoji = human.avatarEmoji
            role = HumanProfileOptions.normalizedRole(human.role)
            gender = HumanProfileOptions.normalizedGender(human.genderRaw)
            hasBirthday = human.birthday != nil
            birthday = human.birthday ?? Date()
            bloodType = human.bloodType.isEmpty ? "未填写" : human.bloodType
            heightText = human.heightCm > 0 ? "\(Int(human.heightCm))" : ""
            mbti = human.mbti.isEmpty ? "未填写" : human.mbti.uppercased()
            nationality = human.nationality
            city = human.city
            themeHex = human.safeThemeColorHex
            notes = HumanProfileOptions.visibleNoteParts(from: human.notes).joined(separator: "｜")
            passedDate = human.passedAwayDate ?? Date()
        } else if let plant {
            name = plant.name
            avatarImageData = plant.avatarImageData
            avatarEmoji = plant.avatarEmoji
            species = plant.species
            location = plant.location
            wateringDays = plant.wateringIntervalDays
            fertilizingDays = plant.fertilizingIntervalDays
            themeHex = plant.themeColorHex
            notes = plant.notes
        }
    }

    private func saveChanges() {
        if let pet {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            pet.name = trimmedName.isEmpty ? pet.name : trimmedName
            pet.avatarImageData = avatarImageData
            pet.species = species
            pet.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
            pet.gender = gender
            pet.isNeutered = isNeutered
            pet.birthday = hasBirthday ? birthday : nil
            pet.homeDate = hasHomeDate ? homeDate : nil
            pet.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(themeHex, fallback: OhanaThemeColorPolicy.petFallbackHex)
            pet.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            CarePlanCalendarSync.ensureDefaultPlans(for: pet, context: modelContext)
            modelContext.safeSave()
            seedAvatarCache(id: pet.id, data: avatarImageData)
            onSaved(pet.id, "pet")
        } else if let human {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            human.name = trimmedName.isEmpty ? human.name : trimmedName
            human.avatarImageData = avatarImageData
            human.avatarEmoji = avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "👤" : avatarEmoji
            human.role = HumanProfileOptions.normalizedRole(role)
            human.birthday = hasBirthday ? birthday : nil
            human.bloodType = bloodType == "未填写" ? "" : bloodType
            human.heightCm = Double(heightText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            human.mbti = mbti == "未填写" ? "" : mbti.uppercased()
            human.nationality = nationality.trimmingCharacters(in: .whitespacesAndNewlines)
            human.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
            human.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(themeHex, fallback: OhanaThemeColorPolicy.humanFallbackHex)
            var noteParts: [String] = []
            let normalizedGender = HumanProfileOptions.normalizedGender(gender)
            if !normalizedGender.isEmpty { noteParts.append("性别:\(normalizedGender)") }
            noteParts.append(contentsOf: human.notes.split(separator: "｜").map(String.init).filter { $0.hasPrefix("关系:") })
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty { noteParts.append(trimmedNotes) }
            human.notes = noteParts.joined(separator: "｜")
            modelContext.safeSave()
            seedAvatarCache(id: human.id, data: avatarImageData)
            onSaved(human.id, "human")
        } else if let plant {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            plant.name = trimmedName.isEmpty ? plant.name : trimmedName
            plant.avatarImageData = avatarImageData
            plant.avatarEmoji = avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "🌱" : avatarEmoji
            plant.species = species.trimmingCharacters(in: .whitespacesAndNewlines)
            plant.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
            plant.wateringIntervalDays = wateringDays
            plant.fertilizingIntervalDays = fertilizingDays
            plant.themeColorHex = themeHex
            plant.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            modelContext.safeSave()
            onSaved(plant.id, "plant")
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(GoMotion.feedback) { isEditing = false }
    }

    private func seedAvatarCache(id: UUID, data: Data?) {
        guard let data, let image = UIImage(data: data) else { return }
        FocusWalletAvatarCache.storeDecodedImage(
            cardId: id,
            data: data,
            image: image,
            isTransparent: ImageCutoutService.imageHasTransparentPixels(image)
        )
    }

    private func deletePetWithCascade() {
        guard let pet else { return }
        let petIdStr = pet.id.uuidString
        if let allEvents = try? modelContext.fetch(FetchDescriptor<Event>()) {
            for event in allEvents where event.relatedEntityId == petIdStr {
                modelContext.delete(event)
            }
        }
        removeQuickAccessItems(for: pet.id)
        modelContext.delete(pet)
        modelContext.safeSave()
        showingPetDeleteSheet = false
        onDeleted()
    }

    private func removeQuickAccessItems(for petId: UUID) {
        let key = "quickActionItems_v2"
        guard let json = UserDefaults.standard.string(forKey: key),
              let data = json.data(using: .utf8),
              var items = try? JSONDecoder().decode([QuickActionItem].self, from: data)
        else { return }
        items.removeAll { $0.petId == petId }
        if let newData = try? JSONEncoder().encode(items),
           let newJSON = String(data: newData, encoding: .utf8) {
            UserDefaults.standard.set(newJSON, forKey: key)
        }
    }

    private func deleteHumanAndReturnHome() {
        guard let human else { return }
        let deletedHumanId = human.id.uuidString
        let hasRemainingHuman = allHumans.contains { $0.id.uuidString != deletedHumanId }
        let deletedCurrentHuman = activeHumanIdStr == deletedHumanId
        let requiresReplacementHuman = !hasRemainingHuman
        let requiresAccountSwitch = deletedCurrentHuman && hasRemainingHuman
        if deletedCurrentHuman || requiresReplacementHuman {
            activeHumanIdStr = ""
        }
        modelContext.delete(human)
        modelContext.safeSave()
        NotificationCenter.default.post(
            name: .ohanaReturnHomeAfterHumanDeletion,
            object: nil,
            userInfo: [
                "requiresReplacementHuman": requiresReplacementHuman,
                "requiresAccountSwitch": requiresAccountSwitch
            ]
        )
        showingHumanDeleteSheet = false
        onDeleted()
    }
}

private struct CrewRosterDeleteConfirmationSheet: View {
    let title: String
    let name: String
    let warning: String
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var confirmName = ""

    private var canDelete: Bool {
        ConfirmationNameMatcher.matches(confirmName, expectedName: name)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.goRed)
                        .frame(width: 36, height: 36)
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(OhanaFont.title3(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("输入名字后才能继续")
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(width: 34, height: 34)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Text(warning)
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))

                TextField(name, text: $confirmName)
                    .font(OhanaFont.callout(.bold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: onDelete) {
                        Text("删除")
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(canDelete ? Color.ohanaPrimaryActionText : Color.primary.opacity(0.32))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canDelete ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                }
            }
            .padding(20)
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
