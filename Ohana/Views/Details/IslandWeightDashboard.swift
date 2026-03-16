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
    @Environment(\.dismiss)       private var dismiss
    @Environment(\.modelContext)  private var modelContext
    @Environment(\.colorScheme)   private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Query(sort: \Pet.name)       private var pets:   [Pet]
    @Query(sort: \Human.name)     private var humans: [Human]

    @State private var vm = IslandUnifiedStatsViewModel()
    @State private var weightTimeRange: WeightTimeFilter = .all
    @State private var chartRevealProgress: CGFloat = 0

    enum WeightTimeFilter: String, CaseIterable, Identifiable {
        case week  = "周"
        case month = "月"
        case year  = "年"
        case all   = "全部"
        var id: String { rawValue }
    }

    // 颜色映射
    private let humanColor   = Color.goLime
    private let petPalette: [Color] = [
        Color(hex: "80FFEA"), Color(hex: "FF8C42"), Color(hex: "C084FC"),
        Color(hex: "FFF44F"), Color(hex: "FF6B8A")
    ]

    private func color(for name: String, isHuman: Bool) -> Color {
        if isHuman { return humanColor }
        let idx = pets.firstIndex(where: { $0.name == name }) ?? 0
        return petPalette[idx % petPalette.count]
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
        NavigationStack {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        navBar
                        weightFloatingChart
                        funBentoRow
                        individualSparklineCard
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
        }
        .onAppear { vm.load(modelContext: modelContext, pets: pets, humans: visibleHumans) }
        .onChange(of: pets.count)   { vm.load(modelContext: modelContext, pets: pets, humans: visibleHumans) }
        .onChange(of: humans.count) { vm.load(modelContext: modelContext, pets: pets, humans: visibleHumans) }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(primaryText)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular, in: Circle())
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

    // MARK: - 模块 1: 全岛体重变动趋势（悬浮无卡片）
    private var weightFloatingChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 时间 filter
            HStack {
                Picker("", selection: $weightTimeRange) {
                    ForEach(WeightTimeFilter.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 6) {
                Text("⚖️").font(.system(size: 13))
                Text("体重趋势")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(secondaryText)
                Spacer()
                Text("kg")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tertiaryText)
            }
            .padding(.horizontal, 4)

            if filteredWeightAbsolutes.isEmpty {
                emptyState("暂无体重数据\n记录后即可看到趋势曲线")
            } else {
                weightAbsoluteLineChart
                weightAbsoluteLegend
            }
        }
        .padding(.horizontal, 4)
    }

    private var filteredWeightAbsolutes: [WeightAbsolutePoint] {
        let now = Date()
        let cal = Calendar.current
        let cutoff: Date? = {
            switch weightTimeRange {
            case .week:  return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))
            case .month: return cal.dateInterval(of: .month, for: now)?.start
            case .year:  return cal.dateInterval(of: .year,  for: now)?.start
            case .all:   return nil
            }
        }()
        guard let c = cutoff else { return vm.weightAbsolutes }
        return vm.weightAbsolutes.filter { $0.date >= c }
    }

    private var filteredAbsoluteSeriesByName: [(String, [WeightAbsolutePoint], Bool)] {
        let names = Array(Set(filteredWeightAbsolutes.map { $0.entityName })).sorted()
        return names.map { name in
            let pts = filteredWeightAbsolutes
                .filter { $0.entityName == name }
                .sorted { $0.date < $1.date }
            return (name, pts, pts.first?.isHuman ?? false)
        }
    }

    private var chartAnimationKey: String {
        filteredAbsoluteSeriesByName
            .map { name, points, _ in
                let joined = points.map { "\($0.date.timeIntervalSince1970):\(String(format: "%.3f", $0.weight))" }
                    .joined(separator: ",")
                return "\(name):\(joined)"
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
            ForEach(filteredAbsoluteSeriesByName, id: \.0) { name, points, isHuman in
                let c = color(for: name, isHuman: isHuman)
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("日期", pt.date),
                        y: .value("kg", pt.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [c.opacity(0.18), c.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .foregroundStyle(by: .value("成员", name))

                ForEach(points) { pt in
                    LineMark(
                        x: .value("日期", pt.date),
                        y: .value("kg", pt.weight)
                    )
                    .foregroundStyle(c)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                }
                .foregroundStyle(by: .value("成员", name))

                if let last = points.last {
                    PointMark(
                        x: .value("日期", last.date),
                        y: .value("kg", last.weight)
                    )
                    .foregroundStyle(c)
                    .symbolSize(36)
                }
            }
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
        .chartForegroundStyleScale(
            domain: filteredAbsoluteSeriesByName.map { $0.0 },
            range:  filteredAbsoluteSeriesByName.map { color(for: $0.0, isHuman: $0.2) }
        )
        .chartLegend(.hidden)
        .mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle()
                    .frame(width: max(12, geo.size.width * chartRevealProgress))
            }
        }
        .frame(height: 200)
        .onAppear { playChartReveal() }
        .onChange(of: chartAnimationKey) { _, _ in playChartReveal() }
    }

    private var weightAbsoluteLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filteredAbsoluteSeriesByName, id: \.0) { name, _, isHuman in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: name, isHuman: isHuman))
                            .frame(width: 16, height: 3)
                        Text(name)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - 模块 2: 趣味 Bento（干饭王 + 全岛总质量）
    private var funBentoRow: some View {
        HStack(spacing: 12) {
            championsCard
            islandMassCard
        }
    }

    private var championsCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("🏆 本月排行")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)

                if let gain = vm.gainChampion {
                    HStack(spacing: 6) {
                        Text(gain.emoji).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("干饭王")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.goYellow.opacity(0.8) : Color.goOrange)
                            Text(gain.entityName)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(primaryText)
                                .lineLimit(1)
                            Text("+\(String(format: "%.1f", gain.deltaPercent))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(colorScheme == .dark ? Color.goYellow : Color.goOrange)
                        }
                    }
                } else {
                    Text("暂无数据").font(.system(size: 11)).foregroundStyle(tertiaryText)
                }

                if let loss = vm.lossChampion {
                    HStack(spacing: 6) {
                        Text(loss.emoji).font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("自律王")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.goTeal.opacity(0.8) : Color.goBlue)
                            Text(loss.entityName)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(primaryText)
                                .lineLimit(1)
                            Text("\(String(format: "%.1f", loss.deltaPercent))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(colorScheme == .dark ? Color.goTeal : Color.goBlue)
                        }
                    }
                } else {
                    Text("暂无数据").font(.system(size: 11)).foregroundStyle(tertiaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(height: 160)
        }
    }

    private var islandMassCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("🌐 全岛总质量")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", totalIslandWeightKg))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.goYellow : Color.goOrange)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("kg")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryText)
                }

                Text(weightComparison)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryText)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(height: 160)
        }
    }

    // MARK: - 模块 3: 个体 Sparkline 清单
    private var individualSparklineCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Text("📊").font(.system(size: 14))
                    Text("个体体重清单")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                }

                let allEntries = buildSparklineEntries()
                if allEntries.isEmpty {
                    emptyState("暂无个体体重数据")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(allEntries.enumerated()), id: \.offset) { idx, entry in
                            sparklineRow(entry: entry)
                            if idx < allEntries.count - 1 {
                                Divider().background(colorScheme == .dark ? .white.opacity(0.06) : .black.opacity(0.06))
                            }
                        }
                    }
                }
            }
            .padding(16)
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

    private func buildSparklineEntries() -> [SparkEntry] {
        var result: [SparkEntry] = []
        for (idx, pet) in pets.enumerated() {
            let sorted = pet.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { continue }
            let pts = sorted.map { SparkPoint(date: $0.date, weight: $0.weight) }
            result.append(SparkEntry(
                emoji: pet.avatarEmoji, name: pet.name,
                current: sorted.last!.weight, isHuman: false,
                history: pts,
                accentColor: petPalette[idx % petPalette.count],
                petRef: pet, humanRef: nil
            ))
        }
        for human in visibleHumans {
            let sorted = human.weightLogs.sorted { $0.date < $1.date }
            guard !sorted.isEmpty else { continue }
            let pts = sorted.map { SparkPoint(date: $0.date, weight: $0.weight) }
            result.append(SparkEntry(
                emoji: human.avatarEmoji, name: human.name,
                current: sorted.last!.weight, isHuman: true,
                history: pts,
                accentColor: humanColor,
                petRef: nil, humanRef: human
            ))
        }
        return result
    }

    private func sparklineRow(entry: SparkEntry) -> some View {
        let rowContent = HStack(spacing: 12) {
            Text(entry.emoji).font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", entry.current))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(entry.accentColor)
                    Text("kg")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tertiaryText)
                }
            }

            Spacer()

            // 极简无轴 Sparkline
            if entry.history.count > 1 {
                AnimatedWeightSparkline(history: entry.history, accentColor: entry.accentColor)
                .frame(width: 80, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tertiaryText.opacity(0.6))
        }
        .padding(.vertical, 10)
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
    
    // MARK: - Glass Card Helper
    @ViewBuilder
    private func glassCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        if reduceTransparency {
            // 无障碍降级：纯色不透明背景
            content()
                .background(Color(.systemBackground).opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            // 浅色模式下更透明
            if colorScheme == .light {
                content()
                    .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                content()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}

#Preview {
    IslandWeightDashboard()
        .modelContainer(SharedModelContainer.make())
}
