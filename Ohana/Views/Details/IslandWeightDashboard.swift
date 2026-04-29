//
//  IslandWeightDashboard.swift
//  Ohana
//
//  全岛体重详情页 — Bento Box 风格数据看板
//  百分比折线图 + 趣味干饭王/自律王 + 全岛总质量 + 个体 Sparkline
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Sparkline Data
private struct SparkPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
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
        withAnimation(.easeOut(duration: 0.7)) {
            revealProgress = 1
        }
    }

    var body: some View {
        Chart(history) { point in
            LineMark(
                x: .value("date", point.date),
                y: .value("kg", point.weight)
            )
            .foregroundStyle(accentColor)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle()
                    .frame(width: max(8, geo.size.width * revealProgress))
            }
        }
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Query(sort: \Pet.name)       private var pets:   [Pet]
    @Query(sort: \Human.name)     private var humans: [Human]

    @State private var vm = IslandUnifiedStatsViewModel()
    @State private var weightTimeRange: WeightTimeFilter = .all
    @State private var selectedSeriesID: String? = nil
    @State private var chartRevealProgress: CGFloat = 0

    enum WeightTimeFilter: String, CaseIterable, Identifiable {
        case week  = "周"
        case month = "月"
        case year  = "年"
        case all   = "全部"
        var id: String { rawValue }
    }

    private let humanColor = Color.goPrimary
    /// 无法匹配到宠物档案时的折线色（重名/数据残留等）
    private let petColorFallback = Color(hex: "80FFEA")

    private func color(forSeriesID seriesID: String, isHuman: Bool) -> Color {
        if seriesID.hasPrefix("human:"),
           let u = UUID(uuidString: String(seriesID.dropFirst(6))),
           let human = visibleHumans.first(where: { $0.id == u }) {
            return Color(hex: human.themeColorHex)
        }
        if seriesID.hasPrefix("pet:"),
           let u = UUID(uuidString: String(seriesID.dropFirst(4))),
           let pet = pets.first(where: { $0.id == u }) {
            return Color(hex: pet.themeColorHex)
        }
        return isHuman ? humanColor : petColorFallback
    }

    /// Y 轴留白，避免折线贴顶/贴底被裁切
    private var chartYDomain: ClosedRange<Double> {
        let w = filteredWeightAbsolutes.map(\.weight)
        guard let mn = w.min(), let mx = w.max(), !w.isEmpty else { return 0...1 }
        if mn == mx {
            let pad = max(abs(mn) * 0.08, 0.5)
            return (mn - pad)...(mx + pad)
        }
        let span = mx - mn
        let pad = max(span * 0.14, 0.3)
        return (mn - pad)...(mx + pad)
    }

    /// X 轴略扩展（仅在有 `filteredWeightAbsolutes` 时与主图一起使用）
    private var chartXDomainResolved: ClosedRange<Date> {
        let dates = filteredWeightAbsolutes.map(\.date)
        let minD = dates.min() ?? Date()
        let maxD = dates.max() ?? Date()
        if minD == maxD {
            let cal = Calendar.current
            let start = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: minD)) ?? minD
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: maxD)) ?? maxD
            return start...end
        }
        let span = maxD.timeIntervalSince(minD)
        let pad = max(span * 0.03, 86_400) // 3% 或至少约一天
        return minD.addingTimeInterval(-pad)...maxD.addingTimeInterval(pad)
    }

    // 只显示 shouldShowOnHome 的人类
    private var visibleHumans: [Human] {
        humans.filter { $0.shouldShowOnHome }
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

    // 全岛总质量
    private var totalIslandWeightKg: Double {
        if let selectedSeriesID,
           let latest = latestWeight(for: selectedSeriesID) {
            return latest
        }
        let petWeight  = pets.compactMap   { $0.weightLogs.sorted { $0.date > $1.date }.first?.weight }.reduce(0, +)
        let humanWeight = visibleHumans.compactMap { $0.weightLogs.sorted { $0.date > $1.date }.first?.weight }.reduce(0, +)
        return petWeight + humanWeight
    }

    // 趣味类比文案
    private var weightComparison: String {
        let kg = totalIslandWeightKg
        if      kg < 10  { return "≈ \(Int(kg / 0.5)) 只成年兔子 🐰" }
        else if kg < 50  { return "≈ \(Int(kg / 10)) 只大型犬 🐕" }
        else if kg < 120 { return "≈ \(String(format: "%.1f", kg / 70)) 个成年人 👤" }
        else if kg < 300 { return "≈ \(Int(kg / 136)) 只成年大猩猩 🦍" }
        else             { return "≈ 半头大象 🐘" }
    }

    var body: some View {
        dashboardBody
            .onAppear { vm.load(modelContext: modelContext, pets: pets, humans: visibleHumans) }
            .onChange(of: pets.count)   { _, _ in vm.load(modelContext: modelContext, pets: pets, humans: visibleHumans) }
            .onChange(of: humans.count) { _, _ in vm.load(modelContext: modelContext, pets: pets, humans: visibleHumans) }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            NavigationStack {
                ZStack {
                    ArkBackgroundView().ignoresSafeArea()
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
            VStack(spacing: 20) {
                if standalone { navBar }
                memberSelector
                weightHeroCard
                funBentoRow
                individualSparklineCard
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, standalone ? 0 : 14)
        }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(primaryText)
                    .frame(width: 36, height: 36)
                    .goGlassBackground(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("全岛体重")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(primaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 64)
    }

    // MARK: - Entity Selector
    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                weightEntityChip(
                    title: "全部",
                    subtitle: "\(buildSparklineEntries(includeSelection: false).count) 位成员",
                    icon: "square.grid.2x2.fill",
                    tint: Color.goLime,
                    isSelected: selectedSeriesID == nil
                ) {
                    selectedSeriesID = nil
                }

                ForEach(pets.filter { !$0.hasPassedAway }) { pet in
                    let seriesID = "pet:\(pet.id.uuidString)"
                    weightEntityChip(
                        title: pet.name,
                        subtitle: latestWeightText(for: seriesID),
                        avatar: { FMPetAvatar(pet: pet, size: 26) },
                        tint: Color(hex: pet.themeColorHex),
                        isSelected: selectedSeriesID == seriesID
                    ) {
                        selectedSeriesID = seriesID
                    }
                }

                ForEach(visibleHumans) { human in
                    let seriesID = "human:\(human.id.uuidString)"
                    weightEntityChip(
                        title: human.name,
                        subtitle: latestWeightText(for: seriesID),
                        avatar: { humanAvatarView(human, size: 26) },
                        tint: Color(hex: human.themeColorHex),
                        isSelected: selectedSeriesID == seriesID
                    ) {
                        selectedSeriesID = seriesID
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func weightEntityChip(
        title: String,
        subtitle: String,
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
                    .background(isSelected ? .black.opacity(0.12) : tint.opacity(0.18), in: Circle())
                weightEntityChipText(title: title, subtitle: subtitle, isSelected: isSelected)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(isSelected ? tint : Color.white.opacity(0.11), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func weightEntityChip<Avatar: View>(
        title: String,
        subtitle: String,
        @ViewBuilder avatar: () -> Avatar,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                avatar()
                weightEntityChipText(title: title, subtitle: subtitle, isSelected: isSelected)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .background(isSelected ? tint : Color.white.opacity(0.11), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func weightEntityChipText(title: String, subtitle: String, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1)
                .opacity(0.68)
        }
        .foregroundStyle(isSelected ? .black : .white)
    }

    // MARK: - 模块 1: 体重趋势主卡
    private var weightHeroCard: some View {
        glassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedSeriesID == nil ? "全员体重趋势" : "\(selectedEntityName) 的体重趋势")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(String(format: "%.1f", totalIslandWeightKg))
                                .font(.system(size: 46, weight: .black, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.goYellow : Color.goOrange)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("kg")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(secondaryText)
                        }

                        Text(selectedSeriesID == nil ? weightComparison : selectedEntitySubtitle)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(secondaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Picker("", selection: $weightTimeRange) {
                        ForEach(WeightTimeFilter.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 156)
                }

                if filteredWeightAbsolutes.isEmpty {
                    emptyState("暂无体重数据\n记录后即可看到趋势曲线")
                        .frame(height: 220)
                } else {
                    weightAbsoluteLineChart
                    weightAbsoluteLegend
                }
            }
            .padding(18)
        }
    }

    private var filteredWeightAbsolutes: [WeightAbsolutePoint] {
        let now = Date()
        let cal = Calendar.current
        let cutoff: Date? = {
            let today = cal.startOfDay(for: now)
            switch weightTimeRange {
            case .week:  return cal.date(byAdding: .day,   value: -6,  to: today)
            case .month: return cal.date(byAdding: .month, value: -1,  to: today)
            case .year:  return cal.date(byAdding: .year,  value: -1,  to: today)
            case .all:   return nil
            }
        }()
        let selected = selectedSeriesID.map { sid in
            vm.weightAbsolutes.filter { $0.seriesID == sid }
        } ?? vm.weightAbsolutes
        guard let c = cutoff else { return selected }
        return selected.filter { $0.date >= c }
    }

    /// 按 `seriesID` 分线，避免同名多只宠物数据混成一条曲线
    private var filteredAbsoluteSeries: [(seriesID: String, displayName: String, points: [WeightAbsolutePoint], isHuman: Bool)] {
        let ids = Array(Set(filteredWeightAbsolutes.map(\.seriesID))).sorted()
        return ids.map { sid in
            let pts = filteredWeightAbsolutes
                .filter { $0.seriesID == sid }
                .sorted { $0.date < $1.date }
            let label = pts.first?.displayName ?? ""
            let isHuman = pts.first?.isHuman ?? false
            return (sid, label, pts, isHuman)
        }
    }

    private var chartAnimationKey: String {
        filteredAbsoluteSeries
            .map { sid, _, points, _ in
                let joined = points.map { "\($0.date.timeIntervalSince1970):\(String(format: "%.3f", $0.weight))" }
                    .joined(separator: ",")
                return "\(sid):\(joined)"
            }
            .joined(separator: "|")
    }

    private func playChartReveal() {
        chartRevealProgress = 0
        withAnimation(.easeOut(duration: 0.85)) {
            chartRevealProgress = 1
        }
    }

    private var weightAbsoluteLineChart: some View {
        Chart {
            ForEach(filteredAbsoluteSeries, id: \.seriesID) { series in
                let c = color(forSeriesID: series.seriesID, isHuman: series.isHuman)
                ForEach(series.points) { pt in
                    AreaMark(
                        x: .value("日期", pt.date),
                        y: .value("kg", pt.weight),
                        series: .value("s", series.seriesID)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [c.opacity(0.22), c.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                ForEach(series.points) { pt in
                    LineMark(
                        x: .value("日期", pt.date),
                        y: .value("kg", pt.weight),
                        series: .value("s", series.seriesID)
                    )
                    .foregroundStyle(c)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                }

                if let last = series.points.last {
                    PointMark(
                        x: .value("日期", last.date),
                        y: .value("kg", last.weight)
                    )
                    .foregroundStyle(c)
                    .symbolSize(36)
                }
            }
        }
        .chartXScale(domain: chartXDomainResolved)
        .chartYScale(domain: chartYDomain)
        .chartPlotStyle { plot in
            plot.padding(EdgeInsets(top: 16, leading: 6, bottom: 10, trailing: 10))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(tertiaryText)
                AxisGridLine().foregroundStyle(tertiaryText.opacity(0.12))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { val in
                if let d = val.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.1f", d))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(tertiaryText)
                    }
                }
                AxisGridLine().foregroundStyle(tertiaryText.opacity(0.12))
            }
        }
        .chartLegend(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: 224)
        .mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle()
                    .frame(width: max(12, geo.size.width * chartRevealProgress))
            }
        }
        .onAppear { playChartReveal() }
        .onChange(of: chartAnimationKey) { _, _ in playChartReveal() }
    }

    private var weightAbsoluteLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filteredAbsoluteSeries, id: \.seriesID) { series in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(forSeriesID: series.seriesID, isHuman: series.isHuman))
                            .frame(width: 16, height: 3)
                        Text(series.displayName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - 模块 2: 趣味 Bento（干饭王 + 全岛总质量）
    private var funBentoRow: some View {
        VStack(spacing: 12) {
            championsCard
            islandMassCard
        }
    }

    private var championsCard: some View {
        glassCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 2) {
                cardHeader(icon: "trophy.fill", title: "本月变化榜", subtitle: "按本月体重变化自动计算")

                HStack(spacing: 12) {
                    rankingTile(
                        title: "增长最多",
                        ranking: vm.gainChampion,
                        accent: colorScheme == .dark ? Color.goYellow : Color.goOrange,
                        fallback: "暂无增重数据"
                    )
                    rankingTile(
                        title: "下降最多",
                        ranking: vm.lossChampion,
                        accent: colorScheme == .dark ? Color.goTeal : Color.goBlue,
                        fallback: "暂无下降数据"
                    )
                }
            }
            .padding(16)
        }
    }

    private func rankingTile(title: String, ranking: FameRanking?, accent: Color, fallback: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(secondaryText)

            if let ranking {
                HStack(spacing: 8) {
                    Text(ranking.emoji)
                        .font(.system(size: 24))
                        .frame(width: 34, height: 34)
                        .background(accent.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ranking.entityName)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                        Text("\(ranking.deltaPercent >= 0 ? "+" : "")\(String(format: "%.1f", ranking.deltaPercent))%")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(accent)
                    }
                }
            } else {
                Text(fallback)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(accent.opacity(colorScheme == .dark ? 0.12 : 0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var islandMassCard: some View {
        glassCard(cornerRadius: 24) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.goLime.opacity(0.95), Color.goTeal.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 58, height: 58)
                    Image(systemName: selectedSeriesID == nil ? "scalemass.fill" : "person.text.rectangle.fill")
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(.black.opacity(0.82))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedSeriesID == nil ? "全岛总质量" : "当前体重")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                    Text(selectedSeriesID == nil ? "来自所有有体重记录的成员" : selectedEntityName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f", totalIslandWeightKg))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.goYellow : Color.goOrange)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("kg")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(secondaryText)
                }
            }
            .padding(16)
        }
    }

    // MARK: - 模块 3: 个体 Sparkline 清单
    private var individualSparklineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "waveform.path.ecg", title: "成员体重卡片", subtitle: "点进单个成员查看记录和新增体重")

            let allEntries = buildSparklineEntries()
            if allEntries.isEmpty {
                glassCard(cornerRadius: 24) {
                    emptyState("暂无个体体重数据")
                        .padding(24)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(allEntries) { entry in
                        sparklineRow(entry: entry)
                    }
                }
            }
        }
    }

    private func cardHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.goLime)
                .frame(width: 28, height: 28)
                .background(Color.goLime.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
        }
    }

    private struct SparkEntry: Identifiable {
        let id = UUID()
        let emoji:    String
        let name:     String
        let current:  Double
        let isHuman:  Bool
        let history:  [SparkPoint]
        let accentColor: Color
        let petRef:   Pet?
        let humanRef: Human?
    }

    private func buildSparklineEntries(includeSelection: Bool = true) -> [SparkEntry] {
        var result: [SparkEntry] = []
        for pet in pets {
            let seriesID = "pet:\(pet.id.uuidString)"
            if includeSelection, let selectedSeriesID, selectedSeriesID != seriesID { continue }
            let sorted = pet.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { continue }
            let pts = sorted.map { SparkPoint(date: $0.date, weight: $0.weight) }
            result.append(SparkEntry(
                emoji: pet.avatarEmoji, name: pet.name,
                current: sorted.last!.weight, isHuman: false,
                history: pts,
                accentColor: Color(hex: pet.themeColorHex),
                petRef: pet, humanRef: nil
            ))
        }
        for human in visibleHumans {
            let seriesID = "human:\(human.id.uuidString)"
            if includeSelection, let selectedSeriesID, selectedSeriesID != seriesID { continue }
            let sorted = human.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { continue }
            let pts = sorted.map { SparkPoint(date: $0.date, weight: $0.weight) }
            result.append(SparkEntry(
                emoji: human.avatarEmoji, name: human.name,
                current: sorted.last!.weight, isHuman: true,
                history: pts,
                accentColor: Color(hex: human.themeColorHex),
                petRef: nil, humanRef: human
            ))
        }
        return result
    }

    private func sparklineRow(entry: SparkEntry) -> some View {
        let rowContent = HStack(spacing: 14) {
            Text(entry.emoji)
                .font(.system(size: 24))
                .frame(width: 46, height: 46)
                .background(entry.accentColor.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", entry.current))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(entry.accentColor)
                    Text("kg")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(tertiaryText)
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
                .fill(entry.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(entry.accentColor.opacity(0.14), lineWidth: 1)
        }
        .contentShape(Rectangle())

        return Group {
            if let pet = entry.petRef {
                NavigationLink(destination: WeightHistoryView(pet: pet)) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else if let human = entry.humanRef {
                NavigationLink(destination: HumanWeightHistoryView(human: human)) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
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
           let human = visibleHumans.first(where: { $0.id == id }) {
            return human.name
        }
        return "成员"
    }

    private var selectedEntitySubtitle: String {
        guard let selectedSeriesID else { return weightComparison }
        let count = vm.weightAbsolutes.filter { $0.seriesID == selectedSeriesID }.count
        return count == 0 ? "还没有体重记录" : "\(count) 条体重记录"
    }

    private func latestWeight(for seriesID: String) -> Double? {
        vm.weightAbsolutes
            .filter { $0.seriesID == seriesID }
            .max(by: { $0.date < $1.date })?
            .weight
    }

    private func latestWeightText(for seriesID: String) -> String {
        guard let weight = latestWeight(for: seriesID) else { return "暂无记录" }
        return String(format: "%.1fkg", weight)
    }

    private func humanAvatarView(_ human: Human, size: CGFloat) -> some View {
        let color = Color(hex: human.themeColorHex.isEmpty ? "4ECDC4" : human.themeColorHex)
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
    
    // MARK: - Glass Card Helper
    @ViewBuilder
    private func glassCard<C: View>(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> C) -> some View {
        if reduceTransparency {
            // 无障碍降级：纯色不透明背景
            content()
                .background(Color(.systemBackground).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            // 浅色模式下更透明
            if colorScheme == .light {
                content()
                    .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                content()
                    .goGlassBackground(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }
}

#Preview {
    IslandWeightDashboard()
        .modelContainer(SharedModelContainer.make())
}
