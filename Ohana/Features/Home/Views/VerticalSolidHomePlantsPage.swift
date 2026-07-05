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
    @Binding var hidesBottomChrome: Bool
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
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

    private var usesFullVisualEffects: Bool {
        workloadPolicy.visualEffectsBudget(isVisible: true).usesFullEffects
    }

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
                                updateBottomChromeVisibility(normalizedOffsetY)
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
            if hidesBottomChrome {
                hidesBottomChrome = false
            }
        }
        .accessibilityIdentifier("home-plants-page")
    }

    private var plantCards: [FocusCard] {
        visiblePlants.map { plant in
            FocusCard(
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
                statusBadgeText: plant.needsCare ? l.tr(zh: "待照护", en: "Care due", de: "Pflege fällig") : nil,
                statusBadgeIsWarning: plant.needsCare,
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

    private var roomRailButtonCount: Int {
        min(plantRoomSummaries.count, 7) + 1
    }

    private var roomRailHeight: CGFloat {
        railHeight(buttonCount: roomRailButtonCount)
    }

    private var viewSwitcherRailHeight: CGFloat {
        railHeight(buttonCount: VerticalSolidHomePlantViewStyle.allCases.count)
    }

    private func railHeight(buttonCount: Int) -> CGFloat {
        guard buttonCount > 0 else { return 0 }
        return 16 + CGFloat(buttonCount) * 44 + CGFloat(max(0, buttonCount - 1)) * 8
    }

    private func viewSwitcherCenterY(roomRailCenterY: CGFloat) -> CGFloat {
        guard showsRoomRail else { return roomRailCenterY }
        return max(56, roomRailCenterY - roomRailHeight / 2 - 10 - viewSwitcherRailHeight / 2)
    }

    @ViewBuilder
    private func plantDockQuickActions(for card: FocusCard) -> some View {
        if let plant = plantSnapshot(for: card) {
            PlantDockQuickActionsView(
                plantID: plant.id,
                plantName: plant.name,
                dueCareTypes: plantDueCareTypes(for: plant),
                localization: localization,
                quickActionItemsRaw: $plantQuickActionItemsRaw,
                shouldReduceWork: reduceMotion,
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
        VStack(spacing: 8) {
            ForEach(VerticalSolidHomePlantViewStyle.allCases) { style in
                plantViewSwitcherButton(style)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .background(roomRailBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-plants-view-switcher-rail")
    }

    private func plantViewSwitcherButton(_ style: VerticalSolidHomePlantViewStyle) -> some View {
        let isSelected = selectedViewStyle == style
        return Button {
            selectPlantViewStyle(style)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: style.icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .frame(height: 14)
                    .accessibilityHidden(true)
                Text(style.shortTitle(l))
                    .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk.opacity(0.74) : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(style.title(l))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("home-plants-view-\(style.rawValue)")
    }

    private var plantRoomRail: some View {
        VStack(spacing: 8) {
            plantRoomRailButton(
                id: "all",
                title: l.tr(zh: "全部", en: "All", de: "Alle"),
                shortTitle: l.tr(zh: "全", en: "All", de: "Alle"),
                count: plants.count,
                dueCount: plants.count(where: \.needsCare),
                isSelected: selectedRoomId == nil
            ) {
                selectRoom(nil)
            }

            ForEach(plantRoomSummaries.prefix(7)) { summary in
                plantRoomRailButton(
                    id: summary.id,
                    title: summary.title,
                    shortTitle: roomRailShortTitle(summary.title),
                    count: summary.plantCount,
                    dueCount: summary.dueCount,
                    isSelected: selectedRoomId == summary.id
                ) {
                    selectRoom(selectedRoomId == summary.id ? nil : summary.id)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .background(roomRailBackground)
        .opacity(showsRoomRail ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-plants-room-edge-rail")
    }

    private func plantRoomRailButton(
        id: String,
        title: String,
        shortTitle: String,
        count: Int,
        dueCount: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(shortTitle)
                    .font(OhanaFont.adaptive(size: shortTitle.count > 2 ? 9 : 11, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text("\(count)")
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.arkInk.opacity(0.72) : Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill.opacity(0.62), in: Circle())
            .overlay(alignment: .topTrailing) {
                if dueCount > 0 {
                    Circle()
                        .fill(Color.goYellow)
                        .frame(width: 9, height: 9) // a11y: allow decorative due dot inside the 44pt home plant room rail button
                        .overlay {
                            Circle().strokeBorder(Color.ohanaCardSurface.opacity(0.8), lineWidth: 1)
                        }
                        .offset(x: -5, y: 5)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(roomRailAccessibilityLabel(title: title, count: count, dueCount: dueCount, isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("home-plants-room-edge-\(roomRailIdentifier(id))")
    }

    @ViewBuilder
    private var roomRailBackground: some View {
        if usesFullVisualEffects && !reduceTransparency {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular.tint(roomRailGlassTint).interactive(true), in: Capsule()) // ui-v4: allow Liquid Glass room rail above plant cards
                .overlay(roomRailStroke)
                .shadow( // ui-v4: allow floating glass room rail depth
                    color: Color.arkInk.opacity(0.16),
                    radius: 16,
                    x: 0,
                    y: 8
                )
        } else {
            Capsule()
                .fill(Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.88 : 0.94))
                .overlay(roomRailStroke)
                .shadow( // ui-v4: allow reduced-mode room rail separation without Liquid Glass.
                    color: Color.arkInk.opacity(colorScheme == .dark ? 0.08 : 0.04),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        }
    }

    private var roomRailStroke: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.ohanaPrimaryText.opacity(colorScheme == .dark ? 0.18 : 0.14),
                        Color.ohanaSecondaryText.opacity(colorScheme == .dark ? 0.18 : 0.10),
                        Color.ohanaGlassStroke.opacity(usesFullVisualEffects ? 0.20 : 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var roomRailGlassTint: Color {
        if reduceTransparency {
            return Color.ohanaCardSurface.opacity(0.94)
        }
        return Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.34 : 0.42)
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
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, offsetY in
            updateBottomChromeVisibility(offsetY)
        }
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
        case .water:
            openPlantFeature(.water, plant: plant)
        case .fertilize:
            openPlantFeature(.fertilize, plant: plant)
        default:
            openPlantFeature(.log, plant: plant)
        }
    }

    private func plantDueCareTypes(for plant: VerticalSolidHomePlantSnapshot) -> Set<PlantCareType> {
        var types = Set<PlantCareType>()
        if plant.hasDueWatering {
            types.insert(.watering)
        }
        if plant.hasDueFertilizing {
            types.insert(.fertilizing)
        }
        return types
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

    private func updateBottomChromeVisibility(_ scrollOffset: CGFloat) {
        let next = VerticalSolidHomePlantScrollChromePolicy.hidesBottomChrome(
            scrollOffset: scrollOffset,
            currentHidden: hidesBottomChrome
        )
        guard next != hidesBottomChrome else { return }
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.quick) {
            hidesBottomChrome = next
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

    private func roomRailShortTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        if trimmed.unicodeScalars.contains(where: { (0x4E00 ... 0x9FFF).contains(Int($0.value)) }) {
            return String(trimmed.prefix(1))
        }
        let words = trimmed
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)
        if words.count >= 2 {
            return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        }
        return String(trimmed.prefix(3)).uppercased()
    }

    private func roomRailIdentifier(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private func roomRailAccessibilityLabel(
        title: String,
        count: Int,
        dueCount: Int,
        isSelected: Bool
    ) -> String {
        let state = isSelected ? l.tr(zh: "已选择", en: "selected", de: "ausgewählt") : l.tr(zh: "未选择", en: "not selected", de: "nicht ausgewählt")
        let due = dueCount == 0
            ? l.tr(zh: "无到期任务", en: "no due tasks", de: "keine fälligen Aufgaben")
            : l.tr(zh: "\(dueCount) 项到期", en: "\(dueCount) due", de: "\(dueCount) fällig")
        return l.tr(
            zh: "\(title)，\(count) 株植物，\(due)，\(state)",
            en: "\(title), \(count) plants, \(due), \(state)",
            de: "\(title), \(count) Pflanzen, \(due), \(state)"
        )
    }
}

private final class VerticalSolidHomePlantDeckScrollOffsetTracker {
    var offsetY: CGFloat = 0
}
