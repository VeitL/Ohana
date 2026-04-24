//
//  OasisRewardView.swift
//  Ohana
//
//  绿洲圣地 — 生命之树动态进化 + 注入能量 + Bento 功能区
//

import SwiftUI
import SwiftData

struct OasisRewardView: View {
    var hideToolbar: Bool = false
    var rulesTrigger: Bool = false
    var inventoryTrigger: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    @State private var treeScale: CGFloat   = 1.0
    @State private var treeGlow: CGFloat    = 0.4
    @State private var showAchievements     = false
    @State private var showingCoconutLog    = false
    @State private var showCoconutShop      = false
    @State private var showGacha            = false
    @State private var showBountyBoard      = false
    @State private var showInventory        = false
    @State private var showCoconutRules     = false
    @State private var showCheckInCalendar  = false
    @State private var showCheckInSheet     = false
    @State private var energyParticles: [EnergyParticle] = []
    // 模块六：打卡日历
    @State private var checkedInDates: Set<String> = []   // "yyyy-MM-dd" 格式
    @State private var makeupPackCount: Int = 0            // 补签包数量
    @State private var showMakeupConfirm: String? = nil    // 待确认补签的日期
    private let checkedInKey = "oasis_checkedIn_dates"
    private let makeupDatesKey = "oasis_makeup_dates"      // 补签日期独立记录
    private let makeupPackKey = "inventory_backdate_1day_count" // 与椰子商店统一 key
    @State private var makeupDates: Set<String> = []       // 补签过的日期集合
    @AppStorage("checkIn_lastClaimedMilestone") private var lastClaimedMilestone: Int = 0
    @AppStorage("appUIStyle") private var appUIStyle: String = "go"
    @Environment(\.colorScheme) private var colorScheme

    private var isMaterial: Bool { appUIStyle == "material" }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var matAccent:  Color { Color(hex: "FF5A00") }
    @State private var lastLevel: TreeLevel = .lv1
    @State private var isInjecting: Bool = false
    @State private var levelUpPulse         = false
    @State private var harvestBubbleBounce  = false
    @State private var justHarvested        = false
    // 任务7：环境光晕 + 采摘飞出
    @State private var glowBreathing: Bool  = false
    @State private var flyCoconut: Bool     = false
    @State private var flyOpacity: Double   = 0
    @State private var harvestedCoconutIndices: Set<Int> = []

    private let treeMgr = OasisTreeManager.shared

    private struct EnergyParticle: Identifiable {
        let id = UUID()
        var offsetX: CGFloat = CGFloat.random(in: -80...80)
        var offsetY: CGFloat = 0
        var opacity: Double  = 1.0
    }

    // MARK: - Star positions (deterministic)
    private let starPositions: [(CGFloat, CGFloat)] = (0..<24).map { i in
        let x = CGFloat((i * 53) % 320) - 160
        let y = CGFloat((i * 37) % 220) - 160
        return (x, y)
    }

    var body: some View {
        ZStack {
            // ── Navy gradient background
            navyBackground

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
                    // R6: 全局 header 占位
                    Spacer().frame(height: 70)

                    if !hideToolbar {
                        // 绿洲工具栏（独立使用时显示，嵌入 tab 时由全局 header 提供）
                        HStack(spacing: 8) {
                            Spacer()
                            Button { showCoconutRules = true } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showInventory = true
                            } label: {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.goPrimary.opacity(0.18), in: Circle())
                                    .overlay(Circle().strokeBorder(Color.goPrimary.opacity(0.35), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24).padding(.top, 4)
                    }

                    // 新手任务面板
                    if !QuestManager.shared.isAllWelcomeQuestsCompleted {
                        WelcomeQuestBentoView()
                            .padding(.horizontal, 20).padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── 页面标题区
                    oasisHeader
                        .padding(.top, 16)
                        .padding(.horizontal, 24)

                    // ── 生命之树核心卡片（夜空风格）
                    treeSceneCard
                        .padding(.horizontal, 16)
                        .padding(.top, 18)

                    // ── 成长进度卡
                    progressCard
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // ── 注入能量按钮
                    injectEnergyButton
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // ── 下一里程碑卡
                    milestoneCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // ── Bento 功能区（紧凑小卡）
                    oasisBentoGrid
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
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
        .sheet(isPresented: $showInventory) {
            InventoryView()
                .presentationDetents([.large])
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
        .sheet(isPresented: $showCheckInSheet) {
            DailyStreakDetailView(pets: pets)
                .presentationDetents([.large])
        }
        .onAppear {
            treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants)
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
        .onChange(of: pets.count)   { treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants) }
        .onChange(of: humans.count) { treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants) }
        .onChange(of: plants.count) { treeMgr.refreshEnergy(modelContext: modelContext, pets: pets, humans: humans, plants: plants) }
        .onChange(of: rulesTrigger) { _, _ in showCoconutRules = true }
        .onChange(of: inventoryTrigger) { _, _ in showInventory = true }
    }

    // MARK: - Navy Background

    private var navyBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2D4ECC"), Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating blob — lime
            Ellipse()
                .fill(Color.goPrimary.opacity(0.12))
                .frame(width: 260, height: 200)
                .blur(radius: 60)
                .offset(x: -80, y: -160)

            // Floating blob — blue
            Ellipse()
                .fill(Color(hex: "5B6AFF").opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 100, y: 80)

            // Floating blob — purple
            Ellipse()
                .fill(Color(hex: "A855F7").opacity(0.13))
                .frame(width: 200, height: 180)
                .blur(radius: 65)
                .offset(x: -60, y: 340)
        }
    }

    // MARK: - Header

    private var oasisHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OASIS · 绿洲")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.45))
                Text("生命之树")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            // Coconut balance pill
            HStack(spacing: 5) {
                Text("🥥")
                    .font(.system(size: 15))
                Text("\(QuestManager.shared.coconutCount)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Color.goPrimary, in: Capsule())
        }
    }

    // MARK: - Tree Scene Card (Night Sky)

    private var treeSceneCard: some View {
        ZStack {
            // Card background — dark radial night-sky gradient
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "0D1B4B"), Color(hex: "060E24")],
                        center: .center, startRadius: 20, endRadius: 260
                    )
                )

            // Stars
            ZStack {
                ForEach(0..<24, id: \.self) { i in
                    let size = CGFloat([1.5, 2.0, 2.5, 1.8][i % 4])
                    Circle()
                        .fill(Color.white.opacity(Double([0.6, 0.8, 0.5, 0.9][i % 4])))
                        .frame(width: size, height: size)
                        .offset(x: starPositions[i].0, y: starPositions[i].1)
                }
            }

            // Moon (top-right)
            Circle()
                .fill(Color.goYellow)
                .frame(width: 28, height: 28)
                .shadow(color: Color.goYellow.opacity(0.7), radius: 12, x: 0, y: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 22).padding(.trailing, 28)

            // Sandy island (bottom ellipse)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 280, height: 52)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, -10)
                .clipped()

            // Decorative bottom elements
            HStack(spacing: 20) {
                Text("🌺").font(.system(size: 18))
                Spacer()
                Text("🐚").font(.system(size: 16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 36).padding(.bottom, 14)

            // Breathing glow ring behind tree
            Circle()
                .fill(RadialGradient(
                    colors: [treeMgr.treeLevel.glowColor.opacity(glowBreathing ? 0.28 : 0.08), .clear],
                    center: .center, startRadius: 20, endRadius: 180
                ))
                .frame(width: 320, height: 320)
                .scaleEffect(glowBreathing ? 1.08 : 0.92)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowBreathing)

            Circle()
                .stroke(Color.goPrimary.opacity(glowBreathing ? 0.22 : 0.06), lineWidth: 2)
                .frame(width: 240, height: 240)
                .blur(radius: glowBreathing ? 6 : 2)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowBreathing)

            // BeautifulCoconutTree
            ZStack(alignment: .bottom) {
                BeautifulCoconutTree(
                    level: treeMgr.treeLevel.rawValue,
                    isInjecting: isInjecting,
                    harvestedCoconuts: harvestedCoconutIndices,
                    onHarvest: { idx in
                        guard !harvestedCoconutIndices.contains(idx) else { return }
                        harvestedCoconutIndices.insert(idx)
                        QuestManager.shared.addCoconuts(1, emoji: "🥥", title: "摘下椰子 +1🥥")
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        flyCoconut = false
                        flyOpacity = 1
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.05)) {
                            flyCoconut = true
                        }
                        withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
                            flyOpacity = 0
                        }
                    }
                )
                .shadow(color: Color.goPrimary.opacity(glowBreathing ? 0.45 : 0.15), radius: glowBreathing ? 24 : 10, x: 0, y: 0)
                .scaleEffect(levelUpPulse ? 1.12 : treeScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: levelUpPulse)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: treeScale)
                .padding(.bottom, 28)

                // Harvest bubble
                if treeMgr.canHarvestToday && !justHarvested {
                    Button {
                        guard treeMgr.harvestDailyPassiveIncome() else { return }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.spring(response: 0.3)) { justHarvested = true }
                        spawnEnergyParticles()
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
                    .padding(.bottom, 10)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear { harvestBubbleBounce = true }
                }
            }

            // Fly coconut animation layer
            if flyOpacity > 0 {
                Text("🥥")
                    .font(.system(size: 28))
                    .offset(y: flyCoconut ? -220 : -60)
                    .opacity(flyOpacity)
                    .allowsHitTesting(false)
            }

            // Level badge pill (top-left)
            HStack(spacing: 5) {
                Text("Lv.\(treeMgr.treeLevel.rawValue) · \(treeMgr.treeLevel.displayName)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.goPrimary, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 16).padding(.leading, 16)
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.goPrimary.opacity(0.35), lineWidth: 1.5)
        )
        .onAppear {
            justHarvested = !treeMgr.canHarvestToday
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glowBreathing = true
            }
        }
        .onChange(of: treeMgr.treeLevel) { _, _ in justHarvested = !treeMgr.canHarvestToday }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row
            HStack {
                Text("成长进度")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("能量 \(treeMgr.totalEnergy) · 下一级 \(treeMgr.nextLevelThreshold)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.goPrimary, Color.goTeal],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * treeMgr.progressToNextLevel, height: 8)
                        .shadow(color: Color.goPrimary.opacity(0.5), radius: 6, x: 0, y: 0)
                        .animation(.spring(response: 0.6), value: treeMgr.progressToNextLevel)
                }
            }
            .frame(height: 8)

            // Stats row
            HStack(spacing: 0) {
                progressStatCell(
                    value: treeMgr.passiveIncomeAmount > 0
                        ? "+\(treeMgr.passiveIncomeAmount)🥥/日"
                        : "Lv.5 解锁",
                    label: "被动收入",
                    color: treeMgr.passiveIncomeAmount > 0
                        ? Color.goPrimary
                        : Color.white.opacity(0.3)
                )
                progressStatCell(
                    value: "\(humans.count + pets.count)成员",
                    label: "家庭贡献",
                    color: Color(hex: "5B6AFF")
                )
                progressStatCell(
                    value: "\(treeMgr.totalEnergy)",
                    label: "岛屿能量",
                    color: Color(hex: "A855F7")
                )
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func progressStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Inject Energy Button

    private var injectEnergyButton: some View {
        let canInject = QuestManager.shared.coconutCount >= 10
        return Button {
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
                Text("⚡")
                Text("注入能量")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                Text("(-10🥥)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canInject ? Color.goPrimary : Color.white.opacity(0.1),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(
                canInject ? Color.clear : Color.white.opacity(0.2),
                lineWidth: 1
            ))
        }
        .buttonStyle(.plain)
        .opacity(canInject ? 1 : 0.45)
    }

    // MARK: - Milestone Card

    /// Passive income per day for each TreeLevel (lv1–lv10)
    private func passiveIncomeForLevel(_ lv: TreeLevel) -> Int {
        switch lv {
        case .lv1:  return 1
        case .lv2:  return 2
        case .lv3:  return 3
        case .lv4:  return 5
        case .lv5:  return 7
        case .lv6:  return 10
        case .lv7:  return 14
        case .lv8:  return 18
        case .lv9:  return 24
        case .lv10: return 30
        }
    }

    private var milestoneCard: some View {
        let currentLv = treeMgr.treeLevel.rawValue
        let isMaxLevel = currentLv >= 10
        let nextLv = min(currentLv + 1, 10)
        let nextLevel = TreeLevel(rawValue: nextLv) ?? .lv10

        return Button {
            // No-op tap (informational)
        } label: {
            HStack(spacing: 14) {
                // Icon square
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.goPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text("🏆")
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if isMaxLevel {
                        Text("已达最高境界")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("生命之树已至巅峰，繁荣永续")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("Lv.\(nextLv) · \(nextLevel.displayName)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("解锁被动收益 +\(passiveIncomeForLevel(nextLevel))🥥/日")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.goPrimary.opacity(0.8))
                    }
                }

                Spacer()

                if !isMaxLevel {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 模块六：打卡日历（完整月视图）

    @State private var calendarDisplayMonth: Date = Date()

    private var checkInCalendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── 标题 + 连胜
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.goPrimary)
                    Text("打卡日历")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(currentStreak) 天连胜")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goYellow)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.goYellow.opacity(0.12), in: Capsule())
            }

            // ── 统计面板
            checkInStatsRow

            OhanaDashedDivider(color: .white.opacity(0.1))

            // ── 月份导航
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        calendarDisplayMonth = Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayMonth) ?? calendarDisplayMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                Spacer()
                Text(monthYearString(calendarDisplayMonth))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    let next = Calendar.current.date(byAdding: .month, value: 1, to: calendarDisplayMonth) ?? calendarDisplayMonth
                    if next <= Date() {
                        withAnimation(.spring(response: 0.3)) { calendarDisplayMonth = next }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            Calendar.current.isDate(calendarDisplayMonth, equalTo: Date(), toGranularity: .month)
                                ? Color.primary.opacity(0.15) : Color.primary.opacity(0.5)
                        )
                }
                .disabled(Calendar.current.isDate(calendarDisplayMonth, equalTo: Date(), toGranularity: .month))
            }
            .padding(.horizontal, 4)

            // ── 星期标题行
            HStack(spacing: 0) {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }

            // ── 月视图网格（按星期正确对齐）
            let cells = monthCalendarCells(for: calendarDisplayMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    calendarDayCell(cell)
                }
            }

            OhanaDashedDivider(color: .white.opacity(0.1))

            // ── 补签包区域
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("📦").font(.system(size: 14))
                    Text("补签包")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.7))
                    Text("×\(makeupPackCount)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(makeupPackCount > 0 ? Color.goPrimary : .white.opacity(0.3))
                }
                Spacer()
                if makeupPackCount > 0 {
                    Text("点击灰色日期补签")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.goPrimary.opacity(0.6))
                } else {
                    Button { showCoconutShop = true } label: {
                        Text("去商店购买 →")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goYellow.opacity(0.8))
                    }
                }
            }

            // ── 里程碑奖励提示
            if currentStreak > 0 {
                checkInMilestoneRow
            }
        }
        .padding(16)
        .background {
            ZStack {
                Color.goDeepNavy
                Color.goPrimary.opacity(0.1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.goPrimary.opacity(0.15), lineWidth: 1))
    }

    // MARK: - 统计面板
    private var checkInStatsRow: some View {
        HStack(spacing: 0) {
            checkInStatCell(value: "\(checkedInDates.count)", label: "总打卡", icon: "checkmark.circle.fill", color: Color.goPrimary)
            checkInStatCell(value: "\(currentStreak)", label: "当前连胜", icon: "flame.fill", color: Color.goYellow)
            checkInStatCell(value: "\(longestStreak)", label: "最长连胜", icon: "trophy.fill", color: Color.goOrange)
            checkInStatCell(value: "\(monthCheckInRate)%", label: "本月", icon: "chart.bar.fill", color: Color.goCardCyan)
        }
    }

    private func checkInStatCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 里程碑奖励行
    private var checkInMilestoneRow: some View {
        let milestones: [(days: Int, reward: Int, emoji: String)] = [
            (7, 10, "⭐️"), (14, 25, "🌟"), (30, 60, "💎"), (60, 150, "👑"), (100, 300, "🏆")
        ]
        let nextMilestone = milestones.first(where: { $0.days > currentStreak })
        let lastClaimed = lastClaimedMilestone

        return VStack(spacing: 6) {
            OhanaDashedDivider(color: .white.opacity(0.1))
            if let next = nextMilestone {
                HStack(spacing: 6) {
                    Text(next.emoji)
                    Text("再连续 \(next.days - currentStreak) 天即可领取 +\(next.reward)🥥")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goPrimary.opacity(0.7))
                    Spacer()
                }
            }

            // 可领取的里程碑
            let claimable = milestones.filter { $0.days <= currentStreak && $0.days > lastClaimed }
            if !claimable.isEmpty {
                ForEach(claimable, id: \.days) { m in
                    Button {
                        claimMilestone(m.days, reward: m.reward, emoji: m.emoji)
                    } label: {
                        HStack(spacing: 8) {
                            Text(m.emoji).font(.system(size: 16))
                            Text("\(m.days) 天连胜达成！")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                            Spacer()
                            Text("+\(m.reward)🥥 领取")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.black.opacity(0.7))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 月历单元格模型
    private struct CalendarCell {
        let dateStr: String  // "" = 占位空格
        let day: Int
        let isToday: Bool
        let isChecked: Bool
        let isMakeup: Bool   // 补签的日期
        let isFuture: Bool
    }

    private func monthCalendarCells(for month: Date) -> [CalendarCell] {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let todayString = fmt.string(from: Date())

        let comps = cal.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = cal.date(from: comps) else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth) - 1 // 0=Sun
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var cells: [CalendarCell] = []

        // 前置空位
        for _ in 0..<weekdayOfFirst {
            cells.append(CalendarCell(dateStr: "", day: 0, isToday: false, isChecked: false, isMakeup: false, isFuture: false))
        }

        // 每天
        for d in 1...daysInMonth {
            var dc = DateComponents(); dc.year = comps.year; dc.month = comps.month; dc.day = d
            let date = cal.date(from: dc) ?? firstOfMonth
            let dateStr = fmt.string(from: date)
            let isToday = dateStr == todayString
            let isChecked = checkedInDates.contains(dateStr)
            let isMakeup = makeupDates.contains(dateStr)
            let isFuture = date > Date() && !isToday
            cells.append(CalendarCell(dateStr: dateStr, day: d, isToday: isToday, isChecked: isChecked, isMakeup: isMakeup, isFuture: isFuture))
        }

        return cells
    }

    @ViewBuilder
    private func calendarDayCell(_ cell: CalendarCell) -> some View {
        if cell.dateStr.isEmpty {
            Color.clear.frame(width: 34, height: 34)
        } else {
            Button {
                if !cell.isChecked && !cell.isToday && !cell.isFuture && makeupPackCount > 0 {
                    showMakeupConfirm = cell.dateStr
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(cellFillColor(cell))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().strokeBorder(
                                cell.isToday ? Color.goPrimary : .clear, lineWidth: 1.5
                            )
                        )
                    if cell.isChecked {
                        if cell.isMakeup {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.black.opacity(0.7))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.black)
                        }
                    } else {
                        Text("\(cell.day)")
                            .font(.system(size: 11, weight: cell.isToday ? .black : .medium, design: .rounded))
                            .foregroundStyle(
                                cell.isFuture ? .white.opacity(0.15) :
                                cell.isToday ? Color.goPrimary : .white.opacity(0.4)
                            )
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(cell.isChecked || cell.isToday || cell.isFuture || makeupPackCount == 0)
        }
    }

    private func cellFillColor(_ cell: CalendarCell) -> Color {
        if cell.isChecked && cell.isMakeup {
            return Color.goYellow.opacity(0.85)
        } else if cell.isChecked {
            return Color.goPrimary
        } else if cell.isToday {
            return Color.goPrimary.opacity(0.22)
        } else {
            return Color.white.opacity(0.05)
        }
    }

    private func monthYearString(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return "\(y) 年 \(m) 月"
    }

    // MARK: - 打卡工具函数

    private func todayStr() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"; return fmt.string(from: Date())
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

    private var longestStreak: Int {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current
        let sorted = checkedInDates.compactMap { fmt.date(from: $0) }.sorted()
        guard !sorted.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<sorted.count {
            if let expected = cal.date(byAdding: .day, value: 1, to: sorted[i-1]),
               cal.isDate(expected, inSameDayAs: sorted[i]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private var monthCheckInRate: Int {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let comps = cal.dateComponents([.year, .month], from: today)
        guard let firstOfMonth = cal.date(from: comps) else { return 0 }
        let dayOfMonth = cal.component(.day, from: today)
        var count = 0
        for d in 0..<dayOfMonth {
            if let date = cal.date(byAdding: .day, value: d, to: firstOfMonth) {
                let s = fmt.string(from: date)
                if checkedInDates.contains(s) { count += 1 }
            }
        }
        return dayOfMonth > 0 ? Int(Double(count) / Double(dayOfMonth) * 100) : 0
    }

    private func loadCheckInData() {
        if let arr = UserDefaults.standard.stringArray(forKey: checkedInKey) {
            checkedInDates = Set(arr)
        }
        if let arr = UserDefaults.standard.stringArray(forKey: makeupDatesKey) {
            makeupDates = Set(arr)
        }
        makeupPackCount = UserDefaults.standard.integer(forKey: makeupPackKey)
    }

    private func triggerTodayCheckIn() {
        let today = todayStr()
        guard !checkedInDates.contains(today) else { return }
        checkedInDates.insert(today)
        UserDefaults.standard.set(Array(checkedInDates), forKey: checkedInKey)
        QuestManager.shared.addCoconuts(1, emoji: "📅", title: "每日打卡奖励")
    }

    private func applyMakeup(date: String) {
        guard makeupPackCount > 0, !checkedInDates.contains(date) else { return }
        makeupPackCount -= 1
        UserDefaults.standard.set(makeupPackCount, forKey: makeupPackKey)
        checkedInDates.insert(date)
        makeupDates.insert(date)
        UserDefaults.standard.set(Array(checkedInDates), forKey: checkedInKey)
        UserDefaults.standard.set(Array(makeupDates), forKey: makeupDatesKey)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func claimMilestone(_ days: Int, reward: Int, emoji: String) {
        QuestManager.shared.addCoconuts(reward, emoji: emoji, title: "\(days)天连胜奖励")
        lastClaimedMilestone = days
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Bento Dynamic Subtitles

    private var shopSubtitle: String {
        let canAfford = QuestManager.shared.coconutCount >= 25
        return canAfford ? "13件道具 · 最低25🥥" : "攒够椰子再来"
    }

    private var gachaSubtitle: String {
        "30🥥/次 · 试试手气"   // 操作导向，不显示历史抽卡统计
    }

    private var bountySubtitle: String {
        let all = BountyTask.loadAll()
        let active = all.filter { !$0.isCompleted }.count
        let mine = BountyTask.pendingAssignedCount(
            for: UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        )
        if mine > 0 { return "@我 \(mine) 个待完成" }
        return active == 0 ? "发布任务 / 接单" : "\(active)个进行中 · 去看看"
    }

    private var bountyAssignedBadge: Int {
        BountyTask.pendingAssignedCount(
            for: UserDefaults.standard.string(forKey: "currentActiveHumanId") ?? ""
        )
    }

    // MARK: - Bento Grid

    private var oasisBentoGrid: some View {
        let allAchievements = pets.flatMap { AchievementManager.compute(for: $0) }
        let unlockedCount   = allAchievements.filter { $0.isUnlocked }.count
        let totalCount      = allAchievements.count
        let noPet           = pets.isEmpty  // 无宠物锁定判断

        return VStack(spacing: 8) {
            // 行一：椰子商店 + 成就解锁
            HStack(spacing: 8) {
                bentoMiniCard(emoji: "🛒", title: "椰子商店",
                    subtitle: shopSubtitle, accent: Color.goYellow,
                    action: { showCoconutShop = true })
                bentoMiniCard(emoji: "🏆", title: "成就解锁",
                    subtitle: noPet ? "添加宠物后解锁 🐾" : "\(unlockedCount)/\(totalCount)",
                    accent: noPet ? Color.white.opacity(0.35) : Color.goTeal,
                    action: { if !noPet { showAchievements = true } })
                    .opacity(noPet ? 0.55 : 1)
            }
            // 行二：扭蛋机 + 悬赏榜
            HStack(spacing: 8) {
                bentoMiniCard(emoji: "🎰", title: "欧气扭蛋机",
                    subtitle: gachaSubtitle, accent: Color.goPrimary,
                    action: { showGacha = true })
                bentoMiniCard(emoji: "📋", title: "家庭悬赏榜",
                    subtitle: bountySubtitle, accent: Color.goOrange,
                    action: { showBountyBoard = true })
                    .overlay(alignment: .topTrailing) {
                        if bountyAssignedBadge > 0 {
                            Text("\(bountyAssignedBadge)")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .padding(.horizontal, 4)
                                .background(Color.goRed, in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.white, lineWidth: 1.5))
                                .offset(x: -6, y: 6)
                        }
                    }
            }
            // 行三：打卡日历（全宽）
            bentoMiniCard(emoji: "📅", title: "打卡日历",
                subtitle: currentStreak > 0 ? "🔥 \(currentStreak)天连胜" : "今日待打卡",
                accent: Color.goOrange,
                action: { loadCheckInData(); showCheckInSheet = true })
        }
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
            .background(
                Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
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

    private struct RuleCard: Identifiable {
        let id = UUID()
        let emoji: String
        let title: String
        let desc: String
        let glowColor: Color
        let reward: String
    }

    private let earnCards: [RuleCard] = [
        RuleCard(emoji: "🦮", title: "遛狗", desc: "带毛孩子出门溜达", glowColor: Color(hex: "C8FF00"), reward: "每100m得1🥥"),
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
        RuleCard(emoji: "🎯", title: "悬赏任务", desc: "发布·接单·奖励", glowColor: Color(hex: "FF8C42"), reward: "转给完成者"),
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
                                    .foregroundStyle(.primary.opacity(0.35))
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
                    Button("关闭") { dismiss() }
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
                    .foregroundStyle(.primary)
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
        }
    }

    @ViewBuilder
    private func bentoCard(_ card: RuleCard, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.emoji)
                .font(.system(size: 28))
            Text(card.title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(card.desc)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.45))
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
                    .foregroundStyle(.primary)
                Text(desc)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
            }
            Spacer()
        }
    }
}

#Preview {
    OasisRewardView()
        .modelContainer(SharedModelContainer.make())
}
