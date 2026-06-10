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
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var pendingReminders: [Reminder] = []
    var familyTasks: [FamilyCollaborationTask] = []
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onAddEntity: ((EntityType) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var addMemberTrigger: Bool = false
    var safeTopInset: CGFloat = 0
    var safeBottomInset: CGFloat = 0
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

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
    private var filteredPlants: [Plant] { [] }
    private var isEmpty: Bool { pets.isEmpty && humans.isEmpty && filteredPlants.isEmpty }
    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var showsFamilyCollaboration: Bool { humans.count > 1 && !activePets.isEmpty }
    private var resolvedInitialMode: CrewRosterMode {
        showsFamilyCollaboration ? initialMode : .members
    }
    private var activeHumanCoconutBalance: Int {
        activeHuman?.coconutBalance ?? 0
    }
    private var activeHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanIdStr }
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
                            familyTasks: familyTasks,
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
                onHumanSaved: { pendingInlineSavedHuman = $0 },
                onPresentCoconutLog: { subject in
                    onPresentCoconutLog?(subject)
                }
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
            if let onPresentCoconutLog {
                onPresentCoconutLog(activeHuman.map { CoconutLogSubject.human($0.id) })
            } else {
                activeFullScreenRoute = .coconutLog
            }
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
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
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
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
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
        guard AppFeatureRouteGuard.allowsAddEntity(type) else {
            AppFeatureRouteGuard.recordIntercept("crewAddEntity:\(type.rawValue)")
            return
        }
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
                    .font(OhanaFont.adaptive(size: 20, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
        [.pet, .human, .plant].filter { type in
            AppFeatureRouteGuard.allowsAddEntity(type)
        }
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
                    .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
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
        let petCards = filteredPets.map { pet in
            var card = FocusCard.from(pet, includeAvatarData: true)
            card.isShownOnHome = effectivePetHomeVisibility(pet)
            return card
        }
        let humanCards = filteredHumans.map { human in
            var card = FocusCard.from(human, includeAvatarData: true)
            card.isShownOnHome = effectiveHumanHomeVisibility(human)
            return card
        }
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
            MemberCommandExecutor(context: modelContext, services: appServices).publishPetHomeVisibility(
                petID: pet.id,
                visible: visible,
                note: "crew.member.homeVisibility.pet"
            )
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
            let result = MemberCommandExecutor(context: modelContext, services: appServices).setHumanHomeVisibility(
                human,
                visible: visible,
                note: "crew.member.homeVisibility.human"
            )
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                homeVisibilityOverrides[human.id] = nil
            }
            postHomeVisibilityChanged(id: result.entityID, kind: result.kind)
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
        appServices.domainRevisions.publishMemberProfileChange(
            entityID: id,
            kind: kind,
            note: "crewRoster.homeVisibility"
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
            Image(systemName: "person.2.slash") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 34, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 72, height: 72)
                .background(Color.goPrimary.opacity(0.14), in: Circle())
            Text(l.tr(zh: "还没有成员", en: "No members yet", de: "Noch keine Mitglieder"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "添加宠物或人类成员开始照顾。", en: "Add a pet or human member to begin.", de: "Füge ein Tier oder einen Menschen hinzu."))
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 32)
    }

}
