//
//  IslandWealthDashboard2.swift
//  Ohana
//
//  欧哈纳财富中心 — 沉浸式深色背景 + 底部 #F2F0F5 悬浮卡片
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

    // 宠物 id → 主题色 映射（传给 ViewModel）
    private var petColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: pets.map { ($0.id.uuidString, Color(hex: $0.themeColorHex)) })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── L0: 全屏深色背景 ──────────────────────────────────────
            ArkBackgroundView()
                .ignoresSafeArea()

            // ── L1: 图表区（上半屏） ──────────────────────────────────
            VStack(spacing: 0) {
                chartArea
                    .padding(.top, 120)
                Spacer()
            }

            // ── L2: 底部悬浮卡片（左右下布满屏幕，无边距）──────────────────────────
            bottomCard
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    vm.pets = pets; vm.humans = humans
                    vm.petColorMap = petColorMap
                }
                .onChange(of: pets.count) {
                    vm.pets = pets; vm.humans = humans
                    vm.petColorMap = petColorMap
                }
                .onChange(of: humans.count) {
                    vm.pets = pets; vm.humans = humans
                    vm.petColorMap = petColorMap
                }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) { navBar }
        .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
    }

    // MARK: - Floating Nav Bar
    private var navBar: some View {
        VStack(spacing: 0) {
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
                // 系统椰子过滤开关
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        vm.showSystemCoconuts.toggle()
                    }
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
            .padding(.top, 56)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial.opacity(0.01))
    }

    // MARK: - Chart Area
    private var chartArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 时间 filter
            Picker("", selection: $vm.timeRange) {
                ForEach(WealthTimeRange.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            if vm.chartBars.isEmpty {
                emptyChart
            } else {
                stackedBarChart
            }
        }
        .frame(height: 260)
        .padding(.horizontal, 20)
    }

    // 堆叠柱状图（根据 timeRange 静态选择 unit，防止动态传入 Calendar.Component 导致 fatal error）
    @ViewBuilder
    private var stackedBarChart: some View {
        switch vm.timeRange {
        case .day:
            barChart(unit: .hour, format: .dateTime.hour())
        case .week:
            barChart(unit: .day,  format: .dateTime.weekday(.abbreviated))
        case .month:
            barChart(unit: .day,  format: .dateTime.day())
        case .all:
            barChart(unit: .month, format: .dateTime.month(.abbreviated))
        }
    }

    private func barChart(unit: Calendar.Component, format: Date.FormatStyle) -> some View {
        let stridedUnit: Calendar.Component = unit
        let names  = vm.chartEntityNames
        let colors = vm.chartEntityColors
        return Chart(vm.chartBars) { bar in
            BarMark(
                x: .value("时间", bar.bucket, unit: stridedUnit),
                y: .value("椰子", bar.amount),
                width: .ratio(0.55)
            )
            .foregroundStyle(by: .value("成员", bar.entityName))
            .cornerRadius(5)
        }
        .chartForegroundStyleScale(
            domain: names,
            range: colors
        )
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .stride(by: stridedUnit)) { _ in
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
        .chartLegend(position: .bottom, alignment: .leading, spacing: 6) {
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
        }
    }

    // 空状态
    private var emptyChart: some View {
        VStack(spacing: 12) {
            Text("🥥")
                .font(.system(size: 52))
            Text("立刻去打卡赚取第一桶金吧！")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Card
    private var bottomCard: some View {
        VStack(spacing: 0) {
            // 拖拽条
            Capsule()
                .fill(Color.black.opacity(0.15))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            // 全岛总资产（大数字）
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
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 24)

            // 排行榜
            if vm.leaderboard.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 36))
                        .foregroundStyle(.primary.opacity(0.25))
                    Text("完成打卡即可解锁财富榜 ✨")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .padding(.vertical, 32)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { idx, row in
                            leaderRow(rank: idx + 1, row: row)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
                .frame(maxHeight: 280)
            }

                Spacer(minLength: 0).frame(height: 40)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.09))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Leader Row
    private func leaderRow(rank: Int, row: WealthLeaderRow) -> some View {
        let accent = vm.color(for: row.entityId)
        let isFirst = rank == 1
        return HStack(spacing: 12) {
            // Rank badge
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

            // Avatar (第一名加发光边框)
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

            // Name + 进度条
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

            // Amount
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
