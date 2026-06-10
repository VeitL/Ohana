//
//  IslandExplorationDashboard.swift
//  Ohana
//
//  全岛探索详情页 — Bento Box 深色毛玻璃主题
//  巡岛王者 + 劳模铲屎官 + 极简里程条 + 成员里程榜
//

import SwiftUI
import SwiftData

// MARK: - Time Range

enum ExploreTimeRange: String, CaseIterable, Identifiable {
    case week  = "周"
    case month = "月"
    case year  = "年"
    case all   = "全部"
    var id: String { rawValue }
}

// MARK: - Internal Models

private struct PetWalkSummary: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let color: Color
    let totalMeters: Double
}

private struct DailyStackPoint: Identifiable {
    let id = UUID()
    let date: Date
    let petName: String
    let petColor: Color
    let km: Double
}

// MARK: - Main View

struct IslandExplorationDashboardContentView: View {
    var standalone: Bool = true
    let pets: [Pet]
    let humans: [Human]
    let allWalkLogs: [PetWalkLog]

    @Environment(\.dismiss)       private var dismiss

    @State private var timeRange: ExploreTimeRange = .month
    @State private var animationProgress: Double = 0.0

    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""

    // MARK: - Filtered logs

    private var filteredLogs: [PetWalkLog] {
        let now = Date()
        let cal = Calendar.current
        let cutoff: Date? = {
            switch timeRange {
            case .week:  return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))
            case .month: return cal.dateInterval(of: .month, for: now)?.start
            case .year:  return cal.dateInterval(of: .year,  for: now)?.start
            case .all:   return nil
            }
        }()
        return allWalkLogs.filter {
            guard let c = cutoff else { return true }
            return $0.startDate >= c
        }
    }

    private var totalMeters: Double {
        filteredLogs.reduce(0) { $0 + $1.distanceMeters }
    }

    // MARK: - Bento 数据

    private var petSummaries: [PetWalkSummary] {
        pets.compactMap { pet -> PetWalkSummary? in
            let m = filteredLogs.filter { $0.pet?.id == pet.id }
                                .reduce(0.0) { $0 + $1.distanceMeters }
            guard m > 0 else { return nil }
            return PetWalkSummary(id: pet.id, name: pet.name,
                                  emoji: pet.avatarEmoji,
                                  color: pet.themeColor.color,
                                  totalMeters: m)
        }.sorted { $0.totalMeters > $1.totalMeters }
    }

    // 巡岛王者（里程最高的宠物）
    private var topPet: PetWalkSummary? { petSummaries.first }

    // 劳模铲屎官（带狗散步最多的人类）
    private struct HumanWalkStats {
        let human: Human
        let totalMeters: Double
    }
    private var topHuman: HumanWalkStats? {
        var dict: [String: (Human, Double)] = [:]
        for log in filteredLogs {
            guard let hid = log.executorId,
                  let h = humans.first(where: { $0.id.uuidString == hid }) else { continue }
            dict[hid] = (h, (dict[hid]?.1 ?? 0) + log.distanceMeters)
        }
        guard let best = dict.values.max(by: { $0.1 < $1.1 }) else { return nil }
        return HumanWalkStats(human: best.0, totalMeters: best.1)
    }

    // MARK: - 图表数据（极简里程条）

    private var stackedPoints: [DailyStackPoint] {
        let cal = Calendar.current
        var result: [DailyStackPoint] = []
        // 按 (day, petId) 聚合
        var grouped: [Date: [String: (Double, Pet)]] = [:]
        for log in filteredLogs {
            guard let pet = log.pet else { continue }
            let day = cal.startOfDay(for: log.startDate)
            if grouped[day] == nil { grouped[day] = [:] }
            let prev = grouped[day]![pet.id.uuidString]?.0 ?? 0
            grouped[day]![pet.id.uuidString] = (prev + log.distanceMeters / 1000, pet)
        }
        for (day, petMap) in grouped.sorted(by: { $0.key < $1.key }) {
            for (_, (km, pet)) in petMap {
                result.append(DailyStackPoint(
                    date: day,
                    petName: pet.name,
                    petColor: pet.themeColor.color,
                    km: km * animationProgress
                ))
            }
        }
        return result
    }

    private var dailyWalkTotalPoints: [OhanaMinimalChartPoint] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: stackedPoints) { cal.startOfDay(for: $0.date) }
        return grouped
            .sorted { $0.key < $1.key }
            .map { day, items in
                OhanaMinimalChartPoint(
                    date: day,
                    value: items.reduce(0) { $0 + $1.km }
                )
            }
    }

    // MARK: - 趣味副标题

    private var funSubtitle: String {
        let km = totalMeters / 1000
        switch km {
        case ..<1:   return "才刚出发，岛屿等你去探索 🌿"
        case ..<10:  return "≈ 绕操场走了好几圈 🏃"
        case ..<42:  return "≈ 相当于城市漫步一整天 🏙️"
        case ..<100: return "≈ 完成了一个全程马拉松 🏃"
        case ..<500: return "≈ 徒步跨越了一座城市 🗺️"
        default:     return "≈ 几乎走了整个沿海线 🌊"
        }
    }

    // MARK: - Body

    var body: some View {
        dashboardBody
            .onAppear { triggerAnimation() }
            .onChange(of: timeRange) { _, _ in
                animationProgress = 0
                triggerAnimation()
            }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()
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
                heroDisplay
                funBentoRow
                stackedBarChartCard
                leaderboardCard
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func triggerAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(GoMotion.page) {
                animationProgress = 1.0
            }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
            Text("全岛探索")
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
        }
        .padding(.top, 64)
    }

    // MARK: - 模块A：核心总数据 Hero Display

    private var heroDisplay: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 时间 filter
            Picker("", selection: $timeRange) {
                ForEach(ExploreTimeRange.allCases) { r in
                    Text(r.rawValue).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            // 大数字
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(
                    (totalMeters / 1000)
                        .formatted(.number.precision(.fractionLength(totalMeters >= 1000 ? 1 : 0)))
                )
                .font(OhanaFont.adaptive(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .contentTransition(.numericText())
                .animation(GoMotion.feedback, value: totalMeters)

                Text("km")
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                    .padding(.bottom, 3)

                Spacer()

                Text(funSubtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
                    .lineLimit(2)
            }
            .padding(.horizontal, 4)

            // 悬浮极简里程条（无背景卡片）
            let data = stackedPoints
            if !data.isEmpty {
                OhanaMinimalBarChart(
                    points: dailyWalkTotalPoints,
                    tint: Color.goPrimary,
                    showsLabels: dailyWalkTotalPoints.count <= 10,
                    maxBarHeight: 86
                )
                .frame(height: 120)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 模块B：荣誉看板 Fun Bento

    private var funBentoRow: some View {
        HStack(spacing: 12) {
            // 左：巡岛王者
            bentoHalfCard(
                title: "🐶 巡岛王者",
                accentColor: Color.goPrimary
            ) {
                if let p = topPet {
                    VStack(spacing: 6) {
                        Text(p.emoji).font(OhanaFont.adaptive(size: 38))
                        Text(p.name)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(
                            (p.totalMeters / 1000)
                                .formatted(.number.precision(.fractionLength(1))) + " km"
                        )
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goPrimary)
                    }
                } else {
                    emptyBentoLabel("暂无数据")
                }
            }

            // 右：劳模铲屎官
            bentoHalfCard(
                title: "🥾 劳模铲屎官",
                accentColor: Color.goTeal
            ) {
                if let h = topHuman {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.goPrimary.mix(with: .black, by: 0.3))
                                .frame(width: 44, height: 44)
                            Text(h.human.avatarEmoji).font(OhanaFont.adaptive(size: 24))
                            
                            if h.human.id.uuidString == activeHumanId && equippedTitle == "title_pioneer" {
                                Text("🚀")
                                    .font(OhanaFont.adaptive(size: 14))
                                    .padding(4)
                                    .background(Color.ohanaControlFill, in: Circle())
                                    .offset(x: 16, y: -16)
                            }
                        }
                        Text(h.human.name)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(
                            (h.totalMeters / 1000)
                                .formatted(.number.precision(.fractionLength(1))) + " km"
                        )
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goTeal)
                    }
                } else {
                    emptyBentoLabel("暂无记录")
                }
            }
        }
    }

    @ViewBuilder
    private func bentoHalfCard<Content: View>(
        title: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                .tracking(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130)
        .background(accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func emptyBentoLabel(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 11, weight: .medium))
            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.2))
    }

    // MARK: - 模块C：探索趋势图（极简里程条）

    private var stackedBarChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("探索趋势")
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                .tracking(1)

            let data = stackedPoints
            if data.isEmpty {
                Text("暂无遛宠记录")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.2))
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                OhanaMinimalBarChart(
                    points: dailyWalkTotalPoints,
                    tint: Color.goPrimary,
                    showsLabels: dailyWalkTotalPoints.count <= 10,
                    maxBarHeight: 100
                )
                .frame(height: 140)

                // 图例
                if petSummaries.count > 1 {
                    HStack(spacing: 12) {
                        ForEach(petSummaries.prefix(5)) { s in
                            HStack(spacing: 4) {
                                Circle().fill(s.color).frame(width: 7, height: 7) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                                Text(s.name)
                                    .font(OhanaFont.adaptive(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.ohanaDivider, lineWidth: 1))
    }

    // MARK: - 模块D：成员贡献榜

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("里程贡献榜")
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                .tracking(1)

            if petSummaries.isEmpty {
                Text("暂无遛宠记录")
                    .font(OhanaFont.adaptive(size: 11, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.2))
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                let maxM = petSummaries.first?.totalMeters ?? 1
                VStack(spacing: 10) {
                    ForEach(petSummaries) { s in
                        HStack(spacing: 12) {
                            // 头像
                            ZStack {
                                Circle()
                                    .fill(s.color.opacity(0.2))
                                    .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                                Text(s.emoji).font(OhanaFont.adaptive(size: 18))
                            }

                            // 名字 + 进度条
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.name)
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(1)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.ohanaDivider.opacity(0.55))
                                            .frame(height: 5)
                                        Capsule()
                                            .fill(s.color)
                                            .frame(
                                                width: max(4, geo.size.width * CGFloat(s.totalMeters / maxM) * CGFloat(animationProgress)),
                                                height: 5
                                            )
                                            .animation(GoMotion.page, value: animationProgress)
                                    }
                                }
                                .frame(height: 5)
                            }

                            // 里程数值
                            Text(
                                (s.totalMeters / 1000)
                                    .formatted(.number.precision(.fractionLength(1))) + " km"
                            )
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(s.color)
                            .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.ohanaDivider, lineWidth: 1))
    }
}
