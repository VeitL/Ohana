//
//  CrewRosterOverlay.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

// MARK: - Ohana 图鉴主视图

enum CrewRosterInlineAddTarget: Equatable {
    case pet(UUID)
    case human(UUID)
}

private enum CrewRosterMemberFilter: String, CaseIterable, Identifiable {
    case all
    case humans
    case pets

    var id: String { rawValue }
}

@MainActor
enum CrewRosterInlineAddCompletion {
    static func target(savedPet: Pet?, savedHuman: Human?) -> CrewRosterInlineAddTarget? {
        if let savedPet {
            return .pet(savedPet.id)
        }
        if let savedHuman {
            return .human(savedHuman.id)
        }
        return nil
    }
}

struct CrewRosterOverlay: View {
    var initialMode: CrewRosterMode = .members
    var pets: [Pet] = []
    var humans: [Human] = []
    var plants: [Plant] = []
    var petSummaries: [UUID: CrewRosterPetSummary] = [:]
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onInlinePetSaved: (Pet) -> Void = { _ in }
    var onInlineHumanSaved: (Human) -> Void = { _ in }
    var onAddEntity: ((EntityType) -> Void)?
    var onClose: (() -> Void)?
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var safeTopInset: CGFloat = 0
    var safeBottomInset: CGFloat = 0
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onOpenTaskCenter: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var activeFullScreenRoute: CrewRosterFullScreenRoute?
    @State private var pendingInlineSavedPet: Pet? = nil
    @State private var pendingInlineSavedHuman: Human? = nil
    @State private var memberSearchText = ""
    @State private var selectedMemberFilter: CrewRosterMemberFilter = .all
    @FocusState private var isMemberSearchFocused: Bool
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var l: L10n { L10n(appLanguage) }
    private var normalizedMemberSearch: String {
        memberSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredPets: [Pet] {
        guard selectedMemberFilter != .humans else { return [] }
        guard !normalizedMemberSearch.isEmpty else { return Array(pets) }
        return pets.filter { pet in
            [pet.name, pet.species, pet.breed]
                .contains { $0.localizedCaseInsensitiveContains(normalizedMemberSearch) }
        }
    }

    private var filteredHumans: [Human] {
        guard selectedMemberFilter != .pets else { return [] }
        guard !normalizedMemberSearch.isEmpty else { return Array(humans) }
        return humans.filter { human in
            [human.name, human.role, human.city]
                .contains { $0.localizedCaseInsensitiveContains(normalizedMemberSearch) }
        }
    }
    private var filteredPlants: [Plant] { [] }
    private var isEmpty: Bool { pets.isEmpty && humans.isEmpty && filteredPlants.isEmpty }

    /// Legacy collaboration routes now resolve to the single member-roster surface.
    private var resolvedInitialMode: CrewRosterMode {
        switch initialMode {
        case .collaboration, .members:
            .members
        }
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
                    } else if rosterFocusCards.isEmpty {
                        memberSearchEmptyState
                    } else {
                        rosterWalletDeck
                            .transition(.opacity.combined(with: .scale(scale: 0.992)))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .crewRosterPresentations(
                fullScreenRoute: $activeFullScreenRoute,
                onAddEntityDismissed: resetPendingInlineAddEntity,
                onAddEntityComplete: completeInlineAddEntity,
                onPetSaved: { pendingInlineSavedPet = $0 },
                onHumanSaved: { pendingInlineSavedHuman = $0 },
                onPresentCoconutLog: { subject in
                    onPresentCoconutLog?(subject)
                }
            )
            .onAppear {
                if searchTrigger {
                    focusMemberSearch()
                }
            }
            .onChange(of: searchTrigger) { _, _ in
                focusMemberSearch()
            }
            .accessibilityIdentifier("crew-roster-\(resolvedInitialMode.rawValue)")
        }
    }

    // MARK: - Top Chrome

    private var rosterTopChrome: some View {
        VStack(spacing: 10) {
            rosterHeader
            rosterTaskCenterAction
            if !isEmpty {
                rosterMemberTools
                rosterMemberSummaryRow
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, safeTopInset + 12)
        .padding(.bottom, 10)
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

    @ViewBuilder
    private var rosterTaskCenterAction: some View {
        if let onOpenTaskCenter {
            Button {
                OhanaFeedback.light()
                onOpenTaskCenter()
            } label: {
                HStack(spacing: 10) {
                    Label(
                        l.tr(zh: "查看待办", en: "View tasks", de: "Aufgaben anzeigen"),
                        systemImage: "checklist"
                    )
                    .font(OhanaFont.callout(.bold))
                    Spacer()
                    Image(systemName: "chevron.right") // a11y: allow decorative disclosure glyph hidden below
                        .font(OhanaFont.caption(.black))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Color.ohanaControlFill,
                    in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityIdentifier("crew-roster-open-task-center")
        }
    }

    @ViewBuilder
    private var rosterMemberTools: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                rosterMemberSearchField
                rosterMemberFilterPicker
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: 10) {
                rosterMemberSearchField
                rosterMemberFilterPicker
            }
        }
    }

    private var rosterMemberSearchField: some View {
        TextField(
            l.tr(zh: "搜索姓名、品种或城市", en: "Search names, breeds, or cities", de: "Name, Rasse oder Ort suchen"),
            text: $memberSearchText
        )
        .textFieldStyle(.roundedBorder)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($isMemberSearchFocused)
        .accessibilityIdentifier("crew-roster-member-search")
    }

    private var rosterMemberFilterPicker: some View {
        Picker(
            l.tr(zh: "筛选成员", en: "Filter members", de: "Mitglieder filtern"),
            selection: $selectedMemberFilter
        ) {
            ForEach(CrewRosterMemberFilter.allCases) { filter in
                Label(memberFilterTitle(filter), systemImage: memberFilterIcon(filter))
                    .tag(filter)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityIdentifier("crew-roster-member-filter")
    }

    @ViewBuilder
    private var rosterMemberSummaryRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                rosterSummaryMetric(value: humans.count, title: l.tr(zh: "人类", en: "People", de: "Menschen"), icon: "person.fill")
                Divider()
                rosterSummaryMetric(value: pets.count, title: l.tr(zh: "宠物", en: "Pets", de: "Tiere"), icon: "pawprint.fill")
                Divider()
                rosterSummaryMetric(value: totalMemberCoconuts, title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokos"), icon: "circle.hexagongrid.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("crew-roster-member-summary")
        } else {
            HStack(spacing: 12) {
                rosterSummaryMetric(value: humans.count, title: l.tr(zh: "人类", en: "People", de: "Menschen"), icon: "person.fill")
                Divider().frame(height: 30)
                rosterSummaryMetric(value: pets.count, title: l.tr(zh: "宠物", en: "Pets", de: "Tiere"), icon: "pawprint.fill")
                Divider().frame(height: 30)
                rosterSummaryMetric(value: totalMemberCoconuts, title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokos"), icon: "circle.hexagongrid.fill")
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("crew-roster-member-summary")
        }
    }

    private func rosterSummaryMetric(value: Int, title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                Text(title)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var totalMemberCoconuts: Int {
        humans.reduce(0) { $0 + max(0, $1.coconutBalance) }
            + pets.reduce(0) { $0 + max(0, $1.coconutBalance) }
    }

    private func memberFilterTitle(_ filter: CrewRosterMemberFilter) -> String {
        switch filter {
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
        case .humans: l.tr(zh: "人类", en: "People", de: "Menschen")
        case .pets: l.tr(zh: "宠物", en: "Pets", de: "Tiere")
        }
    }

    private func memberFilterIcon(_ filter: CrewRosterMemberFilter) -> String {
        switch filter {
        case .all: "person.2.fill"
        case .humans: "person.fill"
        case .pets: "pawprint.fill"
        }
    }

    private var rosterHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.crop.square.stack.fill") // a11y: allow decorative section icon hidden below
                .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
                .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(Color.goPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "家庭成员", en: "Family Members", de: "Familienmitglieder"))
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(
                    zh: "档案、钱包与成员管理",
                    en: "Profiles, wallets, and member management",
                    de: "Profile, Wallets und Mitgliederverwaltung"
                ))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            rosterPrimaryAction

            if !hideToolbar {
                Button { closeRoster() } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                .accessibilityIdentifier("crew-roster-close-action")
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

    private func presentInlineAddEntity(_ type: EntityType) {
        guard AppFeatureRouteGuard.allowsAddEntity(type) else {
            AppFeatureRouteGuard.recordIntercept("crewAddEntity:\(type.rawValue)")
            return
        }
        guard activeFullScreenRoute == nil else { return }
        activeFullScreenRoute = .addEntity(type)
    }

    private func completeInlineAddEntity() {
        let savedPet = pendingInlineSavedPet
        let savedHuman = pendingInlineSavedHuman
        let savedTarget = CrewRosterInlineAddCompletion.target(savedPet: savedPet, savedHuman: savedHuman)
        pendingInlineSavedPet = nil
        pendingInlineSavedHuman = nil

        withAnimation(GoMotion.sheet) {
            activeFullScreenRoute = nil
        }

        OhanaFrameScheduler.runAfterNextFrame(milliseconds: 120) {
            switch savedTarget {
            case .pet:
                guard let savedPet else { return }
                onInlinePetSaved(savedPet)
            case .human:
                guard let savedHuman else { return }
                onInlineHumanSaved(savedHuman)
            case nil:
                break
            }
        }
    }

    private func resetPendingInlineAddEntity() {
        pendingInlineSavedPet = nil
        pendingInlineSavedHuman = nil
    }

    @ViewBuilder
    private var rosterPrimaryAction: some View {
        Menu {
            ForEach(Array(memberAddMenuItems.enumerated()), id: \.element) { _, type in
                Button {
                    addRosterEntity(type)
                } label: {
                    Label(addEntityTitle(for: type), systemImage: type.icon)
                }
                .accessibilityIdentifier("crew-roster-add-\(type.rawValue)-action")
            }
        } label: {
            Label(
                l.tr(zh: "添加成员", en: "Add member", de: "Mitglied hinzufügen"),
                systemImage: "plus"
            )
            .labelStyle(.iconOnly)
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel(l.tr(
            zh: "添加成员",
            en: "Add member",
            de: "Mitglied hinzufügen"
        ))
        .accessibilityIdentifier("crew-roster-primary-action")
    }

    private var memberAddMenuItems: [EntityType] {
        [.human, .pet].filter { type in
            AppFeatureRouteGuard.allowsAddEntity(type)
        }
    }

    private func addRosterEntity(_ type: EntityType) {
        OhanaFeedback.light()
        if let onAddEntity {
            onAddEntity(type)
        } else {
            presentInlineAddEntity(type)
        }
    }

    private func addEntityTitle(for type: EntityType) -> String {
        switch type {
        case .pet: l.addEntityPetTitle
        case .human: l.addEntityHumanTitle
        case .plant: l.addEntityPlantTitle
        }
    }

    // MARK: - Bento Dex 主体
    private var rosterFocusCards: [FocusCard] {
        let petCards = filteredPets.map { pet in
            var card = FocusCard.from(pet, includeAvatarData: false, l: l)
            card.isShownOnHome = true
            return card
        }
        let humanCards = filteredHumans.map { human in
            var card = FocusCard.from(human, includeAvatarData: false)
            card.isShownOnHome = true
            return card
        }
        return (humanCards + petCards).sorted { lhs, rhs in
            if lhs.isHuman != rhs.isHuman {
                return lhs.isHuman
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    private var rosterMediaRequestsByID: [UUID: VerticalSolidHomeMediaPreloadRequest] {
        var requests: [UUID: VerticalSolidHomeMediaPreloadRequest] = [:]
        for pet in filteredPets where !pet.avatarThumbnailSignature.isEmpty {
            requests[pet.id] = VerticalSolidHomeMediaPreloadRequest(
                id: pet.id,
                modelID: pet.persistentModelID,
                source: .pet,
                avatarSignature: pet.avatarThumbnailSignature,
                popoutSignature: "",
                wantsAvatar: true,
                wantsPopout: false
            )
        }
        for human in filteredHumans where human.hasAvatarImageAttachment {
            requests[human.id] = VerticalSolidHomeMediaPreloadRequest(
                id: human.id,
                modelID: human.persistentModelID,
                source: .human,
                avatarSignature: human.avatarThumbnailSignature,
                popoutSignature: "",
                wantsAvatar: true,
                wantsPopout: false
            )
        }
        return requests
    }

    private var rosterWalletDeck: some View {
        CrewRosterWalletScene(
            cards: rosterFocusCards,
            mediaRequestsByID: rosterMediaRequestsByID,
            safeBottom: safeBottomInset,
            reduceMotion: AppWorkloadPolicy.shared.interactionMotionBudget(isVisible: true) != .full,
            onSelect: openRosterMember
        )
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openRosterMember(_ card: FocusCard) {
        OhanaFeedback.light()
        if card.isHuman,
           let human = humans.first(where: { $0.id == card.id }) {
            onSelectHuman(human)
        } else if let pet = pets.first(where: { $0.id == card.id }) {
            onSelectPet(pet)
        }
    }

    private func focusMemberSearch() {
        OhanaFrameScheduler.runAfterNextFrame {
            isMemberSearchFocused = true
        }
    }

    private var memberSearchEmptyState: some View {
        ContentUnavailableView(
            l.tr(zh: "没有匹配的成员", en: "No matching members", de: "Keine passenden Mitglieder"),
            systemImage: "magnifyingglass",
            description: Text(l.tr(
                zh: "请更换搜索内容或成员类型。",
                en: "Try another search or member type.",
                de: "Versuche eine andere Suche oder einen anderen Typ."
            ))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
