//
//  IslandWealthDashboard2.swift
//  Ohana
//
//  欧哈纳财富中心 — 全页可滚动，收支分开展示
//

import SwiftData
import SwiftUI

// MARK: - Content View
struct IslandWealthDashboardContentView: View {
    let pets: [Pet]
    let humans: [Human]
    let walletAccounts: [CoconutAccount]
    let walletLedgerEntries: [CoconutLedgerEntry]

    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @State private var vm = IslandWealthScreenModel()
    @State private var selectedCoconutActorId: String? = nil
    @State private var chartProgress: Double = 0
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var visibleWealthHumans: [Human] {
        appServices.privacy.unlockedHumans(for: .wishlist, from: humans, viewedBy: activeHumanId)
    }

    private var hiddenWealthHumanIds: Set<String> {
        Set(humans.compactMap {
            appServices.privacy.isLocked(.wishlist, for: $0, viewedBy: activeHumanId) ? $0.id.uuidString : nil
        })
    }

    private var petColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: pets.map { ($0.id.uuidString, Color(hex: $0.themeColorHex)) })
    }

    private var wealthScopeTitle: String {
        guard let selectedCoconutActorId else { return l.tr(zh: "全岛", en: "Island", de: "Insel") }
        if let pet = pets.first(where: { $0.id.uuidString == selectedCoconutActorId }) {
            return pet.name
        }
        if let human = visibleWealthHumans.first(where: { $0.id.uuidString == selectedCoconutActorId }) {
            return human.name
        }
        return l.tr(zh: "已筛选", en: "Filtered", de: "Gefiltert")
    }

    private var safeTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 52
    }

    private var navBarHeight: CGFloat { safeTop + 46 }

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 顶部 navBar 占位
                    Spacer().frame(height: navBarHeight)

                    // 全岛总资产
                    totalAssetsRow

                    // 时间筛选
                    timePicker

                    // 收支汇总两格
                    incomeVsSpendingRow

                    // 图表
                    if vm.displayedAssets == 0, vm.periodIncome == 0, vm.periodSpending == 0 {
                        emptyChart
                    } else {
                        chartSection
                    }

                    // 排行榜
                    leaderboardSection

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .top) { navBar }
        .onAppear {
            syncVM()
            replayChartAnimation()
        }
        .onChange(of: pets.count) { syncVM() }
        .onChange(of: humans.count) { syncVM() }
        .onChange(of: walletAccounts.count) { syncVM() }
        .onChange(of: walletLedgerEntries.count) { syncVM() }
        .onChange(of: activeHumanIdStr) { syncVM() }
        .onChange(of: selectedCoconutActorId) {
            syncVM()
            replayChartAnimation()
        }
        .onChange(of: vm.timeRange) {
            replayChartAnimation()
        }
    }

    private func syncVM() {
        if let selectedCoconutActorId, hiddenWealthHumanIds.contains(selectedCoconutActorId) {
            self.selectedCoconutActorId = nil
        }
        vm.applyQuerySnapshot(
            pets: pets,
            allHumans: humans,
            visibleHumans: visibleWealthHumans,
            hiddenHumanIds: hiddenWealthHumanIds,
            walletAccounts: walletAccounts,
            walletLedgerEntries: walletLedgerEntries,
            petColorMap: petColorMap,
            selectedActorId: selectedCoconutActorId
        )
    }

    private func replayChartAnimation() {
        chartProgress = 0
        withAnimation(GoMotion.page) {
            chartProgress = 1
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Text(l.tr(zh: "Ohana 财富", en: "Ohana Wealth", de: "Ohana-Vermögen"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop)
        .padding(.bottom, 10)
        .background(Color.ohanaCardSurface.opacity(0.01))
    }

    // MARK: - Total Assets

    private var totalAssetsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(wealthScopeTitle)
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.goPrimary.opacity(0.7))
            Text("\(vm.displayedAssets)")
                .font(OhanaFont.adaptive(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .ohanaNumericMotion(vm.displayedAssets)
            Text("🥥")
                .font(OhanaFont.adaptive(size: 30))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Time Picker

    private var timePicker: some View {
        Picker("", selection: $vm.timeRange) {
            ForEach(WealthTimeRange.allCases) { r in
                Text(r.title(l)).tag(r)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Income vs Spending Row

    private var incomeVsSpendingRow: some View {
        HStack(spacing: 8) {
            summaryCell(
                label: l.tr(zh: "本期收入", en: "Income", de: "Einnahmen"),
                value: "+\(vm.periodIncome)",
                valueColor: Color.goPrimary,
                icon: "arrow.down.circle.fill"
            )
            summaryCell(
                label: l.tr(zh: "本期花费", en: "Spending", de: "Ausgaben"),
                value: vm.periodSpending > 0 ? "-\(vm.periodSpending)" : l.tr(zh: "本期无花费", en: "No spending", de: "Keine Ausgaben"),
                valueColor: vm.periodSpending > 0 ? Color.goRed : .primary.opacity(0.35),
                icon: "arrow.up.circle.fill"
            )
            summaryCell(
                label: l.tr(zh: "净变化", en: "Net", de: "Saldo"),
                value: vm.periodNet >= 0 ? "+\(vm.periodNet)" : "\(vm.periodNet)",
                valueColor: vm.periodNet >= 0 ? Color.goPrimary : Color.goRed,
                icon: "equal.circle.fill"
            )
        }
    }

    private func summaryCell(label: String, value: String, valueColor: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                    .foregroundStyle(valueColor.opacity(0.7))
                Text(label)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
            }
            Text(value)
                .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text("🥥")
                .font(OhanaFont.adaptive(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            incomeSpendingTrendChart
        }
        .padding(16)
        .background(Color.ohanaCardSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    private var incomeSpendingTrendChart: some View {
        let incomeTint = Color.goPrimary
        let spendingTint = Color.goRed
        let incomePoints = vm.incomeTrendPoints.map {
            OhanaMinimalChartPoint(date: $0.bucket, value: Double($0.amount))
        }
        let spendingPoints = vm.spendingTrendPoints.map {
            OhanaMinimalChartPoint(date: $0.bucket, value: Double($0.amount))
        }
        let allValues = (incomePoints + spendingPoints).map(\.value)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "收支趋势", en: "Income and spending", de: "Einnahmen und Ausgaben"))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.62))
                    Text(selectedCoconutActorId == nil
                        ? l.tr(zh: "全岛收入 / 花费", en: "Island income / spending", de: "Insel Einnahmen / Ausgaben")
                        : l.tr(zh: "\(wealthScopeTitle) 收入 / 花费", en: "\(wealthScopeTitle) income / spending", de: "\(wealthScopeTitle) Einnahmen / Ausgaben"))
                        .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.36))
                }
                Spacer()
                Text(vm.periodNet >= 0 ? "+\(vm.periodNet)🥥" : "\(vm.periodNet)🥥")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(vm.periodNet >= 0 ? incomeTint : spendingTint)
                    .ohanaNumericMotion(vm.periodNet)
            }

            OhanaMinimalMultiTrendChart(
                series: [
                    OhanaMinimalLineSeries(id: "income", points: incomePoints, tint: incomeTint),
                    OhanaMinimalLineSeries(id: "spending", points: spendingPoints, tint: spendingTint.opacity(0.86))
                ],
                yDomain: OhanaChartStyle.yDomain(
                    values: allValues,
                    includeZero: true,
                    paddingRatio: 0.10,
                    minimumSpan: 5
                ),
                progress: chartProgress,
                showsLatestPoint: true,
                drawProgress: chartProgress
            )
            .frame(height: 150)

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle().fill(incomeTint).frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    Text(l.tr(zh: "+\(vm.periodIncome) 收入", en: "+\(vm.periodIncome) income", de: "+\(vm.periodIncome) Einnahmen"))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.58))
                }
                HStack(spacing: 5) {
                    Circle().fill(spendingTint.opacity(0.86)).frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    Text(l.tr(zh: "-\(vm.periodSpending) 花费", en: "-\(vm.periodSpending) spending", de: "-\(vm.periodSpending) Ausgaben"))
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.58))
                }
                Spacer()
            }
        }
    }

    // 空图表
    private var emptyChart: some View {
        VStack(spacing: 12) {
            Text("🥥")
                .font(OhanaFont.adaptive(size: 52))
            Text(l.tr(zh: "立刻去打卡赚取第一桶金吧！", en: "Log a check-in to earn the first coconuts.", de: "Erfasse einen Check-in für die ersten Kokosnüsse."))
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.ohanaCardSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(spacing: 0) {
            if vm.leaderboard.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 36))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                    Text(SingleMemberFamilyShapePresentation.wealthEmptyText(
                        visibleMemberCount: visibleWealthHumans.count,
                        l: l
                    ))
                    .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.ohanaCardSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    HStack {
                        Text(SingleMemberFamilyShapePresentation.wealthSectionTitle(
                            rowCount: vm.leaderboard.count,
                            l: l
                        ))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)

                    LazyVStack(spacing: 10) {
                        ForEach(Array(vm.leaderboard.enumerated()), id: \.element.entityId) { idx, row in
                            leaderRow(rank: idx + 1, row: row, rowCount: vm.leaderboard.count)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Leader Row
    private func leaderRow(rank: Int, row: WealthLeaderRow, rowCount: Int) -> some View {
        let accent = vm.color(for: row.entityId)
        let showsRank = SingleMemberFamilyShapePresentation.showsWealthRank(rowCount: rowCount)
        let isFirst = showsRank && rank == 1
        let isSelected = selectedCoconutActorId == row.entityId
        return Button {
            withAnimation(GoMotion.feedback) {
                selectedCoconutActorId = isSelected ? nil : row.entityId
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(!showsRank ? Color.goPrimary :
                            rank == 1 ? Color.goPrimary :
                            rank == 2 ? Color(hex: "FFF44F").opacity(0.55) :
                            rank == 3 ? Color.goTeal.opacity(0.5) :
                            Color.ohanaCardSurface.opacity(0.74))
                        .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    if showsRank {
                        Text("\(rank)")
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(rank <= 3 ? Color.arkInk : Color.ohanaSecondaryText)
                    } else {
                        Image(systemName: "checkmark.seal.fill") // a11y: allow decorative account badge; row text carries the accessible meaning
                            .accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                            .foregroundStyle(Color.arkInk)
                    }
                }

                ZStack {
                    if isFirst {
                        Circle()
                            .fill(Color.goPrimary.opacity(0.35))
                            .frame(width: 46, height: 46)
                            .blur(radius: 6)
                        Circle()
                            .strokeBorder(Color.goPrimary, lineWidth: 2)
                            .frame(width: 42, height: 42) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    }
                    Text(row.emoji)
                        .font(OhanaFont.adaptive(size: 20))
                        .frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                        .background(accent.opacity(0.12), in: Circle())
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.name)
                        .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.ohanaCardSurfaceElevated.opacity(0.76)).frame(height: 4)
                            Capsule()
                                .fill(accent)
                                .frame(width: max(4, geo.size.width * row.percentage), height: 4)
                        }
                    }
                    .frame(height: 4)
                    HStack(spacing: 8) {
                        leaderStatPill(text: "+\(row.periodIncome)", tint: Color.goPrimary)
                        leaderStatPill(text: "-\(row.periodSpending)", tint: Color.goRed)
                    }
                }

                Spacer(minLength: 8)

                Text("\(row.amount)🥥")
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background((isSelected ? Color.goPrimary : accent).opacity(isSelected ? 0.24 : 0.14), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.goPrimary.opacity(0.16) : Color.ohanaCardSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                        .stroke(Color.goPrimary.opacity(0.85), lineWidth: 1.2)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func leaderStatPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .ohanaNumericMotion(text)
    }
}

#Preview {
    NavigationStack {
        IslandWealthDashboardView()
    }
    .modelContainer(SharedModelContainer.make())
}
