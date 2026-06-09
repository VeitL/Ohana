//
//  CrewRosterWalletScene.swift
//  Ohana
//
//  Wallet V2 style roster deck for Ohana members.
//

import SwiftUI

struct CrewRosterWalletScene<CardOverlay: View, MemberContent: View>: View {
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
    let editingCardId: UUID?
    let editorProgress: CGFloat
    let isEditorContentMounted: Bool
    @ViewBuilder let cardOverlay: (FocusCard) -> CardOverlay
    @ViewBuilder let memberContent: (FocusCard, CGFloat, Bool) -> MemberContent
    let onSelect: (FocusCard) -> Void
    let onCollapse: () -> Void
    let onOpenEditor: (FocusCard) -> Void
    let onCloseEditor: () -> Void
    @AppStorage("shop_equip_fx_lime_glow") private var equipFxLimeGlow = false
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard = true

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

    private var isEditorActive: Bool {
        guard let selectedCardId, let editingCardId else { return false }
        return selectedCardId == editingCardId
    }

    private var isEditorInteractionReady: Bool {
        isEditorActive && editorProgress > 0.985 && isEditorContentMounted
    }

    var body: some View {
        GeometryReader { geo in
            let expandedCardHeight = min(430, max(K.expandedCardH + 36, geo.size.height - 156))
            let expandedTopOffset = max(72, min(108, geo.size.height * 0.13))
            let layout = WalletHeroLayout(
                size: geo.size,
                safeTop: safeTop,
                safeBottom: safeBottom,
                cardCount: cards.count,
                horizontalInset: 0,
                collapsedPeek: 44,
                collapsedBottomGap: 42,
                expandedTopOffset: expandedTopOffset,
                expandedHeightRatio: 0.58,
                expandedMinHeight: expandedCardHeight,
                expandedMaxHeight: expandedCardHeight,
                quickGap: K.expandedQuickModuleGap,
                quickHeight: 0
            )
            let editorFrame = editorFrame(in: geo.size, baseFrame: layout.expandedFrame)

            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isActive = card.id == selectedCardId
                    let frame = frame(for: card, index: index, layout: layout, editorFrame: editorFrame)
                    let walkTrackingPet = FocusHomeWalletCardContent.walkTrackingPet(for: card, isHero: isActive, pets: pets)
                    let cardEditorProgress = isActive && card.id == editingCardId ? editorProgress : 0
                    let cardCornerRadius = cardCornerRadius(for: card, editorProgress: cardEditorProgress)
                    let isCardEditorMounted = card.id == editingCardId && isEditorContentMounted

                    FocusHomeWalletCardContent(
                        card: card,
                        namespace: namespace,
                        heroNamespace: heroNamespace,
                        expandedId: selectedCardId,
                        isHeroExpanded: isActive,
                        heroProgress: isActive ? progress : 0,
                        avatarCacheRevision: avatarCacheRevision,
                        walkTrackingPet: walkTrackingPet,
                        usesMatchedGeometry: false,
                        reduceMotion: reduceMotion,
                        presentation: .rosterMember,
                        expandedCardHeight: card.id == editingCardId ? frame.height : layout.expandedHeight,
                        cardCornerRadius: cardCornerRadius,
                        equipFxLimeGlow: equipFxLimeGlow,
                        equipFxPopoutCard: equipFxPopoutCard
                    )
                    .overlay {
                        if isActive {
                            memberContent(card, WalletHeroTimeline.smooth(cardEditorProgress), isCardEditorMounted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .opacity(Double(WalletHeroTimeline.smooth(progress, 0.26, 0.46)))
                            .allowsHitTesting(isEditorInteractionReady)
                            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                        }
                    }
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect(inactiveScale(for: card, index: index))
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(opacity(for: card, index: index))
                    .zIndex(zIndex(index: index, isActive: isActive))
                    .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                    .allowsHitTesting(isActive && isExpandedInteractionReady)
                    .onTapGesture {
                        guard !isEditorActive, isActive, isExpandedInteractionReady, walkTrackingPet == nil else { return }
                        OhanaFeedback.light()
                        onCollapse()
                    }
                    .simultaneousGesture(collapseDragGesture(isEnabled: walkTrackingPet == nil && !isEditorActive))
                }

                if selectedCardId == nil {
                    collapsedHitZones(layout: layout)
                        .zIndex(70)
                }

                if isExpandedInteractionReady && !isEditorActive {
                    expandedCardHitZone(layout: layout)
                        .zIndex(80)
                }

                homeVisibilityOverlayLayer(layout: layout, editorFrame: editorFrame)
                    .zIndex(100)

                if isExpandedInteractionReady, let activeCard, !isEditorActive {
                    expandedDetailPullIndicator(for: activeCard, frame: layout.expandedFrame)
                        .zIndex(120)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: sceneCoordinateSpace)
        }
    }

    private enum OverlayPlacement {
        case collapsed
        case expandedLeading
    }

    private func homeVisibilityOverlayLayer(layout: WalletHeroLayout, editorFrame: CGRect) -> some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if shouldShowCardOverlay(for: card) {
                    let frame = frame(for: card, index: index, layout: layout, editorFrame: editorFrame)
                    cardOverlayLayer(for: card, frame: frame)
                        .opacity(opacity(for: card, index: index) * cardOverlayOpacity(for: card))
                        .allowsHitTesting(cardOverlayAllowsHitTesting(for: card))
                }
            }
        }
    }

    private func shouldShowCardOverlay(for card: FocusCard) -> Bool {
        guard !isEditorActive else { return false }
        guard let selectedCardId else { return true }
        return card.id == selectedCardId
    }

    private func cardOverlayOpacity(for card: FocusCard) -> Double {
        guard selectedCardId != nil else { return 1 }
        guard card.id == selectedCardId else { return 0 }
        return Double(WalletHeroTimeline.smooth(progress, 0.04, 0.18))
    }

    private func cardOverlayAllowsHitTesting(for card: FocusCard) -> Bool {
        guard selectedCardId != nil else { return true }
        return card.id == selectedCardId && isExpandedInteractionReady
    }

    private func cardOverlayLayer(
        for card: FocusCard,
        frame: CGRect,
        placement: OverlayPlacement = .collapsed
    ) -> some View {
        let overlayWidth: CGFloat = 66
        let overlayHeight: CGFloat = 44
        let sideInset: CGFloat = placement == .collapsed ? 13 : 16
        let topInset: CGFloat = selectedCardId == nil ? 8 : 16
        let x = frame.maxX - sideInset - overlayWidth / 2

        return cardOverlay(card)
            .frame(width: overlayWidth, height: overlayHeight, alignment: .center)
            .position(
                x: x,
                y: frame.minY + topInset + overlayHeight / 2
            )
    }

    private func expandedDetailPullIndicator(for card: FocusCard, frame: CGRect) -> some View {
        VStack(spacing: 7) {
            Capsule()
                .fill(Color.goCardWhite.opacity(0.68))
                .frame(width: 48, height: 5)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.goCardWhite.opacity(0.20), lineWidth: 0.75)
                )
                .shadow(color: Color.arkInk.opacity(0.28), radius: 6, y: 2) // ui-v4: allow readability shadow on image card

            Image(systemName: "chevron.down").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.goCardWhite.opacity(0.72))
                .shadow(color: Color.arkInk.opacity(0.30), radius: 5, y: 2) // ui-v4: allow readability shadow on image card
        }
        .frame(width: 112, height: 54)
        .contentShape(Rectangle())
        .position(x: frame.midX, y: frame.maxY - 28)
        .highPriorityGesture(
            TapGesture()
                .onEnded { openExpandedDetail(card) }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onEnded { value in
                    guard value.translation.height > 24 else { return }
                    openExpandedDetail(card)
                }
        )
        .accessibilityLabel("展开全部信息")
        .accessibilityHint("向下拉动或点击以展开")
    }

    private func openExpandedDetail(_ card: FocusCard) {
        onOpenEditor(card)
    }

    private func editorFrame(in size: CGSize, baseFrame: CGRect) -> CGRect {
        let top: CGFloat = 4
        let bottom: CGFloat = 8
        let height = max(baseFrame.height, size.height - top - bottom)
        return CGRect(
            x: baseFrame.minX,
            y: top,
            width: baseFrame.width,
            height: height
        )
    }

    private func cardCornerRadius(for card: FocusCard, editorProgress: CGFloat) -> CGFloat {
        guard card.id == editingCardId else { return HeroAnim.stackCardCorner }
        return WalletHeroTimeline.lerp(
            HeroAnim.stackCardCorner,
            30,
            WalletHeroTimeline.smooth(editorProgress, 0.12, 0.72)
        )
    }

    private func frame(for card: FocusCard, index: Int, layout: WalletHeroLayout, editorFrame: CGRect) -> CGRect {
        let collapsed = layout.collapsedFrame(index: index, count: cards.count)
        let baseFrame: CGRect
        if reduceMotion {
            baseFrame = card.id == selectedCardId ? layout.expandedFrame : collapsed
        } else if card.id == selectedCardId {
            baseFrame = WalletHeroTimeline.activeFrame(
                from: collapsed,
                to: layout.expandedFrame,
                progress: progress
            )
        } else {
            baseFrame = WalletHeroTimeline.inactiveFrame(
                from: collapsed,
                index: index,
                selectedIndex: selectedCardIndex,
                progress: progress,
                layout: layout,
                direction: heroDirection
            )
        }

        guard card.id == editingCardId else { return baseFrame }
        if reduceMotion {
            return editorProgress > 0.5 ? editorFrame : baseFrame
        }
        return WalletHeroTimeline.interpolate(
            from: baseFrame,
            to: editorFrame,
            progress: WalletHeroTimeline.smooth(editorProgress)
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
                guard isEnabled, selectedCardId != nil, value.translation.height < -80 else { return }
                OhanaFeedback.light()
                onCollapse()
            }
    }
}

enum CrewRosterProfileContinuityMetrics {
    static let horizontalInset: CGFloat = 18
    static let summaryTopInset: CGFloat = 178
    static let summaryDetailGap: CGFloat = 12
}

struct CrewRosterProfileSummarySnapshot: Equatable {
    let memberKindText: String
    let memberKindIcon: String
    let statusText: String?
    let statusIcon: String
    let eyebrow: String
    let summaryText: String
    let metrics: [CrewRosterProfileSummaryMetric]
    let rows: [CrewRosterProfileSummaryRow]

    static func make(card: FocusCard, l: L10n) -> CrewRosterProfileSummarySnapshot {
        let memberKindIcon: String
        let memberKindText: String
        if card.isHuman {
            memberKindIcon = "person.fill"
            memberKindText = l.tr(zh: "人类", en: "Human", de: "Mensch")
        } else if card.actions.contains(where: { $0.icon == "leaf.fill" }) {
            memberKindIcon = "leaf.fill"
            memberKindText = l.tr(zh: "植物", en: "Plant", de: "Pflanze")
        } else {
            memberKindIcon = "pawprint.fill"
            memberKindText = l.tr(zh: "宠物", en: "Pet", de: "Tier")
        }

        var metrics: [CrewRosterProfileSummaryMetric] = []
        if card.coconutBalance > 0 || !card.isHuman {
            metrics.append(.init(
                id: "coconuts",
                title: l.tr(zh: "椰子", en: "Coconuts", de: "Kokos"),
                value: "\(card.coconutBalance)",
                icon: "circle.hexagongrid.fill"
            ))
        }
        if card.streak > 0 {
            metrics.append(.init(
                id: "streak",
                title: l.tr(zh: "连击", en: "Streak", de: "Serie"),
                value: "\(card.streak)",
                icon: "flame.fill"
            ))
        }

        var rows: [CrewRosterProfileSummaryRow] = []
        if let age = card.ageText, !age.isEmpty {
            rows.append(.init(id: "age", title: l.tr(zh: "年龄", en: "Age", de: "Alter"), value: age, icon: "calendar"))
        }
        if let days = card.daysTogetherText, !days.isEmpty {
            rows.append(.init(id: "together", title: l.tr(zh: "陪伴", en: "Together", de: "Zusammen"), value: days, icon: "heart.fill"))
        }
        if let gender = card.genderText, !gender.isEmpty {
            rows.append(.init(id: "gender", title: l.tr(zh: "性别", en: "Gender", de: "Geschlecht"), value: gender, icon: "person.fill"))
        }
        if let zodiac = card.zodiacText, !zodiac.isEmpty {
            rows.append(.init(id: "zodiac", title: l.tr(zh: "星座", en: "Zodiac", de: "Sternzeichen"), value: zodiac, icon: "sparkles"))
        }
        if let mbti = card.mbtiText, !mbti.isEmpty {
            rows.append(.init(id: "mbti", title: "MBTI", value: mbti, icon: "brain.head.profile"))
        }
        if !card.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(.init(id: "breed", title: l.tr(zh: "品种", en: "Breed", de: "Rasse"), value: card.breed, icon: "tag.fill"))
        }
        if rows.count < 4, !card.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(.init(id: "type", title: l.tr(zh: "类型", en: "Type", de: "Typ"), value: card.kind, icon: memberKindIcon))
        }

        let statusText = card.statusBadgeText?.trimmingCharacters(in: .whitespacesAndNewlines)

        return .init(
            memberKindText: memberKindText,
            memberKindIcon: memberKindIcon,
            statusText: statusText?.isEmpty == false ? statusText : nil,
            statusIcon: card.statusBadgeIsWarning ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
            eyebrow: l.tr(zh: "基本信息", en: "Profile", de: "Profil"),
            summaryText: card.personalityHint ?? secondaryIdentityText(for: card),
            metrics: metrics,
            rows: Array(rows.prefix(4))
        )
    }

    private static func secondaryIdentityText(for card: FocusCard) -> String {
        if !card.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return card.breed
        }
        if let days = card.daysTogetherText, !days.isEmpty {
            return days
        }
        return card.kind
    }
}

struct CrewRosterProfileSummaryMetric: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let icon: String
}

struct CrewRosterProfileSummaryRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
    let icon: String
}

struct CrewRosterProfileSummaryHeader: View {
    let snapshot: CrewRosterProfileSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                inlineFact(snapshot.memberKindText, icon: snapshot.memberKindIcon)
                if let status = snapshot.statusText {
                    inlineFact(status, icon: snapshot.statusIcon)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.eyebrow)
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goCardWhite.opacity(0.64))
                        .textCase(.uppercase)
                    Text(snapshot.summaryText)
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.goCardWhite.opacity(0.84))
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                }
                .shadow(color: Color.arkInk.opacity(0.34), radius: 6, y: 2) // ui-v4: allow readability shadow on image card

                Spacer(minLength: 8)

                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(snapshot.metrics) { metric in
                        plainMetric(metric)
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 9) {
                ForEach(snapshot.rows) { row in
                    compactInfoTile(row)
                }
            }
        }
    }

    private func inlineFact(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 10, weight: .black))
            Text(text)
                .font(OhanaFont.caption2(.black))
                .lineLimit(1)
        }
        .foregroundStyle(Color.goCardWhite.opacity(0.78))
        .shadow(color: Color.arkInk.opacity(0.30), radius: 5, y: 2) // ui-v4: allow text readability shadow on image card
    }

    private func plainMetric(_ metric: CrewRosterProfileSummaryMetric) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: metric.icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(metric.value)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.goCardWhite)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
            Text(metric.title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.goCardWhite.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .shadow(color: Color.arkInk.opacity(0.32), radius: 6, y: 2) // ui-v4: allow text readability shadow on image card
    }

    private func compactInfoTile(_ row: CrewRosterProfileSummaryRow) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
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
        .shadow(color: Color.arkInk.opacity(0.30), radius: 5, y: 2) // ui-v4: allow text readability shadow on image card
    }
}

struct CrewRosterWalletInfoOverlay: View {
    let card: FocusCard
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        CrewRosterProfileSummaryHeader(snapshot: .make(card: card, l: l))
    }
}
