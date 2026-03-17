//
//  PetHygieneDetailView.swift
//  Ohana
//
//  护理详情页 — 参考饮食管理页风格
//  深色背景 + ScrollView 卡片 + Swift Charts 7天柱状图
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Chart Data Point for Hygiene
private struct HygieneChartPoint: Identifiable {
    let id = UUID()
    let day: Date
    let count: Int
    let label: String
}

struct PetHygieneDetailView: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @State private var showingPottyOverview = false
    // 模块七：长按护理项目弹出计划 sheet
    @State private var groomingPlanTarget: HygieneType? = nil

    private var themeColor: Color { pet.themeColor.color }

    private var isLitterPet: Bool {
        ["猫", "兔子", "仓鼠", "龙猫", "豚鼠"].contains(pet.species)
    }

    private func daysSince(_ type: HygieneType) -> Int? {
        guard let last = pet.hygieneLogs.filter({ $0.type == type.rawValue })
            .sorted(by: { $0.date > $1.date }).first else { return nil }
        return Calendar.current.dateComponents([.day], from: last.date, to: Date()).day
    }

    private func statusColor(_ type: HygieneType) -> Color {
        guard let d = daysSince(type) else { return .primary.opacity(0.25) }
        let p = Double(d) / Double(type.cycleDays)
        if p < 0.5  { return themeColor }
        if p < 0.85 { return Color.goYellow }
        return Color.goRed
    }

    private func chartPoints(_ type: HygieneType) -> [HygieneChartPoint] {
        let cal = Calendar.current
        let dayLabels = ["日","一","二","三","四","五","六"]
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            let count = pet.hygieneLogs.filter {
                $0.type == type.rawValue && cal.isDate($0.date, inSameDayAs: d)
            }.count
            let weekday = cal.component(.weekday, from: d) - 1
            return HygieneChartPoint(day: d, count: count, label: dayLabels[weekday])
        }
    }

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // ── 状态总览条
                    statusOverviewRow
                    // ── 5项护理卡片（各含 Charts 图表）
                    ForEach(HygieneType.allCases, id: \.rawValue) { type in
                        hygieneTypeCard(type)
                    }
                    // ── 便便/铲屎区
                    pottySection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle("\(pet.name) · 护理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPottyOverview = true } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeColor)
                }
            }
        }
        .sheet(isPresented: $showingPottyOverview) {
            PottyOverviewView(pet: pet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // 模块七：长按护理项目弹出计划 sheet
        .sheet(item: $groomingPlanTarget) { hygieneType in
            HygieneTodoSheet(pet: pet, type: hygieneType)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 状态总览横排
    private var statusOverviewRow: some View {
        HStack(spacing: 0) {
            ForEach(HygieneType.allCases, id: \.rawValue) { type in
                let color = statusColor(type)
                let days = daysSince(type)
                VStack(spacing: 5) {
                    ZStack {
                        Circle().stroke(color.opacity(0.18), lineWidth: 3).frame(width: 44, height: 44)
                        let progress: Double = {
                            guard let d = days else { return 0 }
                            return min(1, Double(d) / Double(type.cycleDays))
                        }()
                        Circle()
                            .trim(from: 0, to: 1 - progress)
                            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text(type.emoji).font(.system(size: 18))
                    }
                    Text(type.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                    if let d = days {
                        Text(d == 0 ? "今天" : "\(d)天前")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(color)
                    } else {
                        Text("未记录")
                            .font(.system(size: 8)).foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 是否今天已完成
    private func isDoneToday(_ type: HygieneType) -> Bool {
        pet.hygieneLogs.contains {
            $0.type == type.rawValue && Calendar.current.isDateInToday($0.date)
        }
    }

    // MARK: - 护理类型卡片（重构）
    private func hygieneTypeCard(_ type: HygieneType) -> some View {
        let logs = pet.hygieneLogs.filter { $0.type == type.rawValue }.sorted { $0.date > $1.date }
        let color = statusColor(type)
        let days = daysSince(type)
        let points = chartPoints(type)
        let hasData = points.contains { $0.count > 0 }   // 迗 7 天是否有数据
        let doneToday = isDoneToday(type)

        return VStack(alignment: .leading, spacing: 10) {
            // 标题行：左边名称 + 右边状态胶囊 + 打卡胶囊
            HStack(spacing: 8) {
                Text(type.emoji).font(.system(size: 16))
                Text(type.rawValue)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                // 状态胶囊
                if let d = days {
                    Text(d == 0 ? "✓ 今天" : "\(d)天前")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(d == 0 ? Color.goLime : color)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((d == 0 ? Color.goLime : color).opacity(0.12), in: Capsule())
                } else {
                    Text("未记录")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.3))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .glassEffect(.regular, in: Capsule())
                }
                // 打卡胶囊（右上角精致按钮）
                Button {
                    let log = PetHygieneLog(date: Date(), type: type, pet: pet)
                    modelContext.insert(log)
                    modelContext.safeSave()
                    QuestManager.shared.awardAction(type: .care(type: type), pet: pet, context: modelContext)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    if doneToday {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.45))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .glassEffect(.regular, in: Capsule())
                    } else {
                        Text("打卡")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.goLime, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }

            // 智能图表：7 天无数据则折叠，有数据才展开
            if hasData {
                Chart(points) { pt in
                    BarMark(
                        x: .value("日", pt.day, unit: .day),
                        y: .value("次", pt.count)
                    )
                    .foregroundStyle(Color.goCardCyan.opacity(pt.count > 0 ? 0.75 : 0.1))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.system(size: 9))
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 44)
            }

            // 最近记录（无分割线）
            if !logs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(logs.prefix(3)) { log in
                        HStack {
                            Text(log.date, format: .dateTime.month().day().hour().minute())
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
                            Spacer()
                            Button { modelContext.delete(log); modelContext.safeSave() } label: {
                                Image(systemName: "trash").font(.system(size: 10))
                                    .foregroundStyle(.primary.opacity(0.2))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .glassEffect(doneToday ? .regular.tint(Color.goLime.opacity(0.15)) : .regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        // 动态透明度：今天已完成则降低，视觉重心自然转向未记录项
        .opacity(doneToday ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: doneToday)
        // 模块七：长按弹出护理计划 sheet
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            groomingPlanTarget = type
        }
    }

    // MARK: - 便便/铲屎区
    private var pottySection: some View {
        let cal = Calendar.current
        let todayPotty = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
        let todayLitter = isLitterPet
            ? pet.careLogs.filter { $0.type == CareType.litter.rawValue && cal.isDateInToday($0.date) }.count
            : 0

        // 7天便便 chart
        let pottyPoints: [HygieneChartPoint] = (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: Date())!
            let count = pet.pottyLogs.filter { cal.isDate($0.date, inSameDayAs: d) }.count
            return HygieneChartPoint(day: d, count: count, label: "")
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("噗噗记录", systemImage: "drop.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goYellow)
                Spacer()
                Button { showingPottyOverview = true } label: {
                    HStack(spacing: 3) {
                        Text("完整分析").font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right").font(.system(size: 10))
                    }
                    .foregroundStyle(Color.goYellow)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.goYellow.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // 今日统计行
            HStack(spacing: 10) {
                statCell(emoji: "💩", value: "\(todayPotty)", label: "今日便便", color: Color.goYellow)
                if isLitterPet {
                    statCell(emoji: "🪣", value: "\(todayLitter)", label: "今日铲屎", color: Color(hex: "AA96DA"))
                }
            }

            // 7天趋势图
            if pottyPoints.contains(where: { $0.count > 0 }) {
                Chart(pottyPoints) { pt in
                    BarMark(x: .value("日", pt.day, unit: .day), y: .value("次", pt.count))
                        .foregroundStyle(Color.goYellow.opacity(pt.count > 0 ? 0.8 : 0.1))
                        .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.system(size: 9)).foregroundStyle(.primary.opacity(0.4))
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 50)
            }

            // 打卡胶囊行（小巧）
            HStack(spacing: 10) {
                Button {
                    modelContext.insert(PetPottyLog(date: Date(), type: .perfectPoop, pet: pet))
                    modelContext.safeSave()
                    QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("便便打卡")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.goYellow, in: Capsule())
                }
                .buttonStyle(.plain)

                if isLitterPet {
                    Button {
                        modelContext.insert(PetCareLog(date: Date(), type: .litter, pet: pet))
                        modelContext.safeSave()
                        QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                            Text("镐屎打卡")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(hex: "AA96DA"), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // 最近便便记录（无分割线）
            ForEach(pet.pottyLogs.sorted { $0.date > $1.date }.prefix(4)) { log in
                HStack {
                    Text("💩").font(.system(size: 13))
                    Text(log.date, format: .dateTime.month().day().hour().minute())
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                    Spacer()
                    Button { modelContext.delete(log); modelContext.safeSave() } label: {
                        Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.primary.opacity(0.3))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statCell(emoji: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 20))
            Text(value).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(.primary)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.primary.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}
