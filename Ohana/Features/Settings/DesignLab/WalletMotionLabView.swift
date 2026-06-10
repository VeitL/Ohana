//
//  WalletMotionLabView.swift
//  Ohana
//
//  Developer-only Apple Wallet style motion playground.
//

import SwiftUI

struct WalletMotionLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("appLanguage") private var appLanguage = "zh"

    @State private var selectedCardId: UUID?
    @State private var progress: CGFloat = 0
    @State private var heroDirection = 0
    @State private var mode: WalletLabMode = .normal
    @State private var showDebug = false
    @State private var reduceMotionPreview = false

    private let cards = WalletMotionLabCard.fixtures
    private var l: L10n { L10n(appLanguage) }
    private var activeCard: WalletMotionLabCard? {
        selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }
    }

    private var reduceMotion: Bool {
        systemReduceMotion || reduceMotionPreview
    }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 14) {
                    header
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                    labControls
                        .padding(.horizontal, 18)

                    WalletMotionLabScene(
                        cards: cards,
                        selectedCardId: selectedCardId,
                        progress: progress,
                        heroDirection: heroDirection,
                        showDebug: showDebug,
                        reduceMotion: reduceMotion,
                        onSelect: selectCard,
                        onCollapse: collapse
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 6)
                    .gesture(collapseDragGesture(height: geo.size.height))

                    if mode == .manual {
                        manualScrubber
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "Apple Wallet 动效实验室", en: "Apple Wallet Motion Lab", de: "Apple-Wallet-Bewegungslabor"))
                    .font(OhanaFont.adaptive(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "纯 fixture 卡片，先把空间连续感调对", en: "Fixture cards only, tuned for spatial continuity", de: "Nur Testkarten, für räumliche Kontinuität"))
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer()

            Button {
                withAnimation(GoMotion.feedback) {
                    showDebug.toggle()
                }
            } label: {
                Image(systemName: showDebug ? "scope" : "scope")
                    .font(OhanaFont.adaptive(size: 16, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 44, height: 44)
                    .background(showDebug ? Color.goPrimary : Color.ohanaCardSurface, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "切换调试层", en: "Toggle debug overlay", de: "Debug-Ebene umschalten"))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaCardSurface, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    private var labControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(WalletLabMode.allCases) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(GoMotion.selection) {
                            mode = item
                            if item == .manual {
                                if selectedCardId == nil { selectedCardId = cards.first?.id }
                                heroDirection = max(heroDirection, 1)
                                progress = max(progress, 0.001)
                            }
                        }
                    } label: {
                        Text(item.title(l))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(mode == item ? Color.ohanaPrimaryActionText : Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(mode == item ? Color.goPrimary : Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            Toggle(isOn: $reduceMotionPreview.animation(GoMotion.selection)) {
                Label(l.tr(zh: "Reduce Motion 预览", en: "Reduce Motion preview", de: "Reduce-Motion-Vorschau"), systemImage: "figure.walk.motion")
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            .toggleStyle(OhanaPillToggleStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
    }

    private var manualScrubber: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("progress")
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(String(format: "%.2f", progress))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .contentTransition(.numericText())
            }
            Slider(
                value: Binding(
                    get: { Double(progress) },
                    set: { value in
                        if selectedCardId == nil { selectedCardId = cards.first?.id }
                        progress = CGFloat(value)
                    }
                ),
                in: 0 ... 1
            )
            .tint(Color.goPrimary)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func selectCard(_ card: WalletMotionLabCard) {
        guard mode != .manual else {
            selectedCardId = card.id
            heroDirection = max(heroDirection, 1)
            progress = max(progress, 0.001)
            return
        }

        if reduceMotion {
            withoutMotion {
                selectedCardId = card.id
                heroDirection = 0
                progress = 1
            }
            return
        }

        selectedCardId = card.id
        heroDirection = 1

        let animation = mode == .slow
            ? Animation.interactiveSpring(response: 1.18, dampingFraction: 0.93, blendDuration: 0.20)
            : GoMotion.heroExpand

        withAnimation(animation) {
            progress = 1
        }
    }

    private func collapse() {
        guard selectedCardId != nil else { return }

        guard mode != .manual else {
            progress = 0
            selectedCardId = nil
            heroDirection = 0
            return
        }

        if reduceMotion {
            withoutMotion {
                progress = 0
                selectedCardId = nil
                heroDirection = 0
            }
            return
        }

        heroDirection = -1
        let animation = mode == .slow
            ? Animation.interactiveSpring(response: 0.96, dampingFraction: 0.96, blendDuration: 0.16)
            : GoMotion.heroCollapse

        withAnimation(animation) {
            progress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (mode == .slow ? 1.0 : 0.54)) {
            if progress <= 0.001 {
                selectedCardId = nil
                heroDirection = 0
            }
        }
    }

    private func collapseDragGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard selectedCardId != nil, value.translation.height > 0, mode != .manual, !reduceMotion else { return }
                heroDirection = -1
                let dragProgress = min(max(value.translation.height / max(height * 0.34, 160), 0), 1)
                progress = 1 - dragProgress
            }
            .onEnded { value in
                guard selectedCardId != nil, mode != .manual else { return }
                guard !reduceMotion else {
                    collapse()
                    return
                }
                if value.predictedEndTranslation.height > 150 || progress < 0.72 {
                    collapse()
                } else {
                    heroDirection = 1
                    withAnimation(GoMotion.heroExpand) {
                        progress = 1
                    }
                }
            }
    }

    private func withoutMotion(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, updates)
    }
}

private struct WalletMotionLabScene: View {
    let cards: [WalletMotionLabCard]
    let selectedCardId: UUID?
    let progress: CGFloat
    let heroDirection: Int
    let showDebug: Bool
    let reduceMotion: Bool
    let onSelect: (WalletMotionLabCard) -> Void
    let onCollapse: () -> Void

    private var activeCard: WalletMotionLabCard? {
        selectedCardId.flatMap { id in cards.first(where: { $0.id == id }) }
    }

    var body: some View {
        GeometryReader { geo in
            let layout = WalletHeroLayout(size: geo.size, safeTop: geo.safeAreaInsets.top, safeBottom: geo.safeAreaInsets.bottom, cardCount: cards.count)
            ZStack {
                if let activeCard {
                    quickActions(for: activeCard, layout: layout)
                        .zIndex(10)
                }

                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let isActive = card.id == selectedCardId
                    let frame = frame(for: card, index: index, layout: layout)
                    let opacity = opacity(for: card)
                    let scale = inactiveScale(for: card)

                    WalletMotionCardView(
                        card: card,
                        progress: isActive ? progress : 0,
                        isActive: isActive,
                        reduceMotion: reduceMotion
                    )
                    .frame(width: frame.width, height: frame.height)
                    .scaleEffect(scale)
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(opacity)
                    .zIndex(zIndex(for: card, index: index, isActive: isActive))
                    .contentShape(RoundedRectangle(cornerRadius: WalletHeroTimeline.cornerRadius(progress: isActive ? progress : 0), style: .continuous))
                    .onTapGesture {
                        if isActive, progress > 0.98 { onCollapse() }
                    }
                    .allowsHitTesting(isActive && progress > 0.05)
                }

                if selectedCardId == nil {
                    collapsedHitZones(layout: layout)
                        .zIndex(70)
                }

                if showDebug {
                    debugOverlay(layout: layout)
                        .zIndex(80)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func frame(for card: WalletMotionLabCard, index: Int, layout: WalletHeroLayout) -> CGRect {
        let collapsed = layout.collapsedFrame(index: index, count: cards.count)
        if reduceMotion {
            return card.id == selectedCardId ? layout.expandedFrame : collapsed
        }
        let selectedIndex = selectedCardIndex
        guard card.id == selectedCardId else {
            return WalletHeroTimeline.inactiveFrame(
                from: collapsed,
                index: index,
                selectedIndex: selectedIndex,
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

    private func opacity(for card: WalletMotionLabCard) -> Double {
        guard selectedCardId != nil else { return 1 }
        if reduceMotion {
            return card.id == selectedCardId ? 1 : 0
        }
        if card.id == selectedCardId { return 1 }
        return WalletHeroTimeline.inactiveOpacity(
            index: cards.firstIndex(where: { $0.id == card.id }) ?? 0,
            selectedIndex: selectedCardIndex,
            progress: progress,
            direction: heroDirection
        )
    }

    private func inactiveScale(for card: WalletMotionLabCard) -> CGFloat {
        guard selectedCardId != nil, card.id != selectedCardId else { return 1 }
        if reduceMotion { return 1 }
        return WalletHeroTimeline.inactiveScale(
            index: cards.firstIndex(where: { $0.id == card.id }) ?? 0,
            selectedIndex: selectedCardIndex,
            progress: progress,
            direction: heroDirection
        )
    }

    private func zIndex(for _: WalletMotionLabCard, index: Int, isActive: Bool) -> Double {
        if isActive {
            return heroDirection < 0 ? Double(index) + 0.25 : 40
        }
        if selectedCardId != nil { return Double(index) }
        return Double(index)
    }

    private var selectedCardIndex: Int? {
        selectedCardId.flatMap { selectedId in
            cards.firstIndex(where: { $0.id == selectedId })
        }
    }

    private func collapsedHitZones(layout: WalletHeroLayout) -> some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let frame = layout.collapsedHitFrame(index: index, count: cards.count)
                Button {
                    onSelect(card)
                } label: {
                    Rectangle()
                        .fill(Color.ohanaPrimaryText.opacity(showDebug ? 0.08 : 0.001))
                        .overlay {
                            if showDebug {
                                RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous)
                                    .strokeBorder(Color.goPrimary.opacity(0.45), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain) // ui-v4: allow invisible Wallet hit zone; visible card handles motion feedback
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .accessibilityLabel(card.title)
            }
        }
    }

    private func quickActions(for card: WalletMotionLabCard, layout: WalletHeroLayout) -> some View {
        let reveal = reduceMotion ? 1 : WalletHeroTimeline.quickReveal(progress: progress)
        return WalletMotionQuickActions(card: card)
            .frame(width: layout.cardWidth, height: layout.quickHeight)
            .position(x: layout.centerX, y: layout.quickFrame.midY)
            .clipShape(WalletHeroRevealShape(reveal: reveal))
            .opacity(reveal > 0.01 ? 1 : 0)
            .allowsHitTesting(progress > 0.98)
    }

    private func debugOverlay(layout: WalletHeroLayout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress \(String(format: "%.2f", progress))")
            Text("direction \(heroDirection)")
            Text("reveal \(String(format: "%.2f", WalletHeroTimeline.quickReveal(progress: progress)))")
        }
        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
        .foregroundStyle(Color.ohanaPrimaryActionText)
        .padding(10)
        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .position(x: layout.centerX, y: layout.expandedFrame.minY - 34)
        .allowsHitTesting(false)
    }
}

private struct WalletMotionCardView: View {
    let card: WalletMotionLabCard
    let progress: CGFloat
    let isActive: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let corner = WalletHeroTimeline.cornerRadius(progress: progress)
            let avatarProgress = WalletHeroTimeline.avatarProgress(progress: progress)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(card.background)
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(card.tint.opacity(0.22))
                            .frame(width: w * 0.72, height: w * 0.72)
                            .offset(x: -w * 0.18, y: -h * 0.32)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 16)
                            .frame(width: w * 0.52, height: w * 0.52)
                            .offset(x: w * 0.16, y: h * 0.20)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(card.eyebrow)
                        .font(.system(size: WalletHeroTimeline.lerp(10, 12, progress), weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(card.title)
                        .font(.system(size: WalletHeroTimeline.lerp(24, 33, progress), weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    HStack(spacing: 8) {
                        metric(card.metricA, value: card.valueA)
                        metric(card.metricB, value: card.valueB)
                    }
                }
                .padding(WalletHeroTimeline.lerp(18, 24, progress))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                avatar(w: w, h: h, progress: avatarProgress)
                    .offset(
                        x: WalletHeroTimeline.lerp(w * 0.54, w * 0.48, avatarProgress),
                        y: WalletHeroTimeline.lerp(h * 0.14, h * 0.08, avatarProgress)
                    )
            }
            .shadow(color: Color.ohanaPrimaryText.opacity(isActive ? 0.18 : 0.08), radius: WalletHeroTimeline.lerp(14, 28, progress), y: WalletHeroTimeline.lerp(8, 18, progress)) // ui-v4: allow intentional Wallet hero depth preview
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : WalletHeroTimeline.lerp(0, -2.8, progress)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.ohanaCardSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private func avatar(w _: CGFloat, h _: CGFloat, progress: CGFloat) -> some View {
        ZStack {
            if card.isBodyAvatar {
                Image(systemName: card.avatarSymbol)
                    .font(.system(size: WalletHeroTimeline.lerp(58, 104, progress), weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(card.tint)
                    .shadow(color: card.tint.opacity(0.24), radius: 20, y: 12) // ui-v4: allow intentional 2.5D avatar depth preview
            } else {
                Circle()
                    .fill(Color.ohanaCardSurface.opacity(0.86))
                    .frame(width: WalletHeroTimeline.lerp(82, 126, progress), height: WalletHeroTimeline.lerp(82, 126, progress))
                    .overlay {
                        Image(systemName: card.avatarSymbol)
                            .font(.system(size: WalletHeroTimeline.lerp(36, 58, progress), weight: .black))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(card.tint)
                    }
            }
        }
        .scaleEffect(WalletHeroTimeline.lerp(0.94, 1.06, progress))
    }
}

private struct WalletMotionQuickActions: View {
    let card: WalletMotionLabCard

    private let actions = [
        ("checkmark", "完成"),
        ("chart.line.uptrend.xyaxis", "趋势"),
        ("calendar", "计划"),
        ("ellipsis", "更多")
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(actions, id: \.0) { action in
                VStack(spacing: 5) {
                    Image(systemName: action.0)
                        .font(OhanaFont.adaptive(size: 17, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(width: 46, height: 46)
                        .background(Color.goPrimary, in: Circle())
                    Text(action.1)
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetMini, style: .continuous))
    }
}

private struct WalletMotionLabCard: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let eyebrow: String
    let metricA: String
    let valueA: String
    let metricB: String
    let valueB: String
    let avatarSymbol: String
    let isBodyAvatar: Bool
    let background: Color
    let tint: Color

    static let fixtures: [WalletMotionLabCard] = [
        WalletMotionLabCard(title: "Milo", eyebrow: "CAT", metricA: "今日", valueA: "2/3", metricB: "椰子", valueB: "128", avatarSymbol: "cat.fill", isBodyAvatar: true, background: Color.ohanaCardSurfaceElevated, tint: Color.petThemeOrange),
        WalletMotionLabCard(title: "Luna", eyebrow: "DOG", metricA: "散步", valueA: "1.8km", metricB: "任务", valueB: "4", avatarSymbol: "dog.fill", isBodyAvatar: true, background: Color.ohanaCardSurface, tint: Color.petThemePurple),
        WalletMotionLabCard(title: "Guan", eyebrow: "HUMAN", metricA: "今日", valueA: "7", metricB: "钱包", valueB: "640", avatarSymbol: "person.crop.circle.fill", isBodyAvatar: false, background: Color.ohanaCardSurfaceElevated, tint: Color.petThemeNavy),
        WalletMotionLabCard(title: "Mochi", eyebrow: "CRITTER", metricA: "星级", valueA: "2", metricB: "心情", valueB: "92", avatarSymbol: "leaf.fill", isBodyAvatar: true, background: Color.ohanaCardSurface, tint: Color.goTeal),
        WalletMotionLabCard(title: "Nana", eyebrow: "BIRD", metricA: "记录", valueA: "16", metricB: "活力", valueB: "88", avatarSymbol: "bird.fill", isBodyAvatar: true, background: Color.ohanaCardSurfaceElevated, tint: Color.petThemePink)
    ]
}

private enum WalletLabMode: String, CaseIterable, Identifiable {
    case normal
    case slow
    case manual

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .normal: l.tr(zh: "正常", en: "Normal", de: "Normal")
        case .slow: l.tr(zh: "0.5x", en: "0.5x", de: "0.5x")
        case .manual: l.tr(zh: "手动", en: "Manual", de: "Manuell")
        }
    }
}

#Preview {
    NavigationStack {
        WalletMotionLabView()
    }
}
