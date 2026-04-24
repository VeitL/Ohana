//
//  IslandWealthDashboard2.swift
//  Ohana
//
//  欧哈纳财富中心 — 全页可滚动，收支分开展示
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Main View
struct IslandWealthDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = IslandWealthViewModel()
    @State private var showingCoconutLog = false
    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query(sort: \Human.name) private var humans: [Human]

    private var petColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: pets.map { ($0.id.uuidString, Color(hex: $0.themeColorHex)) })
    }

    private var safeTop: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 52
    }
    private var navBarHeight: CGFloat { safeTop + 56 }

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()

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
                    if vm.chartBars.isEmpty && vm.spendingBars.isEmpty {
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
        .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
        .onAppear   { syncVM() }
        .onChange(of: pets.count)   { syncVM() }
        .onChange(of: humans.count) { syncVM() }
    }

    private func syncVM() {
        vm.pets = pets; vm.humans = humans; vm.petColorMap = petColorMap
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }
            Spacer()
            Text("Ohana财富")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3)) { vm.showSystemCoconuts.toggle() }
            } label: {
                Image(systemName: vm.showSystemCoconuts ? "gearshape.fill" : "gearshape")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(vm.showSystemCoconuts ? Color.goPrimary : .primary.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            CoconutBalanceCapsule { showingCoconutLog = true }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 8)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.01))
    }

    // MARK: - Total Assets

    private var totalAssetsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("全岛")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.goPrimary.opacity(0.7))
            Text("\(vm.totalAssets)")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4), value: vm.totalAssets)
            Text("🥥")
                .font(.system(size: 30))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - Time Picker

    private var timePicker: some View {
        Picker("", selection: $vm.timeRange) {
            ForEach(WealthTimeRange.allCases) { r in
                Text(r.rawValue).tag(r)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Income vs Spending Row

    private var incomeVsSpendingRow: some View {
        HStack(spacing: 12) {
            summaryCell(
                label: "本期收入",
                value: "+\(vm.periodIncome)",
                valueColor: Color.goLime,
                icon: "arrow.down.circle.fill"
            )
            summaryCell(
                label: "本期花费",
                value: vm.periodSpending > 0 ? "-\(vm.periodSpending)" : "本期无花费",
                valueColor: vm.periodSpending > 0 ? Color.goRed : .primary.opacity(0.35),
                icon: "arrow.up.circle.fill"
            )
        }
    }

    private func summaryCell(label: String, value: String, valueColor: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(valueColor.opacity(0.7))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("🥥")
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch vm.timeRange {
            case .day:   barChart(unit: .hour,  format: .dateTime.hour())
            case .week:  barChart(unit: .day,   format: .dateTime.weekday(.abbreviated))
            case .month: barChart(unit: .day,   format: .dateTime.day())
            case .all:   barChart(unit: .month, format: .dateTime.month(.abbreviated))
            }
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func barChart(unit: Calendar.Component, format: Date.FormatStyle) -> some View {
        let names  = vm.chartEntityNames
        let colors = vm.chartEntityColors
        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(vm.chartBars) { bar in
                    BarMark(
                        x: .value("时间", bar.bucket, unit: unit),
                        y: .value("椰子", bar.amount),
                        width: .ratio(0.45)
                    )
                    .foregroundStyle(by: .value("成员", bar.entityName))
                    .cornerRadius(4)
                }
                ForEach(vm.spendingBars) { bar in
                    BarMark(
                        x: .value("时间", bar.bucket, unit: unit),
                        y: .value("椰子", bar.amount),
                        width: .ratio(0.2)
                    )
                    .foregroundStyle(Color.goRed.opacity(0.75))
                    .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale(domain: names, range: colors)
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .stride(by: unit)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(.primary.opacity(0.1))
                    AxisValueLabel(format: format)
                        .foregroundStyle(.primary.opacity(0.55))
                        .font(.system(size: 10))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.primary.opacity(0.07))
                    AxisValueLabel().foregroundStyle(.primary.opacity(0.5))
                        .font(.system(size: 10))
                }
            }
            .chartLegend(.hidden)

            // 图例（收入成员 + 花费）
            legendView
        }
    }

    private var legendView: some View {
        let entries = vm.leaderboard.prefix(5)
        return HStack(spacing: 10) {
            ForEach(entries) { row in
                HStack(spacing: 4) {
                    Circle().fill(vm.color(for: row.entityId)).frame(width: 7, height: 7)
                    Text(row.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.6))
                        .lineLimit(1)
                }
            }
            if !vm.spendingBars.isEmpty {
                HStack(spacing: 4) {
                    Circle().fill(Color.goRed.opacity(0.75)).frame(width: 7, height: 7)
                    Text("花费")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
            Spacer()
        }
    }

    // 空图表
    private var emptyChart: some View {
        VStack(spacing: 12) {
            Text("🥥")
                .font(.system(size: 52))
            Text("立刻去打卡赚取第一桶金吧！")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(spacing: 0) {
            if vm.leaderboard.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 36))
                        .foregroundStyle(.primary.opacity(0.25))
                    Text("完成打卡即可解锁财富榜 ✨")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    HStack {
                        Text("财富榜")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)

                    LazyVStack(spacing: 10) {
                        ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { idx, row in
                            leaderRow(rank: idx + 1, row: row)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Leader Row
    private func leaderRow(rank: Int, row: WealthLeaderRow) -> some View {
        let accent = vm.color(for: row.entityId)
        let isFirst = rank == 1
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rank == 1 ? Color.goPrimary :
                          rank == 2 ? Color(hex: "FFF44F").opacity(0.55) :
                          rank == 3 ? Color.goTeal.opacity(0.5) :
                          Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)
                Text("\(rank)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(rank <= 3 ? Color.arkInk : .white.opacity(0.6))
            }

            ZStack {
                if isFirst {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.35))
                        .frame(width: 46, height: 46)
                        .blur(radius: 6)
                    Circle()
                        .strokeBorder(Color.goPrimary, lineWidth: 2)
                        .frame(width: 42, height: 42)
                }
                Text(row.emoji)
                    .font(.system(size: 20))
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.12), in: Circle())
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.07)).frame(height: 4)
                        Capsule()
                            .fill(accent)
                            .frame(width: max(4, geo.size.width * row.percentage), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer(minLength: 8)

            Text("\(row.amount)🥥")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(accent.opacity(0.14), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        IslandWealthDashboardView()
    }
    .modelContainer(SharedModelContainer.make())
}
