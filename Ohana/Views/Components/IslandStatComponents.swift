//
//  IslandStatComponents.swift
//  Ohana
//
//  Island Stats 横向卡片 + 专属图表组件 (C4)
//

import Observation
import SwiftUI

private let legacyChartBaseDate = Date(timeIntervalSinceReferenceDate: 0)

private func legacyTrendPoints(_ values: [Double], idPrefix: String) -> [OhanaMinimalChartPoint] {
    values.enumerated().compactMap { index, value in
        guard value.isFinite else { return nil }
        return OhanaMinimalChartPoint(
            date: legacyChartBaseDate.addingTimeInterval(Double(index) * 86400),
            value: value,
            id: "\(idPrefix)-\(index)-\(Int((value * 1000).rounded()))"
        )
    }
}

private func legacyBarPoints(_ values: [Double], labels: [String]) -> [OhanaMinimalChartPoint] {
    values.enumerated().compactMap { index, value in
        guard value.isFinite else { return nil }
        let label = index < labels.count ? labels[index] : nil
        return OhanaMinimalChartPoint(
            date: legacyChartBaseDate.addingTimeInterval(Double(index) * 86400),
            value: max(0, value),
            label: label,
            id: "legacy-bar-\(index)-\(Int((value * 1000).rounded()))-\(label ?? "")"
        )
    }
}

private var legacyChartEmptyState: some View {
    Text(L10n().tr(zh: "暂无数据", en: "No data", de: "Keine Daten"))
        .font(OhanaFont.caption2(.medium))
        .foregroundStyle(Color.ohanaTertiaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// MARK: - Overlapping Avatars（微型头像组）
struct OverlappingAvatarsView: View {
    let emojis: [String]
    var maxCount: Int = 4

    var body: some View {
        let shown = Array(emojis.prefix(maxCount))
        HStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.offset) { i, emoji in
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.mix(with: .black, by: 0.3))
                        .overlay(Circle().strokeBorder(Color.ohanaCardStroke, lineWidth: 1.5))
                        .frame(width: 24, height: 24) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    Text(emoji)
                        .font(OhanaFont.adaptive(size: 12))
                }
                .offset(x: CGFloat(-i) * 8)
                .zIndex(Double(shown.count - i))
            }
            if emojis.count > maxCount {
                ZStack {
                    Circle()
                        .fill(Color.ohanaControlFill)
                        .overlay(Circle().strokeBorder(Color.ohanaCardStroke, lineWidth: 1.5))
                        .frame(width: 24, height: 24) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    Text("+\(emojis.count - maxCount)")
                        .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                }
                .offset(x: CGFloat(-maxCount) * 8)
            }
        }
    }
}

// MARK: - Island Stat Card 容器
struct IslandStatCard<Chart: View>: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let subtitle: String
    let accentColor: Color
    var avatarEmojis: [String] = []
    var onTap: (() -> Void)?
    @ViewBuilder let chart: () -> Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：icon + 标题
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
            }

            // 大数字
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.metric(size: 34))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .ohanaNumericMotion(value)
                if !unit.isEmpty {
                    Text(unit)
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(accentColor)
                }
            }

            // 图表区域
            chart()
                .frame(height: 80)

            // 底部：头像组 或 副标题
            if !avatarEmojis.isEmpty {
                HStack(spacing: 8) {
                    OverlappingAvatarsView(emojis: avatarEmojis)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(OhanaFont.caption2(.medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                            .lineLimit(1)
                    }
                    Spacer()
                    if onTap != nil {
                        Image(systemName: "arrow.up.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 9, weight: .bold))
                            .foregroundStyle(accentColor.opacity(0.6))
                    }
                }
            } else if !subtitle.isEmpty {
                Text(subtitle)
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(width: 260, height: 212)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Multi-Pet Line Chart (多宠物体重趋势，每只独立颜色)
struct MultiPetLineChart: View {
    // [(petName, values, color)]
    let series: [(String, [Double], Color)]

    private var chartSeries: [OhanaMinimalLineSeries] {
        series.map { name, values, color in
            OhanaMinimalLineSeries(
                id: name,
                points: legacyTrendPoints(values, idPrefix: name),
                tint: color
            )
        }
    }

    var body: some View {
        if chartSeries.flatMap(\.points).count >= 2 {
            OhanaMinimalMultiTrendChart(series: chartSeries)
        } else {
            legacyChartEmptyState
        }
    }
}

// MARK: - Mini Line Chart (体重趋势)
struct MiniLineChart: View {
    let values: [Double]
    let accentColor: Color

    var body: some View {
        let points = legacyTrendPoints(values, idPrefix: "mini-line")
        if points.count >= 2 {
            OhanaMinimalTrendChart(points: points, tint: accentColor)
        } else {
            legacyChartEmptyState
        }
    }
}

// MARK: - Mini Bar Chart (步数/遛狗/花费)
struct MiniBarChart: View {
    let values: [Double]
    let labels: [String]
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let points = legacyBarPoints(values, labels: labels)
            if points.isEmpty {
                legacyChartEmptyState
            } else {
                OhanaMinimalBarChart(
                    points: points,
                    tint: accentColor,
                    showsLabels: !labels.isEmpty,
                    maxBarHeight: max(8, geo.size.height - (labels.isEmpty ? 0 : 14)),
                    emptyBarColor: accentColor.opacity(0.16)
                )
            }
        }
    }
}

// MARK: - Multi-Pet Expense Bar (各宠物花费对比)
struct MultiPetExpenseBar: View {
    // [(petName, amount, color)]
    let series: [(String, Double, Color)]
    @State private var animPhase: CGFloat = 0.0

    private var maxAmount: Double { series.map(\.1).max() ?? 1 }

    private var animationKey: String {
        series
            .map { name, value, _ in "\(name):\(String(format: "%.3f", value))" }
            .joined(separator: "|")
    }

    private func playAnimation() {
        animPhase = 0
        withAnimation(GoMotion.page) {
            animPhase = 1.0
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if series.isEmpty {
                Text("暂无花费")
                    .font(OhanaFont.adaptive(size: 10, weight: .medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let barCount = series.count
                let spacing: CGFloat = 4
                let barW = (w - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
                let labelH: CGFloat = 14
                let chartH = h - labelH

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(series.enumerated()), id: \.offset) { _, item in
                        let (name, amount, color) = item
                        let barH = max(4, CGFloat(amount / maxAmount) * chartH * animPhase)
                        VStack(spacing: 2) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                                .fill(color)
                                .frame(width: barW, height: barH)
                            Text(name)
                                .font(OhanaFont.adaptive(size: 7, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                                .frame(width: barW)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: w, height: h, alignment: .bottom)
                .onAppear { playAnimation() }
                .onChange(of: animationKey) { _, _ in playAnimation() }
            }
        }
    }
}

// MARK: - Synergy Flash Card 羁绊简报卡
/// 数据模型：一条简报快报
struct SynergyBrief: Identifiable {
    let id = UUID()
    let emojis: [String] // 左侧头像组
    let headline: String // 大标题（可含 \n）
    let subtext: String // 副文案
    let accentColor: Color // 高亮色
}

/// 简报生成引擎（后台计算，主线程安全更新）
@Observable
@MainActor
final class SynergyEngine {
    var briefs: [SynergyBrief] = []

    func reload(pets: [Pet], humans: [Human]) {
        // 在 MainActor 上提取纯值，再切到后台计算，避免跨线程访问 SwiftData 对象
        let petSnapshots: [(avatarEmoji: String, name: String, coconutBalance: Int,
                            careLogs: [(type: String, executorId: String?, date: Date)],
                            walkLogs: [(executorId: String?, distanceMeters: Double, startDate: Date)],
                            expenseLogs: [(executorId: String?, amount: Double, date: Date)])] =
            pets.map { p in
                (p.avatarEmoji, p.name, p.coconutBalance,
                 p.careLogs.map { ($0.type, $0.executorId, $0.date) },
                 p.walkLogs.map { ($0.executorId, $0.distanceMeters, $0.startDate) },
                 p.expenseLogs.map { ($0.executorId, $0.amount, $0.date) })
            }
        let humanSnapshots: [(id: String, avatarEmoji: String, name: String, coconutBalance: Int)] =
            humans.map { ($0.id.uuidString, $0.avatarEmoji, $0.name, $0.coconutBalance) }

        Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            let result = Self.computeFromSnapshots(pets: petSnapshots, humans: humanSnapshots)
            await MainActor.run {
                self.briefs = result
            }
        }
    }

    // 快照类型别名（纯值，可安全跨线程传递）
    private typealias PetSnap = (avatarEmoji: String, name: String, coconutBalance: Int,
                                 careLogs: [(type: String, executorId: String?, date: Date)],
                                 walkLogs: [(executorId: String?, distanceMeters: Double, startDate: Date)],
                                 expenseLogs: [(executorId: String?, amount: Double, date: Date)])
    private typealias HumanSnap = (id: String, avatarEmoji: String, name: String, coconutBalance: Int)

    private nonisolated static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: 1)
    }

    private nonisolated static func computeFromSnapshots(pets: [PetSnap], humans: [HumanSnap]) -> [SynergyBrief] {
        var results: [SynergyBrief] = []
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!

        // ── 1. 铲屎战况（本月各人执行者对比）
        if humans.count >= 2 {
            let allLitters = pets.flatMap(\.careLogs)
                .filter { $0.type == CareType.litter.rawValue && $0.date >= monthStart }
            let counts: [(HumanSnap, Int)] = humans.map { h in
                (h, allLitters.count(where: { $0.executorId == h.id }))
            }.filter { $0.1 > 0 }
            if counts.count >= 2 {
                let sorted = counts.sorted { $0.1 > $1.1 }
                let winner = sorted[0]
                let loser = sorted[1]
                results.append(SynergyBrief(
                    emojis: [winner.0.avatarEmoji, loser.0.avatarEmoji] + pets.prefix(1).map(\.avatarEmoji),
                    headline: "\(winner.0.name) 铲了 \(winner.1) 次",
                    subtext: "本月铲屎战况 \(winner.1):\(loser.1)，\(loser.0.name) 加油！🧹",
                    accentColor: Self.rgb(255, 244, 79)
                ))
            }
        }

        // ── 2. 散步搭子（本月遛狗最多的人+宠物组合）
        let allWalks = pets.flatMap { p in
            p.walkLogs.filter { $0.startDate >= monthStart }.map { (p, $0) }
        }
        if !allWalks.isEmpty {
            var humanKm: [String: (HumanSnap, Double, String)] = [:] // id → (human, km, topPetEmoji)
            for (pet, walk) in allWalks {
                guard let hid = walk.executorId,
                      let h = humans.first(where: { $0.id == hid }) else { continue }
                let prev = humanKm[hid]?.1 ?? 0
                humanKm[hid] = (h, prev + walk.distanceMeters / 1000, pet.avatarEmoji)
            }
            if let top = humanKm.values.max(by: { $0.1 < $1.1 }) {
                results.append(SynergyBrief(
                    emojis: [top.0.avatarEmoji, top.2],
                    headline: String(format: "%.1f km 最强搭档", top.1),
                    subtext: "\(top.0.name) 本月称霸遛宠榜 🏃",
                    accentColor: Self.rgb(200, 255, 0)
                ))
            } else {
                let totalKm = allWalks.reduce(0.0) { $0 + $1.1.distanceMeters / 1000 }
                results.append(SynergyBrief(
                    emojis: Array(pets.prefix(3).map(\.avatarEmoji)),
                    headline: String(format: "本月探索 %.1f km", totalKm),
                    subtext: "全岛宠物集体出征 🐾",
                    accentColor: Self.rgb(200, 255, 0)
                ))
            }
        }

        // ── 3. 首席提款机（本月花费最多的执行者）
        let allExpenses = pets.flatMap(\.expenseLogs).filter { $0.date >= monthStart }
        if !allExpenses.isEmpty {
            var humanSpend: [String: (HumanSnap, Double)] = [:]
            for exp in allExpenses {
                guard let hid = exp.executorId,
                      let h = humans.first(where: { $0.id == hid }) else { continue }
                humanSpend[hid] = (h, (humanSpend[hid]?.1 ?? 0) + exp.amount)
            }
            if let top = humanSpend.values.max(by: { $0.1 < $1.1 }) {
                results.append(SynergyBrief(
                    emojis: [top.0.avatarEmoji, "💸"],
                    headline: "\(AppCurrency.format(top.1, fractionDigits: 0)) 首席提款机",
                    subtext: "\(top.0.name) 本月最豪 💳",
                    accentColor: Self.rgb(255, 71, 87)
                ))
            }
        }

        // ── 4. 椰子富翁（个人账户余额最高）
        var allEntities: [(String, String, Int)] = []
        allEntities += pets.map { ($0.avatarEmoji, $0.name, $0.coconutBalance) }
        allEntities += humans.map { ($0.avatarEmoji, $0.name, $0.coconutBalance) }
        if let richest = allEntities.filter({ $0.2 > 0 }).max(by: { $0.2 < $1.2 }) {
            results.append(SynergyBrief(
                emojis: [richest.0, "🥥"],
                headline: "\(richest.2) 🥥 岛主",
                subtext: "\(richest.1) 是全岛最富有的成员！",
                accentColor: Self.rgb(200, 255, 0)
            ))
        }

        // 安全降级
        if results.isEmpty {
            results.append(SynergyBrief(
                emojis: pets.prefix(2).map(\.avatarEmoji) + humans.prefix(2).map(\.avatarEmoji),
                headline: "欢迎来到欧哈纳！",
                subtext: "多打卡，解锁家庭故事 🌴",
                accentColor: Self.rgb(0, 212, 170)
            ))
        }
        return results
    }
}

struct SynergyFlashCard: View {
    let pets: [Pet]
    let humans: [Human]

    @State private var engine = SynergyEngine()
    @State private var currentIndex: Int = 0
    @State private var timer: Timer? = nil
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var visibleBriefHumans: [Human] {
        humans.filter {
            !appServices.privacy.isLocked(.expense, for: $0, viewedBy: activeHumanId) &&
                !appServices.privacy.isLocked(.wishlist, for: $0, viewedBy: activeHumanId) &&
                !appServices.privacy.isLocked(.workout, for: $0, viewedBy: activeHumanId)
        }
    }

    var body: some View {
        Group {
            if engine.briefs.isEmpty {
                EmptyView()
            } else {
                let brief = engine.briefs[currentIndex % engine.briefs.count]
                VStack(alignment: .leading, spacing: 14) {
                    // 顶部标签
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                            .foregroundStyle(brief.accentColor)
                        Text("家庭简报")
                            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                            .tracking(2)
                        Spacer()
                        // 分页点
                        HStack(spacing: 4) {
                            ForEach(0 ..< engine.briefs.count, id: \.self) { i in
                                Circle()
                                    .fill(i == currentIndex % engine.briefs.count ? brief.accentColor : .white.opacity(0.2))
                                    .frame(width: 4, height: 4) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            }
                        }
                    }

                    // 主内容行：头像 + 文案
                    HStack(spacing: 16) {
                        // 重叠头像
                        OverlappingAvatarsView(emojis: brief.emojis, maxCount: 3)
                            .frame(width: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(brief.headline)
                                .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .lineLimit(2)
                            Text(brief.subtext)
                                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }

                    // 高亮色条
                    Capsule()
                        .fill(brief.accentColor.opacity(0.35))
                        .frame(height: 3)
                }
                .padding(16)
                .frame(width: 280, height: 160)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(GoMotion.feedback) {
                        currentIndex = (currentIndex + 1) % engine.briefs.count
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .id(currentIndex)
                .animation(GoMotion.page, value: currentIndex)
            }
        }
        .onAppear {
            reloadBriefs()
            startTimer()
        }
        .onDisappear { stopTimer() }
        .onChange(of: pets.count) { _, _ in reloadBriefs() }
        .onChange(of: humans.count) { _, _ in reloadBriefs() }
        .onChange(of: activeHumanIdStr) { _, _ in reloadBriefs() }
    }

    private func reloadBriefs() {
        engine.reload(pets: pets, humans: visibleBriefHumans)
    }

    private func startTimer() {
        stopTimer()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { _ in
            Task { @MainActor in
                guard !engine.briefs.isEmpty else { return }
                withAnimation(GoMotion.page) {
                    currentIndex = (currentIndex + 1) % engine.briefs.count
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Coconut Wealth Ranking Card 椰子财富榜
struct CoconutWealthRankingCard: View {
    let pets: [Pet]
    let humans: [Human]
    var onTap: (() -> Void)?
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var visibleWealthHumans: [Human] {
        appServices.privacy.unlockedHumans(for: .wishlist, from: humans, viewedBy: activeHumanId)
    }

    // 当前查看者可见的全岛总资产；隐私成员的个人椰子余额不计入展示。
    private var computedTotal: Int {
        pets.reduce(0) { $0 + $1.coconutBalance } + visibleWealthHumans.reduce(0) { $0 + $1.coconutBalance }
    }

    private struct RankEntry: Identifiable {
        let id = UUID()
        let emoji: String
        let name: String
        let balance: Int
    }

    private var leaderboard: [RankEntry] {
        var all: [RankEntry] = []
        all += pets.map { RankEntry(emoji: $0.avatarEmoji, name: $0.name, balance: $0.coconutBalance) }
        all += visibleWealthHumans.map { RankEntry(emoji: $0.avatarEmoji, name: $0.name, balance: $0.coconutBalance) }
        // Bug11: 即使 balance=0 也展示所有成员，按余额降序，最多显示前3名
        return all.sorted { $0.balance > $1.balance }.prefix(3).map(\.self)
    }

    private let rankEmojis = ["🥇", "🥈", "🥉", "4️⃣"]

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 12) {
                // 标题行
                HStack(spacing: 6) {
                    Text("🌴")
                        .font(OhanaFont.adaptive(size: 14))
                    Text("Ohana财富")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.5))
                        .tracking(1)
                    Spacer()
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 10, weight: .semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                }

                // 大数字
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(computedTotal)")
                        .font(OhanaFont.metric(size: 36))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .ohanaNumericMotion(computedTotal)
                    Text("🥥")
                        .font(OhanaFont.adaptive(size: 18))
                }

                OhanaDashedDivider(color: Color.ohanaCardStroke).padding(.vertical, 4)

                // 排行榜
                if leaderboard.isEmpty {
                    Text("完成打卡即可解锁财富榜 ✨")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(leaderboard.enumerated()), id: \.element.id) { i, entry in
                            HStack(spacing: 10) {
                                Text(rankEmojis[i])
                                    .font(OhanaFont.adaptive(size: 14))
                                    .frame(width: 20)
                                ZStack {
                                    Circle()
                                        .fill(Color.goPrimary.mix(with: .black, by: 0.35))
                                        .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                                    Text(entry.emoji)
                                        .font(OhanaFont.adaptive(size: 14))
                                }
                                Text(entry.name)
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.balance) 🥥")
                                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(i == 0 ? Color.goPrimary : Color.ohanaSecondaryText)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(i == 0 ? Color.goPrimary.opacity(0.15) : Color.ohanaControlFill,
                                                in: Capsule())
                                    .ohanaNumericMotion(entry.balance)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

// MARK: - Mini Ring Chart (粮仓剩余)
struct MiniRingChart: View {
    let progress: Double
    let accentColor: Color
    @State private var animPhase: CGFloat = 0.0

    private func playAnimation() {
        animPhase = 0
        withAnimation(GoMotion.quick) {
            animPhase = 1.0
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ohanaCardStroke, lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(progress) * animPhase)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(GoMotion.quick, value: progress * Double(animPhase))

            Text("\(Int(progress * 100))%")
                .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)
                .ohanaNumericMotion(Int(progress * 100))
        }
        .frame(width: 44, height: 44)
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear { playAnimation() }
        .onChange(of: progress) { _, _ in playAnimation() }
    }
}
