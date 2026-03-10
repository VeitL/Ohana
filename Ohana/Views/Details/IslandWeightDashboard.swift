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

// MARK: - Main View
struct IslandWeightDashboard: View {
    @Environment(\.dismiss)       private var dismiss
    @Environment(\.modelContext)  private var modelContext
    @Query(sort: \Pet.name)       private var pets:   [Pet]
    @Query(sort: \Human.name)     private var humans: [Human]

    @State private var vm = IslandUnifiedStatsViewModel()

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

    // 全岛总质量
    private var totalIslandWeightKg: Double {
        let petWeight  = pets.compactMap   { $0.weightLogs.sorted { $0.date > $1.date }.first?.weight }.reduce(0, +)
        let humanWeight = humans.compactMap { $0.weightLogs.sorted { $0.date > $1.date }.first?.weight }.reduce(0, +)
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
                        weightTrendCard
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
        .onAppear { vm.load(modelContext: modelContext, pets: pets, humans: humans) }
        .onChange(of: pets.count)   { vm.load(modelContext: modelContext, pets: pets, humans: humans) }
        .onChange(of: humans.count) { vm.load(modelContext: modelContext, pets: pets, humans: humans) }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("全岛体重")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 64)
    }

    // MARK: - 模块 1: 全岛体重变动趋势（百分比折线图）
    private var weightTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("⚖️").font(.system(size: 14))
                Text("全岛体重变动趋势")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("相对初始记录")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.35))
            }

            if vm.weightDeltas.isEmpty {
                emptyState("暂无体重数据\n记录后即可看到趋势曲线")
            } else {
                weightLineChart
                weightLegend
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private var weightLineChart: some View {
        Chart {
            // 零线基准
            RuleMark(y: .value("基准", 0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 5]))
                .foregroundStyle(.primary.opacity(0.18))

            ForEach(vm.weightDeltasBySeries, id: \.0) { name, points, isHuman in
                let c = color(for: name, isHuman: isHuman)
                // 面积填充（极淡）
                ForEach(points) { pt in
                    AreaMark(
                        x: .value("日期", pt.date),
                        y: .value("变动%", pt.percentChange)
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

                // 折线主体
                ForEach(points) { pt in
                    LineMark(
                        x: .value("日期", pt.date),
                        y: .value("变动%", pt.percentChange)
                    )
                    .foregroundStyle(c)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .symbol {
                        Circle().fill(c).frame(width: 5, height: 5)
                    }
                }
                .foregroundStyle(by: .value("成员", name))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.4))
                AxisGridLine().foregroundStyle(.primary.opacity(0.05))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { val in
                if let d = val.as(Double.self) {
                    AxisValueLabel {
                        Text("\(d >= 0 ? "+" : "")\(String(format: "%.1f", d))%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }
                AxisGridLine().foregroundStyle(.primary.opacity(0.05))
            }
        }
        .chartForegroundStyleScale(
            domain: vm.weightDeltasBySeries.map { $0.0 },
            range:  vm.weightDeltasBySeries.map { color(for: $0.0, isHuman: $0.2) }
        )
        .chartLegend(.hidden)
        .frame(height: 200)
    }

    private var weightLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vm.weightDeltasBySeries, id: \.0) { name, _, isHuman in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: name, isHuman: isHuman))
                            .frame(width: 16, height: 3)
                        Text(name)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.6))
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
        VStack(alignment: .leading, spacing: 12) {
            Text("🏆 本月排行")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            if let gain = vm.gainChampion {
                HStack(spacing: 6) {
                    Text(gain.emoji).font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("干饭王")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goYellow.opacity(0.8))
                        Text(gain.entityName)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("+\(String(format: "%.1f", gain.deltaPercent))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.goYellow)
                    }
                }
            } else {
                Text("暂无数据").font(.system(size: 11)).foregroundStyle(.primary.opacity(0.3))
            }

            if let loss = vm.lossChampion {
                HStack(spacing: 6) {
                    Text(loss.emoji).font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("自律王")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goLime.opacity(0.8))
                        Text(loss.entityName)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(String(format: "%.1f", loss.deltaPercent))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.goLime)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .frame(height: 160)
    }

    private var islandMassCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🌐 全岛总质量")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", totalIslandWeightKg))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goYellow)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("kg")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
            }

            Text(weightComparison)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.55))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.goYellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.goYellow.opacity(0.2), lineWidth: 1))
        .frame(height: 160)
    }

    // MARK: - 模块 3: 个体 Sparkline 清单
    private var individualSparklineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("📊").font(.system(size: 14))
                Text("个体体重清单")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            let allEntries = buildSparklineEntries()
            if allEntries.isEmpty {
                emptyState("暂无个体体重数据")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allEntries.enumerated()), id: \.offset) { idx, entry in
                        sparklineRow(entry: entry)
                        if idx < allEntries.count - 1 {
                            Divider().background(.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(.white.opacity(0.1), lineWidth: 1))
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
        for human in humans {
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
                    .foregroundStyle(.primary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", entry.current))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(entry.accentColor)
                    Text("kg")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }

            Spacer()

            // 极简无轴 Sparkline
            if entry.history.count > 1 {
                Chart(entry.history) { pt in
                    LineMark(
                        x: .value("date", pt.date),
                        y: .value("kg", pt.weight)
                    )
                    .foregroundStyle(entry.accentColor)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
                .frame(width: 80, height: 36)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.25))
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
            .foregroundStyle(.primary.opacity(0.3))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
    }
}

#Preview {
    IslandWeightDashboard()
        .modelContainer(SharedModelContainer.make())
}
