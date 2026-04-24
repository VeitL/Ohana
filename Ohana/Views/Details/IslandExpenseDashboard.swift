//
//  IslandExpenseDashboard.swift
//  Ohana
//
//  全岛花费详情页 — Bento Box 深色毛玻璃主题
//  吞金兽 + 消费大头 + 横向 BarMark + SectorMark 环形饼图
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Time Filter
enum ExpenseTimeRange: String, CaseIterable, Identifiable {
    case day   = "日"
    case month = "月"
    case year  = "年"
    case all   = "全部"
    var id: String { rawValue }
}

// MARK: - Internal Data Models
private struct PetExpenseSummary: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let total: Double
    let color: Color
}

private struct CategorySummary: Identifiable {
    let id = UUID()
    let category: ExpenseCategory
    let total: Double
    let pct: Double
}

private struct PayerSummary: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let total: Double
    let color: Color
    let pct: Double
}

// MARK: - Main View
struct IslandExpenseDashboard: View {
    var standalone: Bool = true

    @Environment(\.dismiss)           private var dismiss
    @Query(sort: \Pet.name)           private var pets: [Pet]
    @Query(sort: \Human.createdAt)    private var humans: [Human]
    @State private var timeRange: ExpenseTimeRange = .month
    @State private var chartAnimationProgress: Double = 0.0

    // 时间过滤后的所有花费
    private var filteredLogs: [PetExpenseLog] {
        let now = Date()
        let cal = Calendar.current
        let cutoff: Date? = {
            switch timeRange {
            case .day:   return cal.startOfDay(for: now)
            case .month: return cal.dateInterval(of: .month, for: now)?.start
            case .year:  return cal.dateInterval(of: .year, for: now)?.start
            case .all:   return nil
            }
        }()
        return pets.flatMap { $0.expenseLogs }.filter {
            guard let c = cutoff else { return true }
            return $0.date >= c
        }
    }

    /// 实际总支出（正值，不含报销负值）
    private var totalAmount: Double { filteredLogs.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount } }
    /// 报销合计（绝对值）
    private var totalReimbursed: Double { filteredLogs.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) } }

    // 每宠物汇总
    private var petSummaries: [PetExpenseSummary] {
        pets.compactMap { pet -> PetExpenseSummary? in
            let logs = filteredLogs.filter { $0.pet?.id == pet.id && $0.amount > 0 }
            let total = logs.reduce(0) { $0 + $1.amount }
            guard total > 0 else { return nil }
            return PetExpenseSummary(id: pet.id, name: pet.name,
                                     emoji: pet.avatarEmoji, total: total,
                                     color: Color(hex: pet.themeColorHex))
        }.sorted { $0.total > $1.total }
    }

    // 类目汇总（饼图，仅正值）
    private var categorySummaries: [CategorySummary] {
        let total = max(1, totalAmount)
        var dict: [String: Double] = [:]
        for log in filteredLogs where log.amount > 0 {
            dict[log.category, default: 0] += log.amount
        }
        return dict.compactMap { key, val -> CategorySummary? in
            guard let cat = ExpenseCategory(rawValue: key) else { return nil }
            return CategorySummary(category: cat, total: val, pct: val / total)
        }.sorted { $0.total > $1.total }
    }

    // 吞金兽
    private var topPet: PetExpenseSummary? { petSummaries.first }
    // 消费大头类目
    private var topCategory: CategorySummary? { categorySummaries.first }

    // 按支付人汇总（谁在买单）
    private var humanSummaries: [PayerSummary] {
        let total = max(1, totalAmount)
        var dict: [String: Double] = [:]
        for log in filteredLogs {
            let raw = log.executorId
            let key: String
            if raw == nil || (raw?.isEmpty ?? true) {
                key = "__unknown__"
            } else if let r = raw, !r.isEmpty, humans.contains(where: { $0.id.uuidString == r }) {
                key = r
            } else {
                // 已删除成员或无效 id：并入未指定，避免支付人统计漏额
                key = "__unknown__"
            }
            dict[key, default: 0] += log.amount
        }
        return dict.compactMap { key, val -> PayerSummary? in
            if key == "__unknown__" {
                return PayerSummary(name: "未指定", emoji: "❓", total: val,
                                   color: .white.opacity(0.4), pct: val / total)
            }
            guard let human = humans.first(where: { $0.id.uuidString == key }) else { return nil }
            return PayerSummary(name: human.name, emoji: human.avatarEmoji, total: val,
                               color: humanThemeColor(human), pct: val / total)
        }.sorted { $0.total > $1.total }
    }

    private func humanThemeColor(_ human: Human) -> Color {
        let hex = human.themeColor
        if hex.count == 6 { return Color(hex: hex) }
        return Color.goPrimary
    }

    var body: some View {
        dashboardBody
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                        chartAnimationProgress = 1.0
                    }
                }
            }
            .onChange(of: timeRange) { _, _ in
                chartAnimationProgress = 0.0
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                    chartAnimationProgress = 1.0
                }
            }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            ZStack {
                ArkBackgroundView().ignoresSafeArea()
                scrollContent
            }
            .ignoresSafeArea(edges: .top)
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if standalone { navBar }
                expenseFloatingHeader
                funBentoRow
                petBarChartCard
                payerBreakdownCard
                ExpenseSplitterCard(filteredLogs: filteredLogs, humans: humans)
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
        }
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
            Text("全岛花费")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 64)
    }

    // MARK: - E7: 悬浮首部（时间filter + 大数字 + pie chart）
    private var expenseFloatingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 时间 filter
            Picker("", selection: $timeRange) {
                ForEach(ExpenseTimeRange.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            // 悬浮 Pie Chart（独立色系，无卡片背景）
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    if categorySummaries.isEmpty {
                        // 无数据：灰色空心环
                        Circle()
                            .strokeBorder(.primary.opacity(0.1), lineWidth: 18)
                            .frame(width: 150, height: 150)
                    } else {
                        Chart(categorySummaries) { item in
                            SectorMark(
                                angle: .value("金额", item.total * chartAnimationProgress),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(expensePieColor(item.category))
                            .cornerRadius(4)
                        }
                        .frame(width: 150, height: 150)
                    }

                    VStack(spacing: 2) {
                        if categorySummaries.isEmpty {
                            Text("暂无数据")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.3))
                        } else {
                            Text("¥\(Int(totalAmount))")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(timeRange.rawValue == "全部" ? "累计" : "本\(timeRange.rawValue)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !categorySummaries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(categorySummaries.prefix(4)) { item in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(expensePieColor(item.category))
                                    .frame(width: 7, height: 7)
                                Text(item.category.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.75))
                                Spacer()
                                Text("\(Int(item.pct * 100))%")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.45))
                            }
                        }
                        // 报销行
                        if totalReimbursed > 0 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: "4ECDC4"))
                                    .frame(width: 7, height: 7)
                                Text("保险报销")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "4ECDC4"))
                                Spacer()
                                Text("-¥\(Int(totalReimbursed))")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(hex: "4ECDC4"))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("记录第一笔花费")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
                        Text("在宠物详情页添加花费记录后，这里会显示消费分布")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
    }

    /// E7: 独立色系，和宠物主题色区分
    private func expensePieColor(_ cat: ExpenseCategory) -> Color {
        switch cat {
        case .food:             return Color(hex: "3B82F6")  // 蓝
        case .treats:           return Color(hex: "10B981")  // 緑
        case .medical:          return Color(hex: "F59E0B")  // 橙黄
        case .grooming:         return Color(hex: "8B5CF6")  // 紫
        case .toys:             return Color(hex: "EC4899")  // 粉
        case .insurancePremium: return Color(hex: "06B6D4")  // 青（保险费）
        case .other:            return Color(hex: "6B7280")  // 灰
        }
    }

    // MARK: - 趣味 Bento（吞金兽 + 消费大头）
    private var funBentoRow: some View {
        HStack(spacing: 12) {
            topPetCard
            topCategoryCard
        }
    }

    private var topPetCard: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 5) {
                Text("💰")
                Text("吞金兽")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
            }
            Spacer(minLength: 0)
            if let top = topPet {
                Text(top.emoji).font(.system(size: 34))
                Text(top.name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("¥\(top.total.formatted(.number.precision(.fractionLength(0))))")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))
            } else {
                Text("暂无数据").font(.system(size: 12)).foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private var topCategoryCard: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 5) {
                Text("🏷️")
                Text("消费大头")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.6))
            }
            Spacer(minLength: 0)
            if let top = topCategory {
                Text(top.category.emoji).font(.system(size: 34))
                Text(top.category.rawValue)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(Int(top.pct * 100))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))
            } else {
                Text("暂无数据").font(.system(size: 12)).foregroundStyle(.primary.opacity(0.3))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - 成员花费横向条形图
    private var petBarChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("🐾").font(.system(size: 14))
                Text("成员花费对比")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            if petSummaries.isEmpty {
                emptyState("暂无花费记录")
            } else {
                petBarChart
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private var petBarChart: some View {
        VStack(spacing: 10) {
            let maxVal = petSummaries.first?.total ?? 1
            ForEach(petSummaries) { summary in
                HStack(spacing: 10) {
                    Text(summary.emoji).font(.system(size: 16))
                    Text(summary.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(width: 50, alignment: .leading)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.06))
                                .frame(height: 10)
                            Capsule()
                                .fill(summary.color)
                                .frame(
                                    width: max(8, geo.size.width * (summary.total / maxVal) * chartAnimationProgress),
                                    height: 10
                                )
                        }
                    }
                    .frame(height: 10)
                    Text("¥\(Int(summary.total))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(summary.color)
                        .frame(width: 48, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - 💳 谁在买单卡片
    private var payerBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("💳").font(.system(size: 14))
                Text("谁在买单")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            if humanSummaries.isEmpty {
                emptyState("暂无支付人数据")
            } else {
                let maxVal = humanSummaries.first?.total ?? 1
                VStack(spacing: 10) {
                    ForEach(humanSummaries) { summary in
                        HStack(spacing: 10) {
                            Text(summary.emoji).font(.system(size: 16))
                            Text(summary.name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(width: 50, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(.white.opacity(0.06))
                                        .frame(height: 10)
                                    Capsule()
                                        .fill(summary.color)
                                        .frame(
                                            width: max(8, geo.size.width * (summary.total / maxVal) * chartAnimationProgress),
                                            height: 10
                                        )
                                }
                            }
                            .frame(height: 10)
                            Text("¥\(Int(summary.total))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(summary.color)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - 类目环形饼图 (SectorMark)
    private var categoryDonutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Text("🍩").font(.system(size: 14))
                Text("消费类目分布")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }

            if categorySummaries.isEmpty {
                emptyState("暂无类目数据")
            } else {
                HStack(alignment: .center, spacing: 20) {
                    donutChart
                    categoryLegend
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    }

    private var donutChart: some View {
        ZStack {
            Chart(categorySummaries) { item in
                SectorMark(
                    angle: .value("金额", item.total * chartAnimationProgress),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(categoryColor(item.category))
                .cornerRadius(4)
            }
            .frame(width: 130, height: 130)

            VStack(spacing: 2) {
                Text("¥\(Int(totalAmount))")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text("总计")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var categoryLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(categorySummaries) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(categoryColor(item.category))
                        .frame(width: 8, height: 8)
                    Text(item.category.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.75))
                    Spacer()
                    Text("\(Int(item.pct * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers
    private func categoryColor(_ cat: ExpenseCategory) -> Color {
        switch cat {
        case .food:             return Color(hex: "FF8C42")
        case .treats:           return Color(hex: "FFF44F")
        case .medical:          return Color(hex: "FF4757")
        case .grooming:         return Color(hex: "C084FC")
        case .toys:             return Color(hex: "80FFEA")
        case .insurancePremium: return Color(hex: "06B6D4")
        case .other:            return Color(hex: "95ADBE")
        }
    }

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
    IslandExpenseDashboard()
        .modelContainer(SharedModelContainer.make())
}
