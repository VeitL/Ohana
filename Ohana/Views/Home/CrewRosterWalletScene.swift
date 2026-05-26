//
//  CrewRosterWalletScene.swift
//  Ohana
//
//  Wallet V2 style roster deck for Ohana members.
//

import SwiftUI

struct CrewRosterWalletScene<ExpandedInfo: View, CardOverlay: View>: View {
    private let sceneCoordinateSpace = "CrewRosterWalletSceneSpace"

    let cards: [FocusCard]
    let pets: [Pet]
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let selectedCardId: UUID?
    let progress: CGFloat
    let heroDirection: Int
    let reduceMotion: Bool
    let namespace: Namespace.ID
    let heroNamespace: Namespace.ID
    let avatarCacheRevision: Int
    let expandedInfo: (FocusCard) -> ExpandedInfo
    @ViewBuilder let cardOverlay: (FocusCard) -> CardOverlay
    let onSelect: (FocusCard) -> Void
    let onCollapse: () -> Void

    private var selectedCardIndex: Int? {
        selectedCardId.flatMap { selectedId in
            cards.firstIndex(where: { $0.id == selectedId })
        }
    }

    private var activeCard: FocusCard? {
        selectedCardId.flatMap { id in
            cards.first(where: { $0.id == id })
        }
    }

    private var isExpandedInteractionReady: Bool {
        selectedCardId != nil && progress > 0.985
    }

    var body: some View {
        GeometryReader { geo in
            let layout = WalletHeroLayout(
                size: geo.size,
                safeTop: safeTop,
                safeBottom: safeBottom,
                cardCount: cards.count,
                horizontalInset: 0,
                collapsedPeek: 44,
                collapsedBottomGap: 42,
                expandedTopOffset: 140,
                expandedHeightRatio: 0.43,
                expandedMinHeight: K.expandedCardH,
                expandedMaxHeight: K.expandedCardH,
                quickGap: K.expandedQuickModuleGap,
                quickHeight: 0
            )

            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isActive = card.id == selectedCardId
                    let frame = frame(for: card, index: index, layout: layout)
                    let walkTrackingPet = FocusHomeWalletCardContent.walkTrackingPet(for: card, isHero: isActive, pets: pets)

                    FocusHomeWalletCardContent(
                        card: card,
                        namespace: namespace,
                        heroNamespace: heroNamespace,
                        expandedId: selectedCardId,
                        isHeroExpanded: isActive,
                        heroProgress: isActive ? progress : 0,
                        avatarCacheRevision: avatarCacheRevision,
                        walkTrackingPet: walkTrackingPet,
                        usesMatchedGeometry: false
                    )
                    .overlay {
                        if isActive {
                            expandedInfo(card)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .opacity(Double(WalletHeroTimeline.smooth(progress, 0.26, 0.46)))
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect(inactiveScale(for: card, index: index))
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(opacity(for: card, index: index))
                    .zIndex(zIndex(index: index, isActive: isActive))
                    .contentShape(RoundedRectangle(cornerRadius: WalletHeroTimeline.cornerRadius(progress: isActive ? progress : 0), style: .continuous))
                    .allowsHitTesting(isActive && isExpandedInteractionReady)
                    .onTapGesture {
                        guard isActive, isExpandedInteractionReady, walkTrackingPet == nil else { return }
                        OhanaFeedback.light()
                        onCollapse()
                    }
                    .simultaneousGesture(collapseDragGesture(isEnabled: walkTrackingPet == nil))
                }

                if selectedCardId == nil {
                    collapsedHitZones(layout: layout)
                        .zIndex(70)
                }

                if isExpandedInteractionReady {
                    expandedCardHitZone(layout: layout)
                        .zIndex(80)
                }

                if selectedCardId == nil {
                    collapsedCardOverlays(layout: layout)
                        .zIndex(100)
                } else if isExpandedInteractionReady, let activeCard {
                    cardOverlayLayer(for: activeCard, frame: layout.expandedFrame)
                        .zIndex(100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: sceneCoordinateSpace)
        }
    }

    private func collapsedCardOverlays(layout: WalletHeroLayout) -> some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                cardOverlayLayer(for: card, frame: layout.collapsedFrame(index: index, count: cards.count))
            }
        }
    }

    private func cardOverlayLayer(for card: FocusCard, frame: CGRect) -> some View {
        cardOverlay(card)
            .frame(width: 104, height: 54, alignment: .topTrailing)
            .position(x: frame.maxX - 52, y: frame.minY + 27)
    }

    private func frame(for card: FocusCard, index: Int, layout: WalletHeroLayout) -> CGRect {
        let collapsed = layout.collapsedFrame(index: index, count: cards.count)
        if reduceMotion {
            return card.id == selectedCardId ? layout.expandedFrame : collapsed
        }

        guard card.id == selectedCardId else {
            return WalletHeroTimeline.inactiveFrame(
                from: collapsed,
                index: index,
                selectedIndex: selectedCardIndex,
                progress: progress,
                layout: layout,
                direction: heroDirection
            )
        }

        return WalletHeroTimeline.activeFrame(
            from: collapsed,
            to: layout.expandedFrame,
            progress: progress
        )
    }

    private func opacity(for card: FocusCard, index: Int) -> Double {
        guard selectedCardId != nil else { return 1 }
        if reduceMotion {
            return card.id == selectedCardId ? 1 : 0
        }
        if card.id == selectedCardId { return 1 }
        return WalletHeroTimeline.inactiveOpacity(
            index: index,
            selectedIndex: selectedCardIndex,
            progress: progress,
            direction: heroDirection
        )
    }

    private func inactiveScale(for card: FocusCard, index: Int) -> CGFloat {
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        if reduceMotion { return 1 }
        return WalletHeroTimeline.inactiveScale(
            index: index,
            selectedIndex: selectedCardIndex,
            progress: progress,
            direction: heroDirection
        )
    }

    private func zIndex(index: Int, isActive: Bool) -> Double {
        if isActive {
            return heroDirection < 0 ? Double(index) + 0.25 : 40
        }
        if selectedCardId != nil { return Double(index) }
        return Double(index)
    }

    private func collapsedHitZones(layout: WalletHeroLayout) -> some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let hitFrame = layout.collapsedHitFrame(index: index, count: cards.count)

                Rectangle()
                    .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible Wallet member hit zone
                    .contentShape(Rectangle())
                    .frame(width: hitFrame.width, height: hitFrame.height)
                    .position(x: hitFrame.midX, y: hitFrame.midY)
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                OhanaFeedback.medium()
                                onSelect(card)
                            }
                    )
                    .accessibilityLabel(card.name)
            }
        }
    }

    private func expandedCardHitZone(layout: WalletHeroLayout) -> some View {
        let frame = layout.expandedFrame
        return Button {
            OhanaFeedback.light()
            onCollapse()
        } label: {
            RoundedRectangle(cornerRadius: WalletHeroTimeline.cornerRadius(progress: progress), style: .continuous)
                .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible Wallet expanded member hit zone
                .frame(width: frame.width, height: frame.height)
        }
        .buttonStyle(.plain) // ui-v4: allow invisible Wallet expanded member hit zone
        .position(x: frame.midX, y: frame.midY)
        .simultaneousGesture(collapseDragGesture(isEnabled: true))
        .accessibilityLabel(activeCard?.name ?? "Expanded member card")
    }

    private func collapseDragGesture(isEnabled: Bool = true) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard isEnabled, selectedCardId != nil, value.translation.height > 80 else { return }
                OhanaFeedback.light()
                onCollapse()
            }
    }
}

struct CrewRosterWalletInfoOverlay: View {
    let card: FocusCard
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        if let status = card.statusBadgeText, !status.isEmpty {
                            infoChip(status, icon: card.statusBadgeIsWarning ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        }
                        infoChip(memberKindText, icon: memberKindIcon)
                    }

                    Text(card.personalityHint ?? secondaryIdentityText)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goCardWhite.opacity(0.82))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .shadow(color: Color.arkInk.opacity(0.35), radius: 6, y: 2) // ui-v4: allow readability shadow on image card
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 8) {
                    if card.coconutBalance > 0 || !card.isHuman {
                        metricChip(
                            title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokos"),
                            value: "\(card.coconutBalance)",
                            icon: "circle.hexagongrid.fill"
                        )
                    }
                    if card.streak > 0 {
                        metricChip(
                            title: l.tr(zh: "连击", en: "Streak", de: "Serie"),
                            value: "\(card.streak)",
                            icon: "flame.fill"
                        )
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(infoRows) { row in
                    compactInfoTile(row)
                }
            }
            .padding(.top, 12)
        }
    }

    private var memberKindText: String {
        if card.isHuman { return l.tr(zh: "人类", en: "Human", de: "Mensch") }
        if card.actions.contains(where: { $0.icon == "leaf.fill" }) { return l.tr(zh: "植物", en: "Plant", de: "Pflanze") }
        return l.tr(zh: "宠物", en: "Pet", de: "Tier")
    }

    private var memberKindIcon: String {
        if card.isHuman { return "person.fill" }
        if card.actions.contains(where: { $0.icon == "leaf.fill" }) { return "leaf.fill" }
        return "pawprint.fill"
    }

    private var secondaryIdentityText: String {
        if !card.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return card.breed
        }
        if let days = card.daysTogetherText, !days.isEmpty {
            return days
        }
        return card.kind
    }

    private var infoRows: [CrewRosterWalletInfoRow] {
        var rows: [CrewRosterWalletInfoRow] = []
        if let age = card.ageText, !age.isEmpty {
            rows.append(.init(title: l.tr(zh: "年龄", en: "Age", de: "Alter"), value: age, icon: "calendar"))
        }
        if let days = card.daysTogetherText, !days.isEmpty {
            rows.append(.init(title: l.tr(zh: "陪伴", en: "Together", de: "Zusammen"), value: days, icon: "heart.fill"))
        }
        if let gender = card.genderText, !gender.isEmpty {
            rows.append(.init(title: l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), value: gender, icon: "person.fill"))
        }
        if let zodiac = card.zodiacText, !zodiac.isEmpty {
            rows.append(.init(title: l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen"), value: zodiac, icon: "sparkles"))
        }
        if let mbti = card.mbtiText, !mbti.isEmpty {
            rows.append(.init(title: "MBTI", value: mbti, icon: "brain.head.profile"))
        }
        if !card.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(.init(title: l.tr(zh: "品种", en: "Breed", de: "Rasse"), value: card.breed, icon: "tag.fill"))
        }
        if rows.count < 4, !card.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(.init(title: l.tr(zh: "类型", en: "Type", de: "Typ"), value: card.kind, icon: memberKindIcon))
        }
        return Array(rows.prefix(4))
    }

    private func infoChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text(text)
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
        }
        .foregroundStyle(Color.goCardWhite)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.arkInk.opacity(0.34), in: Capsule())
    }

    private func metricChip(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
            VStack(alignment: .trailing, spacing: 0) {
                Text(value)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(title)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.goCardWhite.opacity(0.64))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.arkInk.opacity(0.36), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func compactInfoTile(_ row: CrewRosterWalletInfoRow) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.value)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.goCardWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(row.title)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.goCardWhite.opacity(0.62))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.arkInk.opacity(0.30), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CrewRosterWalletInfoRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}
