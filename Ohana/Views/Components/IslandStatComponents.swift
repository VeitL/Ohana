//
//  IslandStatComponents.swift
//  Ohana
//
//  Island Stats 横向卡片 + 专属图表组件 (C4)
//

import SwiftUI
import Observation

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
                        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5))
                        .frame(width: 24, height: 24)
                    Text(emoji)
                        .font(.system(size: 12))
                }
                .offset(x: CGFloat(-i) * 8)
                .zIndex(Double(shown.count - i))
            }
            if emojis.count > maxCount {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1.5))
                        .frame(width: 24, height: 24)
                    Text("+\(emojis.count - maxCount)")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
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
    var onTap: (() -> Void)? = nil
    @ViewBuilder let chart: () -> Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：icon + 标题
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(.primary.opacity(0.55))
            }

            // 大数字
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(OhanaFont.metric(size: 34))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
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
                            .foregroundStyle(.primary.opacity(0.3))
                            .lineLimit(1)
                    }
                    Spacer()
                    if onTap != nil {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(accentColor.opacity(0.6))
                    }
                }
            } else if !subtitle.isEmpty {
                Text(subtitle)
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(.primary.opacity(0.35))
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
    @State private var revealProgress: CGFloat = 0.0

    private var allValues: [Double] { series.flatMap { $0.1 } }
    private var minV: Double { (allValues.min() ?? 0) - 0.1 }
    private var maxV: Double { (allValues.max() ?? 1) + 0.1 }
    private var range: Double { max(maxV - minV, 0.01) }

    private func xPos(_ i: Int, count: Int, w: CGFloat) -> CGFloat {
        count <= 1 ? w / 2 : CGFloat(i) / CGFloat(count - 1) * w
    }
    private func yPos(_ v: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((v - minV) / range) * h
    }

    private var animationKey: String {
        series
            .map { name, values, _ in
                let joined = values.map { String(format: "%.3f", $0) }.joined(separator: ",")
                return "\(name):\(joined)"
            }
            .joined(separator: "|")
    }

    private func playAnimation() {
        revealProgress = 0
        withAnimation(.linear(duration: 0.5)) {
            revealProgress = 1.0
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let chartContent = ZStack {
                if allValues.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.25))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                        let (_, values, color) = s
                        if values.count >= 2 {
                            // 渐变填充
                            Path { path in
                                path.move(to: CGPoint(x: xPos(0, count: values.count, w: w), y: h))
                                path.addLine(to: CGPoint(x: xPos(0, count: values.count, w: w), y: yPos(values[0], h: h)))
                                for i in 1..<values.count {
                                    let prev = CGPoint(x: xPos(i-1, count: values.count, w: w), y: yPos(values[i-1], h: h))
                                    let curr = CGPoint(x: xPos(i,   count: values.count, w: w), y: yPos(values[i],   h: h))
                                    let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y)
                                    let cp2 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
                                    path.addCurve(to: curr, control1: cp1, control2: cp2)
                                }
                                path.addLine(to: CGPoint(x: xPos(values.count-1, count: values.count, w: w), y: h))
                                path.closeSubpath()
                            }
                            .fill(LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom))

                            // 折线
                            Path { path in
                                path.move(to: CGPoint(x: xPos(0, count: values.count, w: w), y: yPos(values[0], h: h)))
                                for i in 1..<values.count {
                                    let prev = CGPoint(x: xPos(i-1, count: values.count, w: w), y: yPos(values[i-1], h: h))
                                    let curr = CGPoint(x: xPos(i,   count: values.count, w: w), y: yPos(values[i],   h: h))
                                    let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y)
                                    let cp2 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
                                    path.addCurve(to: curr, control1: cp1, control2: cp2)
                                }
                            }
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                            // 最新点
                            if let last = values.last {
                                Circle().fill(color).frame(width: 5, height: 5)
                                    .position(x: xPos(values.count-1, count: values.count, w: w), y: yPos(last, h: h))
                                    .opacity(revealProgress > 0.98 ? 1 : 0)
                            }
                        }
                    }
                }
            }
            chartContent
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: max(1, w * revealProgress))
                }
            .onAppear { playAnimation() }
            .onChange(of: animationKey) { _, _ in playAnimation() }
        }
    }
}

// MARK: - Mini Line Chart (体重趋势)
struct MiniLineChart: View {
    let values: [Double]
    let accentColor: Color
    @State private var revealProgress: CGFloat = 0.0

    private var minV: Double { (values.min() ?? 0) - 0.1 }
    private var maxV: Double { (values.max() ?? 1) + 0.1 }
    private var range: Double { max(maxV - minV, 0.01) }

    private func xPos(_ i: Int, w: CGFloat) -> CGFloat {
        values.count <= 1 ? w / 2 : CGFloat(i) / CGFloat(values.count - 1) * w
    }
    private func yPos(_ v: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((v - minV) / range) * h
    }

    private var animationKey: String {
        values.map { String(format: "%.3f", $0) }.joined(separator: ",")
    }

    private func playAnimation() {
        revealProgress = 0
        withAnimation(.linear(duration: 0.45)) {
            revealProgress = 1.0
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let chartContent = ZStack {
                if values.count >= 2 {
                    // 填充渐变
                    Path { path in
                        path.move(to: CGPoint(x: xPos(0, w: w), y: h))
                        path.addLine(to: CGPoint(x: xPos(0, w: w), y: yPos(values[0], h: h)))
                        for i in 1..<values.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(values[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(values[i], h: h))
                            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y)
                            let cp2 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
                            path.addCurve(to: curr, control1: cp1, control2: cp2)
                        }
                        path.addLine(to: CGPoint(x: xPos(values.count - 1, w: w), y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.35), accentColor.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ))

                    // 折线
                    Path { path in
                        path.move(to: CGPoint(x: xPos(0, w: w), y: yPos(values[0], h: h)))
                        for i in 1..<values.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(values[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(values[i], h: h))
                            let cp1 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: prev.y)
                            let cp2 = CGPoint(x: prev.x + (curr.x - prev.x) * 0.5, y: curr.y)
                            path.addCurve(to: curr, control1: cp1, control2: cp2)
                        }
                    }
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                    // 最新点
                    if let last = values.last {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 5, height: 5)
                            .position(x: xPos(values.count - 1, w: w), y: yPos(last, h: h))
                            .opacity(revealProgress > 0.98 ? 1 : 0)
                    }
                } else {
                    Text("暂无数据")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.25))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            chartContent
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: max(1, w * revealProgress))
                }
            .onAppear { playAnimation() }
            .onChange(of: animationKey) { _, _ in playAnimation() }
        }
    }
}

// MARK: - Mini Bar Chart (步数/遛狗/花费)
struct MiniBarChart: View {
    let values: [Double]
    let labels: [String]
    let accentColor: Color
    @State private var animPhase: CGFloat = 0.0

    private var animationKey: String {
        values.map { String(format: "%.3f", $0) }.joined(separator: ",")
    }

    private func playAnimation() {
        animPhase = 0
        withAnimation(.linear(duration: 0.35)) {
            animPhase = 1.0
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxV = max(values.max() ?? 1, 1)
            let count = values.count
            let barW = count > 0 ? (w - CGFloat(count - 1) * 3) / CGFloat(count) : w

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, val in
                    VStack(spacing: 2) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                val == values.max()
                                    ? accentColor
                                    : accentColor.opacity(0.35)
                            )
                            .frame(
                                width: barW,
                                height: max(3, CGFloat(val / maxV) * (h - (labels.isEmpty ? 0 : 14)) * animPhase)
                            )
                        if !labels.isEmpty && i < labels.count {
                            Text(labels[i])
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.primary.opacity(0.3))
                                .frame(width: barW)
                        }
                    }
                }
            }
            .frame(width: w, height: h, alignment: .bottom)
            .onAppear { playAnimation() }
            .onChange(of: animationKey) { _, _ in playAnimation() }
        }
    }
}

// MARK: - Multi-Pet Expense Bar (各宠物花费对比)
struct MultiPetExpenseBar: View {
    // [(petName, amount, color)]
    let series: [(String, Double, Color)]
    @State private var animPhase: CGFloat = 0.0

    private var maxAmount: Double { series.map { $0.1 }.max() ?? 1 }

    private var animationKey: String {
        series
            .map { name, value, _ in "\(name):\(String(format: "%.3f", value))" }
            .joined(separator: "|")
    }

    private func playAnimation() {
        animPhase = 0
        withAnimation(.linear(duration: 0.4)) {
            animPhase = 1.0
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if series.isEmpty {
                Text("暂无花费")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.25))
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
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color)
                                .frame(width: barW, height: barH)
                            Text(name)
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
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
    let emojis: [String]      // 左侧头像组
    let headline: String      // 大标题（可含 \n）
    let subtext: String       // 副文案
    let accentColor: Color    // 高亮色
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

        Task.detached(priority: .utility) {
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

    private nonisolated static func computeFromSnapshots(pets: [PetSnap], humans: [HumanSnap]) -> [SynergyBrief] {
        var results: [SynergyBrief] = []
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!

        // ── 1. 铲屎战况（本月各人执行者对比）
        if humans.count >= 2 {
            let allLitters = pets.flatMap { $0.careLogs }
                .filter { $0.type == CareType.litter.rawValue && $0.date >= monthStart }
            let counts: [(HumanSnap, Int)] = humans.map { h in
                (h, allLitters.filter { $0.executorId == h.id }.count)
            }.filter { $0.1 > 0 }
            if counts.count >= 2 {
                let sorted = counts.sorted { $0.1 > $1.1 }
                let winner = sorted[0]; let loser = sorted[1]
                results.append(SynergyBrief(
                    emojis: [winner.0.avatarEmoji, loser.0.avatarEmoji] + pets.prefix(1).map { $0.avatarEmoji },
                    headline: "\(winner.0.name) 铲了 \(winner.1) 次",
                    subtext: "本月铲屎战况 \(winner.1):\(loser.1)，\(loser.0.name) 加油！🧹",
                    accentColor: .goYellow
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
                    accentColor: .goLime
                ))
            } else {
                let totalKm = allWalks.reduce(0.0) { $0 + $1.1.distanceMeters / 1000 }
                results.append(SynergyBrief(
                    emojis: Array(pets.prefix(3).map { $0.avatarEmoji }),
                    headline: String(format: "本月探索 %.1f km", totalKm),
                    subtext: "全岛宠物集体出征 🐾",
                    accentColor: .goLime
                ))
            }
        }

        // ── 3. 首席提款机（本月花费最多的执行者）
        let allExpenses = pets.flatMap { $0.expenseLogs }.filter { $0.date >= monthStart }
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
                    headline: String(format: "¥%.0f 首席提款机", top.1),
                    subtext: "\(top.0.name) 本月最豪 💳",
                    accentColor: .goRed
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
                accentColor: .goLime
            ))
        }

        // 安全降级
        if results.isEmpty {
            results.append(SynergyBrief(
                emojis: (pets.prefix(2).map { $0.avatarEmoji } + humans.prefix(2).map { $0.avatarEmoji }),
                headline: "欢迎来到欧哈纳！",
                subtext: "多打卡，解锁家庭故事 🌴",
                accentColor: .goTeal
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

    var body: some View {
        Group {
            if engine.briefs.isEmpty {
                EmptyView()
            } else {
                let brief = engine.briefs[currentIndex % engine.briefs.count]
                VStack(alignment: .leading, spacing: 14) {
                    // 顶部标签
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(brief.accentColor)
                        Text("家庭简报")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                            .tracking(2)
                        Spacer()
                        // 分页点
                        HStack(spacing: 4) {
                            ForEach(0..<engine.briefs.count, id: \.self) { i in
                                Circle()
                                    .fill(i == currentIndex % engine.briefs.count ? brief.accentColor : .white.opacity(0.2))
                                    .frame(width: 4, height: 4)
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
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(brief.subtext)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
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
                    withAnimation(.spring(response: 0.3)) {
                        currentIndex = (currentIndex + 1) % engine.briefs.count
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .id(currentIndex)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
            }
        }
        .onAppear {
            engine.reload(pets: pets, humans: humans)
            startTimer()
        }
        .onDisappear { stopTimer() }
        .onChange(of: pets.count) { _, _ in engine.reload(pets: pets, humans: humans) }
        .onChange(of: humans.count) { _, _ in engine.reload(pets: pets, humans: humans) }
    }

    private func startTimer() {
        stopTimer()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { _ in
            guard !engine.briefs.isEmpty else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentIndex = (currentIndex + 1) % engine.briefs.count
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
    var onTap: (() -> Void)? = nil
    // 全岛总资产：直接使用 QuestManager.coconutCount（全局唯一数据源）
    private var computedTotal: Int {
        return QuestManager.shared.coconutCount
    }

    private struct RankEntry: Identifiable {
        let id = UUID()
        let emoji: String
        let name: String
        let balance: Int
    }

    private var leaderboard: [RankEntry] {
        var all: [RankEntry] = []
        all += pets.map   { RankEntry(emoji: $0.avatarEmoji, name: $0.name,  balance: $0.coconutBalance) }
        all += humans.map { RankEntry(emoji: $0.avatarEmoji, name: $0.name,  balance: $0.coconutBalance) }
        // Bug11: 即使 balance=0 也展示所有成员，按余额降序，最多显示前3名
        return all.sorted { $0.balance > $1.balance }.prefix(3).map { $0 }
    }

    private let rankEmojis = ["🥇", "🥈", "🥉", "4️⃣"]

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 12) {
                // 标题行
                HStack(spacing: 6) {
                    Text("🌴")
                        .font(.system(size: 14))
                    Text("Ohana财富")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                        .tracking(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.3))
                }

                // 大数字
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(computedTotal)")
                        .font(OhanaFont.metric(size: 36))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("🥥")
                        .font(.system(size: 18))
                }

            OhanaDashedDivider(color: .white.opacity(0.1)).padding(.vertical, 4)

            // 排行榜
            if leaderboard.isEmpty {
                Text("完成打卡即可解锁财富榜 ✨")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.3))
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { i, entry in
                        HStack(spacing: 10) {
                            Text(rankEmojis[i])
                                .font(.system(size: 14))
                                .frame(width: 20)
                            ZStack {
                                Circle()
                                    .fill(Color.goPrimary.mix(with: .black, by: 0.35))
                                    .frame(width: 28, height: 28)
                                Text(entry.emoji)
                                    .font(.system(size: 14))
                            }
                            Text(entry.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.balance) 🥥")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(i == 0 ? Color.goLime : .white.opacity(0.6))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(i == 0 ? Color.goLime.opacity(0.15) : Color.white.opacity(0.06),
                                            in: Capsule())
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
        withAnimation(.easeOut(duration: 0.28)) {
            animPhase = 1.0
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.1), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(progress) * animPhase)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.28), value: progress * Double(animPhase))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(accentColor)
        }
        .frame(width: 44, height: 44)
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear { playAnimation() }
        .onChange(of: progress) { _, _ in playAnimation() }
    }
}
