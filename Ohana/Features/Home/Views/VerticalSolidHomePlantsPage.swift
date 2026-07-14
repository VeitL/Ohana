//
//  VerticalSolidHomePlantsPage.swift
//  Ohana
//
//  Plant page surface for the vertical solid home shell.
//

import Foundation
import SwiftData
import SwiftUI

private enum VerticalSolidHomePlantRoomDialLayout {
    static let width: CGFloat = 68
    static let collapsedHeight: CGFloat = 44
    static let expandedHeight: CGFloat = 220
    static let viewSwitcherHeight: CGFloat = 44
    static let controlGap: CGFloat = 10
}

struct VerticalSolidHomePlantsPage: View {
    let plants: [VerticalSolidHomePlantSnapshot]
    let localization: L10n
    @Binding var plantQuickActionItemsRaw: String
    let pendingQuickCareKeys: Set<String>
    let completedQuickCareKeys: Set<String>
    let failedQuickCareKeys: Set<String>
    let topChromeHeight: CGFloat
    let bottomChromeHeight: CGFloat
    let arrivingPlantCardId: UUID?
    let onOpenPlant: (VerticalSolidHomePlantSnapshot) -> Void
    let onOpenFeature: (VerticalSolidHomePlantSnapshot, PlantCareFeatureDestination) -> Void
    let onCareQuickAction: (VerticalSolidHomePlantSnapshot, PlantCareType) -> Void
    let onAddPlant: () -> Void
    let onOpenBatchCare: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCardId: UUID?
    @State private var selectedRoomId: String?
    @State private var selectedViewStyle: VerticalSolidHomePlantViewStyle = .deck
    @State private var preparedHeroSnapshots: [UUID: FocusHomeVerticalSolidHeroSnapshot] = [:]
    @State private var activeHeroSnapshot: FocusHomeVerticalSolidHeroSnapshot?
    @State private var heroProgress: CGFloat = 0
    @State private var heroDirection: Int = 0
    @State private var heroGeneration = 0
    @State private var plantAvatarCacheRevision = 0
    @State private var plantAvatarPreloadTask: Task<Void, Never>?
    @State private var collapseCleanupTask: Task<Void, Never>?
    @State private var deckScrollOffsetTracker = VerticalSolidHomePlantDeckScrollOffsetTracker()
    @State private var expandedDeckScrollOffsetY: CGFloat = 0

    private var l: L10n { localization }

    var body: some View {
        GeometryReader { proxy in
            let cardViewportHeight = VerticalSolidHomePlantWalletScrollPolicy.cardViewportHeight(
                containerHeight: proxy.size.height,
                bottomChromeHeight: bottomChromeHeight
            )
            let roomRailCenterY = VerticalSolidHomePlantWalletScrollPolicy.roomRailCenterY(
                containerHeight: proxy.size.height,
                topChromeHeight: topChromeHeight
            )

            ZStack(alignment: .top) {
                if plants.isEmpty {
                    VerticalSolidHomeEmptyAction(
                        icon: "leaf.fill",
                        title: l.tr(zh: "添加第一株植物", en: "Add first plant", de: "Erste Pflanze hinzufügen"),
                        action: onAddPlant
                    )
                    .accessibilityIdentifier("home-plants-empty-add-action")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 72)
                } else {
                    if selectedViewStyle == .deck {
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                LazyVStack(spacing: VerticalSolidHomePlantWalletScrollPolicy.sectionSpacing) {
                                    ForEach(plantCardSections) { section in
                                        plantCardSection(section, availableHeight: cardViewportHeight)
                                            .id(section.id)
                                    }
                                }
                                .accessibilityIdentifier("home-plants-view-deck")
                                .padding(.horizontal, 2)
                                .padding(.top, VerticalSolidHomePlantWalletScrollPolicy.topContentInset)
                                .padding(.bottom, bottomChromeHeight + VerticalSolidHomePlantWalletScrollPolicy.bottomContentInset)
                            }
                            .scrollBounceBehavior(.basedOnSize)
                            .scrollDisabled(selectedCardId != nil)
                            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                                geometry.contentOffset.y
                            } action: { _, offsetY in
                                let normalizedOffsetY = max(0, offsetY)
                                deckScrollOffsetTracker.offsetY = normalizedOffsetY
                            }
                            .onChange(of: selectedRoomId) { _, _ in
                                scrollToFirstPlantSection(using: scrollProxy)
                            }
                            .accessibilityIdentifier("home-plants-scroll-view")
                        }
                    } else {
                        plantRoomListView(bottomChromeHeight: bottomChromeHeight)
                    }

                    if showsPlantViewSwitcherRail {
                        plantViewSwitcherRail
                            .position(
                                x: proxy.size.width - VerticalSolidHomePlantWalletScrollPolicy.roomRailTrailingCenterInset,
                                y: viewSwitcherCenterY(roomRailCenterY: roomRailCenterY)
                            )
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .zIndex(31)
                    }

                    if showsRoomRail {
                        plantRoomRail
                            .position(
                                x: proxy.size.width - VerticalSolidHomePlantWalletScrollPolicy.roomRailTrailingCenterInset,
                                y: roomRailCenterY
                            )
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .zIndex(30)
                    }

                    if showsDueCareBanner {
                        plantDueCareBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .zIndex(32)
                    }
                }
            }
        }
        .onAppear {
            prepareHeroSnapshots()
            reconcileRoomSelection()
            reconcileCardSelection()
            scheduleVisiblePlantAvatarPreload()
        }
        .onChange(of: plantCardsSignature) { _, _ in
            prepareHeroSnapshots()
            reconcileRoomSelection()
            reconcileCardSelection()
        }
        .onChange(of: plantAvatarPreloadSignature) { _, _ in
            scheduleVisiblePlantAvatarPreload()
        }
        .onChange(of: plantRoomsSignature) { _, _ in
            reconcileRoomSelection()
            reconcileCardSelection()
        }
        .onDisappear {
            collapseCleanupTask?.cancel()
            collapseCleanupTask = nil
            plantAvatarPreloadTask?.cancel()
            plantAvatarPreloadTask = nil
            heroGeneration += 1
            withoutAnimation {
                selectedCardId = nil
                activeHeroSnapshot = nil
                heroProgress = 0
                heroDirection = 0
            }
        }
        .accessibilityIdentifier("home-plants-page")
    }

    private var plantCards: [FocusCard] {
        visiblePlants.map { plant in
            let status = plantCardStatus(for: plant)
            return FocusCard(
                id: plant.id,
                name: plant.name,
                kind: plant.subtitle.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.subtitle,
                emoji: plant.emoji,
                color: Color(hex: plant.themeHex),
                streak: 0,
                coconutBalance: 0,
                avatarImageData: nil,
                avatarImageSignature: plant.avatarImageSignature,
                avatarImageAssetName: plant.avatarImageAssetName,
                petSpecies: plant.subtitle,
                themeColorHex: plant.themeHex,
                statusBadgeText: status.text,
                statusBadgeIsWarning: status.isWarning,
                statusBadgeToneRaw: status.tone.rawValue,
                isPlant: true,
                isReal: true,
                actions: [
                    FocusCard.Action(label: l.tr(zh: "照护", en: "Care", de: "Pflege"), icon: "drop.fill", colorHex: "4FB6A3"),
                    FocusCard.Action(label: l.tr(zh: "详情", en: "Detail", de: "Detail"), icon: "leaf.circle.fill", colorHex: plant.themeHex)
                ]
            )
        }
    }

    private var visiblePlants: [VerticalSolidHomePlantSnapshot] {
        guard let selectedRoomId else { return plants }
        return plants.filter { roomIdentifier(for: $0) == selectedRoomId }
    }

    private var dueCarePlantCount: Int {
        plants.count(where: \.needsCare)
    }

    private var showsDueCareBanner: Bool {
        dueCarePlantCount > 0 && selectedCardId == nil && heroDirection == 0
    }

    private var plantDueCareBanner: some View {
        Button {
            OhanaFeedback.light()
            onOpenBatchCare()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon; button label names the batch-care action.
                    .font(OhanaFont.adaptive(size: 14, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 34, height: 34) // a11y: allow decorative glyph inside a 50pt labeled batch-care button.
                    .background(Color.goYellow, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(l.tr(
                        zh: "今日 \(dueCarePlantCount) 株待照护",
                        en: "\(dueCarePlantCount) plants need care today",
                        de: "\(dueCarePlantCount) Pflanzen brauchen heute Pflege"
                    ))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                    Text(l.tr(zh: "批量处理", en: "Open batch care", de: "Batch-Pflege öffnen"))
                        .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right") // a11y: allow decorative disclosure glyph; button label names the action.
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .frame(width: 24, height: 24) // a11y: allow non-interactive glyph inside a 50pt labeled button.
                    .accessibilityHidden(true)
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(Color.ohanaCardSurface.opacity(0.94), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.ohanaCardStroke.opacity(0.66), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(
            zh: "今日 \(dueCarePlantCount) 株植物待照护，打开批量照护",
            en: "\(dueCarePlantCount) plants need care today, open batch care",
            de: "\(dueCarePlantCount) Pflanzen brauchen heute Pflege, Batch-Pflege öffnen"
        ))
        .accessibilityIdentifier("home-plants-due-care-banner")
    }

    private var plantCardSections: [VerticalSolidHomePlantCardSection] {
        let cards = plantCards
        guard !cards.isEmpty else { return [] }
        return [VerticalSolidHomePlantCardSection(cards: cards)]
    }

    private var plantCardsSignature: String {
        plantCards.map { card in
            [
                card.id.uuidString,
                card.name,
                card.kind,
                card.statusBadgeText ?? "",
                card.themeColorHex
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private var plantAvatarPreloadSignature: String {
        visiblePlants.map { plant in
            [
                plant.id.uuidString,
                String(describing: plant.modelID),
                plant.avatarImageSignature,
                plant.avatarImageAssetName ?? ""
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private var plantRoomsSignature: String {
        plantRoomSummaries.map { summary in
            "\(summary.id):\(summary.plantCount):\(summary.dueCount)"
        }.joined(separator: "|")
    }

    private var plantRoomSummaries: [VerticalSolidHomePlantRoomSummary] {
        Dictionary(grouping: plants, by: roomIdentifier(for:))
            .map { id, roomPlants in
                VerticalSolidHomePlantRoomSummary(
                    id: id,
                    title: roomTitle(for: roomPlants.first),
                    plantCount: roomPlants.count,
                    dueCount: roomPlants.count(where: \.needsCare)
                )
            }
            .sorted { lhs, rhs in
                if lhs.dueCount != rhs.dueCount {
                    return lhs.dueCount > rhs.dueCount
                }
                if lhs.plantCount != rhs.plantCount {
                    return lhs.plantCount > rhs.plantCount
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var showsRoomRail: Bool {
        selectedViewStyle == .deck &&
        VerticalSolidHomePlantRoomRailPolicy.shouldShow(
            plantCount: plants.count,
            selectedCardId: selectedCardId,
            heroDirection: heroDirection
        )
    }

    private var showsPlantViewSwitcherRail: Bool {
        !plants.isEmpty && selectedCardId == nil && heroDirection == 0
    }

    private var roomRailHeight: CGFloat {
        VerticalSolidHomePlantRoomDialLayout.expandedHeight
    }

    private var viewSwitcherRailHeight: CGFloat {
        VerticalSolidHomePlantRoomDialLayout.viewSwitcherHeight
    }

    private func viewSwitcherCenterY(roomRailCenterY: CGFloat) -> CGFloat {
        guard showsRoomRail else { return roomRailCenterY }
        return max(
            56,
            roomRailCenterY
                - roomRailHeight / 2
                - VerticalSolidHomePlantRoomDialLayout.controlGap
                - viewSwitcherRailHeight / 2
        )
    }

    @ViewBuilder
    private func plantDockQuickActions(for card: FocusCard) -> some View {
        if let plant = plantSnapshot(for: card) {
            PlantDockQuickActionsView(
                plantID: plant.id,
                plantName: plant.name,
                dueCareTypes: plantDueCareTypes(for: plant),
                overdueCareTypes: plantOverdueCareTypes(for: plant),
                pendingCareTypes: plantQuickCareTypes(in: pendingQuickCareKeys, for: plant.id),
                completedCareTypes: plantQuickCareTypes(in: completedQuickCareKeys, for: plant.id),
                failedCareTypes: plantQuickCareTypes(in: failedQuickCareKeys, for: plant.id),
                localization: localization,
                quickActionItemsRaw: $plantQuickActionItemsRaw,
                shouldReduceWork: reduceMotion,
                accentColor: Color(hex: card.themeColorHex),
                forcesSubmenusBelow: false,
                onAction: { action in
                    performPlantDockAction(action, plant: plant)
                },
                onDetail: { action in
                    openPlantDockDetail(action, plant: plant)
                }
            )
        } else {
            VerticalHomeEmbeddedQuickActions(
                title: l.tr(zh: "快捷", en: "Quick", de: "Schnell"),
                items: [],
                localization: localization,
                shouldReduceWork: reduceMotion,
                forcesSubmenusBelow: false
            )
        }
    }

    private var plantViewSwitcherRail: some View {
        Picker(
            l.tr(zh: "植物视图", en: "Plant view", de: "Pflanzenansicht"),
            selection: Binding(
                get: { selectedViewStyle },
                set: { selectPlantViewStyle($0) }
            )
        ) {
            ForEach(VerticalSolidHomePlantViewStyle.allCases) { style in
                Label(style.title(l), systemImage: style.icon)
                    .labelStyle(.iconOnly)
                    .tag(style)
                    .accessibilityIdentifier("home-plants-view-\(style.rawValue)")
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(
            width: 88,
            height: VerticalSolidHomePlantRoomDialLayout.viewSwitcherHeight
        )
        .accessibilityIdentifier("home-plants-view-switcher-rail")
    }

    private var plantRoomRail: some View {
        VerticalSolidHomePlantRoomDial(
            options: plantRoomDialOptions,
            selectedRoomID: selectedRoomId,
            localization: l,
            reduceMotion: reduceMotion,
            onSelect: { selectRoom($0) }
        )
        .opacity(showsRoomRail ? 1 : 0)
    }

    private var plantRoomDialOptions: [VerticalSolidHomePlantRoomDialOption] {
        var options = [VerticalSolidHomePlantRoomDialOption(
            id: "all",
            roomID: nil,
            title: l.tr(zh: "全部", en: "All", de: "Alle"),
            shortTitle: l.tr(zh: "全部", en: "ALL", de: "ALLE"),
            count: plants.count,
            dueCount: plants.count(where: \.needsCare)
        )]
        options.append(contentsOf: plantRoomSummaries.map { summary in
            VerticalSolidHomePlantRoomDialOption(
                id: summary.id,
                roomID: summary.id,
                title: summary.title,
                shortTitle: VerticalSolidHomePlantRoomDial.shortTitle(summary.title),
                count: summary.plantCount,
                dueCount: summary.dueCount
            )
        })
        return options
    }

    private func plantRoomListView(bottomChromeHeight: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(plantRoomSummaries) { summary in
                    plantRoomListSection(summary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.trailing, 52)
            .padding(.bottom, bottomChromeHeight + 120)
            .accessibilityIdentifier("home-plants-view-list")
        }
        .scrollBounceBehavior(.basedOnSize)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .accessibilityIdentifier("home-plants-room-list-view")
    }

    private func plantRoomListSection(_ summary: VerticalSolidHomePlantRoomSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.title)
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("\(summary.plantCount)")
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(Color.goPrimary, in: Capsule())

                Spacer(minLength: 4)

                if summary.dueCount > 0 {
                    Label("\(summary.dueCount)", systemImage: "calendar.badge.clock")
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                        .labelStyle(.titleAndIcon)
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(plantsForRoomListSection(summary)) { plant in
                    plantRoomListCard(plant)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-plants-room-list-section-\(roomRailIdentifier(summary.id))")
    }

    private func plantsForRoomListSection(_ summary: VerticalSolidHomePlantRoomSummary) -> [VerticalSolidHomePlantSnapshot] {
        plants
            .filter { roomIdentifier(for: $0) == summary.id }
            .sorted { lhs, rhs in
                if lhs.needsCare != rhs.needsCare {
                    return lhs.needsCare && !rhs.needsCare
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    private func plantRoomListCard(_ plant: VerticalSolidHomePlantSnapshot) -> some View {
        Button {
            onOpenPlant(plant)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    plantRoomListAvatar(plant)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plant.name)
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(plant.subtitle.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.subtitle)
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 6) {
                    plantRoomListInfoRow(icon: "gauge.with.dots.needle.33percent", text: plant.careDifficultyText, tint: Color.goPrimary)
                    plantRoomListInfoRow(icon: "exclamationmark.triangle.fill", text: plant.attentionText, tint: plant.needsCare ? Color.goYellow : Color.goTeal)
                    plantRoomListInfoRow(icon: plant.needsCare ? "calendar.badge.clock" : "checkmark.seal.fill", text: plant.todoText, tint: plant.needsCare ? Color.goYellow : Color.goTeal)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
            .background(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.94 : 0.98), in: RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.card, style: .continuous)
                    .strokeBorder(Color.ohanaGlassStroke.opacity(colorScheme == .dark ? 0.18 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(plantRoomListCardAccessibilityLabel(plant))
        .accessibilityIdentifier("home-plants-room-list-card-\(plant.id.uuidString)")
    }

    @ViewBuilder
    private func plantRoomListAvatar(_ plant: VerticalSolidHomePlantSnapshot) -> some View {
        let tint = Color(hex: plant.themeHex)
        let avatarEntry = FocusWalletAvatarCache.cachedEntry(for: plant.id, signature: plant.avatarImageSignature)
            ?? FocusWalletAvatarCache.Entry(
                image: FocusWalletNamedImageLoader.image(named: plant.avatarImageAssetName),
                isTransparent: false,
                signature: plant.avatarImageSignature,
                isFinal: false
            )
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .fill(tint.opacity(0.16))
            if let image = avatarEntry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
            } else {
                Image(systemName: "leaf.fill") // a11y: allow decorative fallback avatar; the plant list card label names the plant.
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityHidden(true)
    }

    private func plantRoomListInfoRow(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 9, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 14, height: 14) // a11y: allow decorative status glyph inside a full-size plant list card button.
                .accessibilityHidden(true)
            Text(text)
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }

    private func plantRoomListCardAccessibilityLabel(_ plant: VerticalSolidHomePlantSnapshot) -> String {
        [
            plant.name,
            plant.careDifficultyText,
            plant.attentionText,
            plant.todoText
        ].joined(separator: ", ")
    }

    private func plantCardSection(
        _ section: VerticalSolidHomePlantCardSection,
        availableHeight: CGFloat
    ) -> some View {
        let sectionSelectedCardId = section.contains(cardId: selectedCardId) ? selectedCardId : nil
        let sectionHeroSnapshot = section.contains(cardId: activeHeroSnapshot?.card.id) ? activeHeroSnapshot : nil
        let sectionProgress = sectionSelectedCardId == nil ? 0 : heroProgress
        let sectionHeroDirection = sectionSelectedCardId == nil ? 0 : heroDirection
        let isSectionExpanded = sectionSelectedCardId != nil
        let baseSectionHeight = VerticalSolidHomePlantWalletScrollPolicy.sectionHeight(
            cardCount: section.cards.count,
            isExpanded: isSectionExpanded,
            availableHeight: availableHeight
        )
        let baseSceneHeight = VerticalSolidHomePlantWalletScrollPolicy.sceneHeight(
            cardCount: section.cards.count,
            isExpanded: isSectionExpanded,
            availableHeight: availableHeight
        )
        let sceneHeight = VerticalSolidHomePlantWalletScrollPolicy.anchoredExpandedSceneHeight(
            baseHeight: baseSceneHeight,
            isExpanded: isSectionExpanded,
            scrollOffsetY: expandedDeckScrollOffsetY
        )
        let sectionHeight = max(baseSectionHeight, sceneHeight)

        return FocusHomeVerticalSolidScene(
            cards: section.cards,
            safeTop: 0,
            safeBottom: 0,
            selectedCardId: sectionSelectedCardId,
            preparedHeroSnapshots: preparedHeroSnapshots,
            heroSnapshot: sectionHeroSnapshot,
            progress: sectionProgress,
            heroDirection: sectionHeroDirection,
            arrivingCardId: section.contains(cardId: arrivingPlantCardId) ? arrivingPlantCardId : nil,
            reduceMotion: reduceMotion,
            localization: localization,
            allowsAmbientFloat: false,
            isVisible: true,
            embedsQuickActionsInCard: true,
            freezesInactiveCollapsedGeometryDuringHero: true,
            collapsedTopInset: 0,
            collapsedVerticalBias: FocusHomeVerticalSolidCollapsedLayoutPolicy.defaultVerticalBias,
            collapsedLayoutMode: .scrollExtended,
            expandedVerticalPlacement: .viewportTop(
                topInset: VerticalSolidHomePlantWalletScrollPolicy.expandedCardViewportTopInset,
                scrollOffsetY: expandedDeckScrollOffsetY
            ),
            avatarCacheRevision: plantAvatarCacheRevision,
            quickActions: { card in
                plantDockQuickActions(for: card)
            },
            contextMenu: { _ in EmptyView() },
            onSelect: expandCard,
            onCollapse: collapseCard,
            onWalkCardMinimizeToFloatingControl: {},
            onOpenDetails: openPlant
        )
        .frame(height: sceneHeight)
        .frame(maxWidth: .infinity, minHeight: sectionHeight, alignment: .center)
        .id(section.id)
    }

    private func expandCard(_ snapshot: FocusHomeVerticalSolidHeroSnapshot) {
        let card = snapshot.card
        let canReopenSettledCard = selectedCardId == card.id
            && heroDirection == 0
            && heroProgress <= 0.06
        guard selectedCardId != card.id || canReopenSettledCard else { return }
        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        heroGeneration += 1
        let generation = heroGeneration
        let frozenScrollOffsetY = deckScrollOffsetTracker.offsetY
        OhanaFeedback.light()
        withoutAnimation {
            expandedDeckScrollOffsetY = frozenScrollOffsetY
            selectedCardId = card.id
            activeHeroSnapshot = snapshot
            heroDirection = 1
            heroProgress = 0
        }
        OhanaFrameScheduler.runAfterNextFrame {
            guard generation == heroGeneration,
                  selectedCardId == card.id,
                  heroDirection == 1 else { return }
            withAnimation(heroAnimation, completionCriteria: .removed) {
                heroProgress = 1
            } completion: {
                completeExpand(cardId: card.id, generation: generation)
            }
        }
    }

    private func collapseCard() {
        guard let selectedCardId else { return }
        OhanaFeedback.light()
        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        heroGeneration += 1
        let generation = heroGeneration
        guard let collapseSnapshot = activeHeroSnapshot
            ?? preparedHeroSnapshots[selectedCardId]
            ?? makeHeroSnapshot(for: selectedCardId) else {
            return
        }
        withoutAnimation {
            activeHeroSnapshot = collapseSnapshot
            heroDirection = -1
        }
        withAnimation(heroAnimation, completionCriteria: .removed) {
            heroProgress = 0
        } completion: {
            completeCollapse(cardId: selectedCardId, generation: generation)
        }
    }

    private func completeExpand(cardId: UUID, generation: Int) {
        guard generation == heroGeneration,
              selectedCardId == cardId,
              heroDirection == 1 else { return }
        withoutAnimation {
            heroProgress = 1
            heroDirection = 0
        }
    }

    private func completeCollapse(cardId: UUID, generation: Int) {
        guard generation == heroGeneration,
              selectedCardId == cardId,
              heroDirection == -1 else { return }
        withoutAnimation {
            heroProgress = 0
            heroDirection = 0
        }
        collapseCleanupTask = OhanaFrameScheduler.runAfterNextFrame {
            guard generation == heroGeneration,
                  selectedCardId == cardId,
                  heroDirection == 0 else { return }
            collapseCleanupTask = OhanaFrameScheduler.runAfterNextFrame {
                guard generation == heroGeneration,
                      selectedCardId == cardId,
                      heroDirection == 0 else { return }
                withoutAnimation {
                    self.selectedCardId = nil
                    activeHeroSnapshot = nil
                }
                collapseCleanupTask = nil
            }
        }
    }

    private func openPlant(_ card: FocusCard) {
        guard let plant = plantSnapshot(for: card) else { return }
        openPlant(plant)
    }

    private func openPlant(_ plant: VerticalSolidHomePlantSnapshot) {
        onOpenPlant(plant)
    }

    private func openPlantFeature(_ destination: PlantCareFeatureDestination, plant: VerticalSolidHomePlantSnapshot) {
        onOpenFeature(plant, destination)
    }

    private func performPlantDockAction(_ action: PlantDockQuickAction, plant: VerticalSolidHomePlantSnapshot) {
        guard let careType = action.careType else {
            openPlant(plant)
            return
        }
        onCareQuickAction(plant, careType)
    }

    private func openPlantDockDetail(_ action: PlantDockQuickAction, plant: VerticalSolidHomePlantSnapshot) {
        switch action {
        case .detail:
            openPlant(plant)
        default:
            if let destination = action.detailFeatureDestination {
                openPlantFeature(destination, plant: plant)
            } else {
                openPlant(plant)
            }
        }
    }

    private func plantDueCareTypes(for plant: VerticalSolidHomePlantSnapshot) -> Set<PlantCareType> {
        Set(plant.dueCareTypes)
    }

    private func plantOverdueCareTypes(for plant: VerticalSolidHomePlantSnapshot) -> Set<PlantCareType> {
        Set(plant.overdueCareTypes)
    }

    private func plantCardStatus(for plant: VerticalSolidHomePlantSnapshot) -> HomeCardStatusSnapshot {
        HomeCardStatusPolicy.plantSnapshot(
            overdueCareCount: plant.overdueCareCount,
            dueCareCount: plant.dueCareCount
        )
    }

    private func plantQuickCareTypes(in keys: Set<String>, for plantID: UUID) -> Set<PlantCareType> {
        Set(PlantCareType.allCases.filter { careType in
            keys.contains(PlantQuickCareFeedbackKey.key(plantID: plantID, careType: careType))
        })
    }

    private func plantSnapshot(for card: FocusCard) -> VerticalSolidHomePlantSnapshot? {
        plants.first { $0.id == card.id }
    }

    private func makeHeroSnapshot(for card: FocusCard, index: Int) -> FocusHomeVerticalSolidHeroSnapshot {
        FocusHomeVerticalSolidHeroSnapshot(
            card: card,
            index: index,
            avatarSource: FocusHomeFrozenAvatarSource.cached(for: card) ?? .placeholder
        )
    }

    private func makeHeroSnapshot(for cardId: UUID) -> FocusHomeVerticalSolidHeroSnapshot? {
        guard let pair = sectionIndexedPlantCards().first(where: { $0.card.id == cardId }) else {
            return nil
        }
        return makeHeroSnapshot(for: pair.card, index: pair.index)
    }

    private func prepareHeroSnapshots() {
        let next = Dictionary(
            uniqueKeysWithValues: sectionIndexedPlantCards().map { pair in
                (pair.card.id, makeHeroSnapshot(for: pair.card, index: pair.index))
            }
        )
        withoutAnimation {
            preparedHeroSnapshots = next
            if let selectedCardId,
               let refreshed = next[selectedCardId],
               heroDirection == 0 {
                activeHeroSnapshot = refreshed.preservingCollapsedGeometry(from: activeHeroSnapshot)
            }
        }
    }

    private func scheduleVisiblePlantAvatarPreload() {
        plantAvatarPreloadTask?.cancel()
        let requests = visiblePlants.compactMap { plant -> VerticalSolidHomePlantAvatarPreloadRequest? in
            guard plant.avatarImageAssetName == nil,
                  !plant.avatarImageSignature.isEmpty,
                  FocusWalletAvatarCache.cachedEntry(for: plant.id, signature: plant.avatarImageSignature) == nil
            else { return nil }
            return VerticalSolidHomePlantAvatarPreloadRequest(
                id: plant.id,
                modelID: plant.modelID,
                signature: plant.avatarImageSignature
            )
        }
        guard !requests.isEmpty else { return }

        let loader = SwiftDataMediaBlobLoader(modelContainer: modelContext.container)
        plantAvatarPreloadTask = Task { @MainActor in
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }

            var payloads: [FocusWalletAvatarCache.Payload] = []
            payloads.reserveCapacity(requests.count)
            for request in requests {
                guard !Task.isCancelled else { return }
                guard FocusWalletAvatarCache.cachedEntry(for: request.id, signature: request.signature) == nil,
                      let data = await loader.plantAvatarImageData(modelID: request.modelID),
                      !data.isEmpty
                else {
                    await Task.yield()
                    continue
                }
                payloads.append(FocusWalletAvatarCache.Payload(id: request.id, data: data))
                await Task.yield()
            }

            guard !Task.isCancelled, !payloads.isEmpty else { return }
            let didRefresh = await FocusWalletAvatarCache.preload(payloads: payloads)
            guard !Task.isCancelled, didRefresh else { return }
            plantAvatarCacheRevision &+= 1
        }
    }

    private func selectRoom(_ roomId: String?) {
        OhanaFeedback.light()
        resetCardSelectionForRoomChange()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            selectedRoomId = roomId
        }
    }

    private func selectPlantViewStyle(_ style: VerticalSolidHomePlantViewStyle) {
        guard selectedViewStyle != style else { return }
        OhanaFeedback.light()
        resetCardSelectionForRoomChange()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            selectedViewStyle = style
            if style == .list {
                selectedRoomId = nil
            }
        }
    }

    private func reconcileRoomSelection() {
        guard let selectedRoomId,
              !plantRoomSummaries.contains(where: { $0.id == selectedRoomId }) else { return }
        self.selectedRoomId = nil
    }

    private func sectionIndexedPlantCards() -> [(card: FocusCard, index: Int)] {
        plantCardSections.flatMap { section in
            section.cards.enumerated().map { index, card in
                (card: card, index: index)
            }
        }
    }

    private func scrollToFirstPlantSection(using proxy: ScrollViewProxy) {
        guard let firstSectionId = plantCardSections.first?.id else { return }
        OhanaFrameScheduler.runAfterNextFrame {
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
                proxy.scrollTo(firstSectionId, anchor: .top)
            }
        }
    }

    private func resetCardSelectionForRoomChange() {
        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        heroGeneration += 1
        withoutAnimation {
            selectedCardId = nil
            activeHeroSnapshot = nil
            heroProgress = 0
            heroDirection = 0
        }
    }

    private func reconcileCardSelection() {
        guard let selectedCardId,
              !visiblePlants.contains(where: { $0.id == selectedCardId }) else { return }
        collapseCleanupTask?.cancel()
        collapseCleanupTask = nil
        heroGeneration += 1
        withoutAnimation {
            self.selectedCardId = nil
            activeHeroSnapshot = nil
            heroProgress = 0
            heroDirection = 0
        }
    }

    private var heroAnimation: Animation {
        reduceMotion ? HeroAnim.walletReduced : GoMotion.zStackHero
    }

    private func withoutAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            updates()
        }
    }

    private func roomIdentifier(for plant: VerticalSolidHomePlantSnapshot) -> String {
        roomTitle(for: plant)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    private func roomTitle(for plant: VerticalSolidHomePlantSnapshot?) -> String {
        let trimmed = plant?.roomName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? l.tr(zh: "未设置", en: "Unassigned", de: "Ohne Ort") : trimmed
    }

    private func roomRailIdentifier(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

private struct VerticalSolidHomePlantRoomDialOption: Identifiable, Equatable {
    let id: String
    let roomID: String?
    let title: String
    let shortTitle: String
    let count: Int
    let dueCount: Int
}

private struct VerticalSolidHomePlantRoomDialWheelItem: Identifiable {
    let id: Int
    let cycle: Int
    let option: VerticalSolidHomePlantRoomDialOption
}

private struct VerticalSolidHomePlantRoomDial: View {
    let options: [VerticalSolidHomePlantRoomDialOption]
    let selectedRoomID: String?
    let localization: L10n
    let reduceMotion: Bool
    let onSelect: (String?) -> Void

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var isExpanded = false
    @State private var scrollID: Int?

    private var l: L10n { localization }

    private var currentOption: VerticalSolidHomePlantRoomDialOption {
        options.first(where: { $0.roomID == selectedRoomID }) ?? options[0]
    }

    private var usesDialMotion: Bool {
        workloadPolicy.visualEffectsBudget(isVisible: true).usesFullEffects && !reduceMotion
    }

    var body: some View {
        Group {
            if isExpanded {
                wheel
            } else {
                collapsedButton
            }
        }
        .frame(
            width: VerticalSolidHomePlantRoomDialLayout.width,
            height: isExpanded
                ? VerticalSolidHomePlantRoomDialLayout.expandedHeight
                : VerticalSolidHomePlantRoomDialLayout.collapsedHeight
        )
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .trailing)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-plants-room-edge-rail")
        .onChange(of: selectedRoomID) { _, roomID in
            guard isExpanded else { return }
            recenter(roomID: roomID)
        }
        .onChange(of: options) { _, _ in
            guard isExpanded else { return }
            recenter(roomID: selectedRoomID)
        }
        .onDisappear {
            isExpanded = false
            scrollID = nil
        }
    }

    private var collapsedButton: some View {
        let option = currentOption
        return Button {
            expand()
        } label: {
            label(option, isFocused: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(option, isSelected: true))
        .accessibilityHint(l.tr(
            zh: "轻点展开房间滚轮，上下轻扫切换",
            en: "Tap to expand the room dial, then swipe vertically",
            de: "Tippen, um das Raumrad zu öffnen, dann vertikal streichen"
        ))
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
        .accessibilityIdentifier("home-plants-room-edge-collapsed")
    }

    private var wheel: some View {
        let items = wheelItems
        return ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    wheelButton(item, isFocused: item.id == scrollID)
                        .id(item.id)
                        .scrollTransition(.interactive(timingCurve: .easeInOut), axis: .vertical) { content, phase in
                            let distance = min(CGFloat(abs(phase.value)), 1)
                            let scale: CGFloat = usesDialMotion ? 1 - distance * 0.14 : 1
                            let opacity: Double = max(0.38, 1 - Double(distance) * 0.62)
                            let horizontalOffset: CGFloat = usesDialMotion ? distance * 7 : 0
                            return content
                                .scaleEffect(scale)
                                .opacity(opacity)
                                .offset(x: horizontalOffset)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.vertical, 88, for: .scrollContent)
        .scrollPosition(id: $scrollID, anchor: .center)
        .scrollTargetBehavior(.viewAligned(anchor: .center))
        .frame(
            width: VerticalSolidHomePlantRoomDialLayout.width,
            height: VerticalSolidHomePlantRoomDialLayout.expandedHeight
        )
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.14),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .onAppear {
            if scrollID == nil {
                scrollID = middleID(for: selectedRoomID)
            }
        }
        .onScrollPhaseChange { _, newPhase in
            guard newPhase == .idle else { return }
            settle(items: items)
        }
        .accessibilityLabel(l.tr(
            zh: "房间滚轮",
            en: "Room dial",
            de: "Raumrad"
        ))
        .accessibilityAction(.escape) {
            collapse()
        }
    }

    private var wheelItems: [VerticalSolidHomePlantRoomDialWheelItem] {
        guard !options.isEmpty else { return [] }
        return (0 ..< 13).flatMap { cycle in
            options.indices.map { optionIndex in
                VerticalSolidHomePlantRoomDialWheelItem(
                    id: cycle * options.count + optionIndex,
                    cycle: cycle,
                    option: options[optionIndex]
                )
            }
        }
    }

    private func wheelButton(
        _ item: VerticalSolidHomePlantRoomDialWheelItem,
        isFocused: Bool
    ) -> some View {
        Button {
            commit(item.option)
            collapse()
        } label: {
            label(item.option, isFocused: isFocused)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(item.option, isSelected: isFocused))
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .accessibilityIdentifier("home-plants-room-edge-\(identifier(item.option.id))-\(item.cycle)")
        .accessibilityHidden(item.cycle != 6)
    }

    private func label(
        _ option: VerticalSolidHomePlantRoomDialOption,
        isFocused: Bool
    ) -> some View {
        VStack(spacing: 1) {
            Text(option.shortTitle)
                .font(OhanaFont.adaptive(size: option.shortTitle.count > 2 ? 9 : 12, weight: .black, design: .rounded))
                .foregroundStyle(isFocused ? Color.goPrimary : Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Text("\(option.count)")
                .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(isFocused ? Color.goPrimary.opacity(0.72) : Color.ohanaSecondaryText)
                .lineLimit(1)
        }
        .frame(width: 64, height: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(Color.goPrimary)
                .frame(width: 2, height: 24) // a11y: allow decorative selected-room indicator inside the 44pt dial target.
                .opacity(isFocused ? 1 : 0)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if option.dueCount > 0 {
                Circle()
                    .fill(Color.goYellow)
                    .frame(width: 7, height: 7) // a11y: allow decorative due dot inside the 44pt dial target.
                    .offset(x: -7, y: 6)
                    .accessibilityHidden(true)
            }
        }
    }

    private func expand() {
        scrollID = middleID(for: selectedRoomID)
        withAnimation(reduceMotion ? nil : GoMotion.quick) {
            isExpanded = true
        }
        OhanaFeedback.light()
    }

    private func collapse() {
        withAnimation(reduceMotion ? nil : GoMotion.quick) {
            isExpanded = false
        }
    }

    private func settle(items: [VerticalSolidHomePlantRoomDialWheelItem]) {
        guard
            let scrollID,
            let item = items.first(where: { $0.id == scrollID })
        else { return }

        commit(item.option)
        recenter(roomID: item.option.roomID)
    }

    private func commit(_ option: VerticalSolidHomePlantRoomDialOption) {
        guard selectedRoomID != option.roomID else { return }
        onSelect(option.roomID)
    }

    private func recenter(roomID: String?) {
        let centeredID = middleID(for: roomID)
        guard scrollID != centeredID else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollID = centeredID
        }
    }

    private func middleID(for roomID: String?) -> Int {
        let optionIndex = options.firstIndex(where: { $0.roomID == roomID }) ?? 0
        return 6 * options.count + optionIndex
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        guard
            !options.isEmpty,
            let currentIndex = options.firstIndex(where: { $0.roomID == selectedRoomID })
        else { return }

        let delta: Int
        switch direction {
        case .increment:
            delta = 1
        case .decrement:
            delta = -1
        @unknown default:
            return
        }

        let nextIndex = (currentIndex + delta + options.count) % options.count
        commit(options[nextIndex])
    }

    private func accessibilityLabel(
        _ option: VerticalSolidHomePlantRoomDialOption,
        isSelected: Bool
    ) -> String {
        let state = isSelected
            ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt")
            : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        let due = option.dueCount == 0
            ? l.tr(zh: "无到期任务", en: "no due tasks", de: "keine fälligen Aufgaben")
            : l.tr(zh: "\(option.dueCount) 项到期", en: "\(option.dueCount) due", de: "\(option.dueCount) fällig")
        return l.tr(
            zh: "\(option.title)，\(option.count) 株植物，\(due)，\(state)",
            en: "\(option.title), \(option.count) plants, \(due), \(state)",
            de: "\(option.title), \(option.count) Pflanzen, \(due), \(state)"
        )
    }

    static func shortTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        if trimmed.unicodeScalars.contains(where: { (0x4E00 ... 0x9FFF).contains(Int($0.value)) }) {
            return String(trimmed.prefix(2))
        }
        let words = trimmed
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)
        if words.count >= 2 {
            return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        }
        return String(trimmed.prefix(3)).uppercased()
    }

    private func identifier(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

private final class VerticalSolidHomePlantDeckScrollOffsetTracker {
    var offsetY: CGFloat = 0
}
