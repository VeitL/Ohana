//
//  CoHealthDashboardView.swift
//  Ohana
//
//  模块5：人宠共健仪表盘

import SwiftUI
import SwiftData

struct CoHealthDashboardContentView: View {
    let human: Human
    let allPets: [Pet]

    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @State private var chartRevealProgress: CGFloat = 0.0

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isPrivacyLocked: Bool {
        appServices.privacy.isLocked(.weight, for: human, viewedBy: activeHumanId) ||
            appServices.privacy.isLocked(.workout, for: human, viewedBy: activeHumanId)
    }

    // 取过去30天数据
    private var past30Days: Date {
        Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    // 人类体重（最近10条，升序）
    private var humanWeightPoints: [WeightPoint] {
        Array(
            human.weightLogs
                .filter { $0.date >= past30Days && $0.weight.isFinite }
                .sorted { $0.date < $1.date }
                .suffix(10)
        ).enumerated().map { i, log in
            WeightPoint(index: i, date: log.date, value: log.weight, label: human.name)
        }
    }

    // 关联宠物（只取有 walkLogs 的狗）
    private var associatedPets: [Pet] {
        allPets.filter { pet in
            pet.species == "狗" &&
            pet.walkLogs.contains { $0.executorId == human.id.uuidString }
        }
    }

    // 宠物体重（最近10条，升序）
    private func petWeightPoints(_ pet: Pet) -> [WeightPoint] {
        Array(
            pet.weightLogs
                .filter { $0.date >= past30Days && $0.weight.isFinite }
                .sorted { $0.date < $1.date }
                .suffix(10)
        ).enumerated().map { i, log in
            WeightPoint(index: i, date: log.date, value: log.weight, label: pet.name)
        }
    }

    // 本月遛狗总里程（km）
    private var thisMonthWalkKm: Double {
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? past30Days
        let myId = human.id.uuidString
        let allLogs: [PetWalkLog] = associatedPets.flatMap { $0.walkLogs }
        let filtered = allLogs.filter { $0.executorId == myId && $0.startDate >= start }
        let totalMeters = filtered.reduce(0.0) { $0 + $1.distanceMeters }
        return totalMeters / 1000
    }

    // 宠物本月体重变化
    private var petWeightDelta: Double? {
        guard let pet = associatedPets.first else { return nil }
        let start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? past30Days
        let logs = pet.weightLogs.filter { $0.date >= start }.sorted { $0.date < $1.date }
        guard logs.count >= 2, let first = logs.first?.weight, let last = logs.last?.weight else { return nil }
        return last - first
    }

    // 趣味总结文案
    private var summaryText: String {
        let petName = associatedPets.first?.name ?? "毛孩子"
        let km = String(format: "%.1f", thisMonthWalkKm)
        if let delta = petWeightDelta {
            let dir = delta < 0 ? "瘦了" : "胖了"
            return "本月你带 \(petName) 走了 \(km)km，\(petName)\(dir) \(String(format: "%.1f", abs(delta)))kg 🎉"
        }
        return "本月你带 \(petName) 走了 \(km)km，继续加油！💪"
    }

    private func playWeightChartReveal() {
        chartRevealProgress = 0
        withAnimation(GoMotion.page) {
            chartRevealProgress = 1.0
        }
    }

    var body: some View {
        if isPrivacyLocked {
            lockedCard
        } else {
            dashboardContent
        }
    }

    private var lockedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.goYellow)
                .frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .background(Color.goYellow.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("人宠共健仅本人可见")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("切换到本人账户后可查看体重与运动趋势")
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(20)
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack(spacing: 8) {
                Text("🏃")
                    .font(OhanaFont.adaptive(size: 18))
                Text("人宠共健仪表盘")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 6)

            // 趣味总结
            Text(summaryText)
                .font(OhanaFont.adaptive(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.goPrimary)
                .padding(.horizontal, 20).padding(.bottom, 16)
                .lineLimit(2)

            // 统计小卡行
            statsRow
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // 体重多线图
            weightChart
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        // 外层由 HumanDetailView 等页面套「首页同款」白底卡片；此处不再叠半透明底避免发灰。
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 10) {
            miniStat(
                value: String(format: "%.1f", thisMonthWalkKm),
                unit: "km",
                label: "本月遛狗",
                color: Color.goPrimary
            )
            miniStat(
                value: human.weightLogs.sorted { $0.date > $1.date }.first.flatMap {
                    $0.weight.isFinite ? String(format: "%.1f", $0.weight) : nil
                } ?? "--",
                unit: "kg",
                label: "当前体重",
                color: Color.goTeal
            )
            if let pet = associatedPets.first,
               let w = pet.weightLogs.sorted(by: { $0.date > $1.date }).first?.weight {
                miniStat(
                    value: String(format: "%.1f", w),
                    unit: "kg",
                    label: "\(pet.name)体重",
                    color: pet.themeColor.color
                )
            }
        }
    }

    private func miniStat(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(unit)
                    .font(OhanaFont.adaptive(size: 10, weight: .bold))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Weight Chart
    @ViewBuilder
    private var weightChart: some View {
        let hPoints = humanWeightPoints
        let pPoints = associatedPets.first.map { petWeightPoints($0) } ?? []
        let hasData = hPoints.count >= 2 || pPoints.count >= 2

        VStack(alignment: .leading, spacing: 8) {
            Text("体重对比趋势")
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                .textCase(.uppercase)

            if !hasData {
                Text("体重记录 2 条以上后可查看趋势对比")
                    .font(OhanaFont.adaptive(size: 12, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 80)
            } else {
                let yDomain = OhanaChartStyle.yDomain(
                    values: (hPoints + pPoints).map(\.value),
                    includeZero: false,
                    paddingRatio: 0.16,
                    minimumSpan: 1
                )
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        legendItem(color: Color.goTeal, label: human.name)
                        if let pet = associatedPets.first {
                            legendItem(color: pet.themeColor.color, label: pet.name)
                        }
                    }
                    OhanaMinimalMultiTrendChart(
                        series: [
                            OhanaMinimalLineSeries(
                                id: "human",
                                points: hPoints.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value, id: $0.id.uuidString) },
                                tint: Color.goTeal.opacity(0.9)
                            ),
                            OhanaMinimalLineSeries(
                                id: "pet",
                                points: pPoints.map { OhanaMinimalChartPoint(date: $0.date, value: $0.value, id: $0.id.uuidString) },
                                tint: associatedPets.first?.themeColor.color ?? Color.goPrimary
                            )
                        ],
                        yDomain: yDomain,
                        progress: Double(chartRevealProgress)
                    )
                }
                .frame(height: 110)
                .onAppear { playWeightChartReveal() }
                .onChange(of: hPoints.count + pPoints.count) { _, _ in playWeightChartReveal() }
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            Text(label)
                .font(OhanaFont.adaptive(size: 9, weight: .semibold))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
        }
    }
}

// MARK: - WeightPoint 辅助结构
private struct WeightPoint: Identifiable {
    let id = UUID()
    let index: Int
    let date: Date
    let value: Double
    let label: String
}
