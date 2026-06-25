//
//  CoHealthDashboardView.swift
//  Ohana
//
//  模块5：人宠共健仪表盘

import SwiftData
import SwiftUI

struct CoHealthDashboardContentView: View {
    let human: Human
    let snapshot: CoHealthDashboardSnapshot

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
    private var humanWeightPoints: [CoHealthWeightPoint] {
        snapshot.humanWeightPoints
    }

    // 关联宠物（只取有遛狗 ledger 的狗）
    private var associatedPets: [CoHealthPetSnapshot] {
        snapshot.associatedPets(for: human.id, dogsOnly: true)
    }

    // 宠物体重（最近10条，升序）
    private func petWeightPoints(_ pet: CoHealthPetSnapshot) -> [CoHealthWeightPoint] {
        Array(
            pet.weightPoints
                .filter { $0.date >= past30Days && $0.value.isFinite }
                .sorted { $0.date < $1.date }
                .suffix(10)
        )
    }

    // 本月遛狗总里程（km）
    private var thisMonthWalkKm: Double {
        snapshot.thisMonthWalkKm(for: human.id, pets: associatedPets)
    }

    // 宠物本月体重变化
    private var petWeightDelta: Double? {
        snapshot.petWeightDelta(for: associatedPets)
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
                value: snapshot.latestHumanWeightKg.flatMap { $0.isFinite ? String(format: "%.1f", $0) : nil } ?? "--",
                unit: "kg",
                label: "当前体重",
                color: Color.goTeal
            )
            if let pet = associatedPets.first,
               let w = pet.latestWeightKg {
                miniStat(
                    value: String(format: "%.1f", w),
                    unit: "kg",
                    label: "\(pet.name)体重",
                    color: Color(hex: pet.themeColorHex)
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
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.chip))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.chip).strokeBorder(color.opacity(0.2), lineWidth: 1))
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
                            legendItem(color: Color(hex: pet.themeColorHex), label: pet.name)
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
                            tint: associatedPets.first.map { Color(hex: $0.themeColorHex) } ?? Color.goPrimary
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
