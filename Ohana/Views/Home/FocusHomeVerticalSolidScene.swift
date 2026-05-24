//
//  FocusHomeVerticalSolidScene.swift
//  Ohana
//
//  Real-data portrait solid card scene for the selectable home style.
//

import SwiftUI
import UIKit

struct FocusHomeVerticalSolidScene<QuickActions: View, ContextMenuContent: View>: View {
    let cards: [FocusCard]
    let pets: [Pet]
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let selectedCardId: UUID?
    let progress: CGFloat
    let reduceMotion: Bool
    var isVisible: Bool = true
    var embedsQuickActionsInCard: Bool = false
    var collapsedTopInset: CGFloat = 0
    let quickActions: (FocusCard) -> QuickActions
    let contextMenu: (FocusCard) -> ContextMenuContent
    let onSelect: (FocusCard) -> Void
    let onCollapse: () -> Void
    let onLongPress: (FocusCard) -> Void

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var floatingPhase = false
    @State private var frozenAvatarSources: [UUID: FocusHomeFrozenAvatarSource] = [:]
    @GestureState private var expandedDragY: CGFloat = 0

    private var selectedCard: FocusCard? {
        selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }
    }

    private var isExpandedInteractionReady: Bool {
        selectedCardId != nil && progress > 0.985
    }

    var body: some View {
        GeometryReader { geo in
            let visibleCenterX = visibleCenterX(in: geo)
            ZStack {
                if selectedCardId == nil {
                    collapsedHitLayer(in: geo.size)
                        .zIndex(100)
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onCollapse() }
                        .zIndex(1)
                }

                if let selectedCard {
                    if walkTrackingPet(for: selectedCard, isSelected: true) == nil {
                        quickActionLayer(for: selectedCard, in: geo.size, visibleCenterX: visibleCenterX)
                            .zIndex(embedsQuickActionsInCard ? 48 : 32)
                    }
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    cardLayer(for: card, index: index, in: geo.size, visibleCenterX: visibleCenterX)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                updateFloatingEffect()
                syncFrozenAvatarSource(for: selectedCardId)
            }
            .onChange(of: canFloatCards) { _, _ in
                updateFloatingEffect()
            }
            .onChange(of: selectedCardId) { _, newValue in
                syncFrozenAvatarSource(for: newValue)
            }
            .onChange(of: progress) { _, _ in
                clearFrozenAvatarSourcesIfIdle()
            }
        }
    }

    private func visibleCenterX(in geo: GeometryProxy) -> CGFloat {
        geo.size.width / 2
    }

    private func cardLayer(for card: FocusCard, index: Int, in size: CGSize, visibleCenterX: CGFloat) -> some View {
        let isSelected = card.id == selectedCardId
        let walkTrackingPet = walkTrackingPet(for: card, isSelected: isSelected)
        let frame = frame(for: card, index: index, in: size, visibleCenterX: visibleCenterX)
        let dragY = isSelected ? max(0, expandedDragY) : 0
        let floating = floatingTransform(index: index, isSelected: isSelected)
        let rotation = rotation(for: index, isSelected: isSelected) + floating.rotation
        let scale = isSelected ? max(0.95, 1 - dragY / 1500) : inactiveScale(for: card)
        let opacity = inactiveOpacity(for: card)
        let zIndex = isSelected ? Double(40) : Double(index + 2)
        let cornerRadius = isSelected ? CGFloat(42) : CGFloat(30)
        let frozenAvatarSource = isSelected
            ? frozenAvatarSources[card.id] ?? FocusHomeFrozenAvatarSource.make(for: card)
            : nil

        return ZStack {
            FocusHomeVerticalSolidCardSurface(
                card: card,
                isExpanded: isSelected,
                progress: isSelected ? progress : 0,
                reduceMotion: reduceMotion,
                frozenAvatarSource: frozenAvatarSource
            )
            .opacity(walkTrackingPet == nil ? 1 : 0)

            if let walkTrackingPet {
                WalkTrackingCard(pet: walkTrackingPet)
                    .padding(10)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .center).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(width: frame.width, height: frame.height)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
        .opacity(opacity)
        .position(x: frame.midX + floating.x, y: frame.midY + dragY + floating.y)
        .zIndex(zIndex)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contextMenu { contextMenu(card) }
        .onTapGesture {
            guard walkTrackingPet == nil else { return }
            handleCardTap(isSelected: isSelected)
        }
        .onLongPressGesture {
            handleCardLongPress(card, isSelected: isSelected)
        }
        .simultaneousGesture(collapseDragGesture(isEnabled: isSelected && walkTrackingPet == nil))
        .allowsHitTesting(isSelected)
        .animation(HeroAnim.walletSpring, value: walkTrackingPet?.id)
    }

    private func walkTrackingPet(for card: FocusCard, isSelected: Bool) -> Pet? {
        FocusHomeWalletCardContent.walkTrackingPet(for: card, isHero: isSelected, pets: pets)
    }

    private func handleCardTap(isSelected: Bool) {
        guard isSelected else { return }
        onCollapse()
    }

    private func handleCardLongPress(_ card: FocusCard, isSelected: Bool) {
        guard isSelected else { return }
        onLongPress(card)
    }

    private var canFloatCards: Bool {
        selectedCardId == nil && workloadPolicy.ambientMotionBudget(isVisible: isVisible) == .full
    }

    private var floatingAnimation: Animation {
        .easeInOut(duration: 3.6).repeatForever(autoreverses: true)
    }

    private func updateFloatingEffect() {
        guard canFloatCards else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                floatingPhase = false
            }
            return
        }
        guard !floatingPhase else { return }
        withAnimation(floatingAnimation) {
            floatingPhase = true
        }
    }

    private func syncFrozenAvatarSource(for selectedId: UUID?) {
        guard let selectedId,
              let card = cards.first(where: { $0.id == selectedId }) else {
            clearFrozenAvatarSourcesIfIdle()
            return
        }

        guard frozenAvatarSources[selectedId] == nil else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            frozenAvatarSources = [selectedId: FocusHomeFrozenAvatarSource.make(for: card)]
        }
    }

    private func clearFrozenAvatarSourcesIfIdle() {
        guard selectedCardId == nil,
              progress <= 0.001,
              !frozenAvatarSources.isEmpty else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            frozenAvatarSources.removeAll()
        }
    }

    private func quickActionLayer(for card: FocusCard, in size: CGSize, visibleCenterX: CGFloat) -> some View {
        let frame = expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX)
        let reveal = reduceMotion ? 1 : smooth(progress, 0.42, 0.72)
        let quickHeight = embedsQuickActionsInCard ? CGFloat(238) : CGFloat(132)
        let width = embedsQuickActionsInCard
            ? min(size.width - 12, frame.width + 86)
            : min(size.width - 18, 380)
        let y = embedsQuickActionsInCard
            ? frame.maxY - quickHeight / 2 - 18
            : min(size.height - safeBottom - 122, frame.maxY + 92)
        return FocusHomeVerticalSolidQuickActionLayer(
            content: quickActions(card),
            width: width,
            height: quickHeight,
            reveal: reveal,
            isReady: isExpandedInteractionReady,
            reduceMotion: reduceMotion,
            isEmbedded: embedsQuickActionsInCard
        )
        .position(x: frame.midX, y: y)
    }

    private func collapsedHitLayer(in size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let card = hitTestCard(at: value.location, in: size) else { return }
                        onSelect(card)
                    }
            )
    }

    private func frame(for card: FocusCard, index: Int, in size: CGSize, visibleCenterX: CGFloat) -> CGRect {
        let collapsed = collapsedFrame(index: index, count: cards.count, in: size)
        guard card.id == selectedCardId else {
            if selectedCardId == nil || reduceMotion { return collapsed }
            let pushed = collapsed.offsetBy(dx: 0, dy: 24 + CGFloat(index) * 5)
            return lerpRect(collapsed, pushed, smooth(progress, 0, 0.18))
        }
        let expanded = expandedFrame(for: card, in: size, visibleCenterX: visibleCenterX)
        return reduceMotion ? expanded : lerpRect(collapsed, expanded, eased(progress))
    }

    private func collapsedFrame(index: Int, count: Int, in size: CGSize) -> CGRect {
        let availableHeight = max(260, size.height - collapsedTopInset)
        let width = min(max(size.width * 0.38, 132), 174)
        let height = width * 1.58
        let center = CGPoint(x: size.width / 2, y: collapsedTopInset + availableHeight / 2)
        let slot = portraitSlot(index: index)
        let row = CGFloat(index / 2)
        let x = center.x + slot.dx * width
        let y = center.y - height * 0.40 + slot.dy * height + row * min(34, height * 0.15)
        return CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height)
    }

    private func expandedFrame(for card: FocusCard?, in size: CGSize, visibleCenterX: CGFloat) -> CGRect {
        let aspectRatio: CGFloat = embedsQuickActionsInCard ? 1.72 : 1.58
        let maxWidth: CGFloat = embedsQuickActionsInCard ? 344 : 374
        let horizontalInset: CGFloat = embedsQuickActionsInCard ? 46 : 28
        let topInset = safeTop + (embedsQuickActionsInCard ? 10 : 32)
        let bottomInset = safeBottom + (embedsQuickActionsInCard ? 20 : 28)
        let availableWidth = max(220, size.width - horizontalInset)
        let availableHeight = max(360, size.height - topInset - bottomInset)
        let width = min(availableWidth, maxWidth, availableHeight / aspectRatio)
        let height = width * aspectRatio
        let targetY = topInset + availableHeight / 2
        return CGRect(
            x: visibleCenterX - width / 2,
            y: targetY - height / 2,
            width: width,
            height: height
        )
    }

    private func portraitSlot(index: Int) -> (dx: CGFloat, dy: CGFloat) {
        let slots: [(CGFloat, CGFloat)] = [
            (-0.58, -0.34),
            (0.58, -0.22),
            (-0.50, 0.46),
            (0.52, 0.58),
            (0.02, 0.06),
            (-0.08, 0.98)
        ]
        return slots[index % slots.count]
    }

    private func collapsedRotation(index: Int) -> Double {
        let rotations: [Double] = [-6, 5, -3.5, 7, 1.5, -5]
        return rotations[index % rotations.count]
    }

    private func rotation(for index: Int, isSelected: Bool) -> Double {
        let collapsed = collapsedRotation(index: index)
        guard isSelected, selectedCardId != nil else {
            return collapsed
        }
        if reduceMotion {
            return progress > 0.5 ? 0 : collapsed
        }
        return collapsed * Double(1 - eased(progress))
    }

    private func floatingTransform(index: Int, isSelected: Bool) -> (x: CGFloat, y: CGFloat, rotation: Double) {
        guard canFloatCards, !isSelected else { return (0, 0, 0) }
        let phase: CGFloat = floatingPhase ? 1 : -1
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let depth = max(0.58, 1 - CGFloat(index) * 0.07)
        let verticalDirection: CGFloat = index.isMultiple(of: 3) ? -1 : 1
        return (
            x: direction * phase * 1.2 * depth,
            y: verticalDirection * phase * (2.6 + CGFloat(index % 3) * 0.35) * depth,
            rotation: Double(direction * phase * 0.28 * depth)
        )
    }

    private func inactiveOpacity(for card: FocusCard) -> Double {
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        return reduceMotion ? 0 : Double(1 - smooth(progress, 0, 0.16))
    }

    private func inactiveScale(for card: FocusCard) -> CGFloat {
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        return reduceMotion ? 1 : 1 - smooth(progress, 0, 0.16) * 0.08
    }

    private func hitTestCard(at point: CGPoint, in size: CGSize) -> FocusCard? {
        let indexedCards = Array(cards.enumerated()).sorted { $0.offset > $1.offset }
        for (index, card) in indexedCards {
            let frame = collapsedFrame(index: index, count: cards.count, in: size)
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let radians = -collapsedRotation(index: index) * .pi / 180
            let dx = point.x - center.x
            let dy = point.y - center.y
            let localX = cos(radians) * dx - sin(radians) * dy + frame.width / 2
            let localY = sin(radians) * dx + cos(radians) * dy + frame.height / 2
            if CGRect(origin: .zero, size: frame.size).insetBy(dx: 4, dy: 4).contains(CGPoint(x: localX, y: localY)) {
                return card
            }
        }
        return nil
    }

    private func collapseDragGesture(isEnabled: Bool) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($expandedDragY) { value, state, _ in
                guard isEnabled, value.translation.height > 0 else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard isEnabled else { return }
                if value.translation.height > 84 || value.predictedEndTranslation.height > 150 {
                    onCollapse()
                }
            }
    }

    private func lerpRect(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(
            x: lerp(a.minX, b.minX, t),
            y: lerp(a.minY, b.minY, t),
            width: lerp(a.width, b.width, t),
            height: lerp(a.height, b.height, t)
        )
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func eased(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private func smooth(_ value: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        return eased((value - start) / (end - start))
    }
}

private struct FocusHomeVerticalSolidQuickActionLayer<Content: View>: View {
    let content: Content
    let width: CGFloat
    let height: CGFloat
    let reveal: CGFloat
    let isReady: Bool
    let reduceMotion: Bool
    let isEmbedded: Bool

    var body: some View {
        let base = content
            .transaction { transaction in
                transaction.animation = nil
            }
            .frame(width: width, alignment: .top)
            .frame(height: height, alignment: .top)
            .opacity(isReady ? 1 : Double(reveal))
            .allowsHitTesting(isReady)

        if isReady {
            base
        } else {
            base.clipShape(WalletHeroRevealShape(reveal: reveal))
        }
    }
}

private struct FocusHomeFrozenAvatarSource {
    let image: UIImage?
    let isTransparent: Bool

    @MainActor
    static func make(for card: FocusCard) -> FocusHomeFrozenAvatarSource {
        let entry = FocusWalletAvatarCache.frozenEntry(for: card.id, data: card.avatarImageData)
        return FocusHomeFrozenAvatarSource(image: entry.image, isTransparent: entry.isTransparent)
    }

    @MainActor
    static func live(for card: FocusCard) -> FocusHomeFrozenAvatarSource {
        let entry = FocusWalletAvatarCache.entry(for: card.id, data: card.avatarImageData)
        let image = entry.image ?? card.avatarImageData.flatMap(UIImage.init(data:))
        return FocusHomeFrozenAvatarSource(image: image, isTransparent: entry.isTransparent)
    }
}

private struct FocusHomeVerticalSolidCardSurface: View {
    let card: FocusCard
    let isExpanded: Bool
    let progress: CGFloat
    let reduceMotion: Bool
    let frozenAvatarSource: FocusHomeFrozenAvatarSource?

    private var accent: Color {
        return card.themeColorHex.isEmpty ? card.color : Color(hex: card.themeColorHex)
    }

    private var visualProgress: CGFloat {
        isExpanded ? min(max(progress, 0), 1) : 0
    }

    private var cornerRadius: CGFloat {
        lerp(30, 42, visualProgress)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let p = visualProgress
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let avatarSource = frozenAvatarSource ?? FocusHomeFrozenAvatarSource.live(for: card)

            ZStack(alignment: .topLeading) {
                shape
                    .fill(cardGradient)
                    .overlay {
                        shape
                            .strokeBorder(borderGradient, lineWidth: lerp(1, 1.25, p))
                    }

                VStack(alignment: .leading, spacing: 0) {
                    header(progress: p)
                        .padding(.top, lerp(16, 26, p))
                        .padding(.horizontal, lerp(16, 24, p))

                    Spacer(minLength: 0)

                    avatar(image: avatarSource.image, transparent: avatarSource.isTransparent, width: w, height: h)
                        .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
                        .frame(height: h * lerp(0.42, 0.50, p))
                        .padding(.leading, lerp(10, 24, p))
                        .padding(.trailing, lerp(10, w * 0.30, p))

                    footer(progress: p)
                        .padding(.horizontal, lerp(16, 24, p))
                        .padding(.bottom, lerp(16, 218, p))
                }

                expandedSideInfo(width: w, height: h, progress: p)
            }
            .clipShape(shape)
            .saturation(card.hasPassedAway ? 0 : 1)
            .shadow(color: Color.arkInk.opacity(lerp(0.20, 0.28, p)), radius: lerp(15, 24, p), x: 0, y: lerp(10, 18, p)) // ui-v4: allow intentional home card depth
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.name), \(card.kind)")
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.mix(with: .white, by: 0.10),
                accent.mix(with: .black, by: 0.18),
                accent.mix(with: .black, by: 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.goCardWhite.opacity(lerp(0.20, 0.30, visualProgress)),
                accent.mix(with: .white, by: 0.10).opacity(lerp(0.42, 0.55, visualProgress)),
                Color.arkInk.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func header(progress p: CGFloat) -> some View {
        let reveal = expandedContentProgress(p)
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: headerStackAlignment(progress: p), spacing: lerp(2, 4, p)) {
                Text(card.name)
                    .font(.system(size: lerp(18, 30, p), weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .shadow(color: Color.arkInk.opacity(0.58), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text

                ZStack(alignment: headerFrameAlignment(progress: p)) {
                    Text(card.kind)
                        .opacity(Double(1 - reveal))
                    Text(expandedSubtitle)
                        .opacity(Double(reveal))
                }
                .font(.system(size: lerp(10, 13, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .shadow(color: Color.arkInk.opacity(0.46), radius: 4, x: 0, y: 1) // ui-v4: allow requested legibility shadow on card text
            }
            .frame(maxWidth: .infinity, alignment: headerFrameAlignment(progress: p))

            Spacer(minLength: 0)

            Text(statusBadge)
                .font(.system(size: lerp(10, 12, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite)
                .padding(.horizontal, lerp(9, 12, p))
                .padding(.vertical, lerp(5, 7, p))
                .background(statusBadgeBackground, in: Capsule())
                .shadow(color: Color.arkInk.opacity(0.58), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text
        }
    }

    @ViewBuilder
    private func avatar(image: UIImage?, transparent: Bool, width: CGFloat, height: CGFloat) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(
                    width: width * (card.isHuman ? lerp(0.50, 0.64, visualProgress) : lerp(0.62, 0.76, visualProgress)),
                    height: height * (card.isHuman ? lerp(0.40, 0.48, visualProgress) : lerp(0.42, 0.50, visualProgress)),
                    alignment: .bottom
                )
                .offset(y: card.isHuman ? lerp(0, -52, visualProgress) : lerp(0, -92, visualProgress))
                .shadow(color: Color.arkInk.opacity(transparent ? 0.26 : 0.16), radius: 16, y: 10) // ui-v4: allow intentional avatar depth
        } else {
            Image(systemName: avatarSymbol)
                .font(.system(size: width * lerp(0.36, 0.42, visualProgress), weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goCardWhite.opacity(0.88))
                .frame(height: height * 0.38)
        }
    }

    @ViewBuilder
    private func expandedSideInfo(width: CGFloat, height: CGFloat, progress p: CGFloat) -> some View {
        let values = expandedInfoValues
        let reveal = expandedContentProgress(p)
        if !values.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(values.prefix(3), id: \.self) { value in
                    Text(value)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goCardWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .shadow(color: Color.arkInk.opacity(0.62), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text
                }
            }
            .opacity(Double(reveal))
            .scaleEffect(lerp(0.96, 1, reveal), anchor: .trailing)
            .position(x: width * 0.74, y: height * 0.34)
            .allowsHitTesting(false)
        }
    }

    private func footer(progress p: CGFloat) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text(primaryMetric)
                .font(.system(size: lerp(32, 52, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.numericText())
                .shadow(color: Color.arkInk.opacity(0.60), radius: 5, x: 0, y: 2) // ui-v4: allow requested legibility shadow on card text
            Text(metricUnit)
                .font(.system(size: lerp(11, 15, p), weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite.opacity(0.66))
                .lineLimit(1)
                .shadow(color: Color.arkInk.opacity(0.46), radius: 4, x: 0, y: 1) // ui-v4: allow requested legibility shadow on card text
        }
        .frame(maxWidth: .infinity, alignment: headerFrameAlignment(progress: p))
    }

    private func expandedContentProgress(_ progress: CGFloat) -> CGFloat {
        smooth(progress, 0.18, 0.58)
    }

    private func headerStackAlignment(progress: CGFloat) -> HorizontalAlignment {
        progress > 0.46 ? .trailing : .leading
    }

    private func headerFrameAlignment(progress: CGFloat) -> Alignment {
        progress > 0.46 ? .trailing : .leading
    }

    private var expandedSubtitle: String {
        card.ageText ?? card.daysTogetherText ?? card.kind
    }

    private var expandedInfoValues: [String] {
        var values: [String] = []
        if let ageText = card.ageText, !ageText.isEmpty {
            values.append(ageText)
        }
        if let daysTogetherText = card.daysTogetherText,
           !daysTogetherText.isEmpty,
           daysTogetherText != card.ageText {
            values.append(daysTogetherText)
        }
        if card.isHuman {
            values.append("\(card.coconutBalance)🥥")
        }
        if values.isEmpty {
            values.append(card.kind)
        }
        return values
    }

    private var statusBadge: String {
        if let statusBadgeText = card.statusBadgeText {
            return statusBadgeText
        }
        if card.isHuman { return "🥥" }
        if card.streak > 0 { return "\(card.streak)" }
        return "OK"
    }

    private var statusBadgeBackground: Color {
        card.statusBadgeIsWarning ? Color.goRed : Color.clear
    }

    private var primaryMetric: String {
        if card.isHuman { return "\(card.coconutBalance)" }
        if card.isElectronicPet { return "\(card.critterAppearanceStage)" }
        if card.daysTogether > 0 { return "\(card.daysTogether)" }
        return "\(max(0, card.streak))"
    }

    private var metricUnit: String {
        if card.isHuman { return "c" }
        if card.isElectronicPet { return "Lv" }
        if card.daysTogether > 0 { return "d" }
        return "streak"
    }

    private var avatarSymbol: String {
        if card.isElectronicPet { return "leaf.fill" }
        if card.isHuman { return "person.fill" }
        let species = (card.petSpecies ?? card.kind).lowercased()
        if species.contains("dog") || species.contains("狗") { return "dog.fill" }
        if species.contains("cat") || species.contains("猫") { return "cat.fill" }
        if species.contains("bird") || species.contains("鸟") { return "bird.fill" }
        if species.contains("fish") || species.contains("鱼") { return "fish.fill" }
        return "pawprint.fill"
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: CGFloat) -> Double {
        a + (b - a) * Double(min(max(t, 0), 1))
    }

    private func eased(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private func smooth(_ value: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard end > start else { return value >= end ? 1 : 0 }
        return eased((value - start) / (end - start))
    }
}
