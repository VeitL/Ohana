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
    private enum RosterMode: String {
        case collaboration
        case members
    }

    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onAddEntity: ((EntityType) -> Void)? = nil
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var addMemberTrigger: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @Query(filter: #Predicate<Reminder> { $0.status == "pending" },
           sort: \Reminder.scheduledAt) private var pendingReminders: [Reminder]

    @State private var activeAddEntityType: EntityType? = nil
    @State private var memberAddMenuExpanded = false
    @State private var memberAddMenuItemsVisible = false
    @State private var showingCoconutLog = false
    @State private var familyActivityPet: Pet? = nil
    @State private var showingFamilyWeeklyReport = false
    @State private var selectedRosterMode: RosterMode = .members
    @State private var collaborationCreateTaskTrigger = 0
    @State private var collaborationEditorPresented = false
    @State private var pendingInlineSavedPet: Pet? = nil
    @State private var pendingInlineSavedHuman: Human? = nil
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
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
                        FamilyCollaborationDashboardView(
                            pets: activePets,
                            humans: humans,
                            pendingReminders: pendingReminders,
                            createTaskTrigger: collaborationCreateTaskTrigger,
                            onEditorVisibilityChanged: { isPresented in
                                withAnimation(GoMotion.feedback) {
                                    collaborationEditorPresented = isPresented
                                }
                            },
                            onOpenPetActivity: { familyActivityPet = $0 },
                            onOpenWeeklyReport: { showingFamilyWeeklyReport = true }
                        )
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                bentoDex
                                Spacer(minLength: 60)
                            }
                            .padding(.top, 4)
                            .animation(GoMotion.page, value: selectedRosterMode)
                        }
                    }
                }

                if memberAddMenuExpanded && selectedRosterMode == .members {
                    Color.black.opacity(0.001) // ui-v4: allow transparent tap shield for expanded FAB menu
                        .ignoresSafeArea()
                        .onTapGesture {
                            closeMemberAddMenu()
                        }
                        .transition(.opacity)
                }

                if shouldShowRosterFab {
                    rosterFloatingActionOverlay
                        .padding(.trailing, 22)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.scale(scale: 0.86, anchor: .center).combined(with: .opacity))
                }

            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingCoconutLog) { CoconutLogView() }
            .fullScreenCover(item: $activeAddEntityType, onDismiss: {
                pendingInlineSavedPet = nil
                pendingInlineSavedHuman = nil
            }) { type in
                addEntityCover(type)
            }
            .sheet(item: $familyActivityPet) { pet in
                NavigationStack {
                    ScrollView {
                        FamilyActivityStripView(pet: pet, style: .full)
                            .padding(.vertical, 20)
                    }
                    .navigationTitle(
                        l.tr(
                            zh: "谁在照顾 \(pet.name)",
                            en: "Who's caring for \(pet.name)",
                            de: "Wer kümmert sich um \(pet.name)?"
                        )
                    )
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                                familyActivityPet = nil
                            }
                            .foregroundStyle(Color.goPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFamilyWeeklyReport) {
                NavigationStack {
                    FamilyWeeklyReportDashboardView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                                    showingFamilyWeeklyReport = false
                                }
                                .foregroundStyle(Color.goPrimary)
                            }
                        }
                }
            }
            .onChange(of: addMemberTrigger) { _, _ in
                memberAddMenuItemsVisible = false
                memberAddMenuExpanded = false
                selectedRosterMode = .members
                openMemberAddMenu()
            }
            .onAppear {
                if showsFamilyCollaboration {
                    selectedRosterMode = .collaboration
                }
            }
            .onChange(of: showsFamilyCollaboration) { _, canCollaborate in
                selectedRosterMode = canCollaborate ? .collaboration : .members
                collaborationEditorPresented = false
                memberAddMenuItemsVisible = false
                memberAddMenuExpanded = false
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
        .padding(.top, 16)
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
        Button {
            showingCoconutLog = true
        } label: {
            HStack(spacing: 7) {
                Text("🥥")
                    .font(.system(size: 12, weight: .black))
                Text("\(activeHumanCoconutBalance)")
                    .font(OhanaFont.caption(.black))
                    .monospacedDigit()
                    .lineLimit(1)
                    .ohanaNumericMotion(activeHumanCoconutBalance)
            }
            .foregroundStyle(Color.ohanaPrimaryActionText)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(Color.goPrimary, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .ohanaPhasePop(trigger: activeHumanCoconutBalance)
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
                Button { dismiss() } label: {
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

    private var shouldShowRosterFab: Bool {
        guard activeAddEntityType == nil else { return false }
        if showsFamilyCollaboration && selectedRosterMode == .collaboration {
            return !collaborationEditorPresented
        }
        return selectedRosterMode == .members || isEmpty
    }

    @ViewBuilder
    private func addEntityCover(_ type: EntityType) -> some View {
        ZStack(alignment: .topTrailing) {
            AddEntityDestinationView(
                type: type,
                onComplete: { completeInlineAddEntity() },
                onPetSaved: { pet in
                    pendingInlineSavedPet = pet
                },
                onHumanSaved: { human in
                    pendingInlineSavedHuman = human
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            Button {
                dismissInlineAddEntity()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 42, height: 42)
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 18)
            .padding(.trailing, 18)
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
        .background(OhanaAppBackground())
    }

    private func presentInlineAddEntity(_ type: EntityType) {
        memberAddMenuItemsVisible = false
        withAnimation(GoMotion.fab) {
            memberAddMenuExpanded = false
        }
        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            guard activeAddEntityType == nil else { return }
            activeAddEntityType = type
        }
    }

    private func dismissInlineAddEntity() {
        pendingInlineSavedPet = nil
        pendingInlineSavedHuman = nil
        withAnimation(GoMotion.sheet) {
            activeAddEntityType = nil
        }
    }

    private func completeInlineAddEntity() {
        let savedPet = pendingInlineSavedPet
        let savedHuman = pendingInlineSavedHuman
        pendingInlineSavedPet = nil
        pendingInlineSavedHuman = nil

        withAnimation(GoMotion.sheet) {
            activeAddEntityType = nil
        }

        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            if let savedPet {
                onSelectPet(savedPet)
            } else if let savedHuman {
                onSelectHuman(savedHuman)
            }
        }
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
    private var bentoDex: some View {
        VStack(spacing: 16) {
            // ── 宠物区（正方形卡片 2列 Bento）
            if !filteredPets.isEmpty {
                dexSectionLabel(l.tr(zh: "宠物", en: "Pets", de: "Tiere"), count: filteredPets.count, symbol: "pawprint.fill")
                BentoPetGrid(pets: filteredPets, onSelect: { pet in
                    onSelectPet(pet)
                })
                .padding(.horizontal, 16)
            }

            // ── 人类区（正方形卡片 2列 Bento）
            if !filteredHumans.isEmpty {
                dexSectionLabel(l.tr(zh: "人类", en: "Humans", de: "Menschen"), count: filteredHumans.count, symbol: "person.2.fill")
                BentoHumanGrid(humans: filteredHumans, onSelect: { human in
                    onSelectHuman(human)
                })
                .padding(.horizontal, 16)
            }

            // ── 植物区（竖向卡片横排）
            if !filteredPlants.isEmpty {
                dexSectionLabel(l.tr(zh: "植物", en: "Plants", de: "Pflanzen"), count: filteredPlants.count, symbol: "leaf.fill")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(filteredPlants.enumerated()), id: \.element.id) { index, plant in
                            PlantTallCard(plant: plant)
                                .ohanaSmoothAppear(index: index)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Section 标签
    private func dexSectionLabel(_ title: String, count: Int, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .black))
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
        }
        .padding(.horizontal, 20)
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

// MARK: - 宠物两列网格

private struct BentoPetGrid: View {
    let pets: [Pet]
    let onSelect: (Pet) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                PetSquareCard(pet: pet) {
                    onSelect(pet)
                }
                .ohanaSmoothAppear(index: index)
            }
        }
    }
}

// MARK: - 宠物小卡片（两列网格用，单击进详情）

private struct PetSquareCard: View {
    let pet: Pet
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @State private var isDeletePressing = false
    @State private var deletePressCandidate = false
    @State private var deletePressToken = UUID()
    @State private var suppressTapUntil = Date.distantPast
    @State private var showDeleteAlert = false
    @State private var showHomeStackFullAlert = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""

    private var themeColor: Color { Color(hex: pet.safeThemeColorHex) }
    private var isShownOnHome: Bool { HomeCardVisibility.isPetVisible(pet, raw: hiddenHomePetIDsRaw) }

    private var posterHeadline: String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return String(trimmed.prefix(6)).uppercased()
    }

    private var deletePressAnimation: Animation? {
        if isDeletePressing {
            return workloadPolicy.shouldAnimate()
            ? .easeInOut(duration: 0.09).repeatForever(autoreverses: true)
            : .spring(response: 0.22, dampingFraction: 0.82)
        }
        return .spring(response: 0.22, dampingFraction: 0.82)
    }

    var body: some View {
        VStack(spacing: 8) {
            cardFace
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                guard Date() >= suppressTapUntil else { return }
                onTap()
            }
            .scaleEffect(isDeletePressing ? 0.97 : 1.0)
            .rotationEffect(.degrees(isDeletePressing ? -1.35 : 0))
            .animation(deletePressAnimation, value: isDeletePressing)
            .overlay(alignment: .topTrailing) {
                if isDeletePressing {
                    deletePreviewBadge
                        .padding(7)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
            }
            .onLongPressGesture(
                minimumDuration: 0.7,
                maximumDistance: 12,
                pressing: updateDeletePressFeedback,
                perform: triggerDeleteAlert
            )
            homeVisibilityToggle
        }
        .alert("删除 \(pet.name)？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                let petIdStr = pet.id.uuidString
                if let allEvents = try? modelContext.fetch(FetchDescriptor<Event>()) {
                    for event in allEvents where event.relatedEntityId == petIdStr {
                        modelContext.delete(event)
                    }
                }
                modelContext.delete(pet)
                modelContext.safeSave()
            }
        } message: {
            Text("确定要删除 \(pet.name) 吗？此操作不可撤销。")
        }
    }
    private var cardFace: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let (cardTop, cardBottom) = WalletPetCardTheme.gradientPair(for: pet.themeColorHex)
            let avatarImage: UIImage? = pet.avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent: Bool = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            let isPopout = isTransparent && avatarImage != nil

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [cardTop, cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text(posterHeadline)
                    .font(.system(size: w * 0.28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "FF5A3D").opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(y: -h * 0.22)
                    .allowsHitTesting(false)

                miniSubjectLayer(avatarImage: avatarImage, isPopout: isPopout, w: w, h: h)
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.50)
                    miniInfoColumn(w: w, h: h)
                }
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: themeColor.opacity(0.32), radius: 12, x: 0, y: 4) // ui-v4: allow member card lifted preview
    }

    private var readableTextColor: Color {
        let bright = ["C8FF00","E8FFB0","B8FFD0","FFF44F","FFEB3B","FFFFFF","FFEAA7","FDCB6E"]
        return bright.contains(pet.themeColorHex.uppercased()) ? Color.arkInk : Color.goCardWhite
    }

    private func compactBadge(_ text: String, textColor: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(textColor.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(textColor.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(textColor.opacity(0.12), lineWidth: 0.5))
    }

    private var homeVisibilityBinding: Binding<Bool> {
        Binding(
            get: { isShownOnHome },
            set: { newValue in
                OhanaFeedback.light()
                if newValue,
                   !HomeCardVisibility.canShowPet(pet, pets: allPets, humans: allHumans, raw: hiddenHomePetIDsRaw) {
                    showHomeStackFullAlert = true
                    return
                }
                hiddenHomePetIDsRaw = HomeCardVisibility.rawBySettingPet(pet, visible: newValue, raw: hiddenHomePetIDsRaw)
            }
        )
    }

    private var homeVisibilityToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: isShownOnHome ? "house.fill" : "house.slash.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(isShownOnHome ? Color.goPrimary : Color.ohanaTertiaryText)
                .frame(width: 16)
            Text(isShownOnHome ? "首页显示" : "已隐藏")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(isShownOnHome ? 0.86 : 0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Toggle("", isOn: homeVisibilityBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.goPrimary)
                .scaleEffect(0.62)
                .frame(width: 34, height: 22)
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .background(Color.ohanaControlFill, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("首页显示")
        .accessibilityValue(isShownOnHome ? "开启" : "关闭")
        .alert("首页卡片堆已满", isPresented: $showHomeStackFullAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("首页最多显示 \(HomeCardVisibility.maxVisibleCards) 张卡片。请先隐藏一张成员卡片，再显示 \(pet.name)。")
        }
    }

    private var deletePreviewBadge: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(Color.goCardWhite)
            .frame(width: 28, height: 28)
            .background(Color.goRed, in: Circle())
            .shadow(color: Color.goRed.opacity(0.45), radius: 8, y: 3) // ui-v4: allow delete press warning badge lift
    }

    private func updateDeletePressFeedback(_ pressing: Bool) {
        if pressing {
            let token = UUID()
            deletePressToken = token
            deletePressCandidate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                guard deletePressCandidate, deletePressToken == token else { return }
                suppressTapUntil = Date().addingTimeInterval(1.1)
                withAnimation(deletePressAnimation) {
                    isDeletePressing = true
                }
                OhanaFeedback.light()
            }
        } else {
            deletePressCandidate = false
            deletePressToken = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                guard !showDeleteAlert else { return }
                withAnimation(GoMotion.feedback) {
                    isDeletePressing = false
                }
            }
        }
    }

    private func triggerDeleteAlert() {
        suppressTapUntil = Date().addingTimeInterval(1.1)
        deletePressCandidate = false
        deletePressToken = UUID()
        withAnimation(GoMotion.feedback) {
            isDeletePressing = false
        }
        OhanaFeedback.strong()
        showDeleteAlert = true
    }

    @ViewBuilder
    private func miniSubjectLayer(avatarImage: UIImage?, isPopout: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let avatarImage {
            if isPopout {
                // 透明 2.5D 主体只渲染一层，避免成员页小卡出现重影。
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(0.92)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .shadow(color: Color.arkInk.opacity(0.22), radius: 10, x: 0, y: 6) // ui-v4: allow avatar grounding
            } else {
                // 普通照片：填满左半区域，右侧羽化
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.65),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.08),
                                .clear,
                                themeColor.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    }
            }
        } else {
            // 无头像：剪影
            let silhouetteSpecies: String = {
                let value = pet.species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if value == "dog" || pet.species == "狗" { return "狗" }
                if value == "cat" || pet.species == "猫" { return "猫" }
                return pet.species
            }()
            ZStack {
                Ellipse()
                    .fill(Color.arkInk.opacity(0.16))
                    .frame(width: w * 0.28, height: 12)
                    .blur(radius: 6)
                    .offset(y: h * 0.14)
                PetSilhouetteView(
                    species: silhouetteSpecies,
                    coatColor: pet.coatColor.isEmpty ? Color(hex: "E8C49A") : Color(hex: pet.coatColor),
                    eyeColor: pet.eyeColor.isEmpty ? Color(hex: "6B3A2A") : Color(hex: pet.eyeColor)
                )
                .scaleEffect(0.42)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // ── 方案1：透明抠图 破框悬浮
    private func petCutoutCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor.opacity(0.85),
                                 themeColor.mix(with: Color(hex: "000000"), by: 0.45).opacity(0.95)],
                        startPoint: .topTrailing, endPoint: .bottomLeading))
                // 右侧名字
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.48)
                    miniInfoColumn(w: w, h: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            // 破框层
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(RadialGradient(colors: [themeColor.opacity(0.55), .clear],
                                            center: .center, startRadius: 0, endRadius: 50))
                        .frame(width: 100, height: 28).blur(radius: 8).offset(y: 6)
                    ZStack {
                        Image(uiImage: img).resizable().scaledToFit()
                            .scaleEffect(1.06).colorMultiply(.white)
                            .shadow(color: Color.goCardWhite, radius: 0, x: 2, y: 0) // ui-v4: allow cutout rim for 2.5D readability
                            .shadow(color: Color.goCardWhite, radius: 0, x: -2, y: 0) // ui-v4: allow cutout rim for 2.5D readability
                            .shadow(color: Color.goCardWhite, radius: 0, x: 0, y: -2) // ui-v4: allow cutout rim for 2.5D readability
                        Image(uiImage: img).resizable().scaledToFit()
                    }
                    .frame(width: w * 0.50, height: h * 1.12)
                    .offset(y: -12)
                }
                .frame(width: w * 0.50, alignment: .bottom)
                .allowsHitTesting(false)
            }
        }
    }

    // ── 方案2：普通照片 高斯模糊背景
    private func petBlurCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: w, height: h).blur(radius: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.arkInk.opacity(0.25), Color.arkInk.opacity(0.52)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.ohanaCardSurface.opacity(0.30))
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: w * 0.60, height: h).clipped()
                    .mask(LinearGradient(
                        stops: [.init(color: Color.arkInk, location: 0),
                                .init(color: Color.arkInk, location: 0.45),
                                .init(color: .clear, location: 1.0)],
                        startPoint: .leading, endPoint: .trailing))
                    .allowsHitTesting(false)
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.44)
                    miniInfoColumn(w: w, h: h, textColor: .white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // ── 方案3：纯色渐变 + Emoji
    private func petEmojiCard(geo: GeometryProxy, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor, themeColor.mix(with: .black, by: 0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                    .font(.system(size: 56)).minimumScaleFactor(0.5)
                    .frame(width: w * 0.50, height: h * 0.90, alignment: .center)
                    .allowsHitTesting(false)
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.50)
                    miniInfoColumn(w: w, h: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // ── 右侧信息列（姓名 + 陪伴天数）
    private func miniInfoColumn(w: CGFloat, h: CGFloat, textColor: Color? = nil) -> some View {
        let tc: Color = textColor ?? readableTextColor
        return VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)
            if pet.daysTogether > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(pet.daysTogether)")
                        .font(OhanaFont.metric(size: 20))
                        .foregroundStyle(tc)
                    Text("天")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(tc.opacity(0.6))
                }
                .padding(.bottom, 3)
            } else {
                Text("新成员")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(tc.opacity(0.68))
                    .padding(.bottom, 3)
            }

            HStack(spacing: 4) {
                compactBadge(pet.species.isEmpty ? "宠物" : pet.species, textColor: tc)
                compactBadge(pet.ageText.isEmpty ? "年龄未知" : pet.ageText, textColor: tc)
            }
            .padding(.bottom, 10)
        }
        .padding(.trailing, 10)
        .frame(width: w * 0.50, alignment: .trailing)
    }

    @ViewBuilder
    private var petStatusBadge: some View {
        let statusInfo = petStatus(for: pet)
        if let (emoji, label, color) = statusInfo {
            HStack(spacing: 4) {
                Text(emoji).font(.system(size: 11))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
        }
    }

    private func petStatus(for pet: Pet) -> (String, String, Color)? {
        // 正在遛狗
        let mgr = PetWalkingManager.shared
        if case .running = mgr.phase, mgr.currentPet?.id == pet.id {
            return ("🐕", "遛狗中", Color.goPrimary)
        }
        if case .paused = mgr.phase, mgr.currentPet?.id == pet.id {
            return ("⏸️", "暂停中", Color.goYellow)
        }
        // 余粮告急
        if pet.dailyPortionGrams > 0 && pet.remainingFoodDays <= 3 && pet.remainingFoodDays >= 0 {
            return ("🍖", "粮食告急", Color.goOrange)
        }
        // 今日已遛狗
        let todayWalked = pet.walkLogs.contains { Calendar.current.isDateInToday($0.startDate) }
        if todayWalked { return ("✨", "今日已溜", Color.goTeal) }
        return nil
    }
}

// MARK: - 人类两列网格

private struct BentoHumanGrid: View {
    let humans: [Human]
    let onSelect: (Human) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(humans.enumerated()), id: \.element.id) { index, human in
                HumanSquareCard(human: human) {
                    onSelect(human)
                }
                .ohanaSmoothAppear(index: index)
            }
        }
    }
}

// MARK: - 人类小卡片（两列网格用，单击进详情）

private struct HumanSquareCard: View {
    let human: Human
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @State private var isDeletePressing = false
    @State private var deletePressCandidate = false
    @State private var deletePressToken = UUID()
    @State private var suppressTapUntil = Date.distantPast
    @State private var showDeleteAlert = false
    @State private var showHomeStackFullAlert = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""

    private var themeColor: Color { Color(hex: human.themeColor) }
    private var companionshipDays: Int {
        max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
    }

    private var deletePressAnimation: Animation? {
        if isDeletePressing {
            return workloadPolicy.shouldAnimate()
            ? .easeInOut(duration: 0.09).repeatForever(autoreverses: true)
            : .spring(response: 0.22, dampingFraction: 0.82)
        }
        return .spring(response: 0.22, dampingFraction: 0.82)
    }

    var body: some View {
        VStack(spacing: 8) {
            cardFace
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                guard Date() >= suppressTapUntil else { return }
                onTap()
            }
            .scaleEffect(isDeletePressing ? 0.97 : 1.0)
            .rotationEffect(.degrees(isDeletePressing ? -1.35 : 0))
            .animation(deletePressAnimation, value: isDeletePressing)
            .overlay(alignment: .topTrailing) {
                if isDeletePressing {
                    deletePreviewBadge
                        .padding(7)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
            }
            .onLongPressGesture(
                minimumDuration: 0.7,
                maximumDistance: 12,
                pressing: updateDeletePressFeedback,
                perform: triggerDeleteAlert
            )
            homeVisibilityToggle
        }
        .alert("删除 \(human.name)？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                modelContext.delete(human)
                modelContext.safeSave()
            }
        } message: {
            Text("确定要删除 \(human.name) 吗？此操作不可撤销。")
        }
    }

    private var cardFace: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarImage: UIImage? = human.avatarImageData.flatMap { UIImage(data: $0) }
            let hasAvatarImage = avatarImage != nil
            let isTransparent: Bool = human.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        MeshGradient(
                            width: 3, height: 3,
                            points: [
                                SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                                SIMD2(0.0, 0.5), SIMD2(0.52, 0.38), SIMD2(1.0, 0.5),
                                SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                            ],
                            colors: WalletPetCardTheme.meshColors(for: human.themeColor)
                        )
                    )
                LinearGradient(
                    colors: [.clear, .black.opacity(hasAvatarImage ? 0.16 : 0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text(human.name.uppercased())
                    .font(.system(size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: human.name.count), weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "FF5A3D").opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(0.78)
                    .allowsHitTesting(false)

                humanSubjectLayer(avatarImage: avatarImage, isTransparent: isTransparent, w: w, h: h)
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.50)
                    miniInfoColumn(w: w, h: h)
                }
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.goCardWhite.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: themeColor.opacity(0.28), radius: 12, x: 0, y: 4) // ui-v4: allow member card lifted preview
    }

    private var readableTextColor: Color {
        let bright = ["C8FF00","E8FFB0","B8FFD0","FFF44F","FFEB3B","FFFFFF","FFEAA7","FDCB6E"]
        return bright.contains(human.themeColor.uppercased()) ? Color.arkInk : Color.goCardWhite
    }

    private func compactBadge(_ text: String, textColor: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(textColor.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(textColor.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(textColor.opacity(0.12), lineWidth: 0.5))
    }

    private var homeVisibilityBinding: Binding<Bool> {
        Binding(
            get: { human.shouldShowOnHome },
            set: { newValue in
                OhanaFeedback.light()
                if newValue,
                   !HomeCardVisibility.canShowHuman(human, pets: allPets, humans: allHumans, raw: hiddenHomePetIDsRaw) {
                    showHomeStackFullAlert = true
                    return
                }
                human.shouldShowOnHome = newValue
                modelContext.safeSave()
            }
        )
    }

    private var homeVisibilityToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: human.shouldShowOnHome ? "house.fill" : "house.slash.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(human.shouldShowOnHome ? Color.goPrimary : Color.ohanaTertiaryText)
                .frame(width: 16)
            Text(human.shouldShowOnHome ? "首页显示" : "已隐藏")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(human.shouldShowOnHome ? 0.86 : 0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Toggle("", isOn: homeVisibilityBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.goPrimary)
                .scaleEffect(0.62)
                .frame(width: 34, height: 22)
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .background(Color.ohanaControlFill, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("首页显示")
        .accessibilityValue(human.shouldShowOnHome ? "开启" : "关闭")
        .alert("首页卡片堆已满", isPresented: $showHomeStackFullAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("首页最多显示 \(HomeCardVisibility.maxVisibleCards) 张卡片。请先隐藏一张成员卡片，再显示 \(human.name)。")
        }
    }

    private var deletePreviewBadge: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(Color.goCardWhite)
            .frame(width: 28, height: 28)
            .background(Color.goRed, in: Circle())
            .shadow(color: Color.goRed.opacity(0.45), radius: 8, y: 3) // ui-v4: allow delete press warning badge lift
    }

    private func updateDeletePressFeedback(_ pressing: Bool) {
        if pressing {
            let token = UUID()
            deletePressToken = token
            deletePressCandidate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                guard deletePressCandidate, deletePressToken == token else { return }
                suppressTapUntil = Date().addingTimeInterval(1.1)
                withAnimation(deletePressAnimation) {
                    isDeletePressing = true
                }
                OhanaFeedback.light()
            }
        } else {
            deletePressCandidate = false
            deletePressToken = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                guard !showDeleteAlert else { return }
                withAnimation(GoMotion.feedback) {
                    isDeletePressing = false
                }
            }
        }
    }

    private func triggerDeleteAlert() {
        suppressTapUntil = Date().addingTimeInterval(1.1)
        deletePressCandidate = false
        deletePressToken = UUID()
        withAnimation(GoMotion.feedback) {
            isDeletePressing = false
        }
        OhanaFeedback.strong()
        showDeleteAlert = true
    }

    @ViewBuilder
    private var humanAvatarContent: some View {
        if let data = human.avatarImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if !human.avatarEmoji.isEmpty {
            Text(human.avatarEmoji)
                .font(.system(size: 44))
        } else {
            Text(String(human.name.prefix(1)))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite.opacity(0.6))
        }
    }

    @ViewBuilder
    private func humanSubjectLayer(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let avatarImage {
            if isTransparent {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(0.92)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                    .shadow(color: Color.arkInk.opacity(0.22), radius: 10, x: 0, y: 6) // ui-v4: allow avatar grounding
            } else {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.65),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        } else {
            humanAvatarContent
                .frame(width: w * 0.42, height: h * 0.72)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // ── 方案1：透明抠图 破框悬浮
    private func humanCutoutCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor.opacity(0.85),
                                 themeColor.mix(with: Color(hex: "000000"), by: 0.45).opacity(0.95)],
                        startPoint: .topTrailing, endPoint: .bottomLeading))
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.48)
                    miniInfoColumn(w: w, h: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(RadialGradient(colors: [themeColor.opacity(0.55), .clear],
                                            center: .center, startRadius: 0, endRadius: 50))
                        .frame(width: 100, height: 28).blur(radius: 8).offset(y: 6)
                    ZStack {
                        Image(uiImage: img).resizable().scaledToFit()
                            .scaleEffect(1.06).colorMultiply(.white)
                            .shadow(color: Color.goCardWhite, radius: 0, x: 2, y: 0) // ui-v4: allow cutout rim for 2.5D readability
                            .shadow(color: Color.goCardWhite, radius: 0, x: -2, y: 0) // ui-v4: allow cutout rim for 2.5D readability
                            .shadow(color: Color.goCardWhite, radius: 0, x: 0, y: -2) // ui-v4: allow cutout rim for 2.5D readability
                        Image(uiImage: img).resizable().scaledToFit()
                            .clipShape(Circle()) // Apply circular clipping for humans if preferring normal avatar look
                    }
                    .frame(width: w * 0.50, height: h * 1.12)
                    .offset(y: -12)
                }
                .frame(width: w * 0.50, alignment: .bottom)
                .allowsHitTesting(false)
            }
        }
    }

    // ── 方案2：普通照片 高斯模糊背景
    private func humanBlurCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: w, height: h).blur(radius: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.arkInk.opacity(0.25), Color.arkInk.opacity(0.52)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.ohanaCardSurface.opacity(0.30))
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: w * 0.60, height: h).clipped()
                    .mask(LinearGradient(
                        stops: [.init(color: Color.arkInk, location: 0),
                                .init(color: Color.arkInk, location: 0.45),
                                .init(color: .clear, location: 1.0)],
                        startPoint: .leading, endPoint: .trailing))
                    .allowsHitTesting(false)
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.44)
                    miniInfoColumn(w: w, h: h, textColor: .white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // ── 方案3：纯色渐变 + Emoji
    private func humanEmojiCard(geo: GeometryProxy, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor, themeColor.mix(with: .black, by: 0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(human.avatarEmoji.isEmpty ? String(human.name.prefix(1)) : human.avatarEmoji)
                    .font(.system(size: 56)).minimumScaleFactor(0.5)
                    .frame(width: w * 0.50, height: h * 0.90, alignment: .center)
                    .allowsHitTesting(false)
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.50)
                    miniInfoColumn(w: w, h: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // ── 右侧信息列（姓名 + 陪伴天数 + 角色）
    private func miniInfoColumn(w: CGFloat, h: CGFloat, textColor: Color? = nil) -> some View {
        let tc: Color = textColor ?? readableTextColor
        return VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(companionshipDays)")
                    .font(OhanaFont.metric(size: 20))
                    .foregroundStyle(tc)
                Text("天")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(tc.opacity(0.6))
            }
            .padding(.bottom, 3)

            HStack(spacing: 4) {
                compactBadge("人类", textColor: tc)
                compactBadge(human.birthday == nil ? "年龄未知" : human.ageText, textColor: tc)
            }
            .padding(.bottom, 10)
        }
        .padding(.trailing, 10)
        .frame(width: w * 0.50, alignment: .trailing)
    }
}

// MARK: - 植物竖向长卡片

private struct PlantTallCard: View {
    let plant: Plant

    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景渐变
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "1A2F1A").opacity(0.6), Color(hex: "00D4AA").opacity(0.15)],
                    startPoint: .bottom, endPoint: .top
                ))

            VStack(spacing: 0) {
                Spacer()
                // 植物向上生长的 emoji
                Text(plant.avatarEmoji)
                    .font(.system(size: 42))
                    .shadow(color: Color.goTeal.opacity(0.4), radius: 10) // ui-v4: allow plant avatar growth glow
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // 底部信息
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                if plant.needsWatering {
                    Label("需要浇水", systemImage: "drop.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goCardCyan)
                } else {
                    Text(plant.species.isEmpty ? "植物" : plant.species)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, Color.arkInk.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: 110, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.goCardWhite.opacity(0.08), lineWidth: 1)
        )
    }
}
