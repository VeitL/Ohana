//
//  OasisRewardView.swift
//  Ohana
//
//  绿洲圣地 — 生命之树动态进化 + 注入能量 + Bento 功能区
//

import SwiftUI
import SwiftData

struct OasisRewardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]

    @State private var treeScale: CGFloat   = 1.0
    @State private var treeGlow: CGFloat    = 0.4
    @State private var showAchievements     = false
    @State private var showingCoconutLog    = false
    @State private var showCoconutShop      = false
    @State private var showGacha            = false
    @State private var showBountyBoard      = false
    @State private var showCoconutRules     = false
    @State private var showCheckInCalendar  = false
    @State private var energyParticles: [EnergyParticle] = []
    // 模块六：打卡日历
    @State private var checkedInDates: Set<String> = []   // "yyyy-MM-dd" 格式
    @State private var makeupPackCount: Int = 0            // 补签包数量
    @State private var showMakeupConfirm: String? = nil    // 待确认补签的日期
    private let checkedInKey = "oasis_checkedIn_dates"
    private let makeupPackKey = "oasis_makeup_pack_count"
    @State private var lastLevel: TreeLevel = .lv1
    @State private var isInjecting: Bool = false
    @State private var levelUpPulse         = false
    @State private var harvestBubbleBounce  = false
    @State private var justHarvested        = false
    // 任务7：环境光晕 + 采摘飞出
    @State private var glowBreathing: Bool  = false
    @State private var flyCoconut: Bool     = false
    @State private var flyOpacity: Double   = 0

    private let treeMgr = OasisTreeManager.shared

    private struct EnergyParticle: Identifiable {
        let id = UUID()
        var offsetX: CGFloat = CGFloat.random(in: -80...80)
        var offsetY: CGFloat = 0
        var opacity: Double  = 1.0
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()

            // task21: 粒子特效放在最外层 ZStack，不被 ScrollView 裁剪
            ForEach(energyParticles) { p in
                Text("✨")
                    .font(.system(size: 22))
                    .offset(x: p.offsetX, y: p.offsetY)
                    .opacity(p.opacity)
                    .allowsHitTesting(false)
            }
            .zIndex(99)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── 顶部 Header（safeAreaInset 由外层 TabView 处理）
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("欧哈纳")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(3)
                            Text("绿洲")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button { showCoconutRules = true } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                            // 模块六入口：打卡日历
                            Button { showCheckInCalendar = true } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.goLime)
                                    Text("\(currentStreak)")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.goLime)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.goLime.opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.goLime.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            CoconutBalanceCapsule { showingCoconutLog = true }
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 16)

                    // 新手任务面板
                    if !QuestManager.shared.isAllWelcomeQuestsCompleted {
                        WelcomeQuestBentoView()
                            .padding(.horizontal, 20).padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── 生命之树核心区
                    treeSection
                        .padding(.top, 60)

                    // ── 树等级说明
                    treeLevelLabel
                        .padding(.top, 20)

                    // ── 注入能量按钮
                    injectEnergyButton
                        .padding(.top, 18)

                    // ── Bento 功能区（紧凑小卡）
                    oasisBentoGrid
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 140)
                }
            }
        }
        .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
        .sheet(isPresented: $showCoconutRules) { CoconutRulesSheet() }
        .sheet(isPresented: $showAchievements) {
            if let pet = pets.first {
                NavigationStack { AchievementWallView(pet: pet) }
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showCoconutShop) {
            CoconutShopView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showGacha) {
            GachaView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showBountyBoard) {
            BountyBoardView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showCheckInCalendar) {
            checkInCalendarCard
                .padding(.top, 12)
                .padding(.horizontal, 20)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans)
            lastLevel = treeMgr.treeLevel
            startBreathing()
            loadCheckInData()
            triggerTodayCheckIn()
        }
        // 补签确认弹窗
        .confirmationDialog(
            showMakeupConfirm.map { "补签 \($0)？" } ?? "",
            isPresented: Binding(get: { showMakeupConfirm != nil }, set: { if !$0 { showMakeupConfirm = nil } }),
            titleVisibility: .visible
        ) {
            Button("消耗1个补签包确认补签") {
                if let d = showMakeupConfirm { applyMakeup(date: d) }
                showMakeupConfirm = nil
            }
            Button("取消", role: .cancel) { showMakeupConfirm = nil }
        }
        .onChange(of: pets.count)   { treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans) }
        .onChange(of: humans.count) { treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans) }
    }

    // MARK: - Tree Section

    private var treeSection: some View {
        ZStack(alignment: .bottom) {
            // 呈呆呹呢呢呢呢呢呢呢：呼吸圆形环境光晕
            Circle()
                .fill(RadialGradient(
                    colors: [treeMgr.treeLevel.glowColor.opacity(glowBreathing ? 0.28 : 0.08), .clear],
                    center: .center, startRadius: 20, endRadius: 180
                ))
                .frame(width: 340, height: 340)
                .scaleEffect(glowBreathing ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowBreathing)

            // 外圈发光輪廓（goLime shadow 呼吸）
            Circle()
                .stroke(Color.goLime.opacity(glowBreathing ? 0.22 : 0.06), lineWidth: 2)
                .frame(width: 260, height: 260)
                .blur(radius: glowBreathing ? 6 : 2)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowBreathing)

            // 动态生长椰子树
            BeautifulCoconutTree(
                level: treeMgr.treeLevel.rawValue,
                isInjecting: isInjecting
            )
            .shadow(color: Color.goLime.opacity(glowBreathing ? 0.45 : 0.15), radius: glowBreathing ? 24 : 10, x: 0, y: 0)
            .scaleEffect(levelUpPulse ? 1.12 : treeScale)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: levelUpPulse)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: treeScale)
            .offset(y: -20)

            // 采摘气泡（升级交互闭环）
            if treeMgr.canHarvestToday && !justHarvested {
                Button {
                    guard treeMgr.harvestDailyPassiveIncome() else { return }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(.spring(response: 0.3)) { justHarvested = true }
                    spawnEnergyParticles()
                    // 椰子飞出动画
                    flyCoconut = false
                    flyOpacity = 1
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.05)) {
                        flyCoconut = true
                    }
                    withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
                        flyOpacity = 0
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("🥥").font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("点击采摘今日推落")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                            Text("+\(treeMgr.passiveIncomeAmount) 椰子")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.black.opacity(0.6))
                        }
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black.opacity(0.5))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [Color.goYellow, Color(hex: "FFB800")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule()
                    )
                    .shadow(color: Color.goYellow.opacity(harvestBubbleBounce ? 0.75 : 0.35),
                            radius: harvestBubbleBounce ? 16 : 8, x: 0, y: 4)
                    .scaleEffect(harvestBubbleBounce ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: harvestBubbleBounce)
                }
                .buttonStyle(.plain)
                .offset(y: 42)
                .transition(.scale.combined(with: .opacity))
                .onAppear { harvestBubbleBounce = true }
            }

            // 椰子飞入余额区动画层
            if flyOpacity > 0 {
                Text("🥥")
                    .font(.system(size: 28))
                    .offset(y: flyCoconut ? -280 : -60)
                    .opacity(flyOpacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 320)
        .onAppear {
            justHarvested = !treeMgr.canHarvestToday
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowBreathing = true
            }
        }
        .onChange(of: treeMgr.treeLevel) { _, _ in justHarvested = !treeMgr.canHarvestToday }
    }

    private var treeLevelLabel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(treeMgr.treeLevel.displayName)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("·  生命之树")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [treeMgr.treeLevel.glowColor, treeMgr.treeLevel.glowColor.opacity(0.5)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * treeMgr.progressToNextLevel, height: 6)
                        .animation(.spring(response: 0.6), value: treeMgr.progressToNextLevel)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 60)

            Text("能量 \(treeMgr.totalEnergy) · 下一级需 \(treeMgr.nextLevelThreshold)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var injectEnergyButton: some View {
        Button {
            let beforeLevel = treeMgr.treeLevel
            withAnimation { isInjecting = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { isInjecting = false }
            }
            if treeMgr.injectEnergy(cost: 10) {
                spawnEnergyParticles()
                if treeMgr.treeLevel != beforeLevel {
                    withAnimation { levelUpPulse = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation { levelUpPulse = false }
                    }
                }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } label: {
            HStack(spacing: 8) {
                Text("✨")
                Text("注入能量")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                Text("(-10🥥)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(
                QuestManager.shared.coconutCount >= 10
                    ? Color.goLime
                    : Color.white.opacity(0.1),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(
                QuestManager.shared.coconutCount >= 10
                    ? Color.clear
                    : Color.white.opacity(0.2),
                lineWidth: 1
            ))
        }
        .buttonStyle(.plain)
        .opacity(QuestManager.shared.coconutCount >= 10 ? 1 : 0.45)
    }

    // MARK: - 模块六：打卡日历

    private var checkInCalendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题行
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.goLime)
                    Text("打卡日历")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                // 连胜天数
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(currentStreak) 天连胜")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.goYellow.opacity(0.12), in: Capsule())
                // 补签包数量
                if makeupPackCount > 0 {
                    HStack(spacing: 4) {
                        Text("📦")
                        Text("×\(makeupPackCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.08), in: Capsule())
                }
            }

            // 30天日历网格（每行7天）
            let days = last30Days()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { dateStr in
                    let isToday = dateStr == todayStr()
                    let isChecked = checkedInDates.contains(dateStr)
                    let dayNum = dayNumber(from: dateStr)
                    Button {
                        if !isChecked && !isToday && makeupPackCount > 0 {
                            showMakeupConfirm = dateStr
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    isChecked
                                        ? Color.goLime
                                        : (isToday ? Color.goLime.opacity(0.22) : Color.white.opacity(0.05))
                                )
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle().strokeBorder(
                                        isToday ? Color.goLime : .clear, lineWidth: 1.5
                                    )
                                )
                            if isChecked {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(.black)
                            } else {
                                Text(dayNum)
                                    .font(.system(size: 11, weight: isToday ? .black : .medium, design: .rounded))
                                    .foregroundStyle(
                                        isToday ? Color.goLime : .white.opacity(0.4)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecked || isToday || makeupPackCount == 0)
                }
            }

            // 提示文字
            if makeupPackCount > 0 {
                Text("点击灰色日期可消耗1个补签包")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
            } else {
                Text("在椰子商店购买补签包，可补录漏打卡日期")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.goLime.opacity(0.15), lineWidth: 1))
    }

    // MARK: - 打卡工具函数

    private func todayStr() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; return fmt.string(from: Date())
    }

    private func last30Days() -> [String] {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        return (0..<30).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: Date()).map { fmt.string(from: $0) }
        }
    }

    private func dayNumber(from dateStr: String) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: dateStr) else { return "" }
        return "\(Calendar.current.component(.day, from: d))"
    }

    private var currentStreak: Int {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        var streak = 0
        var day = Date()
        while true {
            let s = fmt.string(from: day)
            if checkedInDates.contains(s) {
                streak += 1
                day = cal.date(byAdding: .day, value: -1, to: day)!
            } else { break }
        }
        return streak
    }

    private func loadCheckInData() {
        if let arr = UserDefaults.standard.stringArray(forKey: checkedInKey) {
            checkedInDates = Set(arr)
        }
        makeupPackCount = UserDefaults.standard.integer(forKey: makeupPackKey)
    }

    private func triggerTodayCheckIn() {
        let today = todayStr()
        guard !checkedInDates.contains(today) else { return }
        checkedInDates.insert(today)
        UserDefaults.standard.set(Array(checkedInDates), forKey: checkedInKey)
        // 奖励1椰子
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: "每日打卡奖励")
    }

    private func applyMakeup(date: String) {
        guard makeupPackCount > 0, !checkedInDates.contains(date) else { return }
        makeupPackCount -= 1
        UserDefaults.standard.set(makeupPackCount, forKey: makeupPackKey)
        checkedInDates.insert(date)
        UserDefaults.standard.set(Array(checkedInDates), forKey: checkedInKey)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Bento Grid

    private var oasisBentoGrid: some View {
        let allAchievements = pets.flatMap { AchievementManager.compute(for: $0) }
        let unlockedCount   = allAchievements.filter { $0.isUnlocked }.count
        let totalCount      = allAchievements.count

        return VStack(spacing: 8) {
            // 行一：椰子商店 + 成就解锁
            HStack(spacing: 8) {
                bentoMiniCard(emoji: "🛒", title: "椰子商店",
                    subtitle: "兑换特效称号", accent: Color.goYellow,
                    action: { showCoconutShop = true })
                bentoMiniCard(emoji: "🏆", title: "成就解锁",
                    subtitle: "\(unlockedCount)/\(totalCount)", accent: Color.goTeal,
                    action: { showAchievements = true })
            }
            // 行二：扭蛋机 + 悬赏榜
            HStack(spacing: 8) {
                bentoMiniCard(emoji: "🎰", title: "欧气扭蛋机",
                    subtitle: "30🥥/次", accent: Color.goPrimary,
                    action: { showGacha = true })
                bentoMiniCard(emoji: "📋", title: "家庭悬赏榜",
                    subtitle: "发布任务", accent: Color.goOrange,
                    action: { showBountyBoard = true })
            }
        }
    }

    private func bentoBigCard(emoji: String, title: String, subtitle: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(emoji).font(.system(size: 30))
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accent.opacity(0.8))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .frame(minHeight: 130)
            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func bentoSmallCard(emoji: String, title: String, subtitle: String, accent: Color, locked: Bool) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(locked ? "即将上线" : subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(locked ? .white.opacity(0.25) : accent.opacity(0.8))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(accent.opacity(locked ? 0.04 : 0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(accent.opacity(locked ? 0.08 : 0.2), lineWidth: 1))
        .opacity(locked ? 0.6 : 1)
    }

    private func bentoMiniCard(emoji: String, title: String, subtitle: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accent.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Animations

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            treeScale = 1.055
            treeGlow  = 0.7
        }
    }

    private func spawnEnergyParticles() {
        energyParticles = (0..<8).map { _ in EnergyParticle() }
        for i in energyParticles.indices {
            withAnimation(.easeOut(duration: Double.random(in: 0.8...1.4)).delay(Double(i) * 0.06)) {
                energyParticles[i].offsetY  = CGFloat.random(in: -180 ... -80)
                energyParticles[i].opacity  = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            energyParticles.removeAll()
        }
    }
}

// MARK: - 椰子获取与消耗指南（Bento 卡片风格）
private struct CoconutRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    // 每条规则独立卡片数据
    private struct RuleCard: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let desc: String
        let glowColor: Color
        let reward: String
    }

    private let earnCards: [RuleCard] = [
        RuleCard(emoji: "�", title: "遛狗", desc: "带毛孩子出门溜达", glowColor: Color(hex: "C8FF00"), reward: "每100m得1🥥"),
        RuleCard(emoji: "🍗", title: "喂食·喂水", desc: "按时投喂，爱意满满", glowColor: Color(hex: "FF8C42"), reward: "每次2~3🥥"),
        RuleCard(emoji: "🧹", title: "铲屎官在线", desc: "勤劳铲屎，功德无量", glowColor: Color(hex: "A8E6CF"), reward: "每次5~8🥥"),
        RuleCard(emoji: "🪮", title: "护理·梳毛", desc: "精心打理，美美的", glowColor: Color(hex: "DDA0DD"), reward: "5~10🥥，洗澡15🥥"),
        RuleCard(emoji: "💉", title: "健康打卡", desc: "关注健康，守护生命", glowColor: Color(hex: "FF6B6B"), reward: "每次20🥥"),
        RuleCard(emoji: "💰", title: "记一笔账", desc: "精打细算，爱的花销", glowColor: Color(hex: "FFD93D"), reward: "每次10🥥"),
        RuleCard(emoji: "🎾", title: "逗玩互动", desc: "玩耍时光最快乐", glowColor: Color(hex: "6BCB77"), reward: "每次10~12🥥"),
        RuleCard(emoji: "🌳", title: "每日掉落", desc: "生命之树被动收益", glowColor: Color(hex: "C8FF00"), reward: "定时领取"),
        RuleCard(emoji: "🎲", title: "暴击加成", desc: "幸运降临！", glowColor: Color(hex: "FFCC00"), reward: "10%双倍·1%五倍🔥"),
    ]

    private let spendCards: [RuleCard] = [
        RuleCard(emoji: "✨", title: "注入生命之树", desc: "让生命之树更旺盛", glowColor: Color(hex: "C8FF00"), reward: "每次10🥥"),
        RuleCard(emoji: "🛍️", title: "椰子商店", desc: "兑换特效/称号/加成", glowColor: Color(hex: "667eea"), reward: "各种道具"),
        RuleCard(emoji: "🎰", title: "欧气扭蛋机", desc: "测测你的运气！", glowColor: Color(hex: "FF6B9D"), reward: "每次30🥥"),
        RuleCard(emoji: "�", title: "悬赏任务", desc: "发布·接单·奖励", glowColor: Color(hex: "FF8C42"), reward: "转给完成者"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()
                LinearGradient(
                    colors: [Color.goPrimary.opacity(0.15), Color(hex: "060E24")],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // ── 收入区
                        bentoCategoryHeader(emoji: "🥥", title: "赚取椰子", subtitle: "打卡越多，岛屿越繁荣！")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(earnCards.enumerated()), id: \.element.id) { idx, card in
                                bentoCard(card, delay: Double(idx) * 0.05)
                            }
                        }

                        // ── 支出区
                        bentoCategoryHeader(emoji: "💸", title: "花费椰子", subtitle: "用来升级岛屿，感受不同体验")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(spendCards.enumerated()), id: \.element.id) { idx, card in
                                bentoCard(card, delay: Double(earnCards.count + idx) * 0.05)
                            }
                        }

                        // ── 双账本说明
                        bentoCategoryHeader(emoji: "👥", title: "双账本系统", subtitle: "人宠各有账户，共同建设岛屿")
                        VStack(spacing: 10) {
                            doubleAccountRow(emoji: "🐾", title: "宠物账户", desc: "记录宠物自己赚取的椰子")
                            doubleAccountRow(emoji: "🧑", title: "主人账户", desc: "记录协助打卡的人类获得的椰子")
                            doubleAccountRow(emoji: "🏝️", title: "全岛总库", desc: "所有椰子之和，用于商店与扭蛋")
                        }
                        .padding(14)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1))

                        // ── 底部口号
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Text("💡")
                                    .font(.system(size: 28))
                                Text("打卡次数越多，椰子越多，生命之树越旺！")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("椰子指南 🥥")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true }
        }
    }

    @ViewBuilder
    private func bentoCategoryHeader(emoji: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(emoji).font(.system(size: 18))
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private func bentoCard(_ card: RuleCard, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.emoji)
                .font(.system(size: 28))
            Text(card.title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(card.desc)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(card.reward)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(card.glowColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(card.glowColor.opacity(0.15), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.04))
                // 霓虹微光
                RadialGradient(
                    colors: [card.glowColor.opacity(0.18), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 80
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(card.glowColor.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(delay), value: appeared)
    }

    @ViewBuilder
    private func doubleAccountRow(emoji: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 20)).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
    }
}

#Preview {
    OasisRewardView()
        .modelContainer(SharedModelContainer.make())
}
