//
//  VerticalGlassHomeLabView.swift
//  Ohana
//
//  Developer-only vertical glass home concept playground.
//

import SwiftUI

struct VerticalGlassHomeLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appLanguage") private var appLanguage = "zh"
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    @State private var selectedTab: VerticalGlassHomeLabTab = .home
    @State private var selectedCardId: UUID?
    @State private var isVisible = false
    @State private var isFocusCollapsed = false
    @State private var selectedFocusIndex = 0
    @GestureState private var focusDragY: CGFloat = 0
    private let cards = VerticalGlassHomeLabCard.fixtures
    private let focusItems = VerticalGlassHomeLabFocus.fixtures
    private var l: L10n { L10n(appLanguage) }
    private var canFloat: Bool {
        !reduceMotion && workloadPolicy.ambientMotionBudget(isVisible: isVisible).allowsMotion
    }

    private var bottomNavGlassTint: Color {
        if reduceTransparency {
            return Color.ohanaCardSurface.opacity(0.92)
        }
        return Color.ohanaCardSurface.opacity(colorScheme == .dark ? 0.28 : 0.34)
    }

    private var bottomNavSpecularStroke: Color {
        colorScheme == .dark ? Color.ohanaPrimaryText.opacity(0.18) : Color.ohanaSecondaryText.opacity(0.10)
    }

    private var clampedFocusDragY: CGFloat {
        min(74, max(-74, focusDragY))
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !canFloat)) { timeline in // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                    let time = canFloat ? timeline.date.timeIntervalSinceReferenceDate : 0
                    ZStack {
                        header(safeTop: geo.safeAreaInsets.top)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .zIndex(30)

                        todayFocusDeck(safeTop: geo.safeAreaInsets.top)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .zIndex(28)

                        VerticalGlassHomeLabStage(
                            cards: cards,
                            selectedCardId: selectedCardId,
                            time: time,
                            reduceMotion: reduceMotion || workloadPolicy.interactionMotionBudget(isVisible: isVisible) != .full,
                            onSelect: selectCard,
                            onCollapse: collapseCard
                        )
                        .padding(.top, geo.safeAreaInsets.top + (isFocusCollapsed ? 112 : 196))
                        .padding(.bottom, geo.safeAreaInsets.bottom + 78)
                        .zIndex(10)

                        bottomBar(safeBottom: geo.safeAreaInsets.bottom)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .zIndex(40)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            isVisible = true
            workloadPolicy.refresh(reason: "verticalGlassHomeLabAppear")
        }
        .onDisappear { isVisible = false }
    }

    private func header(safeTop: CGFloat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "竖版实色首页实验室", en: "Solid Portrait Home Lab", de: "Solides Hochformat-Home-Labor"))
                    .font(OhanaFont.adaptive(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "实色卡片、小幅交错、内嵌快捷操作", en: "Solid cards, light stagger, embedded actions", de: "Solide Karten, leichte Staffelung, Aktionen"))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaCardSurface, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
        .padding(.top, max(10, safeTop + 6))
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func todayFocusDeck(safeTop: CGFloat) -> some View {
        let active = focusItems.indices.contains(selectedFocusIndex) ? focusItems[selectedFocusIndex] : focusItems[0]

        if isFocusCollapsed {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(GoMotion.zStackHero) {
                    isFocusCollapsed = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: active.icon)
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                    Text(active.compactTitle(l))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .lineLimit(1)
                    Text(active.value)
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, safeTop + 74)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let dragY = clampedFocusDragY
            let dragProgress = min(1, abs(dragY) / 74)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                    .fill(Color.ohanaCardSurface.opacity(0.46))
                    .offset(y: 36 + dragProgress * 8)
                    .scaleEffect(x: 0.82 + dragProgress * 0.03, y: 1, anchor: .top)
                RoundedRectangle(cornerRadius: OhanaRadius.sheetMini, style: .continuous)
                    .fill(Color.ohanaCardSurface.opacity(0.66))
                    .offset(y: 24 + dragProgress * 5)
                    .scaleEffect(x: 0.90 + dragProgress * 0.02, y: 1, anchor: .top)
                RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                    .fill(Color.ohanaCardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
                            .strokeBorder(Color.ohanaGlassStroke.opacity(0.22), lineWidth: 1)
                    }

                ZStack {
                    ForEach(Array(focusItems.enumerated()), id: \.element.id) { index, item in
                        let relative = focusRelativeIndex(for: index)

                        VerticalGlassHomeLabFocusItemView(item: item, l: l)
                            .offset(y: focusItemOffset(relative: relative, dragY: dragY))
                            .scaleEffect(focusItemScale(relative: relative, dragProgress: dragProgress))
                            .opacity(focusItemOpacity(relative: relative, dragY: dragY, dragProgress: dragProgress))
                            .allowsHitTesting(relative == 0)
                    }
                }
                .frame(height: 112)
                .clipped()
                .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous))
                .highPriorityGesture(focusSwipeGesture)
                .accessibilityAction(named: Text(l.tr(zh: "下一张任务", en: "Next focus", de: "Nächster Fokus"))) {
                    shiftFocus(1, withFeedback: true)
                }
                .accessibilityAction(named: Text(l.tr(zh: "上一张任务", en: "Previous focus", de: "Vorheriger Fokus"))) {
                    shiftFocus(-1, withFeedback: true)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(GoMotion.zStackHero) {
                        isFocusCollapsed = true
                    }
                } label: {
                    Image(systemName: "chevron.up") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 32, height: 32) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
                .offset(x: 0, y: -12)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
            }
            .frame(height: 148)
            .padding(.top, safeTop + 76)
            .padding(.horizontal, 18)
            .animation(GoMotion.selection, value: selectedFocusIndex)
        }
    }

    private var focusSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($focusDragY) { value, state, _ in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                state = value.translation.height
            }
            .onEnded { value in
                let vertical = value.translation.height
                guard abs(vertical) > abs(value.translation.width) else { return }
                let predicted = value.predictedEndTranslation.height
                guard abs(vertical) > 44 || abs(predicted) > 92 else { return }
                shiftFocus(vertical < 0 ? 1 : -1, withFeedback: true)
            }
    }

    private func focusRelativeIndex(for index: Int) -> Int {
        let count = focusItems.count
        guard count > 0 else { return 0 }
        let forward = (index - selectedFocusIndex + count) % count
        let backward = (selectedFocusIndex - index + count) % count
        return forward <= backward ? forward : -backward
    }

    private func focusItemOffset(relative: Int, dragY: CGFloat) -> CGFloat {
        CGFloat(relative) * 58 + dragY
    }

    private func focusItemScale(relative: Int, dragProgress: CGFloat) -> CGFloat {
        relative == 0 ? (1 - dragProgress * 0.025) : (0.96 + dragProgress * 0.04)
    }

    private func focusItemOpacity(relative: Int, dragY: CGFloat, dragProgress: CGFloat) -> Double {
        if relative == 0 {
            return Double(1 - dragProgress * 0.34)
        }
        let isIncoming = (dragY < 0 && relative == 1) || (dragY > 0 && relative == -1)
        return isIncoming ? Double(dragProgress) : 0
    }

    private func shiftFocus(_ delta: Int, withFeedback: Bool = false) {
        guard !focusItems.isEmpty else { return }
        if withFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        withAnimation(GoMotion.selection) {
            selectedFocusIndex = (selectedFocusIndex + delta + focusItems.count) % focusItems.count
        }
    }

    private func bottomBar(safeBottom: CGFloat) -> some View {
        ZStack(alignment: .top) {
            let navShape = Capsule()

            navShape
                .fill(reduceTransparency ? Color.ohanaCardSurface.opacity(0.94) : Color.clear)
                .glassEffect(.regular.tint(bottomNavGlassTint).interactive(true), in: navShape) // ui-v4: allow Flighty-style liquid nav background
                .overlay {
                    navShape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.ohanaPrimaryText.opacity(colorScheme == .dark ? 0.18 : 0.14),
                                bottomNavSpecularStroke,
                                Color.ohanaGlassStroke.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
                .frame(height: 54)
                .padding(.top, 8)

            HStack(spacing: 8) {
                labTabButton(.home)
                labTabButton(.calendar)

                Color.clear
                    .frame(width: 58, height: 1)

                labTabButton(.oasis)
                if PlantFeatureGate.allows(.plants) {
                    labTabButton(.plants)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Image(systemName: "plus") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .font(OhanaFont.adaptive(size: 22, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 58, height: 58)
                    .background(Color.goPrimary, in: Circle())
                    .overlay(Circle().strokeBorder(Color.ohanaPrimaryActionText.opacity(0.18), lineWidth: 1))
                    .shadow(color: Color.goPrimary.opacity(0.36), radius: 16, x: 0, y: 8) // ui-v4: allow floating primary add action depth
            }
            .buttonStyle(ScaleButtonStyle())
            .offset(y: -8)
            .accessibilityLabel(l.tr(zh: "添加", en: "Add", de: "Hinzufügen"))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, max(8, safeBottom + 2))
    }

    private func labTabButton(_ tab: VerticalGlassHomeLabTab) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(GoMotion.selection) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .symbolVariant(selectedTab == tab ? .fill : .none)
                Text(tab.title(l))
                    .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(selectedTab == tab ? Color.goPrimary : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(tab.title(l))
    }

    private func selectCard(_ card: VerticalGlassHomeLabCard) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
            selectedCardId = card.id
        }
    }

    private func collapseCard() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero) {
            selectedCardId = nil
        }
    }
}

private struct VerticalGlassHomeLabStage: View {
    let cards: [VerticalGlassHomeLabCard]
    let selectedCardId: UUID?
    let time: TimeInterval
    let reduceMotion: Bool
    let onSelect: (VerticalGlassHomeLabCard) -> Void
    let onCollapse: () -> Void

    @GestureState private var expandedDragY: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let selected = selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }

            ZStack {
                if selected != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onCollapse)
                        .zIndex(1)
                } else {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    guard let tappedCard = hitTestCard(at: value.location, in: geo.size) else { return }
                                    onSelect(tappedCard)
                                }
                        )
                        .zIndex(80)
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isSelected = selectedCardId == card.id
                    let isBackground = selected != nil && !isSelected
                    let frame = cardFrame(for: card, at: index, in: geo.size, isSelected: isSelected)
                    let float = floatingOffset(for: index)

                    VerticalGlassHomeLabCardView(
                        card: card,
                        isExpanded: isSelected,
                        reduceMotion: reduceMotion,
                        onCollapse: onCollapse
                    )
                    .frame(width: frame.width, height: frame.height)
                    .rotationEffect(.degrees(isSelected ? 0 : card.rotationDegrees))
                    .scaleEffect(isBackground ? 0.92 : 1)
                    .opacity(isBackground ? 0 : 1)
                    .position(
                        x: frame.midX,
                        y: frame.midY + (isSelected ? max(0, expandedDragY) : (reduceMotion ? 0 : float))
                    )
                    .scaleEffect(isSelected ? max(0.94, 1 - max(0, expandedDragY) / 1400) : 1)
                    .zIndex(isSelected ? 20 : card.depth)
                    .contentShape(RoundedRectangle(cornerRadius: isSelected ? 44 : 30, style: .continuous))
                    .onTapGesture {
                        if isSelected { onCollapse() }
                    }
                    .allowsHitTesting(isSelected)
                    .simultaneousGesture(collapseDragGesture(isEnabled: isSelected))
                    .animation(reduceMotion ? GoMotion.reduced : GoMotion.zStackHero, value: selectedCardId)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func cardFrame(
        for card: VerticalGlassHomeLabCard,
        at _: Int,
        in size: CGSize,
        isSelected: Bool
    ) -> CGRect {
        let collapsedWidth = min(size.width * 0.36, 148)
        let expandedWidth = min(size.width - 30, 356)
        let width = isSelected ? expandedWidth : collapsedWidth
        let height = width * 1.58
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let selectedCenter = CGPoint(x: center.x, y: center.y - 2)
        let collapsedCenter = CGPoint(
            x: center.x + card.collapsedOffset.width,
            y: center.y + card.collapsedOffset.height
        )
        let targetCenter = isSelected ? selectedCenter : collapsedCenter

        return CGRect(
            x: targetCenter.x - width / 2,
            y: targetCenter.y - height / 2,
            width: width,
            height: height
        )
    }

    private func hitTestCard(at point: CGPoint, in size: CGSize) -> VerticalGlassHomeLabCard? {
        let indexedCards = Array(cards.enumerated())
            .sorted { lhs, rhs in lhs.element.depth > rhs.element.depth }

        for (index, card) in indexedCards {
            let frame = cardFrame(for: card, at: index, in: size, isSelected: false)
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let radians = -card.rotationDegrees * .pi / 180
            let dx = point.x - center.x
            let dy = point.y - center.y
            let localX = cos(radians) * dx - sin(radians) * dy + frame.width / 2
            let localY = sin(radians) * dx + cos(radians) * dy + frame.height / 2
            let localPoint = CGPoint(x: localX, y: localY)
            let visibleRect = CGRect(origin: .zero, size: frame.size)
                .insetBy(dx: 5, dy: 5)

            if visibleRect.contains(localPoint) {
                return card
            }
        }

        return nil
    }

    private func floatingOffset(for index: Int) -> CGFloat {
        let wave = sin(time * 0.72 + Double(index) * 1.27)
        return CGFloat(wave) * 2.8
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
}

private struct VerticalGlassHomeLabCardView: View {
    @AppStorage("appLanguage") private var appLanguage = "zh"

    let card: VerticalGlassHomeLabCard
    let isExpanded: Bool
    let reduceMotion: Bool
    let onCollapse: () -> Void

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let shape = RoundedRectangle(cornerRadius: isExpanded ? 44 : 30, style: .continuous)

            ZStack {
                shape
                    .fill(
                        LinearGradient(
                            colors: solidCardColors(isExpanded: isExpanded),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.goCardWhite.opacity(isExpanded ? 0.28 : 0.20),
                                    card.tint.mix(with: .white, by: 0.12).opacity(isExpanded ? 0.58 : 0.42),
                                    Color.arkInk.opacity(isExpanded ? 0.18 : 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isExpanded ? 1.25 : 1
                        )
                    }

                cardContent(width: width, height: height)
            }
            .clipShape(shape)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(card.name), \(card.kind)")
        }
    }

    @ViewBuilder
    private func cardContent(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name)
                        .font(.system(size: isExpanded ? 28 : 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(isExpanded ? card.expandedSubtitle : card.kind)
                        .font(.system(size: isExpanded ? 12 : 9, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                if isExpanded {
                    Button(action: onCollapse) {
                        Image(systemName: "xmark") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 34, height: 34) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                            .background(Color.ohanaControlFill, in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel("Close")
                } else {
                    Text(card.badge)
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(card.tint, in: Capsule())
                }
            }
            .padding(.top, isExpanded ? 24 : 16)
            .padding(.horizontal, isExpanded ? 22 : 15)

            Spacer(minLength: 0)

            ZStack(alignment: .bottomTrailing) {
                Image(systemName: card.avatarSymbol)
                    .font(.system(size: width * (isExpanded ? 0.47 : 0.43), weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.92))
                    .frame(width: width * 0.78, height: height * 0.36)
                    .offset(y: isExpanded ? -4 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height * (isExpanded ? 0.36 : 0.42))

            if isExpanded {
                expandedMetrics
                    .padding(.horizontal, 18)
                    .padding(.top, 6)

                quickActions
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            } else {
                compactFooter
                    .padding(.horizontal, 15)
                    .padding(.bottom, 16)
            }
        }
    }

    private var compactFooter: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(card.primaryMetric)
                .font(OhanaFont.adaptive(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
            Text(card.metricUnit)
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
    }

    private func solidCardColors(isExpanded: Bool) -> [Color] {
        [
            card.tint.mix(with: .white, by: isExpanded ? 0.12 : 0.10),
            card.tint,
            card.tint.mix(with: .black, by: isExpanded ? 0.34 : 0.30)
        ]
    }

    private var expandedMetrics: some View {
        HStack(spacing: 8) {
            metricPill(card.primaryMetric, card.metricLabel)
            metricPill(card.secondaryMetric, card.secondaryLabel)
        }
    }

    private func metricPill(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
            Text(label)
                .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private var quickActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(card.actions) { action in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: action.icon)
                            .font(OhanaFont.adaptive(size: 15, weight: .black))
                        Text(action.title(l))
                            .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(action.isPrimary ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(action.isPrimary ? card.tint : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

private enum VerticalGlassHomeLabTab: String, CaseIterable, Identifiable {
    case home
    case calendar
    case oasis
    case plants

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .calendar: "calendar"
        case .oasis: "tree"
        case .plants: "leaf"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .home: l.tr(zh: "首页", en: "Home", de: "Home")
        case .calendar: l.tr(zh: "日历", en: "Calendar", de: "Kalender")
        case .oasis: "Oasis"
        case .plants: l.tr(zh: "植物", en: "Plants", de: "Pflanzen")
        }
    }
}

private struct VerticalGlassHomeLabCard: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let expandedSubtitle: String
    let badge: String
    let avatarSymbol: String
    let tint: Color
    let collapsedOffset: CGSize
    let rotationDegrees: Double
    let depth: Double
    let primaryMetric: String
    let metricUnit: String
    let metricLabel: String
    let secondaryMetric: String
    let secondaryLabel: String
    let actions: [VerticalGlassHomeLabAction]

    static let fixtures: [VerticalGlassHomeLabCard] = [
        VerticalGlassHomeLabCard(
            name: "Lilo",
            kind: "Cat",
            expandedSubtitle: "3y · Bond 286",
            badge: "2",
            avatarSymbol: "cat.fill",
            tint: .goOrange,
            collapsedOffset: CGSize(width: -90, height: -112),
            rotationDegrees: -9,
            depth: 3,
            primaryMetric: "86",
            metricUnit: "%",
            metricLabel: "Today",
            secondaryMetric: "2/4",
            secondaryLabel: "Tasks",
            actions: VerticalGlassHomeLabAction.pet
        ),
        VerticalGlassHomeLabCard(
            name: "Momo",
            kind: "Dog",
            expandedSubtitle: "5y · Walk ready",
            badge: "1",
            avatarSymbol: "dog.fill",
            tint: .goTeal,
            collapsedOffset: CGSize(width: 82, height: -96),
            rotationDegrees: 6,
            depth: 5,
            primaryMetric: "42",
            metricUnit: "m",
            metricLabel: "Walk",
            secondaryMetric: "1.8k",
            secondaryLabel: "Steps",
            actions: VerticalGlassHomeLabAction.dog
        ),
        VerticalGlassHomeLabCard(
            name: "Noa",
            kind: "Human",
            expandedSubtitle: "Owner · Private wallet",
            badge: "🥥",
            avatarSymbol: "person.fill",
            tint: .goPurple,
            collapsedOffset: CGSize(width: -72, height: 118),
            rotationDegrees: 5,
            depth: 4,
            primaryMetric: "920",
            metricUnit: "🥥",
            metricLabel: "Wallet",
            secondaryMetric: "6",
            secondaryLabel: "Focus",
            actions: VerticalGlassHomeLabAction.human
        ),
        VerticalGlassHomeLabCard(
            name: "Rio",
            kind: "Fish",
            expandedSubtitle: "Aquarium · Stable",
            badge: "OK",
            avatarSymbol: "fish.fill",
            tint: .goBlue,
            collapsedOffset: CGSize(width: 96, height: 98),
            rotationDegrees: -6,
            depth: 2,
            primaryMetric: "24",
            metricUnit: "°",
            metricLabel: "Water",
            secondaryMetric: "7d",
            secondaryLabel: "Filter",
            actions: VerticalGlassHomeLabAction.aquarium
        )
    ]
}

private struct VerticalGlassHomeLabFocus: Identifiable {
    let id = UUID()
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let compactZh: String
    let compactEn: String
    let compactDe: String
    let subtitleZh: String
    let subtitleEn: String
    let subtitleDe: String
    let value: String
    let unit: String
    let icon: String
    let tint: Color

    func title(_ l: L10n) -> String {
        l.tr(zh: titleZh, en: titleEn, de: titleDe)
    }

    func compactTitle(_ l: L10n) -> String {
        l.tr(zh: compactZh, en: compactEn, de: compactDe)
    }

    func subtitle(_ l: L10n) -> String {
        l.tr(zh: subtitleZh, en: subtitleEn, de: subtitleDe)
    }

    static let fixtures: [VerticalGlassHomeLabFocus] = [
        VerticalGlassHomeLabFocus(
            titleZh: "今日照护",
            titleEn: "Care Focus",
            titleDe: "Pflegefokus",
            compactZh: "任务",
            compactEn: "Focus",
            compactDe: "Fokus",
            subtitleZh: "2 个待完成",
            subtitleEn: "2 tasks left",
            subtitleDe: "2 Aufgaben offen",
            value: "4/6",
            unit: "",
            icon: "checkmark.seal.fill",
            tint: .goPrimary
        ),
        VerticalGlassHomeLabFocus(
            titleZh: "喂水提醒",
            titleEn: "Water Reminder",
            titleDe: "Wasser-Erinnerung",
            compactZh: "饮水",
            compactEn: "Water",
            compactDe: "Wasser",
            subtitleZh: "今日目标 1600 ml",
            subtitleEn: "Goal 1600 ml",
            subtitleDe: "Ziel 1600 ml",
            value: "1200",
            unit: "ml",
            icon: "drop.fill",
            tint: .goBlue
        ),
        VerticalGlassHomeLabFocus(
            titleZh: "家庭悬赏",
            titleEn: "Family Bounty",
            titleDe: "Familienbonus",
            compactZh: "悬赏",
            compactEn: "Bounty",
            compactDe: "Bonus",
            subtitleZh: "完成后 +50🥥",
            subtitleEn: "+50🥥 when done",
            subtitleDe: "+50🥥 danach",
            value: "50",
            unit: "🥥",
            icon: "target",
            tint: .goOrange
        )
    ]
}

private struct VerticalGlassHomeLabFocusItemView: View {
    let item: VerticalGlassHomeLabFocus
    let l: L10n

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                    .fill(item.tint.opacity(0.16))
                Image(systemName: item.icon)
                    .font(OhanaFont.adaptive(size: 34, weight: .black))
                    .foregroundStyle(item.tint)
                    .symbolRenderingMode(.monochrome)
            }
            .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title(l))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(item.value)
                        .font(OhanaFont.adaptive(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Text(item.unit)
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.86))
                }
                Text(item.subtitle(l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .frame(height: 112)
    }
}

private struct VerticalGlassHomeLabAction: Identifiable {
    let id: String
    let titleZh: String
    let titleEn: String
    let titleDe: String
    let icon: String
    let isPrimary: Bool

    init(id: String, zh: String, en: String, de: String, icon: String, isPrimary: Bool) {
        self.id = id
        self.titleZh = zh
        self.titleEn = en
        self.titleDe = de
        self.icon = icon
        self.isPrimary = isPrimary
    }

    func title(_ l: L10n) -> String {
        l.tr(zh: titleZh, en: titleEn, de: titleDe)
    }

    static let pet: [VerticalGlassHomeLabAction] = [
        VerticalGlassHomeLabAction(id: "feed", zh: "喂食", en: "Feed", de: "Futter", icon: "fork.knife", isPrimary: true),
        VerticalGlassHomeLabAction(id: "water", zh: "喂水", en: "Water", de: "Wasser", icon: "drop.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "poop", zh: "噗噗", en: "Poop", de: "Häufchen", icon: "circle.grid.2x2.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "play", zh: "陪玩", en: "Play", de: "Spiel", icon: "sparkles", isPrimary: false),
        VerticalGlassHomeLabAction(id: "weight", zh: "体重", en: "Weight", de: "Gewicht", icon: "scalemass.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "more", zh: "更多", en: "More", de: "Mehr", icon: "ellipsis", isPrimary: false)
    ]

    static let dog: [VerticalGlassHomeLabAction] = [
        VerticalGlassHomeLabAction(id: "walk", zh: "遛狗", en: "Walk", de: "Gassi", icon: "figure.walk", isPrimary: true),
        VerticalGlassHomeLabAction(id: "feed", zh: "喂食", en: "Feed", de: "Futter", icon: "fork.knife", isPrimary: false),
        VerticalGlassHomeLabAction(id: "water", zh: "喂水", en: "Water", de: "Wasser", icon: "drop.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "play", zh: "陪玩", en: "Play", de: "Spiel", icon: "sparkles", isPrimary: false),
        VerticalGlassHomeLabAction(id: "weight", zh: "体重", en: "Weight", de: "Gewicht", icon: "scalemass.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "record", zh: "记录", en: "Note", de: "Notiz", icon: "square.and.pencil", isPrimary: false)
    ]

    static let human: [VerticalGlassHomeLabAction] = [
        VerticalGlassHomeLabAction(id: "weight", zh: "体重", en: "Weight", de: "Gewicht", icon: "scalemass.fill", isPrimary: true),
        VerticalGlassHomeLabAction(id: "cost", zh: "花费", en: "Cost", de: "Kosten", icon: "creditcard.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "med", zh: "用药", en: "Meds", de: "Meds", icon: "pills.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "move", zh: "运动", en: "Move", de: "Aktiv", icon: "figure.run", isPrimary: false),
        VerticalGlassHomeLabAction(id: "note", zh: "备注", en: "Note", de: "Notiz", icon: "note.text", isPrimary: false),
        VerticalGlassHomeLabAction(id: "all", zh: "全部", en: "All", de: "Alle", icon: "square.grid.2x2.fill", isPrimary: false)
    ]

    static let aquarium: [VerticalGlassHomeLabAction] = [
        VerticalGlassHomeLabAction(id: "water", zh: "水体", en: "Water", de: "Wasser", icon: "drop.degreesign.fill", isPrimary: true),
        VerticalGlassHomeLabAction(id: "filter", zh: "滤芯", en: "Filter", de: "Filter", icon: "line.3.horizontal.decrease.circle.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "clean", zh: "清洁", en: "Clean", de: "Rein", icon: "sparkles", isPrimary: false),
        VerticalGlassHomeLabAction(id: "feed", zh: "喂食", en: "Feed", de: "Futter", icon: "fish.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "health", zh: "健康", en: "Health", de: "Gesund", icon: "heart.fill", isPrimary: false),
        VerticalGlassHomeLabAction(id: "more", zh: "更多", en: "More", de: "Mehr", icon: "ellipsis", isPrimary: false)
    ]
}
