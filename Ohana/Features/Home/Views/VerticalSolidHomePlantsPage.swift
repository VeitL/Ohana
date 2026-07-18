//
//  VerticalSolidHomePlantsPage.swift
//  Ohana
//
//  Plant page surface for the vertical solid home shell.
//

import Foundation
import SwiftData
import SwiftUI

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
    @State private var selectedViewStyle: VerticalSolidHomePlantViewStyle = .roomStacks
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
            let selectedRoomCardViewportHeight = VerticalSolidHomePlantWalletScrollPolicy.selectedRoomCardViewportHeight(
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
                    if selectedRoomId != nil {
                        plantDeckView(
                            cardViewportHeight: selectedRoomCardViewportHeight,
                            bottomChromeHeight: bottomChromeHeight
                        )
                    } else if selectedViewStyle == .roomStacks {
                        plantRoomStackOverview(
                            containerWidth: proxy.size.width,
                            bottomChromeHeight: bottomChromeHeight
                        )
                    } else {
                        plantAllRoomsExpandedView(
                            containerWidth: proxy.size.width,
                            bottomChromeHeight: bottomChromeHeight
                        )
                    }

                    if showsPlantViewToggle {
                        plantExpandAllButton
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.top, 12)
                            .padding(.trailing, 16)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .zIndex(31)
                            .accessibilityIdentifier(plantViewToggleIdentifier)
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
                            .padding(.leading, 16)
                            .padding(.trailing, showsPlantViewToggle ? 116 : 16)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-plants-page")
    }

    private var plantCards: [FocusCard] {
        visiblePlants.map { plantCard(for: $0) }
    }

    private func plantCard(for plant: VerticalSolidHomePlantSnapshot) -> FocusCard {
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

    private var visiblePlants: [VerticalSolidHomePlantSnapshot] {
        guard let selectedRoomId else { return plants }
        return plants.filter { roomIdentifier(for: $0) == selectedRoomId }
    }

    private var dueCarePlantCount: Int {
        plants.count(where: \.needsCare)
    }

    private var showsDueCareBanner: Bool {
        dueCarePlantCount > 0 &&
            selectedRoomId == nil &&
            selectedCardId == nil &&
            heroDirection == 0
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
        plantRoomGroups.map(\.summary)
    }

    private var plantRoomGroups: [VerticalSolidHomePlantRoomGroup] {
        Dictionary(grouping: plants, by: roomIdentifier(for:))
            .map { id, roomPlants in
                let sortedPlants = roomPlants.sorted { lhs, rhs in
                    if lhs.needsCare != rhs.needsCare {
                        return lhs.needsCare && !rhs.needsCare
                    }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return VerticalSolidHomePlantRoomGroup(
                    summary: VerticalSolidHomePlantRoomSummary(
                        id: id,
                        title: roomTitle(for: sortedPlants.first),
                        plantCount: sortedPlants.count,
                        dueCount: sortedPlants.count(where: \.needsCare)
                    ),
                    plants: sortedPlants
                )
            }
            .sorted { lhs, rhs in
                if lhs.summary.dueCount != rhs.summary.dueCount {
                    return lhs.summary.dueCount > rhs.summary.dueCount
                }
                if lhs.summary.plantCount != rhs.summary.plantCount {
                    return lhs.summary.plantCount > rhs.summary.plantCount
                }
                return lhs.summary.title.localizedStandardCompare(rhs.summary.title) == .orderedAscending
            }
    }

    private var showsRoomRail: Bool {
        selectedRoomId != nil &&
            VerticalSolidHomePlantRoomRailPolicy.shouldShow(
            plantCount: plants.count,
            selectedCardId: selectedCardId,
            heroDirection: heroDirection
        )
    }

    private var showsPlantViewToggle: Bool {
        !plants.isEmpty &&
            selectedRoomId == nil &&
            selectedCardId == nil &&
            heroDirection == 0
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

    private var plantExpandAllButton: some View {
        Button {
            selectPlantViewStyle(selectedViewStyle.toggled)
        } label: {
            Label(
                selectedViewStyle.toggleTitle(l),
                systemImage: selectedViewStyle.toggleIcon
            )
            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minWidth: 92, minHeight: 50)
            .background(Color.ohanaCardSurface.opacity(0.96), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.ohanaGlassStroke.opacity(0.62), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(selectedViewStyle.toggleTitle(l))
    }

    private var plantViewToggleIdentifier: String {
        selectedViewStyle == .roomStacks
            ? "home-plants-expand-all"
            : "home-plants-collapse-all"
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

    private func plantRoomStackOverview(
        containerWidth: CGFloat,
        bottomChromeHeight: CGFloat
    ) -> some View {
        let roomGroups = plantRoomGroups
        let cellWidth = VerticalSolidHomePlantRoomStackLayout.gridCellWidth(
            containerWidth: containerWidth
        )
        let columns = Array(
            repeating: GridItem(
                .flexible(minimum: 0),
                spacing: VerticalSolidHomePlantRoomStackLayout.overviewSpacing
            ),
            count: VerticalSolidHomePlantRoomStackLayout.overviewColumnCount
        )

        return ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(
                columns: columns,
                spacing: VerticalSolidHomePlantRoomStackLayout.overviewSpacing
            ) {
                ForEach(roomGroups) { group in
                    VerticalSolidHomePlantRoomStack(
                        summary: group.summary,
                        cards: group.plants.map { plantCard(for: $0) },
                        containerWidth: cellWidth,
                        localization: localization,
                        reduceMotion: reduceMotion,
                        avatarCacheRevision: plantAvatarCacheRevision,
                        onOpen: { selectRoom(group.id) }
                    )
                }
            }
            .padding(.horizontal, VerticalSolidHomePlantRoomStackLayout.overviewHorizontalPadding)
            .padding(.top, VerticalSolidHomePlantRoomStackLayout.overviewTopInset)
            .padding(
                .bottom,
                bottomChromeHeight + VerticalSolidHomePlantRoomStackLayout.overviewBottomInset
            )
            .accessibilityIdentifier("home-plants-room-stack-overview")
        }
        .scrollBounceBehavior(.basedOnSize)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
    }

    private func plantDeckView(
        cardViewportHeight: CGFloat,
        bottomChromeHeight: CGFloat
    ) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: VerticalSolidHomePlantWalletScrollPolicy.sectionSpacing) {
                    if let selectedRoomSummary {
                        selectedRoomDeckHeader(selectedRoomSummary)
                            .id(selectedRoomHeaderID)
                    }

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
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
    }

    private var selectedRoomSummary: VerticalSolidHomePlantRoomSummary? {
        guard let selectedRoomId else { return nil }
        return plantRoomSummaries.first { $0.id == selectedRoomId }
    }

    private var selectedRoomHeaderID: String {
        "home-plants-selected-room-header"
    }

    private func selectedRoomDeckHeader(_ summary: VerticalSolidHomePlantRoomSummary) -> some View {
        HStack(spacing: 10) {
            Button {
                selectRoom(nil)
            } label: {
                Image(systemName: "chevron.left") // a11y: allow parent Button supplies the localized back label
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .frame(width: 42, height: 42)
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(
                zh: "返回房间卡片堆",
                en: "Back to room card stacks",
                de: "Zurück zu den Raumkartenstapeln"
            ))
            .accessibilityIdentifier("home-plants-room-stack-close")

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(l.tr(
                    zh: "\(summary.plantCount) 株植物",
                    en: "\(summary.plantCount) plants",
                    de: "\(summary.plantCount) Pflanzen"
                ))
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 4)

            if summary.dueCount > 0 {
                Label("\(summary.dueCount)", systemImage: "calendar.badge.clock")
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(Color.goYellow, in: Capsule())
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(
            maxWidth: .infinity,
            minHeight: VerticalSolidHomePlantWalletScrollPolicy.selectedRoomHeaderHeight
        )
        .background(Color.ohanaCardSurface.opacity(0.95), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.ohanaGlassStroke.opacity(0.58), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.trailing, 50)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-plants-selected-room-header")
    }

    private func plantAllRoomsExpandedView(
        containerWidth: CGFloat,
        bottomChromeHeight: CGFloat
    ) -> some View {
        let roomGroups = plantRoomGroups
        let columns = Array(
            repeating: GridItem(
                .flexible(minimum: 0),
                spacing: VerticalSolidHomePlantExpandedGridLayout.columnSpacing
            ),
            count: VerticalSolidHomePlantExpandedGridLayout.columnCount(
                containerWidth: containerWidth
            )
        )

        return ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(
                alignment: .leading,
                spacing: VerticalSolidHomePlantExpandedGridLayout.roomSpacing
            ) {
                ForEach(roomGroups) { group in
                    plantAllExpandedRoomSection(group, columns: columns)
                }
            }
            .padding(.horizontal, VerticalSolidHomePlantExpandedGridLayout.horizontalPadding)
            .padding(.top, VerticalSolidHomePlantExpandedGridLayout.topInset)
            .padding(
                .bottom,
                bottomChromeHeight + VerticalSolidHomePlantExpandedGridLayout.bottomInset
            )
            .accessibilityIdentifier("home-plants-all-expanded-view")
        }
        .scrollBounceBehavior(.basedOnSize)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private func plantAllExpandedRoomSection(
        _ group: VerticalSolidHomePlantRoomGroup,
        columns: [GridItem]
    ) -> some View {
        let summary = group.summary

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.title)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("\(summary.plantCount)")
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 22)
                    .background(Color.goPrimary, in: Capsule())

                Spacer(minLength: 4)

                if summary.dueCount > 0 {
                    Label("\(summary.dueCount)", systemImage: "calendar.badge.clock")
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
            }

            LazyVGrid(
                columns: columns,
                spacing: VerticalSolidHomePlantExpandedGridLayout.rowSpacing
            ) {
                ForEach(group.plants) { plant in
                    plantAllExpandedCard(plant)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "home-plants-all-expanded-room-\(roomRailIdentifier(summary.id))"
        )
    }

    private func plantAllExpandedCard(_ plant: VerticalSolidHomePlantSnapshot) -> some View {
        GeometryReader { proxy in
            Button {
                onOpenPlant(plant)
            } label: {
                VerticalSolidHomePlantCompactCardSurface(
                    card: plantCard(for: plant),
                    displayWidth: proxy.size.width,
                    reduceMotion: reduceMotion,
                    localization: localization,
                    avatarCacheRevision: plantAvatarCacheRevision
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel([
                plant.name,
                plant.careDifficultyText,
                plant.attentionText,
                plant.todoText
            ].joined(separator: ", "))
            .accessibilityIdentifier("home-plants-all-expanded-card-\(plant.id.uuidString)")
        }
        .aspectRatio(
            1 / FocusHomeVerticalSolidCollapsedLayoutPolicy.cardAspectRatio,
            contentMode: .fit
        )
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
            selectedRoomId = nil
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
        let targetID = selectedRoomId == nil ? firstSectionId : selectedRoomHeaderID
        OhanaFrameScheduler.runAfterNextFrame {
            withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
                proxy.scrollTo(targetID, anchor: .top)
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
