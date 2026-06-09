//
//  GachaView.swift
//  Ohana
//
//  Series blind-box gacha presented as an inline V4 glass popup.
//

import SwiftUI
import SwiftData

struct GachaRouteContainer: View {
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \GachaOwnedItem.latestObtainedAt, order: .reverse) private var ownedItems: [GachaOwnedItem]
    @Query(sort: \GachaDrawLog.drawDate, order: .reverse) private var drawLogs: [GachaDrawLog]

    var drawsBackground: Bool = true
    var onClose: (() -> Void)? = nil
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    var body: some View {
        GachaView(
            drawsBackground: drawsBackground,
            onClose: onClose,
            onPresentCoconutLog: onPresentCoconutLog,
            humans: humans,
            ownedItems: ownedItems,
            drawLogs: drawLogs
        )
    }
}

struct GachaView: View {
    var drawsBackground: Bool = true
    var onClose: (() -> Void)? = nil
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil
    let humans: [Human]
    let ownedItems: [GachaOwnedItem]
    let drawLogs: [GachaDrawLog]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @AppStorage("appLanguage") private var appLanguage: String = "zh"
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @AppStorage("gachaHistory") private var legacyHistoryRaw: String = ""

    @State private var selectedSeriesId = GachaSeriesCatalog.defaultSeriesId
    @State private var isDrawing = false
    @State private var revealPhase: CoconutGachaRevealPhase = .idle
    @State private var showPrize = false
    @State private var drawOutcome: GachaDrawOutcome?
    @State private var feedbackText: String?
    @State private var shakeToken = 0
    @State private var revealingCollectibleItemId: String?
    @State private var preRevealOwnedCounts: [String: Int] = [:]
    @State private var revealCardPhase: GachaCollectibleRevealPhase = .idle
    @State private var collectionPulseItemId: String?
    @State private var pendingCollectionCompletion = false
    @State private var collectionCompletionToken = 0
    @State private var isCollectionCompletionCelebrating = false
    @State private var revealResetToken = 0
    @State private var selectedCollectionItemId: String?

    init(
        drawsBackground: Bool = true,
        onClose: (() -> Void)? = nil,
        onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil,
        humans: [Human] = [],
        ownedItems: [GachaOwnedItem] = [],
        drawLogs: [GachaDrawLog] = []
    ) {
        self.drawsBackground = drawsBackground
        self.onClose = onClose
        self.onPresentCoconutLog = onPresentCoconutLog
        self.humans = humans
        self.ownedItems = ownedItems
        self.drawLogs = drawLogs
    }

    private var l: L10n { L10n(appLanguage) }
    private var series: GachaSeriesEntry { GachaSeriesCatalog.series(id: selectedSeriesId) }
    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
    }
    private var currentCoconutBalance: Int { currentHuman?.coconutBalance ?? 0 }
    private var currentHumanLogs: [GachaDrawLog] {
        drawLogs.filter { $0.ownerHumanId == currentHuman?.id.uuidString && $0.seriesId == series.id }
    }
    private var collectionProgress: (owned: Int, total: Int) {
        GachaDrawService.collectionProgress(
            humanId: currentHuman?.id.uuidString ?? "",
            seriesId: series.id,
            ownedItems: ownedItems
        )
    }
    private var selectedSeriesUnlocked: Bool {
        GachaDrawService.isSeriesUnlocked(
            seriesId: series.id,
            humanId: currentHuman?.id.uuidString ?? "",
            ownedItems: ownedItems
        )
    }
    private var defaultCommonProgress: (owned: Int, total: Int) {
        let firstSeries = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        let ownedIds = Set(ownedItems
            .filter {
                $0.ownerHumanId == currentHuman?.id.uuidString &&
                $0.seriesId == firstSeries.id &&
                $0.ownedCount > 0
            }
            .map(\.itemId))
        return (
            firstSeries.commonItems.filter { ownedIds.contains($0.id) }.count,
            firstSeries.commonItems.count
        )
    }
    private var displayedCollectionProgress: (owned: Int, total: Int) {
        guard revealingCollectibleItemId != nil, revealCardPhase.holdsCollectionUpdate else {
            return collectionProgress
        }
        return (
            preRevealOwnedCounts.values.filter { $0 > 0 }.count,
            series.items.count
        )
    }
    private var canDraw: Bool {
        guard let currentHuman else { return false }
        return currentHuman.coconutBalance >= GachaDrawService.costPerDraw && !isDrawing && selectedSeriesUnlocked
    }
    private var shouldAnimateReveal: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }
    private var selectedCollectionItem: GachaItemEntry? {
        guard let selectedCollectionItemId else { return nil }
        return series.items.first { $0.id == selectedCollectionItemId }
    }

    var body: some View {
        GeometryReader { proxy in
            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: true) {
                if drawsBackground {
                    OhanaAppBackground()
                        .ignoresSafeArea()
                }

                LinearGradient(
                    colors: [
                        Color.black.opacity(colorScheme == .dark ? 0.34 : 0.16), // ui-v4: allow modal scrim ink
                        Color.black.opacity(colorScheme == .dark ? 0.10 : 0.05) // ui-v4: allow modal scrim ink
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .ignoresSafeArea()
                .onTapGesture { close() }

                VStack {
                    Spacer(minLength: 0)
                    popupPanel(maxHeight: proxy.size.height * 0.94)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }

                if let selectedCollectionItem {
                    collectionItemDetailOverlay(selectedCollectionItem)
                        .zIndex(4)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .statusBarHidden(false)
    }

    private func popupPanel(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                .padding(.top, 8)
                .padding(.bottom, 6)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "Ohana 盲盒", en: "Ohana Blind Box", de: "Ohana Blindbox"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(series.localizedName(l))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                balancePill

                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { close() }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    seriesSelector
                    gachaStage
                    drawButton
                    if let feedbackText {
                        Text(feedbackText)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.goOrange)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    collectionSection
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .frame(maxHeight: maxHeight)
        .background { OhanaPopupGlassSurface(cornerRadius: 52) }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.18), radius: 34, x: 0, y: -8) // ui-v4: allow lifted inline popup shadow
    }

    private var seriesSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GachaSeriesCatalog.allSeries) { entry in
                    seriesChip(entry)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func seriesChip(_ entry: GachaSeriesEntry) -> some View {
        let isSelected = entry.id == series.id
        let isUnlocked = GachaDrawService.isSeriesUnlocked(
            seriesId: entry.id,
            humanId: currentHuman?.id.uuidString ?? "",
            ownedItems: ownedItems
        )
        return Button {
            guard !isDrawing else { return }
            if isUnlocked {
                withAnimation(shouldAnimateReveal ? GoMotion.selection : GoMotion.reduced) {
                    selectedSeriesId = entry.id
                    selectedCollectionItemId = nil
                    feedbackText = nil
                }
                OhanaFeedback.light()
            } else {
                feedbackText = lockedSeriesMessage
                OhanaFeedback.light()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isUnlocked ? seriesIconName(entry) : "lock.fill")
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .frame(width: 24, height: 24) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .foregroundStyle(isSelected && isUnlocked ? Color.arkInk : Color.ohanaPrimaryText)
                    .background(
                        (isSelected && isUnlocked ? Color.goPrimary : Color.ohanaControlFill),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.localizedName(l))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(seriesChipSubtitle(entry, isUnlocked: isUnlocked))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(isUnlocked ? Color.ohanaSecondaryText : Color.goYellow)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(minHeight: 48)
            .background(isSelected ? Color.ohanaCardSurface : Color.ohanaControlFill, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.goPrimary.opacity(0.58) : Color.ohanaCardStroke, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isUnlocked ? 1 : 0.78)
        .accessibilityLabel(seriesChipAccessibility(entry, isUnlocked: isUnlocked))
    }

    private func seriesIconName(_ entry: GachaSeriesEntry) -> String {
        entry.id == GachaSeriesCatalog.defaultSeriesId ? "sparkles" : "moon.stars.fill"
    }

    private func seriesChipSubtitle(_ entry: GachaSeriesEntry, isUnlocked: Bool) -> String {
        if entry.id == GachaSeriesCatalog.defaultSeriesId {
            return l.tr(zh: "第一套", en: "Set 1", de: "Set 1")
        }
        if isUnlocked {
            return l.tr(zh: "已解锁", en: "Unlocked", de: "Freigeschaltet")
        }
        return l.tr(
            zh: "Nana 普通款 \(defaultCommonProgress.owned)/\(defaultCommonProgress.total) 解锁",
            en: "Unlock at Nana regulars \(defaultCommonProgress.owned)/\(defaultCommonProgress.total)",
            de: "Frei bei Nana normal \(defaultCommonProgress.owned)/\(defaultCommonProgress.total)"
        )
    }

    private func seriesChipAccessibility(_ entry: GachaSeriesEntry, isUnlocked: Bool) -> String {
        isUnlocked
            ? l.tr(zh: "\(entry.localizedName(l))，可选择", en: "\(entry.localizedName(l)), selectable", de: "\(entry.localizedName(l)), auswählbar")
            : lockedSeriesMessage
    }

    private var lockedSeriesMessage: String {
        l.tr(
            zh: "集齐第一套 Nana 的 8 个普通款后解锁 Midnight Atelier。",
            en: "Complete the 8 Nana regulars to unlock Midnight Atelier.",
            de: "Sammle alle 8 normalen Nana-Figuren, um Midnight Atelier freizuschalten."
        )
    }

    private var balancePill: some View {
        CoconutBalanceCapsule(balance: currentCoconutBalance, showsDeltaAnimation: true) {
            presentCoconutLog()
            OhanaFeedback.light()
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .disabled(currentHuman == nil)
        .opacity(currentHuman == nil ? 0.62 : 1)
        .accessibilityLabel(l.tr(zh: "当前椰子余额 \(currentCoconutBalance)，打开椰子历史", en: "Current coconut balance \(currentCoconutBalance), open coconut history", de: "Aktueller Kokosnussstand \(currentCoconutBalance), Kokosnuss-Historie öffnen"))
    }

    private func presentCoconutLog() {
        let subject = currentHuman.map { CoconutLogSubject.human($0.id) }
        onPresentCoconutLog?(subject)
    }

    private var gachaStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.ohanaCardSurface)

            VStack(spacing: 8) {
                CoconutGachaRevealView(
                    phase: revealPhase,
                    prizeSymbol: drawOutcome?.displaySymbol,
                    rarity: drawOutcome?.item?.rarity,
                    trigger: shakeToken,
                    instantCoconutDelta: drawOutcome?.log.instantCoconutDelta ?? 0,
                    collectibleItem: drawOutcome?.item,
                    revealCardPhase: revealCardPhase,
                    isNewCollectible: drawOutcome?.log.isNew == true,
                    onCollectibleCardTap: revealCollectibleToyOnCard,
                    onCollectibleKeepTap: releaseCollectibleFromCard
                )
                .frame(height: drawOutcome?.item == nil ? 230 : 376)

                if showPrize, let outcome = drawOutcome {
                    prizeSummary(outcome)
                        .transition(.scale(scale: 0.86).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func prizeSummary(_ outcome: GachaDrawOutcome) -> some View {
        let tint = outcomeTint(outcome)
        return HStack(spacing: 10) {
            if let item = outcome.item {
                GachaCollectibleThumbnailView(
                    item: item,
                    ownedCount: max(1, outcome.ownedItem?.ownedCount ?? 1)
                )
            } else {
                Text(outcome.displaySymbol)
                    .font(OhanaFont.adaptive(size: 34)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(outcomeTitle(outcome))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if outcome.log.isNew && outcome.item != nil {
                        Text("NEW")
                            .font(OhanaFont.caption2(.black))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.goPrimary, in: Capsule())
                    }
                }
                Text(outcomeSubtitle(outcome))
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(tint)
            }

            Spacer()

            if let owned = outcome.ownedItem {
                Text("x\(owned.ownedCount)")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
            } else if outcome.log.instantCoconutDelta > 0 {
                Text("+\(outcome.log.instantCoconutDelta)🥥")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.goPrimary)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func outcomeTitle(_ outcome: GachaDrawOutcome) -> String {
        if let item = outcome.item { return item.localizedName(l) }
        if let instant = outcome.instantResult { return instant.localizedTitle(l) }
        return outcome.log.instantTitle(l)
    }

    private func outcomeSubtitle(_ outcome: GachaDrawOutcome) -> String {
        if let item = outcome.item { return item.rarity.name(l) }
        if let instant = outcome.instantResult { return instant.localizedDetail(l) }
        return outcome.log.instantDetail(l)
    }

    private func outcomeTint(_ outcome: GachaDrawOutcome) -> Color {
        if let item = outcome.item { return item.rarity.tint }
        switch outcome.outcomeKind {
        case .collectible: return Color.goPrimary
        case .instantReward: return Color.goYellow
        case .message: return Color.goTeal
        }
    }

    private var drawButton: some View {
        Button {
            draw()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: canDraw ? "sparkles" : "lock.fill")
                Text(drawButtonTitle)
                if canDraw {
                    Text("-\(GachaDrawService.costPerDraw)🥥")
                        .foregroundStyle(Color.arkInk.opacity(0.58))
                }
            }
            .font(OhanaFont.headline(.black))
            .foregroundStyle(canDraw ? Color.arkInk : Color.ohanaSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(canDraw ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canDraw)
    }

    private var drawButtonTitle: String {
        if currentHuman == nil {
            return l.tr(zh: "先切换本人账户", en: "Choose your account", de: "Konto wählen")
        }
        if let currentHuman, currentHuman.coconutBalance < GachaDrawService.costPerDraw {
            return l.tr(zh: "椰子不足", en: "Not enough coconuts", de: "Nicht genug Kokos")
        }
        if !selectedSeriesUnlocked {
            return l.tr(zh: "系列未解锁", en: "Series locked", de: "Serie gesperrt")
        }
        return isDrawing
            ? l.tr(zh: "打开中", en: "Opening", de: "Öffnet")
            : l.tr(zh: "敲开椰子", en: "Crack it open", de: "Kokos öffnen")
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(l.tr(zh: "系列收藏", en: "Collection", de: "Sammlung"), systemImage: "square.grid.3x3.fill")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Text("\(displayedCollectionProgress.owned)/\(displayedCollectionProgress.total)")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .contentTransition(.numericText())
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(series.items) { item in
                    collectionCell(item)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(collectionCompletionGlow)
        .scaleEffect(isCollectionCompletionCelebrating ? 1.012 : 1)
        .ohanaShine(
            trigger: collectionCompletionToken,
            cornerRadius: 26,
            isEnabled: shouldAnimateReveal && collectionCompletionToken > 0
        )
        .animation(shouldAnimateReveal ? GoMotion.feedback : GoMotion.reduced, value: isCollectionCompletionCelebrating)
    }

    @ViewBuilder
    private var collectionCompletionGlow: some View {
        if isCollectionCompletionCelebrating {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(0.54), lineWidth: 2)

                ForEach(0..<9, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                        .font(.system(size: index.isMultiple(of: 2) ? 15 : 9, weight: .black))
                        .foregroundStyle(index.isMultiple(of: 2) ? Color.goPrimary : Color.goYellow)
                        .offset(
                            x: CGFloat([-124, -84, -44, 0, 44, 84, 124, -108, 108][index]),
                            y: CGFloat([-42, -70, -48, -78, -48, -70, -42, 74, 74][index])
                        )
                        .opacity(shouldAnimateReveal ? 0.90 : 0.44)
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private func collectionCell(_ item: GachaItemEntry) -> some View {
        let owned = ownedItems.first {
            $0.ownerHumanId == currentHuman?.id.uuidString &&
            $0.seriesId == series.id &&
            $0.itemId == item.id
        }
        let ownedCount = displayedOwnedCount(for: item, actualCount: owned?.ownedCount ?? 0)
        let isPulsing = collectionPulseItemId == item.id
        let completionIndex = series.items.firstIndex { $0.id == item.id } ?? 0
        let isCompletionCelebrating = isCollectionCompletionCelebrating && ownedCount > 0
        return Button {
            guard ownedCount > 0 else { return }
            selectedCollectionItemId = item.id
            OhanaFeedback.light()
        } label: {
            VStack(spacing: 4) {
                GachaCollectibleThumbnailView(
                    item: item,
                    ownedCount: ownedCount,
                    isPulsing: isPulsing
                )
                    .overlay(alignment: .topTrailing) {
                        if ownedCount > 1 {
                            Text("x\(ownedCount)")
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(Color.arkInk)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.goPrimary, in: Capsule())
                                .offset(x: 5, y: -5)
                        }
                    }
                Text(collectionDisplayName(for: item))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(ownedCount == 0 ? Color.ohanaTertiaryText : item.rarity.tint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .frame(minHeight: 24)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(ownedCount > 0 ? 1 : 0.82)
        .accessibilityLabel(collectionCellAccessibilityLabel(item, ownedCount: ownedCount))
        .frame(maxWidth: .infinity)
        .scaleEffect(isCompletionCelebrating ? 1.05 : 1)
        .animation(
            shouldAnimateReveal
                ? GoMotion.feedback.delay(GoMotion.staggerDelay(completionIndex, step: 0.04, maxDelay: 0.24))
                : GoMotion.reduced,
            value: isCollectionCompletionCelebrating
        )
    }

    private func collectionCellAccessibilityLabel(_ item: GachaItemEntry, ownedCount: Int) -> String {
        if ownedCount > 0 {
            return l.tr(
                zh: "\(collectionDisplayName(for: item))，已拥有 \(ownedCount) 个，点按放大欣赏",
                en: "\(collectionDisplayName(for: item)), owned \(ownedCount), tap to inspect",
                de: "\(collectionDisplayName(for: item)), \(ownedCount) im Besitz, tippen zum Ansehen"
            )
        }
        return l.tr(
            zh: "\(collectionDisplayName(for: item))，尚未拥有",
            en: "\(collectionDisplayName(for: item)), not owned yet",
            de: "\(collectionDisplayName(for: item)), noch nicht im Besitz"
        )
    }

    private func collectionItemDetailOverlay(_ item: GachaItemEntry) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.44 : 0.22), // ui-v4: allow nested detail scrim
                    Color.black.opacity(colorScheme == .dark ? 0.26 : 0.14) // ui-v4: allow nested detail scrim
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
            .onTapGesture { dismissCollectionDetail() }

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(collectionDisplayName(for: item))
                            .font(OhanaFont.title3(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(item.rarity.name(l))
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(item.rarity.tint)
                    }
                    Spacer()
                    OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                        dismissCollectionDetail()
                    }
                }

                collectionDetailImage(item)
                    .frame(width: 230, height: 292)
                    .padding(.vertical, 2)
                    .ohanaShine(trigger: item.id, cornerRadius: 30, isEnabled: shouldAnimateReveal)

                HStack(spacing: 8) {
                    Label("x\(ownedCount(for: item))", systemImage: "square.stack.3d.up.fill")
                    Text(item.localizedPersonality(l))
                        .lineLimit(2)
                }
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("“\(item.localizedMotto(l))”")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.76)
                    .padding(.horizontal, 8)
            }
            .padding(18)
            .frame(maxWidth: 356)
            .background { OhanaPopupGlassSurface(cornerRadius: 42) }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.18), radius: 28, x: 0, y: 14) // ui-v4: allow focused collectible viewer lift
            .padding(.horizontal, 18)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @ViewBuilder
    private func collectionDetailImage(_ item: GachaItemEntry) -> some View {
        if item.imageAssetName.isEmpty {
            Text(item.placeholderSymbol)
                .font(OhanaFont.adaptive(size: 86)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(item.imageAssetName)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dismissCollectionDetail() {
        withAnimation(shouldAnimateReveal ? GoMotion.stateChange : GoMotion.reduced) {
            selectedCollectionItemId = nil
        }
    }

    private func ownedCount(for item: GachaItemEntry) -> Int {
        ownedItems.first {
            $0.ownerHumanId == currentHuman?.id.uuidString &&
            $0.seriesId == series.id &&
            $0.itemId == item.id
        }?.ownedCount ?? 0
    }

    private func displayedOwnedCount(for item: GachaItemEntry, actualCount: Int) -> Int {
        guard revealingCollectibleItemId == item.id, revealCardPhase.holdsCollectionUpdate else {
            return actualCount
        }
        return preRevealOwnedCounts[item.id] ?? 0
    }

    private func collectionDisplayName(for item: GachaItemEntry) -> String {
        strippedSeriesPrefix(from: item.localizedName(l))
    }

    private func strippedSeriesPrefix(from name: String) -> String {
        let prefixes = ["Nana ", "Nana-", "nana "]
        for prefix in prefixes where name.hasPrefix(prefix) {
            let trimmed = String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return name
    }

    @ViewBuilder
    private var recentSection: some View {
        let recent = currentHumanLogs.prefix(4)
        if !recent.isEmpty || !legacyHistoryRaw.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"), systemImage: "clock.fill")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                ForEach(Array(recent), id: \.id) { log in
                    if let row = recentRowData(log) {
                        HStack(spacing: 10) {
                            Text(row.symbol)
                                .font(OhanaFont.adaptive(size: 22)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                                .background(row.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(OhanaFont.caption(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text(log.drawDate.formatted(.dateTime.month().day().hour().minute()))
                                    .font(OhanaFont.caption2(.medium))
                                    .foregroundStyle(Color.ohanaTertiaryText)
                            }
                            Spacer()
                            Text(row.badge)
                                .font(OhanaFont.caption2(.black))
                                .foregroundStyle(row.isEmphasized ? Color.arkInk : Color.ohanaTertiaryText)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(row.isEmphasized ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                        }
                    }
                }

                if currentHumanLogs.isEmpty, !legacyHistoryRaw.isEmpty {
                    Text(l.tr(zh: "旧版扭蛋记录已保留为历史，不会影响新系列收藏。", en: "Legacy gacha history is kept separately and will not affect the new collection.", de: "Alte Gacha-Historie bleibt separat und beeinflusst die neue Sammlung nicht."))
                        .font(OhanaFont.caption(.medium))
                        .foregroundStyle(Color.ohanaTertiaryText)
                }
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    private func recentRowData(_ log: GachaDrawLog) -> (symbol: String, title: String, badge: String, tint: Color, isEmphasized: Bool)? {
        if log.outcomeKind == .collectible,
           let item = GachaSeriesCatalog.item(seriesId: log.seriesId, itemId: log.itemId) {
            return (
                item.placeholderSymbol,
                item.localizedName(l),
                log.isNew ? "NEW" : "x",
                item.rarity.tint,
                log.isNew
            )
        }
        let symbol = log.instantSymbol.isEmpty ? "✨" : log.instantSymbol
        let title = log.instantTitle(l).isEmpty ? log.outcomeKind.name(l) : log.instantTitle(l)
        let badge = log.instantCoconutDelta > 0 ? "+\(log.instantCoconutDelta)🥥" : log.outcomeKind.name(l)
        let tint: Color = log.outcomeKind == .message ? Color.goTeal : Color.goYellow
        return (symbol, title, badge, tint, log.instantCoconutDelta > 0)
    }

    private func draw() {
        guard !isDrawing else { return }
        do {
            let countSnapshot = currentOwnedCounts()
            let outcome = try GachaDrawService.draw(
                seriesId: series.id,
                human: currentHuman,
                context: modelContext
            )
            drawOutcome = outcome
            feedbackText = nil
            isDrawing = true
            revealResetToken += 1
            let resetToken = revealResetToken
            showPrize = false
            revealPhase = .charging
            revealCardPhase = .idle
            shakeToken += 1
            collectionPulseItemId = nil
            pendingCollectionCompletion = isFirstCollectionCompletion(outcome: outcome, previousCounts: countSnapshot)
            isCollectionCompletionCelebrating = false
            preRevealOwnedCounts = countSnapshot
            revealingCollectibleItemId = outcome.item?.id

            OhanaFeedback.medium()

            guard shouldAnimateReveal else {
                if outcome.item != nil {
                    runReducedCollectibleReveal()
                    return
                }
                withAnimation(GoMotion.reduced) {
                    revealPhase = .reveal
                    revealCardPhase = .idle
                    showPrize = true
                    revealingCollectibleItemId = nil
                }
                OhanaFeedback.success()
                returnToCoconut(resetToken: resetToken, delay: 1.12)
                return
            }

            if outcome.item != nil {
                runCollectibleReveal(outcome)
                return
            }

            runNonCollectibleReveal(outcome, resetToken: resetToken)
        } catch let error as GachaDrawError {
            feedbackText = message(for: error)
            OhanaFeedback.error()
        } catch {
            feedbackText = l.tr(zh: "扭蛋暂时打不开", en: "Gacha is not ready", de: "Gacha ist nicht bereit")
            OhanaFeedback.error()
        }
    }

    private func currentOwnedCounts() -> [String: Int] {
        guard let currentHuman else { return [:] }
        return ownedItems
            .filter { $0.ownerHumanId == currentHuman.id.uuidString && $0.seriesId == series.id }
            .reduce(into: [String: Int]()) { counts, owned in
                counts[owned.itemId] = owned.ownedCount
            }
    }

    private func isFirstCollectionCompletion(outcome: GachaDrawOutcome, previousCounts: [String: Int]) -> Bool {
        guard outcome.item != nil, outcome.log.isNew else { return false }
        let previouslyOwnedCount = previousCounts.values.filter { $0 > 0 }.count
        return previouslyOwnedCount == series.items.count - 1
    }

    private func runNonCollectibleReveal(_ outcome: GachaDrawOutcome, resetToken: Int) {
        let isGrandBundle = outcome.log.instantCoconutDelta >= 500
        withAnimation(GoMotion.feedback) {
            revealPhase = .charging
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(GoMotion.feedback) {
                revealPhase = .crack
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(GoMotion.page) {
                    revealPhase = .reveal
                }
                withAnimation(GoMotion.feedback) {
                    showPrize = true
                    if isGrandBundle {
                        shakeToken += 1
                    }
                }
                isGrandBundle ? OhanaFeedback.strong() : OhanaFeedback.light()
                if isGrandBundle {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                        guard resetToken == revealResetToken else { return }
                        OhanaFeedback.medium()
                    }
                }
                returnToCoconut(resetToken: resetToken, delay: isGrandBundle ? 1.86 : 1.18)
            }
        }
    }

    private func runCollectibleReveal(_ outcome: GachaDrawOutcome) {
        withAnimation(GoMotion.feedback) {
            revealPhase = .charging
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(GoMotion.feedback) {
                revealPhase = .crack
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                withAnimation(GoMotion.page) {
                    revealPhase = .reveal
                    revealCardPhase = .cardPopped
                }
                outcome.item?.isHidden == true ? OhanaFeedback.strong() : OhanaFeedback.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    withAnimation(GoMotion.page.speed(0.42)) {
                        revealCardPhase = .flipping
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.08) {
                        withAnimation(GoMotion.stateChange) {
                            revealCardPhase = .revealed
                        }
                        OhanaFeedback.light()
                    }
                }
            }
        }
    }

    private func runReducedCollectibleReveal() {
        withAnimation(GoMotion.reduced) {
            revealPhase = .reveal
            revealCardPhase = .revealed
        }
        OhanaFeedback.light()
    }

    private func revealCollectibleToyOnCard() {
        guard isDrawing, drawOutcome?.item != nil, revealCardPhase == .revealed else { return }

        guard shouldAnimateReveal else {
            withAnimation(GoMotion.reduced) {
                revealCardPhase = .toyReady
            }
            OhanaFeedback.light()
            return
        }

        if drawOutcome?.item?.isHidden == true {
            withAnimation(GoMotion.feedback) {
                revealCardPhase = .secretBurst
                shakeToken += 1
            }
            OhanaFeedback.strong()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                guard revealCardPhase == .secretBurst else { return }
                OhanaFeedback.medium()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.18) {
                guard revealCardPhase == .secretBurst else { return }
                withAnimation(GoMotion.stateChange) {
                    revealCardPhase = .toyReady
                }
                OhanaFeedback.success()
            }
            return
        }

        withAnimation(GoMotion.feedback) {
            revealCardPhase = .toyAppearing
            shakeToken += 1
        }
        drawOutcome?.item?.isHidden == true ? OhanaFeedback.strong() : OhanaFeedback.medium()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            guard revealCardPhase == .toyAppearing else { return }
            withAnimation(GoMotion.stateChange) {
                revealCardPhase = .toyReady
            }
            OhanaFeedback.light()
        }
    }

    private func releaseCollectibleFromCard() {
        guard isDrawing, drawOutcome?.item != nil, revealCardPhase == .toyReady else { return }

        guard shouldAnimateReveal else {
            finishCollectibleReveal()
            return
        }

        withAnimation(GoMotion.feedback) {
            revealCardPhase = .cardGone
        }
        OhanaFeedback.medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(GoMotion.stateChange) {
                revealCardPhase = .flying
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.23) {
                finishCollectibleReveal()
            }
        }
    }

    private func finishCollectibleReveal() {
        let itemId = drawOutcome?.item?.id
        withAnimation(shouldAnimateReveal ? GoMotion.stateChange : GoMotion.reduced) {
            revealPhase = .idle
            revealCardPhase = .idle
            showPrize = false
            drawOutcome = nil
            collectionPulseItemId = itemId
            revealingCollectibleItemId = nil
        }
        OhanaFeedback.success()
        isDrawing = false
        triggerCollectionCompletionAnimationIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            withAnimation(GoMotion.reduced) {
                if collectionPulseItemId == itemId {
                    collectionPulseItemId = nil
                }
                preRevealOwnedCounts = [:]
            }
        }
    }

    private func returnToCoconut(resetToken: Int, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard resetToken == revealResetToken else { return }
            withAnimation(shouldAnimateReveal ? GoMotion.stateChange : GoMotion.reduced) {
                revealPhase = .idle
                revealCardPhase = .idle
                showPrize = false
                drawOutcome = nil
                revealingCollectibleItemId = nil
                collectionPulseItemId = nil
                preRevealOwnedCounts = [:]
            }
            isDrawing = false
        }
    }

    private func triggerCollectionCompletionAnimationIfNeeded() {
        guard pendingCollectionCompletion else { return }
        pendingCollectionCompletion = false
        collectionCompletionToken += 1
        OhanaFeedback.strong()

        withAnimation(shouldAnimateReveal ? GoMotion.feedback : GoMotion.reduced) {
            isCollectionCompletionCelebrating = true
        }

        let holdDuration: Double = shouldAnimateReveal ? 1.35 : 0.42
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
            withAnimation(shouldAnimateReveal ? GoMotion.stateChange : GoMotion.reduced) {
                isCollectionCompletionCelebrating = false
            }
        }
    }

    private func message(for error: GachaDrawError) -> String {
        switch error {
        case .missingHuman:
            return l.tr(zh: "先切换到本人账户", en: "Switch to your account first", de: "Wechsle zuerst zu deinem Konto")
        case .insufficientBalance(let missing):
            return l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig")
        case .invalidSeries:
            return l.tr(zh: "这个系列概率配置不完整", en: "This series has invalid odds", de: "Diese Serie hat ungültige Chancen")
        case .lockedSeries:
            return lockedSeriesMessage
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}
