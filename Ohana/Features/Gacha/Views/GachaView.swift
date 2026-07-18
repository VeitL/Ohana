//
//  GachaView.swift
//  Ohana
//
//  Series blind-box gacha presented with native navigation and sheets.
//

import SwiftData
import SwiftUI
import UIKit

private enum GachaFlowSheet: Identifiable {
    case odds
    case funding(GachaFundingPreview)

    var id: String {
        switch self {
        case .odds: "odds"
        case let .funding(preview): "funding:\(preview.id.uuidString)"
        }
    }
}

private struct GachaFundingConfirmationSheet: View {
    let preview: GachaFundingPreview
    let approve: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(l.tr(zh: "个人余额", en: "Personal balance", de: "Persönliches Guthaben")) {
                        Text("\(preview.personalBalance)🥥")
                    }
                    LabeledContent(l.tr(zh: "岛屿可支配", en: "Island spendable", de: "Insel verfügbar")) {
                        Text("\(preview.islandSpendableBalance)🥥")
                    }
                    LabeledContent(l.tr(zh: "本次总额", en: "Draw total", de: "Gesamt")) {
                        Text("\(preview.cost)🥥")
                    }
                } header: {
                    Text(l.tr(zh: "合资确认", en: "Funding confirmation", de: "Finanzierung bestätigen"))
                } footer: {
                    Text(l.tr(
                        zh: "执行前会重新核验每个人的余额；变化时不会部分扣款。",
                        en: "Every balance is rechecked before execution. Changes never cause a partial charge.",
                        de: "Alle Guthaben werden vor der Ausführung erneut geprüft. Änderungen führen nie zu Teilabbuchungen."
                    ))
                }

                Section(l.tr(zh: "出资明细", en: "Contributions", de: "Beiträge")) {
                    ForEach(preview.contributions) { contribution in
                        LabeledContent(contribution.humanName) {
                            Text("\(contribution.amount)🥥")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle(l.tr(zh: "确认抽取", en: "Confirm draw", de: "Zug bestätigen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "确认出资", en: "Confirm", de: "Bestätigen")) {
                        dismiss()
                        Task { @MainActor in approve() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct GachaOddsRulesSheet: View {
    let series: GachaSeriesEntry
    let status: GachaGuaranteeStatus

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    probabilityRow(
                        l.tr(zh: "普通收藏款", en: "Regular collectible", de: "Normale Sammelfigur"),
                        value: status.hiddenUnlocked ? "38%" : "40%"
                    )
                    probabilityRow(
                        l.tr(zh: "单个普通款", en: "Each regular", de: "Je normale Figur"),
                        value: status.hiddenUnlocked ? "4.75%" : l.tr(zh: "缺款优先", en: "Missing-first", de: "Fehlende zuerst")
                    )
                    probabilityRow(
                        l.tr(zh: "隐藏款", en: "Secret collectible", de: "Geheime Figur"),
                        value: status.hiddenUnlocked ? "2%" : l.tr(zh: "未解锁", en: "Locked", de: "Gesperrt")
                    )
                    ForEach(series.instantResults) { result in
                        probabilityRow(result.localizedTitle(l), value: percent(result.probabilityBasisPoints))
                    }
                } header: {
                    Text(l.tr(zh: "当前有效概率", en: "Current effective odds", de: "Aktuelle Chancen"))
                } footer: {
                    Text(l.tr(
                        zh: "普通款未集齐时，隐藏款 2% 转入普通收藏。普通命中后，75% 从缺少款中均匀选择，25% 从全部普通款中选择。",
                        en: "Until all regulars are owned, the secret 2% moves to regulars. A regular hit chooses missing items 75% of the time and all regulars 25% of the time.",
                        de: "Bis alle normalen Figuren da sind, gehen die geheimen 2 % an normale Figuren. Ein normaler Treffer wählt zu 75 % fehlende und zu 25 % alle normalen Figuren."
                    ))
                }

                Section(l.tr(zh: "保底进度", en: "Guarantees", de: "Garantien")) {
                    if let remaining = status.drawsUntilNewCommonGuarantee {
                        guaranteeRow(
                            l.tr(zh: "缺少普通款", en: "Missing regular", de: "Fehlende normale Figur"),
                            detail: l.tr(zh: "最多再 \(remaining) 抽", en: "Within \(remaining) draws", de: "In spätestens \(remaining) Zügen")
                        )
                    }
                    if let remaining = status.drawsUntilHiddenGuarantee {
                        guaranteeRow(
                            l.tr(zh: "隐藏款", en: "Secret", de: "Geheime Figur"),
                            detail: l.tr(zh: "最多再 \(remaining) 抽", en: "Within \(remaining) draws", de: "In spätestens \(remaining) Zügen")
                        )
                    }
                    if let remaining = status.drawsUntilCompletedCollectionGuarantee {
                        guaranteeRow(
                            l.tr(zh: "完整系列后的收藏品", en: "Post-completion collectible", de: "Figur nach Abschluss"),
                            detail: l.tr(zh: "最多再 \(remaining) 抽", en: "Within \(remaining) draws", de: "In spätestens \(remaining) Zügen")
                        )
                    }
                }

                Section(l.tr(zh: "重复补偿", en: "Duplicate compensation", de: "Duplikat-Ausgleich")) {
                    LabeledContent(l.tr(zh: "普通重复款", en: "Regular duplicate", de: "Normales Duplikat")) { Text("20✦") }
                    LabeledContent(l.tr(zh: "隐藏重复款", en: "Secret duplicate", de: "Geheimes Duplikat")) { Text("100✦") }
                    Text(l.tr(
                        zh: "重复款仍会累加收藏数量。伙伴星光不能支付盲盒或兑换椰子。",
                        en: "Duplicates still increase owned count. Companion stardust cannot pay for blind boxes or be exchanged for coconuts.",
                        de: "Duplikate erhöhen weiterhin die Anzahl. Begleiter-Sternlicht bezahlt keine Blindboxen und ist nicht in Kokosnüsse tauschbar."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(l.tr(zh: "概率与规则", en: "Odds & rules", de: "Chancen & Regeln"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.done) { dismiss() }
                }
            }
        }
    }

    private func probabilityRow(_ title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value).fontWeight(.semibold)
        }
    }

    private func guaranteeRow(_ title: String, detail: String) -> some View {
        LabeledContent(title) {
            Text(detail)
                .multilineTextAlignment(.trailing)
        }
    }

    private func percent(_ basisPoints: Int) -> String {
        let value = Double(basisPoints) / 100
        return value.rounded() == value
            ? "\(Int(value))%"
            : String(format: "%.2f%%", value).replacingOccurrences(of: "0%", with: "%")
    }
}

struct GachaView: View {
    var drawsBackground: Bool = true
    var onClose: (() -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    let humans: [Human]
    let ownedItems: [GachaOwnedItem]
    let drawLogs: [GachaDrawLog]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppServices.self) private var appServices
    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
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
    @State private var presentedFlowSheet: GachaFlowSheet?
    @State private var displayedStardustBalance = 0
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

    private var selectedActiveHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
    }

    private var currentHuman: Human? {
        if let selectedActiveHuman {
            return selectedActiveHuman
        }
        return humans.first(where: EconomyWalletWritePolicy.canWrite)
    }

    private var currentHumanWalletIsFrozen: Bool {
        guard let currentHuman else { return false }
        return !EconomyWalletWritePolicy.canWrite(currentHuman)
    }

    private var currentCoconutBalance: Int {
        guard let currentHuman else { return 0 }
        return appServices.coconutWallet.balance(for: currentHuman, context: modelContext)
    }

    private var islandSpendableHumanBalance: Int {
        humans
            .filter(EconomyWalletWritePolicy.canWrite)
            .reduce(0) { $0 + max(0, appServices.coconutWallet.balance(for: $1, context: modelContext)) }
    }

    private var currentHumanLogs: [GachaDrawLog] {
        drawLogs.filter { $0.ownerHumanId == currentHuman?.id.uuidString && $0.seriesId == series.id }
    }

    private var guaranteeStatus: GachaGuaranteeStatus {
        GachaDrawService.guaranteeStatus(
            humanId: currentHuman?.id.uuidString ?? "",
            series: series,
            ownedItems: ownedItems,
            logs: drawLogs
        )
    }

    private var collectionProgress: (owned: Int, total: Int) {
        appServices.gacha.collectionProgress(
            humanId: currentHuman?.id.uuidString ?? "",
            seriesId: series.id,
            ownedItems: ownedItems
        )
    }

    private var selectedSeriesUnlocked: Bool {
        appServices.gacha.isSeriesUnlocked(
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
            firstSeries.commonItems.count(where: { ownedIds.contains($0.id) }),
            firstSeries.commonItems.count
        )
    }

    private var displayedCollectionProgress: (owned: Int, total: Int) {
        guard revealingCollectibleItemId != nil, revealCardPhase.holdsCollectionUpdate else {
            return collectionProgress
        }
        return (
            preRevealOwnedCounts.values.count(where: { $0 > 0 }),
            series.items.count
        )
    }

    private var canDraw: Bool {
        currentHuman != nil &&
            !currentHumanWalletIsFrozen &&
            islandSpendableHumanBalance >= appServices.gacha.costPerDraw &&
            !isDrawing &&
            selectedSeriesUnlocked
    }

    private var shouldAnimateReveal: Bool {
        !reduceMotion && workloadPolicy.shouldRunInteractionAnimation(isVisible: true)
    }

    private var selectedCollectionItem: GachaItemEntry? {
        guard let selectedCollectionItemId else { return nil }
        return series.items.first { $0.id == selectedCollectionItemId }
    }

    private var collectionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 128 : 72), spacing: 8)]
    }
}

extension GachaView {
    var body: some View {
        NavigationStack {
            ZStack {
                if drawsBackground {
                    OhanaAppBackground()
                        .ignoresSafeArea()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        seriesSelector
                        economyOverview
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
            .navigationTitle(l.tr(zh: "Ohana 盲盒", en: "Ohana Blind Box", de: "Ohana Blindbox"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel) { close() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedFlowSheet = .odds
                    } label: {
                        Label(
                            l.tr(zh: "概率与规则", en: "Odds & rules", de: "Chancen & Regeln"),
                            systemImage: "info.circle"
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { balancePill }
            }
        }
        .sheet(item: selectedCollectionItemBinding) { item in
            collectionItemDetailSheet(item)
        }
        .sheet(item: $presentedFlowSheet) { sheet in
            switch sheet {
            case .odds:
                GachaOddsRulesSheet(series: series, status: guaranteeStatus)
            case let .funding(preview):
                GachaFundingConfirmationSheet(preview: preview) {
                    draw(approvedFunding: preview)
                }
            }
        }
        .task {
            refreshStardustBalance()
        }
        .onChange(of: drawLogs.count) { _, _ in
            refreshStardustBalance()
        }
        .accessibilityIdentifier("gacha-screen")
    }

    private var selectedCollectionItemBinding: Binding<GachaItemEntry?> {
        Binding(
            get: { selectedCollectionItem },
            set: { selectedCollectionItemId = $0?.id }
        )
    }

    private func collectionItemDetailSheet(_ item: GachaItemEntry) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    collectionDetailImage(item)
                        .frame(width: 230, height: 292)
                        .padding(.vertical, 2)
                        .ohanaShine(trigger: item.id, cornerRadius: OhanaRadius.sheetMini, isEnabled: shouldAnimateReveal)

                    LabeledContent(l.tr(zh: "已拥有", en: "Owned", de: "Im Besitz")) {
                        Label("x\(ownedCount(for: item))", systemImage: "square.stack.3d.up.fill")
                    }

                    LabeledContent(l.tr(zh: "个性", en: "Personality", de: "Persönlichkeit")) {
                        Text(item.localizedPersonality(l))
                    }

                    Text("“\(item.localizedMotto(l))”")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(20)
            }
            .navigationTitle(collectionDisplayName(for: item))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.cancel) { dismissCollectionDetail() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
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
                    economyOverview
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
        .background { OhanaPopupGlassSurface(cornerRadius: OhanaRadius.inlinePopup) }
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

    private var economyOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(
                    currentHuman?.name ?? l.tr(zh: "未选择归属人", en: "No owner selected", de: "Keine Person gewählt"),
                    systemImage: "person.crop.circle.fill"
                )
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                Button {
                    presentedFlowSheet = .odds
                } label: {
                    Label(
                        l.tr(zh: "概率与规则", en: "Odds & rules", de: "Chancen & Regeln"),
                        systemImage: "info.circle"
                    )
                    .font(OhanaFont.caption(.bold))
                }
                .buttonStyle(.plain)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    economyMetric(
                        value: "\(currentCoconutBalance)🥥",
                        label: l.tr(zh: "个人余额", en: "Personal", de: "Persönlich")
                    )
                    economyMetric(
                        value: "\(islandSpendableHumanBalance)🥥",
                        label: l.tr(zh: "岛屿可用", en: "Island spendable", de: "Insel verfügbar")
                    )
                }
                GridRow {
                    economyMetric(
                        value: "\(displayedStardustBalance)✦",
                        label: l.tr(zh: "伙伴星光", en: "Companion stardust", de: "Begleiter-Sternlicht")
                    )
                    economyMetric(
                        value: guaranteeSummary,
                        label: l.tr(zh: "下一保底", en: "Next guarantee", de: "Nächste Garantie")
                    )
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func economyMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(2)
            Text(label)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var guaranteeSummary: String {
        if let remaining = guaranteeStatus.drawsUntilNewCommonGuarantee {
            return l.tr(zh: "新款 ≤\(remaining) 抽", en: "New ≤\(remaining)", de: "Neu ≤\(remaining)")
        }
        if let remaining = guaranteeStatus.drawsUntilHiddenGuarantee {
            return l.tr(zh: "隐藏 ≤\(remaining) 抽", en: "Secret ≤\(remaining)", de: "Geheim ≤\(remaining)")
        }
        if let remaining = guaranteeStatus.drawsUntilCompletedCollectionGuarantee {
            return l.tr(zh: "收藏 ≤\(remaining) 抽", en: "Item ≤\(remaining)", de: "Figur ≤\(remaining)")
        }
        return l.tr(zh: "解锁后显示", en: "Shown after unlock", de: "Nach Freigabe")
    }

    private func seriesChip(_ entry: GachaSeriesEntry) -> some View {
        let isSelected = entry.id == series.id
        let isUnlocked = appServices.gacha.isSeriesUnlocked(
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
                        isSelected && isUnlocked ? Color.goPrimary : Color.ohanaControlFill,
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
        let missing = max(0, defaultCommonProgress.total - defaultCommonProgress.owned)
        return l.tr(
            zh: "还缺 \(missing) 个 Nana 普通款",
            en: "\(missing) Nana regulars missing",
            de: "Noch \(missing) normale Nana-Figuren"
        )
    }

    private func seriesChipAccessibility(_ entry: GachaSeriesEntry, isUnlocked: Bool) -> String {
        isUnlocked
            ? l.tr(zh: "\(entry.localizedName(l))，可选择", en: "\(entry.localizedName(l)), selectable", de: "\(entry.localizedName(l)), auswählbar")
            : lockedSeriesMessage
    }

    private var lockedSeriesMessage: String {
        let missing = max(0, defaultCommonProgress.total - defaultCommonProgress.owned)
        return l.tr(
            zh: "还缺 \(missing) 个 Nana 普通款；集齐后解锁 Midnight Atelier。",
            en: "\(missing) Nana regulars remain before Midnight Atelier unlocks.",
            de: "Noch \(missing) normale Nana-Figuren bis zur Freigabe von Midnight Atelier."
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
            RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort, style: .continuous)
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
                    onCollectibleKeepTap: { releaseCollectibleFromCard(drawAgain: false) },
                    onCollectibleRepeatTap: { releaseCollectibleFromCard(drawAgain: true) }
                )
                .frame(height: drawOutcome?.item == nil ? 230 : 376)

                if showPrize, let outcome = drawOutcome {
                    prizeSummary(outcome)
                        .transition(.scale(scale: 0.86).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                    if outcome.item == nil {
                        nonCollectibleResultActions
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
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
                    .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(outcomeTitle(outcome))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if outcome.log.isNew, outcome.item != nil {
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text("x\(owned.ownedCount)")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if let stardust = outcome.log.stardustDelta, stardust > 0 {
                        Text("+\(stardust)✦")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.goYellow)
                    }
                }
            } else if outcome.log.instantCoconutDelta > 0 {
                Text("+\(outcome.log.instantCoconutDelta)🥥")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.goPrimary)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private var nonCollectibleResultActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { nonCollectibleResultButtons }
            VStack(spacing: 10) { nonCollectibleResultButtons }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var nonCollectibleResultButtons: some View {
        Button {
            settleNonCollectible(drawAgain: false)
        } label: {
            Label(l.tr(zh: "收下", en: "Collect", de: "Annehmen"), systemImage: "checkmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)

        Button {
            settleNonCollectible(drawAgain: true)
        } label: {
            Label(l.tr(zh: "再来一次", en: "Open another", de: "Noch einmal"), systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.goPrimary)
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
            requestDraw()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: canDraw ? "sparkles" : "lock.fill")
                Text(drawButtonTitle)
                if canDraw {
                    Text("-\(appServices.gacha.costPerDraw)🥥")
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
        if currentHumanWalletIsFrozen {
            return l.tr(zh: "钱包已冻结", en: "Wallet frozen", de: "Wallet eingefroren")
        }
        if islandSpendableHumanBalance < appServices.gacha.costPerDraw {
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

            LazyVGrid(columns: collectionColumns, spacing: 8) {
                ForEach(series.items) { item in
                    collectionCell(item)
                }
            }
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay(collectionCompletionGlow)
        .scaleEffect(isCollectionCompletionCelebrating ? 1.012 : 1)
        .ohanaShine(
            trigger: collectionCompletionToken,
            cornerRadius: OhanaRadius.cardLarge,
            isEnabled: shouldAnimateReveal && collectionCompletionToken > 0
        )
        .animation(shouldAnimateReveal ? GoMotion.feedback : GoMotion.reduced, value: isCollectionCompletionCelebrating)
    }

    @ViewBuilder
    private var collectionCompletionGlow: some View {
        if isCollectionCompletionCelebrating {
            ZStack {
                RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                    .strokeBorder(Color.goPrimary.opacity(0.54), lineWidth: 2)

                ForEach(0 ..< 9, id: \.self) { index in
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

    @ViewBuilder
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
        Group {
            if ownedCount > 0 {
                Button {
                    selectedCollectionItemId = item.id
                    OhanaFeedback.light()
                } label: {
                    collectionCellLabel(
                        item,
                        ownedCount: ownedCount,
                        isPulsing: isPulsing
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                collectionCellLabel(item, ownedCount: 0, isPulsing: false)
                    .accessibilityElement(children: .ignore)
            }
        }
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

    private func collectionCellLabel(
        _ item: GachaItemEntry,
        ownedCount: Int,
        isPulsing: Bool
    ) -> some View {
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
                    .ohanaShine(trigger: item.id, cornerRadius: OhanaRadius.sheetMini, isEnabled: shouldAnimateReveal)

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
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))

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
            .background { OhanaPopupGlassSurface(cornerRadius: OhanaRadius.sheetLarge) }
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
                                .background(row.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
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
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
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

    private func requestDraw() {
        guard !isDrawing, let currentHuman else { return }
        let preview = GachaDrawService.fundingPreview(human: currentHuman, context: modelContext)
        guard preview.missing == 0 else {
            feedbackText = message(for: .insufficientBalance(missing: preview.missing))
            OhanaFeedback.error()
            return
        }
        if preview.requiresCofundingConfirmation {
            presentedFlowSheet = .funding(preview)
            OhanaFeedback.light()
        } else {
            draw(approvedFunding: nil)
        }
    }

    private func draw(approvedFunding: GachaFundingPreview?) {
        guard !isDrawing else { return }
        do {
            let countSnapshot = currentOwnedCounts()
            let outcome = try appServices.gacha.draw(
                seriesId: series.id,
                human: currentHuman,
                context: modelContext,
                approvedFunding: approvedFunding
            )
            drawOutcome = outcome
            refreshStardustBalance()
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
                announceOutcome(outcome)
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
        let previouslyOwnedCount = previousCounts.values.count(where: { $0 > 0 })
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
                announceOutcome(outcome)
                if isGrandBundle {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                        guard resetToken == revealResetToken else { return }
                        OhanaFeedback.medium()
                    }
                }
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
                        announceOutcome(outcome)
                    }
                }
            }
        }
    }

    private func runReducedCollectibleReveal() {
        withAnimation(GoMotion.reduced) {
            revealPhase = .reveal
            revealCardPhase = .toyReady
        }
        OhanaFeedback.light()
        if let outcome = drawOutcome {
            announceOutcome(outcome)
        }
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

    private func releaseCollectibleFromCard(drawAgain: Bool) {
        guard isDrawing, drawOutcome?.item != nil, revealCardPhase == .toyReady else { return }

        guard shouldAnimateReveal else {
            finishCollectibleReveal(drawAgain: drawAgain)
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
                finishCollectibleReveal(drawAgain: drawAgain)
            }
        }
    }

    private func finishCollectibleReveal(drawAgain: Bool) {
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
        refreshStardustBalance()
        triggerCollectionCompletionAnimationIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.64) {
            withAnimation(GoMotion.reduced) {
                if collectionPulseItemId == itemId {
                    collectionPulseItemId = nil
                }
                preRevealOwnedCounts = [:]
            }
        }
        guard drawAgain else { return }
        DispatchQueue.main.async {
            requestDraw()
        }
    }

    private func settleNonCollectible(drawAgain: Bool) {
        guard isDrawing, drawOutcome?.item == nil else { return }
        revealResetToken += 1
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
        OhanaFeedback.success()
        guard drawAgain else { return }
        DispatchQueue.main.async {
            requestDraw()
        }
    }

    private func refreshStardustBalance() {
        displayedStardustBalance = GachaDrawService.stardustBalance(context: modelContext)
    }

    private func announceOutcome(_ outcome: GachaDrawOutcome) {
        let stardust = outcome.log.stardustDelta ?? 0
        let supplement = stardust > 0
            ? l.tr(zh: "，重复补偿 \(stardust) 星光", en: ", duplicate compensation \(stardust) stardust", de: ", Duplikat-Ausgleich \(stardust) Sternlicht")
            : ""
        let announcement = "\(outcomeTitle(outcome))，\(outcomeSubtitle(outcome))\(supplement)"
        UIAccessibility.post(notification: .announcement, argument: announcement)
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
            l.tr(zh: "先切换到本人账户", en: "Switch to your account first", de: "Wechsle zuerst zu deinem Konto")
        case let .insufficientBalance(missing):
            l.tr(zh: "还差 \(missing)🥥", en: "Need \(missing)🥥 more", de: "Noch \(missing)🥥 nötig")
        case .walletFrozen:
            l.tr(zh: "该钱包已冻结，历史仍可查看。", en: "This wallet is frozen. History remains available.", de: "Dieses Wallet ist eingefroren. Der Verlauf bleibt sichtbar.")
        case .invalidSeries:
            l.tr(zh: "这个系列概率配置不完整", en: "This series has invalid odds", de: "Diese Serie hat ungültige Chancen")
        case .lockedSeries:
            lockedSeriesMessage
        case .fundingConfirmationRequired:
            l.tr(
                zh: "需要先确认其他成员的出资明细。",
                en: "Review and confirm the other members' contributions first.",
                de: "Bitte zuerst die Beiträge der anderen Mitglieder prüfen und bestätigen."
            )
        case .fundingChanged:
            l.tr(
                zh: "余额或出资已变化，请重新确认。",
                en: "Balances changed. Please review funding again.",
                de: "Guthaben geändert. Bitte Finanzierung erneut prüfen."
            )
        case .backupOrRestoreInProgress:
            l.tr(
                zh: "正在备份或恢复，请稍后再试。",
                en: "Backup or restore is in progress. Try again shortly.",
                de: "Sicherung oder Wiederherstellung läuft. Bitte später erneut versuchen."
            )
        case .persistenceFailed:
            l.tr(
                zh: "这次没有扣款，请稍后再试。",
                en: "Nothing was charged. Please try again.",
                de: "Es wurde nichts abgebucht. Bitte erneut versuchen."
            )
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
