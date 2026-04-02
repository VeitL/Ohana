//
//  GachaView.swift
//  Ohana
//
//  欧气扭蛋机 — 消耗 30🥥/次，抽取稀有图标/气候特效/称号
//

import SwiftUI
import SwiftData

// MARK: - 奖品模型
struct GachaPrize: Identifiable {
    let id: String
    let emoji: String
    let name: String
    let rarity: Rarity
    let description: String

    enum Rarity: String {
        case common   = "普通"
        case rare     = "稀有"
        case epic     = "史诗"
        case legend   = "传说"

        var color: Color {
            switch self {
            case .common: return .white.opacity(0.6)
            case .rare:   return Color.goTeal
            case .epic:   return Color.goPrimary
            case .legend: return Color.goYellow
            }
        }

        var glowColor: Color {
            switch self {
            case .common: return .white.opacity(0.1)
            case .rare:   return Color.goTeal.opacity(0.4)
            case .epic:   return Color.goPrimary.opacity(0.5)
            case .legend: return Color.goYellow.opacity(0.6)
            }
        }

        var weight: Int {
            switch self {
            case .common: return 55
            case .rare:   return 30
            case .epic:   return 12
            case .legend: return 3
            }
        }
    }

    /// 是否是补打卡券类型
    var isBackdatePass: Bool {
        id == "r_backdate_1day" || id == "e_backdate_3day"
    }
    /// 补打卡券可补天数
    var backdateDays: Int {
        id == "e_backdate_3day" ? 3 : (id == "r_backdate_1day" ? 1 : 0)
    }

    static let allPrizes: [GachaPrize] = [
        // Common（概率合计 55%，调整后每张约11%）
        GachaPrize(id: "c_paw",    emoji: "🐾", name: "肉球印章",    rarity: .common, description: "可爱肉球装饰徽章"),
        GachaPrize(id: "c_bone",   emoji: "🦴", name: "骨头项圈",    rarity: .common, description: "经典骨头风格"),
        GachaPrize(id: "c_fish",   emoji: "🐟", name: "小鱼干",      rarity: .common, description: "猫咪最爱"),
        GachaPrize(id: "c_carrot", emoji: "🥕", name: "胡萝卜勋章",  rarity: .common, description: "兔兔能量补充"),
        GachaPrize(id: "c_sun",    emoji: "☀️", name: "晴天徽章",    rarity: .common, description: "阳光明媚的一天"),
        // Rare（概率合计 30%，含补打卡券 8%）
        GachaPrize(id: "r_rainbow",      emoji: "🌈", name: "彩虹光环",      rarity: .rare,   description: "打卡时环绕彩虹光"),
        GachaPrize(id: "r_moon",         emoji: "🌙", name: "月光守夜",      rarity: .rare,   description: "夜间打卡特效"),
        GachaPrize(id: "r_flower",       emoji: "🌸", name: "樱花飘落",      rarity: .rare,   description: "春季风格特效"),
        GachaPrize(id: "r_backdate_1day",emoji: "�", name: "昨日补打卡券",   rarity: .rare,   description: "补录昨天任意 1 次打卡，正常获得椰子奖励"),
        // Epic（概率合计 12%，含补打卡券 3%）
        GachaPrize(id: "e_diamond",      emoji: "💎", name: "钻石星光",      rarity: .epic,   description: "史诗级钻石光晕特效"),
        GachaPrize(id: "e_rocket",       emoji: "🚀", name: "星际漫游",      rarity: .epic,   description: "宇宙探索者称号"),
        GachaPrize(id: "e_aurora",       emoji: "🌌", name: "极光夜幕",      rarity: .epic,   description: "史诗级极光背景"),
        GachaPrize(id: "e_backdate_3day",emoji: "📅", name: "三日补打卡券",   rarity: .epic,   description: "补录 3 天内任意 1 次打卡，正常获得奖励"),
        // Legend
        GachaPrize(id: "l_crown",   emoji: "👑", name: "岛主王冠",   rarity: .legend, description: "传说级！欧哈纳岛主专属"),
        GachaPrize(id: "l_dragon",  emoji: "🐉", name: "神龙之力",   rarity: .legend, description: "传说级！龙年限定守护"),
    ]

    static func roll() -> GachaPrize {
        // 每个奖品单独权重：同稀有度内均分（补打卡券单独权重）
        // r_backdate_1day: 8, r_火焰/月光/彩虹/花: 各(30-8)/4=5.5→6/6/5/5
        // e_backdate_3day: 3, e_其他3个: 各(12-3)/3=3
        let weights: [String: Int] = [
            "c_paw": 11, "c_bone": 11, "c_fish": 11, "c_carrot": 11, "c_sun": 11,
            "r_rainbow": 5, "r_moon": 6, "r_flower": 6, "r_backdate_1day": 8,
            "e_diamond": 3, "e_rocket": 3, "e_aurora": 3, "e_backdate_3day": 3,
            "l_crown": 1, "l_dragon": 2,
        ]
        let total = weights.values.reduce(0, +)
        var roll = Int.random(in: 0..<total)
        for prize in allPrizes {
            let w = weights[prize.id] ?? prize.rarity.weight
            roll -= w
            if roll < 0 { return prize }
        }
        return allPrizes.first!
    }
}

// MARK: - 扭蛋机 View
struct GachaView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("gachaHistory") private var historyRaw: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @State private var questManager = QuestManager.shared

    private let cost = 30

    @State private var isRolling     = false
    @State private var capsuleScale  : CGFloat = 1.0
    @State private var capsuleRotation: Double = 0
    @State private var showResult    = false
    @State private var currentPrize  : GachaPrize? = nil
    @State private var prizeBounce   = false
    @State private var glowOpacity   : Double = 0
    @State private var particles     : [(id: UUID, x: CGFloat, opacity: Double)] = []
    @State private var historyItems  : [GachaPrize] = []
    @State private var showBackdateSheet = false
    @State private var backdatePrize: GachaPrize? = nil

    private var canRoll: Bool { questManager.coconutCount >= cost && !isRolling }

    // 历史记录（最多显示12个）
    private var recentHistory: [GachaPrize] {
        let ids = historyRaw.split(separator: ",").prefix(12).map(String.init)
        return ids.compactMap { id in GachaPrize.allPrizes.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()

                // 背景光晕
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.goPrimary.opacity(0.18 + glowOpacity * 0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    ))
                    .frame(width: 400, height: 400)
                    .animation(.easeInOut(duration: 0.6), value: glowOpacity)

                // 粒子
                ForEach(particles, id: \.id) { p in
                    Circle()
                        .fill(Color.goPrimary.opacity(p.opacity))
                        .frame(width: 6, height: 6)
                        .position(x: p.x, y: geo.size.height * 0.42)
                        .blur(radius: 2)
                }

                ScrollView {
                    VStack(spacing: 32) {
                        // 余额
                        balanceRow

                        // 扭蛋机主体
                        gachaMachine

                        // 结果展示
                        if showResult, let prize = currentPrize {
                            prizeResultCard(prize)
                                .transition(.scale.combined(with: .opacity))
                        }

                        // 历史记录
                        if !recentHistory.isEmpty {
                            historySection
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            }
            .navigationTitle("欧气扭蛋机")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Color.goPrimary)
                }
            }
        }
    }

    // MARK: - 余额行
    private var balanceRow: some View {
        HStack {
            HStack(spacing: 6) {
                Text("🥥")
                Text("\(questManager.coconutCount)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goYellow)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: questManager.coconutCount)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.white.opacity(0.08), in: Capsule())

            Spacer()

            Text("每次消耗 \(cost)🥥")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.35))
        }
    }

    // MARK: - 扭蛋机主体
    private var gachaMachine: some View {
        VStack(spacing: 24) {
            // 扭蛋球
            ZStack {
                // 外光晕
                Circle()
                    .fill(RadialGradient(
                        colors: [
                            (currentPrize?.rarity.glowColor ?? Color.goPrimary.opacity(0.3)),
                            .clear
                        ],
                        center: .center, startRadius: 20, endRadius: 100
                    ))
                    .frame(width: 200, height: 200)
                    .opacity(isRolling ? 1.0 : 0.4)
                    .animation(.easeInOut(duration: 0.4), value: isRolling)

                // 球体
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.goPrimary, Color.goDeepNavy],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 130, height: 130)
                        .shadow(color: Color.goPrimary.opacity(0.6), radius: isRolling ? 30 : 10, x: 0, y: 0)

                    // 分割线
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 130, height: 2)

                    // 中心图标
                    Text(isRolling ? "❓" : (currentPrize?.emoji ?? "🎲"))
                        .font(.system(size: 48))
                        .shadow(color: .white.opacity(0.5), radius: 8)
                }
                .scaleEffect(capsuleScale)
                .rotationEffect(.degrees(capsuleRotation))
            }
            .frame(height: 200)

            // 抽取按钮
            Button {
                rollGacha()
            } label: {
                HStack(spacing: 8) {
                    if isRolling {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                    } else {
                        Text("🎰")
                    }
                    Text(isRolling ? "抽取中..." : "抽一次")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(canRoll ? .black : .white.opacity(0.3))
                    if !isRolling {
                        Text("-\(cost)🥥")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(canRoll ? .black.opacity(0.5) : .white.opacity(0.2))
                    }
                }
                .frame(width: 200)
                .padding(.vertical, 16)
                .background(
                    canRoll ? Color.goPrimary : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: canRoll ? Color.goPrimary.opacity(0.5) : .clear, radius: 20, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .opacity(canRoll ? 1 : 0.5)
            .disabled(!canRoll)

            if questManager.coconutCount < cost {
                Text("椰子不足，快去打卡赚取吧 🥥")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.3))
            }
        }
    }

    // MARK: - 奖品结果卡
    private func prizeResultCard(_ prize: GachaPrize) -> some View {
        VStack(spacing: 14) {
            Text("✨ 恭喜获得 ✨")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
                .tracking(2)

            Text(prize.emoji)
                .font(.system(size: 64))
                .scaleEffect(prizeBounce ? 1.12 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5).repeatCount(3), value: prizeBounce)

            Text(prize.name)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Text(prize.rarity.rawValue)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(prize.rarity.color)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(prize.rarity.color.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(prize.rarity.color.opacity(0.4), lineWidth: 1))

            Text(prize.description)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
                .multilineTextAlignment(.center)

            // 补打卡券：立即使用 按钮
            if prize.isBackdatePass {
                Button {
                    backdatePrize = prize
                    showBackdateSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text("📅")
                        Text("立即使用补打卡券")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 28).padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(prize.rarity.glowColor, lineWidth: 1.5)
                )
        )
        .shadow(color: prize.rarity.glowColor, radius: 24, x: 0, y: 8)
        .sheet(isPresented: $showBackdateSheet) {
            if let bp = backdatePrize {
                BackdateCheckInSheet(backdateDays: bp.backdateDays)
            }
        }
    }

    // MARK: - 历史记录
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近记录")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(recentHistory) { prize in
                    VStack(spacing: 4) {
                        Text(prize.emoji)
                            .font(.system(size: 26))
                            .frame(width: 46, height: 46)
                            .background(prize.rarity.glowColor, in: RoundedRectangle(cornerRadius: 12))
                        Text(prize.rarity.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(prize.rarity.color)
                    }
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.07), lineWidth: 1))
        )
    }

    // MARK: - 抽取逻辑
    private func rollGacha() {
        guard canRoll else { return }
        isRolling = true
        showResult = false
        questManager.coconutCount -= cost

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // 旋转动画
        withAnimation(.linear(duration: 0.8).repeatCount(3)) {
            capsuleRotation = 360
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).repeatCount(4)) {
            capsuleScale = 1.15
        }
        withAnimation(.easeInOut(duration: 0.6)) {
            glowOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            capsuleRotation = 0
            capsuleScale = 1.0

            let prize = GachaPrize.roll()
            currentPrize = prize

            // 追加历史
            var ids = historyRaw.split(separator: ",").map(String.init)
            ids.insert(prize.id, at: 0)
            historyRaw = ids.prefix(24).joined(separator: ",")

            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                showResult = true
            }
            prizeBounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                prizeBounce = false
            }

            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            if prize.rarity == .legend {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }

            withAnimation(.easeOut(duration: 0.4)) {
                glowOpacity = 0
            }
            isRolling = false
        }
    }
}
