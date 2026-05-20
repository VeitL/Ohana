//
//  IslandWeightDashboard.swift
//  Ohana
//
//  全岛体重详情页 — Bento Box 风格数据看板
//  百分比折线图 + 趣味干饭王/自律王 + 全岛总质量 + 个体 Sparkline
//

import SwiftUI
import SwiftData

// MARK: - Sparkline Data
private struct SparkPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}

private struct IslandWeightTrendPoint: Identifiable, Hashable {
    let id: String
    let date: Date
    let value: Double
}

private enum IslandWeightEntryRoute: Identifiable {
    case pet(Pet)
    case human(Human)

    var id: String {
        switch self {
        case .pet(let pet): return "pet:\(pet.id.uuidString)"
        case .human(let human): return "human:\(human.id.uuidString)"
        }
    }

    var target: GenericWeightEntrySheet.Target {
        switch self {
        case .pet(let pet): return .pet(pet)
        case .human(let human): return .human(human)
        }
    }
}

private struct AnimatedWeightSparkline: View {
    let history: [SparkPoint]
    let accentColor: Color
    @State private var revealProgress: CGFloat = 0

    private var animationKey: String {
        history
            .map { "\($0.date.timeIntervalSince1970):\(String(format: "%.3f", $0.weight))" }
            .joined(separator: "|")
    }

    private func playAnimation() {
        revealProgress = 0
        withAnimation(GoMotion.page) {
            revealProgress = 1
        }
    }

    var body: some View {
        OhanaMinimalTrendChart(
            points: history.map { OhanaMinimalChartPoint(date: $0.date, value: $0.weight, id: $0.id.uuidString) },
            tint: accentColor,
            progress: Double(revealProgress),
            showsLatestPoint: false
        )
        .onAppear { playAnimation() }
        .onChange(of: animationKey) { _, _ in playAnimation() }
    }
}

// MARK: - Main View
struct IslandWeightDashboard: View {
    /// When false, skips the outer NavigationStack and nav bar — for embedding inside FeatureAggregateView.
    var standalone: Bool = true

    @Environment(\.dismiss)       private var dismiss
    @Environment(\.modelContext)  private var modelContext
    @Environment(\.colorScheme)   private var colorScheme
    @Query(sort: \Pet.name)       private var pets:   [Pet]
    @Query(sort: \Human.name)     private var humans: [Human]
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    @State private var vm = IslandUnifiedStatsViewModel()
    @State private var weightTimeRange: WeightTimeFilter = .days30
    @State private var selectedSeriesID: String? = nil
    @State private var chartRevealProgress: CGFloat = 0
    @State private var activeWeightEntryRoute: IslandWeightEntryRoute? = nil

    enum WeightTimeFilter: String, CaseIterable, Identifiable {
        case days7  = "7"
        case days30 = "30"
        case days90 = "90"
        case all   = "全部"
        var id: String { rawValue }

        var dayCount: Int? {
            switch self {
            case .days7: return 7
            case .days30: return 30
            case .days90: return 90
            case .all: return nil
            }
        }
    }

    private let humanColor = Color.goPrimary
    /// 无法匹配到宠物档案时的折线色（重名/数据残留等）
    private let petColorFallback = Color(hex: "80FFEA")

    private func color(forSeriesID seriesID: String, isHuman: Bool) -> Color {
        if seriesID.hasPrefix("human:"),
           let u = UUID(uuidString: String(seriesID.dropFirst(6))),
           let human = visibleWeightHumans.first(where: { $0.id == u }) {
            return Color(hex: human.safeThemeColorHex)
        }
        if seriesID.hasPrefix("pet:"),
           let u = UUID(uuidString: String(seriesID.dropFirst(4))),
           let pet = pets.first(where: { $0.id == u }) {
            return Color(hex: pet.safeThemeColorHex)
        }
        return isHuman ? humanColor : petColorFallback
    }

    // 只显示 shouldShowOnHome 的人类
    private var visibleHumans: [Human] {
        humans.filter { $0.shouldShowOnHome }
    }

    private var visiblePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var visibleWeightHumans: [Human] {
        PrivacyService.unlockedHumans(for: .weight, from: visibleHumans, viewedBy: activeHumanId)
    }

    private var privateVisibleWeightHumans: [Human] {
        visibleWeightHumans.filter { PrivacyService.isPubliclyHidden(.weight, for: $0) }
    }

    private var visibleWeightHumanSignature: String {
        visibleWeightHumans
            .map { "\($0.id.uuidString):\($0.privateFieldsRaw):\($0.weightLogs.count)" }
            .joined(separator: "|")
    }

    // 自适应文字颜色
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.45) : .black.opacity(0.4)
    }

    private var visibleSeriesIDs: Set<String> {
        var ids = Set(visiblePets.map { "pet:\($0.id.uuidString)" })
        ids.formUnion(visibleWeightHumans.map { "human:\($0.id.uuidString)" })
        return ids
    }

    // 当前总量 / 选中成员最新体重
    private var totalIslandWeightKg: Double {
        if let selectedSeriesID,
           let latest = latestWeight(for: selectedSeriesID) {
            return latest
        }
        let petWeight  = visiblePets.compactMap { $0.weightLogs.sorted { $0.date > $1.date }.first?.weightInKg }.reduce(0, +)
        let humanWeight = visibleWeightHumans.compactMap { $0.weightLogs.sorted { $0.date > $1.date }.first?.weight }.reduce(0, +)
        return petWeight + humanWeight
    }

    // 轻量趣味类比
    private var weightComparison: String {
        let kg = totalIslandWeightKg
        if      kg <= 0  { return "等待第一条体重" }
        else if kg < 10  { return "≈ \(max(1, Int(kg / 0.5))) 只兔子" }
        else if kg < 50  { return "≈ \(max(1, Int(kg / 10))) 只大型犬" }
        else if kg < 120 { return "≈ \(String(format: "%.1f", kg / 70)) 个成年人" }
        else if kg < 300 { return "≈ \(max(1, Int(kg / 136))) 只大猩猩" }
        else             { return "≈ 半头大象" }
    }

    var body: some View {
        dashboardBody
            .onAppear { reloadDashboard() }
            .onChange(of: pets.count) { _, _ in reloadDashboard() }
            .onChange(of: humans.count) { _, _ in reloadDashboard() }
            .onChange(of: activeHumanIdStr) { _, _ in reloadDashboard() }
            .onChange(of: visibleWeightHumanSignature) { _, _ in reloadDashboard() }
    }

    private func reloadDashboard() {
        if let selectedSeriesID,
           selectedSeriesID.hasPrefix("human:"),
           !visibleWeightHumans.contains(where: { selectedSeriesID == "human:\($0.id.uuidString)" }) {
            self.selectedSeriesID = nil
        }
        vm.load(modelContext: modelContext, pets: pets, humans: visibleWeightHumans)
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            NavigationStack {
                ZStack {
                    OhanaAppBackground().ignoresSafeArea()
                    scrollContent
                }
                .ignoresSafeArea(edges: .top)
                .navigationBarHidden(true)
            }
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if standalone { navBar }
                privateWeightNotice
                weightPlanetHero
                memberSelector
                weightHeroCard
                weightBadgeStrip
                individualSparklineCard
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, standalone ? 0 : 14)
        }
        .overlay {
            if let activeWeightEntryRoute {
                GenericWeightEntrySheet(
                    target: activeWeightEntryRoute.target,
                    onSaved: {
                        reloadDashboard()
                    },
                    onDismiss: {
                        withAnimation(GoMotion.feedback) {
                            self.activeWeightEntryRoute = nil
                        }
                    }
                )
                .id(activeWeightEntryRoute.id)
                .zIndex(30)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(primaryText)
                    .frame(width: 40, height: 40)
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
            Text("体重星球")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(primaryText)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 50)
    }

    // MARK: - Entity Selector
    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                weightEntityChip(
                    title: "全部",
                    icon: "sparkles",
                    tint: Color.goLime,
                    isSelected: selectedSeriesID == nil
                ) {
                    selectedSeriesID = nil
                }

                ForEach(visiblePets) { pet in
                    let seriesID = "pet:\(pet.id.uuidString)"
                    weightEntityChip(
                        title: pet.name,
                        avatar: { FMPetAvatar(pet: pet, size: 28) },
                        tint: Color(hex: pet.safeThemeColorHex),
                        isSelected: selectedSeriesID == seriesID
                    ) {
                        selectedSeriesID = seriesID
                    }
                }

                ForEach(visibleWeightHumans) { human in
                    let seriesID = "human:\(human.id.uuidString)"
                    weightEntityChip(
                        title: human.name,
                        avatar: { humanAvatarView(human, size: 28) },
                        tint: Color(hex: human.safeThemeColorHex),
                        isSelected: selectedSeriesID == seriesID
                    ) {
                        selectedSeriesID = seriesID
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var privateWeightNotice: some View {
        if !privateVisibleWeightHumans.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 26, height: 26)
                    .background(Color.goYellow.opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("包含仅自己可见的体重数据")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text(privateWeightNoticeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color.goYellow.opacity(colorScheme == .dark ? 0.12 : 0.18),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.goYellow.opacity(0.24), lineWidth: 1)
            )
        }
    }

    private var privateWeightNoticeText: String {
        let names = privateVisibleWeightHumans.map(\.name).joined(separator: "、")
        return "\(names) 的体重只会在本人账户下显示，其他成员看不到。"
    }

    private func weightEntityChip(
        title: String,
        icon: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                    .frame(width: 26, height: 26)
                    .background(isSelected ? Color.arkInk.opacity(0.16) : tint.opacity(0.18), in: Circle())
                weightEntityChipText(title: title, isSelected: isSelected)
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .background(isSelected ? tint : Color.ohanaControlFill.opacity(0.74), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func weightEntityChip<Avatar: View>(
        title: String,
        @ViewBuilder avatar: () -> Avatar,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                avatar()
                weightEntityChipText(title: title, isSelected: isSelected)
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .padding(.vertical, 8)
            .background(isSelected ? tint : Color.ohanaControlFill.opacity(0.74), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func weightEntityChipText(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        .foregroundStyle(isSelected ? .black : .white)
    }

    // MARK: - 首屏：体重星球
    private var weightPlanetHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: selectedSeriesID == nil ? "globe.asia.australia.fill" : "scalemass.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color.arkInk)
                            .frame(width: 34, height: 34)
                            .background(chartAccentColor, in: Circle())

                        Text(selectedSeriesID == nil ? "体重星球" : selectedEntityName)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(primaryText)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", latestChartValue ?? totalIslandWeightKg))
                            .font(.system(size: 58, weight: .black, design: .rounded))
                            .foregroundStyle(primaryText)
                            .ohanaNumericMotion(latestChartValue ?? totalIslandWeightKg)
                            .minimumScaleFactor(0.55)
                            .lineLimit(1)
                        Text("kg")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(secondaryText)
                    }

                    HStack(spacing: 8) {
                        trendDeltaPill
                        Text(selectedSeriesID == nil ? weightComparison : selectedEntitySubtitle)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                recordWeightActionButton
            }
        }
        .padding(.top, standalone ? 4 : 0)
    }

    private var recordWeightActionButton: some View {
        Button {
            if let route = selectedWeightEntryRoute {
                withAnimation(GoMotion.feedback) {
                    activeWeightEntryRoute = route
                }
            } else if let first = buildSparklineEntries(includeSelection: false).first {
                withAnimation(GoMotion.feedback) {
                    selectedSeriesID = first.seriesID
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: selectedWeightEntryRoute == nil ? "person.crop.circle.badge.plus" : "plus")
                    .font(.system(size: 13, weight: .black))
                Text(selectedWeightEntryRoute == nil ? "选成员" : "记录")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(buildSparklineEntries(includeSelection: false).isEmpty && selectedWeightEntryRoute == nil)
        .opacity(buildSparklineEntries(includeSelection: false).isEmpty && selectedWeightEntryRoute == nil ? 0.55 : 1)
    }

    @ViewBuilder
    private var trendDeltaPill: some View {
        let delta = periodDeltaKg
        HStack(spacing: 5) {
            Image(systemName: deltaIcon(for: delta))
                .font(.system(size: 10, weight: .black))
            Text(deltaText(for: delta))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .ohanaNumericMotion(deltaText(for: delta))
        }
        .foregroundStyle(deltaTint(for: delta))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(deltaTint(for: delta).opacity(colorScheme == .dark ? 0.16 : 0.13), in: Capsule())
    }

    private func deltaText(for delta: Double?) -> String {
        guard let delta else { return "新数据" }
        if abs(delta) < 0.05 { return "稳定" }
        return "\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta))kg"
    }

    private func deltaIcon(for delta: Double?) -> String {
        guard let delta else { return "sparkle" }
        if abs(delta) < 0.05 { return "equal.circle.fill" }
        return delta > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
    }

    private func deltaTint(for delta: Double?) -> Color {
        guard let delta else { return Color.goPrimary }
        if abs(delta) < 0.05 { return Color.goTeal }
        return delta > 0 ? Color.goOrange : Color.goBlue
    }

    // MARK: - 模块 1: 极简趋势
    private var weightHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSeriesID == nil ? "全岛总质量趋势" : "体重趋势")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text(weightTimeRange == .all ? "全部记录" : "近 \(weightTimeRange.rawValue) 天")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryText)
                }
                Spacer()
                rangeSelector
            }

            if chartTrendPoints.isEmpty {
                emptyState("记录体重后出现趋势")
                    .frame(height: 188)
            } else {
                weightTrendChart
                    .frame(height: 188)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var rangeSelector: some View {
        HStack(spacing: 5) {
            ForEach(WeightTimeFilter.allCases) { range in
                Button {
                    withAnimation(GoMotion.feedback) {
                        weightTimeRange = range
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(weightTimeRange == range ? Color.arkInk : primaryText)
                        .frame(minWidth: range == .all ? 42 : 30)
                        .padding(.vertical, 7)
                        .background(weightTimeRange == range ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var filteredWeightAbsolutes: [WeightAbsolutePoint] {
        let now = Date()
        let cal = Calendar.current
        let cutoff = chartCutoff(from: now, calendar: cal)
        let selected = selectedSeriesID.map { sid in
            vm.weightAbsolutes.filter { $0.seriesID == sid }
        } ?? vm.weightAbsolutes.filter { visibleSeriesIDs.contains($0.seriesID) }
        guard let c = cutoff else { return selected }
        return selected.filter { $0.date >= c }
    }

    private var chartTrendPoints: [IslandWeightTrendPoint] {
        if let selectedSeriesID {
            return selectedWeightTrend(seriesID: selectedSeriesID)
        }
        return aggregateWeightTrend()
    }

    private var chartAnimationKey: String {
        chartTrendPoints
            .map { "\($0.id):\(String(format: "%.3f", $0.value))" }
            .joined(separator: "|")
    }

    private func playChartReveal() {
        chartRevealProgress = 0
        withAnimation(GoMotion.page) {
            chartRevealProgress = 1
        }
    }

    private var weightTrendChart: some View {
        OhanaMinimalTrendChart(
            points: chartTrendPoints.map {
                OhanaMinimalChartPoint(date: $0.date, value: $0.value, id: $0.id)
            },
            xDomain: chartXDomainForTrend,
            yDomain: chartYDomainForTrend,
            tint: chartAccentColor,
            progress: Double(chartRevealProgress),
            showsLatestPoint: true,
            yReferenceLineCount: 3,
            yReferenceFormatter: { OhanaChartStyle.weightReferenceLabel(kilograms: $0, domain: $1) }
        )
        .frame(maxWidth: .infinity)
        .onAppear { playChartReveal() }
        .onChange(of: chartAnimationKey) { _, _ in playChartReveal() }
    }

    private var latestChartValue: Double? {
        chartTrendPoints.last?.value
    }

    private var periodDeltaKg: Double? {
        guard chartTrendPoints.count >= 2,
              let first = chartTrendPoints.first?.value,
              let last = chartTrendPoints.last?.value else { return nil }
        return last - first
    }

    private var chartAccentColor: Color {
        guard let selectedSeriesID else { return Color.goPrimary }
        return color(forSeriesID: selectedSeriesID, isHuman: selectedSeriesID.hasPrefix("human:"))
    }

    private var chartYDomainForTrend: ClosedRange<Double> {
        OhanaChartStyle.yDomain(
            values: chartTrendPoints.map(\.value),
            includeZero: false,
            paddingRatio: 0.16,
            minimumSpan: selectedSeriesID == nil ? 4 : 1
        )
    }

    private var chartXDomainForTrend: ClosedRange<Date>? {
        guard let first = chartTrendPoints.first?.date,
              let last = chartTrendPoints.last?.date else { return nil }
        if first == last {
            return first.addingTimeInterval(-43_200)...last.addingTimeInterval(43_200)
        }
        return first...last
    }

    private func chartCutoff(from now: Date = Date(), calendar cal: Calendar = .current) -> Date? {
        guard let days = weightTimeRange.dayCount else { return nil }
        let today = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: -(days - 1), to: today)
    }

    private func selectedWeightTrend(seriesID: String) -> [IslandWeightTrendPoint] {
        filteredWeightAbsolutes
            .filter { $0.seriesID == seriesID }
            .sorted { $0.date < $1.date }
            .map {
                IslandWeightTrendPoint(
                    id: $0.id.uuidString,
                    date: $0.date,
                    value: $0.weight
                )
            }
    }

    private func aggregateWeightTrend() -> [IslandWeightTrendPoint] {
        let allPoints = vm.weightAbsolutes
            .filter { visibleSeriesIDs.contains($0.seriesID) }
            .sorted { $0.date < $1.date }
        guard !allPoints.isEmpty else { return [] }

        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let earliest = cal.startOfDay(for: allPoints.first?.date ?? today)
        let start = chartCutoff(from: now, calendar: cal) ?? earliest
        let daySpan = max(0, cal.dateComponents([.day], from: start, to: today).day ?? 0)
        let stride = max(1, Int(ceil(Double(max(daySpan, 1)) / 90.0)))
        let grouped = Dictionary(grouping: allPoints, by: \.seriesID)
            .mapValues { $0.sorted { $0.date < $1.date } }

        var result: [IslandWeightTrendPoint] = []
        var offset = 0
        while offset <= daySpan {
            guard let bucketDate = cal.date(byAdding: .day, value: offset, to: start) else { break }
            let bucketEnd = cal.date(byAdding: .day, value: 1, to: bucketDate) ?? bucketDate
            var total = 0.0
            var count = 0

            for series in grouped.values {
                if let latest = series.last(where: { $0.date < bucketEnd }) {
                    total += latest.weight
                    count += 1
                }
            }

            if count > 0 {
                result.append(
                    IslandWeightTrendPoint(
                        id: "all-\(Int(bucketDate.timeIntervalSinceReferenceDate))",
                        date: bucketDate,
                        value: total
                    )
                )
            }
            offset += stride
        }

        if result.last?.date != today {
            var total = 0.0
            var count = 0
            for series in grouped.values {
                if let latest = series.last(where: { $0.date <= now }) {
                    total += latest.weight
                    count += 1
                }
            }
            if count > 0 {
                result.append(IslandWeightTrendPoint(id: "all-now", date: now, value: total))
            }
        }
        return result
    }

    // MARK: - 模块 2: 轻量变化徽章
    private var weightBadgeStrip: some View {
        HStack(spacing: 10) {
            rankingPill(
                title: "增长",
                ranking: vm.gainChampion,
                accent: Color.goOrange,
                fallback: "暂无"
            )
            rankingPill(
                title: "下降",
                ranking: vm.lossChampion,
                accent: Color.goBlue,
                fallback: "暂无"
            )
        }
    }

    private func rankingPill(title: String, ranking: FameRanking?, accent: Color, fallback: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(accent)
            if let ranking {
                Text(ranking.emoji)
                    .font(.system(size: 16))
                Text(ranking.entityName)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                Text("\(ranking.deltaPercent >= 0 ? "+" : "")\(String(format: "%.1f", ranking.deltaPercent))%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
            } else {
                Text(fallback)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryText)
            }
        }
        .foregroundStyle(primaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    // MARK: - 模块 3: 个体 Sparkline 清单
    private var individualSparklineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("成员", systemImage: "person.2.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                Spacer()
                Text("\(buildSparklineEntries(includeSelection: false).count)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(secondaryText)
                    .ohanaNumericMotion(buildSparklineEntries(includeSelection: false).count)
            }

            let allEntries = buildSparklineEntries()
            if allEntries.isEmpty {
                emptyState("还没有体重记录")
                    .frame(minHeight: 86)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(allEntries) { entry in
                        sparklineRow(entry: entry)
                    }
                }
            }
        }
    }

    private struct SparkEntry: Identifiable {
        let id: String
        let seriesID: String
        let emoji:    String
        let name:     String
        let current:  Double
        let delta:    Double?
        let isHuman:  Bool
        let history:  [SparkPoint]
        let accentColor: Color
        let petRef:   Pet?
        let humanRef: Human?
    }

    private func buildSparklineEntries(includeSelection: Bool = true) -> [SparkEntry] {
        var result: [SparkEntry] = []
        for pet in visiblePets {
            let seriesID = "pet:\(pet.id.uuidString)"
            if includeSelection, let selectedSeriesID, selectedSeriesID != seriesID { continue }
            let sorted = pet.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { continue }
            let pts = sorted.map { SparkPoint(date: $0.date, weight: $0.weight) }
            result.append(SparkEntry(
                id: seriesID,
                seriesID: seriesID,
                emoji: pet.avatarEmoji, name: pet.name,
                current: sorted.last!.weightInKg,
                delta: deltaForSeries(seriesID),
                isHuman: false,
                history: pts,
                accentColor: Color(hex: pet.safeThemeColorHex),
                petRef: pet, humanRef: nil
            ))
        }
        for human in visibleWeightHumans {
            let seriesID = "human:\(human.id.uuidString)"
            if includeSelection, let selectedSeriesID, selectedSeriesID != seriesID { continue }
            let sorted = human.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { continue }
            let pts = sorted.map { SparkPoint(date: $0.date, weight: $0.weight) }
            result.append(SparkEntry(
                id: seriesID,
                seriesID: seriesID,
                emoji: human.avatarEmoji, name: human.name,
                current: sorted.last!.weight,
                delta: deltaForSeries(seriesID),
                isHuman: true,
                history: pts,
                accentColor: Color(hex: human.safeThemeColorHex),
                petRef: nil, humanRef: human
            ))
        }
        return result
    }

    private func sparklineRow(entry: SparkEntry) -> some View {
        let rowContent = HStack(spacing: 14) {
            rowAvatar(entry)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%.1f", entry.current))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(entry.accentColor)
                    Text("kg")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(tertiaryText)
                    Text(deltaText(for: entry.delta))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(deltaTint(for: entry.delta))
                }
            }

            Spacer()

            if entry.history.count > 1 {
                AnimatedWeightSparkline(history: entry.history, accentColor: entry.accentColor)
                    .frame(width: 104, height: 44)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tertiaryText.opacity(0.6))
        }
        .padding(14)
        .frame(minHeight: 86)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.ohanaCardSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(entry.accentColor.opacity(0.20), lineWidth: selectedSeriesID == entry.seriesID ? 1.5 : 0)
        }
        .contentShape(Rectangle())

        return Group {
            if let pet = entry.petRef {
                NavigationLink(destination: WeightHistoryView(pet: pet)) {
                    rowContent
                }
                .buttonStyle(ScaleButtonStyle())
            } else if let human = entry.humanRef {
                NavigationLink(destination: HumanWeightHistoryView(human: human)) {
                    rowContent
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                rowContent
            }
        }
    }

    @ViewBuilder
    private func rowAvatar(_ entry: SparkEntry) -> some View {
        if let pet = entry.petRef {
            FMPetAvatar(pet: pet, size: 46)
        } else if let human = entry.humanRef {
            humanAvatarView(human, size: 46)
        } else {
            Text(entry.emoji)
                .font(.system(size: 24))
                .frame(width: 46, height: 46)
                .background(entry.accentColor.opacity(0.16), in: Circle())
        }
    }

    // MARK: - Empty State
    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(tertiaryText)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var selectedEntityName: String {
        guard let selectedSeriesID else { return "全部成员" }
        if selectedSeriesID.hasPrefix("pet:"),
           let id = UUID(uuidString: String(selectedSeriesID.dropFirst(4))),
           let pet = pets.first(where: { $0.id == id }) {
            return pet.name
        }
        if selectedSeriesID.hasPrefix("human:"),
           let id = UUID(uuidString: String(selectedSeriesID.dropFirst(6))),
           let human = visibleWeightHumans.first(where: { $0.id == id }) {
            return human.name
        }
        return "成员"
    }

    private var selectedEntitySubtitle: String {
        guard let selectedSeriesID else { return weightComparison }
        let count = vm.weightAbsolutes.filter { $0.seriesID == selectedSeriesID }.count
        return count == 0 ? "还没有体重记录" : "\(count) 条体重记录"
    }

    private var selectedWeightEntryRoute: IslandWeightEntryRoute? {
        guard let selectedSeriesID else { return nil }
        if selectedSeriesID.hasPrefix("pet:"),
           let id = UUID(uuidString: String(selectedSeriesID.dropFirst(4))),
           let pet = visiblePets.first(where: { $0.id == id }) {
            return .pet(pet)
        }
        if selectedSeriesID.hasPrefix("human:"),
           let id = UUID(uuidString: String(selectedSeriesID.dropFirst(6))),
           let human = visibleWeightHumans.first(where: { $0.id == id }) {
            return .human(human)
        }
        return nil
    }

    private func deltaForSeries(_ seriesID: String) -> Double? {
        let points = selectedWeightTrend(seriesID: seriesID)
        guard points.count >= 2,
              let first = points.first?.value,
              let last = points.last?.value else { return nil }
        return last - first
    }

    private func latestWeight(for seriesID: String) -> Double? {
        vm.weightAbsolutes
            .filter { $0.seriesID == seriesID }
            .max(by: { $0.date < $1.date })?
            .weight
    }

    private func humanAvatarView(_ human: Human, size: CGFloat) -> some View {
        let color = Color(hex: human.safeThemeColorHex)
        return ZStack {
            Circle().fill(color.opacity(0.24)).frame(width: size, height: size)
            if let data = human.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(String(human.name.prefix(1)))
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundStyle(color)
            }
        }
    }
}

#Preview {
    IslandWeightDashboard()
        .modelContainer(SharedModelContainer.make())
}
