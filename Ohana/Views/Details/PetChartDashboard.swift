//
//  PetChartDashboard.swift
//  Ohana
//
//  N3: 透明图表仪表盘，替代 PetBentoGrid
//  每个图表卡片：透明背景 + 折线/柱状图 + 右上角快速添加按钮 + 点击进入详情
//

import SwiftUI
import SwiftData

// MARK: - Main Dashboard（Island Stats 横滚风格）

struct PetChartDashboard: View {
    let pet: Pet
    let onWeight:  () -> Void
    let onWalk:    () -> Void
    let onPotty:   () -> Void
    let onExpense: () -> Void
    let onFood:    () -> Void
    @Binding var showingAddWeight: Bool
    @Binding var quickWeightInput: String
    let modelContext: ModelContext

    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 190

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // 1. 体重
                dashCard(width: cardWidth) {
                    weightCardContent
                }
                .onTapGesture { onWeight() }
                chartDivider(height: cardHeight)

                // 2. 遛狗（狗）/ 余粮（其他）
                if pet.species == "狗" {
                    dashCard(width: cardWidth) {
                        walkCardContent
                    }
                    .onTapGesture { onWalk() }
                    chartDivider(height: cardHeight)
                } else {
                    dashCard(width: cardWidth) {
                        foodCardContent
                    }
                    .onTapGesture { onFood() }
                    chartDivider(height: cardHeight)
                }

                // 3. 噗噗
                dashCard(width: cardWidth) {
                    pottyCardContent
                }
                .onTapGesture { onPotty() }
                chartDivider(height: cardHeight)

                // 4. 花费
                dashCard(width: cardWidth) {
                    expenseCardContent
                }
                .onTapGesture { onExpense() }

                // 5. 狗额外显示余粮
                if pet.species == "狗" && pet.dailyPortionGrams > 0 {
                    chartDivider(height: cardHeight)
                    dashCard(width: cardWidth) {
                        foodCardContent
                    }
                    .onTapGesture { onFood() }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // 无背景无边框卡片容器
    private func dashCard<C: View>(width: CGFloat, @ViewBuilder content: () -> C) -> some View {
        content()
            .frame(width: width, height: cardHeight, alignment: .topLeading)
            .padding(.horizontal, 14)
    }

    // 虚线分割（Island Stats 风格）
    private func chartDivider(height: CGFloat) -> some View {
        VStack {
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.primary.opacity(0.12))
            }
        }
        .frame(width: 1, height: height)
    }

    // ── 体重 ─────────────────────────────────────────────────────
    private var weightCardContent: some View {
        let sorted = pet.weightLogs.sorted { $0.date < $1.date }
        let latest = sorted.last
        return VStack(alignment: .leading, spacing: 10) {
            cardHeader(icon: "scalemass", title: "体重", accent: .goTeal) {
                Button { showingAddWeight.toggle() } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 16)).foregroundStyle(Color.goLime)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(latest.map { String(format: "%.1f", $0.weight) } ?? "--")
                    .font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.primary)
                Text("kg").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.goTeal)
            }
            if showingAddWeight {
                HStack(spacing: 6) {
                    TextField("0.0", text: $quickWeightInput)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                    Button {
                        if let w = Double(quickWeightInput.replacingOccurrences(of: ",", with: ".")) {
                            let log = PetWeightLog(date: Date(), weight: w, pet: pet)
                            modelContext.insert(log)
                            modelContext.safeSave()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        quickWeightInput = ""; showingAddWeight = false
                    } label: {
                        Text("存").font(.system(size: 12, weight: .black)).foregroundStyle(.black)
                            .padding(.horizontal, 10).padding(.vertical, 5).background(Color.goLime, in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
            if sorted.count >= 2 {
                WeightLineChart(logs: Array(sorted.suffix(10))).frame(height: 60)
            } else {
                emptyHint
            }
        }
    }

    // ── 巡岛/遛狗 ────────────────────────────────────────────────
    private var walkCardContent: some View {
        let lastWalk = pet.walkLogs.sorted { $0.startDate > $1.startDate }.first
        let weekCounts = last7DaysWalk()
        let mgr = PetWalkingManager.shared
        let isWalking = mgr.phase != .idle && mgr.currentPet?.id == pet.id
        return VStack(alignment: .leading, spacing: 10) {
            cardHeader(icon: "figure.walk", title: "巡岛", accent: .goLime) {
                if isWalking {
                    HStack(spacing: 3) {
                        Circle().fill(Color.goLime).frame(width: 6, height: 6)
                        Text("进行中")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goLime)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.25))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(weekCounts.reduce(0, +))")
                    .font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.primary)
                Text("次").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.goLime)
            }
            Text(lastWalk.map { "上次 \($0.distanceText)" } ?? "暂无记录")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.primary.opacity(0.35))
            Spacer(minLength: 0)
            MiniBarChart(values: weekCounts.map { Double($0) }, labels: [], accentColor: .goLime).frame(height: 60)
        }
    }

    // ── 噗噗 ─────────────────────────────────────────────────────
    private var pottyCardContent: some View {
        let todayCount = pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
        let week = last7DaysPotty()
        return VStack(alignment: .leading, spacing: 10) {
            cardHeader(icon: "drop.fill", title: "噗噗", accent: .goOrange) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.25))
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(todayCount)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.primary)
                Text("次").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.goOrange)
            }
            Text("今日").font(.system(size: 11, weight: .medium)).foregroundStyle(.primary.opacity(0.35))
            Spacer(minLength: 0)
            MiniBarChart(values: week.map { Double($0) }, labels: [], accentColor: .goOrange).frame(height: 60)
        }
    }

    // ── 花费 ─────────────────────────────────────────────────────
    private var expenseCardContent: some View {
        let monthTotal = pet.expenseLogs.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
        let monthly = last6MonthExpense()
        return VStack(alignment: .leading, spacing: 10) {
            cardHeader(icon: "yensign.circle", title: "花费", accent: .goYellow) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.25))
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥\(Int(monthTotal))")
                    .font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.primary)
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            Text("本月").font(.system(size: 11, weight: .medium)).foregroundStyle(.primary.opacity(0.35))
            Spacer(minLength: 0)
            MiniBarChart(values: monthly, labels: [], accentColor: .goYellow).frame(height: 60)
        }
    }

    // ── 余粮（B6: 点击进入 PetFoodManagementView）────────────────
    private var foodCardContent: some View {
        let accent: Color = pet.remainingFoodDays <= 7 ? .goRed : .goTeal
        return VStack(alignment: .leading, spacing: 10) {
            cardHeader(icon: "fork.knife", title: "余粮", accent: accent) {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.25))
            }
            if pet.remainingFoodDays > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(pet.remainingFoodDays)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(pet.remainingFoodDays <= 7 ? Color.goRed : .white)
                    Text("天").font(.system(size: 14, weight: .bold)).foregroundStyle(.primary.opacity(0.4))
                }
                Text("\(Int(pet.remainingFoodGrams))g 剩余")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.primary.opacity(0.35))
                Spacer(minLength: 0)
                ProgressView(value: pet.remainingFoodPercent).tint(accent).scaleEffect(y: 1.2)
                Text("点击管理粮食")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.primary.opacity(0.22))
            } else {
                Text("未设置").font(.system(size: 14)).foregroundStyle(.primary.opacity(0.3))
                Spacer(minLength: 0)
                Text("点击添加余粮信息")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.goLime.opacity(0.7))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.goLime.opacity(0.1), in: Capsule())
            }
        }
    }

    // ── 卡片头部 ─────────────────────────────────────────────────
    @ViewBuilder
    private func cardHeader<T: View>(icon: String, title: String, accent: Color, @ViewBuilder trailing: () -> T = { EmptyView() }) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(accent)
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.55))
            Spacer()
            trailing()
        }
    }

    private var emptyHint: some View {
        Text("暂无数据").font(.system(size: 10)).foregroundStyle(.primary.opacity(0.2))
            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)
    }

    // ── 数据计算辅助 ────────────────────────────────────────────
    private func last6MonthExpense() -> [Double] {
        let cal = Calendar.current
        return (0..<6).reversed().map { offset in
            let date = cal.date(byAdding: .month, value: -offset, to: Date())!
            return pet.expenseLogs.filter {
                cal.isDate($0.date, equalTo: date, toGranularity: .month)
            }.reduce(0) { $0 + $1.amount }
        }
    }

    private func last7DaysWalk() -> [Int] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            return pet.walkLogs.filter { cal.isDate($0.startDate, inSameDayAs: date) }.count
        }
    }

    private func last7DaysPotty() -> [Int] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: Date())!
            return pet.pottyLogs.filter { cal.isDate($0.date, inSameDayAs: date) }.count
        }
    }
}


