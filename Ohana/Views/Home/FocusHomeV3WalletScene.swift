//
//  FocusHomeV3WalletScene.swift
//  Ohana
//
//  Wallet-lab powered home card stack. The scene intentionally renders a
//  lightweight card surface during hero motion so business views cannot hitch
//  the transition.
//

import SwiftUI
import UIKit

struct FocusHomeV3WalletScene<QuickActions: View, ContextMenuContent: View>: View {
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
    let quickActions: (FocusCard) -> QuickActions
    let contextMenu: (FocusCard) -> ContextMenuContent
    let onSelect: (FocusCard) -> Void
    let onCollapse: () -> Void
    let onLongPress: (FocusCard) -> Void
    let reorderDragId: UUID?
    let reorderDragOffset: CGFloat
    let isReorderModeActive: Bool
    let isReorderEnabled: Bool
    let onCollapsedLongPress: (FocusCard, [FocusCard], CGFloat) -> Void
    let onCollapsedDragChanged: (FocusCard, [FocusCard], CGFloat, [CGFloat]) -> Void
    let onCollapsedDragEnded: (FocusCard, [FocusCard], CGFloat, [CGFloat]) -> Void
    let onReorderCancel: () -> Void

    private var activeCard: FocusCard? {
        selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }
    }

    private var selectedCardIndex: Int? {
        selectedCardId.flatMap { selectedId in
            cards.firstIndex(where: { $0.id == selectedId })
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
                collapsedBottomGap: 38,
                expandedTopOffset: 116,
                expandedHeightRatio: 0.43,
                expandedMinHeight: K.expandedCardH,
                expandedMaxHeight: K.expandedCardH,
                quickGap: K.expandedQuickModuleGap,
                quickHeight: K.expandedQuickModuleEditH
            )

            ZStack {
                if let activeCard {
                    quickActionLayer(for: activeCard, layout: layout)
                        .zIndex(isExpandedInteractionReady ? 90 : 10)
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isActive = card.id == selectedCardId
                    let isReorderingCard = reorderDragId == card.id
                    let frame = frame(for: card, index: index, layout: layout)

                    FocusHomeV3WalletCardSurface(
                        card: card,
                        progress: isActive ? progress : 0,
                        isActive: isActive,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect(inactiveScale(for: card, index: index) * (isReorderingCard ? 1.015 : 1))
                    .position(x: frame.midX, y: frame.midY + (isReorderingCard ? reorderDragOffset : 0))
                    .opacity(opacity(for: card, index: index))
                    .zIndex(isReorderingCard ? 160 : zIndex(index: index, isActive: isActive))
                    .contentShape(RoundedRectangle(cornerRadius: WalletHeroTimeline.cornerRadius(progress: isActive ? progress : 0), style: .continuous))
                    .if(selectedCardId != nil && !isActive) { view in
                        view.contextMenu { contextMenu(card) }
                    }
                    .allowsHitTesting(false)
                }

                if selectedCardId == nil {
                    collapsedHitZones(layout: layout)
                        .zIndex(70)
                }

                if isExpandedInteractionReady {
                    expandedCardHitZone(layout: layout)
                        .zIndex(80)
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func quickActionLayer(for card: FocusCard, layout: WalletHeroLayout) -> some View {
        let reveal = reduceMotion ? 1 : WalletHeroTimeline.quickReveal(progress: progress)
        Group {
            if isExpandedInteractionReady {
                quickActions(card)
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            } else {
                FocusHomeV3QuickActionRevealSurface(card: card)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: layout.cardWidth, height: layout.quickHeight)
        .position(x: layout.centerX, y: layout.quickFrame.midY)
        .contentShape(Rectangle())
        .clipShape(WalletHeroRevealShape(reveal: reveal))
        .opacity(reveal > 0.01 ? 1 : 0)
        .allowsHitTesting(isExpandedInteractionReady)
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
                let cardFrame = layout.collapsedFrame(index: index, count: cards.count)
                let slotTopYs = (0..<cards.count).map { slotIndex in
                    layout.collapsedFrame(index: slotIndex, count: cards.count).minY
                }

                Rectangle()
                    .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible Wallet hit zone
                    .contentShape(Rectangle())
                    .frame(width: hitFrame.width, height: hitFrame.height)
                    .position(x: hitFrame.midX, y: hitFrame.midY)
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded {
                                if isReorderModeActive || reorderDragId != nil {
                                    onReorderCancel()
                                    return
                                }
                                OhanaFeedback.medium()
                                onSelect(card)
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .onEnded { _ in
                                guard isReorderEnabled, selectedCardId == nil else { return }
                                onCollapsedLongPress(card, cards, cardFrame.minY)
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                guard isReorderEnabled, reorderDragId == card.id else { return }
                                onCollapsedDragChanged(card, cards, value.translation.height, slotTopYs)
                            }
                            .onEnded { value in
                                guard isReorderEnabled, reorderDragId == card.id else { return }
                                onCollapsedDragEnded(card, cards, value.translation.height, slotTopYs)
                            }
                    )
                    .accessibilityLabel(card.name)
                    .accessibilityHint(isReorderModeActive ? "拖动调整排序，点击退出排序" : "点击展开查看，长按调整排序")
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
                .fill(Color.ohanaPrimaryText.opacity(0.001)) // ui-v4: allow invisible Wallet card hit zone
                .frame(width: frame.width, height: frame.height)
        }
        .buttonStyle(.plain) // ui-v4: allow invisible Wallet card hit zone; visible card handles feedback
        .position(x: frame.midX, y: frame.midY)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onEnded { value in
                    guard value.translation.height > 80 else { return }
                    OhanaFeedback.light()
                    onCollapse()
                }
        )
        .accessibilityLabel(activeCard?.name ?? "Expanded card")
    }
}

private struct FocusHomeV3WalletCardSurface: View {
    let card: FocusCard
    let progress: CGFloat
    let isActive: Bool
    let reduceMotion: Bool
    @AppStorage("shop_equip_fx_popout_card") private var equipFxPopoutCard: Bool = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let corner = WalletHeroTimeline.cornerRadius(progress: progress)
            let avatarProgress = WalletHeroTimeline.avatarProgress(progress: progress)
            let avatarEntry = FocusWalletAvatarCache.entry(for: card.id, data: card.avatarImageData)
            let avatarImage = avatarEntry.image ?? card.avatarImageData.flatMap(UIImage.init(data:))
            let popoutImage = FocusPopoutImageCache.image(
                for: card.id,
                data: equipFxPopoutCard ? (card.cardPopoutImageData ?? (card.cardStyleRaw == "popout" ? card.avatarImageData : nil)) : nil
            )
            let usesPopoutOverlay = equipFxPopoutCard && avatarProgress > 0.12 && !card.isHuman && card.cardStyleRaw == "popout" && popoutImage != nil

            ZStack(alignment: .topLeading) {
                walletGlassBackground(corner: corner)
                    .overlay {
                        if card.hasPassedAway {
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .fill(Color.ohanaPrimaryText.opacity(0.06))
                        }
                    }

                if !usesPopoutOverlay {
                    avatar(image: avatarImage, isTransparentAvatar: avatarEntry.isTransparent, w: w, h: h, progress: avatarProgress)
                        .frame(width: avatarColumnWidth(w: w, progress: avatarProgress), height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                collapsedNameLayer(w: w, h: h, progress: progress)

                infoLayer(w: w, h: h, progress: progress)
                    .opacity(Double(WalletHeroTimeline.smooth(progress, 0.14, 0.34)))

                if usesPopoutOverlay, let popoutImage {
                    popoutHeroSubject(popoutImage, w: w, h: h, progress: avatarProgress)
                        .zIndex(4)
                        .allowsHitTesting(false)
                }
            }
            .saturation(card.hasPassedAway ? 0 : 1)
            .shadow(color: Color.ohanaPrimaryText.opacity(isActive ? 0.17 : 0.08), radius: WalletHeroTimeline.lerp(14, 28, progress), y: WalletHeroTimeline.lerp(8, 18, progress)) // ui-v4: allow intentional Wallet hero depth
        }
    }

    private var cardAccent: Color {
        card.themeColorHex.isEmpty ? card.color : Color(hex: card.themeColorHex)
    }

    private func walletGlassBackground(corner: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return shape
            .fill(.clear)
            .glassEffect(.regular.interactive(false), in: shape) // ui-v4: allow user-requested homepage Wallet card glass preview
            .overlay {
                shape
                    .strokeBorder(Color.ohanaGlassStroke, lineWidth: 1)
            }
    }

    private var expandedSubtitle: String? {
        card.ageText ?? card.daysTogetherText ?? card.personalityHint
    }

    private var metricATitle: String {
        if card.isElectronicPet { return "Lv" }
        return card.isHuman ? "Today" : "Together"
    }

    private var metricAValue: String {
        if card.isElectronicPet { return "\(card.critterAppearanceStage)" }
        return card.daysTogetherText ?? "\(card.streak)"
    }

    private var metricBTitle: String {
        card.isElectronicPet ? "Bond" : "🥥"
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.ohanaCardSurfaceElevated.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func infoLayer(w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        let sideWidth = w * WalletHeroTimeline.lerp(0.52, 0.50, progress)
        return VStack(alignment: .trailing, spacing: WalletHeroTimeline.lerp(7, 9, progress)) {
            Text(card.kind.uppercased())
                .font(.system(size: WalletHeroTimeline.lerp(10, 12, progress), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .lineLimit(1)

            Text(card.name)
                .font(.system(size: WalletHeroTimeline.lerp(24, 34, progress), weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .contentTransition(.opacity)

            if let subtitle = expandedSubtitle {
                Text(subtitle)
                    .font(.system(size: WalletHeroTimeline.lerp(11, 13, progress), weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .opacity(Double(WalletHeroTimeline.smooth(progress, 0.18, 0.36)))
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                metric(metricATitle, value: metricAValue)
                metric(metricBTitle, value: "\(card.coconutBalance)")
            }
        }
        .padding(WalletHeroTimeline.lerp(18, 24, progress))
        .frame(width: sideWidth, height: h, alignment: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    private func collapsedNameLayer(w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        Text(card.name)
            .font(.system(size: WalletHeroTimeline.lerp(22, 18, progress), weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.64)
            .padding(.horizontal, WalletHeroTimeline.lerp(18, 22, progress))
            .padding(.top, WalletHeroTimeline.lerp(16, 20, progress))
            .frame(maxWidth: min(w * 0.62, 250), maxHeight: .infinity, alignment: .topLeading)
            .opacity(Double(1 - WalletHeroTimeline.smooth(progress, 0.06, 0.24)))
            .allowsHitTesting(false)
    }

    private func avatarColumnWidth(w: CGFloat, progress: CGFloat) -> CGFloat {
        if card.isHuman {
            return w * WalletHeroTimeline.lerp(0.42, 0.46, progress)
        }
        return w * WalletHeroTimeline.lerp(0.50, 0.72, progress)
    }

    @ViewBuilder
    private func avatar(image: UIImage?, isTransparentAvatar: Bool, w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        if let uiImage = image {
            if card.isHuman {
                let columnWidth = w * WalletHeroTimeline.lerp(0.34, 0.46, progress)
                let avatarHeight = h * WalletHeroTimeline.lerp(0.80, 0.90, progress)
                let avatarOffsetY = h * WalletHeroTimeline.lerp(0.0, -0.035, progress)
                let expandedOffsetX: CGFloat = isTransparentAvatar ? 0.08 : 0.05
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: columnWidth, height: avatarHeight, alignment: .bottom)
                    .offset(x: w * WalletHeroTimeline.lerp(0.03, expandedOffsetX, progress), y: avatarOffsetY)
                    .shadow(color: Color.arkInk.opacity(0.18), radius: 14, y: 8) // ui-v4: allow intentional avatar depth
                    .frame(width: avatarColumnWidth(w: w, progress: progress), height: h, alignment: .bottomLeading)
            } else {
                let columnWidth = w * WalletHeroTimeline.lerp(0.46, 0.72, progress)
                let avatarHeight = h * WalletHeroTimeline.lerp(1.02, 0.96, progress)
                let avatarOffsetY = WalletHeroTimeline.lerp(h * 0.13, -h * 0.02, progress)
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: columnWidth, height: avatarHeight, alignment: .bottom)
                    .offset(x: w * WalletHeroTimeline.lerp(0.015, 0.06, progress), y: avatarOffsetY)
                    .shadow(color: Color.arkInk.opacity(0.22), radius: 18, x: 0, y: 12) // ui-v4: allow intentional avatar grounding
                    .frame(width: avatarColumnWidth(w: w, progress: progress), height: h, alignment: .bottomLeading)
            }
        } else {
            fallbackAvatar(w: w, h: h, progress: progress)
        }
    }

    private func fallbackAvatar(w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        let size = min(w * WalletHeroTimeline.lerp(card.isHuman ? 0.22 : 0.30, card.isHuman ? 0.30 : 0.42, progress), h * 0.64)
        return ZStack(alignment: .center) {
            if card.isHuman {
                HumanSilhouetteView(gender: card.humanGender ?? "", accent: cardAccent.opacity(0.82))
                    .frame(width: size * 1.06, height: h * WalletHeroTimeline.lerp(0.70, 0.82, progress))
            } else {
                Image(systemName: avatarSymbol)
                    .font(.system(size: size * 0.58, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(cardAccent)
            }
        }
        .scaleEffect(WalletHeroTimeline.lerp(0.94, 1.06, progress))
        .frame(width: avatarColumnWidth(w: w, progress: progress), height: h, alignment: .center)
        .offset(x: w * WalletHeroTimeline.lerp(0.02, 0.05, progress))
    }

    private func popoutHeroSubject(_ image: UIImage, w: CGFloat, h: CGFloat, progress: CGFloat) -> some View {
        let artHeight = h * 1.18
        let artWidth = w * 0.70
        let liftedY = WalletHeroTimeline.lerp(h * 0.16, -h * 0.04, progress)
        let subjectScale = WalletHeroTimeline.lerp(0.92, reduceMotion ? 1.0 : 1.035, progress)
        return ZStack(alignment: .bottomLeading) {
            Ellipse()
                .fill(Color.arkInk.opacity(0.28))
                .frame(width: w * 0.42, height: 34)
                .blur(radius: 18)
                .offset(x: w * 0.08, y: h * 0.88)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: artWidth, height: artHeight, alignment: .bottom)
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : -4),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .bottomLeading,
                    perspective: 0.54
                )
                .scaleEffect(subjectScale, anchor: .bottomLeading)
                .offset(x: w * 0.015, y: liftedY)
                .shadow(color: Color.arkInk.opacity(0.34), radius: 22, x: 0, y: 16) // ui-v4: allow popout subject depth
        }
        .frame(width: w, height: h, alignment: .bottomLeading)
    }

    private var avatarSymbol: String {
        if card.isElectronicPet { return "leaf.fill" }
        if card.isHuman { return "person.crop.circle.fill" }
        let species = (card.petSpecies ?? card.kind).lowercased()
        if species.contains("dog") || species.contains("狗") { return "dog.fill" }
        if species.contains("cat") || species.contains("猫") { return "cat.fill" }
        if species.contains("bird") || species.contains("鸟") { return "bird.fill" }
        if species.contains("fish") || species.contains("鱼") { return "fish.fill" }
        return "pawprint.fill"
    }
}

private struct FocusHomeV3QuickActionRevealSurface: View {
    let card: FocusCard

    private var itemCount: Int {
        card.isHuman ? 6 : 8
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
            spacing: 10
        ) {
            ForEach(0..<itemCount, id: \.self) { index in
                VStack(spacing: 8) {
                    Circle()
                        .fill(index == 0 ? Color.goPrimary : Color.ohanaCardSurfaceElevated)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: icon(for: index))
                                .font(.system(size: 17, weight: .black))
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(index == 0 ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                        }
                    Capsule()
                        .fill(Color.ohanaSecondaryText.opacity(0.22))
                        .frame(width: index % 3 == 0 ? 34 : 26, height: 5)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 78)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func icon(for index: Int) -> String {
        let petIcons = ["fork.knife", "drop.fill", "sparkles", "chart.line.uptrend.xyaxis", "heart.fill", "scalemass.fill", "creditcard.fill", "ellipsis"]
        let humanIcons = ["scalemass.fill", "creditcard.fill", "pill.fill", "figure.run", "note.text", "ellipsis"]
        let icons = card.isHuman ? humanIcons : petIcons
        return icons[index % icons.count]
    }
}
